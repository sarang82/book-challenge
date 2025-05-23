import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'aladin_service.dart';

class ChallengeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AladinService _aladinService = AladinService();

  //챌린지 생성
  Future<void> createChallenge({
    required String title,
    required String type, //'완독','시간'
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    required String bookId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if(uid == null) throw Exception("로그인된 사용자가 없습니다.");

    // AladinService로 책 상세정보 받아오기
    final bookDetail = await _aladinService.fetchBookDetail(bookId);
    final coverUrl = bookDetail?['coverUrl'] ?? ''; // coverUrl이 없으면 빈 문자열로
    final bookTitle = bookDetail?['title'] ?? '';

    await _firestore.collection('challenge').add({
      'userId': uid,
      'isbn': bookId,
      'coverUrl': coverUrl,
      'title': title,
      'bookTitle': bookTitle,
      'description':description,
      'type': type,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'itemPage': bookDetail?['itemPage'] ?? 0,
      'pagesRead': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  //챌린지 목록 띄우기
  Future<List<Challenge>> getChallenges() async{
    final uid = _auth.currentUser?.uid;
    if (uid ==null) throw Exception("로그인 된 사용자가 없습니다.");

    final querySnapshot = await _firestore.collection('challenge')
        .where('userId', isEqualTo: uid)
        .orderBy('startDate')
        .get();

    //디버그용 코드
    print('현재 로그인된 UID: $uid');
    print('가져온 챌린지 문서 수: ${querySnapshot.docs.length}');

    return querySnapshot.docs //문서 하나하나가 담긴 리스트
        .map((doc) => Challenge.fromDocument(doc)) //문서들을 챌린지 class로 바꿈
        .toList(); //리스트로 반환
}

  // 오늘 읽은 페이지 조회
  Future<int> getTodayPagesRead(String challengeId, String userId) async {
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    final formattedDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final doc = await _firestore
        .collection('challenge')
        .doc(challengeId)
        .collection('pagesRead')
        .doc(userId)
        .collection('daily')
        .doc(formattedDate)
        .get();

    if (doc.exists) {
      final data = doc.data();
      return data?['pagesRead'] ?? 0;
    } else {
      return 0;
    }
  }


// 오늘 읽은 페이지 저장
  Future<void> saveTodayPagesRead(
      String challengeId, String userId, int pages) async {
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));  // UTC+9로 보정
    final formattedDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    await _firestore
        .collection('challenge')
        .doc(challengeId)
        .collection('pagesRead')
        .doc(userId)
        .collection('daily')
        .doc(formattedDate)
        .set({
      'pagesRead': pages,
      'date': formattedDate,
    });
  }

  //히스토리
  Future<List<DailyPageRead>> getAllPagesRead(String challengeId, String userId) async {
    final snapshot = await _firestore
        .collection('challenge')
        .doc(challengeId)
        .collection('pagesRead')
        .doc(userId)
        .collection('daily')
        .orderBy('date')  // 날짜순 정렬 (날짜 필드가 있어야 함)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return DailyPageRead(
        date: data['date'] ?? '',
        pagesRead: data['pagesRead'] ?? 0,
      );
    }).toList();
  }

}
int parseItemPage(dynamic page) {
  if (page == null) return 0;
  if (page is int) return page;
  if (page is String) {
    try {
      return int.parse(page);
    } catch (_) {
      return 0;
    }
  }
  return 0;
}
//챌린지 객체
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
      itemPage: data['itemPage'] ?? 0,
      pagesRead: data['pagesRead'] ?? 0,
    );
  }
}

// 모델 클래스 예시
class DailyPageRead {
  final String date;
  final int pagesRead;

  DailyPageRead({required this.date, required this.pagesRead});
}
