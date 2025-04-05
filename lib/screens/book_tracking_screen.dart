import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/book_data_service.dart';
import '../services/firestore_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../main.dart'; // 글로벌 BookDataService 인스턴스 접근용

class BookTrackingScreen extends StatefulWidget {
  const BookTrackingScreen({super.key});

  @override
  State<BookTrackingScreen> createState() => _BookTrackingScreenState();
}

class _BookTrackingScreenState extends State<BookTrackingScreen> with SingleTickerProviderStateMixin {
  // main.dart에서 정의한 글로벌 인스턴스 사용
  final BookDataService _bookDataService = bookDataService;
  final FirestoreService _firestoreService = FirestoreService();

  bool _isLoading = true;
  bool _isRefreshing = false;
  late TabController _tabController;
  int _selectedIndex = 3; // 서재 화면은 인덱스 3

  // 데이터 저장
  Map<String, List<Map<String, dynamic>>> _bookData = {
    'bestsellers': [],
    'newReleases': [],
    'recommendedBooks': []
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 초기 데이터 로드
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 초기 데이터 로드 (최적화된 방식)
  Future<void> _loadInitialData() async {
    if (_isRefreshing) return; // 이미 새로고침 중이면 중복 호출 방지

    setState(() {
      _isLoading = true;
      _isRefreshing = true;
    });

    try {
      // 초기 데이터 로드 (기본적으로 5개 책 로드)
      final data = await _bookDataService.getInitialData();

      if (mounted) {
        setState(() {
          // 각 카테고리 데이터가 있는 경우에만 업데이트
          if (data['bestsellers']!.isNotEmpty) {
            _bookData['bestsellers'] = data['bestsellers']!;
          }
          if (data['newReleases']!.isNotEmpty) {
            _bookData['newReleases'] = data['newReleases']!;
          }
          if (data['recommendedBooks']!.isNotEmpty) {
            _bookData['recommendedBooks'] = data['recommendedBooks']!;
          }

          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('초기 도서 데이터 로드 오류: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  // 하단 내비게이션 바 탭 핸들러
  void _onItemTapped(int index) {
    if (index == _selectedIndex) return; // 같은 탭 선택 시 무시

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/timer');
        break;
      case 1:
      // 챌린지 화면으로 이동
        Navigator.pushReplacementNamed(context, '/challenge');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 3:
      // 현재 화면이므로 아무 작업도 하지 않음
        break;
      case 4:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
      default:
      // 구현되지 않은 탭
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('준비 중인 기능입니다.'))
        );
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('서재', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          tabs: const [
            Tab(text: '맞춤 도서'),
            Tab(text: '내 서재'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _isLoading ? _buildLoadingIndicator() : _buildCustomBookView(),
          _buildMyLibraryView(),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildCustomBookView() {
    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBookSection('베스트셀러', _bookData['bestsellers'] ?? []),
              _buildBookSection('신간 도서', _bookData['newReleases'] ?? []),
              _buildBookSection('추천 도서', _bookData['recommendedBooks'] ?? []),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyLibraryView() {
    return const Center(
      child: Text(
        '내 서재 기능은 준비 중입니다!',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBookSection(String title, List<Map<String, dynamic>> books) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        SizedBox(
          height: 200,
          child: books.isEmpty
              ? const Center(child: Text('데이터가 없습니다'))
              : ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            itemBuilder: (context, index) {
              return _buildBookItem(books[index]);
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildBookItem(Map<String, dynamic> book) {
    // 메모리 최적화: 이미지 캐싱 및 최적화
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              book['coverUrl'] ?? 'https://via.placeholder.com/100x150',
              fit: BoxFit.cover,
              // 메모리 캐싱 활성화
              cacheWidth: 200, // 메모리 최적화를 위한 캐시 크기 제한
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.book, size: 40),
                );
              },
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 100,
            child: Text(
              book['title'] ?? '제목 없음',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}