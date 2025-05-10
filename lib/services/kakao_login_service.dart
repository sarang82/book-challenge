import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class KakaoLoginService {
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Firebase Functions URL
  final String _firebaseFunctionsUrl =
      'https://us-central1-talkdok-cf1b4.cloudfunctions.net/kakaoCustomAuth';

  Future<void> signInWithKakao() async {
    try {
      // 웹 로그인 강제 사용
      OAuthToken token = await UserApi.instance.loginWithKakaoAccount();

      // 카카오 사용자 정보 가져오기
      User kakaoUser = await UserApi.instance.me();

      final kakaoUid = kakaoUser.id.toString();
      final email = kakaoUser.kakaoAccount?.email ?? '$kakaoUid@kakao.com';
      final nickname = kakaoUser.kakaoAccount?.profile?.nickname ?? '카카오 사용자';

      // ✅ Firebase Functions에 access token 전달하여 Custom Token 받기
      final customToken = await _getCustomToken(token.accessToken);

      // Firebase Auth에 Custom Token으로 로그인
      fb_auth.UserCredential userCredential =
      await _auth.signInWithCustomToken(customToken);
      final uid = userCredential.user!.uid;

      // Firestore에 사용자 정보 저장
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'provider': 'kakao',
        'kakao_uid': kakaoUid,
        'email': email,
        'nickname': nickname,
      });
    } catch (e) {
      print('Kakao 로그인 실패: $e');
      throw Exception('Kakao 로그인 실패: $e');
    }
  }

// ✅ 함수의 파라미터를 accessToken으로 바꿔
  Future<String> _getCustomToken(String kakaoAccessToken) async {
    final url = Uri.parse(_firebaseFunctionsUrl);
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'kakaoAccessToken': kakaoAccessToken}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['token']; // Firebase Custom Token 반환
    } else {
      print('Custom token 요청 실패: ${response.body}');
      throw Exception('Failed to get custom token');
    }
  }
}