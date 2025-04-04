import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //회원가입
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String nickname,
    required String userId,
    required String birthday,
    required String gender,
  }) async {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: userId, password: password,);

    //firestore에 저장
    await _firestore.collection('users').doc(userCredential.user!.uid).set({
      'userId':userId,
      'nickname': nickname,
      'email': email,
      'birthday': birthday,
      'gender': gender,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return userCredential;
  }

  // 로그인
  Future<UserCredential> login(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // 로그아웃
  Future<void> logout() async {
    await _auth.signOut();
  }

  // 현재 유저
  User? get currentUser => _auth.currentUser;
}