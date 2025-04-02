import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 베스트셀러 저장
  Future<void> saveBestsellers(List<Map<String, dynamic>> books) async {
    try {
      final batch = _firestore.batch();
      final collection = _firestore.collection('bestsellers');

      // 기존 데이터 삭제 - 매번 최신 데이터로 갱신
      await deleteCollection('bestsellers');

      for (var book in books) {
        final docRef = collection.doc(book['isbn']);
        batch.set(docRef, {
          ...book,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      if (kDebugMode) {
        print('베스트셀러 데이터 저장 완료: ${books.length}개');
      }
    } catch (e) {
      if (kDebugMode) {
        print('베스트셀러 데이터 저장 실패: $e');
      }
      throw e;
    }
  }

  // 신작 도서 저장
  Future<void> saveNewReleases(List<Map<String, dynamic>> books) async {
    try {
      final batch = _firestore.batch();
      final collection = _firestore.collection('newReleases');

      // 기존 데이터 삭제
      await deleteCollection('newReleases');

      for (var book in books) {
        final docRef = collection.doc(book['isbn']);
        batch.set(docRef, {
          ...book,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      if (kDebugMode) {
        print('신작 도서 데이터 저장 완료: ${books.length}개');
      }
    } catch (e) {
      if (kDebugMode) {
        print('신작 도서 데이터 저장 실패: $e');
      }
      throw e;
    }
  }

  // 추천 도서 저장 (편집자 선정)
  Future<void> saveRecommendedBooks(List<Map<String, dynamic>> books) async {
    try {
      final batch = _firestore.batch();
      final collection = _firestore.collection('recommendedBooks');

      // 기존 데이터 삭제
      await deleteCollection('recommendedBooks');

      for (var book in books) {
        final docRef = collection.doc(book['isbn']);
        batch.set(docRef, {
          ...book,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      if (kDebugMode) {
        print('추천 도서 데이터 저장 완료: ${books.length}개');
      }
    } catch (e) {
      if (kDebugMode) {
        print('추천 도서 데이터 저장 실패: $e');
      }
      throw e;
    }
  }

  // 기본 도서 정보 저장 (중복 방지를 위한 통합 정보)
  Future<void> addBook(Map<String, dynamic> book) async {
    try {
      await _firestore.collection('books').doc(book['isbn']).set({
        ...book,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        print('도서 정보 저장 실패: $e');
      }
      throw e;
    }
  }

  // 도서 정보 가져오기 (베스트셀러)
  Stream<QuerySnapshot> getBestsellers() {
    return _firestore.collection('bestsellers')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // 도서 정보 가져오기 (신작 도서)
  Stream<QuerySnapshot> getNewReleases() {
    return _firestore.collection('newReleases')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // 도서 정보 가져오기 (추천 도서)
  Stream<QuerySnapshot> getRecommendedBooks() {
    return _firestore.collection('recommendedBooks')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // 컬렉션 데이터 삭제 (전체 갱신 시 사용)
  Future<void> deleteCollection(String collectionPath) async {
    try {
      final collection = await _firestore.collection(collectionPath).get();

      if (collection.docs.isEmpty) {
        if (kDebugMode) {
          print('삭제할 $collectionPath 데이터가 없습니다.');
        }
        return;
      }

      final batch = _firestore.batch();
      for (var doc in collection.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      if (kDebugMode) {
        print('$collectionPath 컬렉션 데이터 삭제 완료: ${collection.docs.length}개');
      }
    } catch (e) {
      if (kDebugMode) {
        print('$collectionPath 컬렉션 데이터 삭제 실패: $e');
      }
      throw e;
    }
  }
}