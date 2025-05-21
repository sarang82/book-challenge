import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookReviewTab extends StatefulWidget {
  final String isbn;
  final String title;
  final String author;
  final String coverUrl;

  const BookReviewTab({
    super.key,
    required this.isbn,
    required this.title,
    required this.author,
    required this.coverUrl,
  });

  @override
  State<BookReviewTab> createState() => _BookReviewTabState();
}

class _BookReviewTabState extends State<BookReviewTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  bool _hasWrittenReview = false;
  bool _isLoadingMore = false;
  List<Map<String, dynamic>> _reviews = [];
  late ScrollController _scrollController;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreReviews = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    _loadReviews();
    _checkUserReview();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // 스크롤 리스너 - 페이지네이션을 위한 스크롤 감지
  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMoreReviews) {
      _loadMoreReviews();
    }
  }

  // 사용자의 리뷰 존재 여부 확인
  Future<void> _checkUserReview() async {
    if (_auth.currentUser == null) {
      setState(() {
        _hasWrittenReview = false;
      });
      return;
    }

    try {
      final userId = _auth.currentUser!.uid;
      final docSnapshot = await _firestore
          .collection('bookReviews')
          .doc(widget.isbn)
          .collection('reviews')
          .doc(userId)
          .get();

      setState(() {
        _hasWrittenReview = docSnapshot.exists;
      });
    } catch (e) {
      if (kDebugMode) {
        print('사용자 리뷰 확인 오류: $e');
      }
      setState(() {
        _hasWrittenReview = false;
      });
    }
  }

  // 초기 리뷰 로드
  Future<void> _loadReviews() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final querySnapshot = await _firestore
          .collection('bookReviews')
          .doc(widget.isbn)
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _reviews = [];
          _isLoading = false;
          _hasMoreReviews = false;
        });
        return;
      }

      List<Map<String, dynamic>> reviews = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        // 작성자 정보 가져오기
        String authorId = data['userId'] ?? '';
        String authorNickname = '알 수 없음';

        if (authorId.isNotEmpty) {
          try {
            final userDoc = await _firestore.collection('users').doc(authorId).get();
            if (userDoc.exists) {
              authorNickname = userDoc.get('nickname') ?? '알 수 없음';
            }
          } catch (e) {
            if (kDebugMode) {
              print('작성자 정보 로드 오류: $e');
            }
          }
        }

        // 현재 사용자의 좋아요 여부 확인
        bool isLiked = false;
        if (_auth.currentUser != null) {
          List<dynamic> likedUsers = data['likedUsers'] ?? [];
          isLiked = likedUsers.contains(_auth.currentUser!.uid);
        }

        reviews.add({
          ...data,
          'id': doc.id,
          'authorNickname': authorNickname,
          'isLiked': isLiked,
        });
      }

      setState(() {
        _reviews = reviews;
        _isLoading = false;
        _lastDocument = querySnapshot.docs.last;
        _hasMoreReviews = querySnapshot.docs.length >= 10;
      });
    } catch (e) {
      if (kDebugMode) {
        print('리뷰 로드 오류: $e');
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 더 많은 리뷰 로드 (페이지네이션)
  Future<void> _loadMoreReviews() async {
    if (!_hasMoreReviews || _lastDocument == null) return;

    try {
      setState(() {
        _isLoadingMore = true;
      });

      final querySnapshot = await _firestore
          .collection('bookReviews')
          .doc(widget.isbn)
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(10)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _isLoadingMore = false;
          _hasMoreReviews = false;
        });
        return;
      }

      List<Map<String, dynamic>> newReviews = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        // 작성자 정보 가져오기
        String authorId = data['userId'] ?? '';
        String authorNickname = '알 수 없음';

        if (authorId.isNotEmpty) {
          try {
            final userDoc = await _firestore.collection('users').doc(authorId).get();
            if (userDoc.exists) {
              authorNickname = userDoc.get('nickname') ?? '알 수 없음';
            }
          } catch (e) {
            if (kDebugMode) {
              print('작성자 정보 로드 오류: $e');
            }
          }
        }

        // 현재 사용자의 좋아요 여부 확인
        bool isLiked = false;
        if (_auth.currentUser != null) {
          List<dynamic> likedUsers = data['likedUsers'] ?? [];
          isLiked = likedUsers.contains(_auth.currentUser!.uid);
        }

        newReviews.add({
          ...data,
          'id': doc.id,
          'authorNickname': authorNickname,
          'isLiked': isLiked,
        });
      }

      setState(() {
        _reviews.addAll(newReviews);
        _isLoadingMore = false;
        _lastDocument = querySnapshot.docs.last;
        _hasMoreReviews = querySnapshot.docs.length >= 10;
      });
    } catch (e) {
      if (kDebugMode) {
        print('더 많은 리뷰 로드 오류: $e');
      }
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  // 리뷰 좋아요 토글
  Future<void> _toggleLike(Map<String, dynamic> review) async {
    if (_auth.currentUser == null) {
      _showLoginPrompt();
      return;
    }

    final userId = _auth.currentUser!.uid;
    final reviewId = review['id'];
    final isLiked = review['isLiked'] ?? false;

    try {
      final reviewRef = _firestore
          .collection('bookReviews')
          .doc(widget.isbn)
          .collection('reviews')
          .doc(reviewId);

      if (isLiked) {
        // 좋아요 취소
        await reviewRef.update({
          'likedUsers': FieldValue.arrayRemove([userId]),
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        // 좋아요 추가
        await reviewRef.update({
          'likedUsers': FieldValue.arrayUnion([userId]),
          'likeCount': FieldValue.increment(1),
        });
      }

      // 로컬 상태 업데이트
      setState(() {
        final reviewIndex = _reviews.indexWhere((r) => r['id'] == reviewId);
        if (reviewIndex != -1) {
          _reviews[reviewIndex]['isLiked'] = !isLiked;
          _reviews[reviewIndex]['likeCount'] = (_reviews[reviewIndex]['likeCount'] ?? 0) + (isLiked ? -1 : 1);
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('좋아요 토글 오류: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('좋아요 처리 중 오류가 발생했습니다.')),
      );
    }
  }

  // 자신의 리뷰 삭제
  Future<void> _deleteReview(Map<String, dynamic> review) async {
    final reviewId = review['id'];

    try {
      // Firestore에서 리뷰 삭제
      await _firestore
          .collection('bookReviews')
          .doc(widget.isbn)
          .collection('reviews')
          .doc(reviewId)
          .delete();

      // 로컬 상태 업데이트
      setState(() {
        _reviews.removeWhere((r) => r['id'] == reviewId);
        _hasWrittenReview = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('리뷰가 삭제되었습니다.')),
      );
    } catch (e) {
      if (kDebugMode) {
        print('리뷰 삭제 오류: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('리뷰 삭제 중 오류가 발생했습니다.')),
      );
    }
  }

  // 로그인 안내 다이얼로그
  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그인 필요'),
        content: const Text('이 기능을 이용하려면, 로그인이 필요합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/login').then((_) {
                // 로그인 완료 후 리뷰 상태 갱신
                if (_auth.currentUser != null) {
                  _loadReviews();
                  _checkUserReview();
                }
              });
            },
            child: const Text('로그인'),
          ),
        ],
      ),
    );
  }

  // 리뷰 작성 화면으로 이동
  void _navigateToWriteReview() {
    if (_auth.currentUser == null) {
      _showLoginPrompt();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WriteReviewScreen(
          isbn: widget.isbn,
          title: widget.title,
          author: widget.author,
          coverUrl: widget.coverUrl,
        ),
      ),
    ).then((_) {
      // 리뷰 작성 후 화면으로 돌아오면 리뷰 목록 갱신
      _loadReviews();
      _checkUserReview();
    });
  }

  // 리뷰 수정 화면으로 이동
  void _navigateToEditReview(Map<String, dynamic> review) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WriteReviewScreen(
          isbn: widget.isbn,
          title: widget.title,
          author: widget.author,
          coverUrl: widget.coverUrl,
          reviewToEdit: review,
        ),
      ),
    ).then((_) {
      // 리뷰 수정 후 화면으로 돌아오면 리뷰 목록 갱신
      _loadReviews();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '리뷰',
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
          // 리뷰 작성 버튼 (연필 아이콘)
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black),
            onPressed: _hasWrittenReview ? null : _navigateToWriteReview,
            // 이미 리뷰를 작성한 경우 비활성화
            color: _hasWrittenReview ? Colors.grey : Colors.black,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reviews.isEmpty
          ? _buildEmptyReviews()
          : _buildReviewList(),
    );
  }

  // 리뷰가 없을 때 표시할 위젯
  Widget _buildEmptyReviews() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            '아직 등록된 리뷰가 없습니다.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // 리뷰 목록 위젯
  Widget _buildReviewList() {
    return RefreshIndicator(
      onRefresh: _loadReviews,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _reviews.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _reviews.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final review = _reviews[index];
          final isMyReview = review['userId'] == _auth.currentUser?.uid;

          return _buildReviewItem(review, isMyReview);
        },
      ),
    );
  }

  // 개별 리뷰 아이템 위젯
  Widget _buildReviewItem(Map<String, dynamic> review, bool isMyReview) {
    final authorNickname = review['authorNickname'] ?? '알 수 없음';
    final rating = review['rating'] ?? 0;
    final content = review['content'] ?? '';
    final createdAt = review['createdAt'] != null
        ? (review['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    final likeCount = review['likeCount'] ?? 0;
    final isLiked = review['isLiked'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 리뷰 헤더 (작성자, 별점, 날짜)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorNickname,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // 별점 표시
                          Row(
                            children: List.generate(5, (index) {
                              return Icon(
                                index < rating ? Icons.star : Icons.star_border,
                                color: index < rating ? Colors.amber : Colors.grey,
                                size: 16,
                              );
                            }),
                          ),
                          const SizedBox(width: 8),
                          // 작성일 표시
                          Text(
                            '${createdAt.year}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.day.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 내 리뷰인 경우 수정/삭제 메뉴
                if (isMyReview)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _navigateToEditReview(review);
                      } else if (value == 'delete') {
                        _showDeleteConfirmDialog(review);
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

            // 리뷰 내용
            Text(
              content,
              style: const TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 12),

            // 좋아요 버튼 및 카운트
            Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleLike(review),
                  child: Icon(
                    isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    color: isLiked ? Colors.blue : Colors.grey,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  likeCount.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    color: isLiked ? Colors.blue : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 리뷰 삭제 확인 다이얼로그
  void _showDeleteConfirmDialog(Map<String, dynamic> review) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('리뷰 삭제'),
        content: const Text('이 리뷰를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteReview(review);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

// 리뷰 작성 화면
class WriteReviewScreen extends StatefulWidget {
  final String isbn;
  final String title;
  final String author;
  final String coverUrl;
  final Map<String, dynamic>? reviewToEdit; // 수정 모드일 경우 해당 리뷰 데이터

  const WriteReviewScreen({
    super.key,
    required this.isbn,
    required this.title,
    required this.author,
    required this.coverUrl,
    this.reviewToEdit,
  });

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _contentController = TextEditingController();

  int _rating = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 수정 모드인 경우 기존 데이터 로드
    if (widget.reviewToEdit != null) {
      _rating = widget.reviewToEdit!['rating'] ?? 0;
      _contentController.text = widget.reviewToEdit!['content'] ?? '';
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  // 리뷰 저장
  Future<void> _saveReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('별점을 선택해주세요.')),
      );
      return;
    }

    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용을 입력해주세요.')),
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
      final isEditMode = widget.reviewToEdit != null;

      Map<String, dynamic> reviewData = {
        'userId': userId,
        'rating': _rating,
        'content': _contentController.text.trim(),
        'likeCount': isEditMode ? widget.reviewToEdit!['likeCount'] ?? 0 : 0,
        'likedUsers': isEditMode ? widget.reviewToEdit!['likedUsers'] ?? [] : [],
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!isEditMode) {
        // 새 리뷰 추가 시 생성 시간 추가
        reviewData['createdAt'] = FieldValue.serverTimestamp();
      }

      // Firestore에 저장
      if (isEditMode) {
        // 리뷰 수정
        await _firestore
            .collection('bookReviews')
            .doc(widget.isbn)
            .collection('reviews')
            .doc(userId)
            .update(reviewData);
      } else {
        // 새 리뷰 작성
        await _firestore
            .collection('bookReviews')
            .doc(widget.isbn)
            .collection('reviews')
            .doc(userId)
            .set(reviewData);
      }

      // 도서 평균 평점 업데이트
      await _updateBookAverageRating(widget.isbn);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEditMode ? '리뷰가 수정되었습니다.' : '리뷰가 등록되었습니다.')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (kDebugMode) {
        print('리뷰 저장 오류: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('리뷰 저장 중 오류가 발생했습니다.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 책의 평균 평점 업데이트
  Future<void> _updateBookAverageRating(String isbn) async {
    try {
      final reviewsSnapshot = await _firestore
          .collection('bookReviews')
          .doc(isbn)
          .collection('reviews')
          .get();

      if (reviewsSnapshot.docs.isEmpty) return;

      int totalRating = 0;
      for (var doc in reviewsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final rating = data['rating'];
        if (rating is int) {
          totalRating += rating;
        } else if (rating is double) {
          totalRating += rating.toInt();
        }
      }

      double averageRating = totalRating / reviewsSnapshot.docs.length;

      // 도서의 평균 평점 업데이트
      await _firestore
          .collection('bookReviews')
          .doc(isbn)
          .set({
        'averageRating': averageRating,
        'reviewCount': reviewsSnapshot.docs.length,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        print('평균 평점 업데이트 오류: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.reviewToEdit != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isEditMode ? '리뷰 수정' : '리뷰 작성',
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
            onPressed: _isLoading ? null : _saveReview,
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
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 도서 정보
            _buildBookInfo(),
            const SizedBox(height: 24),

            // 별점 선택
            const Text(
              '별점',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: index < _rating ? Colors.amber : Colors.grey,
                    size: 36,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = index + 1;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 24),

            // 리뷰 내용
            const Text(
              '리뷰 내용',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              maxLines: 6,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: '이 책에 대한 생각을 자유롭게 작성해주세요.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 도서 정보 위젯
  Widget _buildBookInfo() {
    return Row(
      children: [
      // 책 커버
      Container(
      width: 60,
      height: 84,
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
          image: NetworkImage(widget.coverUrl),
          fit: BoxFit.cover,
          onError: (_, __) {
            if (kDebugMode) {
              print('이미지 로드 실패');
            }
          },
        ),
      ),
    ),
    const SizedBox(width: 16),
    // 책 정보
    Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          widget.author,
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
      ],
    );
  }
}