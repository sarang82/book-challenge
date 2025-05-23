import 'dart:ui';

import 'package:intl/intl.dart';
import 'package:book_tracking_app/services/challenge_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/book_search_service.dart';

class ChallengeAddScreen extends StatefulWidget {
  const ChallengeAddScreen({super.key});

  @override
  State<ChallengeAddScreen> createState() => _ChallengeAddScreenState();
}

class _ChallengeAddScreenState extends State<ChallengeAddScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _isRefreshing = false;

  //달력을 위한 변수
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  //책 검색
  final TextEditingController _bookSearchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedBook;
  final BookSearchService _bookSearchService = BookSearchService();
  bool _isSearching = false;

  //챌린지 등록을 위한 컨트롤러 만들기
  //입력
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  //드롭다운
  String _selectedGoalType = '페이지';

  void _showDatePicker(bool isStart) async {
    final DateTime initial = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? (_startDate ?? DateTime.now()));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          _startDateController.text = '${picked.year}.${picked.month}.${picked.day}';
        } else {
          _endDate = picked;
          _endDateController.text = '${picked.year}.${picked.month}.${picked.day}';
        }
      });
    }
  }


  // 실시간 검색
  void _onSearchChanged(String query) async {
    if (query
        .trim()
        .isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    final results = await _bookSearchService.searchBooks(query);
    print('검색결과: $results'); // 디버깅용코드

    setState(() {
      _searchResults = results;
    });
  }

  @override
  Widget build(BuildContext context) {
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
              // 목표 도서 넣기
              const Text('목표 도서의 제목을 검색하세요.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 10),

              TextField(
                controller: _bookSearchController,
                decoration: InputDecoration(
                  hintText: '도서명을 입력하세요.',
                  hintStyle: const TextStyle(fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF7F7F7),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                ),
                onChanged: (value) {
                  _onSearchChanged(value);
                  setState(() {
                    _isSearching = value
                        .trim()
                        .isNotEmpty;
                  });
                },
              ),

              // 리스트 조건부 렌더링
              if (_isSearching)
                _isLoading
                    ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
                    : _searchResults.isEmpty
                    ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '"${_bookSearchController.text}" 검색 결과가 없습니다',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                )
                    : Container(
                  height: 200, // 이게 꼭 있어야 리스트뷰 보임!
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final book = _searchResults[index];
                      return ListTile(
                        leading: book['cover'] != null && book['cover'] != ''
                            ? Image.network(
                          book['cover'],
                          width: 40,
                          height: 60,
                          fit: BoxFit.cover,
                        )
                            : Container(
                          width: 40,
                          height: 60,
                          color: Colors.grey[200],
                          child: Icon(Icons.book, color: Colors.grey),
                        ),
                        title: Text(book['title'] ?? ''),
                        subtitle: Text(book['author'] ?? ''),
                        onTap: () {
                          setState(() {
                            _selectedBook = book;
                            _bookSearchController.text = book['title'] ?? '';
                            _searchResults = [];
                            _isSearching = false;
                          });
                        },
                      );
                    },
                  ),
                ),

              SizedBox(height:30),

              //챌린지명
              const Text('새로운 챌린지명을 입력하세요.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'ex) 2주 안에 데미안 완독!',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF7F7F7),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                ),
              ),
              const SizedBox(height: 30), //각 폼 띄우기..

              //챌린지 설명
              const Text('챌린지에 대한 설명을 입력하세요.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,),
              ),
              const SizedBox(height: 8),
              Stack(
                children: [
                  TextField(
                    controller: _descriptionController,
                    maxLines: 5,
                    maxLength: 200,
                    // 텍스트 길이 제한은 유지
                    buildCounter: (BuildContext context, {
                      required int currentLength,
                      required bool isFocused,
                      required int? maxLength,
                    }) => null,
                    // 기본 카운터 제거
                    decoration: InputDecoration(
                      hintText: 'ex) 독후감 대회를 위해 빠르게 완독하기 위한 목적!',
                      hintStyle: const TextStyle(fontSize: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF7F7F7),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 8,
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _descriptionController,
                      builder: (context, value, child) {
                        final currentLength = value.text.length;
                        return Text(
                          '$currentLength/200',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              SizedBox(height: 30),

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
                  setState(() {
                    _selectedGoalType = value!;
                  });
                },
                style: const TextStyle(
                  fontSize: 14,
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
              const SizedBox(height: 30),

              // 챌린지 목표 기간 설정
              const Text(
                '챌린지 목표 기간을 설정하세요.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 20),

              Row(
                children: [
                  // 시작일 (오늘 날짜, 수정 불가)
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(
                        text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
                      ),
                      readOnly: true,
                      enabled: false, // 아예 비활성화
                      decoration: const InputDecoration(
                        labelText: '시작 날짜',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          suffixIcon: Icon(Icons.calendar_today, size: 20)
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // 종료일 (사용자가 선택)
                  Expanded(
                    child: TextField(
                      controller: _endDateController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: '종료 날짜',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        suffixIcon: Icon(Icons.calendar_today, size: 20),
                      ),
                      onTap: () => _showDatePicker(false),
                    ),
                  ),
                ],
              ),


              const SizedBox(height: 30),



              SizedBox(height: 40),
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_titleController.text
                          .trim()
                          .isEmpty ||
                          _descriptionController.text
                              .trim()
                              .isEmpty ||
                          _selectedGoalType
                              .trim()
                              .isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('모든 필드를 입력해주세요.')));
                        return;
                      }

                      if (_startDate == null || _endDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('시작 날짜와 종료 날짜를 모두 선택해주세요.'))
                        );
                        return;
                      }

                      if (_startDate!.isAfter(_endDate!)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('시작 날짜는 종료 날짜보다 빨라야 합니다.'))
                        );
                        return;
                      }

                      if (_selectedBook == null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('목표 도서를 선택해주세요.')));
                        return;
                      }

                      setState(() => _isLoading = true);
                      try {
                        await ChallengeService().createChallenge(
                          title: _titleController.text,
                          type: _selectedGoalType == '타이머 사용' ? '시간' : '페이지',
                          description: _descriptionController.text,
                          startDate: _startDate!,
                          endDate: _endDate!,
                          bookId: _selectedBook?['isbn'] ?? '',
                        );

                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text("챌린지 생성에 성공했습니다!")));
                        Navigator.pop(context);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text("챌린지 생성에 실패했습니다. 다시 시도해주세요.")));
                      } finally {
                        setState(() => _isLoading = false);
                      }
                    }
                    ,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFF08A),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('등록',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontSize: 16,
                      ),),
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