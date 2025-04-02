import 'package:flutter/foundation.dart';
import 'aladin_service.dart';
import 'firestore_service.dart';

class BookDataService {
  final AladinService _aladinService = AladinService();
  final FirestoreService _firestoreService = FirestoreService();

  // 베스트셀러와 신작 도서 데이터 업데이트
  Future<void> updateBookData() async {
    try {
      if (kDebugMode) {
        print('도서 데이터 업데이트 시작...');
      }

      // 베스트셀러 가져오기
      final bestsellers = await _aladinService.fetchBestsellers();
      if (bestsellers.isNotEmpty) {
        final transformedBestsellers = bestsellers
            .map(_aladinService.transformBookData)
            .toList();
        await _firestoreService.saveBestsellers(transformedBestsellers);
        if (kDebugMode) {
          print('베스트셀러 데이터 저장 완료 (${bestsellers.length}개)');
        }
      } else {
        if (kDebugMode) {
          print('베스트셀러 데이터가 비어 있어 저장하지 않음');
        }
      }

      // 신작 도서 가져오기
      final newReleases = await _aladinService.fetchNewReleases();
      if (newReleases.isNotEmpty) {
        final transformedNewReleases = newReleases
            .map(_aladinService.transformBookData)
            .toList();
        await _firestoreService.saveNewReleases(transformedNewReleases);
        if (kDebugMode) {
          print('신작 도서 데이터 저장 완료 (${newReleases.length}개)');
        }
      } else {
        if (kDebugMode) {
          print('신작 도서 데이터가 비어 있어 저장하지 않음');
        }
      }

      // 추천 도서 가져오기
      final recommendedBooks = await _aladinService.fetchRecommendedBooks();
      if (recommendedBooks.isNotEmpty) {
        final transformedRecommendedBooks = recommendedBooks
            .map(_aladinService.transformBookData)
            .toList();
        await _firestoreService.saveRecommendedBooks(transformedRecommendedBooks);
        if (kDebugMode) {
          print('추천 도서 데이터 저장 완료 (${recommendedBooks.length}개)');
        }
      } else {
        if (kDebugMode) {
          print('추천 도서 데이터가 비어 있어 저장하지 않음');
        }
      }

      if (kDebugMode) {
        print('모든 도서 데이터 업데이트 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('도서 데이터 업데이트 실패: $e');
      }
      throw e;
    }
  }
}