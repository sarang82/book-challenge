import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/bottom_nav_bar.dart';

class TimerScreen extends StatefulWidget {
  final Function(int)? onTabChanged; // optional로 변경
  final int currentIndex; // 기본값 제공

  const TimerScreen({
    super.key,
    this.onTabChanged,
    this.currentIndex = 0,
  });

  @override
  _TimerScreenState createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with SingleTickerProviderStateMixin {
  int _seconds = 0;
  bool _isRunning = false;
  late DateTime _selectedDay;
  Map<DateTime, int> _readingLog = {};
  late TabController _tabController;

  final user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.currentIndex);
    _loadUserReadingLog();
  }

  Future<void> _loadUserReadingLog() async {
    if (user == null) return;
    final uid = user!.uid;
    final snapshot = await _firestore.collection('reading_logs').doc(uid).get();
    if (snapshot.exists) {
      final data = snapshot.data()!;
      final Map<String, dynamic> logs = data['log'] ?? {};
      setState(() {
        _readingLog = logs.map((key, value) {
          final parts = key.split('-').map(int.parse).toList();
          return MapEntry(DateTime(parts[0], parts[1], parts[2]), value as int);
        });
      });
    }
  }

  Future<void> _saveReadingLog() async {
    if (user == null) return;
    final uid = user!.uid;
    final Map<String, int> stringMap = {
      for (var entry in _readingLog.entries)
        '${entry.key.year}-${entry.key.month}-${entry.key.day}': entry.value
    };
    await _firestore.collection('reading_logs').doc(uid).set({'log': stringMap});
  }

  void _startTimer() {
    setState(() {
      _isRunning = true;
    });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!_isRunning) return false;
      setState(() {
        _seconds++;
      });
      return true;
    });
  }

  void _stopTimer() {
    setState(() {
      _isRunning = false;
      DateTime key = DateTime.now();
      key = DateTime(key.year, key.month, key.day);
      _readingLog[key] = (_readingLog[key] ?? 0) + _seconds;
      _seconds = 0;
    });
    _saveReadingLog();
  }

  int _getTodaySeconds() {
    DateTime today = DateTime.now();
    today = DateTime(today.year, today.month, today.day);
    return _readingLog[today] ?? 0;
  }

  int _getMonthlyTotalSeconds() {
    return _readingLog.entries
        .where((entry) =>
    entry.key.year == _selectedDay.year &&
        entry.key.month == _selectedDay.month)
        .fold(0, (prev, entry) => prev + entry.value);
  }

  int _getMonthlyTotalHours() => _getMonthlyTotalSeconds() ~/ 3600;
  int _getMonthlyTotalMinutes() => (_getMonthlyTotalSeconds() % 3600) ~/ 60;

  Color _getColorBasedOnMinutes(int minutes) {
    if (minutes >= 180) return Colors.blue[900]!;
    if (minutes >= 90) return Colors.blue[700]!;
    if (minutes >= 60) return Colors.blue[500]!;
    if (minutes >= 30) return Colors.blue[300]!;
    return Colors.blue[100]!;
  }

  // 하단 네비게이션 탭 클릭 시 처리 함수
  void _onItemTapped(int index) {
    // widget.onTabChanged가 null이 아니면 호출
    if (widget.onTabChanged != null) {
      widget.onTabChanged!(index);
    }

    // 탭 변경에 따라 페이지 네비게이션
    if (index != widget.currentIndex) {
      switch (index) {
        case 0:
          Navigator.pushReplacementNamed(context, '/timer');
          break;
        case 1:
          Navigator.pushReplacementNamed(context, '/challenge');
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('타이머 / 달력'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '타이머'),
            Tab(text: '달력'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTimerTab(),
          _buildCalendarTab(),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: widget.currentIndex,
        onTap: _onItemTapped,  // 하단 탭 클릭 시 _onItemTapped 호출
      ),
    );
  }

  Widget _buildTimerTab() {
    int todaySeconds = _getTodaySeconds();
    int todayHours = todaySeconds ~/ 3600;
    int todayMinutes = (todaySeconds % 3600) ~/ 60;

    String formattedTime = "${(_seconds ~/ 3600).toString().padLeft(2, '0')}:"
        "${((_seconds % 3600) ~/ 60).toString().padLeft(2, '0')}:"
        "${(_seconds % 60).toString().padLeft(2, '0')}";

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Text(
              formattedTime,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isRunning ? null : _startTimer,
                  child: const Text('시작'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _isRunning ? _stopTimer : null,
                  child: const Text('중지'),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Text(
              "오늘 나는\n${todayHours}시간 ${todayMinutes}분\n독서했어요.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _selectedDay,
            calendarFormat: CalendarFormat.month,
            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
              });
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, date, _) {
                DateTime key = DateTime(date.year, date.month, date.day);
                int seconds = _readingLog[key] ?? 0;
                int minutes = seconds ~/ 60;
                return Container(
                  margin: const EdgeInsets.all(4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getColorBasedOnMinutes(minutes),
                  ),
                  child: Text(
                    '${date.day}',
                    style: const TextStyle(color: Colors.black),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "이번달 나는?\n총 ${_getMonthlyTotalHours()}시간 ${_getMonthlyTotalMinutes()}분\n독서했어요.",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}