//import 'package:flutter/material.dart';
//import '/services/auth_service.dart'; // 인증 서비스
//import '/screens/login_screen.dart'; // 로그인 화면
//
//class EmailCheckScreen extends StatefulWidget {
//  const EmailCheckScreen({super.key});
//
//  @override
//  State<EmailCheckScreen> createState() => _EmailCheckScreenState();
//}
//
//class _EmailCheckScreenState extends State<EmailCheckScreen> {
//  final AuthService _authService = AuthService();
//  bool _isEmailVerified = false;
//  bool _isChecking = false;
//
//  // 이메일 인증 확인
//  Future<void> _checkEmailVerification() async {
//    setState(() {
//      _isChecking = true;
//    });
//
//    try {
//      // 인증 상태 확인
//      await _authService.completeSignupAfterEmailVerification();
//      setState(() {
//        _isEmailVerified = true;
//      });
//    } catch (e) {
//      setState(() {
//        _isEmailVerified = false;
//      });
//      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('이메일 인증이 완료되지 않았습니다.')));
//    } finally {
//      setState(() {
//        _isChecking = false;
//      });
//    }
//  }
//
//  @override
//  void initState() {
//    super.initState();
//    // 페이지 처음 들어오면 인증 상태를 확인
//    _checkEmailVerification();
//  }
//
//  @override
//  Widget build(BuildContext context) {
//    return Scaffold(
//      backgroundColor: Colors.white,
//      appBar: AppBar(
//        title: const Text('이메일 인증 확인', style: TextStyle(fontWeight: FontWeight.bold)),
//        centerTitle: true,
//        backgroundColor: Colors.white,
//        elevation: 0,
//        leading: IconButton(
//          icon: const Icon(Icons.close, color: Colors.black),
//          onPressed: () => Navigator.pop(context),
//        ),
//      ),
//      body: Padding(
//        padding: const EdgeInsets.all(16.0),
//        child: Column(
//          mainAxisAlignment: MainAxisAlignment.center,
//          crossAxisAlignment: CrossAxisAlignment.center,
//          children: [
//            _isChecking
//                ? const CircularProgressIndicator()
//                : _isEmailVerified
//                ? Column(
//              children: [
//                Align(
//                  alignment: Alignment.center,//아이콘 가운데정렬
//                  child: Icon(Icons.check_circle, color: Colors.green, size: 100),
//                ),
//                const SizedBox(height: 20),
//                Align(
//                  alignment: Alignment.center, // Text를 가운데 정렬
//                  child: Text(
//                    '이메일 인증이 완료되었습니다!',
//                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
//                    textAlign: TextAlign.center, // 텍스트 가운데 정렬
//                  ),
//                ),
//                const SizedBox(height: 20),
//                  Align(
//                    alignment: Alignment.center, // 버튼을 가운데 정렬
//                    child: ElevatedButton(
//                      onPressed: () {
//                        // 로그인 화면으로 네비게이트
//                        Navigator.pushReplacement(
//                          context,
//                          MaterialPageRoute(builder: (context) => const LoginPage()),
//                        );
//                      },
//                      child: const Text('로그인 화면으로'),
//                    ),
//                  ),
//              ],
//            )
//        : Column(
//          children: [
//            Align(
//              alignment: Alignment.center, // Icon을 가운데 정렬
//              child: Icon(Icons.warning, color: Colors.orange, size: 100),
//            ),
//             const SizedBox(height: 20),
//            Align(
//              alignment: Alignment.center, // Text를 가운데 정렬
//              child: Text(
//                '인증 메일을 발송했습니다.',
//                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
//                textAlign: TextAlign.center, // 텍스트 가운데 정렬
//              ),
//            ),
//            const SizedBox(height:20),
//            Align(
//              alignment: Alignment.center, // 버튼을 가운데 정렬
//              child: SizedBox(
//                width: double.infinity,
//                child: ElevatedButton(
//                  style: ElevatedButton.styleFrom(
//                    padding: const EdgeInsets.symmetric(vertical: 15),
//                  ),
//                  onPressed: (){
//                    _checkEmailVerification();
//                  },
//                  child: Text(
//                    '다시 확인',
//                    style: TextStyle(fontSize:15),
//                  ),
//                ),
//                ),
//               ),
//              ],
//            ),
//          ],
//        ),
//      ),
//    );
//  }
//}
//