import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import '/utils/validators.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendVerificationEmailAndSaveTempUsers({
    required String email,
    required String pwd, }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: pwd,
      );

      final user = userCredential.user;
      if (user != null) {
        await user.sendEmailVerification(
          ActionCodeSettings(
            url: 'https://talkdok-cf1b4.firebaseapp.com',
            handleCodeInApp: true,
            androidPackageName: 'com.example.book_tracking_app',
            androidInstallApp: true,
            androidMinimumVersion: '12',
          ),
        );

        await _firestore.collection('tempUsers').doc(user.uid).set({
          'email': email,
          //'password': pwd,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch (e) {
      throw Exception('인증 메일 발송 실패: ${e.message}');
    }
  }

  //회원가입
  Future<void> CompleteSignUp({
    required String email,
    required String pwd,
    required String nickname,
    required String userId,
    required String birthday,
    required String gender,
  }) async {
    final user = _auth.currentUser;
    //하..
    if (user == null || !user.emailVerified) {
      throw Exception('이메일 인증을 완료해주세요.');
    }

    final tempDoc = await _firestore.collection('tempUsers').doc(user.uid).get();

    if (!tempDoc.exists) {
      throw Exception('임시 사용자 정보가 존재하지 않습니다.');
    }

    final data = tempDoc.data()!;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'userId': user.uid,
        'nickname': nickname,
        'email': user.email,
        'birthday': birthday,
        'gender': gender,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // tempUsers 삭제
      await _firestore.collection('tempUsers').doc(user.uid).delete();
    } catch (e) {
      print("Firestore save failed: $e");
      throw Exception("Firestore save failed: $e");
    }
  }

//    //1. 이메일 형식
//    if (!isValidEmail(email)) {
//      throw Exception('이메일 형식이 올바르지 않습니다.');
//    }
//
//// 비밀번호 확인
//    if (!isValidPassword(pwd)) {
//      throw Exception('비밀번호는 8~16자, 특수문자 1개 이상 포함해야 합니다.');
//    }
//
//    //계정 생성
//    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
//      email: email, password: pwd,);
//
//    // Firestore에 사용자 정보 저장 + 이메일 인증 상태 저장
//    try {
//      await _firestore.collection('users').doc(userCredential.user!.uid).set({
//        'userId': userId,
//        'nickname': nickname,
//        'email': email,
//        'birthday': birthday,
//        'gender': gender,
//        'status': 'pending', // 이메일 인증 대기 상태
//        'createdAt': FieldValue.serverTimestamp(),
//        'verificationDeadline': FieldValue.serverTimestamp(),  // 인증 기한
//      });
//    } catch (e) {
//      print("Firestore save failed: $e");
//      throw Exception("Firestore save failed: $e");
//    }
//
//    return userCredential;
//  }

  // 로그인
  Future<UserCredential> login(String email, String password) async {
    UserCredential userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // 이메일 인증 확인
    if (userCredential.user != null && !userCredential.user!.emailVerified) {
      // 인증되지 않은 이메일로 로그인 시 이메일 인증이 필요하다는 메시지 처리
      throw Exception('이메일 인증을 완료해주세요.');
    }

    return userCredential;
  }

  // 로그아웃
  Future<void> logout() async {
    await _auth.signOut();
  }

  // 현재 유저
  User? get currentUser => _auth.currentUser;

  //닉네임 띄우기
  Future<String?> getNickname() async {
    final user = _auth.currentUser;

    //user 정보 없으면 널띄우기
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();

    if(doc.exists) {
      return doc.data()?['nickname'];
    } else{
      return null;
    }
  }

}