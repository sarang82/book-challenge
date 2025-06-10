// ... 생략된 import는 그대로 유지
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Map<DateTime, int> _maxFocusLog = {};
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  final user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _dailyGoalSeconds = 0;
  int _currentSessionSeconds = 0;
  String _nickname = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.currentIndex);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (user == null) return;

    // 닉네임은 users 컬렉션에서 가져오기
    final userDoc = await _firestore.collection('users').doc(user!.uid).get();
    if (userDoc.exists) {
      setState(() {
        _nickname = userDoc.data()?['nickname'] ?? '사용자';
      });
    }

    // 독서 로그와 목표 시간은 reading_logs 컬렉션에서 가져오기
    final logDoc = await _firestore.collection('reading_logs').doc(user!.uid).get();
    if (logDoc.exists) {
      final Map<String, dynamic> logs = logDoc.data()?['log'] ?? {};
      final Map<String, dynamic> maxes = logDoc.data()?['max'] ?? {};
      final int goalSeconds = logDoc.data()?['dailyGoalSeconds'] ?? 3600;

      setState(() {
        _dailyGoalSeconds = goalSeconds;

        _readingLog = logs.map((key, value) {
          final date = DateTime.parse(key);
          return MapEntry(date, value as int);
        });

        _maxFocusLog = maxes.map((key, value) {
          final date = DateTime.parse(key);
          return MapEntry(date, value as int);
        });
      });
    } else {

      setState(() {
        _dailyGoalSeconds = 0;
      });
    }
  }

  Future<void> _saveReadingLog(int seconds) async {
    if (user == null) return;

    DateTime now = DateTime.now();
    DateTime key = DateTime(now.year, now.month, now.day);

    _readingLog[key] = (_readingLog[key] ?? 0) + seconds;

    if (seconds > (_maxFocusLog[key] ?? 0)) {
      _maxFocusLog[key] = seconds;
    }

    final log = {
      for (var e in _readingLog.entries)
        _formatDateKey(e.key): e.value,
    };

    final max = {
      for (var e in _maxFocusLog.entries)
        _formatDateKey(e.key): e.value,
    };

    await _firestore.collection('reading_logs').doc(user!.uid).set({
      'log': log,
      'max': max,
      'dailyGoalSeconds': _dailyGoalSeconds, // 목표 시간도 함께 저장
    });
  }

  Future<void> _saveDailyGoalToFirestore() async {
    if (user == null) return;

    // 기존 데이터를 유지하면서 목표 시간만 업데이트
    final logDoc = await _firestore.collection('reading_logs').doc(user!.uid).get();
    Map<String, dynamic> existingData = {};

    if (logDoc.exists) {
      existingData = logDoc.data() ?? {};
    }

    existingData['dailyGoalSeconds'] = _dailyGoalSeconds;

    await _firestore.collection('reading_logs').doc(user!.uid).set(existingData);
  }

  String _formatDateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  void _onItemTapped(int index) {
    if (widget.onTabChanged != null) widget.onTabChanged!(index);
    if (index != widget.currentIndex) {
      final route = ['/timer', '/challenge', '/home', '/library', '/profile'][index];
      Navigator.pushReplacementNamed(context, route);
    }
  }

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
    int todayMaxFocus = _maxFocusLog[todayKey] ?? 0;
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
          // 타이머 탭
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 320,
                                height: 400,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.transparent,
                                  border: Border.all(color: Colors.lightBlue.shade100, width: 4),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "${DateTime.now().year}년 ${DateTime.now().month}월 ${DateTime.now().day}일 (${['일','월','화','수','목','금','토'][DateTime.now().weekday % 7]})",
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      formattedTime,
                                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        ElevatedButton(
                                          onPressed: timerProvider.isRunning
                                              ? () async {
                                            timerProvider.stop();
                                            _currentSessionSeconds = timerProvider.seconds;
                                            await _saveReadingLog(_currentSessionSeconds);
                                            timerProvider.reset();
                                            await _loadUserData();
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
                                          onPressed: timerProvider.isRunning
                                              ? null
                                              : () {
                                            timerProvider.start();
                                          },
                                          child: const Text('시작'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue[100]!.withOpacity(0.9),
                                            foregroundColor: Colors.black,
                                            shape: const CircleBorder(),
                                            padding: const EdgeInsets.all(24),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 30),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "$_nickname님, 목표를 위해 조금만 더 달려볼까요?",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      _buildInfoRow("오늘 최대 집중 시간", _formatDuration(todayMaxFocus)),
                                      _buildInfoRow("오늘 누적 목표 시간", _formatDuration(totalToday)),
                                      _buildInfoRow("일일 목표 시간", _formatDuration(_dailyGoalSeconds)),
                                      const SizedBox(height: 10),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) {
                                                final hourController = TextEditingController();
                                                final minuteController = TextEditingController();

                                                return AlertDialog(
                                                  backgroundColor: Colors.white,
                                                  title: const Text("목표 시간 설정"),
                                                  content: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      TextField(
                                                        controller: hourController,
                                                        keyboardType: TextInputType.number,
                                                        decoration: const InputDecoration(labelText: '시간 (시)'),
                                                      ),
                                                      TextField(
                                                        controller: minuteController,
                                                        keyboardType: TextInputType.number,
                                                        decoration: const InputDecoration(labelText: '시간 (분)'),
                                                      ),
                                                    ],
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context),
                                                      child: const Text("취소"),
                                                    ),
                                                    TextButton(
                                                      onPressed: () async {
                                                        final hours = int.tryParse(hourController.text) ?? 0;
                                                        final minutes = int.tryParse(minuteController.text) ?? 0;
                                                        setState(() {
                                                          _dailyGoalSeconds = hours * 3600 + minutes * 60;
                                                        });
                                                        await _saveDailyGoalToFirestore();
                                                        Navigator.pop(context);
                                                      },
                                                      child: const Text("설정"),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            shape: const CircleBorder(),
                                            padding: const EdgeInsets.all(20),
                                            backgroundColor: Colors.blue[100],
                                            foregroundColor: Colors.black,
                                          ),
                                          child: const Text('목표 설정'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // 달력 탭
          SingleChildScrollView(
            child: Column(
              children: [
                TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
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
                Builder(
                  builder: (context) {
                    final focused = _focusedDay;
                    final thisMonthLogs = _readingLog.entries.where((e) {
                      final entryDate = e.key;
                      return entryDate.year == focused.year && entryDate.month == focused.month;
                    });

                    final totalSeconds = thisMonthLogs.fold(0, (sum, e) => sum + e.value);

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

  Widget _buildInfoRow(String label, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(time),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return "${hours.toString().padLeft(2, '0')} : ${minutes.toString().padLeft(2, '0')}";
  }
}