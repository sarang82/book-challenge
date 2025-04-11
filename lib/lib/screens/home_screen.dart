import 'package:book_tracking_app/screens/book_info_screen.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../widgets/bottom_nav_bar.dart'; // bottom_nav_bar 임포트
import '../services/book_search_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 2; // 홈 화면은 인덱스 2

  // 검색 관련 상태 변수 추가
  final TextEditingController _searchController = TextEditingController();
  final BookSearchService _searchService = BookSearchService();
  //홈에서 닉네임 불러오기
  String? _nickname;

  bool _isSearching = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _searchResults = [];

  // 디바운싱을 위한 타이머
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // 검색어 변경 리스너 등록
    _searchController.addListener(_onSearchChanged);
    //닉네임 불러오기
    _loadNickname();
  }

  Future<void> _loadNickname() async {
    final nickname = await AuthService().getNickname();
    setState(() {
      _nickname = nickname ?? '사용자';
    });
  }

  @override
  void dispose() {
    // 메모리 누수 방지를 위한 리소스 해제
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // 검색어 변경 시 호출되는 메서드 (디바운싱 적용)
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.isNotEmpty) {
        _performSearch(_searchController.text);
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    });
  }

  // 검색 실행
  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearching = true;
    });

    try {
      final results = await _searchService.searchBooks(query);

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('검색 중 오류가 발생했습니다: $e'))
      );
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });

      switch (index) {
        case 0:
        // 타이머 화면으로 이동
          Navigator.pushReplacementNamed(context, '/timer');
          break;
        case 1:
        // 챌린지 화면으로 이동
          Navigator.pushReplacementNamed(context, '/challenge');
          break;
        case 2:
        // 이미 홈 화면이므로 아무 작업 안함
          break;
        case 3:
        // 서재 화면으로 이동
          Navigator.pushReplacementNamed(context, '/library');
          break;
        case 4:
        // 프로필 화면으로 이동
          Navigator.pushReplacementNamed(context, '/profile');
          break;
      }
    }
  }

  // 검색창 포커스 해제
  void _clearFocus() {
    FocusScope.of(context).unfocus();
  }

  // 검색 모드 종료
  void _exitSearchMode() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchResults = [];
    });
    _clearFocus();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    // 도서 항목 하나의 높이 (패딩 포함) 계산
    final double bookItemHeight = 76.0; // 60px 높이 + 패딩 16px
    // 4개 항목을 보여주는 높이 계산
    final double resultsHeight = bookItemHeight * 4;


    return GestureDetector(
      onTap: _clearFocus, // 화면 터치시 키보드 닫기
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Container(
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(18),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '제목 또는 저자를 입력하세요.',
                hintStyle: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.normal),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: _exitSearchMode,
                )
                    : null,
              ),
              onSubmitted: _performSearch,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: Colors.black),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.black),
              onPressed: () {},
            ),
          ],
        ),
        body: Stack(
          children: [
            // 기본 홈 화면 내용
            Column(
              children: [
                const SizedBox(height: 20),
                _buildMainCard(),
                const SizedBox(height: 20),
                Expanded(child: _buildImageSection(screenWidth)),
              ],
            ),

            // 검색 결과 오버레이
            if (_isSearching)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.white,
                  height: _isLoading || _searchResults.isEmpty
                      ? 80 // 로딩 중이거나 결과가 없을 때는 작은 높이
                      : resultsHeight, // 결과가 있으면 4개 항목 높이
                  child: _isLoading
                      ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                      : _searchResults.isEmpty
                      ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        '"${_searchController.text}" 검색 결과가 없습니다',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  )
                      : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final book = _searchResults[index];
                      return _buildSimpleBookItem(book);
                    },
                  ),
                ),
              ),
          ],
        ),
        // 기존 BottomNavigationBar 대신 새로운 BottomNavBar 위젯 사용
        bottomNavigationBar: BottomNavBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }

  // 간소화된 도서 아이템 위젯 (표지, 제목, 저자만 표시)
  Widget _buildSimpleBookItem(Map<String, dynamic> book) {
    return InkWell(
      onTap: () {
        // 도서 상세 페이지로 이동하는 기능 (추후 구현)
        setState(() {
          _isSearching = false;
        });
        _clearFocus();

        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => BookInfoScreen(bookData: book),
            ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.withOpacity(0.3)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 도서 표지
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                book['coverUrl'] ?? 'https://via.placeholder.com/100x150?text=No+Cover',
                width: 40,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 40,
                    height: 60,
                    color: Colors.grey[300],
                    child: const Icon(Icons.book, size: 24),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            // 도서 정보 (제목과 저자만)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    book['title'] ?? '제목 없음',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book['author'] ?? '저자 미상',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
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
  Widget _buildMainCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: Image.asset(
                    'assets/images/Sea_otter.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '오늘의 독서 날씨: 맑음! ☀️',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black),
                      ),
                      SizedBox(height: 5),
                      Text(
                        '$_nickname님,\n같이 책을 읽어볼까요?',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            const Text(
              '[아몬드 3일만에 읽기] 챌린지 현황',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black),
            ),
            const SizedBox(height: 10),
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                Container(
                  width: 240,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.blue[300],
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerRight,
              child: Text('78%', style: TextStyle(color: Colors.black)),
            ),
            const SizedBox(height: 15),
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE798),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Center(
                child: Text(
                  '새 챌린지 시작하기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(double width) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/wave.png'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
