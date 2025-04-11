import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      currentIndex: currentIndex,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.timer), label: '타이머'),
        BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: '챌린지'),
        BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
        BottomNavigationBarItem(icon: Icon(Icons.library_books), label: '서재'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: '프로필'),
      ],
    );
  }
}