import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ChallengeAddScreen extends StatefulWidget {
  const ChallengeAddScreen({super.key});

  @override
  State<ChallengeAddScreen> createState() => _ChallengeAddScreenState();
}

class _ChallengeAddScreenState extends State<ChallengeAddScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _isRefreshing = false;
  //달력을 위한 변수
  DateTime _startDate = DateTime.now(); //시작 날짜
  DateTime _endDate = DateTime.now().add(const Duration(days: 31)); //종료날짜
  //서재 가져오기 변수
  String _selectedBookSource = '내 서재에서 가져오기';

  void _showDatePicker(bool isStartDate){
    showModalBottomSheet(context: context,
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
                  if (isStartDate){
                    _startDate = newDate;
                  } else {
                    _endDate = newDate;
                  }
                });
              },
            ),
          );
        }
      );
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('챌린지 생성',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                //챌린지명
                const Text('새로운 챌린지명을 입력하세요.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'ex) 데미안 1주 안에 읽기',
                    hintStyle: const TextStyle(
                      fontSize:14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF7F7F7),
                    contentPadding: const EdgeInsets.symmetric(horizontal:12, vertical: 14),
                  ),
                ),
                const SizedBox(height:30), //각 폼 띄우기..

                //챌린지 설명
                const Text('챌린지에 대한 설명을 입력하세요.',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,),
                ),
                const SizedBox(height: 8),
                TextField(
                  maxLines: 5,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: 'ex) 학교 과제를 위한 챌린지..',
                    hintStyle: const TextStyle(
                      fontSize:14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF7F7F7),
                    contentPadding: const EdgeInsets.symmetric(horizontal:12, vertical: 14),
                  ),
                ),
                SizedBox(height:30),

                //챌린지 목표 달성 방법
                const Text('챌린지 목표 달성 방법을 선택하세요.',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,),),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: '매일 읽은 페이지 기록',
                  items: [
                    DropdownMenuItem(value: '매일 읽은 페이지 기록', 
                        child: Text('매일 읽은 페이지 기록')),
                    DropdownMenuItem(value: '타이머 사용',
                        child: Text('타이머 사용')),
                  ],
                  onChanged: (value) {
                    //선택값 저장할 state 변수
                  },
                  style: const TextStyle(
                    fontSize:14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w300,
                  ),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none, // 테두리 없애기
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                  ),
                ),
                const SizedBox(height:30),

                //date picker
                const Text('챌린지 목표 기간을 설정하세요.',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,),),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    //시작날짜
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('시작 날짜'),
                        TextButton(
                          onPressed: () => _showDatePicker(true),
                          child: Text(
                            '${_startDate.year}.${_startDate.month}.${_startDate.day}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        )
                      ],
                    ),

                    //종료 날짜
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('종료 날짜'),
                        TextButton(
                          onPressed: () => _showDatePicker(false),
                          child: Text(
                            '${_endDate.year}.${_endDate.month}.${_endDate.day}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        )
                      ],
                    )
                  ],
                ),
                SizedBox(height: 30),

                //목표 도서 넣기
                const Text('목표 도서를 선택하세요',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,),),
                SizedBox(height:8),
                DropdownButtonFormField<String>(
                  value: _selectedBookSource,
                  items: const [
                    DropdownMenuItem(
                      value: '내 서재에서 가져오기',
                      child: Text('내 서재에서 가져오기'),
                    ),
                    DropdownMenuItem(
                      value: '검색으로 가져오기',
                      child: Text('검색으로 가져오기'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedBookSource = value!;
                    });
                  },
                  style: const TextStyle(
                    fontSize:14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w300,
                  ),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none, // 테두리 없애기
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                  ),
                ),
                SizedBox(height: 40),
                Center(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // 제출 로직은 나중에쓸거임
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFF08A),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('등록',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize:16,
                        ),),
                    ),
                  ),
                ),
              ],

            ),
          )
      )
    );
  }
}