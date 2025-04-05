import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'aladin_service.dart';
import 'firestore_service.dart';

class BookDataService {
  final AladinService _aladinService = AladinService();
  final FirestoreService _firestoreService = FirestoreService();

  // 데이터 로딩 중 상태를 추적하기 위한 플래그
  bool _isUpdating = false;

  // 첫 로드 시 각 카테고리별 5개 도서 가져오기
  Future<Map<String, List<Map<String, dynamic>>>> getInitialData() async {
    try {
      if (_isUpdating) {
        // 이미 업데이트 중이면 대기
        if (kDebugMode) {
          print('이미 데이터 업데이트 중입니다. 대기 중...');
        }
        await Future.delayed(const Duration(seconds: 2));
      }

      final Map<String, List<Map<String, dynamic>>> result = {
        'bestsellers': [],
        'newReleases': [],
        'recommendedBooks': []
      };

      // 각 카테고리별 데이터 로드 - Firestore 데이터 접근을 최소화하기 위해 동시 실행
      List<Future> loadFutures = [
        _loadCategoryData('bestsellers', result),
        _loadCategoryData('newReleases', result),
        _loadCategoryData('recommendedBooks', result),
      ];

      await Future.wait(loadFutures);

      // 데이터가 하나라도 비어있으면 데이터 업데이트
      if (result['bestsellers']!.isEmpty ||
          result['newReleases']!.isEmpty ||
          result['recommendedBooks']!.isEmpty) {

        // 백그라운드로 데이터 업데이트 시작 - UI 차단하지 않기 위해 unawaited 처리
        _updateBookDataInBackground();

        // 현재 존재하는 데이터라도 우선 반환
        if (kDebugMode) {
          print('일부 데이터가 비어 있습니다. 백그라운드에서 업데이트를 시작합니다.');
        }
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('초기 데이터 로드 실패: $e');
      }

      // 실패해도 빈 데이터라도 반환
      return {
        'bestsellers': [],
        'newReleases': [],
        'recommendedBooks': []
      };
    }
  }

  // 카테고리 데이터 로드 헬퍼 함수
  Future<void> _loadCategoryData(String category, Map<String, List<Map<String, dynamic>>> result) async {
    try {
      result[category] = await _firestoreService.getInitialBooks(category);
    } catch (e) {
      if (kDebugMode) {
        print('$category 초기 데이터 로드 실패: $e');
      }
      result[category] = [];
    }
  }

  // 백그라운드에서 데이터 업데이트 진행
  Future<void> _updateBookDataInBackground() async {
    if (_isUpdating) return; // 이미 업데이트 중이면 중복 실행 방지

    _isUpdating = true;

    try {
      await updateBookData();
    } catch (e) {
      if (kDebugMode) {
        print('백그라운드 데이터 업데이트 실패: $e');
      }
    } finally {
      _isUpdating = false;
    }
  }

  // 특정 카테고리의 추가 도서 로드 (페이지네이션)
  Future<List<Map<String, dynamic>>> loadMoreBooks(
      String category,
      DocumentSnapshot? lastDocument,
      {int pageSize = 10}
      ) async {
    try {
      return await _firestoreService.getMoreBooks(category, lastDocument, pageSize: pageSize);
    } catch (e) {
      if (kDebugMode) {
        print('추가 $category 데이터 로드 실패: $e');
      }
      return [];
    }
  }

  // 베스트셀러와 신작 도서 데이터 업데이트
  Future<void> updateBookData() async {
    try {
      if (kDebugMode) {
        print('도서 데이터 업데이트 시작...');
      }

      // 각 컬렉션의 업데이트 필요 여부 확인 - 동시 실행으로 성능 향상
      final needUpdateFutures = await Future.wait([
        _firestoreService.needsUpdate('bestsellers', updateInterval: const Duration(days: 1)),
        _firestoreService.needsUpdate('newReleases', updateInterval: const Duration(days: 1)),
        _firestoreService.needsUpdate('recommendedBooks', updateInterval: const Duration(days: 1))
      ]);

      final needBestsellerUpdate = needUpdateFutures[0];
      final needNewReleasesUpdate = needUpdateFutures[1];
      final needRecommendedUpdate = needUpdateFutures[2];

      // 병렬 처리를 위한 Future 목록
      List<Future> updateFutures = [];

      // 베스트셀러 업데이트 코드
      if (needBestsellerUpdate) {
        updateFutures.add(_updateCategoryData('bestsellers', () => _aladinService.fetchBestsellers(maxResults: 30)));
      } else {
        if (kDebugMode) {
          print('베스트셀러 데이터가 최신 상태입니다. API 호출 건너뜁니다.');
        }
      }

      // 신작 도서 업데이트 코드
      if (needNewReleasesUpdate) {
        updateFutures.add(_updateCategoryData('newReleases', () => _aladinService.fetchNewReleases(maxResults: 30)));
      } else {
        if (kDebugMode) {
          print('신작 도서 데이터가 최신 상태입니다. API 호출 건너뜁니다.');
        }
      }

      // 추천 도서 업데이트 코드
      if (needRecommendedUpdate) {
        updateFutures.add(_updateCategoryWithRetry('recommendedBooks'));
      } else {
        if (kDebugMode) {
          print('추천 도서 데이터가 최신 상태입니다. API 호출 건너뜁니다.');
        }
      }

      // 모든 업데이트 작업 병렬 처리로 대기
      if (updateFutures.isNotEmpty) {
        await Future.wait(updateFutures);
      }

      if (kDebugMode) {
        print('모든 도서 데이터 업데이트 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('도서 데이터 업데이트 실패: $e');
      }
      // 오류 전파는 하지만 앱 종료는 방지
    }
  }

  // 추천 도서에 대한 특별 처리 함수 (추가 오류 처리)
  Future<void> _updateCategoryWithRetry(String category) async {
    try {
      await _updateCategoryData(category, () => _aladinService.fetchRecommendedBooks(maxResults: 30));
    } catch (e) {
      if (kDebugMode) {
        print('$category 첫 번째 시도 실패, 대체 API 사용: $e');
      }

      // ItemNewSpecial이 실패하면 ItemNewAll로 대체 시도
      try {
        await _updateCategoryData(category, () => _aladinService.fetchNewReleases(maxResults: 30));
        if (kDebugMode) {
          print('$category 대체 API 호출 성공');
        }
      } catch (e) {
        if (kDebugMode) {
          print('$category 대체 API도 실패: $e');
        }
        rethrow;
      }
    }
  }

  // 카테고리별 데이터 업데이트 헬퍼 함수
  Future<void> _updateCategoryData(String category, Future<List<Map<String, dynamic>>> Function() fetchFunction) async {
    try {
      final books = await fetchFunction();
      if (books.isNotEmpty) {
        final transformedBooks = books.map(_aladinService.transformBookData).toList();

        bool hasData = await _firestoreService.hasData(category);
        if (!hasData) {
          await _firestoreService.saveInitialBooks(category, transformedBooks);
          if (kDebugMode) {
            print('$category 초기 데이터 저장 완료 (${transformedBooks.length}개)');
          }
        } else {
          int newCount = await _firestoreService.updateBooks(category, transformedBooks);
          if (kDebugMode) {
            print('$category 데이터 업데이트 완료 (새 도서 $newCount개)');
          }
        }
      } else {
        if (kDebugMode) {
          print('$category 데이터가 비어 있어 저장하지 않음');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('$category 데이터 업데이트 실패: $e');
      }
      throw e; // 상위 함수에서 처리할 수 있도록 오류 전파
    }
  }
}