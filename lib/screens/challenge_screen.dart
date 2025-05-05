import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/challenge_service.dart';

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

  //챌린지 띄우기
  final ChallengeService _challengeService = ChallengeService();
  List<Challenge> _challenges = [];

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
    final challenges = await _challengeService.getChallenges();

    setState(() {
      _challenges = challenges;
      _isLoading = false;
      _isRefreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    //진행중/완료 나누기
    final ongoing = _challenges
        .where((c) => c.endDate.isAfter(DateTime.now())).toList();
    final completed = _challenges
        .where((c) => c.endDate.isBefore(DateTime.now())).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
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
        children: [
          //진행 중 탭
          ongoing.isEmpty
          ? const Center(child: Text('진행 중인 챌린지가 없습니다.'))
          : ListView.builder(
            itemCount: ongoing.length,
            itemBuilder: (context, index) {
              final challenge = ongoing[index];
              return Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundImage: AssetImage('assets/images/Sea_otter.png'),
                      backgroundColor: Colors.white,
                    ),
                    title: Text(challenge.title),
                    subtitle: Text(challenge.description),
                  ),
                  Divider(), // ListTile 뒤에 구분선 추가
                ],
              );
            },
          ),
          // 완료 탭
          completed.isEmpty
              ? const Center(child: Text('완료한 챌린지가 없습니다.'))
              : ListView.builder(
            itemCount: completed.length,
            itemBuilder: (context, index) {
              final challenge = completed[index];
              return Column(
                children: [
                  ListTile(
                    title: Text(challenge.title),
                    subtitle: Text(challenge.description),
                  ),
                  Divider(), // ListTile 뒤에 구분선 추가
                ],
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}