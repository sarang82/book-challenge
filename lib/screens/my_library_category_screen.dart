import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/my_library_service.dart';
import 'book_info_screen.dart';

class MyLibraryCategoryScreen extends StatefulWidget {
  final String title;
  final String status; // READING, COMPLETED, WISHLIST

  const MyLibraryCategoryScreen({
    Key? key,
    required this.title,
    required this.status,
  }) : super(key: key);

  @override
  State<MyLibraryCategoryScreen> createState() => _MyLibraryCategoryScreenState();
}

class _MyLibraryCategoryScreenState extends State<MyLibraryCategoryScreen> {
  final MyLibraryService _myLibraryService = MyLibraryService();

  List<Map<String, dynamic>> _books = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  static const int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadBooks();
    if (kDebugMode) {
      print('MyLibraryCategoryScreen 초기화: ${widget.status}');
    }
  }

  // 내 서재 도서 로드
  Future<void> _loadBooks() async {
    if (kDebugMode) {
      print('내 서재 도서 데이터 로드 시작: ${widget.status}');
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // 특정 상태의 모든 도서 가져오기
      final libraryData = await _myLibraryService.fetchAllMyLibraryBooks();
      final books = libraryData[widget.status] ?? [];

      if (kDebugMode) {
        print('${widget.status} 상태의 도서 ${books.length}권 로드 완료');
      }

      setState(() {
        _books = books;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('내 서재 도서 로드 실패: $e');
      }

      setState(() {
        _isLoading = false;
        _errorMessage = '도서 데이터를 불러오는 데 실패했습니다: $e';
      });
    }
  }

  // 현재 페이지의 도서 목록 가져오기
  List<Map<String, dynamic>> _getCurrentPageBooks() {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage > _books.length ? _books.length : startIndex + _itemsPerPage;

    if (startIndex >= _books.length) {
      return [];
    }

    return _books.sublist(startIndex, endIndex);
  }

  // 페이지 변경
  void _changePage(int page) {
    final maxPage = (_books.length / _itemsPerPage).ceil();
    if (page < 1 || page > maxPage) return;

    setState(() {
      _currentPage = page;
    });
  }

  // 도서 상태 업데이트 후 목록 새로고침
  Future<void> _refreshAfterUpdate() async {
    await _loadBooks();
  }

  @override
  Widget build(BuildContext context) {
    final currentPageBooks = _getCurrentPageBooks();
    final maxPage = (_books.length / _itemsPerPage).ceil();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _errorMessage != null
          ? _buildErrorView()
          : Column(
        children: [
          // 상태 정보 및 통계
          _buildStatusInfo(),

          // 도서 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : currentPageBooks.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadBooks,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: currentPageBooks.length,
                itemBuilder: (context, index) {
                  return _buildBookListItem(currentPageBooks[index]);
                },
              ),
            ),
          ),

          // 페이지네이션 UI
          if (!_isLoading && _books.isNotEmpty && maxPage > 1)
            _buildPagination(maxPage),
        ],
      ),
    );
  }

  // 상태 정보 표시
  Widget _buildStatusInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          _buildStatusIcon(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '총 ${_books.length}권${_getCurrentPageInfo()}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 상태별 아이콘
  Widget _buildStatusIcon() {
    IconData iconData;
    Color iconColor;

    switch (widget.status) {
      case MyLibraryService.READING:
        iconData = Icons.menu_book;
        iconColor = Colors.blue;
        break;
      case MyLibraryService.COMPLETED:
        iconData = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case MyLibraryService.WISHLIST:
        iconData = Icons.favorite;
        iconColor = Colors.red;
        break;
      default:
        iconData = Icons.book;
        iconColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 24,
      ),
    );
  }

  // 페이지 정보 텍스트
  String _getCurrentPageInfo() {
    if (_books.length <= _itemsPerPage) return '';
    final maxPage = (_books.length / _itemsPerPage).ceil();
    return ' (페이지 $_currentPage / $maxPage)';
  }

  // 빈 상태 표시
  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (widget.status) {
      case MyLibraryService.READING:
        message = '현재 읽고 있는 책이 없습니다.\n새로운 책을 추가해보세요!';
        icon = Icons.menu_book_outlined;
        break;
      case MyLibraryService.COMPLETED:
        message = '완독한 책이 없습니다.\n독서를 시작해보세요!';
        icon = Icons.check_circle_outline;
        break;
      case MyLibraryService.WISHLIST:
        message = '읽고 싶은 책이 없습니다.\n관심있는 책을 찾아보세요!';
        icon = Icons.favorite_outline;
        break;
      default:
        message = '등록된 책이 없습니다.';
        icon = Icons.book_outlined;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
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

  // 오류 화면
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

  // 도서 리스트 아이템
  Widget _buildBookListItem(Map<String, dynamic> book) {
    return InkWell(
      onTap: () {
        // 도서 정보 화면으로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookInfoScreen(bookData: book),
          ),
        ).then((_) {
          // 돌아올 때 데이터 새로고침
          _refreshAfterUpdate();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 도서 표지 (진행률 표시 제거)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                book['coverUrl'] ?? 'https://via.placeholder.com/100x150?text=No+Cover',
                width: 70,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
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

            // 도서 정보 (날짜 정보 제거)
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
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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