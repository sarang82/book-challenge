import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/book_data_service.dart';
import '../services/firestore_service.dart';
import '../services/my_library_service.dart';
import '../services/recommendation_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../main.dart';
import '../screens/category_detail_screen.dart';
import '../screens/book_info_screen.dart';
import '../screens/my_library_category_screen.dart';

class BookTrackingScreen extends StatefulWidget {
  const BookTrackingScreen({super.key});

  @override
  State<BookTrackingScreen> createState() => _BookTrackingScreenState();
}

class _BookTrackingScreenState extends State<BookTrackingScreen> with SingleTickerProviderStateMixin {
  // 서비스 인스턴스들
  final BookDataService _bookDataService = bookDataService;
  final FirestoreService _firestoreService = FirestoreService();
  final MyLibraryService _myLibraryService = MyLibraryService();
  final RecommendationService _recommendationService = RecommendationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 로딩 상태
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isMyLibraryLoading = true;
  bool _isAIRecommendationLoading = false; // 초기값 false로 변경

  // 스트림 관련 추가
  Stream<List<Map<String, dynamic>>>? _aiRecommendationStream;
  bool _isAIRecommendationInitialized = false;

  late TabController _tabController;
  int _selectedIndex = 3;

  // 데이터
  Map<String, List<Map<String, dynamic>>> _bookData = {
    'bestsellers': [],
    'newReleases': [],
    'recommendedBooks': []
  };

  // 내 서재 데이터
  List<Map<String, dynamic>> _readingBooks = [];
  List<Map<String, dynamic>> _completedBooks = [];
  List<Map<String, dynamic>> _wishlistBooks = [];

  // AI 추천 데이터
  List<Map<String, dynamic>> _aiRecommendedBooks = [];
  bool _hasLibraryBooks = false;
  String _recommendationType = 'weekly';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);

    // 초기 데이터 로드
    _loadInitialData();
    _loadMyLibraryData();

    // AI 추천 스트림 시작
    _startAIRecommendationStream();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  // 탭 변경 감지 (최적화된 버전)
  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      if (_tabController.index == 1) {
        // 내 서재 탭으로 이동 시 서재 데이터만 로드
        _loadMyLibraryDataOnly();
      } else if (_tabController.index == 0) {
        // 맞춤 도서 탭으로 돌아올 때 필요시 AI 추천 체크
        _checkAndLoadAIRecommendationsIfNeeded();
      }
    }
  }

  // AI 추천 스트림 시작 (새로 추가)
  void _startAIRecommendationStream() {
    if (_isAIRecommendationInitialized) return;

    setState(() {
      _isAIRecommendationLoading = true;
    });

    _aiRecommendationStream = _recommendationService.getRecommendationsStream();

    _aiRecommendationStream!.listen(
          (recommendations) {
        if (mounted) {
          setState(() {
            _aiRecommendedBooks = recommendations;
            _isAIRecommendationLoading = false;
            _isAIRecommendationInitialized = true;
          });

          if (kDebugMode) {
            print('스트림에서 AI 추천 업데이트: ${recommendations.length}권');
          }
        }
      },
      onError: (error) {
        if (kDebugMode) print('AI 추천 스트림 오류: $error');
        if (mounted) {
          setState(() {
            _isAIRecommendationLoading = false;
            _isAIRecommendationInitialized = true;
          });
        }
      },
    );

    // 추천 상태도 업데이트
    _updateRecommendationStatus();
  }

  // 추천 상태 업데이트 (새로 추가)
  Future<void> _updateRecommendationStatus() async {
    try {
      final status = await _recommendationService.getRecommendationStatus();
      if (mounted) {
        setState(() {
          _hasLibraryBooks = status['hasLibraryBooks'] ?? false;
          _recommendationType = status['recommendationType'] ?? 'weekly';
        });
      }
    } catch (e) {
      if (kDebugMode) print('추천 상태 업데이트 오류: $e');
    }
  }

  // 내 서재 데이터만 로드 (새로 추가)
  Future<void> _loadMyLibraryDataOnly() async {
    if (_auth.currentUser == null) {
      setState(() {
        _readingBooks = [];
        _completedBooks = [];
        _wishlistBooks = [];
        _hasLibraryBooks = false;
        _isMyLibraryLoading = false;
      });
      return;
    }

    setState(() {
      _isMyLibraryLoading = true;
    });

    try {
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
      if (kDebugMode) print('내 서재 데이터만 로드 오류: $e');
      if (mounted) {
        setState(() {
          _isMyLibraryLoading = false;
        });
      }
    }
  }

  // 필요시 AI 추천 확인 (새로 추가)
  void _checkAndLoadAIRecommendationsIfNeeded() {
    // 이미 초기화되었다면 스킵
    if (_isAIRecommendationInitialized) {
      if (kDebugMode) print('AI 추천 이미 초기화됨, 스킵');
      return;
    }

    // 스트림 다시 시작
    _startAIRecommendationStream();
  }

  // 초기 데이터 로드
  Future<void> _loadInitialData() async {
    if (_isRefreshing) return;

    setState(() {
      _isLoading = true;
      _isRefreshing = true;
    });

    try {
      final data = await _bookDataService.getInitialData();

      if (mounted) {
        setState(() {
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

  // 내 서재 데이터 로드 (수정된 버전 - 서재 상태 변경 감지)
  Future<void> _loadMyLibraryData() async {
    if (_auth.currentUser == null) {
      setState(() {
        _readingBooks = [];
        _completedBooks = [];
        _wishlistBooks = [];
        _hasLibraryBooks = false;
        _isMyLibraryLoading = false;
      });
      return;
    }

    setState(() {
      _isMyLibraryLoading = true;
    });

    try {
      final libraryData = await _myLibraryService.fetchAllMyLibraryBooks();

      if (mounted) {
        setState(() {
          _readingBooks = libraryData[MyLibraryService.READING] ?? [];
          _completedBooks = libraryData[MyLibraryService.COMPLETED] ?? [];
          _wishlistBooks = libraryData[MyLibraryService.WISHLIST] ?? [];
          _isMyLibraryLoading = false;
        });

        // 서재 상태 변경 감지
        final totalBooks = _readingBooks.length + _completedBooks.length + _wishlistBooks.length;
        final previousHasBooks = _hasLibraryBooks;
        final currentHasBooks = totalBooks > 0;

        // 서재 상태 변경 시에만 캐시 무효화 및 AI 추천 재시작
        if (previousHasBooks != currentHasBooks) {
          if (kDebugMode) {
            print('서재 상태 변경 감지: $previousHasBooks → $currentHasBooks');
          }
          await _recommendationService.invalidateUserRecommendations();
          // AI 추천 재시작
          _forceRestartAIRecommendations();
        }
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

  // AI 추천 강제 재시작 (새로 추가)
  void _forceRestartAIRecommendations() {
    setState(() {
      _isAIRecommendationInitialized = false;
      _isAIRecommendationLoading = true;
      _aiRecommendedBooks = [];
    });

    _startAIRecommendationStream();
  }

  // 하단 내비게이션 바 탭 핸들러
  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/timer');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/challenge');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 3:
        break;
      case 4:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('준비 중인 기능입니다.'))
        );
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  String _getCategoryKey(String title) {
    if (title == '베스트셀러') return 'bestsellers';
    if (title == '신간 도서') return 'newReleases';
    if (title == 'AI 추천 도서') return 'recommendedBooks';
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

  Widget _buildCustomBookView() {
    return RefreshIndicator(
      onRefresh: () async {
        // 새로고침 시 모든 데이터 강제 재로드
        await Future.wait([
          _loadInitialData(),
          _loadMyLibraryData(),
        ]);
        // AI 추천도 강제 재시작
        _forceRestartAIRecommendations();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBookSection('베스트셀러', _bookData['bestsellers'] ?? []),
              _buildBookSection('신간 도서', _bookData['newReleases'] ?? []),
              _buildAIRecommendationSection(),
            ],
          ),
        ),
      ),
    );
  }

  // AI 추천 도서 섹션 (스트림 기반으로 수정)
  Widget _buildAIRecommendationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'AI 추천 도서',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _recommendationType == 'personalized' ? Colors.green[100] : Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _recommendationType == 'personalized' ? Icons.person : Icons.trending_up,
                        size: 14,
                        color: _recommendationType == 'personalized' ? Colors.green[600] : Colors.blue[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _recommendationType == 'personalized' ? '개인화' : '인기',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _recommendationType == 'personalized' ? Colors.green[600] : Colors.blue[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // 점진적 로딩 표시 추가
                if (_isAIRecommendationLoading && _aiRecommendedBooks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.orange[600],
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh), // 항상 새로고침 아이콘만 표시
              onPressed: _isAIRecommendationLoading && _aiRecommendedBooks.isEmpty
                  ? null // 완전 새로 로딩 중일 때만 비활성화
                  : () async {
                // 강제 새로고침
                await _recommendationService.invalidateUserRecommendations();
                if (_recommendationType == 'weekly') {
                  await _recommendationService.forceUpdateWeeklyRecommendations();
                }
                _forceRestartAIRecommendations();
              },
              tooltip: 'AI 추천 새로고침',
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 200,
          child: _buildAIRecommendationContent(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // AI 추천 콘텐츠 (점진적 로딩 지원)
  Widget _buildAIRecommendationContent() {
    // 로딩 중이고 아직 책이 없는 경우
    if (_isAIRecommendationLoading && _aiRecommendedBooks.isEmpty) {
      return _buildAILoadingState();
    }

    // 책이 없는 경우 (로딩 완료)
    if (_aiRecommendedBooks.isEmpty && !_isAIRecommendationLoading) {
      return _buildEmptyAIRecommendation();
    }

    // 책이 있는 경우 (점진적 로딩 또는 완료)
    return _buildAIBooksList();
  }

  // AI 로딩 상태 (개선된 버전)
  Widget _buildAILoadingState() {
    return Center(  // Center로 전체를 감싸기
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,  // Column이 필요한 만큼만 공간 차지
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'AI가 당신을 위한 책을 찾고 있어요...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // AI 책 목록 (점진적 로딩 애니메이션 포함)
  Widget _buildAIBooksList() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: _aiRecommendedBooks.length + (_isAIRecommendationLoading ? 1 : 0),
      itemBuilder: (context, index) {
        // 마지막 아이템이고 로딩 중인 경우 로딩 표시
        if (index == _aiRecommendedBooks.length && _isAIRecommendationLoading) {
          return _buildLoadingBookItem();
        }

        // 실제 책 아이템
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _buildAIRecommendationItem(_aiRecommendedBooks[index]),
        );
      },
    );
  }

  // 로딩 중인 책 아이템 (점진적 로딩용)
  Widget _buildLoadingBookItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[200],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '로딩중...',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: 80,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }

  // 빈 AI 추천 상태 위젯 (기존과 동일)
  Widget _buildEmptyAIRecommendation() {
    if (_recommendationType != 'personalized') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, color: Colors.blue[600], size: 32),
            const SizedBox(height: 8),
            Text(
              '맞춤 AI 추천을 받고 싶나요?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '서재에 읽은 책이나 관심 있는 책을 추가하면\n당신만을 위한 개인화 추천을 받을 수 있어요!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blue[700], fontSize: 12),
            ),
          ],
        ),
      );
    } else {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'AI 추천을 준비 중입니다...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
  }

  // AI 추천 아이템 위젯 (기존과 동일)
  Widget _buildAIRecommendationItem(Map<String, dynamic> book) {
    return InkWell(
      onTap: () {
        _navigateToBookInfoFromAI(book);
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
                  child: book['coverUrl'] != null && book['coverUrl'].isNotEmpty
                      ? Image.network(
                    book['coverUrl'],
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
                      return _buildPlaceholderCover(book);
                    },
                  )
                      : _buildPlaceholderCover(book),
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
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 플레이스홀더 커버 (기존과 동일)
  Widget _buildPlaceholderCover(Map<String, dynamic> book) {
    return Container(
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _recommendationType == 'personalized' ? Icons.person : Icons.auto_awesome,
            size: 24,
            color: Colors.grey,
          ),
          const SizedBox(height: 4),
          Text(
            book['genre'] ?? 'AI',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // AI 추천 도서에서 상세 정보로 이동 (자동 새로고침 제거)
  void _navigateToBookInfoFromAI(Map<String, dynamic> aiBook) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookInfoScreen(bookData: aiBook),
      ),
    ).then((_) {
      // 도서 상세에서 돌아온 후 서재 탭이면 서재 데이터만 새로고침
      if (_tabController.index == 1) {
        _loadMyLibraryDataOnly();
      }
      // AI 추천은 자동 새로고침하지 않음
    });
  }

  // 내 서재 화면
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

  Widget _buildMyLibrarySection(String title, List<Map<String, dynamic>> books, String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MyLibraryCategoryScreen(
                  title: title,
                  status: status,
                ),
              ),
            ).then((_) {
              _loadMyLibraryData();
            });
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookInfoScreen(bookData: book),
          ),
        ).then((_) {
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

  Widget _buildMyLibraryBookItem(Map<String, dynamic> book, String status) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookInfoScreen(bookData: book),
          ),
        ).then((_) {
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