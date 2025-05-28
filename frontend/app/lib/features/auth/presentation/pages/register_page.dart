import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/providers/auth_notifier_provider.dart';
import '../../data/models/auth_state.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _nameController = TextEditingController();

  String? _selectedGender;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final request = RegisterRequest(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      name: _nameController.text.trim(),
      gender: _selectedGender!,
    );

    final authNotifier = ref.read(authNotifierProvider.notifier);
    final result = await authNotifier.register(request);

    if (!mounted) return;

    if (result.success) {
      _showAnimatedSuccessDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? '회원가입 실패')),
      );
    }

    setState(() => _isSubmitting = false);
  }

  void _showAnimatedSuccessDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '회원가입 완료',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, _, child) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Transform.scale(
              scale: animation.value,
              child: Opacity(
                opacity: animation.value,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                          Icons.check_circle, size: 60, color: Colors.green),
                      const SizedBox(height: 16),
                      const Text(
                        '회원가입 완료',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '회원가입이 성공적으로 완료되었습니다.\n이메일 인증을 진행해주세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, height: 1.5),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE72410),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(); // 다이얼로그 닫기
                          Navigator.pop(context); // 회원가입 페이지 닫기
                        },
                        child: const Text(
                          '확인',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text("회원가입"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "기본 정보 입력",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              _buildRoundedField(_emailController, "이메일",
                  type: TextInputType.emailAddress),
              const SizedBox(height: 16),

              _buildRoundedField(_passwordController, "비밀번호",
                  type: TextInputType.visiblePassword, obscureText: true),
              const SizedBox(height: 16),

              _buildRoundedField(
                _passwordConfirmController,
                "비밀번호 확인",
                type: TextInputType.visiblePassword,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '비밀번호 확인을 입력해주세요.';
                  }
                  if (value != _passwordController.text) {
                    return '비밀번호가 일치하지 않습니다.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildRoundedField(_nameController, "닉네임"),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedGender,
                dropdownColor: Colors.white,
                iconEnabledColor: Colors.black,
                decoration: InputDecoration(
                  labelText: "성별",
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFDADADA)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFDADADA)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFDADADA)),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: "male", child: Text("남자")),
                  DropdownMenuItem(value: "female", child: Text("여자")),
                  DropdownMenuItem(value: "other", child: Text("선택안함")),
                ],
                onChanged: (value) {
                  setState(() => _selectedGender = value);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '성별을 선택해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE72410),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    "회원가입",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoundedField(TextEditingController controller,
      String label, {
        TextInputType type = TextInputType.text,
        bool obscureText = false,
        bool required = true,
        String? Function(String?)? validator,
      }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDADADA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDADADA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDADADA)),
        ),
      ),
      validator: validator ??
              (value) {
            if (required && (value == null || value
                .trim()
                .isEmpty)) {
              return '$label을(를) 입력해주세요.';
            }

            if (label == "이메일") {
              final emailRegex =
              RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegex.hasMatch(value!)) {
                return '올바른 이메일 형식이 아닙니다.';
              }
            }

            return null;
          },
    );
  }
}
