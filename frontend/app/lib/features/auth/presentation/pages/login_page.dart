import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hoseomeet/features/auth/presentation/pages/agreement_page.dart';
import 'package:hoseomeet/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:hoseomeet/features/auth/presentation/pages/register_page.dart';

import '../../../../commons/network/auth_http_client_provider.dart';
import '../../../../features/auth/providers/auth_notifier_provider.dart';
import '../../../navigation/presentation/pages/main_tab_page.dart';
import '../../data/models/auth_state.dart';
import '../../providers/auth_notifier.dart';
import 'package:hoseomeet/firebase/api/send_token_service.dart';
import '../../providers/user_profile_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  bool _navigated = false;

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
    final authState = ref.watch(authNotifierProvider);
    final authNotifier = ref.read(authNotifierProvider.notifier);
    final userProfileNotifier = ref.read(userProfileNotifierProvider.notifier);

    if (authState.isLoggedIn && !_navigated) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.isNotEmpty) {
          final authClient = ref.read(authHttpClientProvider);
          final sendTokenService = SendTokenService(authClient);
          final response = await sendTokenService.sendToken(token);

          if (response.statusCode == 200) {
            debugPrint('[FCM 토큰 등록] 서버 전송 성공');
          } else {
            debugPrint('[FCM 토큰 등록] 실패: code=${response.statusCode}, body=${response.body}');
          }
        }

        await userProfileNotifier.fetchUserProfile();

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => MainTabPage()),
          );
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildMainUI(context, authState, authNotifier),
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
            Positioned(
              left: w(context, 139),
              top: h(context, 198),
              child: SizedBox(
                width: w(context, 153),
                height: h(context, 134),
                child: Image.asset("assets/img/login_logo.png"),
              ),
            ),
            Positioned(
              left: w(context, 79),
              top: h(context, 369),
              child: _buildTextField(_idController, hintText: '아이디'),
            ),
            Positioned(
              left: w(context, 79),
              top: h(context, 414),
              child: _buildTextField(_pwController, hintText: '비밀번호', obscureText: true),
            ),
            Positioned(
              left: w(context, 79),
              top: h(context, 469),
              child: GestureDetector(
                onTap: authState.isLoading
                    ? null
                    : () async {
                  final id = _idController.text.trim();
                  final pw = _pwController.text.trim();

                  if (id.isEmpty || pw.isEmpty) {
                    _showDialog(context, '입력 오류', '아이디와 비밀번호를 입력해주세요.');
                    return;
                  }

                  await authNotifier.loginUser(id, pw);

                  final err = ref.read(authNotifierProvider).errorMessage;
                  if (err != null && context.mounted) {
                    _showDialog(context, '로그인 실패', err);
                  }
                },
                child: Container(
                  width: w(context, 272),
                  height: h(context, 38),
                  decoration: ShapeDecoration(
                    color: authState.isLoading ? Colors.grey : const Color(0xFFE72410),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                  child: Center(
                    child: authState.isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Text(
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
            Positioned(
              left: w(context, 79),
              top: h(context, 526),
              child: SizedBox(
                width: w(context, 272),
                height: h(context, 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AgreementPage()),
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
                    const SizedBox(width: 16),
                    Container(
                      width: 1,
                      height: 12,
                      color: Color(0xFFB5B5B5),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                        );},
                      child: const Text(
                        '비밀번호 찾기',
                        style: TextStyle(
                          color: Color(0xFFB5B5B5),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.60,
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

  Widget _buildTextField(
      TextEditingController controller, {
        required String hintText,
        bool obscureText = false,
      }) {
    return Container(
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
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hintText,
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
    );
  }

  void _showDialog(BuildContext context, String title, String message) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: title,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, _) {
        return Center(
          child: Transform.scale(
            scale: animation.value,
            child: Opacity(
              opacity: animation.value,
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        style: const TextStyle(fontSize: 15, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: const Color(0xFFE72410),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('확인'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
