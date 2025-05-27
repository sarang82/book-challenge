import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'reading_memo_screen.dart';

class ReadingRecordsScreen extends StatefulWidget {
  const ReadingRecordsScreen({super.key});

  @override
  State<ReadingRecordsScreen> createState() => _ReadingRecordsScreenState();
}

class _ReadingRecordsScreenState extends State<ReadingRecordsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _memos = [];
  List<Map<String, dynamic>> _filteredMemos = [];
  bool _isLoading = true;
  String _selectedFilter = '전체';
  String _sortBy = '최신순';

  final List<String> _sortOptions = ['최신순', '오래된순', '책 제목순'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterMemos);
    _loadMemos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 날짜 포맷 함수
  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  // 메모 로드
  Future<void> _loadMemos() async {
    if (_auth.currentUser == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final userId = _auth.currentUser!.uid;
      // 단순한 쿼리로 변경 (인덱스 불필요)
      final querySnapshot = await _firestore
          .collection('readingMemos')
          .where('userId', isEqualTo: userId)
          .get();

      List<Map<String, dynamic>> memos = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id; // 문서 ID 추가
        memos.add(data);
      }

      // 클라이언트에서 날짜순으로 정렬
      memos.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime); // 최신순
      });

      setState(() {
        _memos = memos;
        _filteredMemos = memos;
        _isLoading = false;
      });

      _applySorting();
    } catch (e) {
      if (kDebugMode) {
        print('메모 로드 오류: $e');
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 메모 필터링
  void _filterMemos() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredMemos = _memos.where((memo) {
        final matchesSearch = query.isEmpty ||
            memo['bookTitle'].toString().toLowerCase().contains(query) ||
            memo['bookAuthor'].toString().toLowerCase().contains(query) ||
            memo['quote'].toString().toLowerCase().contains(query) ||
            memo['thoughts'].toString().toLowerCase().contains(query);

        return matchesSearch;
      }).toList();
    });

    _applySorting();
  }

  // 정렬 적용
  void _applySorting() {
    setState(() {
      switch (_sortBy) {
        case '최신순':
          _filteredMemos.sort((a, b) {
            final aTime = a['createdAt'] as Timestamp?;
            final bTime = b['createdAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });
          break;
        case '오래된순':
          _filteredMemos.sort((a, b) {
            final aTime = a['createdAt'] as Timestamp?;
            final bTime = b['createdAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return aTime.compareTo(bTime);
          });
          break;
        case '책 제목순':
          _filteredMemos.sort((a, b) {
            final aTitle = a['bookTitle']?.toString() ?? '';
            final bTitle = b['bookTitle']?.toString() ?? '';
            return aTitle.compareTo(bTitle);
          });
          break;
      }
    });
  }

  // 메모 삭제
  Future<void> _deleteMemo(String memoId) async {
    try {
      await _firestore.collection('readingMemos').doc(memoId).delete();

      setState(() {
        _memos.removeWhere((memo) => memo['id'] == memoId);
        _filteredMemos.removeWhere((memo) => memo['id'] == memoId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메모가 삭제되었습니다.')),
      );
    } catch (e) {
      if (kDebugMode) {
        print('메모 삭제 오류: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메모 삭제 중 오류가 발생했습니다.')),
      );
    }
  }

  // 메모 삭제 확인 다이얼로그
  void _showDeleteConfirmDialog(String memoId, String bookTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('메모 삭제'),
        content: Text('\'$bookTitle\'의 메모를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMemo(memoId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  // 메모 수정 화면으로 이동
  void _navigateToEditMemo(Map<String, dynamic> memo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReadingMemoScreen(memoToEdit: memo),
      ),
    ).then((_) {
      // 수정 후 목록 새로고침
      _loadMemos();
    });
  }

  // 새 메모 작성 화면으로 이동
  void _navigateToNewMemo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReadingMemoScreen(),
      ),
    ).then((_) {
      // 작성 후 목록 새로고침
      _loadMemos();
    });
  }

  // 메모 상세보기 다이얼로그
  void _showMemoDetailDialog(Map<String, dynamic> memo) {
    final createdAt = memo['createdAt'] != null
        ? (memo['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white, // 배경색을 흰색으로 설정
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600),
          decoration: BoxDecoration(
            color: Colors.white, // 컨테이너도 흰색으로 설정
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              memo['bookTitle'] ?? '제목 없음',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (memo['bookAuthor'] != null && memo['bookAuthor'].toString().isNotEmpty)
                              Text(
                                memo['bookAuthor'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 메타데이터 (날짜만)
                  Row(
                    children: [
                      Text(
                        _formatDate(createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 인용구 (네모박스 제거)
                  if (memo['quote'] != null && memo['quote'].toString().isNotEmpty) ...[
                    const Text(
                      '인상 깊은 구절',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"${memo['quote']}"',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 감상
                  if (memo['thoughts'] != null && memo['thoughts'].toString().isNotEmpty) ...[
                    const Text(
                      '나의 생각',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      memo['thoughts'],
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '독서 기록',
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
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            onPressed: _navigateToNewMemo,
          ),
        ],
      ),
      body: Column(
        children: [
          // 검색 및 필터
          _buildSearchAndFilter(),

          // 메모 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMemos.isEmpty
                ? _buildEmptyState()
                : _buildMemoList(),
          ),
        ],
      ),
    );
  }

  // 검색 및 필터 위젯
  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 검색바
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '책 제목, 저자, 내용으로 검색...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 정렬 필터만 표시
          DropdownButtonFormField<String>(
            value: _sortBy,
            decoration: InputDecoration(
              labelText: '정렬',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _sortOptions.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Text(option),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _sortBy = value!;
              });
              _applySorting();
            },
          ),
        ],
      ),
    );
  }

  // 빈 상태 위젯
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty
                ? '검색 결과가 없습니다'
                : '아직 작성된 독서 기록이 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToNewMemo,
            icon: const Icon(Icons.add),
            label: const Text('첫 메모 작성하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFEE798),
              foregroundColor: Colors.orange[800],
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // 메모 목록 위젯
  Widget _buildMemoList() {
    return RefreshIndicator(
      onRefresh: _loadMemos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredMemos.length,
        itemBuilder: (context, index) {
          final memo = _filteredMemos[index];
          return _buildMemoItem(memo);
        },
      ),
    );
  }

  // 개별 메모 아이템 위젯
  Widget _buildMemoItem(Map<String, dynamic> memo) {
    final createdAt = memo['createdAt'] != null
        ? (memo['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: Colors.white, // 카드 배경색을 흰색으로 설정
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showMemoDetailDialog(memo),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white, // 컨테이너 배경색도 흰색으로 설정
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더 (제목, 저자, 메뉴)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          memo['bookTitle'] ?? '제목 없음',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (memo['bookAuthor'] != null && memo['bookAuthor'].toString().isNotEmpty)
                          Text(
                            memo['bookAuthor'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _navigateToEditMemo(memo);
                      } else if (value == 'delete') {
                        _showDeleteConfirmDialog(memo['id'], memo['bookTitle'] ?? '');
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('수정'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('삭제'),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 내용 미리보기 (인상 깊은 구절만 표시)
              if (memo['quote'] != null && memo['quote'].toString().isNotEmpty)
                Text(
                  '"${memo['quote']}"',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

              const SizedBox(height: 12),

              // 메타 정보 (날짜만, 책 표지 제거)
              Row(
                children: [
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  // 책 표지 이미지 제거
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}