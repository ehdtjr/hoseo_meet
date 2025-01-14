import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class MeetDetailFooter extends StatelessWidget {
  final DateTime createdAt;
  final int pageViews;
  final int currentPeople;
  final int maxPeople;
  final bool isSubscribed; // 참여 여부를 나타내는 변수 추가

  const MeetDetailFooter({
    super.key,
    required this.createdAt,
    required this.pageViews,
    required this.currentPeople,
    required this.maxPeople,
    required this.isSubscribed, // 필수 매개변수로 추가
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 334,
      height: 31,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // 작성 시간
          Text(
            _formatTimeDifference(createdAt),
            style: _TextStyles.timestamp,
          ),
          const SizedBox(width: 4),
          // 가운데 점
          Container(
            width: 2,
            height: 2,
            decoration: const BoxDecoration(
              color: Colors.black, // 원 색상
              shape: BoxShape.circle, // 원 모양
            ),
          ),
          const SizedBox(width: 4),
          // 조회수
          Text(
            '조회 $pageViews',
            style: _TextStyles.timestamp,
          ),
          const SizedBox(width: 8),
          // 참여 인원 - 좌측으로 100 이동
          Row(
            children: [
              const SizedBox(width: 100), // 좌측으로 100 이동
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
                    '$currentPeople/$maxPeople',
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
          // 참여하기 버튼 (참여 여부에 따라 동적으로 변경)
          InkWell(
            onTap: isSubscribed
                ? null // 참여 중이면 버튼 동작 비활성화
                : () {
              print('참여하기 클릭됨');
            },
            child: Container(
              width: 95,
              height: 31,
              decoration: BoxDecoration(
                color: isSubscribed
                    ? const Color(0xFFA0A0A0) // 참여 중이면 회색 버튼
                    : const Color(0xFFE72410), // 참여 전이면 빨간 버튼
                borderRadius: BorderRadius.circular(21),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C000000),
                    blurRadius: 7.30,
                    offset: Offset(1, 4),
                    spreadRadius: 0,
                  )
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                isSubscribed ? '참여중' : '참여하기', // 텍스트 동적 변경
                style: isSubscribed
                    ? _TextStyles.subscribedButton // 참여 중 스타일
                    : _TextStyles.joinButton, // 참여 전 스타일
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
