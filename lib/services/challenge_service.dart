import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'aladin_service.dart';

class ChallengeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

    await _firestore.collection('challenge').add({
      'userId': uid,
      'isbn': bookId,
      'title': title,
      'description':description,
      'type': type,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
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

  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.isbn,
  });

  factory Challenge.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Challenge(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: data['type'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      isbn: data['isbn'] ?? '',
    );
  }
}
