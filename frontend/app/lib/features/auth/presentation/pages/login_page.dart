import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../../commons/network/auth_http_client_provider.dart';
import '../../../../features/auth/providers/auth_notifier_provider.dart';
import '../../../navigation/presentation/pages/main_tab_page.dart';
import '../../data/models/auth_state.dart';
import '../../providers/auth_notifier.dart';

// (★) 추가: SendTokenService import
import 'package:hoseomeet/firebase/api/send_token_service.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  static const double baseWidth = 430.0;
  static const double baseHeight = 932.0;

  double w(BuildContext context, double x) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth * (x / baseWidth);
  }

  double h(BuildContext context, double y) {
    final screenHeight = MediaQuery.of(context).size.height;
    return screenHeight * (y / baseHeight);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider); // AuthState
    final authNotifier = ref.read(authNotifierProvider.notifier);

    // 로그인 성공 시 화면 이동 + FCM 토큰 서버 전송
    if (authState.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // (1) FCM 토큰 가져오기
        final token = await FirebaseMessaging.instance.getToken();
        print('로그인 후 FCM 토큰: $token');

        // (2) 토큰 서버 전송
        if (token != null && token.isNotEmpty) {
          // 예) SendTokenService를 사용해 서버 API 호출
          final authClient = ref.read(authHttpClientProvider);
          final sendTokenService = SendTokenService(authClient);
          final response = await sendTokenService.sendToken(token);

          if (response.statusCode == 200) {
            print('[FCM 토큰 등록] 서버 전송 성공');
          } else {
            print('[FCM 토큰 등록] 실패: code=${response.statusCode}, body=${response.body}');
          }
        }

        // (3) 화면 전환
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainTabPage()),
        );
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          if (authState.isLoading)
            const Opacity(
              opacity: 0.6,
              child: ModalBarrier(dismissible: false, color: Colors.black),
            ),
          if (authState.isLoading)
            const Center(child: CircularProgressIndicator()),

          _buildMainUI(context, authState, authNotifier),
        ],
      ),
    );
  }

  Widget _buildMainUI(BuildContext context, AuthState authState, AuthNotifier authNotifier) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(color: Colors.white),
        child: Stack(
          children: [
            // 로고
            Positioned(
              left: w(context, 139),
              top: h(context, 198),
              child: SizedBox(
                width: w(context, 153),
                height: h(context, 134),
                child: Image.asset("assets/img/login_logo.png"),
              ),
            ),
            // 아이디 입력
            Positioned(
              left: w(context, 79),
              top: h(context, 369),
              child: Container(
                width: w(context, 272),
                height: h(context, 36),
                decoration: ShapeDecoration(
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(width: 1, color: Color(0xFFF0B3AD)),
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: w(context, 19)),
                  child: TextField(
                    controller: _idController,
                    decoration: const InputDecoration(
                      hintText: '아이디',
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.60,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
            // 비밀번호 입력
            Positioned(
              left: w(context, 79),
              top: h(context, 414),
              child: Container(
                width: w(context, 272),
                height: h(context, 36),
                decoration: ShapeDecoration(
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(width: 1, color: Color(0xFFF0B3AD)),
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: w(context, 19)),
                  child: TextField(
                    controller: _pwController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: '비밀번호',
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.60,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
            // 로그인 버튼
            Positioned(
              left: w(context, 79),
              top: h(context, 469),
              child: GestureDetector(
                onTap: () async {
                  final id = _idController.text.trim();
                  final pw = _pwController.text.trim();

                  if (id.isEmpty || pw.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('아이디와 비밀번호를 입력해주세요.')),
                    );
                    return;
                  }

                  // 로그인 시도
                  await authNotifier.loginUser(id, pw);

                  // 에러가 있다면 표시
                  final err = ref.read(authNotifierProvider).errorMessage;
                  if (err != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                  }
                },
                child: Container(
                  width: w(context, 272),
                  height: h(context, 38),
                  decoration: ShapeDecoration(
                    color: const Color(0xFFE72410),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      '캠퍼스밋 로그인',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.60,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 회원가입 / 아이디/비번 찾기
            Positioned(
              left: w(context, 129),
              top: h(context, 526),
              child: SizedBox(
                width: w(context, 200),
                height: h(context, 30),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('회원가입 페이지 이동 미구현')),
                          );
                        },
                        child: const Text(
                          '회원가입',
                          style: TextStyle(
                            color: Color(0xFFB5B5B5),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.60,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 62,
                      top: 0,
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('아이디/비번 찾기 미구현')),
                          );
                        },
                        child: const Text(
                          '아이디/비밀번호 찾기',
                          style: TextStyle(
                            color: Color(0xFFB5B5B5),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.60,
                          ),
                        ),
                      ),
                    ),
                    // 가운데 점
                    Positioned(
                      left: w(context, 52),
                      top: h(context, 7),
                      child: Container(
                        width: w(context, 1),
                        height: w(context, 1),
                        decoration: const BoxDecoration(
                          color: Color(0xFFB5B5B5),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
