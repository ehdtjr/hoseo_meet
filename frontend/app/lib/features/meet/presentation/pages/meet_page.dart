import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoseomeet/features/meet/presentation/pages/create_meet_page.dart';
import '../widgets/meet_page/meet_circula_image_list.dart';
import '../widgets/meet_page/category_bar.dart';
import '../widgets/meet_page/meet_page_list.dart';
import '../widgets/meet_page/meet_page_serchbar.dart';

// 실제 파일명과 경로에 맞추어 import 변경
import '../../providers/meet_post_category_provider.dart';
import '../../providers/meet_post_provider.dart';
import '../../providers/meet_post_search.dart';

class MeetPage extends ConsumerStatefulWidget {
  const MeetPage({super.key});

  @override
  ConsumerState<MeetPage> createState() => _MeetPageState();
}

class _MeetPageState extends ConsumerState<MeetPage> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();

    // 초기 검색어 상태 설정
    _searchController.text = ref.read(searchQueryProvider);

    // 위젯 트리가 완전히 빌드된 뒤 초기 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(meetPostProvider.notifier).resetAndLoad();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 현재 검색어 상태
    ref.watch(searchQueryProvider);

    // 모임 게시글 목록 상태
    final meetPosts = ref.watch(meetPostProvider);
    // 모임 게시글 관련 notifier
    final notifier = ref.read(meetPostProvider.notifier);

    // 선택된 카테고리 상태
    final selectedCategory = ref.watch(meetPostCategoryProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: MeetSearchBarWidget(
            controller: _searchController,
            onSearch: (query) {
              ref.read(searchQueryProvider.notifier).state = query;
              notifier.resetAndLoad();
            },
            onClear: () {
              _searchController.clear();
              ref.read(searchQueryProvider.notifier).state = '';
              notifier.resetAndLoad();
            },
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent, // 터치 이벤트가 감지되도록 설정
        onTap: () {
          FocusScope.of(context).unfocus(); // 현재 포커스 해제하여 키보드 닫기
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 이미지 리스트와 카테고리 바
            Padding(
              padding: const EdgeInsets.only(left: 20.0, top: 15.0, bottom: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단 이미지 리스트
                  SizedBox(
                    width: double.infinity,
                    child: MeetCircularImageList(),
                  ),
                  const SizedBox(height: 25),
                  // 카테고리 바
                  CategoryBar(
                    selectedCategory: selectedCategory,
                    onCategorySelected: (category) {
                      // 카테고리 변경 시
                      ref.read(meetPostCategoryProvider.notifier).state = category;
                      notifier.resetAndLoad();
                    },
                  ),
                ],
              ),
            ),

            // 구분선
            const Divider(
              height: 2,
              thickness: 2,
              color: Colors.red,
            ),

            // 리스트 영역
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  notifier.resetAndLoad(); // 새 데이터 로드
                },
                child: MeetPostList(
                  meetPosts: meetPosts,
                  isLoading: notifier.isLoading,
                  hasMore: notifier.hasMore,
                  loadMore: () => notifier.loadMeetPosts(loadMore: true),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: RawMaterialButton(
        onPressed: () {
          // 버튼 클릭 시 동작
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateMeetPage(),
            ),
          );
        },
        fillColor: Colors.red, // 버튼 배경색
        shape: const CircleBorder(), // 원형 버튼
        constraints: const BoxConstraints.tightFor(
          width: 56,
          height: 56,
        ), // 버튼 크기 설정
        child: Image.asset(
          'assets/img/add-meet-post.png', // PNG 파일 경로
          width: 56,
          height: 56,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
