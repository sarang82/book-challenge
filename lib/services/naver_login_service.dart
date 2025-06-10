import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class NaverLoginService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> signInWithNaver(BuildContext context) async {
    final clientId = 'PLHdaznm0rzZR_ejyPhp'; // 네이버 앱 등록 시 발급받은 client_id
    final redirectUri = 'https://authcustomtoken-lczljd5ldq-uc.a.run.app/naver'; // Firebase Functions 콜백 URL
    final state = DateTime.now().millisecondsSinceEpoch.toString(); // CSRF 방지용 state

    // force_login=true와 force_logout=true로 파라미터 추가하여 항상 로그인 페이지가 뜨도록 설정
    final authUrl = Uri.https('nid.naver.com', '/oauth2.0/authorize', {
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'state': state,
      'force_login': 'true', // 강제 로그인 파라미터
      'force_logout': 'true', // 강제 로그아웃 파라미터 추가
    });

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NaverLoginWebView(authUrl: authUrl.toString()),
        ),
      );

      if (result == null) {
        throw Exception('네이버 로그인 코드 획득 실패');
      }

      final Uri uri = Uri.parse(result);
      final code = uri.queryParameters['code'];

      if (code == null) {
        throw Exception('네이버 로그인 코드 획득 실패');
      }

      final response = await http.post(
        Uri.parse('https://authcustomtoken-lczljd5ldq-uc.a.run.app/naver'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'naverAuthCode': code}),
      );

      if (response.statusCode == 200) {
        final token = jsonDecode(response.body)['token'];
        await _auth.signInWithCustomToken(token);
        print("로그인 성공");
      } else {
        throw Exception('Firebase 인증 실패: ${response.body}');
      }
    } catch (e) {
      print('Naver 로그인 오류: $e');
      throw Exception('Naver 로그인 처리 중 오류 발생');
    }
  }
}

class NaverLoginWebView extends StatefulWidget {
  final String authUrl;
  NaverLoginWebView({required this.authUrl});

  @override
  _NaverLoginWebViewState createState() => _NaverLoginWebViewState();
}

class _NaverLoginWebViewState extends State<NaverLoginWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    // 웹뷰 초기화
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (url.startsWith('https://authcustomtoken-lczljd5ldq-uc.a.run.app/naver')) {
              Navigator.pop(context, url); // 인증 코드 추출용 리디렉션 URL 감지
            }
          },
          onWebResourceError: (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('웹뷰 로딩 중 오류 발생')),
            );
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authUrl)); // 로그인 URL로 웹뷰 로드
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('네이버 로그인')),
      body: WebViewWidget(controller: _controller),
    );
  }
}
