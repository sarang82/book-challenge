import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  void _showChallengeDropdown(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('미션'),
                onTap: () {
                  Navigator.pop(context); // 모달 닫기
                  Navigator.pushNamed(context, '/mission');
                },
              ),
              ListTile(
                title: const Text('챌린지'),
                onTap: () {
                  Navigator.pop(context); // 모달 닫기
                  Navigator.pushNamed(context, '/challenge');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      currentIndex: currentIndex,
      onTap: (index) {
        if (index == 1) {
          _showChallengeDropdown(context); // 챌린지 탭 누르면 모달
        } else {
          onTap(index); // 나머지는 기본 이동
        }
      },
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