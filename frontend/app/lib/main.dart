import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Riverpod
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Kakao, Naver, Dotenv
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

// Geolocator
import 'package:geolocator/geolocator.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('[FCM 백그라운드] title: ${message.notification?.title}, '
      'body: ${message.notification?.body}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) 위치 권한 먼저 확인
  final locationGranted = await _checkAndRequestLocationPermission();
  if (!locationGranted) {
    // 권한 거부 시, 별도 처리 (앱 종료 or 경고 페이지 등)
    // 여기서는 예시로 그냥 콘솔만 출력하고 진행
    print('위치 권한이 거부되었습니다. 앱 기능 일부가 제한될 수 있습니다.');
  }

  // 2) .env 파일 로드
  await dotenv.load(fileName: ".env");

  // 3) Kakao SDK 초기화
  KakaoSdk.init(
    nativeAppKey: dotenv.env['KAKAO_NATIVE_APP_KEY'] ?? '',
    javaScriptAppKey: dotenv.env['KAKAO_JAVASCRIPT_APP_KEY'] ?? '',
  );

  // 4) Firebase 초기화
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // FCM 백그라운드 메시지 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 5) flutter_local_notifications 설정
  await _initLocalNotifications();

  // 6) iOS 푸시 알림 권한 요청
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  print('iOS 알림 권한 상태: ${settings.authorizationStatus}');

  // iOS Foreground 알림 표시 허용
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // 7) (선택) FCM 토큰 확인
  final token = await FirebaseMessaging.instance.getToken();
  print('FCM Token: $token');

  // 8) 한국어 로케일 초기화
  await initializeDateFormatting('ko_KR', null);

  // 9) Naver Map 초기화
  await NaverMapSdk.instance.initialize(
    clientId: dotenv.env['NAVER_MAP_CLIENT_ID'] ?? '',
  );

  // 모든 초기화 완료 후 runApp
  runApp(const ProviderScope(child: MyApp()));
}

Future<bool> _checkAndRequestLocationPermission() async {
  // 1) 위치 서비스 활성화 여부
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // 사용자가 위치 서비스를 비활성화한 경우
    print('위치 서비스가 꺼져있습니다.');
    // return false;  // 여기서 false를 반환해도 됨
  }

  // 2) 위치 권한 상태 확인
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    // 권한 요청
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // 여전히 거부
      print('위치 권한이 거부되었습니다.');
      return false;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // 사용자가 '다시 묻지 않음'으로 설정
    print('위치 권한이 영구적으로 거부되었습니다. 앱 설정에서 권한을 허용해주세요.');
    return false;
  }

  // 여기까지 왔다면 권한이 허용된 상태
  return true;
}

Future<void> _initLocalNotifications() async {
  // 1) Android 초기화 설정
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  // 2) iOS 초기화 설정
  final DarwinInitializationSettings initializationSettingsIOS =
  DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  // 3) 통합 초기화 설정
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  // 4) 플러그인 초기화
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      debugPrint('알림 클릭됨, payload: ${response.payload}');
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );
}

// (선택) 백그라운드 알림 클릭 처리
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('백그라운드에서 알림 클릭됨, payload: ${notificationResponse.payload}');
}

// MyApp
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo (FCM Foreground)',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: "Pretendard",
        scaffoldBackgroundColor: Colors.white,
        splashFactory: NoSplash.splashFactory,
        appBarTheme: const AppBarTheme(
          color: Colors.white,
          iconTheme: IconThemeData(color: Colors.black),
        ),
      ),
      home: SplashScreen(),
    );
  }
}
