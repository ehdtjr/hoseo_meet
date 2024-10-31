import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // 화면 렌더링 완료 후 권한 요청 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestNotificationPermission();
    });
  }

  // 알림 권한 요청 메서드
  Future<void> _requestNotificationPermission() async {
    if (Theme.of(context).platform == TargetPlatform.android) {
      if (await Permission.notification.isGranted) {
        print("안드로이드 알림 권한이 이미 허용되었습니다.");
      } else {
        PermissionStatus status = await Permission.notification.request();
        if (status.isGranted) {
          print("안드로이드 알림 권한이 허용되었습니다.");
        } else {
          print("안드로이드 알림 권한이 거부되었습니다.");
        }
      }
    } else if (Theme.of(context).platform == TargetPlatform.iOS) {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print("iOS 알림 권한이 허용되었습니다.");
      } else {
        print("iOS 알림 권한이 거부되었습니다.");
      }
    }

    // 권한 요청 완료 후 1초 후에 로그인 화면으로 이동
    Future.delayed(Duration(seconds: 1), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE72410), // 스플래시 화면 배경 색상
      body: Center(
        child: Image.asset(
          'assets/img/logo.png',
          width: 100, // 로고 너비
          height: 100, // 로고 높이
          errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
            // 이미지 로드 실패 시 기본 Flutter 로고를 표시
            return FlutterLogo(size: 100);
          },
        ),
      ),
    );
  }
}
