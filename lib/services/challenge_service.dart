import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'aladin_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ChallengeService (“overwrite” 방식으로 변경됨)
// ─────────────────────────────────────────────────────────────────────────────
class ChallengeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AladinService _aladinService = AladinService();

  // ───────────────────────────────────────────────────────────────────────────
  // 오늘 날짜 한글 기준으로 “YYYY-MM-DD” 포맷
  String _formatToday() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 챌린지 생성 (원본 코드와 동일)
  Future<void> createChallenge({
    required String title,
    required String type, // '완독', '시간'
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    required String bookId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("로그인된 사용자가 없습니다.");

    final bookDetail = await _aladinService.fetchBookDetail(bookId);
    final coverUrl = bookDetail?['coverUrl'] ?? '';
    final bookTitle = bookDetail?['title'] ?? '';

    await _firestore.collection('challenge').add({
      'userId': uid,
      'isbn': bookId,
      'coverUrl': coverUrl,
      'title': title,
      'bookTitle': bookTitle,
      'description': description,
      'type': type,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'itemPage': bookDetail?['itemPage'] ?? 0,
      'pagesRead': 0, // 최초 0으로 세팅
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 챌린지 목록 조회 (원본 코드와 동일)
  Future<List<Challenge>> getChallenges() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("로그인 된 사용자가 없습니다.");

    final querySnapshot = await _firestore
        .collection('challenge')
        .where('userId', isEqualTo: uid)
        .orderBy('startDate')
        .get();

    return querySnapshot.docs
        .map((doc) => Challenge.fromDocument(doc))
        .toList();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 1) “오늘까지 읽은 누적 페이지” 조회 (Overwrite 방식)
  Future<int> getTodayPagesRead(String challengeId, String userId) async {
    final today = _formatToday();

    final doc = await _firestore
        .collection('challenge')
        .doc(challengeId)
        .collection('pagesRead')
        .doc(userId)
        .collection('daily')
        .doc(today)
        .get();

    if (doc.exists) {
      final data = doc.data();
      return (data?['cumulativePagesRead'] as int?) ?? 0;
    } else {
      return 0;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2) 챌린지 “전체 누적 페이지” 조회
  Future<int> getTotalPagesRead(String challengeId, String userId) async {
    final challengeDoc = await _firestore
        .collection('challenge')
        .doc(challengeId)
        .get();

    if (challengeDoc.exists) {
      final data = challengeDoc.data() as Map<String, dynamic>;
      return (data['pagesRead'] as int?) ?? 0;
    }
    return 0;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3) “오늘까지 읽은 누적 페이지” 덮어쓰기( overwrite ) 저장
  Future<void> saveTodayPagesRead(
      String challengeId, String userId, int cumulativePages) async {
    final today = _formatToday();

    // ─ (1) daily 문서에 cumulativePagesRead 저장 (overwrite)
    await _firestore
        .collection('challenge')
        .doc(challengeId)
        .collection('pagesRead')
        .doc(userId)
        .collection('daily')
        .doc(today)
        .set({
      'cumulativePagesRead': cumulativePages,
      'date': today,
    });

    // ─ (2) challenge 문서의 pagesRead 필드도 동일 누적값으로 overwrite
    await _firestore
        .collection('challenge')
        .doc(challengeId)
        .update({'pagesRead': cumulativePages});
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 4) 전체 일일 기록 가져오기 (date 순서대로)
  Future<List<DailyPageRead>> getAllPagesRead(
      String challengeId, String userId) async {
    final snapshot = await _firestore
        .collection('challenge')
        .doc(challengeId)
        .collection('pagesRead')
        .doc(userId)
        .collection('daily')
        .orderBy('date')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return DailyPageRead(
        date: data['date'] as String? ?? '',
        cumulativePagesRead: (data['cumulativePagesRead'] as int?) ?? 0,
      );
    }).toList();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 챌린지 삭제 (원본과 동일)
  Future<void> deleteChallenge(String challengeId, String userId) async {
    final dailyCollectionRef = _firestore
        .collection('challenge')
        .doc(challengeId)
        .collection('pagesRead')
        .doc(userId)
        .collection('daily');

    // (1) daily 하위 컬렉션 삭제
    final dailyDocs = await dailyCollectionRef.get();
    for (final doc in dailyDocs.docs) {
      await doc.reference.delete();
    }

    // (2) 사용자 페이지 기록 문서 삭제
    await _firestore
        .collection('challenge')
        .doc(challengeId)
        .collection('pagesRead')
        .doc(userId)
        .delete();

    // (3) 챌린지 본문 삭제
    await _firestore.collection('challenge').doc(challengeId).delete();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 챌린지 모델 (원본과 동일)
class Challenge {
  final String id;
  final String title;
  final String description;
  final String type;
  final DateTime startDate;
  final DateTime endDate;
  final String isbn;
  final String coverUrl;
  final String bookTitle;
  final int itemPage;
  final int pagesRead;

  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.isbn,
    required this.coverUrl,
    required this.bookTitle,
    required this.itemPage,
    required this.pagesRead,
  });

  factory Challenge.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Challenge(
      id: doc.id,
      title: data['title'] ?? '',
      bookTitle: data['bookTitle'] ?? '',
      description: data['description'] ?? '',
      type: data['type'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      isbn: data['isbn'] ?? '',
      coverUrl: data['coverUrl'] ?? '',
      itemPage: (data['itemPage'] as num?)?.toInt() ?? 0,
      pagesRead: (data['pagesRead'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 일일 “누적 읽은 페이지” 모델
// ─────────────────────────────────────────────────────────────────────────────
class DailyPageRead {
  final String date;
  final int cumulativePagesRead;

  DailyPageRead({
    required this.date,
    required this.cumulativePagesRead,
  });
}
