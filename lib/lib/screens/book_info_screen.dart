import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/aladin_service.dart';
import '../services/firestore_service.dart';

class BookInfoScreen extends StatefulWidget {
  final Map<String, dynamic>? bookData;

  const BookInfoScreen({
    super.key,
    required this.bookData,
  });

  @override
  State<BookInfoScreen> createState() => _BookInfoScreenState();
}

class _BookInfoScreenState extends State<BookInfoScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  Map<String, dynamic>? _detailedBookData;
  final AladinService _aladinService = AladinService();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);

    // 상세 정보 로드
    _loadDetailedBookInfo();
  }

  // 상세 정보 로드 메서드 추가
  Future<void> _loadDetailedBookInfo() async {
    if (widget.bookData == null || widget.bookData!['isbn'] == null) return;

    final String isbn = widget.bookData!['isbn'];

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. 먼저 Firestore에서 상세 정보가 있는지 확인
      Map<String, dynamic>? detailedData = await _firestoreService.getBookDetail(isbn);

      // 2. 상세 정보가 없거나 페이지 수 정보가 없는 경우 API 호출
      if (detailedData == null || detailedData['itemPage'] == null || detailedData['itemPage'] == 0) {
        if (kDebugMode) {
          print('도서 ID: $isbn의 상세 정보를 API에서 가져옵니다.');
        }

        final apiDetailedData = await _aladinService.fetchBookDetail(isbn);

        if (apiDetailedData != null) {
          // API에서 가져온 정보가 있으면 Firestore에 저장
          await _firestoreService.saveOrUpdateBookDetail(isbn, apiDetailedData);
          detailedData = apiDetailedData;
        }
      } else {
        if (kDebugMode) {
          print('도서 ID: $isbn의 상세 정보를 Firestore에서 가져왔습니다.');
        }
      }

      if (mounted) {
        setState(() {
          if (detailedData != null) {
            // 기존 데이터와 상세 데이터 병합
            _detailedBookData = {...widget.bookData!, ...detailedData};
          } else {
            _detailedBookData = widget.bookData;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('도서 상세 정보 로드 실패: $e');
      }

      if (mounted) {
        setState(() {
          _detailedBookData = widget.bookData;
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bookData == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            '도서 정보',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text('도서 정보를 불러올 수 없습니다.'),
        ),
      );
    }

    // 상세 데이터 또는 기본 데이터 사용
    final bookData = _detailedBookData ?? widget.bookData!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '도서 정보',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : BookInfoContent(
        bookData: bookData,
        tabController: _tabController,
      ),
      bottomNavigationBar: const BookBottomNavigationBar(),
    );
  }
}

class BookInfoContent extends StatelessWidget {
  final Map<String, dynamic> bookData;
  final TabController tabController;

  const BookInfoContent({
    super.key,
    required this.bookData,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          // 책 제목
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                bookData['title'] ?? '제목 없음',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF5A5959),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 책 이미지
          Center(
            child: Container(
              width: 170,
              height: 238,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
                image: DecorationImage(
                  image: NetworkImage(
                      bookData['coverUrl'] ?? 'https://via.placeholder.com/170x238?text=No+Cover'
                  ),
                  fit: BoxFit.cover,
                  onError: (_, __) {
                    if (kDebugMode) {
                      print('이미지 로드 실패');
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 저자 정보
          Center(
            child: Text(
              _buildAuthorText(),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 1.67,
              ),
            ),
          ),

          // 탭 섹션
          const SizedBox(height: 20),
          BookInfoTabs(tabController: tabController),

          // 탭 콘텐츠
          SizedBox(
            height: 300, // 고정 높이 설정, 필요에 따라 조정
            child: TabBarView(
              controller: tabController,
              children: [
                // 상세 정보 탭
                _buildDetailsTab(),

                // 리뷰 탭 (미구현)
                const Center(
                  child: Text('리뷰 기능은 준비 중입니다.'),
                ),
              ],
            ),
          ),

          // 도서 DB
          Padding(
            padding: const EdgeInsets.only(top: 20, right: 20, bottom: 20),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '도서 DB: ${bookData['dataSource'] ?? '알라딘'}',
                style: const TextStyle(
                  color: Color(0xFF4C4C4C),
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 저자 정보 텍스트 생성
  String _buildAuthorText() {
    String authorText = bookData['author'] ?? '저자 미상';

    // 번역자 정보가 있는 경우 추가
    if (bookData['translator'] != null && bookData['translator'].toString().isNotEmpty) {
      authorText += ' · ${bookData['translator']} 번역';
    }

    return authorText;
  }

  // 상세 정보 탭 내용
  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 책 소개
          const Text(
            '책 소개',
            style: TextStyle(
              color: Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            bookData['description'] ?? '책 소개가 없습니다.',
            style: const TextStyle(
              color: Color(0xFF4C4C4C),
              fontSize: 12,
              height: 1.67,
            ),
          ),
          const SizedBox(height: 20),

          // 출판사 정보
          BookInfoItem(title: '출판사', value: bookData['publisher'] ?? '정보 없음'),
          const SizedBox(height: 10),

          // ISBN 정보
          BookInfoItem(title: 'ISBN', value: bookData['isbn'] ?? '정보 없음'),
          const SizedBox(height: 10),

          // 페이지 정보
          BookInfoItem(title: '페이지',
              value: bookData['itemPage'] != null && bookData['itemPage'] != 0
                  ? '${bookData['itemPage']}p'
                  : '정보 없음'),
          const SizedBox(height: 10),

          // 추가: 출판일
          if (bookData['pubDate'] != null)
            BookInfoItem(title: '출판일', value: bookData['pubDate']),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class BookInfoTabs extends StatelessWidget {
  final TabController tabController;

  const BookInfoTabs({
    super.key,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 탭 버튼들
        TabBar(
          controller: tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          tabs: const [
            Tab(text: '상세 정보'),
            Tab(text: '리뷰'),
          ],
        ),
      ],
    );
  }
}

class BookInfoItem extends StatelessWidget {
  final String title;
  final String value;

  const BookInfoItem({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF4C4C4C),
            fontSize: 12,
            height: 1.67,
          ),
        ),
      ],
    );
  }
}

class BookBottomNavigationBar extends StatelessWidget {
  const BookBottomNavigationBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE8E7E7), width: 1),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          BottomNavItem(label: '타이머', isSelected: false),
          BottomNavItem(label: '챌린지', isSelected: false),
          BottomNavItem(label: '홈', isSelected: false),
          BottomNavItem(label: '서재', isSelected: true),
          BottomNavItem(label: '프로필', isSelected: false),
        ],
      ),
    );
  }
}

class BottomNavItem extends StatelessWidget {
  final String label;
  final bool isSelected;

  const BottomNavItem({
    super.key,
    required this.label,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 여기에 아이콘 추가 가능
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : const Color(0xFF929292),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}