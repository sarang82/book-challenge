import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/bottom_nav_bar.dart';
import '../providers/timer_provider.dart';
import 'package:table_calendar/table_calendar.dart';

class TimerScreen extends StatefulWidget {
  final Function(int)? onTabChanged;
  final int currentIndex;

  const TimerScreen({
    super.key,
    this.onTabChanged,
    this.currentIndex = 0,
  });

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<DateTime, int> _readingLog = {};
  late DateTime _selectedDay;
  final user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.currentIndex);
    _selectedDay = DateTime.now();
    _loadUserReadingLog();
  }

  // Firebase에서 독서 기록을 가져오는 메서드
  Future<void> _loadUserReadingLog() async {
    if (user == null) return;
    final snapshot = await _firestore.collection('reading_logs').doc(user!.uid).get();
    if (snapshot.exists) {
      final Map<String, dynamic> logs = snapshot.data()?['log'] ?? {};
      setState(() {
        _readingLog = logs.map((key, value) {
          final parts = key.split('-');
          // 월과 일이 1자리일 때 2자리로 맞춰주기 위해 padLeft 사용
          final year = int.parse(parts[0]);
          final month = int.parse(parts[1].padLeft(2, '0'));
          final day = int.parse(parts[2].padLeft(2, '0'));

          return MapEntry(DateTime(year, month, day), value as int);
        });
      });
    }
  }


  // 독서 기록을 Firebase에 저장하는 메서드
  Future<void> _saveReadingLog(int seconds) async {
    if (user == null) return;
    DateTime key = DateTime.now();
    key = DateTime(key.year, key.month, key.day);
    _readingLog[key] = (_readingLog[key] ?? 0) + seconds;

    final log = {
      for (var e in _readingLog.entries)
        '${e.key.year}-${e.key.month}-${e.key.day}': e.value
    };

    await _firestore.collection('reading_logs').doc(user!.uid).set({'log': log});
  }

  // 탭 변경 시 네비게이션
  void _onItemTapped(int index) {
    if (widget.onTabChanged != null) widget.onTabChanged!(index);
    if (index != widget.currentIndex) {
      final route = ['/timer', '/challenge', '/home', '/library', '/profile'][index];
      Navigator.pushReplacementNamed(context, route);
    }
  }

  // 독서 시간에 따른 색상 반환
  Color _getColorBasedOnMinutes(int minutes) {
    if (minutes == 0) return Colors.transparent;
    if (minutes >= 180) return Colors.blue[900]!;
    if (minutes >= 90) return Colors.blue[700]!;
    if (minutes >= 60) return Colors.blue[500]!;
    if (minutes >= 30) return Colors.blue[300]!;
    return Colors.blue[100]!;
  }

  @override
  Widget build(BuildContext context) {
    final timerProvider = Provider.of<TimerProvider>(context);

    int todaySeconds = _readingLog[DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)] ?? 0;
    int displaySeconds = timerProvider.seconds;
    int totalToday = todaySeconds + displaySeconds;

    String formattedTime = "${(displaySeconds ~/ 3600).toString().padLeft(2, '0')}:"
        "${((displaySeconds % 3600) ~/ 60).toString().padLeft(2, '0')}:"
        "${(displaySeconds % 60).toString().padLeft(2, '0')}";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('타이머'),
        centerTitle: true,
        bottom: TabBar(
          labelColor: Colors.black,            // 선택된 탭 글씨 색
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          controller: _tabController,
          tabs: const [Tab(text: '타이머'), Tab(text: '달력')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 타이머 화면
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(formattedTime, style: const TextStyle(fontSize: 48)),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: timerProvider.isRunning
                          ? () async {
                        timerProvider.stop();
                        await _saveReadingLog(timerProvider.seconds);
                        timerProvider.reset();
                        _loadUserReadingLog(); // UI 갱신
                      }
                          : null,
                      child: const Text('중지'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCDCACA),
                        foregroundColor: Colors.black,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(24),
                      ),
                    ),
                    const SizedBox(width: 60),
                    ElevatedButton(
                      onPressed: timerProvider.isRunning ? null : timerProvider.start,
                      child: const Text('시작'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFE232),
                        foregroundColor: Colors.black,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(24),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Text("오늘 나는\n${totalToday ~/ 3600}시간 ${(totalToday % 3600) ~/ 60}분\n독서했어요.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // 달력 화면
          SingleChildScrollView(
            child: Column(
              children: [
                TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _selectedDay,
                  selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                    });
                  },
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, date, _) {
                      final key = DateTime(date.year, date.month, date.day);
                      final minutes = (_readingLog[key] ?? 0) ~/ 60;
                      return Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getColorBasedOnMinutes(minutes),
                        ),
                        alignment: Alignment.center,
                        child: Text('${date.day}'),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                // 이번달 독서 시간 계산 및 표시
                Text(
                  "이번달 나는?\n총 ${_readingLog.entries.where((e) => e.key.month == _selectedDay.month).fold(0, (sum, e) => sum + e.value) ~/ 3600}시간 "
                      "${_readingLog.entries.where((e) => e.key.month == _selectedDay.month).fold(0, (sum, e) => sum + e.value) % 3600 ~/ 60}분 독서했어요.",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: widget.currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
