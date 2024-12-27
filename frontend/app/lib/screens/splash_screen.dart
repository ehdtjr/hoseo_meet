import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../api/login/login_service.dart'; // AuthService
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // (1) 앱 초기화 로직
      await _initializeApp();
    });
  }

  /// 앱 초기화
  Future<void> _initializeApp() async {
    // (A) 알림 권한 요청
    await _requestNotificationPermission();
    // (B) AuthService 초기화 -> Refresh Token 로드 (public method)
    await _authService.init();  // init() 내부에서 restoreRefreshToken() 호출

    // (C) Refresh Token 기반 자동로그인 시도
    await _attemptAutoLogin();
  }

  /// 알림 권한 요청
  Future<void> _requestNotificationPermission() async {
    if (Theme.of(context).platform == TargetPlatform.android) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        final newStatus = await Permission.notification.request();
        if (newStatus.isGranted) {
          print("안드로이드 알림 권한이 허용되었습니다.");
        } else {
          print("안드로이드 알림 권한이 거부되었습니다.");
        }
      } else {
        print("안드로이드 알림 권한이 이미 허용되었습니다.");
      }
    } else if (Theme.of(context).platform == TargetPlatform.iOS) {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
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
  }

  /// 자동 로그인 시도
  Future<void> _attemptAutoLogin() async {
    final hasRefresh = _authService.refreshToken != null;
    print("[SplashScreen] 최종 hasRefresh: $hasRefresh");

    if (hasRefresh) {
      final success = await _authService.refreshAccessToken();
      if (success) {
        // 성공 -> HomeScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
        return;
      }
    }

    // 실패 or 없음 -> LoginScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE72410),
      body: Center(
        child: Image.asset(
          'assets/img/logo.png',
          width: 100,
          height: 100,
          errorBuilder: (context, exception, stackTrace) {
            return const FlutterLogo(size: 100);
          },
        ),
      ),
    );
  }
}
