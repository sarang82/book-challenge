import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/challenge_service.dart';

// 챌린지 정보 스크린
class ChallengeInfoScreen extends StatefulWidget {
  final Challenge challenge;
  const ChallengeInfoScreen({super.key, required this.challenge});

  @override
  _ChallengeInfoScreenState createState() => _ChallengeInfoScreenState();
}

class _ChallengeInfoScreenState extends State<ChallengeInfoScreen> {
  late int pagesRead;
  int totalPagesRead = 0;
  final ChallengeService _challengeService = ChallengeService();
  late String userId;
  String? _nickname;

  @override
  void initState() {
    super.initState();
    // 초기 pagesRead는 Challenge 문서의 pagesRead 필드를 받아옴
    pagesRead = widget.challenge.pagesRead;

    final currentUser = FirebaseAuth.instance.currentUser;
    _loadNickname();

    if (currentUser != null) {
      userId = currentUser.uid;
      _loadTodayPages();
      _loadPageReads();
    } else {
      // 로그인 정보가 없으면 홈으로 돌아가기
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/home');
      });
    }
  }

  void _loadTodayPages() async {
    if (userId.isEmpty) return;
    final pages = await _challengeService.getTodayPagesRead(
      widget.challenge.id,
      userId,
    );
    setState(() {
      pagesRead = pages; // 오늘까지 누적 페이지(덮어쓰기 방식)
    });
  }

  Future<void> _loadPageReads() async {
    if (userId.isEmpty) return;
    final total = await _challengeService.getTotalPagesRead(
      widget.challenge.id,
      userId,
    );
    setState(() {
      totalPagesRead = total; // 전체 누적 페이지
    });
  }

  Future<void> _loadNickname() async {
    final nickname = await AuthService().getNickname();
    setState(() {
      _nickname = nickname ?? '사용자';
    });
  }

  @override
  Widget build(BuildContext context) {
    // 전체 목표 페이지 수 대비 진행률 계산
    double progress = totalPagesRead / widget.challenge.itemPage;
    if (progress > 1.0) progress = 1.0;

    // KST 기준 현재 시각
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    final nowDateOnly = DateTime(now.year, now.month, now.day);

    final end = widget.challenge.endDate.toUtc().add(const Duration(hours: 9));
    final endDateOnly = DateTime(end.year, end.month, end.day);

    // 1) pagesRead가 목표 페이지 이상
    // 2) 챌린지 종료일이 지났을 때
    final isChallengeCompleted =
        (totalPagesRead == widget.challenge.itemPage) ||
            nowDateOnly.isAfter(endDateOnly);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          '챌린지',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
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
          const SizedBox(height: 8),
          // 챌린지 설명 추가
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              widget.challenge.description,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.challenge.startDate.toLocal().toString().split(' ')[0]} - '
                '${widget.challenge.endDate.toLocal().toString().split(' ')[0]}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          // ────────────────────────────────────────────────────────────────
          // DefaultTabController: "오늘의 여정" vs "히스토리" 탭
          // ────────────────────────────────────────────────────────────────
          DefaultTabController(
            length: 2,
            child: Expanded(
              child: Column(
                children: [
                  TabBar(
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.black,
                    tabs: [
                      Tab(text: isChallengeCompleted ? '완료 정보' : '오늘의 여정'),
                      const Tab(text: '히스토리'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // 첫 번째 탭: 진행 중 (오늘의 여정) or 완료 정보
                        isChallengeCompleted
                            ? _buildFailureOrSuccessTab(progress, isChallengeCompleted)
                            : _buildTodayTab(progress),
                        // 두 번째 탭: 히스토리
                        HistoryTab(
                          challengeId: widget.challenge.id,
                          userId: userId,
                          challengeService: _challengeService,
                        ),
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

  // ────────────────────────────────────────────────────────────────────────
  // "오늘의 여정" (진행 중) 화면
  // ────────────────────────────────────────────────────────────────────────
  Widget _buildTodayTab(double progress) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (pagesRead == 0)
          const Text('아직 오늘의 기록이 없어요...', style: TextStyle(fontSize: 16))
        else
          Text(
            '${_nickname ?? '사용자'}님, 오늘 $pagesRead 페이지를 읽었어요! 😁',
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
                  Text(
                    '${(progress * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalPagesRead / ${widget.challenge.itemPage} page',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
          ),
          onPressed: () async {
            final controller = TextEditingController();

            int? inputPages = await showDialog<int>(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  backgroundColor: Colors.white,
                  title: Text(
                    '오늘 읽은 페이지 수 입력',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.w300
                    ),
                  ),
                  content: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    cursorColor: Colors.blue.shade800,
                    decoration:InputDecoration(
                      hintText: '숫자 입력',
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue.shade700),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      child: Text('취소',),
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue.shade700,
                      ),
                    ),
                    TextButton(
                        child: Text('저장'),
                        onPressed: () {
                          final input = int.tryParse(controller.text);
                          if (input != null && input > 0 && input <= widget.challenge.itemPage) {
                            Navigator.of(context).pop(input);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  input == null || input <= 0
                                      ? '올바른 숫자를 입력해주세요'
                                      : '전체 페이지 수(${widget.challenge.itemPage}) 이상 입력할 수 없습니다',
                                ),
                              ),
                            );
                          }
                        },
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.blue.shade700
                        )
                    ),
                  ],
                );
              },
            );

            if (inputPages != null && inputPages > 0) {
              final userIdNow = FirebaseAuth.instance.currentUser?.uid;
              if (userIdNow != null) {
                // 누적(overwrite) 방식 저장
                await _challengeService.saveTodayPagesRead(
                  widget.challenge.id,
                  userIdNow,
                  inputPages,
                );
                // 저장 후 다시 불러오기
                final newCumulative = await _challengeService.getTodayPagesRead(
                  widget.challenge.id,
                  userIdNow,
                );
                final newTotal = await _challengeService.getTotalPagesRead(
                  widget.challenge.id,
                  userIdNow,
                );
                setState(() {
                  pagesRead = newCumulative;
                  totalPagesRead = newTotal;
                });
              }
            }
          },
          child: Text(
            '오늘 읽은 페이지 입력',
            style: TextStyle(
              color: Colors.blue.shade700,
            ),
          ),
        ),
      ],
    );
  }


  // ────────────────────────────────────────────────────────────────────────
  // "완료 정보" (실패 or 성공) 화면 ─────────────────────────────────────────────
  //
  // Case 2: 실패하지 않고 "성공" (pagesRead ≥ itemPage, 기간 남아있음 or 기간 경과)
  // Case 3: "기간 경과"로 인해 실패 (pagesRead < itemPage, 기간 경과)
  //
  // 두 경우 모두 이 메서드가 호출됩니다. 내부에서 pagesRead와 종료일을 체크하여
  // - Case 2 → "성공" UI
  // - Case 3 → "실패" UI ("과거 진행률 확인" 버튼 포함)
  // ────────────────────────────────────────────────────────────────────────
  Widget _buildFailureOrSuccessTab(double progress, bool isChallengeCompleted) {
    // "완료 성공" (pagesRead ≥ itemPage, 기간 남았든 경과했든 상관없이 모두 성공 간주)
    if (totalPagesRead >= widget.challenge.itemPage) {
      return _buildSuccessTab(progress);
    }

    // "실패" (pagesRead < itemPage & 기간 경과) → _buildFailureTab 반환
    return _buildFailureTab(progress);
  }

  // ────────────────────────────────────────────────────────────────────────
  // 케이스 2 (성공) 전용 위젯 (간단히 🎉 아이콘과 구구절절 성공 메시지)
  // ────────────────────────────────────────────────────────────────────────
  Widget _buildSuccessTab(double progress) {
    if (progress > 1.0) progress = 1.0;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!_showProgressDetails) ...[
              // "성공 메시지" 영역
              const SizedBox(height: 40),
              const Icon(
                Icons.emoji_events,
                size: 100,
                color: Colors.amber,
              ),
              const SizedBox(height: 12),
              const Text(
                '챌린지를 성공적으로 완료하셨습니다!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '총 ${widget.challenge.itemPage}쪽 읽음',
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                '완료 날짜: ${DateTime.now().toLocal().toString().split(' ')[0]}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
            ] else ...[
              // "그래프" 영역 (토글 후 표시)
              const SizedBox(height: 40),
              Container(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 원형 프로그레스바 (크기 140)
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 20,
                        backgroundColor: Colors.grey[300],
                        color: Colors.blue,
                        // valueColor: 제거 → 기본 테마 색상 적용
                      ),
                    ),
                    // 퍼센트 텍스트 + 페이지 정보
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${(progress * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            // color: 제거 → 기본 텍스트 색상 적용
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalPagesRead / ${widget.challenge.itemPage} page',
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            // "과거 진행률 확인" ↔ "뒤로" 버튼
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _showProgressDetails = !_showProgressDetails;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:  Colors.white,
              ),
              child: Text(
                _showProgressDetails ? '뒤로' : '과거 진행률 확인',
                style: TextStyle(
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ────────────────────────────────────────────────────────────────────────
  // 케이스 3 (기간 경과로 인한 실패) 전용 위젯: "챌린지를 완료하지 못했습니다" 메시지 → 접히는 "과거 진행률 확인" 버튼
  // ────────────────────────────────────────────────────────────────────────
  bool _showProgressDetails = false;

  Widget _buildFailureTab(double progress) {
    if (progress > 1.0) progress = 1.0;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!_showProgressDetails) ...[
              const SizedBox(height: 40),
              const Icon(
                Icons.sentiment_dissatisfied,
                size: 100,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              const Text(
                '챌린지를 완료하지 못했습니다.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '기간이 만료되었습니다: ${widget.challenge.endDate.toLocal().toString().split(' ')[0]}',
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                '총 읽은 페이지: $totalPagesRead쪽',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
            ] else ...[
              const SizedBox(height: 40),

              // ───────────────────────────────────────────────────────────
              // 그래프 표시 부분 (140×140 크기로 조정)
              // ───────────────────────────────────────────────────────────
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${(progress * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalPagesRead / ${widget.challenge.itemPage} page',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            // "과거 진행률 확인" / "뒤로" 버튼
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _showProgressDetails = !_showProgressDetails;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:  Colors.white,
              ),
              child: Text(
                _showProgressDetails ? '뒤로' : '과거 진행률 확인',
                style: TextStyle(
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HistoryTab 위젯 (원본과 동일, 페이지 오버라이트 변경 반영됨)
// ─────────────────────────────────────────────────────────────────────────────
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
    _pagesReadFuture = widget.challengeService.getAllPagesRead(
      widget.challengeId,
      widget.userId,
    );
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

              // 오늘 누적
              final todayCumulative = item.cumulativePagesRead;

              // 이전날 누적
              final prevCumulative = (index == 0)
                  ? 0
                  : pagesReadList[index - 1].cumulativePagesRead;

              // 오늘 읽은 분량 = 오늘 누적 - 이전날 누적
              final todayReadPages = todayCumulative - prevCumulative;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.date,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '하루 동안 $todayReadPages쪽을 읽었어요!',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              );
            },
          );
        }
      },
    );
  }
}