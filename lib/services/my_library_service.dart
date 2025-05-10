import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class MyLibraryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 책 카테고리 상수
  static const String COMPLETED = 'completed'; // 완독한 도서
  static const String READING = 'reading';     // 읽고 있는 책
  static const String WISHLIST = 'wishlist';   // 읽고 싶은 책

  // 현재 로그인한 사용자 ID 가져오기
  String? get currentUserId => _auth.currentUser?.uid;

  // 사용자가 로그인되어 있는지 확인
  bool get isUserLoggedIn => _auth.currentUser != null;

  // 내 서재에 도서 추가
  Future<bool> addBookToLibrary({
    required Map<String, dynamic> bookData,
    required String category,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // 로그인 확인
      final String? userId = currentUserId;
      if (userId == null) {
        if (kDebugMode) {
          print('로그인이 필요합니다.');
        }
        return false;
      }

      // 카테고리별 추가 정보 설정
      Map<String, dynamic> additionalData = {
        'status': category,
        'addedAt': FieldValue.serverTimestamp(),
      };

      // 읽기 시작일/종료일 추가
      if (startDate != null) {
        additionalData['startDate'] = Timestamp.fromDate(startDate);
      }

      if (endDate != null) {
        additionalData['endDate'] = Timestamp.fromDate(endDate);
      }

      // 완독한 책의 경우 진행률 100%로 설정
      if (category == COMPLETED) {
        additionalData['progress'] = 1.0;
      }
      // 읽고 있는 책의 경우 기본 진행률 설정
      else if (category == READING) {
        additionalData['progress'] = bookData['progress'] ?? 0.0;
      }

      // 도서 정보와 추가 정보를 병합
      final Map<String, dynamic> dataToSave = {
        ...bookData,
        ...additionalData,
      };

      // Firestore에 저장
      // users/{userId}/myLibrary/{category}/books/{isbn}
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('myLibrary')
          .doc(category)
          .collection('books')
          .doc(bookData['isbn'])
          .set(dataToSave);

      if (kDebugMode) {
        print('도서가 내 서재에 추가되었습니다. 카테고리: $category');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('내 서재에 도서 추가 실패: $e');
      }
      return false;
    }
  }

  // 카테고리별 도서 목록 가져오기
  Future<List<Map<String, dynamic>>> getBooksByCategory(String category) async {
    try {
      final String? userId = currentUserId;
      if (userId == null) {
        return [];
      }

      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('myLibrary')
          .doc(category)
          .collection('books')
          .orderBy('addedAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      if (kDebugMode) {
        print('카테고리별 도서 목록 가져오기 실패: $e');
      }
      return [];
    }
  }

  // 전체 내 서재 도서 목록 가져오기
  Future<Map<String, List<Map<String, dynamic>>>> fetchAllMyLibraryBooks() async {
    final result = {
      COMPLETED: <Map<String, dynamic>>[],
      READING: <Map<String, dynamic>>[],
      WISHLIST: <Map<String, dynamic>>[],
    };

    try {
      // 로그인 확인
      if (!isUserLoggedIn) {
        return result;
      }

      // 카테고리별 도서 가져오기 (병렬 처리)
      final futures = await Future.wait([
        getBooksByCategory(COMPLETED),
        getBooksByCategory(READING),
        getBooksByCategory(WISHLIST),
      ]);

      result[COMPLETED] = futures[0];
      result[READING] = futures[1];
      result[WISHLIST] = futures[2];

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('내 서재 데이터 가져오기 실패: $e');
      }
      return result;
    }
  }

  // 내 서재에서 도서 삭제
  Future<bool> removeBookFromLibrary(String isbn, String category) async {
    try {
      final String? userId = currentUserId;
      if (userId == null) {
        return false;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('myLibrary')
          .doc(category)
          .collection('books')
          .doc(isbn)
          .delete();

      if (kDebugMode) {
        print('도서가 내 서재에서 삭제되었습니다.');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('내 서재에서 도서 삭제 실패: $e');
      }
      return false;
    }
  }

  // 도서 카테고리 변경
  Future<bool> moveBookToCategory({
    required String isbn,
    required String fromCategory,
    required String toCategory,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final String? userId = currentUserId;
      if (userId == null) {
        return false;
      }

      // 1. 기존 카테고리에서 도서 정보 가져오기
      final docSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('myLibrary')
          .doc(fromCategory)
          .collection('books')
          .doc(isbn)
          .get();

      if (!docSnapshot.exists) {
        if (kDebugMode) {
          print('해당 도서를 찾을 수 없습니다.');
        }
        return false;
      }

      // 2. 도서 데이터 가져오기
      final bookData = docSnapshot.data()!;

      // 3. 카테고리별 추가 정보 설정
      Map<String, dynamic> additionalData = {
        'status': toCategory,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 읽기 시작일/종료일 추가
      if (startDate != null) {
        additionalData['startDate'] = Timestamp.fromDate(startDate);
      }

      if (endDate != null) {
        additionalData['endDate'] = Timestamp.fromDate(endDate);
      }

      // 완독한 책의 경우 진행률 100%로 설정
      if (toCategory == COMPLETED) {
        additionalData['progress'] = 1.0;
      }
      // 새 카테고리가 읽고 있는 책이고 기존에 진행률이 없다면 기본값 설정
      else if (toCategory == READING && bookData['progress'] == null) {
        additionalData['progress'] = 0.0;
      }

      // 4. 도서 정보와 추가 정보를 병합
      final Map<String, dynamic> dataToSave = {
        ...bookData,
        ...additionalData,
      };

      // 5. 새 카테고리에 도서 추가
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('myLibrary')
          .doc(toCategory)
          .collection('books')
          .doc(isbn)
          .set(dataToSave);

      // 6. 기존 카테고리에서 도서 삭제
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('myLibrary')
          .doc(fromCategory)
          .collection('books')
          .doc(isbn)
          .delete();

      if (kDebugMode) {
        print('도서가 $fromCategory에서 $toCategory으로 이동되었습니다.');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('도서 카테고리 변경 실패: $e');
      }
      return false;
    }
  }

  // 도서 진행률 업데이트
  Future<bool> updateReadingProgress(String isbn, double progress) async {
    try {
      final String? userId = currentUserId;
      if (userId == null) {
        return false;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('myLibrary')
          .doc(READING)
          .collection('books')
          .doc(isbn)
          .update({
        'progress': progress,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('도서 진행률이 업데이트되었습니다: $progress');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('도서 진행률 업데이트 실패: $e');
      }
      return false;
    }
  }

  // 도서가 내 서재에 이미 있는지 확인
  Future<String?> checkBookInLibrary(String isbn) async {
    try {
      final String? userId = currentUserId;
      if (userId == null) {
        return null;
      }

      // 각 카테고리 확인
      for (final category in [COMPLETED, READING, WISHLIST]) {
        final docSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('myLibrary')
            .doc(category)
            .collection('books')
            .doc(isbn)
            .get();

        if (docSnapshot.exists) {
          return category; // 도서가 있는 카테고리 반환
        }
      }

      return null; // 어느 카테고리에도 없음
    } catch (e) {
      if (kDebugMode) {
        print('도서 확인 실패: $e');
      }
      return null;
    }
  }
}