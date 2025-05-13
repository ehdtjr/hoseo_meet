import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoseomeet/features/home/presentation/widgets/home_map_widgets.dart';
import 'package:hoseomeet/widgets/search_bar.dart';
import '../../../auth/providers/user_profile_provider.dart';
import '../../../meet/providers/meet_post_provider.dart';
import '../../../meet/providers/meet_post_search.dart';
import '../../providers/category_provider.dart';
import '../../providers/room/room_post_provider.dart';
import '../widgets/bottom_sheet/bottom_sheet_container.dart';
import '../widgets/home_category_row.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _searchController = TextEditingController();


  bool _showMap = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _showMap = true;
        });
      }
    });
  }

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
          if (_showMap)
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
            child: Consumer(
              builder: (context, ref, _) {
                final selectedCategory = ref.watch(categoryProvider);

                void _handleSearch(String query) {
                  final categoryName = selectedCategory?.name;

                  if (categoryName == '자취방') {
                    ref.read(roomPostSearchQueryProvider.notifier).state = query;
                    ref.read(roomPostProvider.notifier).resetAndLoad();
                  } else {
                    ref.read(meetPostSearchQueryProvider.notifier).state = query;
                    ref.read(meetPostProvider.notifier).resetAndLoad();
                  }
                }
                return SearchBarWidget(
                  controller: _searchController,
                  onSearch: _handleSearch,
                  onClear: () {
                    _searchController.clear();
                    _handleSearch('');
                  },
                );
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
