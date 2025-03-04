import 'package:flutter/material.dart';

class NoOverscrollBehavior extends ScrollBehavior {
  @override
  Widget buildViewportChrome(
      BuildContext context, Widget child, AxisDirection axisDirection) {
    return child;
  }
}

/// 고정 헤더로 사용할 RoomHeaderWidget
class RoomHeaderWidget extends StatefulWidget {
  final double expandedHeight;
  final List<String> imageUrls;

  const RoomHeaderWidget({
    Key? key,
    required this.expandedHeight,
    required this.imageUrls,
  }) : super(key: key);

  @override
  _RoomHeaderWidgetState createState() => _RoomHeaderWidgetState();
}

class _RoomHeaderWidgetState extends State<RoomHeaderWidget> {
  late final PageController _pageController;
  final ValueNotifier<int> _currentPageNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _currentPageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 이미지가 없는 경우 회색 박스 표시
    if (widget.imageUrls.isEmpty) {
      return Container(
        height: widget.expandedHeight,
        color: Colors.grey,
        child: const Center(
          child: Icon(Icons.image_not_supported, color: Colors.white, size: 50),
        ),
      );
    }

    return Container(
      height: widget.expandedHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 여러 이미지가 있을 경우 PageView로 슬라이더 구현
          widget.imageUrls.length > 1
              ? ScrollConfiguration(
            behavior: NoOverscrollBehavior(),
            child: PageView.builder(
              controller: _pageController,
              physics: const ClampingScrollPhysics(),
              itemCount: widget.imageUrls.length,
              onPageChanged: (index) {
                _currentPageNotifier.value = index;
              },
              itemBuilder: (context, index) {
                return Image.network(
                  widget.imageUrls[index],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey,
                    child: const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  ),
                );
              },
            ),
          )
              : Image.network(
            widget.imageUrls.first,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey,
              child: const Center(
                child: Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
          ),
          // 페이지 인디케이터 (여러 이미지 있을 때만)
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<int>(
                valueListenable: _currentPageNotifier,
                builder: (context, currentPage, child) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.imageUrls.length, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: currentPage == index ? 10 : 6,
                        height: currentPage == index ? 10 : 6,
                        decoration: BoxDecoration(
                          color: currentPage == index ? Colors.white : Colors.white54,
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
