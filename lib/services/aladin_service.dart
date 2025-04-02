import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class AladinService {
  final String _baseUrl = 'http://www.aladin.co.kr/ttb/api/ItemList.aspx';
  final String _apiKey = 'ttbraanggo0946001'; // API 키를 직접 입력

  // 베스트셀러 가져오기
  Future<List<Map<String, dynamic>>> fetchBestsellers({int maxResults = 20}) async {
    try {
      final response = await http.get(Uri.parse(
          '$_baseUrl?ttbkey=$_apiKey&QueryType=Bestseller&MaxResults=$maxResults&start=1&SearchTarget=Book&output=js&Version=20131101'
      )).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data == null || data['item'] == null) {
          if (kDebugMode) {
            print('베스트셀러 API 응답에 item 필드가 없습니다: ${response.body}');
          }
          return [];
        }

        if (kDebugMode) {
          print('베스트셀러 API 응답 성공: ${data['item'].length}개 도서 데이터 수신');
        }
        return List<Map<String, dynamic>>.from(data['item']);
      } else {
        if (kDebugMode) {
          print('베스트셀러 API 응답 오류: ${response.statusCode}');
          print('응답 내용: ${response.body}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('베스트셀러 API 호출 중 예외 발생: $e');
      }
      return [];
    }
  }

  // 신작 도서 가져오기
  Future<List<Map<String, dynamic>>> fetchNewReleases({int maxResults = 20}) async {
    try {
      final response = await http.get(Uri.parse(
          '$_baseUrl?ttbkey=$_apiKey&QueryType=ItemNewAll&MaxResults=$maxResults&start=1&SearchTarget=Book&output=js&Version=20131101'
      )).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data == null || data['item'] == null) {
          if (kDebugMode) {
            print('신작 도서 API 응답에 item 필드가 없습니다: ${response.body}');
          }
          return [];
        }

        if (kDebugMode) {
          print('신작 도서 API 응답 성공: ${data['item'].length}개 도서 데이터 수신');
        }
        return List<Map<String, dynamic>>.from(data['item']);
      } else {
        if (kDebugMode) {
          print('신작 도서 API 응답 오류: ${response.statusCode}');
          print('응답 내용: ${response.body}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('신작 도서 API 호출 중 예외 발생: $e');
      }
      return [];
    }
  }

  // 추천 도서 가져오기 (편집자 선정)
  Future<List<Map<String, dynamic>>> fetchRecommendedBooks({int maxResults = 20}) async {
    try {
      final response = await http.get(Uri.parse(
          '$_baseUrl?ttbkey=$_apiKey&QueryType=ItemEditorChoice&MaxResults=$maxResults&start=1&SearchTarget=Book&output=js&Version=20131101'
      )).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data == null || data['item'] == null) {
          if (kDebugMode) {
            print('추천 도서 API 응답에 item 필드가 없습니다: ${response.body}');
          }
          return [];
        }

        if (kDebugMode) {
          print('추천 도서 API 응답 성공: ${data['item'].length}개 도서 데이터 수신');
        }
        return List<Map<String, dynamic>>.from(data['item']);
      } else {
        if (kDebugMode) {
          print('추천 도서 API 응답 오류: ${response.statusCode}');
          print('응답 내용: ${response.body}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('추천 도서 API 호출 중 예외 발생: $e');
      }
      return [];
    }
  }

  // 책 정보를 Firebase에 저장하기 좋은 형태로 변환
  Map<String, dynamic> transformBookData(Map<String, dynamic> bookData) {
    return {
      'isbn': bookData['isbn13'] ?? bookData['isbn'] ?? '',
      'title': bookData['title'] ?? '',
      'author': bookData['author'] ?? '',
      'publisher': bookData['publisher'] ?? '',
      'pubDate': bookData['pubDate'] ?? '',
      'coverUrl': bookData['cover'] ?? '',
      'description': bookData['description'] ?? '',
      'priceStandard': bookData['priceStandard'] ?? 0,
      'priceSales': bookData['priceSales'] ?? 0,
      'categoryName': bookData['categoryName'] ?? '',
      'link': bookData['link'] ?? '',
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }
}