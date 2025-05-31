import 'dart:convert';
import 'dart:math' as math;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RecommendationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final GenerativeModel _geminiModel;

  static const String _geminiModelName = 'gemini-2.0-flash';

  static String get _aladinApiKey {
    final key = dotenv.env['ALADIN_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('ALADIN_API_KEY가 환경변수에 설정되지 않았습니다');
    }
    return key;
  }

  static const String _personalizedCacheCollection = 'personalizedRecommendations';
  static const String _weeklyRecommendationCollection = 'weeklyRecommendations';
  static const String _personalizedType = 'AI_PERSONALIZED';
  static const String _weeklyType = 'AI_WEEKLY';

  // 중복 방지용 단순 Set
  final Set<String> _processedBooks = {};

  RecommendationService({String? geminiApiKey}) {
    final apiKey = geminiApiKey ?? dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY가 설정되지 않았습니다');
    }

    _geminiModel = GenerativeModel(
      model: _geminiModelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        maxOutputTokens: 1200,
        temperature: 0.7,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> getRecommendations() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return await getWeeklyRecommendations();
      }

      final userId = user.uid;
      final hasLibraryBooks = await _hasUserBooks(userId);

      if (hasLibraryBooks) {
        final personalizedRecommendations = await getPersonalizedRecommendations(userId: userId);
        if (personalizedRecommendations.isNotEmpty) {
          return personalizedRecommendations;
        }
      }

      return await getWeeklyRecommendations();
    } catch (e) {
      return await getWeeklyRecommendations();
    }
  }

  Stream<List<Map<String, dynamic>>> getRecommendationsStream() async* {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        yield* getWeeklyRecommendationsStream();
        return;
      }

      final userId = user.uid;
      final hasLibraryBooks = await _hasUserBooks(userId);

      if (hasLibraryBooks) {
        yield* getPersonalizedRecommendationsStream(userId: userId);
      } else {
        yield* getWeeklyRecommendationsStream();
      }
    } catch (e) {
      yield* getWeeklyRecommendationsStream();
    }
  }

  Stream<List<Map<String, dynamic>>> getPersonalizedRecommendationsStream({String? userId}) async* {
    try {
      final targetUserId = userId ?? _auth.currentUser?.uid;
      if (targetUserId == null) return;

      // 캐시된 데이터 확인
      final cachedRecommendations = await _getCachedPersonalizedRecommendations(targetUserId);
      if (cachedRecommendations.isNotEmpty) {
        yield cachedRecommendations;
        return;
      }

      // 새로운 추천 생성
      final userBooks = await _getUserBooks(targetUserId);
      if (userBooks.isEmpty) return;

      final userProfile = await _analyzeUserProfile(userBooks);
      if (userProfile['topGenres'].isEmpty && userProfile['topAuthors'].isEmpty) {
        return;
      }

      final geminiBooks = await _generateGeminiRecommendations(userProfile, true);
      if (geminiBooks.isEmpty) return;

      yield* _enrichWithAladinDataStream(geminiBooks, _personalizedType, targetUserId);
    } catch (e) {
      // 오류 발생 시 빈 스트림 반환
    }
  }

  Stream<List<Map<String, dynamic>>> getWeeklyRecommendationsStream() async* {
    try {
      // 캐시된 데이터 확인
      final cachedRecommendations = await _getCachedWeeklyRecommendations();
      if (cachedRecommendations.isNotEmpty) {
        yield cachedRecommendations;
        return;
      }

      // 새로운 추천 생성
      final geminiBooks = await _generateGeminiRecommendations({}, false);
      if (geminiBooks.isEmpty) return;

      yield* _enrichWithAladinDataStream(geminiBooks, _weeklyType, null);
    } catch (e) {
      // 오류 발생 시 빈 스트림 반환
    }
  }

  // 고성능 병렬 처리 (5권씩, 빠른 처리)
  Stream<List<Map<String, dynamic>>> _enrichWithAladinDataStream(
      List<Map<String, dynamic>> geminiBooks,
      String recommendationType,
      String? userId) async* {

    final List<Map<String, dynamic>> completedBooks = [];
    final Set<String> userBookTitles = userId != null
        ? (await _getUserBooks(userId)).map((book) =>
        _normalizeTitle(book['title']?.toString() ?? '')).toSet()
        : <String>{};

    const batchSize = 5; // 5권씩 병렬 처리로 증가

    for (int i = 0; i < geminiBooks.length; i += batchSize) {
      final endIndex = math.min(i + batchSize, geminiBooks.length);
      final batch = geminiBooks.sublist(i, endIndex);

      // 배치 내에서 병렬 처리
      final futures = batch.map((geminiBook) async {
        try {
          final bookTitle = _normalizeTitle(geminiBook['title']?.toString() ?? '');
          final uniqueId = _generateUniqueBookId(geminiBook);

          // 중복 검사
          if (_processedBooks.contains(uniqueId) || userBookTitles.contains(bookTitle)) {
            return null;
          }

          final enrichedBook = await _processSingleBook(geminiBook, recommendationType)
              .timeout(const Duration(seconds: 5)); // 타임아웃 단축 (8초 → 5초)

          if (enrichedBook != null) {
            _processedBooks.add(uniqueId);
            return enrichedBook;
          }
          return null;
        } catch (e) {
          return null;
        }
      });

      // 배치 완료까지 대기
      final batchResults = await Future.wait(futures, eagerError: false);

      // null이 아닌 결과만 추가
      final validBooks = batchResults.where((book) => book != null).cast<Map<String, dynamic>>().toList();

      if (validBooks.isNotEmpty) {
        completedBooks.addAll(validBooks);
        yield List<Map<String, dynamic>>.from(completedBooks);
      }

      // 배치 간 대기 시간 단축 (300ms → 100ms)
      if (endIndex < geminiBooks.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    // 캐시 저장
    if (completedBooks.isNotEmpty) {
      if (recommendationType == _personalizedType && userId != null) {
        await _cachePersonalizedRecommendations(userId, completedBooks);
      } else if (recommendationType == _weeklyType) {
        await _cacheWeeklyRecommendations(completedBooks);
      }
    }
  }

  Future<Map<String, dynamic>?> _processSingleBook(
      Map<String, dynamic> geminiBook, String recommendationType) async {
    try {
      final title = geminiBook['title']?.toString().trim() ?? '';

      if (title.isEmpty) return null;

      // Aladin에서 도서 정보 검색 (제목만 검색)
      final aladinBook = await _searchBookByTitle(title);

      if (aladinBook != null) {
        return _createCompleteBookData(aladinBook, geminiBook, recommendationType);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  String _normalizeTitle(String title) {
    return title.toLowerCase()
        .replaceAll(RegExp(r'[^\w가-힣]'), '')
        .replaceAll(RegExp(r'\s+'), '');
  }

  String _generateUniqueBookId(Map<String, dynamic> book) {
    final isbn = book['isbn']?.toString().trim();
    if (isbn != null && isbn.isNotEmpty) {
      return 'isbn_$isbn';
    }

    final title = _normalizeTitle(book['title']?.toString() ?? '');
    return 'title_${title.hashCode.abs()}';
  }

  // 기존 메서드들 (호환성 유지)
  Future<List<Map<String, dynamic>>> getPersonalizedRecommendations({String? userId}) async {
    try {
      final targetUserId = userId ?? _auth.currentUser?.uid;
      if (targetUserId == null) throw Exception('사용자 ID가 없습니다');

      final cachedRecommendations = await _getCachedPersonalizedRecommendations(targetUserId);
      if (cachedRecommendations.isNotEmpty) {
        return cachedRecommendations;
      }

      final userBooks = await _getUserBooks(targetUserId);
      final userProfile = await _analyzeUserProfile(userBooks);

      if (userProfile['topGenres'].isEmpty && userProfile['topAuthors'].isEmpty) {
        return [];
      }

      final geminiBooks = await _generateGeminiRecommendations(userProfile, true);
      if (geminiBooks.isEmpty) return [];

      return await _enrichWithAladinData(geminiBooks, _personalizedType);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getWeeklyRecommendations() async {
    try {
      final cachedRecommendations = await _getCachedWeeklyRecommendations();
      if (cachedRecommendations.isNotEmpty) {
        return cachedRecommendations;
      }

      final geminiBooks = await _generateGeminiRecommendations({}, false);
      if (geminiBooks.isEmpty) return [];

      return await _enrichWithAladinData(geminiBooks, _weeklyType);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _enrichWithAladinData(
      List<Map<String, dynamic>> geminiBooks, String recommendationType) async {
    final enrichedBooks = <Map<String, dynamic>>[];
    const batchSize = 5; // 5권씩으로 증가

    for (int i = 0; i < geminiBooks.length; i += batchSize) {
      final endIndex = math.min(i + batchSize, geminiBooks.length);
      final batch = geminiBooks.sublist(i, endIndex);

      // 배치 병렬 처리
      final futures = batch.map((book) => _processSingleBook(book, recommendationType)
          .timeout(const Duration(seconds: 5))); // 타임아웃 단축

      final results = await Future.wait(futures, eagerError: false);

      for (final result in results) {
        if (result != null) {
          enrichedBooks.add(result);
        }
      }

      // 배치 간 대기 시간 단축 (300ms → 100ms)
      if (endIndex < geminiBooks.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    return enrichedBooks;
  }

  Future<List<Map<String, dynamic>>> _generateGeminiRecommendations(
      Map<String, dynamic> userProfile, bool isPersonalized) async {
    try {
      String prompt;

      if (isPersonalized && userProfile.isNotEmpty) {
        final topGenres = List<String>.from(userProfile['topGenres'] ?? []);
        final topAuthors = List<String>.from(userProfile['topAuthors'] ?? []);

        prompt = """
독서 프로필:
- 선호 장르: ${topGenres.join(', ')}
- 선호 작가: ${topAuthors.join(', ')}

위 취향을 바탕으로 2025년 한국에서 구매 가능한 실제 도서 15권을 추천해주세요.
실제 존재하는 정확한 책제목과 저자명만 사용하세요.

JSON 형식:
[{"title":"정확한책제목","author":"정확한저자명","genre":"장르"}]
""";
      } else {
        prompt = """
2025년 한국에서 인기있는 실제 도서 15권을 JSON으로 추천해주세요.
다양한 장르로 구성하고, 실제 존재하는 정확한 책제목과 저자명만 사용하세요.

JSON 형식:
[{"title":"책제목","author":"저자명","genre":"장르"}]
""";
      }

      final response = await _geminiModel.generateContent([Content.text(prompt)]);
      return _parseRecommendations(response.text);
    } catch (e) {
      return [];
    }
  }

  Future<bool> _hasUserBooks(String userId) async {
    try {
      for (String status in ['completed', 'reading', 'wishlist']) {
        final snapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('myLibrary')
            .doc(status)
            .collection('books')
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> _getUserBooks(String userId) async {
    try {
      final List<Map<String, dynamic>> allBooks = [];

      for (String status in ['completed', 'reading', 'wishlist']) {
        final snapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('myLibrary')
            .doc(status)
            .collection('books')
            .get();

        for (var doc in snapshot.docs) {
          final bookData = doc.data();
          if (bookData['title'] != null && bookData['title'].toString().isNotEmpty) {
            allBooks.add({
              'title': bookData['title']?.toString() ?? '',
              'author': bookData['author']?.toString() ?? '',
              'genre': _normalizeGenre(bookData['genre']?.toString() ?? ''),
              'categoryName': bookData['categoryName']?.toString() ?? '',
              'status': status,
            });
          }
        }
      }

      return allBooks;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> _analyzeUserProfile(List<Map<String, dynamic>> userBooks) async {
    try {
      if (userBooks.isEmpty) {
        return {'topGenres': <String>[], 'topAuthors': <String>[], 'totalBooks': 0};
      }

      final Map<String, int> genreCount = {};
      final Map<String, int> authorCount = {};

      for (var book in userBooks) {
        final genre = book['genre'] as String;
        final author = book['author'] as String;

        if (genre.isNotEmpty && genre != '일반') {
          genreCount[genre] = (genreCount[genre] ?? 0) + 1;
        }

        if (author.isNotEmpty) {
          authorCount[author] = (authorCount[author] ?? 0) + 1;
        }
      }

      final topGenres = _getTopItems(genreCount, 3);
      final topAuthors = _getTopItems(authorCount, 3);

      return {
        'topGenres': topGenres,
        'topAuthors': topAuthors,
        'totalBooks': userBooks.length,
      };
    } catch (e) {
      return {'topGenres': <String>[], 'topAuthors': <String>[], 'totalBooks': 0};
    }
  }

  List<String> _getTopItems(Map<String, int> countMap, int limit) {
    final sortedEntries = countMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sortedEntries.take(limit).map((e) => e.key).toList();
  }

  Future<Map<String, dynamic>?> _searchBookByTitle(String title) async {
    try {
      final searchUrl = Uri.parse(
          'https://www.aladin.co.kr/ttb/api/ItemSearch.aspx?ttbkey=$_aladinApiKey&Query=${Uri.encodeComponent(title)}&QueryType=Title&MaxResults=3&start=1&SearchTarget=Book&output=js&Version=20131101&OptResult=packing');

      final response = await http.get(searchUrl).timeout(const Duration(seconds: 5)); // 타임아웃 단축 (10초 → 5초)

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['item'] != null && data['item'].isNotEmpty) {
          return data['item'][0];
        }
      }
    } catch (e) {
      // 오류 무시
    }
    return null;
  }

  Map<String, dynamic> _createCompleteBookData(
      Map<String, dynamic> aladinBook,
      Map<String, dynamic> geminiBook,
      String recommendationType) {

    String bookId = aladinBook['isbn13']?.toString() ??
        aladinBook['isbn']?.toString() ??
        _generateBookId(aladinBook['title']?.toString() ?? '', aladinBook['author']?.toString() ?? '');

    final currentTime = DateTime.now().toIso8601String();

    return {
      'id': bookId,
      'title': aladinBook['title'] ?? geminiBook['title'] ?? '',
      'author': aladinBook['author'] ?? geminiBook['author'] ?? '',
      'publisher': aladinBook['publisher'] ?? '',
      'isbn': aladinBook['isbn13'] ?? aladinBook['isbn'] ?? '',
      'coverUrl': aladinBook['cover'] ?? '',
      'description': aladinBook['description'] ?? '',
      'pubDate': aladinBook['pubDate'] ?? '',
      'link': aladinBook['link'] ?? '',
      'categoryName': aladinBook['categoryName'] ?? '',
      'itemPage': _parseItemPage(aladinBook),
      'genre': geminiBook['genre'] ?? _extractGenre(aladinBook['categoryName']),
      'recommendationType': recommendationType,
      'recommendedAt': currentTime,
      'status': 'RECOMMENDED',
      'progress': 0,
      'isEbook': false,
      'addedAt': currentTime,
      'timestamp': currentTime,
      'updatedAt': currentTime,
      'startDate': null,
    };
  }

  String _generateBookId(String title, String author) {
    if (title.isEmpty && author.isEmpty) {
      return 'book_${DateTime.now().millisecondsSinceEpoch}';
    }
    final combined = '${title}_${author}'.toLowerCase().replaceAll(RegExp(r'[^\w가-힣]'), '');
    return 'book_${combined.hashCode.abs()}';
  }

  // 캐시 관리
  Future<List<Map<String, dynamic>>> _getCachedPersonalizedRecommendations(String userId) async {
    try {
      final doc = await _firestore.collection(_personalizedCacheCollection).doc(userId).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final updatedAt = data['updatedAt'] as Timestamp?;

        if (updatedAt != null && DateTime.now().difference(updatedAt.toDate()).inDays < 3) {
          final books = data['books'] as List<dynamic>?;
          if (books != null && books.isNotEmpty) {
            return books.cast<Map<String, dynamic>>();
          }
        }
      }
    } catch (e) {
      // 오류 무시
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _getCachedWeeklyRecommendations() async {
    try {
      final doc = await _firestore.collection(_weeklyRecommendationCollection).doc('current').get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final updatedAt = data['updatedAt'] as Timestamp?;

        if (updatedAt != null && DateTime.now().difference(updatedAt.toDate()).inDays < 3) {
          final books = data['books'] as List<dynamic>?;
          if (books != null && books.isNotEmpty) {
            return books.cast<Map<String, dynamic>>();
          }
        }
      }
    } catch (e) {
      // 오류 무시
    }
    return [];
  }

  Future<void> _cachePersonalizedRecommendations(String userId, List<Map<String, dynamic>> recommendations) async {
    try {
      await _firestore.collection(_personalizedCacheCollection).doc(userId).set({
        'books': recommendations,
        'updatedAt': FieldValue.serverTimestamp(),
        'version': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      // 오류 무시
    }
  }

  Future<void> _cacheWeeklyRecommendations(List<Map<String, dynamic>> recommendations) async {
    try {
      await _firestore.collection(_weeklyRecommendationCollection).doc('current').set({
        'books': recommendations,
        'updatedAt': FieldValue.serverTimestamp(),
        'version': DateTime.now().millisecondsSinceEpoch,
        'totalBooks': recommendations.length,
      });
    } catch (e) {
      // 오류 무시
    }
  }

  String _normalizeGenre(String genre) {
    if (genre.isEmpty || genre == 'null') return '일반';

    final lowerGenre = genre.toLowerCase();

    if (lowerGenre.contains('소설')) return '소설';
    if (lowerGenre.contains('에세이')) return '에세이';
    if (lowerGenre.contains('인문')) return '인문';
    if (lowerGenre.contains('자기계발')) return '자기계발';
    if (lowerGenre.contains('경제') || lowerGenre.contains('경영')) return '경제/경영';
    if (lowerGenre.contains('과학')) return '과학';
    if (lowerGenre.contains('역사')) return '역사';
    if (lowerGenre.contains('문학')) return '문학';
    if (lowerGenre.contains('예술')) return '예술';

    return genre;
  }

  String _extractGenre(String? categoryName) {
    if (categoryName == null || categoryName.isEmpty) return '일반';

    final categories = categoryName.split('>');
    if (categories.length >= 2) {
      return _normalizeGenre(categories[1].trim());
    }
    return '일반';
  }

  int _parseItemPage(Map<String, dynamic> aladinBook) {
    try {
      if (aladinBook['subInfo'] != null && aladinBook['subInfo']['itemPage'] != null) {
        final itemPage = aladinBook['subInfo']['itemPage'];
        if (itemPage is int) return itemPage;
        if (itemPage is String) return int.tryParse(itemPage) ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  List<Map<String, dynamic>> _parseRecommendations(String? responseText) {
    if (responseText == null || responseText.isEmpty) {
      return [];
    }

    try {
      String jsonText = responseText;

      if (jsonText.contains('```json')) {
        final parts = jsonText.split('```json');
        if (parts.length > 1) {
          jsonText = parts[1];
        }
      }

      if (jsonText.contains('```')) {
        jsonText = jsonText.split('```')[0];
      }

      jsonText = jsonText.trim();
      final startIndex = jsonText.indexOf('[');
      final endIndex = jsonText.lastIndexOf(']');

      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        jsonText = jsonText.substring(startIndex, endIndex + 1);
      }

      final List<dynamic> jsonList = json.decode(jsonText);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  // 관리 메서드
  Future<void> invalidateUserRecommendations({String? userId}) async {
    try {
      final targetUserId = userId ?? _auth.currentUser?.uid;
      if (targetUserId != null) {
        await _firestore.collection(_personalizedCacheCollection).doc(targetUserId).delete();
        _processedBooks.clear();
      }
    } catch (e) {
      // 오류 무시
    }
  }

  Future<void> forceUpdateWeeklyRecommendations() async {
    try {
      await _firestore.collection(_weeklyRecommendationCollection).doc('current').delete();
      _processedBooks.clear();
      await getWeeklyRecommendations();
    } catch (e) {
      throw Exception('주간 추천 업데이트 실패: $e');
    }
  }

  Future<Map<String, dynamic>> getRecommendationStatus() async {
    try {
      final user = _auth.currentUser;
      bool hasBooks = false;

      if (user != null) {
        hasBooks = await _hasUserBooks(user.uid);
      }

      return {
        'isLoggedIn': user != null,
        'userId': user?.uid,
        'hasLibraryBooks': hasBooks,
        'recommendationType': hasBooks ? 'personalized' : 'weekly',
        'reason': hasBooks ? '서재 도서를 바탕으로 개인화 추천' : '인기 도서 추천',
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  void resetStreamStates() {
    _processedBooks.clear();
  }
}