import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/providers/auth_notifier_provider.dart';
import '../../../navigation/presentation/pages/main_tab_page.dart';
import '../../data/models/auth_state.dart';
import '../../providers/auth_notifier.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  // TextField 컨트롤러
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  // 디자인 기준
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
    final authState = ref.watch(authNotifierProvider); // AuthState 구독
    final authNotifier = ref.read(authNotifierProvider.notifier);

    // 로그인 성공 시 화면 이동 처리 (예시)
    if (authState.isLoggedIn) {
      // 이미 로그인된 상태라면 바로 HomeScreen 으로
      WidgetsBinding.instance.addPostFrameCallback((_) {
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
          // 로딩 상태 표시
          if (authState.isLoading)
            const Opacity(
              opacity: 0.6,
              child: ModalBarrier(dismissible: false, color: Colors.black),
            ),
          if (authState.isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),

          // 메인 UI
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
            // 로고 영역
            Positioned(
              left: w(context, 139),
              top: h(context, 198),
              child: Container(
                width: w(context, 153),
                height: h(context, 134),
                color: Colors.transparent,
                child: Image.asset("assets/img/login_logo.png"),
              ),
            ),

            // 아이디 입력 영역
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
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w500,
                      height: 1.60,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),

            // 비밀번호 입력 영역
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
                    obscureText: true, // 비밀번호 마스킹
                    decoration: const InputDecoration(
                      hintText: '비밀번호',
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w500,
                      height: 1.60,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),

            // 로그인 버튼 (onTap)
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

                  // 에러가 있다면 스낵바 표시
                  final err = ref.read(authNotifierProvider).errorMessage;
                  if (err != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(err)),
                    );
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
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                        height: 1.60,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 아이디/비밀번호 찾기, 회원가입
            Positioned(
              left: w(context, 129),
              top: h(context, 526),
              child: SizedBox(
                width: w(context, 200),
                height: h(context, 30),
                child: Stack(
                  children: [
                    // 회원가입
                    Positioned(
                      left: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () {
                          // TODO: 회원가입 페이지로 이동
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('회원가입 페이지 이동 미구현')),
                          );
                        },
                        child: const Text(
                          '회원가입',
                          style: TextStyle(
                            color: Color(0xFFB5B5B5),
                            fontSize: 13,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w500,
                            height: 1.60,
                          ),
                        ),
                      ),
                    ),

                    // 아이디/비밀번호 찾기
                    Positioned(
                      left: 62,
                      top: 0,
                      child: GestureDetector(
                        onTap: () {
                          // TODO: 아이디/비번 찾기 페이지
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('아이디/비번 찾기 미구현')),
                          );
                        },
                        child: const Text(
                          '아이디/비밀번호 찾기',
                          style: TextStyle(
                            color: Color(0xFFB5B5B5),
                            fontSize: 13,
                            fontFamily: 'Pretendard',
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
