import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../widgets/showConfirmDialog.dart';
import '../../../auth/presentation/pages/report_page.dart';
import '../../data/models/story_post.dart';
import '../../providers/story_post_provider.dart';
import '../../../auth/providers/user_profile_provider.dart';

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(storyPostProvider.notifier).fetchAuthorsForStories(widget.stories);
    });

    _startProgress();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _nextStory();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.removeStatusListener(_handleAnimationStatus);
    _progressController.dispose();
    super.dispose();
  }

  void _startProgress() => _progressController.forward(from: 0.0);
  void _pauseProgress() => _progressController.stop();

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
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
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("❌ 참여 실패")),
              );
            }
          } finally {
            if (mounted) _startProgress();
          }
        }
      },
      child: Container(
        width: 134,
        height: 52,
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: 1.5,
              color: story.isSubscribed ? Colors.grey : const Color(0xFFE72410),
            ),
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: Center(
          child: Text(
            story.isSubscribed ? '참여중' : '참여하기',
            style: TextStyle(
              color: story.isSubscribed ? Colors.grey : const Color(0xFFE72410),
              fontSize: 21,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileNotifierProvider);

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
        onTapUp: (_) => _startProgress(),
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
                  final author = ref.read(storyPostProvider.notifier).getAuthor(story.authorId);
                  final isMyStory = user.userProfile?.id == story.authorId;

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        story.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(child: Text('이미지 로드 실패')),
                      ),

                      // ✅ 텍스트 오버레이 추가
                      if (story.textOverlay.text.isNotEmpty)
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

                      if (author != null)
                        Positioned(
                          top: 20,
                          left: 10,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.grey.shade300,
                                backgroundImage: author.profile.isNotEmpty
                                    ? NetworkImage(author.profile)
                                    : null,
                                child: author.profile.isEmpty
                                    ? const Icon(Icons.person, size: 30, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                author.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 4,
                                      color: Colors.black54,
                                      offset: Offset(1, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // 옵션 메뉴
                      Positioned(
                        top: 20,
                        right: 50,
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onSelected: (value) {
                            if (value == 'report') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReportPage(
                                    reportedUserId: story.authorId,
                                    reportedUserName: author?.name ?? '알 수 없음',
                                    reportedUserProfile: author?.profile,
                                  ),
                                ),
                              );
                            } else if (value == 'delete') {
                              showConfirmDialog(
                                context: context,
                                title: "정말 삭제할까요?",
                                description: "삭제된 스토리는 복구할 수 없습니다.",
                                confirmText: "삭제",
                                confirmColor: Colors.redAccent,
                                onConfirm: () async {
                                  final success = await ref
                                      .read(storyPostProvider.notifier)
                                      .deleteStoryPost(story.id);

                                  if (success) {
                                    Navigator.pop(context); // DetailPage 닫기
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("삭제 완료")),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("삭제 실패")),
                                    );
                                  }
                                },
                              );
                            }
                          },
                          itemBuilder: (_) => [
                            if (isMyStory)
                              const PopupMenuItem(value: 'delete', child: Text('삭제하기')),
                            if (!isMyStory)
                              const PopupMenuItem(value: 'report', child: Text('신고하기')),
                          ],
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

                      // 참여 버튼
                      Positioned(
                        bottom: 50,
                        left: 0,
                        right: 0,
                        child: Center(child: _buildParticipateButton(story)),
                      ),
                    ],
                  );
                },
              ),

              // 상단 진행 바
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
                          builder: (_, __) => LinearProgressIndicator(
                            value: index == _currentIndex
                                ? _progressController.value
                                : index < _currentIndex
                                ? 1.0
                                : 0.0,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
