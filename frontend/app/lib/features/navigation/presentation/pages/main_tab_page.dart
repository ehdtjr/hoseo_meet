// file: lib/features/navigation/presentation/pages/main_tab_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoseomeet/features/home/presentation/pages/home_page.dart';

import '../../../chat/presentation/pages/chat_page.dart';
import '../../providers/bottom_nav_index_provider.dart';
import '../widgets/app_bottom_nav_bar.dart';

class MainTabPage extends ConsumerWidget {
  const MainTabPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 현재 탭 인덱스 (Riverpod)
    final currentIndex = ref.watch(bottomNavIndexProvider);

    // 바텀 내비 아이템 목록
    final bottomNavItems = [
      BottomNavItem(svgAsset: 'assets/icons/fi-rr-home.svg', label: 'HOME'),
      BottomNavItem(svgAsset: 'assets/icons/fi-rr-laugh.svg', label: 'MENT'),
      BottomNavItem(svgAsset: 'assets/icons/fi-rr-comment-alt.svg', label: 'CHAT'),
      BottomNavItem(svgAsset: 'assets/icons/fi-rr-user.svg', label: 'ME'),
    ];

    // 탭별 화면들 (IndexedStack에 배치)
    // 실제로는 HomePage(), MentPage(), ChatPage(), MePage() 등을 넣으시면 됩니다.
    final pages = [
      const HomePage(),
      Center(child: Text('MENT 페이지')),
      const ChatPage(),
      Center(child: Text('ME 페이지')),
    ];

    return Scaffold(
      // 탭 전환 시 이전 화면 상태를 유지하고 싶다면 IndexedStack 사용
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),

      // 커스텀 바텀 내비
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
