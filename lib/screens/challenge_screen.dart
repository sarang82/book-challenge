import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/challenge_service.dart';
import 'challenge_info_screen.dart';
import 'challenge_add_screen.dart'; // 챌린지 추가 화면 임포트

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

  final ChallengeService _challengeService = ChallengeService();
  List<Challenge> _challenges = [];

  bool _isBeforeToday(DateTime d) =>
      d.toLocal().difference(DateTime.now()).inDays < 0;

  bool _isChallengeFailed(Challenge c) =>
      c.itemPage == 0
          ? true
          : c.pagesRead < c.itemPage;

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
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChallengeInfoScreen(challenge: challenge),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
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
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.book,
                        size: 30,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                            : challenge.bookTitle,
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

  Widget _buildEmptyChallengeView(String message) {
    final parts = message.split('시작');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/Sea_otter.png',
            width: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(color: Colors.grey, fontSize: 16),
              children: [
                TextSpan(text: parts[0]),
                TextSpan(
                  text: '시작',
                  style: const TextStyle(
                    color: Colors.grey,
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.bold,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChallengeAddScreen(),
                        ),
                      ).then((value) {
                        if (value == true) _loadInitialData();
                      });
                    },
                ),
                TextSpan(text: parts.length > 1 ? parts[1] : ''),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ongoing = _challenges.where((c) =>
    (c.pagesRead < c.itemPage) && !_isBeforeToday(c.endDate)
    ).toList();
    final completed = _challenges.where((c) =>
    (c.pagesRead >= c.itemPage) || _isBeforeToday(c.endDate)
    ).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          '챌린지',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
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
          // 진행 중 탭
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
                      icon: Icon(
                        _isLatestFirst
                            ? Icons.keyboard_arrow_down_outlined
                            : Icons.keyboard_arrow_up_outlined,
                        color: Colors.black87
                      ),
                      label: Text(
                        _isLatestFirst ? '최신순' : '오래된순',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ongoing.isEmpty
                    ? _buildEmptyChallengeView('진행 중인 챌린지가 없어요.\n지금 시작해보세요!')
                    : ListView.separated(
                  itemCount: ongoing.length,
                  itemBuilder: (context, index) =>
                      _buildChallengeCard(ongoing[index]),
                  separatorBuilder: (context, index) =>
                  const SizedBox(height: 12),
                ),
              ),
            ],
          ),
          // 완료 탭
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
                      icon: Icon(
                        _isLatestFirst
                            ? Icons.keyboard_arrow_down_outlined
                            : Icons.keyboard_arrow_up_outlined,
                        color:Colors.black87
                      ),
                      label: Text(
                        _isLatestFirst ? '최신순' : '오래된순',
                        style: TextStyle( color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: completed.isEmpty
                    ? Center(child: Text('완료한 챌린지가 없습니다.'))
                    : ListView.separated(
                  itemCount: completed.length,
                  itemBuilder: (context, index) =>
                      _buildChallengeCard(completed[index], showResult: true),
                  separatorBuilder: (context, index) =>
                  const SizedBox(height: 12),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (i) => _onItemTapped(i),
      ),
    );
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
      switch (index) {
        case 0:
          Navigator.pushReplacementNamed(context, '/timer');
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
}
