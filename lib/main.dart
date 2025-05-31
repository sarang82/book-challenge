import 'package:book_tracking_app/providers/timer_provider.dart';
import 'package:book_tracking_app/screens/mission_screeen.dart';

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
import 'screens/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'screens/reading_memo_screen.dart';
import 'screens/reading_records_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// 글로벌 인스턴스로 사용하여 중복 초기화 방지
final BookDataService bookDataService = BookDataService();

void main() async {
  // Flutter 위젯 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Kakao SDK 초기화
    KakaoSdk.init(
      nativeAppKey: '3994fcb20cffde63abe5d0db12a3a7ed', // ← 여기에 본인의 Kakao 네이티브 앱 키 입력
      javaScriptAppKey: '23b59a92b46c746ac380cd4c08cc2691', // 웹 로그인 연동시 필요 시 사용
    );

    // Firebase 초기화
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) {
      print('Firebase 초기화 성공');
    }

    // 앱 시작
    runApp(
      ChangeNotifierProvider(
        create: (_) => TimerProvider(),
        child: const MyApp(),
      ),
    );

    // 백그라운드 데이터 초기화
    _initializeDataInBackground();

  } catch (e) {
    if (kDebugMode) {
      print('초기화 오류: $e');
    }
    runApp(const MyApp()); // 오류 발생해도 앱은 시작
  }
}

// 백그라운드 데이터 초기화
Future<void> _initializeDataInBackground() async {
  try {
    await bookDataService.getInitialData().catchError((e) {
      if (kDebugMode) {
        print('백그라운드 데이터 오류 (무시됨): $e');
      }
    });
  } catch (e) {
    if (kDebugMode) {
      print('백그라운드 데이터 예외 발생: $e');
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '톡독',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'), // 한국어 지원
      ],
      locale: const Locale('ko', 'KR'), // 앱 전체 강제 한국어
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const LoginPage(), // 첫 화면: 로그인
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomeScreen(),
        '/library': (context) => const BookTrackingScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/timer': (context) => const TimerScreen(),
        '/mission': (context) => const MissionScreen(),
        '/challenge': (context) => const ChallengeScreen(),
        '/newChallenge': (context) => const ChallengeAddScreen(),
        '/readingMemo': (context) => const ReadingMemoScreen(),      // 새로 추가
        '/readingRecords': (context) => const ReadingRecordsScreen(),
      },
    );
  }
}
