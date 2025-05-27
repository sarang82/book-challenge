import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../services/book_search_service.dart';

class ReadingMemoScreen extends StatefulWidget {
  final Map<String, dynamic>? memoToEdit; // 수정 모드일 경우 해당 메모 데이터

  const ReadingMemoScreen({
    super.key,
    this.memoToEdit,
  });

  @override
  State<ReadingMemoScreen> createState() => _ReadingMemoScreenState();
}

class _ReadingMemoScreenState extends State<ReadingMemoScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BookSearchService _searchService = BookSearchService();

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quoteController = TextEditingController();
  final TextEditingController _thoughtsController = TextEditingController();

  bool _isLoading = false;
  bool _isSearching = false;
  bool _isSearchLoading = false;
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedBook;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    // 수정 모드인 경우 기존 데이터 로드
    if (widget.memoToEdit != null) {
      _loadMemoData();
    }
  }

  void _loadMemoData() {
    final memo = widget.memoToEdit!;
    _quoteController.text = memo['quote'] ?? '';
    _thoughtsController.text = memo['thoughts'] ?? '';

    // 선택된 책 정보 복원
    _selectedBook = {
      'title': memo['bookTitle'] ?? '',
      'author': memo['bookAuthor'] ?? '',
      'coverUrl': memo['coverUrl'] ?? '',
    };
    _searchController.text = _selectedBook!['title'];
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _quoteController.dispose();
    _thoughtsController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.isNotEmpty && _selectedBook == null) {
        _performSearch(_searchController.text);
      } else if (_searchController.text.isEmpty) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
          _selectedBook = null;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearchLoading = true;
      _isSearching = true;
    });

    try {
      final results = await _searchService.searchBooks(query);
      setState(() {
        _searchResults = results;
        _isSearchLoading = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearchLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('검색 중 오류가 발생했습니다: $e')),
      );
    }
  }

  void _selectBook(Map<String, dynamic> book) {
    setState(() {
      _selectedBook = book;
      _searchController.text = book['title'] ?? '';
      _isSearching = false;
      _searchResults = [];
    });
    FocusScope.of(context).unfocus();
  }

  void _clearBookSelection() {
    setState(() {
      _selectedBook = null;
      _searchController.clear();
      _isSearching = false;
      _searchResults = [];
    });
  }

  // 메모 저장
  Future<void> _saveMemo() async {
    if (_selectedBook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('책을 선택해주세요.')),
      );
      return;
    }

    if (_quoteController.text.trim().isEmpty && _thoughtsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인용구 또는 감상을 입력해주세요.')),
      );
      return;
    }

    if (_auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = _auth.currentUser!.uid;
      final isEditMode = widget.memoToEdit != null;

      Map<String, dynamic> memoData = {
        'userId': userId,
        'bookTitle': _selectedBook!['title'] ?? '',
        'bookAuthor': _selectedBook!['author'] ?? '',
        'coverUrl': _selectedBook!['coverUrl'] ?? '',
        'quote': _quoteController.text.trim(),
        'thoughts': _thoughtsController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!isEditMode) {
        memoData['createdAt'] = FieldValue.serverTimestamp();
      }

      // Firestore에 저장
      if (isEditMode) {
        // 메모 수정
        await _firestore
            .collection('readingMemos')
            .doc(widget.memoToEdit!['id'])
            .update(memoData);
      } else {
        // 새 메모 작성
        await _firestore
            .collection('readingMemos')
            .add(memoData);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEditMode ? '메모가 수정되었습니다.' : '메모가 저장되었습니다.')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (kDebugMode) {
        print('메모 저장 오류: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메모 저장 중 오류가 발생했습니다.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.memoToEdit != null;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            isEditMode ? '메모 수정' : '독서 메모 작성',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            TextButton(
              onPressed: _isLoading ? null : _saveMemo,
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
            : Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 도서 선택
                  _buildSectionTitle('도서 선택'),
                  const SizedBox(height: 12),
                  _buildBookSelector(),

                  if (_selectedBook != null) ...[
                    const SizedBox(height: 16),
                    _buildSelectedBook(),
                  ],

                  const SizedBox(height: 24),

                  // 인용구
                  _buildSectionTitle('인상 깊은 구절'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _quoteController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: '마음에 든 구절을 적어보세요.',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 감상
                  _buildSectionTitle('나의 생각'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _thoughtsController,
                    maxLines: 6,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      hintText: '이 책에 대한 생각이나 느낀 점을 자유롭게 작성해보세요.',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  const SizedBox(height: 100), // 하단 여백
                ],
              ),
            ),

            // 검색 결과 오버레이
            if (_isSearching)
              Positioned(
                top: 100, // 도서 선택 섹션 아래에 위치
                left: 16,
                right: 16,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _isSearchLoading
                      ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                      : _searchResults.isEmpty
                      ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        '"${_searchController.text}" 검색 결과가 없습니다',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  )
                      : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final book = _searchResults[index];
                      return _buildBookSearchItem(book);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildBookSelector() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: '책 제목을 검색하세요',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _selectedBook != null
            ? IconButton(
          icon: const Icon(Icons.clear),
          onPressed: _clearBookSelection,
        )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      readOnly: _selectedBook != null,
    );
  }

  Widget _buildSelectedBook() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(
              _selectedBook!['coverUrl'] ?? 'https://via.placeholder.com/100x150?text=No+Cover',
              width: 50,
              height: 75,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 50,
                height: 75,
                color: Colors.grey[300],
                child: const Icon(Icons.book, size: 30),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedBook!['title'] ?? '제목 없음',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedBook!['author'] ?? '저자 미상',
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
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: _clearBookSelection,
          ),
        ],
      ),
    );
  }

  Widget _buildBookSearchItem(Map<String, dynamic> book) {
    return InkWell(
      onTap: () => _selectBook(book),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.withOpacity(0.3)),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                book['coverUrl'] ?? 'https://via.placeholder.com/100x150?text=No+Cover',
                width: 40,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 40,
                  height: 60,
                  color: Colors.grey[300],
                  child: const Icon(Icons.book, size: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book['title'] ?? '제목 없음',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book['author'] ?? '저자 미상',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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