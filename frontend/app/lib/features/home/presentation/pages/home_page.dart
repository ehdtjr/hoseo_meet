import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoseomeet/features/home/presentation/widgets/home_map_widgets.dart';
import 'package:hoseomeet/widgets/search_bar.dart';
import '../../../auth/providers/user_profile_provider.dart';
import '../../providers/category_provider.dart';
import '../widgets/bottom_sheet/bottom_sheet_container.dart';
import '../widgets/home_category_row.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileState = ref.watch(userProfileNotifierProvider);
    final userProfileNotifier = ref.read(userProfileNotifierProvider.notifier);
    final selectedCategory = ref.watch(categoryProvider);

    return Scaffold(
      body: Stack(
        children: [
          // 지도
          Positioned.fill(
            child: Container(
              color: Colors.grey[300],
              child: const HomeMap(),
            ),
          ),
          // 검색바
          const Positioned(
            top: 60,
            left: 24,
            right: 24,
            child: SearchBarWidget(),
          ),
          // 카테고리 Row
          const Positioned(
            top: 122,
            left: 24,
            right: 0,
            child: CategoryRow(), // 분리된 위젯 사용
          ),
          // 하단 오버레이
          DraggableScrollableSheet(
            initialChildSize: 0.2,
            minChildSize: 0.1,
            maxChildSize: 0.75,
            builder: (BuildContext context, ScrollController scrollController) {
              if (userProfileState.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (userProfileState.errorMessage != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(userProfileState.errorMessage!),
                      ElevatedButton(
                        onPressed: () => userProfileNotifier.fetchUserProfile(),
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                );
              }

              if (userProfileState.userProfile != null) {
                // 사용자 이름을 userProfile에서 가져오기
                final userName = userProfileState.userProfile!.name;

                return BottomSheetContainer(
                  scrollController: scrollController,
                  userProfile: userProfileState.userProfile!,
                  selectedCategory: selectedCategory,
                  userName: userName,
                );
              }

              return const Center(child: Text('프로필 정보가 없습니다.'));
            },
          ),
        ],
      ),
    );
  }
}
