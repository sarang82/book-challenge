import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/bottom_nav_bar.dart';
import '../screens/mission_add_screen.dart';

class MissionScreen extends StatefulWidget {
  const MissionScreen({super.key});

  @override
  _MissionScreenState createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {
  int _selectedIndex = 1;

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

  Future<List<Map<String, dynamic>>> fetchOngoingMissions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('missions')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'ongoing')
        .get();

    return snapshot.docs.map((doc) => {
      ...doc.data(),
      'id': doc.id
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchCompletedMissions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('missions')
        .where('userId', isEqualTo: user.uid)
        .where('status', whereIn: ['completed', 'failed'])
        .get();

    return snapshot.docs.map((doc) {
      var data = doc.data();
      return {
        ...data,
        'id': doc.id,
      };
    }).toList();
  }

  Future<void> updateMissionStatus(String missionId, String status) async {
    await FirebaseFirestore.instance
        .collection('missions')
        .doc(missionId)
        .update({'status': status});
    setState(() {});
  }

  Widget _buildOngoingMissionsView() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchOngoingMissions(),
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
          separatorBuilder: (context, index) => const Divider(color: Colors.grey, thickness: 1, height: 1),
          itemBuilder: (context, index) {
            final mission = missions[index];
            return ListTile(
              leading: Image.asset('assets/images/Sea_otter.png', width: 40, height: 40),
              title: Text(mission['title'] ?? '제목 없음'),
              subtitle: Text(mission['description'] ?? ''),
              trailing: Row(
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
            );
          },
        );
      },
    );
  }

  Widget _buildCompletedMissionsView() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchCompletedMissions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyMissionView("아직 완료한 미션이 없어요.\n지금 시작해보세요!");
        }

        final missions = snapshot.data!;
        return ListView.separated(
          itemCount: missions.length,
          separatorBuilder: (context, index) =>
          const Divider(color: Colors.grey, thickness: 1, height: 1),
          itemBuilder: (context, index) {
            final mission = missions[index];
            final isFailed = mission['status'] == 'failed';

            return ListTile(
              leading: Image.asset(
                isFailed
                    ? 'assets/images/Sea_otter.png'
                    : 'assets/images/Prize.png',
                width: 40,
                height: 40,
              ),
              title: Text(
                mission['title'] ?? '제목 없음' + (isFailed ? ' (실패)' : ''),
                style: TextStyle(color:Colors.black),
              ),
              subtitle: Text(mission['description'] ?? ''),
            );
          },
        );
      },
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
                        MaterialPageRoute(builder: (context) => const MissionAddScreen()),
                      );
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MissionAddScreen()),
          );
        },
        backgroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),

    );
  }
}