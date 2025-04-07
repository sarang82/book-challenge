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

final BookDataService bookDataService = BookDataService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) {
      print('Firebase 초기화 성공');
    }

    runApp(const MyApp());
    _initializeDataInBackground();

  } catch (e) {
    if (kDebugMode) {
      print('Firebase 초기화 오류: $e');
    }
    runApp(const MyApp());
  }
}

Future<void> _initializeDataInBackground() async {
  try {
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
      home: const LoginPage(),
      routes: {
        '/login': (context) => const LoginPage(), // 또는 LoginScreen() 사용 시 이름 확인
        '/home': (context) => const HomeScreen(),
        '/library': (context) => const BookTrackingScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/timer': (context) => const TimerScreen(),
        '/challenge': (context) => const ChallengeScreen(),
      },
    );
  }
}
