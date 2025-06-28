import 'package:campusmeet/features/home/presentation/widgets/restaurant/menu/menu_section.dart';
import 'package:campusmeet/features/home/presentation/widgets/restaurant/restaurant_info_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/restaurant/restaurant_post_detail.dart';
import '../../../providers/restaurant/restaurant_post_provider.dart';
import '../room_page/tab_bar_delegate.dart';
import 'bottom_action_button.dart';

class RestaurantCustomScrollView extends StatefulWidget {
  final RestaurantPostDetail restaurant;

  const RestaurantCustomScrollView({
    super.key,
    required this.restaurant,
  });

  @override
  State<RestaurantCustomScrollView> createState() =>
      _RestaurantCustomScrollViewState();
}

class _RestaurantCustomScrollViewState
    extends State<RestaurantCustomScrollView> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  bool _isScrolling = false;
  DateTime _lastUpdateTime = DateTime.now();
  List<double>? _cachedPositions;

  final GlobalKey _infoKey = GlobalKey();
  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _reviewKey = GlobalKey();
  final GlobalKey _photoKey = GlobalKey();

  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
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
        return _infoKey.currentContext;
      case 1:
        return _menuKey.currentContext;
      case 2:
        return _reviewKey.currentContext;
      case 3:
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

    if (mounted && _activeTabIndex != activeIndex) {
      setState(() {
        _activeTabIndex = activeIndex;
      });
    }

    if (_tabController.index != activeIndex && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tabController.animateTo(activeIndex);
      });
    }
  }

  List<double> _calculateSectionPositions() {
    return _cachedPositions ??= [
      _getSectionOffset(_infoKey),
      _getSectionOffset(_menuKey),
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
    return viewport.getOffsetToReveal(renderBox, 0.0).offset;
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _invalidateCache());

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
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
                      Tab(text: "메뉴"),
                      Tab(text: "리뷰"),
                      Tab(text: "사진"),
                    ],
                  ),
                ),
              ),

              // 정보 섹션
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Container(
                    key: _infoKey,
                    child: Consumer(
                      builder: (context, ref, _) {
                        final restaurantNotifier =
                        ref.read(restaurantPostProvider.notifier);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RestaurantInfoSection(
                              restaurant: widget.restaurant,
                              onUpdate: (updated) async {
                                await restaurantNotifier.updateRestaurant(updated);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('맛집 정보가 저장되었습니다')),
                                );
                              },
                            ),
                            const Divider(
                                color: Color(0xFFF0B4AD), thickness: 1.0),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // 메뉴 섹션
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: Container(
                    key: _menuKey,
                    child: MenuSection(
                      postId: widget.restaurant.id,
                    ),
                  ),
                ),
              ),

              // 리뷰 섹션 (예시용 빈 공간)
              SliverToBoxAdapter(
                child: Container(
                  key: _reviewKey,
                  height: 400,
                  padding: const EdgeInsets.all(20),
                  child: const Text('리뷰 섹션 내용 (예시)'),
                ),
              ),

              // 사진 섹션 (예시용 빈 공간)
              SliverToBoxAdapter(
                child: Container(
                  key: _photoKey,
                  height: 400,
                  padding: const EdgeInsets.all(20),
                  child: const Text('사진 섹션 내용 (예시)'),
                ),
              ),
            ],
          ),
        ),
        BottomActionButton(tabIndex: _activeTabIndex, postId: widget.restaurant.id),
      ],
    );
  }
}
