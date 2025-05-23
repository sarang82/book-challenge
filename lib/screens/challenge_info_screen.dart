import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/challenge_service.dart'; // Challenge 모델 경로에 맞게 수정하세요.

class ChallengeInfoScreen extends StatefulWidget {
  final Challenge challenge;
  const ChallengeInfoScreen({super.key, required this.challenge});

  @override
  _ChallengeInfoScreenState createState() => _ChallengeInfoScreenState();
}

class _ChallengeInfoScreenState extends State<ChallengeInfoScreen> {
  late int pagesRead;
  //페이지 저장을 위해
  final ChallengeService _challengeService = ChallengeService();
  late String userId; // 실제 사용자 ID
  //닉네임
  String? _nickname;


  @override
  void initState() {
    super.initState();
    pagesRead = widget.challenge.pagesRead;

    final currentUser = FirebaseAuth.instance.currentUser;
    _loadNickname();

    if (currentUser != null) {
      userId = currentUser.uid;
      _loadTodayPages();
    } else {
      // 로그인 정보 없으면 로그인 화면으로 이동
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/home');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('챌린지',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                widget.challenge.coverUrl,
                width: 150,
                height: 220,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.challenge.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.challenge.startDate.toLocal().toString().split(' ')[0]} - ${widget.challenge.endDate.toLocal().toString().split(' ')[0]}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 12),
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
                        _buildTodayTab(),
                        _buildHistoryTab(widget.challenge.id, userId, _challengeService),
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

  Widget _buildTodayTab() {

    //한국 시간으로 보정
    final nowKST = DateTime.now().toUtc().add(const Duration(hours: 9));
    final formattedDateKST = "${nowKST.year}-${nowKST.month.toString().padLeft(2, '0')}-${nowKST.day.toString().padLeft(2, '0')}";
    
    double progress = widget.challenge.itemPage == 0
        ? 0
        : pagesRead / widget.challenge.itemPage;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (pagesRead == 0)
          const Text('아직 오늘의 기록이 없어요...', style: TextStyle(fontSize: 16))
        else
          Text(
            '$_nickname님, 오늘 $pagesRead 페이지를 읽었어요! 😁',
            style: const TextStyle(fontSize: 12),
          ),
        const SizedBox(height: 20),
        Container(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 20,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${(progress * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '$pagesRead / ${widget.challenge.itemPage} page',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () async {
            final controller = TextEditingController();

            // 1) 사용자 입력 받는 다이얼로그 띄우기
            int? inputPages = await showDialog<int>(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('오늘 읽은 페이지 수 입력'),
                  content: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '숫자 입력',
                    ),
                  ),
                  actions: [
                    TextButton(
                      child: const Text('취소'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    TextButton(
                      child: const Text('저장'),
                      onPressed: () async {
                        final input = int.tryParse(controller.text);
                        if (input != null && input > 0) {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('확인'),
                                content: const Text('한 번 입력하면 수정할 수 없습니다. 계속하시겠습니까?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('취소'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('확인'),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirm == true) {
                            Navigator.of(context).pop(input);  // 확인하면 입력값 반환
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('올바른 숫자를 입력해주세요')),
                          );
                        }
                      },
                    ),
                  ],
                );
              },
            );

            // 2) 여기서 inputPages가 오늘 입력한 값
            if (inputPages != null && inputPages > 0) {
              final userId = FirebaseAuth.instance.currentUser?.uid;
              if (userId != null) {
                // 3) 기존 오늘 읽은 페이지 불러오기 (비동기)
                final todayPages = await _challengeService.getTodayPagesRead(widget.challenge.id, userId);

                // 4) 기존 값과 새로 입력한 값을 더함
                final newTodayPages = todayPages + inputPages;

                // 5) 합산된 값을 저장
                await _challengeService.saveTodayPagesRead(widget.challenge.id, userId, newTodayPages);

                // 6) 상태 업데이트 (화면에 표시할 페이지 수 갱신)
                setState(() {
                  pagesRead = newTodayPages;
                });
              }
            }
          },
          child: const Text('오늘 읽은 페이지 입력'),
        ),
      ],
    );
  }

  Widget _buildHistoryTab(String challengeId, String userId, ChallengeService challengeService) {
    return HistoryTab(
      challengeId: challengeId,
      userId: userId,
      challengeService: challengeService,
    );
  }


  void _loadTodayPages() async {
    if (userId.isEmpty) return;  // 안전하게 처리
    final pages = await _challengeService.getTodayPagesRead(widget.challenge.id, userId);
    setState(() {
      pagesRead = pages;
    });
  }

  Future<void> _loadNickname() async {
    final nickname = await AuthService().getNickname();
    setState(() {
      _nickname = nickname ?? '사용자';
    });
  }
}

// HistoryTab 위젯 추가

class HistoryTab extends StatefulWidget {
  final String challengeId;
  final String userId;
  final ChallengeService challengeService;

  const HistoryTab({
    Key? key,
    required this.challengeId,
    required this.userId,
    required this.challengeService,
  }) : super(key: key);

  @override
  _HistoryTabState createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  late Future<List<DailyPageRead>> _pagesReadFuture;

  @override
  void initState() {
    super.initState();
    _pagesReadFuture = widget.challengeService.getAllPagesRead(widget.challengeId, widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DailyPageRead>>(
      future: _pagesReadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('에러가 발생했습니다: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('기록된 페이지가 없습니다.'));
        } else {
          final pagesReadList = snapshot.data!;
          return ListView.builder(
            itemCount: pagesReadList.length,
            itemBuilder: (context, index) {
              final item = pagesReadList[index];
              return ListTile(
                title: Text(item.date),
                subtitle: Text('${item.pagesRead} 페이지 읽음'),
              );
            },
          );
        }
      },
    );
  }
}
