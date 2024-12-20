import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/splash_screen.dart';
import 'firebase_options.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 앱 초기화 상태를 관리하는 FutureProvider
final appInitProvider = FutureProvider<void>((ref) async {
  // .env 파일 로드
  await dotenv.load();

  // Kakao SDK 초기화
  KakaoSdk.init(
    nativeAppKey: dotenv.env['KAKAO_NATIVE_APP_KEY'] ?? '',
    javaScriptAppKey: dotenv.env['KAKAO_JAVASCRIPT_APP_KEY'] ?? '',
  );

  String? hashKey = await KakaoSdk.origin;
  print("Current Key Hash: $hashKey");

  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 한국어 로케일 데이터 초기화
  await initializeDateFormatting('ko_KR', null);
});

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        fontFamily: "Pretendard",
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        splashFactory: NoSplash.splashFactory,
        appBarTheme: const AppBarTheme(
          color: Colors.white,
          iconTheme: IconThemeData(color: Colors.black),
        ),
      ),
      home: const AppInitializer(),
    );
  }
}

class AppInitializer extends ConsumerWidget {
  const AppInitializer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appInitState = ref.watch(appInitProvider);

    return appInitState.when(
      data: (_) => SplashScreen(), // 초기화 완료 시 SplashScreen 표시
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()), // 로딩 화면
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Text('초기화에 실패했습니다: $error'),
        ),
      ),
    );
  }
}
