import 'package:flutter/material.dart';
import '../services/challenge_service.dart'; // Challenge 모델 경로에 맞게 수정하세요.

class ChallengeInfoScreen extends StatelessWidget {
  final Challenge challenge;
  const ChallengeInfoScreen({super.key, required this.challenge});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('챌린지', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                challenge.coverUrl,
                width: 150,
                height: 220,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            challenge.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${challenge.startDate.toLocal().toString().split(' ')[0]} - ${challenge.endDate.toLocal().toString().split(' ')[0]}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          // 탭: 오늘의 여정 / 히스토리
          DefaultTabController(
            length: 2,
            child: Expanded(
              child: Column(
                children: [
                  const TabBar(
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.black,
                    tabs: [
                      Tab(text: '오늘의 여정'),
                      Tab(text: '히스토리'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildTodayTab(challenge),
                        _buildHistoryTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayTab(Challenge challenge) {
    double progress = challenge.itemPage == 0
        ? 0
        : challenge.pagesRead / challenge.itemPage;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('아직 오늘의 기록이 없어요...', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 20),
        SizedBox(
          height: 140,
          width: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 10,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${(progress * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '${challenge.pagesRead} / ${challenge.itemPage} page',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: const [
            ElevatedButton(onPressed: null, child: Text('오늘 읽은 페이지 입력')),
            ElevatedButton(onPressed: null, child: Text('오늘의 미션 시작')),
          ],
        )
      ],
    );
  }

  Widget _buildHistoryTab() {
    return const Center(child: Text('히스토리 기록이 없습니다.'));
  }
}
