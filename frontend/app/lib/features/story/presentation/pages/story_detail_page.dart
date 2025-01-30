import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/story_post.dart';
import '../../providers/story_post_provider.dart';

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

class _StoryDetailPageState extends ConsumerState<StoryDetailPage>
    with SingleTickerProviderStateMixin {
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
    )..addStatusListener(_handleAnimationStatus);

    _startProgress();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _nextStory();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.removeStatusListener(_handleAnimationStatus);
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

  Widget _buildParticipateButton(StoryPost story) {
    return GestureDetector(
      onTap: () async {
        if (!story.isSubscribed) {
          _pauseProgress();
          try {
            final success = await ref.read(storyPostProvider.notifier).subscribeToStory(story.id);
            if (success && mounted) {
              setState(() {
                final index = widget.stories.indexOf(story);
                widget.stories[index] = story.copyWith(isSubscribed: true);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("✅ 참여 완료!")),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("❌ 참여 실패")),
              );
            }
          } finally {
            if (mounted) {
              _startProgress();
            }
          }
        }
      },
      child: Container(
        width: 134,
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: 1.5,
              color: story.isSubscribed ? Colors.grey : const Color(0xFFE72410),
            ),
            borderRadius: BorderRadius.circular(26),
          ),
          shadows: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 7.30,
              offset: Offset(1, 4),
              spreadRadius: 0,
            )
          ],
        ),
        child: Center(
          child: Text(
            story.isSubscribed ? '참여중' : '참여하기',
            style: TextStyle(
              color: story.isSubscribed ? Colors.grey : const Color(0xFFE72410),
              fontSize: 21,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          _pauseProgress();
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
                      Image.network(
                        story.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(child: Text('이미지 로드 실패'));
                        },
                      ),
                      Positioned(
                        left: story.textOverlay.position.x,
                        top: story.textOverlay.position.y,
                        child: Text(
                          story.textOverlay.text,
                          style: TextStyle(
                            color: Color(int.parse(story.textOverlay.fontStyle.color, radix: 16)),
                            fontSize: story.textOverlay.fontStyle.size.toDouble(),
                            fontWeight: story.textOverlay.fontStyle.bold
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 50,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: _buildParticipateButton(story),
                        ),
                      ),
                    ],
                  );
                },
              ),
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
                              valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.white),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
