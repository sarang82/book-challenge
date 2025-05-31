import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/challenge_service.dart';
import 'challenge_info_screen.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 1;
  bool _isLoading = true;
  bool _isRefreshing = false;
  late TabController _tabController;
  bool _isLatestFirst = true;
  bool _isBeforeToday(DateTime d) =>
      d.toLocal().difference(DateTime.now()).inDays < 0;

  //챌린지 성공/실패
  bool _isChallengeFailed(Challenge c) =>
      c.itemPage == 0                // 책 쪽수 못 받아왔으면 무조건 실패
          ? true
          : c.pagesRead < c.itemPage; // 누적 쪽수 < 총 쪽수 ➡ 실패

  final ChallengeService _challengeService = ChallengeService();
  List<Challenge> _challenges = [];

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
      switch (index) {
        case 0:
          Navigator.pushReplacementNamed(context, '/timer');
          break;
        case 1:
          break;
        case 2:
          Navigator.pushReplacementNamed(context, '/home');
          break;
        case 3:
          Navigator.pushReplacementNamed(context, '/library');
          break;
        case 4:
          Navigator.pushReplacementNamed(context, '/profile');
          break;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (_isRefreshing) return;
    final challenges = await _challengeService.getChallenges();
    setState(() {
      _challenges = challenges;
      _isLoading = false;
      _isRefreshing = false;
      _sortChallenges();
    });
  }

  void _sortChallenges() {
    _challenges.sort((a, b) => _isLatestFirst
        ? b.startDate.compareTo(a.startDate)
        : a.startDate.compareTo(b.startDate));
  }

  Widget _buildChallengeCard(Challenge challenge, {bool showResult = false}) {
    final isFailed = _isChallengeFailed(challenge);
    final date = challenge.endDate;
    final formattedDate = "${date.year}. ${date.month.toString().padLeft(2, '0')}. ${date.day.toString().padLeft(2, '0')}";

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChallengeInfoScreen(challenge: challenge),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 이미지 컨테이너 (가로 100, 세로 100)
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: showResult
                        ? Center(
                      child: Image.asset(
                        isFailed
                            ? 'assets/images/Sea_otter.png'
                            : 'assets/images/Prize.png',
                        width: 70,
                        height: 70,
                        fit: BoxFit.contain,
                      ),
                    )
                        : Image.network(
                      challenge.coverUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.book, size: 30, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 텍스트 컬럼 (가운데 정렬, 미션 화면 스타일과 동일)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        challenge.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        showResult
                            ? (isFailed ? "챌린지가 종료됐어요." : "챌린지를 완수했어요!")
                            : challenge.bookTitle, // 여기 수정됨!
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade300, height: 1),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final ongoing = _challenges.where((c) =>
          (c.pagesRead < c.itemPage) && !_isBeforeToday(c.endDate)
            ).toList();

    // “완료”: (페이지를 다 읽었거나) 또는 (종료일 지남)
    final completed = _challenges.where((c) =>
      (c.pagesRead >= c.itemPage) || _isBeforeToday(c.endDate)
    ).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('챌린지', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
          // 진행 중
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _isLatestFirst = !_isLatestFirst;
                          _sortChallenges();
                        });
                      },
                      icon: Icon(_isLatestFirst ? Icons.keyboard_arrow_down_outlined : Icons.keyboard_arrow_up_outlined),
                      label: Text(_isLatestFirst ? '최신순' : '오래된순'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ongoing.isEmpty
                    ? const Center(child: Text('진행 중인 챌린지가 없습니다.'))
                    : ListView.separated(
                  itemCount: ongoing.length,
                  itemBuilder: (context, index) {
                    return _buildChallengeCard(ongoing[index]);
                  },
                  separatorBuilder: (context, index) => Column(
                    children: [
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // 완료
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _isLatestFirst = !_isLatestFirst;
                          _sortChallenges();
                        });
                      },
                      icon: Icon(_isLatestFirst ? Icons.keyboard_arrow_down_outlined : Icons.keyboard_arrow_up_outlined),
                      label: Text(_isLatestFirst ? '최신순' : '오래된순'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: completed.isEmpty
                    ? const Center(child: Text('완료한 챌린지가 없습니다.'))
                    : ListView.separated(
                  itemCount: completed.length,
                  itemBuilder: (context, index) {
                    return _buildChallengeCard(completed[index], showResult: true);
                  },
                  separatorBuilder: (context, index) => Column(
                    children: [
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
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
