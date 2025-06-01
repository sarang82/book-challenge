import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/bottom_nav_bar.dart';
import '../screens/mission_add_screen.dart';

class MissionScreen extends StatefulWidget {
  const MissionScreen({super.key});

  @override
  _MissionScreenState createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {
  int _selectedIndex = 1;
  bool _isSortedByNewest = true;

  Future<List<Map<String, dynamic>>>? _ongoingMissionsFuture;

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });

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
    _loadOngoingMissions();
  }


  void _loadOngoingMissions() {
    _ongoingMissionsFuture = fetchOngoingMissions();
  }

  Future<List<Map<String, dynamic>>> fetchOngoingMissions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('missions')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'ongoing')
        .get();

    final List<Map<String, dynamic>> validMissions = [];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final startDate = (data['startDate'] as Timestamp).toDate();
      final now = DateTime.now();

      final isExpired = now.year > startDate.year ||
          now.month > startDate.month ||
          now.day > startDate.day;

      if (isExpired) {
        // 하루가 지났으면 자동 실패 처리
        await FirebaseFirestore.instance
            .collection('missions')
            .doc(doc.id)
            .update({'status': 'failed'});
      } else {
        validMissions.add({
          ...data,
          'id': doc.id,
        });
      }
    }

    return validMissions;
  }

  Future<List<Map<String, dynamic>>> fetchCompletedMissions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('missions')
        .where('userId', isEqualTo: user.uid)
        .where('status', whereIn: ['completed', 'failed'])
        .get();

    final missions = snapshot.docs.map((doc) {
      var data = doc.data();
      return {
        ...data,
        'id': doc.id,
      };
    }).toList();

    return missions;
  }

  Future<void> updateMissionStatus(String missionId, String status) async {
    await FirebaseFirestore.instance
        .collection('missions')
        .doc(missionId)
        .update({'status': status});
    setState(() {
      _loadOngoingMissions(); // 상태 변경 후에도 reload
    });
  }

  Widget _buildOngoingMissionsView() {

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _ongoingMissionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyMissionView("아직 진행 중인 미션이 없어요.\n지금 시작해보세요!");
        }

        final missions = snapshot.data!;
        return ListView.separated(
          itemCount: missions.length,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          separatorBuilder: (context, index) => const SizedBox(height: 20),
          itemBuilder: (context, index) {
            final mission = missions[index];
            final date = (mission['startDate'] as Timestamp?)?.toDate() ?? DateTime.now();
            final formattedDate = "${date.year}. ${date.month.toString().padLeft(2, '0')}. ${date.day.toString().padLeft(2, '0')}";

            return Column(
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
                      child: Center(
                        child: Image.asset(
                          'assets/images/Sea_otter.png',
                          width: 70,
                          height: 70,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            mission['title'] ?? '제목 없음',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "미션 진행 중이에요!",
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.black),
                          onPressed: () => updateMissionStatus(mission['id'], 'completed'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black),
                          onPressed: () => updateMissionStatus(mission['id'], 'failed'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: Colors.grey.shade300, height: 1),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCompletedMissionsView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isSortedByNewest = !_isSortedByNewest;
                  });
                },
                icon: Icon(_isSortedByNewest
                    ? Icons.keyboard_arrow_down_outlined
                    : Icons.keyboard_arrow_up_outlined),
                label: Text(_isSortedByNewest ? "최신순" : "오래된순"),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: fetchCompletedMissions(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyMissionView("아직 완료한 미션이 없어요.\n지금 시작해보세요!");
              }

              final missions = snapshot.data!;

              missions.sort((a, b) {
                final dateA = (a['endDate'] as Timestamp?)?.toDate() ??
                    (a['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime(0);
                final dateB = (b['endDate'] as Timestamp?)?.toDate() ??
                    (b['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime(0);

                return _isSortedByNewest
                    ? dateB.compareTo(dateA)
                    : dateA.compareTo(dateB);
              });

              return ListView.separated(
                itemCount: missions.length,
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                separatorBuilder: (context, index) => const SizedBox(height: 20),
                itemBuilder: (context, index) {
                  final mission = missions[index];
                  final isFailed = mission['status'] == 'failed';
                  final date = (mission['endDate'] as Timestamp?)?.toDate() ??
                      (mission['createdAt'] as Timestamp?)?.toDate();
                  final formattedDate = date != null
                      ? "${date.year}. ${date.month.toString().padLeft(2, '0')}. ${date.day.toString().padLeft(2, '0')}"
                      : "";

                  return Column(
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
                            child: Center(
                              child: Image.asset(
                                isFailed
                                    ? 'assets/images/Sea_otter.png'
                                    : 'assets/images/Prize.png',
                                width: 70,
                                height: 70,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  mission['title'] ?? '제목 없음',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isFailed
                                      ? "미션이 종료됐어요."
                                      : "미션을 완수했어요!",
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(color: Colors.grey.shade300, height: 1),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyMissionView(String message) {
    final parts = message.split('시작');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/Sea_otter.png', width: 80, color: Colors.grey),
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
                            builder: (context) => const MissionAddScreen()),
                      ).then((value) {
                        if (value == true) {
                          setState(() {
                            _loadOngoingMissions(); // 시작 텍스트 클릭 후 돌아왔을 때 reload
                          });
                        }
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          '미션',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MissionAddScreen()),
              ).then((value) {
                if (value == true) {
                  setState(() {
                    _loadOngoingMissions(); // 미션 등록 화면에서 돌아왔을 때 reload
                  });
                }
              });
            },
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              labelColor: Colors.black,
              indicatorColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: '진행 중'),
                Tab(text: '완료'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildOngoingMissionsView(),
                  _buildCompletedMissionsView(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
