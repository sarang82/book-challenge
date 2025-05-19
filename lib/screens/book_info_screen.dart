import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart'; // 날짜 포맷용
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/aladin_service.dart';
import '../services/firestore_service.dart';
import '../services/my_library_service.dart'; // 내 서재 서비스 추가
import '../widgets/bottom_nav_bar.dart';

class BookInfoScreen extends StatefulWidget {
  final Map<String, dynamic>? bookData;

  const BookInfoScreen({
    super.key,
    required this.bookData,
  });

  @override
  State<BookInfoScreen> createState() => _BookInfoScreenState();
}

class _BookInfoScreenState extends State<BookInfoScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _isCheckingLibrary = false; // 내 서재 확인 로딩 상태
  Map<String, dynamic>? _detailedBookData;
  String? _libraryCategory; // 내 서재에 있는 카테고리
  final AladinService _aladinService = AladinService();
  final FirestoreService _firestoreService = FirestoreService();
  final MyLibraryService _myLibraryService = MyLibraryService(); // 내 서재 서비스
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _selectedIndex = 3; // 서재 화면은 인덱스 3

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);

    // 상세 정보 로드
    _loadDetailedBookInfo();

    // 내 서재에 있는지 확인
    _checkBookInLibrary();
  }

  // 내 서재에 도서가 있는지 확인
  Future<void> _checkBookInLibrary() async {
    if (widget.bookData == null || widget.bookData!['isbn'] == null || !_myLibraryService.isUserLoggedIn) {
      return;
    }

    setState(() {
      _isCheckingLibrary = true;
    });

    try {
      final isbn = widget.bookData!['isbn'];
      final category = await _myLibraryService.checkBookInLibrary(isbn);

      if (mounted) {
        setState(() {
          _libraryCategory = category;
          _isCheckingLibrary = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('내 서재 확인 오류: $e');
      }
      if (mounted) {
        setState(() {
          _isCheckingLibrary = false;
        });
      }
    }
  }

  // 상세 정보 로드 메서드 추가
  Future<void> _loadDetailedBookInfo() async {
    if (widget.bookData == null || widget.bookData!['isbn'] == null) return;

    final String isbn = widget.bookData!['isbn'];

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. 먼저 Firestore에서 상세 정보가 있는지 확인
      Map<String, dynamic>? detailedData = await _firestoreService.getBookDetail(isbn);

      // 2. 상세 정보가 없거나 페이지 수 정보가 없는 경우 API 호출
      if (detailedData == null || detailedData['itemPage'] == null || detailedData['itemPage'] == 0) {
        if (kDebugMode) {
          print('도서 ID: $isbn의 상세 정보를 API에서 가져옵니다.');
        }

        final apiDetailedData = await _aladinService.fetchBookDetail(isbn);

        if (apiDetailedData != null) {
          // API에서 가져온 정보가 있으면 Firestore에 저장
          await _firestoreService.saveOrUpdateBookDetail(isbn, apiDetailedData);
          detailedData = apiDetailedData;
        }
      } else {
        if (kDebugMode) {
          print('도서 ID: $isbn의 상세 정보를 Firestore에서 가져왔습니다.');
        }
      }

      if (mounted) {
        setState(() {
          if (detailedData != null) {
            // 기존 데이터와 상세 데이터 병합
            _detailedBookData = {...widget.bookData!, ...detailedData};
          } else {
            _detailedBookData = widget.bookData;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('도서 상세 정보 로드 실패: $e');
      }

      if (mounted) {
        setState(() {
          _detailedBookData = widget.bookData;
          _isLoading = false;
        });
      }
    }
  }

  // 하단 내비게이션 바 탭 핸들러
  void _onItemTapped(int index) {
    if (index == _selectedIndex) return; // 같은 탭 선택 시 무시

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/timer');
        break;
      case 1:
      // 챌린지 화면으로 이동
        Navigator.pushReplacementNamed(context, '/challenge');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 3:
      // 서재 화면으로 이동 (현재 선택된 화면)
        Navigator.pushReplacementNamed(context, '/booktracking');
        break;
      case 4:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
      default:
      // 구현되지 않은 탭
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('준비 중인 기능입니다.'))
        );
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  // 내 서재에 추가 바텀시트 표시
  void _showAddToLibraryBottomSheet() {
    if (!_myLibraryService.isUserLoggedIn) {
      _showLoginPrompt();
      return;
    }

    if (_detailedBookData == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => AddToLibraryBottomSheet(
        bookData: _detailedBookData!,
        existingCategory: _libraryCategory,
        onSaved: (category) {
          setState(() {
            _libraryCategory = category;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('도서가 ${_getCategoryText(category)}에 추가되었습니다'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        onRemoved: () {
          setState(() {
            _libraryCategory = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('도서가 내 서재에서 삭제되었습니다'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  // 로그인 안내 다이얼로그 표시
  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그인 필요'),
        content: const Text('내 서재 기능을 이용하려면 로그인이 필요합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/login').then((_) {
                // 로그인 후 내 서재 확인
                if (_myLibraryService.isUserLoggedIn) {
                  _checkBookInLibrary();
                }
              });
            },
            child: const Text('로그인'),
          ),
        ],
      ),
    );
  }

  // 카테고리 텍스트 변환
  String _getCategoryText(String category) {
    switch (category) {
      case MyLibraryService.COMPLETED:
        return '완독한 도서';
      case MyLibraryService.READING:
        return '읽고 있는 책';
      case MyLibraryService.WISHLIST:
        return '읽고 싶은 책';
      default:
        return '내 서재';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bookData == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            '도서 정보',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text('도서 정보를 불러올 수 없습니다.'),
        ),
      );
    }

    // 상세 데이터 또는 기본 데이터 사용
    final bookData = _detailedBookData ?? widget.bookData!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '도서 정보',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // 우측 상단에 + 버튼 추가
          _isCheckingLibrary
              ? const Padding(
            padding: EdgeInsets.all(8.0),
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          )
              : IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            onPressed: _showAddToLibraryBottomSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // 내 서재 상태 표시 (있는 경우)
          if (_libraryCategory != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bookmark, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${_getCategoryText(_libraryCategory!)}에 추가됨',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _showAddToLibraryBottomSheet,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('변경'),
                  ),
                ],
              ),
            ),

          // 도서 정보 내용
          Expanded(
            child: BookInfoContent(
              bookData: bookData,
              tabController: _tabController,
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: '타이머'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: '챌린지'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.library_books), label: '서재'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '프로필'),
        ],
      ),
    );
  }
}

// 내 서재에 추가 바텀 시트
class AddToLibraryBottomSheet extends StatefulWidget {
  final Map<String, dynamic> bookData;
  final String? existingCategory;
  final Function(String) onSaved;
  final Function() onRemoved;

  const AddToLibraryBottomSheet({
    super.key,
    required this.bookData,
    this.existingCategory,
    required this.onSaved,
    required this.onRemoved,
  });

  @override
  State<AddToLibraryBottomSheet> createState() => _AddToLibraryBottomSheetState();
}

class _AddToLibraryBottomSheetState extends State<AddToLibraryBottomSheet> {
  final MyLibraryService _myLibraryService = MyLibraryService();
  bool _isLoading = false;

  // 선택한 값들
  String _selectedCategory = MyLibraryService.WISHLIST; // 기본값: 읽고 싶은 책
  DateTime? _startDate;
  DateTime? _endDate;

  // 컨트롤러들
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // 기존 카테고리가 있으면 설정
    if (widget.existingCategory != null) {
      _selectedCategory = widget.existingCategory!;
    }

    // 날짜 초기화
    if (widget.bookData['startDate'] != null) {
      _startDate = widget.bookData['startDate'] is Timestamp
          ? (widget.bookData['startDate'] as Timestamp).toDate()
          : DateTime.now();
      _startDateController.text = DateFormat('yyyy. MM. dd').format(_startDate!);
    }

    if (widget.bookData['endDate'] != null) {
      _endDate = widget.bookData['endDate'] is Timestamp
          ? (widget.bookData['endDate'] as Timestamp).toDate()
          : DateTime.now();
      _endDateController.text = DateFormat('yyyy. MM. dd').format(_endDate!);
    }

    // 기본 날짜 설정 (없는 경우)
    if (_startDate == null && _selectedCategory == MyLibraryService.READING) {
      _startDate = DateTime.now();
      _startDateController.text = DateFormat('yyyy. MM. dd').format(_startDate!);
    }

    if (_endDate == null && _selectedCategory == MyLibraryService.COMPLETED) {
      _endDate = DateTime.now();
      _endDateController.text = DateFormat('yyyy. MM. dd').format(_endDate!);
    }
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  // 날짜 선택 다이얼로그
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          _startDateController.text = DateFormat('yyyy. MM. dd').format(picked);
        } else {
          _endDate = picked;
          _endDateController.text = DateFormat('yyyy. MM. dd').format(picked);
        }
      });
    }
  }

  // 내 서재에 도서 추가
  Future<void> _addToLibrary() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      bool success;
      final bookData = widget.bookData;

      // 이미 추가된 도서라면 카테고리 변경
      if (widget.existingCategory != null && widget.existingCategory != _selectedCategory) {
        success = await _myLibraryService.moveBookToCategory(
          isbn: bookData['isbn'],
          fromCategory: widget.existingCategory!,
          toCategory: _selectedCategory,
          startDate: _startDate,
          endDate: _endDate,
        );
      }
      // 기존 카테고리와 동일한 경우 - 날짜만 업데이트
      else if (widget.existingCategory != null && widget.existingCategory == _selectedCategory) {
        // 임시로 삭제 후 다시 추가
        await _myLibraryService.removeBookFromLibrary(bookData['isbn'], _selectedCategory);

        success = await _myLibraryService.addBookToLibrary(
          bookData: bookData,
          category: _selectedCategory,
          startDate: _startDate,
          endDate: _endDate,
        );
      }
      // 새로 추가
      else {
        success = await _myLibraryService.addBookToLibrary(
          bookData: bookData,
          category: _selectedCategory,
          startDate: _startDate,
          endDate: _endDate,
        );
      }

      if (success) {
        Navigator.pop(context);
        widget.onSaved(_selectedCategory);
      } else {
        _showErrorMessage('도서 추가 실패');
      }
    } catch (e) {
      if (kDebugMode) {
        print('도서 추가 오류: $e');
      }
      _showErrorMessage('오류가 발생했습니다');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 내 서재에서 도서 삭제
  Future<void> _removeFromLibrary() async {
    if (_isLoading || widget.existingCategory == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _myLibraryService.removeBookFromLibrary(
        widget.bookData['isbn'],
        widget.existingCategory!,
      );

      if (success) {
        Navigator.pop(context);
        widget.onRemoved();
      } else {
        _showErrorMessage('도서 삭제 실패');
      }
    } catch (e) {
      if (kDebugMode) {
        print('도서 삭제 오류: $e');
      }
      _showErrorMessage('오류가 발생했습니다');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 오류 메시지 표시
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 16.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타이틀
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const Text(
                  '내 서재에 책 담기',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 24), // 정렬을 위한 빈 공간
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 독서 상태 선택
          const Text(
            '독서 상태',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),

          // 독서 상태 버튼들
          Row(
            children: [
              _buildCategoryButton('완독한 도서', MyLibraryService.COMPLETED),
              const SizedBox(width: 8),
              _buildCategoryButton('읽고 있는 책', MyLibraryService.READING),
              const SizedBox(width: 8),
              _buildCategoryButton('읽고 싶은 책', MyLibraryService.WISHLIST),
            ],
          ),

          const SizedBox(height: 24),

          // 읽기 시작일/완료일 (해당되는 경우만)
          if (_selectedCategory == MyLibraryService.READING ||
              _selectedCategory == MyLibraryService.COMPLETED) ...[
            const Text(
              '독서 기간',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                // 시작일
                Expanded(
                  child: TextField(
                    controller: _startDateController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: '시작일',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      suffixIcon: Icon(Icons.calendar_today, size: 20),
                    ),
                    onTap: () => _selectDate(context, true),
                  ),
                ),

                const SizedBox(width: 16),

                // 완료일 (완독한 도서인 경우만)
                if (_selectedCategory == MyLibraryService.COMPLETED)
                  Expanded(
                    child: TextField(
                      controller: _endDateController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: '완료일',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        suffixIcon: Icon(Icons.calendar_today, size: 20),
                      ),
                      onTap: () => _selectDate(context, false),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 24),
          ],

          // 저장 버튼
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _addToLibrary,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Text(
                '저장',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // 삭제 버튼 (기존에 추가된 도서인 경우)
          if (widget.existingCategory != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _isLoading ? null : _removeFromLibrary,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '내 서재에서 삭제',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 카테고리 버튼 위젯
  Widget _buildCategoryButton(String label, String category) {
    final isSelected = _selectedCategory == category;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategory = category;

            // 읽기 시작 날짜 자동 설정 (없는 경우)
            if (category == MyLibraryService.READING && _startDate == null) {
              _startDate = DateTime.now();
              _startDateController.text = DateFormat('yyyy. MM. dd').format(_startDate!);
            }

            // 완독일 자동 설정 (없는 경우)
            if (category == MyLibraryService.COMPLETED && _endDate == null) {
              _endDate = DateTime.now();
              _endDateController.text = DateFormat('yyyy. MM. dd').format(_endDate!);
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.transparent,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.black,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BookInfoContent extends StatelessWidget {
  final Map<String, dynamic> bookData;
  final TabController tabController;

  const BookInfoContent({
    super.key,
    required this.bookData,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 기본 정보 영역 (제목, 이미지, 저자) - 중앙 정렬
        Center(  // Center 위젯으로 감싸서 전체 콘텐츠를 중앙 정렬
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                // 책 제목
                Text(
                  bookData['title'] ?? '제목 없음',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF5A5959),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),

                // 책 이미지
                Container(
                  width: 170,
                  height: 238,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    image: DecorationImage(
                      image: NetworkImage(
                          bookData['coverUrl'] ?? 'https://via.placeholder.com/170x238?text=No+Cover'
                      ),
                      fit: BoxFit.cover,
                      onError: (_, __) {
                        if (kDebugMode) {
                          print('이미지 로드 실패');
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 저자 정보
                Text(
                  _buildAuthorText(),
                  textAlign: TextAlign.center,  // 텍스트 내용도 중앙 정렬
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.67,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),

        // 탭 섹션
        BookInfoTabs(tabController: tabController),

        // 탭 콘텐츠 - Expanded로 감싸서 남은 공간을 모두 사용하게 함
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              // 상세 정보 탭 - 왼쪽 정렬 유지
              _buildDetailsTab(),

              // 리뷰 탭 (미구현)
              const Center(
                child: Text('리뷰 기능은 준비 중입니다.'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 저자 정보 텍스트 생성
  String _buildAuthorText() {
    String authorText = bookData['author'] ?? '저자 미상';

    // 번역자 정보가 있는 경우 추가
    if (bookData['translator'] != null && bookData['translator'].toString().isNotEmpty) {
      authorText += ' · ${bookData['translator']} 번역';
    }

    return authorText;
  }

  // 상세 정보 탭 내용
  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 책 소개
          const Text(
            '책 소개',
            style: TextStyle(
              color: Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            bookData['description'] ?? '책 소개가 없습니다.',
            style: const TextStyle(
              color: Color(0xFF4C4C4C),
              fontSize: 12,
              height: 1.67,
            ),
          ),
          const SizedBox(height: 20),

          // 출판사 정보
          BookInfoItem(title: '출판사', value: bookData['publisher'] ?? '정보 없음'),
          const SizedBox(height: 10),

          // ISBN 정보
          BookInfoItem(title: 'ISBN', value: bookData['isbn'] ?? '정보 없음'),
          const SizedBox(height: 10),

          // 페이지 정보
          BookInfoItem(title: '페이지',
              value: bookData['itemPage'] != null && bookData['itemPage'] != 0
                  ? '${bookData['itemPage']}p'
                  : '정보 없음'),
          const SizedBox(height: 10),

          // 추가: 출판일
          if (bookData['pubDate'] != null)
            BookInfoItem(title: '출판일', value: bookData['pubDate']),
          const SizedBox(height: 20),

          // 도서 DB 정보를 탭 내부로 이동
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '도서 DB: ${bookData['dataSource'] ?? '알라딘'}',
              style: const TextStyle(
                color: Color(0xFF4C4C4C),
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class BookInfoTabs extends StatelessWidget {
  final TabController tabController;

  const BookInfoTabs({
    super.key,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 탭 버튼들
        TabBar(
          controller: tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          tabs: const [
            Tab(text: '상세 정보'),
            Tab(text: '리뷰'),
          ],
        ),
      ],
    );
  }
}

class BookInfoItem extends StatelessWidget {
  final String title;
  final String value;

  const BookInfoItem({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF4C4C4C),
            fontSize: 12,
            height: 1.67,
          ),
        ),
      ],
    );
  }
}