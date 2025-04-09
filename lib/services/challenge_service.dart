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


}