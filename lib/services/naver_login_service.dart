import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class NaverLoginService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> signInWithNaver(BuildContext context) async {
    final clientId = 'PLHdaznm0rzZR_ejyPhp'; // 네이버 앱 client_id
    final redirectUri = 'https://authcustomtoken-lczljd5ldq-uc.a.run.app/naver'; // Firebase Functions 콜백 URL
    final state = DateTime.now().millisecondsSinceEpoch.toString();

    // 항상 로그인 화면 띄우도록 force_login, force_logout, prompt 파라미터 추가
    final authUrl = Uri.https('nid.naver.com', '/oauth2.0/authorize', {
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'state': state,
      'force_login': 'true',
      'force_logout': 'true',
      'prompt': 'login',
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
  late WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    final cookieManager = WebViewCookieManager();

    // 쿠키와 캐시 완전 삭제
    await cookieManager.clearCookies();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (url.startsWith('https://authcustomtoken-lczljd5ldq-uc.a.run.app/naver')) {
              Navigator.pop(context, url); // 인증 코드 감지 시 종료 및 전달
            }
          },
          onWebResourceError: (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('웹뷰 로딩 중 오류 발생')),
            );
          },
        ),
      );

    await _controller.clearCache();
    await _controller.loadRequest(Uri.parse(widget.authUrl));

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('네이버 로그인')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : WebViewWidget(controller: _controller),
    );
  }
}
