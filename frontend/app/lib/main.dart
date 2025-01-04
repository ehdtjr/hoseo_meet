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
// (★) FCMService import
import 'firebase/fcm_service.dart';

/// 전역 로컬 알림 플러그인
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

/// FCM 백그라운드 메시지 핸들러 (top-level 함수)
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('[백그라운드] 메시지 수신: ${message.notification?.title}');
  // 필요하다면 여기에 await Firebase.initializeApp(); 추가
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

  // (7) 로컬 알림 초기화 (안드로이드 포어그라운드 표시용)
  await _initLocalNotifications();

  // (8) 앱 실행. ProviderScope로 감싸서 Riverpod을 전역에서 사용 가능
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

/// 로컬 알림 초기화
Future<void> _initLocalNotifications() async {
  const androidInitSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInitSettings = DarwinInitializationSettings();

  const initSettings = InitializationSettings(
    android: androidInitSettings,
    iOS: iosInitSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (resp) {
      print('알림 클릭됨: payload=${resp.payload}');
    },
  );
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

/// ConsumerStatefulWidget에서 FcmService를 초기화
class MyApp extends ConsumerStatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late final FcmService fcmService;

  @override
  void initState() {
    super.initState();

    // (A) FcmService 생성, ref를 주입
    fcmService = FcmService(
      localNotificationsPlugin: flutterLocalNotificationsPlugin,
      ref: ref, // <-- ConsumerStatefulWidget에서는 ref 접근 가능
    );

    // (B) FCM 관련 초기화
    _initFCM();
  }

  Future<void> _initFCM() async {
    // iOS 권한
    await fcmService.requestIOSPermissions();
    // 포어그라운드 메시지 리스너
    fcmService.setupForegroundListener();
    // 백그라운드 메시지 핸들러
    fcmService.setupBackgroundHandler(firebaseMessagingBackgroundHandler);
  }

  @override
  Widget build(BuildContext context) {
    // 첫 화면으로 LoginPage를 띄운다고 가정
    return MaterialApp(
      title: 'Flutter Demo (with FCM)',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const LoginPage(),
    );
  }
}
