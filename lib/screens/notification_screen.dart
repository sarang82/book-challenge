import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _isLoading = true;
  List<bool> _selectedDays = List<bool>.filled(7, false);
  int _selectedHour = 9;
  int _selectedMinute = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // 정보 불러오기
  Future<void> _loadInitialData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('notification_schedule')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _selectedHour = data['hour'] ?? 9;
        final int minute = data['minute'] ?? 0;
        _selectedMinute = (minute / 10).round() * 10;
        final List<dynamic> days = data['days'] ?? List.filled(7, false);

        setState(() {
          _selectedDays = List<bool>.from(days);
        });
      }
    } catch (e) {
      print('알림 데이터 불러오기 오류: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 알림 저장 코드
  Future<void> _saveNotificationSettings() async {
    final token = await FirebaseMessaging.instance.getToken();
    final user = FirebaseAuth.instance.currentUser;

    if (token == null || user == null) return;

    await FirebaseFirestore.instance
        .collection('notification_schedule')
        .doc(user.uid)
        .set({
      'token': token,
      'hour': _selectedHour,
      'minute': _selectedMinute,
      'days': _selectedDays,
      'createdAt': FieldValue.serverTimestamp(),
      'uid': user.uid,
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("저장 완료")));
  }

  String _formatTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '알림 설정',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveNotificationSettings,
            child: Text(
              '저장',
              style: TextStyle(
                color: _isLoading ? Colors.grey : Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('요일 선택',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Center(
              child: ToggleButtons(
                children: ['월', '화', '수', '목', '금', '토', '일']
                    .map((d) => Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(d),
                ))
                    .toList(),
                isSelected: _selectedDays,
                onPressed: (i) => setState(() {
                  _selectedDays[i] = !_selectedDays[i];
                }),
                fillColor: Colors.blue.withOpacity(0.2),
                selectedColor: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 24),
            const Text('알림 시간',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('시간: '),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    dropdownColor: Colors.white,
                    value: _selectedHour,
                    items: List.generate(
                      24,
                          (i) => DropdownMenuItem(
                        value: i,
                        child:
                        Text(i.toString().padLeft(2, '0')),
                      ),
                    ),
                    onChanged: (val) {
                      if (val != null)
                        setState(() => _selectedHour = val);
                    },
                  ),
                  const SizedBox(width: 32),
                  const Text('분: '),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    dropdownColor: Colors.white,
                    value: _selectedMinute,
                    items: List.generate(6, (i) => i * 10)
                        .map((val) => DropdownMenuItem(
                      value: val,
                      child: Text(val
                          .toString()
                          .padLeft(2, '0')),
                    ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null)
                        setState(() => _selectedMinute = val);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
