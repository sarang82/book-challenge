import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 데이터 갱신 주기 (기본 24시간)
  final Duration defaultUpdateInterval = const Duration(hours: 24);

  // 마지막 업데이트 시간 확인
  Future<bool> needsUpdate(String collectionName, {Duration? updateInterval}) async {
    final interval = updateInterval ?? defaultUpdateInterval;

    try {
      // 마지막 업데이트 시간 정보를 저장하는 컬렉션
      final updateInfoDoc = await _firestore.collection('updateInfo').doc(collectionName).get();

      if (!updateInfoDoc.exists) {
        if (kDebugMode) {
          print('$collectionName의 업데이트 정보가 없습니다. 업데이트가 필요합니다.');
        }
        return true;
      }

      final lastUpdate = updateInfoDoc.data()?['lastUpdate'] as Timestamp?;
      if (lastUpdate == null) {
        return true;
      }

      final now = DateTime.now();
      final difference = now.difference(lastUpdate.toDate());

      if (kDebugMode) {
        print('$collectionName 마지막 업데이트: ${lastUpdate.toDate()}, 경과 시간: ${difference.inHours}시간');
      }

      return difference > interval;
    } catch (e) {
      if (kDebugMode) {
        print('업데이트 필요 여부 확인 중 오류: $e');
      }
      // 오류가 발생하면 업데이트가 필요하다고 처리
      return true;
    }
  }

  // 업데이트 시간 기록
  Future<void> updateLastUpdateTime(String collectionName) async {
    try {
      await _firestore.collection('updateInfo').doc(collectionName).set({
        'lastUpdate': FieldValue.serverTimestamp(),
        'collectionName': collectionName
      });

      if (kDebugMode) {
        print('$collectionName 업데이트 시간 기록 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('업데이트 시간 기록 중 오류: $e');
      }
    }
  }

  // 초기 로드 시 각 카테고리별 데이터 5개만 가져오기
  Future<List<Map<String, dynamic>>> getInitialBooks(String collectionName) async {
    try {
      final snapshot = await _firestore
          .collection(collectionName)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('초기 $collectionName 데이터 로드 실패: $e');
      }
      return [];
    }
  }

  // 페이지네이션으로 추가 데이터 로드하기
  Future<List<Map<String, dynamic>>> getMoreBooks(
      String collectionName,
      DocumentSnapshot? lastDocument,
      {int pageSize = 10}
      ) async {
    try {
      Query query = _firestore
          .collection(collectionName)
          .orderBy('timestamp', descending: true)
          .limit(pageSize);

      // 마지막 문서가 있으면 해당 문서 이후의 데이터 가져오기
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('추가 $collectionName 데이터 로드 실패: $e');
      }
      return [];
    }
  }

  // 최초 API 호출 시에만 데이터를 전부 저장 (전체 데이터를 유지)
  Future<bool> saveInitialBooks(String collectionName, List<Map<String, dynamic>> books) async {
    try {
      // 해당 컬렉션에 데이터가 있는지 확인
      bool doesHaveData = await hasData(collectionName);

      // 데이터가 없을 때만 저장
      if (!doesHaveData && books.isNotEmpty) {
        final batch = _firestore.batch();

        for (var book in books) {
          String isbn = book['isbn'] ?? '0';
          if (isbn == '0') continue;

          final docRef = _firestore.collection(collectionName).doc(isbn);
          batch.set(docRef, {
            ...book,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
        await updateLastUpdateTime(collectionName);

        if (kDebugMode) {
          print('$collectionName 초기 데이터 저장 완료 (${books.length}개)');
        }
        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('$collectionName 초기 데이터 저장 실패: $e');
      }
      return false;
    }
  }

  // 주기적으로 새 데이터 추가 (기존 데이터는 유지, 새 데이터만 추가)
  Future<int> updateBooks(String collectionName, List<Map<String, dynamic>> books) async {
    try {
      if (books.isEmpty) return 0;

      final batch = _firestore.batch();
      int newBooksCount = 0;

      for (var book in books) {
        String isbn = book['isbn'] ?? '0';
        if (isbn == '0') continue;

        // 해당 도서가 이미 존재하는지 확인
        final docSnapshot = await _firestore.collection(collectionName).doc(isbn).get();

        // 존재하지 않는 경우에만 추가
        if (!docSnapshot.exists) {
          final docRef = _firestore.collection(collectionName).doc(isbn);
          batch.set(docRef, {
            ...book,
            'timestamp': FieldValue.serverTimestamp(),
          });
          newBooksCount++;
        }
      }

      // 새로운 도서가 있을 때만 배치 실행
      if (newBooksCount > 0) {
        await batch.commit();
        await updateLastUpdateTime(collectionName);

        if (kDebugMode) {
          print('$collectionName 데이터 업데이트 완료 (새 도서 $newBooksCount개)');
        }
      }

      return newBooksCount;
    } catch (e) {
      if (kDebugMode) {
        print('$collectionName 데이터 업데이트 실패: $e');
      }
      return 0;
    }
  }

  // 데이터가 있는지 확인
  Future<bool> hasData(String collectionName) async {
    try {
      final snapshot = await _firestore.collection(collectionName).limit(1).get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('$collectionName 데이터 확인 중 오류: $e');
      }
      return false;
    }
  }

  // 스트림으로 데이터 가져오기 - 기존 메서드들
  Stream<QuerySnapshot> getBestsellers() {
    return _firestore.collection('bestsellers')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getNewReleases() {
    return _firestore.collection('newReleases')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getRecommendedBooks() {
    return _firestore.collection('recommendedBooks')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // 도서 상세 정보 가져오기
  Future<Map<String, dynamic>?> getBookDetail(String isbn) async {
    try {
      final docSnapshot = await _firestore.collection('bookDetails').doc(isbn).get();

      if (docSnapshot.exists) {
        if (kDebugMode) {
          print('Firestore에서 도서 상세 정보 로드 성공: $isbn');
        }
        return docSnapshot.data() as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('도서 상세 정보 조회 실패: $e');
      }
      return null;
    }
  }

  // 도서 상세 정보 저장 또는 업데이트
  Future<bool> saveOrUpdateBookDetail(String isbn, Map<String, dynamic> detailData) async {
    try {
      await _firestore.collection('bookDetails').doc(isbn).set({
        ...detailData,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (kDebugMode) {
        print('도서 상세 정보 저장 성공: $isbn');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('도서 상세 정보 저장 실패: $e');
      }
      return false;
    }
  }
}