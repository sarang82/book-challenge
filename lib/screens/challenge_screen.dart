import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  int _selectedIndex = 1; // 챌린지 화면은 인덱스 1

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
        // 이미 챌린지 화면이므로 아무 작업 안함
          break;
        case 2:
        // 홈 화면으로 이동
          Navigator.pushReplacementNamed(context, '/home');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('독서 챌린지'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          '챌린지 화면 개발 중입니다',
          style: TextStyle(fontSize: 18),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}