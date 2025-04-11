import 'screens/challenge_add_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/book_tracking_screen.dart';
import 'screens/profile_screen.dart';
import 'services/book_data_service.dart';
import 'screens/timer_screen.dart';
import 'screens/challenge_screen.dart';
import 'services/book_search_service.dart';
import 'screens/login_screen.dart';

// 글로벌 인스턴스로 사용하여 중복 초기화 방지
final BookDataService bookDataService = BookDataService();

void main() async {
  // Flutter 위젯 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Firebase 초기화
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) {
      print('Firebase 초기화 성공');
    }

    // 앱 시작
    runApp(const MyApp());

    // 백그라운드에서 데이터 업데이트 시작
    // 앱 UI를 먼저 보여주고 데이터는 비동기적으로 로드
    _initializeDataInBackground();

  } catch (e) {
    if (kDebugMode) {
      print('Firebase 초기화 오류: $e');
    }
    // 오류가 발생해도 앱은 시작
    runApp(const MyApp());
  }
}

// 백그라운드에서 데이터 초기화
Future<void> _initializeDataInBackground() async {
  try {
    // 초기 데이터 미리 로드 (실패해도 계속 진행)
    await bookDataService.getInitialData().catchError((e) {
      if (kDebugMode) {
        print('백그라운드 데이터 초기화 오류 (무시됨): $e');
      }
    });
  } catch (e) {
    if (kDebugMode) {
      print('백그라운드 데이터 초기화 중 예외 발생: $e');
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI 독서 앱!',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const LoginPage(),  // 바로 로그인 화면으로 이동
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomeScreen(),
        '/library': (context) => const BookTrackingScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/timer': (context) => const TimerScreen(), // 타이머 화면 추가
        '/challenge': (context) => const ChallengeScreen(), // 챌린지 화면 추가
        '/newChallenge' : (context) => const ChallengeAddScreen(),
      },
    );
  }
}