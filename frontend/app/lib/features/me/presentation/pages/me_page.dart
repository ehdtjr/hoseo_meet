import 'package:campusmeet/features/me/presentation/pages/block_user_page.dart';
import 'package:campusmeet/features/me/presentation/pages/terms_of_user_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../widgets/showConfirmDialog.dart';
import '../../../auth/presentation/pages/privacy_policy_page.dart';
import '../../../auth/presentation/pages/terms_policy_page.dart';
import '../../../auth/providers/auth_notifier_provider.dart';
import '../../../auth/providers/tag_provider.dart';
import '../../../auth/providers/user_profile_provider.dart';
import '../../widgets/profile_section.dart';
import 'edit_profile_page.dart';
import 'change_password_page.dart';

class MePage extends ConsumerStatefulWidget {
  const MePage({Key? key}) : super(key: key);

  @override
  ConsumerState<MePage> createState() => _MePageState();
}

class _MePageState extends ConsumerState<MePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        ref.read(userProfileNotifierProvider.notifier).fetchUserProfile());
        ref.read(tagNotifierProvider.notifier).fetchTags();
  }

  @override
  Widget build(BuildContext context) {
    final userProfileState = ref.watch(userProfileNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "프로필",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: userProfileState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          const ProfileSection(),
          const Divider(height: 32, thickness: 1, color: Color(0xFFF0B4AD)),
          // 메뉴 섹션
          ..._buildMenuSection("계정", ["프로필 변경", "비밀번호 변경", "차단한 사용자"]),
          // ..._buildMenuSection("게시글", ["내가 작성한 글"]),
          ..._buildMenuSection("이용 안내", ["이용 규칙", "약관 및 정책", "개인정보 처리 방침"]),
          ..._buildMenuSection("기타", ["로그아웃", "회원 탈퇴"]),
        ],
      ),
    );
  }


  List<Widget> _buildMenuSection(String title, List<String> items) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          title,
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ),
      ...items.map((item) => ListTile(
        title: Text(item,
            style: const TextStyle(fontSize: 16, color: Colors.black87)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {
          switch (item) {
            case "프로필 변경":
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileImagePage()),
              );
              break;
            case "비밀번호 변경":
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
              );
              break;
            case "차단한 사용자":
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BlockUserPage()),
              );
              break;
            case "이용 규칙":
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsOfUsePage()),
              );
              break;
            case "약관 및 정책":
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsPolicyPage()),
              );
              case "개인정보 처리 방침":
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
              );
              break;
            case "로그아웃":
              ref.read(authNotifierProvider.notifier).logout();
              break;
            case "회원 탈퇴":
              showConfirmDialog(
                context: context,
                title: "정말 탈퇴하시겠어요?",
                description: "계정 정보와 모든 데이터가 삭제됩니다. 이 작업은 되돌릴 수 없습니다.",
                confirmText: "탈퇴하기",
                confirmColor: Colors.redAccent,
                onConfirm: () async {
                  try {
                    await ref.read(authNotifierProvider.notifier).deleteAccount();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('탈퇴 실패: $e')),
                      );
                    }
                  }
                },
              );
              break;
            default:
              break;
          }
        },
      )),
      const Divider(height: 24, thickness: 1, color: Color(0xFFF0B4AD)),
    ];
  }
}