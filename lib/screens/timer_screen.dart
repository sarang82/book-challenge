import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  int _selectedIndex = 0; // 타이머 화면은 인덱스 0

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });

      switch (index) {
        case 0:
        // 이미 타이머 화면이므로 아무 작업 안함
          break;
        case 1:
        // 챌린지 화면으로 이동
          Navigator.pushReplacementNamed(context, '/challenge');
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
        title: const Text('독서 타이머',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          '타이머 화면 개발 중입니다',
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