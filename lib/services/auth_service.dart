import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore
import 'package:google_sign_in/google_sign_in.dart'; // Google Sign In
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao_user; // Kakao SDK

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  // 이메일로 회원가입
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String nickname,
    required String userId,
    required String birthday,
    required String gender,
  }) async {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Firestore에 사용자 정보 저장
    await _firestore.collection('users').doc(userCredential.user!.uid).set({
      'userId': userId,
      'nickname': nickname,
      'email': email,
      'birthday': birthday,
      'gender': gender,
      'createdAt': FieldValue.serverTimestamp(),
      'photoUrl': '',
    });

    return userCredential;
  }

  // 이메일로 로그인
  Future<UserCredential> login(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // 로그아웃
  Future<void> logout() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  // 구글 로그인
  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'ERROR_ABORTED_BY_USER',
        message: '로그인이 취소되었습니다.',
      );
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;

    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'userId': user.uid,
          'nickname': user.displayName ?? '사용자',
          'email': user.email ?? '',
          'birthday': '',
          'gender': '선택하지 않음',
          'photoUrl': user.photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    return userCredential;
  }

  // 카카오 로그인
  Future<UserCredential> signInWithKakao() async {
    try {
      // 카카오 로그인
      final kakaoToken = await kakao_user.UserApi.instance.loginWithKakaoAccount();
      final kakaoUser = await kakao_user.UserApi.instance.me();

      // Firebase에서 사용자 인증
      final OAuthCredential credential = OAuthProvider('kakao.com').credential(
        accessToken: kakaoToken.accessToken,
        idToken: kakaoToken.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Firestore에 카카오 사용자 정보 저장
      final uid = userCredential.user!.uid;
      await _firestore.collection('users').doc(uid).set({
        'nickname': kakaoUser.kakaoAccount?.profile?.nickname ?? '카카오 사용자',
        'email': kakaoUser.kakaoAccount?.email ?? '${kakaoUser.id}@kakao.com',
        'kakao_uid': kakaoUser.id.toString(),
        'photoUrl': kakaoUser.kakaoAccount?.profile?.profileImageUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return userCredential;
    } catch (e) {
      throw Exception('Kakao 로그인 실패: $e');
    }
  }

  // 현재 사용자 가져오기
  User? get currentUser => _auth.currentUser;

  // 프로필 정보 가져오기
  Future<String?> getNickname() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data();
      return data != null ? data['nickname'] : null;
    } else {
      return null;
    }
  }

  // 프로필 사진 URL 가져오기
  Future<String?> getPhotoUrl() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data();
      return data != null ? data['photoUrl'] : null;
    } else {
      return null;
    }
  }

  // 이메일 업데이트
  Future<void> updateEmail(String newEmail) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updateEmail(newEmail);
      await _firestore.collection('users').doc(user.uid).update({
        'email': newEmail,
      });
    }
  }

  // 닉네임 업데이트
  Future<void> updateNickname(String newNickname) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'nickname': newNickname,
      });
    }
  }

  // 프로필 사진 URL 업데이트
  Future<void> updateProfilePhoto(String newPhotoUrl) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'photoUrl': newPhotoUrl,
      });
    }
  }

  // 성별 업데이트
  Future<void> updateGender(String newGender) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'gender': newGender,
      });
    }
  }

  // 사용자 정보 가져오기
  Future<Map<String, dynamic>?> getUserInfo() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return doc.data();
    } else {
      return null;
    }
  }
}
