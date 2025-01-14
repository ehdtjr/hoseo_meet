import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../data/models/meet_post_detail.dart';

class MeetAuthorSection extends StatelessWidget {
  final MeetDetail post;

  const MeetAuthorSection({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5), // 좌우 5px 패딩
      child: Row(
        children: [
// 작성자 프로필 이미지
          Container(
            width: 45,
            height: 45,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFBDBDBD), // 기본 회색 배경
            ),
            child: ClipOval(
              child: Image.network(
                post.author.profile,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFFBDBDBD), // 이미지가 없을 때 회색 원
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 24,
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child; // 로딩이 끝나면 이미지 표시
                  }
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.grey,
                    ),
                  ); // 로딩 중일 때 표시
                },
              ),
            ),
          ),

          const SizedBox(width: 15),
          // 작성자 이름과 태그
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTag(post.type), // 타입 태그
              const SizedBox(height: 3),
              Text(
                post.author.name,
                style: _TextStyles.authorName,
              ),
            ],
          ),
          const Spacer(),
          // 더보기 버튼
          Padding(
            padding: const EdgeInsets.only(right: 15), // 우측 15px 패딩
            child: SvgPicture.asset(
              'assets/icons/fi-rr-menu-dots-vertical.svg',
              width: 14,
              colorFilter: const ColorFilter.mode(
                Color(0xFFE72410),
                BlendMode.srcIn,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTag(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(width: 1, color: const Color(0xFFE72410)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _getTypeDisplay(type),
        style: _TextStyles.redTag,
      ),
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
}

class _TextStyles {
  static const TextStyle redTag = TextStyle(
    color: Color(0xFFE72410),
    fontSize: 10,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle authorName = TextStyle(
    color: Colors.black,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
}
