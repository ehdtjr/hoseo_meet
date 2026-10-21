import 'package:campusmeet/features/meet/presentation/widgets/common/show_user_action_bottomsheet.dart';
import 'package:campusmeet/features/meet/providers/meet_post_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../commons/services/block_manager.dart';
import '../../../../auth/presentation/pages/report_page.dart';
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
    final userProfile = ref.watch(userProfileNotifierProvider).userProfile;
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
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFBDBDBD),
                  child: const Icon(Icons.person, color: Colors.white, size: 24),
                ),
                loadingBuilder: (_, child, loadingProgress) =>
                loadingProgress == null
                    ? child
                    : const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.grey,
                  ),
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

          // 더보기 버튼
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
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
                      onReport: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReportPage(
                              reportedUserId: post.author.id,
                              reportedUserName: post.author.name,
                              reportedUserProfile: post.author.profile,
                            ),
                          ),
                        );
                      },
                        onBlock: () async {
                          await BlockedUsers.blockUser(post.author.id);

                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          final container = ProviderScope.containerOf(context, listen: false);

                          await Navigator.of(context).maybePop();
                          // SnackBar는 다음 프레임에서 띄움
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('차단되었습니다.'),
                              ),
                            );
                          });
                          await Future.delayed(const Duration(milliseconds: 400));
                          container.read(meetPostProvider.notifier).resetAndLoad();
                        }
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
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
