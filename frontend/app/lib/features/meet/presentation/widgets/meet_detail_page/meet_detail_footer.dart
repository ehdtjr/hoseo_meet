import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../providers/meet_post_provider.dart';

class MeetDetailFooter extends ConsumerWidget {
  final int postId; // 게시글 ID만 전달

  const MeetDetailFooter({
    super.key,
    required this.postId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // postId와 연결된 상태를 가져옴
    final post = ref.watch(meetPostProvider).firstWhere((p) => p.id == postId);

    // 상태 값을 사용
    final bool isFull = post.currentPeople >= post.maxPeople; // 정원이 가득 찼는지 확인
    final bool isSubscribed = post.isSubscribed; // 이미 참여 중인지 확인
    final bool isButtonDisabled = isSubscribed || isFull; // 버튼 비활성화 조건

    return SizedBox(
      width: 334,
      height: 31,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // 작성 시간
          Text(
            _formatTimeDifference(post.createdAt),
            style: _TextStyles.timestamp,
          ),
          const SizedBox(width: 4),
          // 가운데 점
          Container(
            width: 2,
            height: 2,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          // 조회수
          Text(
            '조회 ${post.pageViews}',
            style: _TextStyles.timestamp,
          ),
          const SizedBox(width: 8),
          // 참여 인원
          Row(
            children: [
              const SizedBox(width: 100),
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
          const Spacer(),
          // 참여하기 버튼
          InkWell(
            onTap: isButtonDisabled
                ? null // 참여 중이거나 정원이 가득 찬 경우 버튼 비활성화
                : () async {
              try {
                final notifier = ref.read(meetPostProvider.notifier);
                await notifier.subscribeToPost(postId); // 서버 요청
              } catch (e) {
                _showErrorDialog(context, '참여 요청 중 오류가 발생했습니다.');
              }
            },
            child: Container(
              width: 95,
              height: 31,
              decoration: BoxDecoration(
                color: isButtonDisabled
                    ? const Color(0xFFA0A0A0) // 비활성화 시 회색
                    : const Color(0xFFE72410), // 활성화 시 빨강
                borderRadius: BorderRadius.circular(21),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C000000),
                    blurRadius: 7.30,
                    offset: Offset(1, 4),
                    spreadRadius: 0,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                isFull
                    ? '인원초과' // 정원이 가득 찬 경우 텍스트
                    : isSubscribed
                    ? '참여중' // 이미 참여 중인 경우 텍스트
                    : '참여하기', // 기본 텍스트
                style: isButtonDisabled
                    ? _TextStyles.subscribedButton // 비활성화 텍스트 스타일
                    : _TextStyles.joinButton, // 활성화 텍스트 스타일
              ),
            ),
          ),
        ],
      ),
    );
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

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
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
}

class _TextStyles {
  static const TextStyle timestamp = TextStyle(
    color: Color(0xFF707070),
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle joinButton = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle subscribedButton = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );
}
