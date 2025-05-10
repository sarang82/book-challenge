import 'sign_up_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '/services/auth_service.dart';
import '/services/kakao_login_service.dart';
import 'home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 로그인 함수
  void _login() async {
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      await _auth.signInWithEmailAndPassword(email: email, password: password);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 성공!')),
      );

    //홈 화면으로 이동
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));

    } on FirebaseAuthException catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('로그인 실패: ${e.message}')),
    );
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      await GoogleSignIn().signOut(); // 계정 선택창 항상 보이게
      final userCredential = await AuthService().signInWithGoogle();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google 로그인 성공!')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen()),
      );
    } catch (e) {
      print('Google 로그인 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google 로그인 실패: $e')),
      );
    }
  }

  Future<void> _signInWithKakao() async {
    try {
      await KakaoLoginService().signInWithKakao(); // ✅ 안전한 Kakao 로그인 사용
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kakao 로그인 성공!')),
      );
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
    } catch (e) {
      print('Kakao 로그인 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kakao 로그인 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView( //스크롤 가능하도록 수정
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const Icon(Icons.arrow_back),
                const SizedBox(height: 40),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      '매일 새로운 도전,\n톡톡',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Transform.rotate(
                      angle: -30 * 3.1415927 / 180,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('assets/images/iPhone 15 Pro Max.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '로그인 후 이용 가능합니다.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: '아이디 입력',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: '패스워드 입력',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('비밀번호를 잊으셨나요?', style: TextStyle(fontSize: 12)),

                    // 회원가입으로 이동
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SignUpScreen()),
                        );
                      },
                      child: const Text(
                        '회원가입',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: _login,
                    child: const Text(
                      '로그인',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: _signInWithKakao,
                      child: CircleAvatar(
                        backgroundColor: const Color(0xFFFFE812),
                        radius: 25,
                        child: Image.asset('assets/images/kakaoicon.png', width: 30, height: 30),
                      ),
                    ),
                    CircleAvatar(
                      backgroundColor: const Color(0xFF03C75A),
                      radius: 25,
                      child: Image.asset('assets/images/navericon.png', width: 30, height: 30),
                    ),
                    GestureDetector(
                      onTap: _signInWithGoogle,
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 25,
                        child: Image.asset('assets/images/googleicon.png', width: 90, height: 90),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}