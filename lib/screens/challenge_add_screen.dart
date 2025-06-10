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
  DateTime _startDate = DateTime.now().toUtc().add(const Duration(hours: 9));
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
    final now = DateTime.now().toUtc().add(const Duration(hours: 9)); // 한국 시간 기준 현재

    final DateTime initial = isStart
        ? (_startDate)
        : (_endDate ?? _startDate); // 종료일 없으면 시작일 기준

    final DateTime firstDate = isStart
        ? now // 시작일은 오늘부터 가능
        : _startDate.isAfter(now) ? _startDate : now; // 종료일은 시작일 또는 오늘 이후부터

    final DateTime lastDate = isStart
        ? now.add(const Duration(days: 365)) // 시작일 최대 1년 후
        : _startDate.add(const Duration(days: 365)); // 종료일도 시작일 기준 최대 1년 후

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue, // 선택된 날짜, 확인 버튼 색
              onPrimary: Colors.white, // 확인 버튼 텍스트 색
              onSurface: Colors.black, // 달력 내 일반 텍스트 색
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.blue), // 취소 버튼 텍스트 색
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        final formattedDate = DateFormat('yyyy-MM-dd').format(picked);

        if (isStart) {
          _startDate = picked;
          _startDateController.text = formattedDate;

          if (_endDate != null && _endDate!.isBefore(_startDate)) {
            _endDate = null;
            _endDateController.text = '';
          }
        } else {
          _endDate = picked;
          _endDateController.text = formattedDate;
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

  Future<void> _createChallenge() async {
    if (_titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        _selectedGoalType.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('모든 필드를 입력해주세요.')),
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('시작 날짜와 종료 날짜를 모두 선택해주세요.')),
      );
      return;
    }

    if (_startDate!.isAfter(_endDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('시작 날짜는 종료 날짜보다 빨라야 합니다.')),
      );
      return;
    }

    if (_selectedBook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('목표 도서를 선택해주세요.')),
      );
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("챌린지 생성에 성공했습니다!")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("챌린지 생성에 실패했습니다. 다시 시도해주세요.")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
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
        actions: [
          TextButton(
            onPressed: _isLoading
                ? null
                : () async {
              setState(() {
                _isLoading = true;
              });

              await _createChallenge(); // 챌린지 생성 함수

              if (mounted) {
                Navigator.pushReplacementNamed(context, '/home'); // 홈으로 이동
              }
            },
            child: Text(
              '등록',
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

              SizedBox(height:40),

              //챌린지명
              const Text(
                '새로운 챌린지명을 입력하세요.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              Stack(
                children: [
                  TextField(
                    controller: _titleController,
                    maxLength: 20, // 글자수 제한
                    buildCounter: (BuildContext context, {
                      required int currentLength,
                      required bool isFocused,
                      required int? maxLength,
                    }) => null, // 기본 카운터 제거
                    decoration: InputDecoration(
                      hintText: '챌린지 이름을 입력하세요.',
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
                      valueListenable: _titleController,
                      builder: (context, value, child) {
                        final currentLength = value.text.length;
                        return Text(
                          '$currentLength/20',
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

              const SizedBox(height: 40), //각 폼 띄우기..

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
                    maxLength: 50,
                    // 텍스트 길이 제한은 유지
                    buildCounter: (BuildContext context, {
                      required int currentLength,
                      required bool isFocused,
                      required int? maxLength,
                    }) => null,
                    // 기본 카운터 제거
                    decoration: InputDecoration(
                      hintText: '챌린지에 대한 설명을 50자 내로 입력해주세요.',
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
                          '$currentLength/50',
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

              SizedBox(height: 40),

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
                        text: DateFormat('yyyy-MM-dd').format(_startDate),
                      ),
                      readOnly: true,
                      enabled: false, // 비활성화
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
                      decoration: InputDecoration(
                        labelText: '종료 날짜',
                        floatingLabelBehavior: FloatingLabelBehavior.always, // 항상 위에 표시
                        labelStyle: TextStyle(color: Colors.blue.shade700),
                        border: OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue.shade700, width:2)
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue.shade700, width:2),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        suffixIcon: Icon(Icons.calendar_today, size: 20),
                      ),
                      onTap: () => _showDatePicker(false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
