import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart'; // initializeDateFormatting을 위한 import
import 'screens/splash_screen.dart';
import 'firebase_options.dart';

void main() async {
  // Flutter 엔진이 준비되기 전에 비동기 작업을 처리하기 위해 추가
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // 한국어 로케일 데이터를 초기화합니다.
  await initializeDateFormatting('ko_KR', null);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        fontFamily: "Pretendard",
        primarySwatch: Colors.blue, // 기본 테마 색상을 파랑으로 설정
        scaffoldBackgroundColor: Colors.white, // 모든 Scaffold의 배경색을 흰색으로 설정
        splashFactory: NoSplash.splashFactory, // 물방울 효과 제거
        appBarTheme: AppBarTheme(
          color: Colors.white, // AppBar의 배경색을 흰색으로 설정
          iconTheme: IconThemeData(color: Colors.black), // AppBar 아이콘 색상 설정
        ),
      ),
      home: SplashScreen(), // 앱 시작 시 스플래시 화면을 표시
    );
  }
}