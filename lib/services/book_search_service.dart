import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../services/aladin_service.dart';

class BookSearchService {
  final AladinService _aladinService = AladinService();
  final String _baseUrl = 'https://www.aladin.co.kr/ttb/api/ItemSearch.aspx';
  final String _apiKey = 'ttbraanggo0946001';

  // 내부 메모리 캐시 (최적화용)
  final Map<String, List<Map<String, dynamic>>> _searchCache = {};
  // 캐시 만료 시간 (1시간)
  final Duration _cacheDuration = const Duration(hours: 1);

  // 통합 검색 메서드 (제목 또는 저자 통합)
  Future<List<Map<String, dynamic>>> searchBooks(String query) async {
    //두글자 이상 검색으로 수정
    if (query.trim().length <2) {
      return [];
    }

    // 캐시 키 설정
    final cacheKey = query.toLowerCase().trim();

    // 캐시에 결과가 있는지 확인
    if (_searchCache.containsKey(cacheKey)) {
      final cachedData = _searchCache[cacheKey]!;
      final now = DateTime.now();

      // 캐시가 유효한지 확인
      if (cachedData.isNotEmpty) {
        final cachedAt = cachedData.first['_cachedAt'];
        if (cachedAt != null) {
          final cachedTime = now.difference(cachedAt as DateTime);
          if (cachedTime < _cacheDuration) {
            if (kDebugMode) {
              print('캐시에서 검색 결과 사용: $cacheKey');
            }

            // 캐시 시간 정보 제거 후 반환
            return cachedData.map((item) {
              final Map<String, dynamic> result = Map.from(item);
              result.remove('_cachedAt');
              return result;
            }).toList();
          }
        }
      }
    }

    try {
      // 알라딘 API Keyword 검색 URL 생성 (제목, 저자 등 모든 필드 대상 검색)
      final searchUrl = Uri.parse(
          '$_baseUrl?ttbkey=$_apiKey&Query=$query&QueryType=Keyword&MaxResults=20&start=1&SearchTarget=Book&output=js&Version=20131101'
      );

      if (kDebugMode) {
        print('통합 도서 검색 API 호출: $searchUrl');
      }

      // API 요청
      final response = await http.get(searchUrl)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // JSON 파싱
        final data = jsonDecode(response.body);

        // 검색 결과가 없는 경우
        if (data['item'] == null || data['item'].isEmpty) {
          return [];
        }

        // 검색 결과 매핑
        final results = List<Map<String, dynamic>>.from(data['item']);

        // 도서 데이터 변환
        final transformedResults = results.map((item) {
          final transformed = _aladinService.transformBookData(item);

          // 캐시 시간 추가
          transformed['_cachedAt'] = DateTime.now();

          return transformed;
        }).toList();

        // 결과 캐싱
        _searchCache[cacheKey] = transformedResults;

        // 캐시 시간 정보 제거 후 반환
        return transformedResults.map((item) {
          final Map<String, dynamic> result = Map.from(item);
          result.remove('_cachedAt');
          return result;
        }).toList();
      } else {
        if (kDebugMode) {
          print('API 응답 오류: ${response.statusCode}');
          print('오류 내용: ${response.body}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('도서 검색 중 오류 발생: $e');
      }
      return [];
    }
  }

  // 캐시 삭제
  void clearCache() {
    _searchCache.clear();
    if (kDebugMode) {
      print('검색 캐시 삭제 완료');
    }
  }
}