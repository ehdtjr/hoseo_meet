import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoseomeet/features/meet/presentation/pages/create_meet_page.dart';
import '../../../story/presentation/widgets/story_circula_image_list.dart';
import '../widgets/meet_page/category_bar.dart';
import '../widgets/meet_page/meet_page_list.dart';
import '../widgets/meet_page/meet_page_serchbar.dart';

// 실제 파일명과 경로에 맞추어 import 변경
import '../../providers/meet_post_category_provider.dart';
import '../../providers/meet_post_provider.dart';
import '../../providers/meet_post_search.dart';
import '../../../story/providers/story_post_provider.dart'; // ✅ 스토리 데이터 Provider 추가
import '../../../navigation/providers/bottom_nav_index_provider.dart'; // 탭 상태 감시

class MeetPage extends ConsumerStatefulWidget {
  const MeetPage({super.key});

  @override
  ConsumerState<MeetPage> createState() => _MeetPageState();
}

class _MeetPageState extends ConsumerState<MeetPage> {
  late TextEditingController _searchController;
  bool _isInitialized = false; // 활성화 상태를 추적하기 위한 변수

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();

    // 초기 검색어 상태 설정
    _searchController.text = ref.read(searchQueryProvider);
  }

  @override
  Widget build(BuildContext context) {
    // 현재 탭 상태 감시
    final currentIndex = ref.watch(bottomNavIndexProvider);

    // ✅ MeetPage가 활성화될 때 데이터를 초기화 (모임 리스트 + 스토리 리스트)
    if (currentIndex == 1 && !_isInitialized) {
      _isInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(meetPostProvider.notifier).resetAndLoad(); // 모임 리스트 재조회
        ref.invalidate(storyPostProvider); // ✅ 스토리 리스트 재조회
      });
    }

    // ✅ 다른 탭으로 이동하면 초기화 상태를 리셋
    if (currentIndex != 1) {
      _isInitialized = false;
    }

    // 현재 검색어 상태 감시
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
        behavior: HitTestBehavior.translucent, // 터치 이벤트 감지
        onTap: () {
          FocusScope.of(context).unfocus(); // 키보드 닫기
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
                  // ✅ 스토리 리스트 (스토리가 없어도 추가 버튼은 항상 보이도록 설정)
                  const SizedBox(
                    width: double.infinity,
                    child: StoryCircularImageList(),
                  ),
                  const SizedBox(height: 25),
                  // ✅ 카테고리 바
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
            const SizedBox(height: 20),

            // ✅ 리스트 영역 (새로고침 기능 추가)
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  notifier.resetAndLoad(); // 모임 리스트 새 데이터 로드
                  ref.invalidate(storyPostProvider); // ✅ 스토리 리스트 새 데이터 로드
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
        onPressed: () async {
          // 페이지 이동 후 생성 작업 결과를 기다림
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateMeetPage(),
            ),
          );

          // ✅ CreateMeetPage에서 Navigator.pop(context, true); 로 성공 여부 확인
          if (result == true) {
            ref.read(meetPostProvider.notifier).resetAndLoad(); // 모임 리스트 갱신
            ref.invalidate(storyPostProvider); // ✅ 스토리 리스트도 갱신
          }
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
