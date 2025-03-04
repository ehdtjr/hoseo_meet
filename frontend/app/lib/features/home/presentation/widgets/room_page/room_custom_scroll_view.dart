import 'package:flutter/material.dart';
import 'package:hoseomeet/features/home/presentation/widgets/room_page/photo_section.dart';
import 'package:hoseomeet/features/home/presentation/widgets/room_page/review/review_section.dart';
import 'package:hoseomeet/features/home/presentation/widgets/room_page/room_info_section.dart';
import 'package:hoseomeet/features/home/data/models/room_post_detail.dart';
import 'package:hoseomeet/features/home/presentation/widgets/room_page/tab_bar_delegate.dart';

class RoomCustomScrollView extends StatefulWidget {
  final RoomDetail roomDetail;
  const RoomCustomScrollView({
    Key? key,
    required this.roomDetail,
  }) : super(key: key);

  @override
  _RoomCustomScrollViewState createState() => _RoomCustomScrollViewState();
}

class _RoomCustomScrollViewState extends State<RoomCustomScrollView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  bool _isScrolling = false;

  // 각 섹션의 GlobalKey 추가
  final GlobalKey roomInfoKey = GlobalKey();
  final GlobalKey reviewKey = GlobalKey();
  final GlobalKey photoKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_isScrolling && _tabController.indexIsChanging) {
      _scrollToSection(_tabController.index);
    }
  }

  void _scrollToSection(int index) {
    _isScrolling = true;
    final context = _getSectionContext(index);
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ).then((_) => _isScrolling = false);
    }
  }

  BuildContext? _getSectionContext(int index) {
    switch (index) {
      case 0:
        return roomInfoKey.currentContext;
      case 1:
        return reviewKey.currentContext;
      case 2:
        return photoKey.currentContext;
      default:
        return null;
    }
  }

  void _updateActiveTab(double offset) {
    final positions = _calculateSectionPositions();
    final activeIndex = _findClosestIndex(offset, positions);

    if (_tabController.index != activeIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tabController.animateTo(activeIndex);
      });
    }
  }

  List<double> _calculateSectionPositions() {
    return [
      _getSectionOffset(roomInfoKey),
      _getSectionOffset(reviewKey),
      _getSectionOffset(photoKey),
    ];
  }

  double _getSectionOffset(GlobalKey key) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    return renderBox?.localToGlobal(Offset.zero).dy ?? 0;
  }

  int _findClosestIndex(double offset, List<double> positions) {
    double minDistance = double.infinity;
    int closestIndex = 0;

    for (int i = 0; i < positions.length; i++) {
      final distance = (positions[i] - offset).abs();
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (!_isScrolling && notification is ScrollUpdateNotification) {
          _updateActiveTab(notification.metrics.pixels);
        }
        return false;
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: TabBarDelegate(
              TabBar(
                controller: _tabController, // 컨트롤러 연결
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
                    key: roomInfoKey, // 키 적용
                    child: RoomInfoSection(roomDetail: widget.roomDetail),
                  ),
                  const SizedBox(height: 20),
                  const Divider(
                    color: Color(0xFFF0B4AD),
                    thickness: 1.0,
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Container(
                key: reviewKey, // 키 적용
                child: ReviewSection(postId: widget.roomDetail.id.toString()),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Container(
                key: photoKey, // 키 적용
                child: const PhotoSection(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
