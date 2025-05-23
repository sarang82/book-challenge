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

  final ChallengeService _challengeService = ChallengeService();
  List<Challenge> _challenges = [];

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
      switch (index) {
        case 0: Navigator.pushReplacementNamed(context, '/timer'); break;
        case 1: break;
        case 2: Navigator.pushReplacementNamed(context, '/home'); break;
        case 3: Navigator.pushReplacementNamed(context, '/library'); break;
        case 4: Navigator.pushReplacementNamed(context, '/profile'); break;
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
    });
  }

  Widget _buildChallengeCard(Challenge challenge) {
    final imageUrl = challenge.coverUrl;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          width: 80,
          height: 150,
          fit: BoxFit.contain,
          cacheWidth: 200,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: 80,
              height: 150,
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 80,
              height: 110,
              color: Colors.grey[300],
              child: const Icon(Icons.book, size: 30, color: Colors.grey),
            );
          },
        ),
      ),
      title: Text(
        challenge.title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //const SizedBox(height: 4),
          Text(
            '<${challenge.bookTitle}>',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            challenge.description,
            style: const TextStyle(fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '기간: ${challenge.startDate.toLocal().toString().split(' ')[0]} ~ ${challenge.endDate.toLocal().toString().split(' ')[0]}',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),

        ],

      ),

      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChallengeInfoScreen(challenge: challenge),
          ),
        );
      },


    );




  }

  @override
  Widget build(BuildContext context) {
    final ongoing = _challenges.where((c) => c.endDate.isAfter(DateTime.now())).toList();
    final completed = _challenges.where((c) => c.endDate.isBefore(DateTime.now())).toList();

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
          ongoing.isEmpty
              ? const Center(child: Text('진행 중인 챌린지가 없습니다.'))
              : ListView.separated(
            itemCount: ongoing.length,
            itemBuilder: (context, index) {
              return _buildChallengeCard(ongoing[index]);
            },
            separatorBuilder: (context, index) => const Divider(
              thickness: 0.5,
              height: 1,
              color: Colors.grey,
            ),
          ),
          completed.isEmpty
              ? const Center(child: Text('완료한 챌린지가 없습니다.'))
              : ListView.separated(
            itemCount: completed.length,
            itemBuilder: (context, index) {
              return _buildChallengeCard(completed[index]);
            },
            separatorBuilder: (context, index) => const Divider(
              thickness: 0.5,
              height: 1,
              color: Colors.grey,
            ),
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
