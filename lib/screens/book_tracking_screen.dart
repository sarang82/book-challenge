import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/book_data_service.dart';
import '../services/firestore_service.dart';

class BookTrackingScreen extends StatefulWidget {
  const BookTrackingScreen({super.key});

  @override
  State<BookTrackingScreen> createState() => _BookTrackingScreenState();
}

class _BookTrackingScreenState extends State<BookTrackingScreen> with SingleTickerProviderStateMixin {
  final BookDataService _bookDataService = BookDataService();
  final FirestoreService _firestoreService = FirestoreService();

  bool _isLoading = true;
  late TabController _tabController;
  int _selectedIndex = 3;

  // 스트림 구독 관리
  Stream<QuerySnapshot>? bestsellersStream;
  Stream<QuerySnapshot>? newReleasesStream;
  Stream<QuerySnapshot>? recommendedBooksStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Firebase 데이터 초기화 및 업데이트
    _initializeData();

    // Firestore 스트림 설정
    _setupStreams();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      // 데이터 최신화
      await _bookDataService.updateBookData();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('도서 데이터 업데이트 오류: $e');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setupStreams() {
    // Firestore에서 데이터 스트림 가져오기
    bestsellersStream = _firestoreService.getBestsellers();
    newReleasesStream = _firestoreService.getNewReleases();
    recommendedBooksStream = _firestoreService.getRecommendedBooks();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });

      // 네비게이션 로직
      Future.microtask(() {
        if (!mounted) return;

        switch (index) {
          case 0:
            Navigator.pushNamed(context, '/timer');
            break;
          case 1:
            Navigator.pushNamed(context, '/challenge');
            break;
          case 2:
            Navigator.pushNamed(context, '/');
            break;
          case 3:
            Navigator.pushNamed(context, '/library');
            break;
          case 4:
            Navigator.pushNamed(context, '/profile');
            break;
        }
      });
    }
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
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: '타이머'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: '챌린지'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.library_books), label: '서재'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '프로필'),
        ],
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
      onRefresh: _initializeData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFirestoreBookSection('베스트셀러', bestsellersStream),
              _buildFirestoreBookSection('신간 도서', newReleasesStream),
              _buildPlaceholderSection('AI 추천 도서'),
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

  Widget _buildFirestoreBookSection(String title, Stream<QuerySnapshot>? stream) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        SizedBox(
          height: 200,
          child: StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('오류: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Center(
                  child: Text('데이터가 없습니다'),
                );
              }

              // 최대 5개의 책만 표시
              final limitedDocs = docs.length > 5 ? docs.sublist(0, 5) : docs;

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: limitedDocs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return _buildBookItem(data);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPlaceholderSection(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const SizedBox(
          height: 200,
          child: Center(
            child: Text('준비 중입니다', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildBookItem(Map<String, dynamic> book) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: InkWell(
        onTap: () {
          // 나중에 상세 화면으로 이동하는 기능 추가 예정
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('도서 상세 페이지는 준비 중입니다')),
          );
        },
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
              child: FadeInImage.assetNetwork(
                placeholder: 'assets/book_placeholder.png', // 플레이스홀더 이미지 추가 필요
                image: book['coverUrl'] ?? 'https://placehold.co/100x150',
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 300),
                imageErrorBuilder: (context, error, stackTrace) {
                  return Image.network(
                    'https://placehold.co/100x150',
                    fit: BoxFit.cover,
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
                  overflow: TextOverflow.ellipsis
              ),
            ),
          ],
        ),
      ),
    );
  }
}