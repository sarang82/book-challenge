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

// Firebase에서 독서 기록 불러오기
  Future<void> _loadUserReadingLog() async {
    if (user == null) return;
    final snapshot = await _firestore.collection('reading_logs').doc(user!.uid).get();

    if (snapshot.exists) {
      final Map<String, dynamic> logs = snapshot.data()?['log'] ?? {};
      print("[READING_LOG] Raw Firestore Data: $logs"); // Firestore 원본 데이터

      setState(() {
        // 파싱
        _readingLog = logs.map((key, value) {
          try {
            // "2025-4-5" -> DateTime(2025, 4, 5) 변환
            final parts = key.split('-');
            final year = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final day = int.parse(parts[2]);
            final parsedDate = DateTime(year, month, day);

            print("[READING_LOG] Parsed Date: $parsedDate, Value: $value"); // 파싱된 데이터
            return MapEntry(parsedDate, value as int);
          } catch (e) {
            print("[READING_LOG] Parsing Error: $e");
            return MapEntry(DateTime(1900), 0); // 파싱 실패한 항목 무시
          }
        })
          ..removeWhere((key, value) => key.year == 1900); // 잘못된 항목 제거

        // 최종 변환 결과 확인
        print("[READING_LOG] Final _readingLog: $_readingLog");
      });
    }
  }




  // 누적 시간 저장
  Future<void> _saveReadingLog(int seconds) async {
    if (user == null) return;
    DateTime now = DateTime.now();
    DateTime key = DateTime(now.year, now.month, now.day);

    _readingLog[key] = (_readingLog[key] ?? 0) + seconds;

    final log = {
      for (var e in _readingLog.entries)
        '${e.key.year}-${e.key.month.toString().padLeft(2, '0')}-${e.key.day.toString().padLeft(2, '0')}': e.value,
    };

    await _firestore.collection('reading_logs').doc(user!.uid).set({'log': log});
  }

  void _onItemTapped(int index) {
    if (widget.onTabChanged != null) widget.onTabChanged!(index);
    if (index != widget.currentIndex) {
      final route = ['/timer', '/challenge', '/home', '/library', '/profile'][index];
      Navigator.pushReplacementNamed(context, route);
    }
  }

  // 누적 시간에 따른 색상
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

    DateTime todayKey = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    int todaySeconds = _readingLog[todayKey] ?? 0;
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
          labelColor: Colors.black,
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
                        await _loadUserReadingLog(); // 업데이트 반영
                        setState(() {});
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
                        backgroundColor: Colors.blue[500]!.withOpacity(0.7),
                        foregroundColor: Colors.black,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(24),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Text(
                  "${totalToday ~/ 3600}시간 ${(totalToday % 3600) ~/ 60}분",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
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
                // 이번 달 누적 시간
                Builder(
                  builder: (context) {
                    final now = DateTime.now();
                    final thisMonthLogs = _readingLog.entries.where((e) {
                      final entryDate = DateTime(e.key.year, e.key.month, e.key.day);
                      final today = DateTime(now.year, now.month);
                      return entryDate.year == today.year && entryDate.month == today.month;
                    });

                    final totalSeconds = thisMonthLogs.fold(0, (sum, e) => sum + e.value);
                    print("[READING_LOG] 이번달 누적 시간: $totalSeconds 초, Logs: $thisMonthLogs"); // 누적 시간 디버그

                    return Text(
                      "${totalSeconds ~/ 3600}시간 ${(totalSeconds % 3600) ~/ 60}분 독서했어요.",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    );
                  },
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