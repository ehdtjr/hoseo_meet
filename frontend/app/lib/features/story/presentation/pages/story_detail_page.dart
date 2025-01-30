import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/story_post.dart';

class StoryDetailPage extends ConsumerStatefulWidget {
  final List<StoryPost> stories;
  final int initialIndex;

  const StoryDetailPage({
    required this.stories,
    this.initialIndex = 0,
    super.key,
  });

  @override
  ConsumerState<StoryDetailPage> createState() => _StoryDetailPageState();
}

class _StoryDetailPageState extends ConsumerState<StoryDetailPage> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressController;
  late int _currentIndex;

  final Duration _storyDuration = const Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _progressController = AnimationController(
      vsync: this,
      duration: _storyDuration,
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    _startProgress();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _startProgress() {
    _progressController.forward(from: 0.0);
  }

  void _pauseProgress() {
    _progressController.stop();
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          _pauseProgress();
          // 화면을 좌/우로 나눠서 이전/다음 스토리 처리
          if (details.globalPosition.dx < MediaQuery.of(context).size.width / 2) {
            _previousStory();
          } else {
            _nextStory();
          }
        },
        onTapUp: (details) {
          _startProgress();
        },
        child: SafeArea(
          child: Stack(
            children: [
              // 스토리 페이지뷰
              PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.stories.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                    _startProgress();
                  });
                },
                itemBuilder: (context, index) {
                  final story = widget.stories[index];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // 스토리 이미지
                      Image.network(
                        story.imageUrl,
                        fit: BoxFit.cover,
                      ),
                      // 텍스트 오버레이
                      Positioned(
                        left: story.textOverlay.position.x,
                        top: story.textOverlay.position.y,
                        child: Text(
                          story.textOverlay.text,
                          style: TextStyle(
                            color: Color(int.parse(story.textOverlay.fontStyle.color, radix: 16)),
                            fontSize: story.textOverlay.fontStyle.size.toDouble(),
                            fontWeight: story.textOverlay.fontStyle.bold ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              // 상단 프로그레스 바
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  children: List.generate(
                    widget.stories.length,
                        (index) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: AnimatedBuilder(
                          animation: _progressController,
                          builder: (context, child) {
                            return LinearProgressIndicator(
                              value: index == _currentIndex
                                  ? _progressController.value
                                  : index < _currentIndex
                                  ? 1.0
                                  : 0.0,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // 닫기 버튼
              Positioned(
                top: 20,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
