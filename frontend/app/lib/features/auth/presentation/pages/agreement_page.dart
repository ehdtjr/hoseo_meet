import 'package:campusmeet/features/auth/presentation/pages/privacy_policy_page.dart';
import 'package:campusmeet/features/auth/presentation/pages/register_page.dart';
import 'package:flutter/material.dart';
import 'terms_policy_page.dart'; // TermsPolicyPage를 import 해주세요

class AgreementPage extends StatefulWidget {
  const AgreementPage({super.key});

  @override
  State<AgreementPage> createState() => _AgreementPageState();
}

class _AgreementPageState extends State<AgreementPage> {
  bool _agreeTerms = false;
  bool _agreePrivacy = false;
  bool _agreeLocation = false;

  bool get _allChecked => _agreeTerms && _agreePrivacy && _agreeLocation;

  Widget _buildCheckboxWithViewButton({
    required String label,
    required bool value,
    required Function(bool?) onChanged,
    required VoidCallback onViewPressed,
  }) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFFE72410), // ✅ 체크 시 빨간색
        ),
        Expanded(child: Text(label)),
        TextButton(
          onPressed: onViewPressed,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFE72410), // ✅ 텍스트도 빨간색
          ),
          child: const Text('보기'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('약관 동의'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildCheckboxWithViewButton(
                label: '이용약관에 동의합니다.',
                value: _agreeTerms,
                onChanged: (val) => setState(() => _agreeTerms = val ?? false),
                onViewPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TermsPolicyPage(initialIndex: 0),
                    ),
                  );
                },
              ),
              _buildCheckboxWithViewButton(
                label: '위치기반 서비스 이용에 동의합니다.',
                value: _agreeLocation,
                onChanged: (val) =>
                    setState(() => _agreeLocation = val ?? false),
                onViewPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TermsPolicyPage(initialIndex: 1),
                    ),
                  );
                },
              ),
              _buildCheckboxWithViewButton(
                label: '개인정보 처리방침에 동의합니다.',
                value: _agreePrivacy,
                onChanged: (val) =>
                    setState(() => _agreePrivacy = val ?? false),
                onViewPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32), // ✅ 너무 아래로 밀리지 않게 여백만 추가
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _allChecked
                      ? () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterPage()),
                    );
                  }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE72410),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '모두 동의하고 계속하기',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
