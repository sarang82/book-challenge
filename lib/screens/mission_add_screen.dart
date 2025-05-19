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
  DateTime _endDate = DateTime.now().add(const Duration(days: 31)); // 종료 날짜
  String _selectedBookSource = '내 서재에서 가져오기';

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
      'bookSource': _selectedBookSource,
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


  // 날짜 선택을 위한 함수
  void _showDatePicker(bool isStartDate) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (_) {
        return SizedBox(
          height: 300,
          child: CupertinoDatePicker(
            backgroundColor: Colors.white,
            mode: CupertinoDatePickerMode.date,
            initialDateTime: isStartDate ? _startDate : _endDate,
            onDateTimeChanged: (DateTime newDate) {
              setState(() {
                if (isStartDate) {
                  _startDate = newDate;
                } else {
                  _endDate = newDate;
                }
              });
            },
          ),
        );
      },
    );
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
              // 날짜 선택 (시작 날짜, 종료 날짜)
              const Text('미션 기간을 설정하세요', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('시작 날짜'),
                      TextButton(
                        onPressed: () => _showDatePicker(true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black,
                          backgroundColor: Colors.white,
                          padding:const EdgeInsets.symmetric(horizontal :16, vertical : 8),
                          shape : RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          )
                        ),
                        child: Text(
                          '${_startDate.year}.${_startDate.month}.${_startDate.day}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      )
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('종료 날짜'),
                      TextButton(
                        onPressed: () => _showDatePicker(false),
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.black,
                            backgroundColor: Colors.white,
                            padding:const EdgeInsets.symmetric(horizontal :16, vertical : 8),
                            shape : RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            )
                        ),
                        child: Text(
                          '${_endDate.year}.${_endDate.month}.${_endDate.day}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      )
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 30),
              // 목표 도서 선택
              const Text('목표 도서를 선택하세요', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedBookSource,
                items: const [
                  DropdownMenuItem(value: '내 서재에서 가져오기', child: Text('내 서재에서 가져오기')),
                  DropdownMenuItem(value: '검색으로 가져오기', child: Text('검색으로 가져오기')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedBookSource = value!;
                  });
                },
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w300,
                ),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Color(0xFFF5F5F5),
                ),
                dropdownColor: Colors.white,
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
