import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoseomeet/features/home/presentation/widgets/home_map_widgets.dart';
import 'package:hoseomeet/widgets/search_bar.dart';
import '../../../auth/providers/user_profile_provider.dart';
import '../../providers/category_provider.dart';
import '../widgets/bottom_sheet/bottom_sheet_container.dart';
import '../widgets/home_category_row.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          Positioned(
            top: 60,
            left: 24,
            right: 24,
            child: SearchBarWidget(
              controller: _searchController,
              onSearch: (query) {
                print('검색어: $query');
                // 검색 로직 추가 가능
              },
              onClear: () {
                _searchController.clear();
                print('검색어 초기화');
              },
            ),
          ),
          // 카테고리 Row
          const Positioned(
            top: 122,
            left: 24,
            right: 0,
            child: CategoryRow(),
          ),
          // 하단 오버레이
          DraggableScrollableSheet(
            initialChildSize: 0.2,
            minChildSize: 0.2,
            maxChildSize: 0.8,
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
                final userName = userProfileState.userProfile!.name;

                return BottomSheetContainer(
                  scrollController: scrollController, // ScrollController 전달
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
