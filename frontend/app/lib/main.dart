import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:photo_manager/photo_manager.dart';
import 'firebase_options.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'firebase/fcm_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[백그라운드] 메시지 수신: ${message.notification?.title}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await dotenv.load(fileName: ".env");
  await initializeDateFormatting('ko_KR', null);

  // 권한 초기화
  await _initPermissions();

  await NaverMapSdk.instance.initialize(
    clientId: dotenv.env['NAVER_MAP_CLIENT_ID'] ?? '',
  );

  await _initLocalNotifications();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

Future<void> _initPermissions() async {
  try {
    // 위치 서비스 확인
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('위치 서비스가 비활성화되어 있습니다.');
    }

    // 카메라 권한 먼저 요청
    final cameraStatus = await Permission.camera.request();
    debugPrint('카메라 권한 상태: $cameraStatus');

    // 위치 및 알림 권한 요청
    Map<Permission, PermissionStatus> statuses = await [
      Permission.locationWhenInUse,
      Permission.notification,
    ].request();
    debugPrint('위치/알림 권한 상태: $statuses');

    // 갤러리 권한 요청 (PhotoManager)
    final permissionState = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.image,
          mediaLocation: false,
        ),
        iosAccessLevel: IosAccessLevel.readWrite,
      ),
    );

    if (Platform.isAndroid) {
      if (!permissionState.isAuth) {
        // Android 13 이상
        final photosStatus = await Permission.photos.request();
        debugPrint('사진 권한 상태 (Android 13+): $photosStatus');

        // Android 12 이하
        if (!photosStatus.isGranted) {
          final storageStatus = await Permission.storage.request();
          debugPrint('저장소 권한 상태 (Android 12-): $storageStatus');
        }
      }
    }

    debugPrint('PhotoManager 권한 상태: ${permissionState.isAuth}');
    debugPrint('✅ 모든 권한 초기화 완료');
  } catch (e) {
    debugPrint('권한 초기화 오류: $e');
  }
}

Future<void> _initLocalNotifications() async {
  const androidInitSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInitSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const initSettings = InitializationSettings(
    android: androidInitSettings,
    iOS: iosInitSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (resp) {
      debugPrint('알림 클릭됨: payload=${resp.payload}');
    },
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late final FcmService fcmService;

  @override
  void initState() {
    super.initState();
    fcmService = FcmService(
      localNotificationsPlugin: flutterLocalNotificationsPlugin,
      ref: ref,
    );
    _initFCM();
  }

  Future<void> _initFCM() async {
    await fcmService.requestIOSPermissions();
    fcmService.setupForegroundListener();
    fcmService.setupBackgroundHandler(firebaseMessagingBackgroundHandler);
  }

  @override
  Widget build(BuildContext context) {
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
