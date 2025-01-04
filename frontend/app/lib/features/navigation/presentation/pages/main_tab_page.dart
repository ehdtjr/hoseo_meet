// file: lib/features/navigation/presentation/pages/main_tab_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hoseomeet/features/home/presentation/pages/home_page.dart';
import 'package:hoseomeet/features/chat/presentation/pages/chat_page.dart';

// 바텀 내비게이션 인덱스 Provider
import '../../providers/bottom_nav_index_provider.dart';
import '../widgets/app_bottom_nav_bar.dart';

// (★) 로그인 상태 감시하기 위해 AuthNotifier import
import 'package:hoseomeet/features/auth/providers/auth_notifier_provider.dart';
import 'package:hoseomeet/features/auth/presentation/pages/login_page.dart';

class MainTabPage extends ConsumerWidget {
  const MainTabPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ① 현재 사용자 로그인 상태
    final authState = ref.watch(authNotifierProvider);

    // ② 로그인되지 않았다면 → LoginPage 이동
    if (!authState.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      });
    }

    // ③ 현재 탭 인덱스 (Riverpod)
    final currentIndex = ref.watch(bottomNavIndexProvider);

    // ④ 바텀 내비 아이템
    final bottomNavItems = [
      BottomNavItem(svgAsset: 'assets/icons/fi-rr-home.svg', label: 'HOME'),
      BottomNavItem(svgAsset: 'assets/icons/fi-rr-laugh.svg', label: 'MENT'),
      BottomNavItem(svgAsset: 'assets/icons/fi-rr-comment-alt.svg', label: 'CHAT'),
      BottomNavItem(svgAsset: 'assets/icons/fi-rr-user.svg', label: 'ME'),
    ];

    // ⑤ 탭별 화면들
    final pages = [
      const HomePage(),
      const Center(child: Text('MENT 페이지')),
      const ChatPage(),
      const Center(child: Text('ME 페이지')),
    ];

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: AppBottomNavBar(
        items: bottomNavItems,
        currentIndex: currentIndex,
        onTap: (index) {
          ref.read(bottomNavIndexProvider.notifier).state = index;
        },
      ),
    );
  }
}
