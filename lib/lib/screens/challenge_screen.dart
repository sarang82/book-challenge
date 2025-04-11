import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 1; // 챌린지 화면은 인덱스 1
  bool _isLoading = true;
  bool _isRefreshing = false;
  late TabController _tabController;

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
      //나중에 수정ㄱㄱ
      _isLoading = false;
      _isRefreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('챌린지',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          tabs: const [
            Tab(text: '진행 중'),
            Tab(text: '완료'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: const [
          //나중에 조건문으로 추가ㄱㄱ
          Center(child: Text('진행 중인 챌린지가 없습니다.')),
          Center(child: Text('완료한 챌린지가 없습니다.')),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}