import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
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

