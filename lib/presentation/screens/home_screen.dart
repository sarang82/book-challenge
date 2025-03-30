import 'package:flutter/material.dart';

void main() {
  runApp(const FigmaToCodeApp());
}

class FigmaToCodeApp extends StatelessWidget {
  const FigmaToCodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Container(
          height: 36,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              SizedBox(width: 10),
              Icon(Icons.search, color: Colors.grey),
              SizedBox(width: 5),
              Text(
                '제목 또는 저자를 입력하세요.',
                style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.normal),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_scanner, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          _buildMainCard(),
          const SizedBox(height: 20),
          Expanded(child: _buildImageSection(screenWidth)),
          _buildBottomNavBar(),
        ],
      ),
    );
  }
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
          // 헤더 부분 (해달 이미지와 텍스트)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
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
                  children: const [
                    Text(
                      '오늘의 독서 날씨: 맑음 ☀️',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '개구리님,\n같이 책을 읽어볼까요?',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 25),
          // 구분선 제거

          // 챌린지 현황 부분
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
                width: 240, // 진행률에 맞게 너비 조정 (78%)
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.blue[300],
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: const [
              Text('78%', style: TextStyle(color: Colors.black)),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              color: Color(0xFFFEE798), // 노란색 버튼
              borderRadius: BorderRadius.circular(25),
            ),
            child: Center(
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
    // 실제 이미지 경로 적용
    decoration: BoxDecoration(
      image: const DecorationImage(
        image: AssetImage(
          'assets/images/wave.png'
        ),
        fit: BoxFit.cover,
      ),
    ),
  );
}

Widget _buildBottomNavBar() {
  return BottomNavigationBar(
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
    currentIndex: 2, // 홈 선택
  );
}