import 'package:campusmeet/features/meet/presentation/widgets/common/show_user_action_bottomsheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../auth/providers/user_profile_provider.dart';
import '../../../data/models/meet_post_detail.dart';
import '../common/show_post_option_bottomsheet.dart';

class MeetAuthorSection extends ConsumerWidget {
  final MeetDetail post;
  final VoidCallback onDelete;

  const MeetAuthorSection({
    super.key,
    required this.post,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref
        .watch(userProfileNotifierProvider)
        .userProfile;
    final isAuthor = userProfile?.id == post.author.id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Row(
        children: [
          // 프로필 이미지
          Container(
            width: 45,
            height: 45,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFBDBDBD),
            ),
            child: ClipOval(
              child: Image.network(
                post.author.profile,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(
                      color: const Color(0xFFBDBDBD),
                      child: const Icon(
                          Icons.person, color: Colors.white, size: 24),
                    ),
                loadingBuilder: (_, child, loadingProgress) =>
                loadingProgress == null
                    ? child
                    : const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.grey,
                    )
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          // 이름과 태그
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTag(post.type),
              const SizedBox(height: 3),
              Text(post.author.name, style: _TextStyles.authorName),
            ],
          ),
          const Spacer(),

          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                if (isAuthor) {
                  showPostOptionsBottomSheet(
                    context: context,
                    onDelete: onDelete,
                  );
                } else {
                  showUserActionBottomSheet(
                      context: context,
                      user: post.author,
                      ref: ref
                  );
                }
              },
              child: SvgPicture.asset(
                'assets/icons/fi-rr-menu-dots-vertical.svg',
                width: 18,
                colorFilter: const ColorFilter.mode(
                  Color(0xFFE72410),
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
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
      child: Text(_getTypeDisplay(type), style: _TextStyles.redTag),
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
  static const redTag = TextStyle(
    color: Color(0xFFE72410),
    fontSize: 10,
    fontWeight: FontWeight.w500,
  );

  static const authorName = TextStyle(
    color: Colors.black,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
}
