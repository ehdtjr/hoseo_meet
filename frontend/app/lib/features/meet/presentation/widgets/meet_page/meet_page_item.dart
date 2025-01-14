import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../data/models/meet_post.dart';
import '../../../providers/meet_post_provider.dart';
import '../meet_detail_page/meet_detail_modal.dart';

class MeetPageItem extends ConsumerWidget {
  final MeetPost post;

  const MeetPageItem({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showDetailModal(context, ref), // 아이템 클릭 시 모달 호출
      child: Container(
        padding: const EdgeInsets.only(
          top: 18.0,
          left: 20.0,
          right: 20.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            width: 1,
                            color: const Color(0xFFE72410),
                          ),
                        ),
                        child: Text(
                          _getTypeDisplay(post.type),
                          style: _TextStyles.redTag,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        post.author.name,
                        style: _TextStyles.authorName,
                      ),
                      const Spacer(),
                      SvgPicture.asset(
                        'assets/icons/fi-rr-menu-dots-vertical.svg',
                        width: 18,
                        height: 18,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFF707070),
                          BlendMode.srcIn,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post.title,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    post.shortContent.isNotEmpty ? post.shortContent : '',
                    style: _TextStyles.content,
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            _formatTimeDifference(post.createdAt),
                            style: const TextStyle(
                              color: Color(0xFF707070),
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 2,
                            height: 2,
                            decoration: const BoxDecoration(
                              color: Color(0xFF707070),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '조회수 ${post.pageViews}',
                            style: const TextStyle(
                              color: Color(0xFF707070),
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          SvgPicture.asset(
                            'assets/icons/fi-rr-user.svg',
                            width: 14,
                            height: 14,
                            colorFilter: const ColorFilter.mode(
                              Color(0xFF707070),
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${post.currentPeople}/${post.maxPeople}',
                            style: const TextStyle(
                              color: Color(0xFF707070),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 13),
            const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFF0B4AD),
            ),
          ],
        ),
      ),
    );
  }

  /// 상세 정보 모달을 보여주는 함수
  void _showDetailModal(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(meetPostProvider.notifier);

    // 로딩 인디케이터 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final meetDetail = await notifier.loadDetailMeetPost(post.id);

      Navigator.of(context).pop(); // 로딩 인디케이터 닫기

      if (meetDetail != null) {
        // 상세 정보 모달 표시
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              backgroundColor: Colors.white,
              child: MeetDetailModal(post: meetDetail),
            );
          },
        );
      } else {
        _showErrorDialog(context, '상세 정보를 불러오지 못했습니다.');
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showErrorDialog(context, '상세 정보를 불러오는 중 오류가 발생했습니다.');
    }
  }

  /// 오류 메시지를 다이얼로그로 표시하는 함수
  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('오류'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  String _getTypeDisplay(String type) {
    const typeMap = {
      'meet': '모임',
      'delivery': '배달',
      'taxi': '카풀',
    };

    return typeMap[type.toLowerCase()] ?? '전체';
  }

  String _formatTimeDifference(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else {
      return '${difference.inDays}일 전';
    }
  }
}

class _TextStyles {
  static const TextStyle redTag = TextStyle(
    color: Color(0xFFE72410),
    fontSize: 10,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle authorName = TextStyle(
    color: Color(0xFF707070),
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle content = TextStyle(
    color: Color(0xFF707070),
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
}
