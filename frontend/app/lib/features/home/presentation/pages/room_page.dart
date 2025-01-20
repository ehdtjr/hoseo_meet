import 'package:flutter/material.dart';

import '../widgets/room_page/photo_section.dart';
import '../widgets/room_page/review/review_section.dart';
import '../widgets/room_page/room_info_section.dart';
import '../widgets/room_page/tab_bar_delegate.dart';

class RoomPage extends StatefulWidget {
  final String postId;

  const RoomPage({super.key, required this.postId});

  @override
  _RoomPageState createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _scrollController;

  static const double _sliverAppBarExpandedHeight = 280.0;
  static const double _sliverAppBarCollapsedHeight = kToolbarHeight;

  int _currentTabIndex = 0;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _scrollToSection(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isAnimating) return;

    final double offset = _scrollController.offset;
    final double sectionHeight = MediaQuery.of(context).size.height * 0.6;

    int newIndex;
    if (offset >= sectionHeight * 2 - _sliverAppBarCollapsedHeight) {
      newIndex = 2;
    } else if (offset >= sectionHeight - _sliverAppBarCollapsedHeight) {
      newIndex = 1;
    } else {
      newIndex = 0;
    }

    if (_currentTabIndex != newIndex) {
      setState(() {
        _currentTabIndex = newIndex;
        _tabController.animateTo(newIndex);
      });
    }
  }

  void _scrollToSection(int index) {
    _isAnimating = true;

    final double sectionHeight = MediaQuery.of(context).size.height * 0.6;
    double targetOffset = index * sectionHeight;

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    ).then((_) {
      _isAnimating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              // SliverAppBar: 이미지 영역
              SliverAppBar(
                expandedHeight: _sliverAppBarExpandedHeight,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Image.network(
                    'https://cdn.mhnse.com/news/photo/202409/319248_360163_4259.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // 텍스트 정보 영역
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        '퍼스트빌',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 26,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '자취방',
                        style: TextStyle(
                          color: Color(0xFF5F5F5F),
                          fontSize: 13,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w500,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ...List.generate(4, (index) {
                            return const Icon(Icons.star, color: Color(0xFFE72410), size: 24);
                          }),
                          const Icon(Icons.star, color: Color(0xFFD9D9D9), size: 24),
                          const SizedBox(width: 8),
                          const Text(
                            '(17)',
                            style: TextStyle(
                              color: Color(0xFF5F5F5F),
                              fontSize: 13,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w500,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '"잠이 잘오고 해가 잘 들어오는 자취방"',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF5F5F5F),
                          fontSize: 15,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w500,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // TabBar 영역
              SliverPersistentHeader(
                pinned: true,
                delegate: TabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    labelColor: Colors.red,
                    unselectedLabelColor: Colors.grey,
                    indicator: const UnderlineTabIndicator(
                      borderSide: BorderSide(width: 3.0, color: Colors.red),
                      insets: EdgeInsets.symmetric(horizontal: 50.0),
                    ),
                    tabs: const [
                      Tab(text: "정보"),
                      Tab(text: "리뷰"),
                      Tab(text: "사진"),
                    ],
                  ),
                ),
              ),

              // 각 섹션들
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Column(
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(),
                        child: RoomInfoSection(postId: widget.postId),
                      ),
                      const SizedBox(height: 20), // Divider 위에 여백 추가
                      const Divider(
                        color: Color(0xFFF0B4AD), // F0B4AD 색상 적용
                        thickness: 1.0, // Divider 두께
                        height: 1.0, // Divider 높이
                      ),
                    ],
                  ),
                ),
              ),


              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10.0, left: 25.0, right: 25.0, bottom: 25.0), // 각 방향별 패딩 설정
                  child: Column(
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(),
                        child: ReviewSection(postId: widget.postId),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 25.0, right: 25.0, bottom: 25.0), // 마지막 섹션에도 동일한 패딩 적용
                  child: Column(
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(),
                        child: const PhotoSection(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
