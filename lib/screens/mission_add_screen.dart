import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:book_tracking_app/services/mission_service.dart';
import 'package:book_tracking_app/services/mission_recommend_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class MissionAddScreen extends StatefulWidget {
  const MissionAddScreen({super.key});

  @override
  _MissionAddScreenState createState() => _MissionAddScreenState();
}

class _MissionAddScreenState extends State<MissionAddScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final MissionService _missionService = MissionService();

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now(); // 종료 날짜를 시작 날짜와 동일하게

  String? _recommendedMission;
  String _newMission = '';

  final MissionRecommendationService _missionRecommendationService = MissionRecommendationService(); // 추천 서비스 인스턴스


  Future<void> _addMission() async {
    if (_titleController.text.trim().isEmpty || _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('미션 제목과 설명을 모두 입력해주세요!')),
      );
      return;
    }

    // Firestore에 미션 추가
    await FirebaseFirestore.instance.collection('missions').add({
      'title': _titleController.text,
      'description': _descriptionController.text,
      'startDate': _startDate,
      'endDate': _endDate,
      'createdAt': Timestamp.now(),
      'userId': FirebaseAuth.instance.currentUser?.uid,  // 사용자 ID 추가
      'status': 'ongoing',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('미션이 추가되었습니다!')),
    );

    // 입력 필드 초기화
    _titleController.clear();
    _descriptionController.clear();
  }

// 랜덤 미션 추천을 위한 함수 (MissionRecommendationService 사용)
  Future<void> _getRandomMission() async {
    try {
      var recommendedMission = await _missionRecommendationService.getRandomMission('독서', '쉬움');

      // 랜덤 미션이 없을 경우 기본값 설정
      setState(() {
        _recommendedMission = recommendedMission['title'] ?? '기본 미션 제목';  // null이면 기본값 사용
        _titleController.text = _recommendedMission!;  // 추천 미션을 제목 입력 필드에 설정
      });
    } catch (e) {
      // 에러 발생 시 기본 미션 제목 설정
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
    _getRandomMission(); // 앱 시작 시 랜덤 미션 추천
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
              // 미션 제목 입력 (추천 미션이 자동으로 들어감)
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
                    onPressed: _getRandomMission,  // 랜덤 미션 새로 가져오기
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 미션 설명 입력
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: '미션 설명'),
              ),
              const SizedBox(height: 16),
              // 오늘 날짜 표시
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
              // 미션 등록 버튼
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _addMission,  // Firestore에 미션 등록
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