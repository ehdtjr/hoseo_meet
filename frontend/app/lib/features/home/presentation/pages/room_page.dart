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

  final GlobalKey roomInfoKey = GlobalKey();
  final GlobalKey reviewKey = GlobalKey();
  final GlobalKey photoKey = GlobalKey();

  final Map<int, double> _sectionOffsets = {};
  int _currentTabIndex = 0;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController = ScrollController();

    // 최초 레이아웃 완료 후 오프셋 계산
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateSectionOffsets();
      _scrollController.addListener(_onScroll);
    });

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

  // 섹션별 오프셋 계산 함수
  void _calculateSectionOffsets() {
    for (int i = 0; i < 3; i++) {
      _sectionOffsets[i] = _getSectionOffset(i);
    }
  }

  double _getSectionOffset(int index) {
    final RenderBox? renderBox;
    switch(index) {
      case 0:
        renderBox = roomInfoKey.currentContext?.findRenderObject() as RenderBox?;
        break;
      case 1:
        renderBox = reviewKey.currentContext?.findRenderObject() as RenderBox?;
        break;
      case 2:
        renderBox = photoKey.currentContext?.findRenderObject() as RenderBox?;
        break;
      default:
        return 0;
    }

    if (renderBox == null) return 0;

    final offset = renderBox.localToGlobal(Offset.zero).dy;
    // AppBar 높이와 TabBar 높이를 고려한 오프셋 계산
    return offset - _sliverAppBarCollapsedHeight - kTextTabBarHeight;
  }

  void _onScroll() {
    if (_isAnimating) return;

    final double scrollOffset = _scrollController.offset;
    int newIndex = 0;

    // 현재 스크롤 위치에 따른 활성 섹션 결정
    for (int i = 0; i < _sectionOffsets.length; i++) {
      if (scrollOffset >= _sectionOffsets[i]! - 50) { // 약간의 여유값 추가
        newIndex = i;
      }
    }

    if (_currentTabIndex != newIndex) {
      setState(() {
        _currentTabIndex = newIndex;
        _tabController.animateTo(newIndex);
      });
    }
  }

  void _scrollToSection(int index) {
    if (!mounted) return;

    _isAnimating = true;
    double targetOffset = _sectionOffsets[index] ?? 0;

    // 최소/최대 스크롤 범위 제한
    targetOffset = targetOffset.clamp(
        0,
        _scrollController.position.maxScrollExtent
    );

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
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                children: [
                  Container(
                    key: roomInfoKey,
                    child: RoomInfoSection(postId: widget.postId),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFF0B4AD), thickness: 1.0),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Container(
                key: reviewKey,
                child: ReviewSection(postId: widget.postId),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Container(
                key: photoKey,
                child: const PhotoSection(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
