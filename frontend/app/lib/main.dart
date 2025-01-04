import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/date_symbol_data_local.dart';

// 로컬 알림
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// 예시: 로그인 페이지
import 'features/auth/presentation/pages/login_page.dart';

/// 전역으로 로컬 알림 플러그인 선언
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

/// FCM 백그라운드 메시지 핸들러 (top-level 함수)
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // (필요하다면) Firebase.initializeApp() 호출
  // await Firebase.initializeApp();
  print('[백그라운드] 메시지 수신: ${message.notification?.title}');
}

Future<void> main() async {
  // (1) Flutter 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // (2) .env 파일 로드
  await dotenv.load(fileName: ".env");

  // (3) 한국어 로케일 초기화 (intl)
  await initializeDateFormatting('ko_KR', null);

  // (4) 위치 권한 확인 (Geolocator)
  final locationGranted = await _checkAndRequestLocationPermission();
  if (!locationGranted) {
    print('위치 권한이 거부되었습니다. 앱 기능 일부가 제한될 수 있습니다.');
  }

  // (5) NaverMap 초기화
  await NaverMapSdk.instance.initialize(
    clientId: dotenv.env['NAVER_MAP_CLIENT_ID'] ?? '',
  );

  // (6) Firebase 초기화
  await Firebase.initializeApp();

  // (6-1) iOS 알림 권한 요청 + 포그라운드 배너 표시
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,   // 배너
    badge: true,
    sound: true,
  );
  print('iOS 알림 권한 상태: ${settings.authorizationStatus}');
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // (7) 로컬 알림 초기화 (안드로이드 포그라운드 표시용)
  await _initLocalNotifications();

  // (8) 포그라운드 메시지(안드로이드) 수신 시 시스템 알림 띄우는 콜백 설정
  _setupForegroundFCMListener();

  // (9) 백그라운드 메시지 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // (11) 앱 실행 (ProviderScope + MyApp)
  runApp(
    const ProviderScope(
      child: MyApp(firstScreen: LoginPage()),
    ),
  );
}

/// 로컬 알림 초기화
Future<void> _initLocalNotifications() async {
  const AndroidInitializationSettings androidInitSettings =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  final DarwinInitializationSettings iosInitSettings =
  DarwinInitializationSettings();

  final InitializationSettings settings = InitializationSettings(
    android: androidInitSettings,
    iOS: iosInitSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(
    settings,
    onDidReceiveNotificationResponse: (NotificationResponse resp) {
      print('알림 클릭됨: payload=${resp.payload}');
    },
  );
}

/// 안드로이드 포그라운드 메시지 수신 시, 로컬 알림으로 표시
void _setupForegroundFCMListener() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print('포어그라운드 알림 수신: ${message.notification?.title}, ${message.notification?.body}');

    // 안드로이드 알림 채널 설정
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'my_channel_id',
      '포그라운드 알림 채널',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails notiDetails =
    NotificationDetails(android: androidDetails);

    // 실제 알림 띄우기
    await flutterLocalNotificationsPlugin.show(
      0,
      message.notification?.title ?? 'No title',
      message.notification?.body ?? 'No body',
      notiDetails,
      payload: 'foreground msg',
    );
  });
}

/// 위치 권한 확인 함수
Future<bool> _checkAndRequestLocationPermission() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    print('위치 서비스가 꺼져있습니다.');
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return false;
    }
  }
  if (permission == LocationPermission.deniedForever) {
    return false;
  }
  return true;
}

class MyApp extends StatelessWidget {
  final Widget firstScreen;
  const MyApp({super.key, required this.firstScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo (with FCM)',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: firstScreen,
    );
  }
}
