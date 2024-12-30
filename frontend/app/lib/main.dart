import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Firebase 옵션 (자동 생성된 파일)
import 'firebase_options.dart';

// 예시: 간단한 SplashScreen
import 'screens/splash_screen.dart';

// ---------------------------
// 1) 전역 변수 / 백그라운드 핸들러
// ---------------------------

// flutter_local_notifications 플러그인 전역 인스턴스
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// FCM 백그라운드 메시지 핸들러 (필수)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 백그라운드에서 Firebase를 재초기화해야 함
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print('[FCM 백그라운드] title: ${message.notification?.title}, '
      'body: ${message.notification?.body}');
}

// ---------------------------
// 2) 메인 함수
// ---------------------------
void main() async {
  // Flutter에서 비동기 초기화를 하려면 필요
  WidgetsFlutterBinding.ensureInitialized();

  // .env 파일 로드 (API Key 등)
  await dotenv.load(fileName: ".env");

  // Kakao SDK 초기화 (env에서 키 가져오기)
  KakaoSdk.init(
    nativeAppKey: dotenv.env['KAKAO_NATIVE_APP_KEY'] ?? '',
    javaScriptAppKey: dotenv.env['KAKAO_JAVASCRIPT_APP_KEY'] ?? '',
  );


  // Naver Map SDK 초기화
  await NaverMapSdk.instance.initialize(
    clientId: dotenv.env['NAVER_MAP_CLIENT_ID'] ?? '',
  );

  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // FCM 백그라운드 메시지 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // -----------------------------------------------
  // flutter_local_notifications 설정 (Android + iOS)
  // -----------------------------------------------
  // 1) Android 초기화 설정
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  // 2) iOS 초기화 설정
  final DarwinInitializationSettings initializationSettingsIOS =
  DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
    // (선택) iOS 포그라운드 상태에서 로컬 알림 콜백
    // onDidReceiveLocalNotification: (id, title, body, payload) async {
    //   // iOS에서 포그라운드 알림 수신 시 처리할 로직
    // },
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
      // 알림 클릭 시 처리 로직
      debugPrint('알림 클릭됨, payload: ${response.payload}');
    },
    // (선택) 백그라운드 알림 클릭 시 동작
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  // iOS 푸시 알림 권한 요청
  NotificationSettings settings =
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  print('iOS 알림 권한 상태: ${settings.authorizationStatus}');

  // iOS에서 Foreground 알림 배너/사운드 표시 허용
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // (선택) FCM 토큰 확인 - 디버그용
  final token = await FirebaseMessaging.instance.getToken();
  print('FCM Token: $token');

  // 한국어 로케일 초기화
  await initializeDateFormatting('ko_KR', null);

  // FCM Foreground 알림 수신 리스너 등록
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('[FCM Fore그라운드] 수신: '
        '${message.notification?.title} / ${message.notification?.body}');

    // 알림 정보
    RemoteNotification? notification = message.notification;

    if (notification != null) {
      // Android 알림 설정
      const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
        'foreground_channel_id',        // 채널 ID
        'Foreground Notifications',     // 채널 이름
        channelDescription: '앱이 활성일 때 표시될 알림 채널',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      );

      // iOS 알림 설정 (소리 추가)
      const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        sound: 'default',  // 기본 iOS 사운드
      );

      // 플랫폼별 설정 통합
      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      // 로컬 알림 표시
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,  // 알림 ID
        notification.title,     // 알림 제목
        notification.body,      // 알림 내용
        platformDetails,        // 플랫폼별 설정
      );
    }
  });

  // 모든 초기화 완료 후, runApp
  runApp(const ProviderScope(child: MyApp()));
}

// (선택) 백그라운드 알림 클릭 처리
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('백그라운드에서 알림 클릭됨, payload: ${notificationResponse.payload}');
}

// ---------------------------
// 3) MyApp & MaterialApp
// ---------------------------
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
