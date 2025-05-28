import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:book_tracking_app/services/mission_service.dart';
import 'package:book_tracking_app/services/mission_recommend_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MissionAddScreen extends StatefulWidget {
  const MissionAddScreen({super.key});

  @override
  _MissionAddScreenState createState() => _MissionAddScreenState();
}

class _MissionAddScreenState extends State<MissionAddScreen> {
  final TextEditingController _titleController = TextEditingController();
  final MissionService _missionService = MissionService();

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  String? _recommendedMission;

  final MissionRecommendationService _missionRecommendationService = MissionRecommendationService();

  Future<void> _addMission() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('미션 제목을 입력해주세요!')),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('missions').add({
      'title': _titleController.text,
      'description': '', // 미션 설명 제거로 빈 문자열로 저장
      'startDate': _startDate,
      'endDate': _endDate,
      'createdAt': Timestamp.now(),
      'userId': FirebaseAuth.instance.currentUser?.uid,
      'status': 'ongoing',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('미션이 추가되었습니다!')),
    );

    _titleController.clear();
  }

  Future<void> _getRandomMission() async {
    try {
      var recommendedMission = await _missionRecommendationService.getRandomMission('독서', '쉬움');
      setState(() {
        _recommendedMission = recommendedMission['title'] ?? '기본 미션 제목';
        _titleController.text = _recommendedMission!;
      });
    } catch (e) {
      setState(() {
        _recommendedMission = '기본 미션 제목';
        _titleController.text = _recommendedMission!;
      });
      print('미션 추천 중 오류 발생: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _getRandomMission();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('미션 생성', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: '미션 제목'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _getRandomMission,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 미션 설명 입력 부분이 제거됨
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '기간 : ${_startDate.year}.${_startDate.month}.${_startDate.day}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 40),
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _addMission,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFF08A),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      '미션 등록',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}