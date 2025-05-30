import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AladinApiException implements Exception {
  final String message;
  final int? statusCode;

  AladinApiException(this.message, {this.statusCode});

  @override
  String toString() => 'AladinApiException: $message${statusCode != null ? ' (Status code: $statusCode)' : ''}';
}

class AladinService {
  final String _baseUrl = 'https://www.aladin.co.kr/ttb/api/ItemList.aspx';
  final String _apiKey = 'ttbraanggo0946001'; // 추후 환경 변수나 설정 파일로 분리 권장

  // 최대 재시도 횟수
  final int _maxRetries = 3;

  // 캐시 만료 기간 (7일)
  final Duration cacheDuration = const Duration(days: 7);

  // 내부 메모리 캐시 (선택 사항: 추가 최적화용)
  final Map<String, _CachedResponse> _cache = {};

  // 인터넷 연결 확인
  Future<bool> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // API 호출 공통 메서드 (재시도 로직 포함)
  Future<List<Map<String, dynamic>>> _fetchBooks({
    required String queryType,
    int maxResults = 20,
    int retryCount = 0,
    bool useCache = true,
  }) async {
    // 캐시 키 생성
    final cacheKey = '${queryType}_${maxResults}';

    // 캐시된 결과가 있고 유효한지 확인
    if (useCache && _cache.containsKey(cacheKey)) {
      final cachedData = _cache[cacheKey]!;
      final now = DateTime.now();
      if (now.difference(cachedData.timestamp) < cacheDuration) {
        if (kDebugMode) {
          print('캐시에서 $queryType 데이터 사용 (${cachedData.data.length}개)');
        }
        return cachedData.data;
      }
    }

    // 인터넷 연결 확인
    if (!await _checkConnectivity()) {
      if (kDebugMode) {
        print('인터넷 연결이 없습니다.');
      }
      throw AladinApiException('인터넷 연결이 없습니다.');
    }

    try {
      // OptResult=packing 파라미터 추가
      final url = Uri.parse(
          '$_baseUrl?ttbkey=$_apiKey&QueryType=$queryType&MaxResults=$maxResults&start=1&SearchTarget=Book&output=js&Version=20131101&OptResult=packing'
      );

      if (kDebugMode) {
        print('API 호출: $url');
      }

      final response = await http.get(url)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        // 응답 데이터 검증
        final dynamic data;
        try {
          data = jsonDecode(response.body);
        } catch (e) {
          throw AladinApiException('JSON 파싱 오류: $e');
        }

        if (data == null) {
          throw AladinApiException('응답 데이터가 null입니다.');
        }

        if (data['errorCode'] != null) {
          throw AladinApiException('API 오류: ${data['errorMessage'] ?? data['errorCode']}');
        }

        if (data['item'] == null) {
          if (kDebugMode) {
            print('API 응답에 item 필드가 없습니다: ${response.body}');
          }
          return [];
        }

        final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(data['item']);
        if (kDebugMode) {
          print('API 응답 성공: ${items.length}개 도서 데이터 수신');
          // 응답 구조 확인을 위한 로깅 추가
          if (items.isNotEmpty) {
            print('첫 번째 도서 데이터 샘플:');
            print(json.encode(items.first));
          }
        }

        // 결과를 캐시에 저장
        _cache[cacheKey] = _CachedResponse(
          data: items,
          timestamp: DateTime.now(),
        );

        return items;
      } else {
        if (kDebugMode) {
          print('API 응답 오류: ${response.statusCode}');
          print('응답 내용: ${response.body}');
        }

        // 서버 오류인 경우 재시도
        if (response.statusCode >= 500 && retryCount < _maxRetries) {
          if (kDebugMode) {
            print('서버 오류로 인한 재시도 ${retryCount + 1}/$_maxRetries');
          }

          // 지수 백오프 (재시도 간격을 점차 늘림)
          await Future.delayed(Duration(seconds: 2 * (retryCount + 1)));
          return _fetchBooks(
            queryType: queryType,
            maxResults: maxResults,
            retryCount: retryCount + 1,
            useCache: false, // 재시도할 때는 캐시 사용 안 함
          );
        }

        throw AladinApiException('API 응답 오류', statusCode: response.statusCode);
      }
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        print('API 호출 타임아웃: $e');
      }

      // 타임아웃 시 재시도
      if (retryCount < _maxRetries) {
        if (kDebugMode) {
          print('타임아웃으로 인한 재시도 ${retryCount + 1}/$_maxRetries');
        }

        await Future.delayed(Duration(seconds: 2 * (retryCount + 1)));
        return _fetchBooks(
          queryType: queryType,
          maxResults: maxResults,
          retryCount: retryCount + 1,
          useCache: false,
        );
      }

      throw AladinApiException('API 호출 타임아웃');
    } catch (e) {
      if (kDebugMode) {
        print('API 호출 중 예외 발생: $e');
      }

      // 기타 예외 시 재시도
      if (retryCount < _maxRetries) {
        if (kDebugMode) {
          print('예외로 인한 재시도 ${retryCount + 1}/$_maxRetries');
        }

        await Future.delayed(Duration(seconds: 2 * (retryCount + 1)));
        return _fetchBooks(
          queryType: queryType,
          maxResults: maxResults,
          retryCount: retryCount + 1,
          useCache: false,
        );
      }

      throw AladinApiException('API 호출 중 예외 발생: $e');
    }
  }

  // 베스트셀러 가져오기
  Future<List<Map<String, dynamic>>> fetchBestsellers({int maxResults = 20}) async {
    return _fetchBooks(queryType: 'Bestseller', maxResults: maxResults);
  }

  // 신작 도서 가져오기
  Future<List<Map<String, dynamic>>> fetchNewReleases({int maxResults = 20}) async {
    return _fetchBooks(queryType: 'ItemNewAll', maxResults: maxResults);
  }

  Future<List<Map<String, dynamic>>> fetchRecommendedBooks({int maxResults = 20}) async {
    // ItemNewSpecial: 주목할 만한 신간 도서 (알라딘 API에서 지원하는 쿼리타입)
    return _fetchBooks(queryType: 'ItemNewSpecial', maxResults: maxResults);
  }

  // 책 정보를 Firebase에 저장하기 좋은 형태로 변환
  Map<String, dynamic> transformBookData(Map<String, dynamic> bookData) {
    // 페이지 수 파싱 함수
    int parseItemPage(dynamic page) {
      if (page == null) return 0;
      if (page is int) return page;
      if (page is String) {
        try {
          return int.parse(page);
        } catch (_) {
          return 0;
        }
      }
      return 0;
    }

    // 페이지 수 추출 - API 문서에 따르면 subInfo.itemPage에 위치
    int itemPage = 0;
    if (bookData['subInfo'] != null && bookData['subInfo']['itemPage'] != null) {
      itemPage = parseItemPage(bookData['subInfo']['itemPage']);
      if (kDebugMode) {
        print('subInfo에서 페이지 수 찾음: $itemPage');
      }
    } else {
      // 디버깅용 로그
      if (kDebugMode) {
        print('subInfo 또는 itemPage가 없음: ${bookData.keys.join(', ')}');
        if (bookData['subInfo'] != null) {
          print('subInfo 키: ${bookData['subInfo'].keys.join(', ')}');
        }
      }
    }

    // 도서 데이터 변환 및 반환
    return {
      'isbn': bookData['isbn13'] ?? bookData['isbn'] ?? '0',
      'title': bookData['title'] ?? '',
      'author': bookData['author'] ?? '',
      'publisher': bookData['publisher'] ?? '',
      'pubDate': bookData['pubDate'] ?? '',
      'coverUrl': bookData['cover'] ?? '',
      'description': bookData['description'] ?? '',
      'categoryName': bookData['categoryName'] ?? '',
      'link': bookData['link'] ?? '',
      'itemPage': itemPage,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  // 캐시 비우기
  void clearCache() {
    _cache.clear();
  }

  // 도서 상세 정보 조회 (ISBN 검색)
  Future<Map<String, dynamic>?> fetchBookDetail(String isbn) async {
    if (isbn.isEmpty || isbn == '0') return null;

    try {
      final url = Uri.parse(
          'https://www.aladin.co.kr/ttb/api/ItemLookUp.aspx?ttbkey=$_apiKey&itemIdType=ISBN&ItemId=$isbn&output=js&Version=20131101&OptResult=packing'
      );

      if (kDebugMode) {
        print('도서 상세 정보 API 호출: $url');
      }

      final response = await http.get(url)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['item'] != null && data['item'].isNotEmpty) {
          if (kDebugMode) {
            print('도서 상세 정보 로드 성공: ${data['item'][0]['title']}');

            // 디버깅을 위한 응답 구조 출력
            print('도서 상세 응답 구조:');
            print(json.encode(data['item'][0]));

            // subInfo 구조 확인
            if (data['item'][0]['subInfo'] != null) {
              print('subInfo 구조:');
              print(json.encode(data['item'][0]['subInfo']));
            }
          }
          return transformBookData(data['item'][0]);
        }
      } else {
        if (kDebugMode) {
          print('도서 상세 정보 API 오류: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('도서 상세 정보 조회 실패: $e');
      }
    }

    return null;
  }
}

// 캐시된 응답을 저장하기 위한 내부 클래스
class _CachedResponse {
  final List<Map<String, dynamic>> data;
  final DateTime timestamp;

  _CachedResponse({required this.data, required this.timestamp});
}