import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  DateTime _lastUpdateTime = DateTime.now();
  List<double>? _cachedPositions;

  // 각 섹션의 GlobalKey를 Container에 부여하여 올바른 위치 계산이 가능하도록 함.
  final GlobalKey _roomInfoKey = GlobalKey();
  final GlobalKey _reviewKey = GlobalKey();
  final GlobalKey _photoKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    // 첫 프레임 이후 캐시 무효화
    WidgetsBinding.instance.addPostFrameCallback((_) => _invalidateCache());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _invalidateCache() {
    _cachedPositions = null;
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
        alignment: 0.0,
      ).then((_) {
        _isScrolling = false;
      });
    } else {
      _isScrolling = false;
    }
  }

  BuildContext? _getSectionContext(int index) {
    switch (index) {
      case 0:
        return _roomInfoKey.currentContext;
      case 1:
        return _reviewKey.currentContext;
      case 2:
        return _photoKey.currentContext;
      default:
        return null;
    }
  }

  void _updateActiveTab(double scrollOffset) {
    final now = DateTime.now();
    if (now.difference(_lastUpdateTime).inMilliseconds < 100) return;
    _lastUpdateTime = now;

    final positions = _calculateSectionPositions();
    final activeIndex = _findClosestIndex(scrollOffset, positions);

    if (_tabController.index != activeIndex && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tabController.animateTo(activeIndex);
      });
    }
  }

  List<double> _calculateSectionPositions() {
    return _cachedPositions ??= [
      _getSectionOffset(_roomInfoKey),
      _getSectionOffset(_reviewKey),
      _getSectionOffset(_photoKey),
    ];
  }

  double _getSectionOffset(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return 0;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) return 0;
    final viewport = RenderAbstractViewport.of(renderBox);
    if (viewport == null) return 0;
    // getOffsetToReveal()를 사용하여 스크롤뷰 내에서 해당 위젯이 보이도록 하는 오프셋 계산
    final offset = viewport.getOffsetToReveal(renderBox, 0.0).offset;
    return offset;
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
    // 매 프레임마다 캐시 무효화하여 레이아웃 변경 시 최신 위치를 계산하도록 함.
    WidgetsBinding.instance.addPostFrameCallback((_) => _invalidateCache());

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (!_isScrolling && notification is ScrollUpdateNotification) {
          _updateActiveTab(notification.metrics.pixels);
        }
        return false;
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const ClampingScrollPhysics(),
        slivers: [
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
          // Room Info 섹션
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(25.0),
              child: Container(
                key: _roomInfoKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RoomInfoSection(roomDetail: widget.roomDetail),
                    const SizedBox(height: 20),
                    const Divider(
                      color: Color(0xFFF0B4AD),
                      thickness: 1.0,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Review 섹션
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Container(
                key: _reviewKey,
                child: ReviewSection(postId: widget.roomDetail.id.toString()),
              ),
            ),
          ),
          // Photo 섹션
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Container(
                key: _photoKey,
                child: const PhotoSection(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
