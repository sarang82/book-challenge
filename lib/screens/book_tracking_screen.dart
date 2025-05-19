import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/book_data_service.dart';
import '../services/firestore_service.dart';
import '../services/my_library_service.dart'; // 내 서재 서비스 추가
import '../widgets/bottom_nav_bar.dart';
import '../main.dart'; // 글로벌 BookDataService 인스턴스 접근용
import '../screens/category_detail_screen.dart';
import '../screens/book_info_screen.dart';

class BookTrackingScreen extends StatefulWidget {
  const BookTrackingScreen({super.key});

  @override
  State<BookTrackingScreen> createState() => _BookTrackingScreenState();
}

class _BookTrackingScreenState extends State<BookTrackingScreen> with SingleTickerProviderStateMixin {
  // main.dart에서 정의한 글로벌 인스턴스 사용
  final BookDataService _bookDataService = bookDataService;
  final FirestoreService _firestoreService = FirestoreService();
  final MyLibraryService _myLibraryService = MyLibraryService(); // 내 서재 서비스 인스턴스
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isMyLibraryLoading = true; // 내 서재 로딩 상태
  late TabController _tabController;
  int _selectedIndex = 3; // 서재 화면은 인덱스 3

  // 맞춤 도서 데이터
  Map<String, List<Map<String, dynamic>>> _bookData = {
    'bestsellers': [],
    'newReleases': [],
    'recommendedBooks': []
  };

  // 내 서재 데이터
  List<Map<String, dynamic>> _readingBooks = []; // 읽고 있는 책
  List<Map<String, dynamic>> _completedBooks = []; // 완독한 도서
  List<Map<String, dynamic>> _wishlistBooks = []; // 읽고 싶은 책

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 탭 변경 리스너 추가
    _tabController.addListener(_handleTabChange);

    // 초기 데이터 로드
    _loadInitialData();

    // 내 서재 데이터 로드
    _loadMyLibraryData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  // 탭 변경 감지
  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      if (_tabController.index == 1) {
        // 내 서재 탭으로 이동 시 데이터 새로고침
        _loadMyLibraryData();
      }
    }
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

  // 내 서재 데이터 로드
  Future<void> _loadMyLibraryData() async {
    // 로그인 확인
    if (_auth.currentUser == null) {
      setState(() {
        _readingBooks = [];
        _completedBooks = [];
        _wishlistBooks = [];
        _isMyLibraryLoading = false;
      });
      return;
    }

    setState(() {
      _isMyLibraryLoading = true;
    });

    try {
      // 내 서재 서비스에서 데이터 가져오기
      final libraryData = await _myLibraryService.fetchAllMyLibraryBooks();

      if (mounted) {
        setState(() {
          _readingBooks = libraryData[MyLibraryService.READING] ?? [];
          _completedBooks = libraryData[MyLibraryService.COMPLETED] ?? [];
          _wishlistBooks = libraryData[MyLibraryService.WISHLIST] ?? [];
          _isMyLibraryLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('내 서재 데이터 로드 오류: $e');
      }
      if (mounted) {
        setState(() {
          _isMyLibraryLoading = false;
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

  // 카테고리명을 키로 변환하는 헬퍼 함수
  String _getCategoryKey(String title) {
    if (title == '베스트셀러') return 'bestsellers';
    if (title == '신간 도서') return 'newReleases';
    if (title == '추천 도서') return 'recommendedBooks';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
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
          // 맞춤 도서 탭
          _isLoading ? _buildLoadingIndicator() : _buildCustomBookView(),

          // 내 서재 탭
          _isMyLibraryLoading
              ? _buildLoadingIndicator()
              : _auth.currentUser == null
              ? _buildLoginPrompt()
              : _buildMyLibraryView(),
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

  // 로그인 안내 화면
  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '내 서재를 이용하려면 로그인이 필요합니다',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              // 로그인 화면으로 이동
              Navigator.pushNamed(context, '/login').then((_) {
                // 로그인 후 내 서재 데이터 로드
                if (_auth.currentUser != null) {
                  _loadMyLibraryData();
                }
              });
            },
            child: const Text('로그인하기'),
          ),
        ],
      ),
    );
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
              _buildBookSection('AI 추천 도서', _bookData['recommendedBooks'] ?? []),
            ],
          ),
        ),
      ),
    );
  }

  // 내 서재 화면 구현
  Widget _buildMyLibraryView() {
    return RefreshIndicator(
      onRefresh: _loadMyLibraryData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMyLibrarySection('읽고 있는 책', _readingBooks, MyLibraryService.READING),
              _buildMyLibrarySection('완독한 도서', _completedBooks, MyLibraryService.COMPLETED),
              _buildMyLibrarySection('읽고 싶은 책', _wishlistBooks, MyLibraryService.WISHLIST),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookSection(String title, List<Map<String, dynamic>> books) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            // 더보기 버튼 추가
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryDetailScreen(
                      title: title,
                      category: _getCategoryKey(title),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
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

  // 내 서재 섹션 빌더
  Widget _buildMyLibrarySection(String title, List<Map<String, dynamic>> books, String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            // 더보기 버튼 추가
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                // 해당 카테고리의 상세 페이지로 이동 (미구현)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('준비 중인 기능입니다')),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 200,
          child: books.isEmpty
              ? const Center(child: Text('등록된 책이 없습니다'))
              : ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            itemBuilder: (context, index) {
              return _buildMyLibraryBookItem(books[index], status);
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildBookItem(Map<String, dynamic> book) {
    return InkWell(
      onTap: () {
        // 도서 정보 화면으로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookInfoScreen(bookData: book),
          ),
        ).then((_) {
          // 도서 정보 화면에서 돌아오면 내 서재 데이터 새로고침
          if (_tabController.index == 1) {
            _loadMyLibraryData();
          }
        });
      },
      child: Padding(
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
      ),
    );
  }

  // 내 서재 도서 아이템
  Widget _buildMyLibraryBookItem(Map<String, dynamic> book, String status) {
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
          _loadMyLibraryData();
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          children: [
            Stack(
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
                    cacheWidth: 200,
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
                // 읽기 진행 상태 표시 (읽고 있는 책인 경우에만)
                if (status == MyLibraryService.READING)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: FractionallySizedBox(
                        widthFactor: book['progress'] ?? 0.0,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
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
      ),
    );
  }
}