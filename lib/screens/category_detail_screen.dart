import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart'; // bookDataService 접근을 위해
import 'book_info_screen.dart'; // 추가된 import

class CategoryDetailScreen extends StatefulWidget {
  final String title;
  final String category;

  const CategoryDetailScreen({
    Key? key,
    required this.title,
    required this.category,
  }) : super(key: key);

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  List<Map<String, dynamic>> _books = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalBooks = 0;

  @override
  void initState() {
    super.initState();
    _loadBooks();
    if (kDebugMode) {
      print('CategoryDetailScreen 초기화: ${widget.category}');
    }
  }

  // 간소화된 도서 로드 메서드
  Future<void> _loadBooks() async {
    if (kDebugMode) {
      print('도서 데이터 로드 시작: ${widget.category}');
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // 쿼리 단순화 - orderBy 제거
      final snapshot = await FirebaseFirestore.instance
          .collection(widget.category)
          .limit(30) // 더 많은 데이터를 한 번에 가져옴
          .get();

      // 쿼리 결과 로깅
      if (kDebugMode) {
        print('쿼리 결과: ${snapshot.docs.length}개 문서');
        if (snapshot.docs.isNotEmpty) {
          print('첫 번째 문서 샘플: ${snapshot.docs.first.data()}');
        }
      }

      if (snapshot.docs.isEmpty) {
        setState(() {
          _books = [];
          _isLoading = false;
          _errorMessage = '해당 카테고리에 도서가 없습니다';
        });
        return;
      }

      // 문서 데이터 변환 및 로깅
      final books = snapshot.docs.map((doc) {
        final data = doc.data();
        if (kDebugMode) {
          print('도서 데이터: $data');
        }
        return data;
      }).toList();

      _totalBooks = books.length;

      setState(() {
        _books = books;
        _isLoading = false;
      });

      if (kDebugMode) {
        print('도서 ${books.length}권 로드 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('도서 로드 실패: $e');
        if (e is FirebaseException) {
          print('Firebase 오류 코드: ${e.code}, 메시지: ${e.message}');
        }
      }

      setState(() {
        _isLoading = false;
        _errorMessage = '도서 데이터를 불러오는 데 실패했습니다: $e';
      });
    }
  }

  // 현재 페이지의 도서 목록 가져오기
  List<Map<String, dynamic>> _getCurrentPageBooks() {
    final startIndex = (_currentPage - 1) * 10;
    final endIndex = startIndex + 10 > _books.length ? _books.length : startIndex + 10;

    if (startIndex >= _books.length) {
      return [];
    }

    return _books.sublist(startIndex, endIndex);
  }

  // 페이지 변경
  void _changePage(int page) {
    final maxPage = (_books.length / 10).ceil();
    if (page < 1 || page > maxPage) return;

    setState(() {
      _currentPage = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPageBooks = _getCurrentPageBooks();
    final maxPage = (_books.length / 10).ceil();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _errorMessage != null
          ? _buildErrorView()
          : Column(
        children: [
          if (kDebugMode)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('총 ${_books.length}권, 현재 페이지: $_currentPage / $maxPage'),
            ),

          // 도서 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : currentPageBooks.isEmpty
                ? const Center(child: Text('도서 정보가 없습니다'))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: currentPageBooks.length,
              itemBuilder: (context, index) {
                return _buildBookListItem(currentPageBooks[index]);
              },
            ),
          ),

          // 페이지네이션 UI
          if (!_isLoading && _books.isNotEmpty)
            _buildPagination(maxPage),
        ],
      ),
    );
  }

  // 페이지네이션 UI
  Widget _buildPagination(int maxPage) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 이전 페이지 버튼
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1
                ? () => _changePage(_currentPage - 1)
                : null,
            color: _currentPage > 1 ? Colors.blue : Colors.grey,
          ),

          // 페이지 번호들
          for (int i = 1; i <= maxPage; i++)
            if (i == _currentPage ||
                i == 1 ||
                i == maxPage ||
                (i >= _currentPage - 1 && i <= _currentPage + 1))
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => _changePage(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: i == _currentPage ? Colors.blue : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$i',
                      style: TextStyle(
                        color: i == _currentPage ? Colors.white : Colors.grey[700],
                        fontWeight: i == _currentPage ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              )
            else if (i == _currentPage - 2 || i == _currentPage + 2)
              Text('...', style: TextStyle(color: Colors.grey[700])),

          // 다음 페이지 버튼
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < maxPage
                ? () => _changePage(_currentPage + 1)
                : null,
            color: _currentPage < maxPage ? Colors.blue : Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? '오류가 발생했습니다',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadBooks,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookListItem(Map<String, dynamic> book) {
    return InkWell(
      onTap: () {
        // 도서 정보 화면으로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookInfoScreen(bookData: book),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.withOpacity(0.3)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 도서 표지
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                book['coverUrl'] ?? 'https://via.placeholder.com/100x150?text=No+Cover',
                width: 70,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  if (kDebugMode) {
                    print('이미지 로드 실패: $error');
                  }
                  return Container(
                    width: 70,
                    height: 100,
                    color: Colors.grey[300],
                    child: const Icon(Icons.book, size: 40),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            // 도서 정보 (제목과 저자)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book['title'] ?? '제목 없음',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book['author'] ?? '저자 미상',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (kDebugMode)
                    Text(
                      '키: ${book.keys.join(", ")}',
                      style: const TextStyle(fontSize: 10),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}