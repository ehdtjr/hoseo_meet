import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/data/models/user.dart';
import '../../../../auth/presentation/pages/report_page.dart';
import '../../../../auth/providers/user_profile_provider.dart'; // 현재 유저 정보용 추가
import '../../../data/models/chat_room.dart';
import '../../../providers/chat_detail_provider.dart';
import '../../../providers/chat_room_provicer.dart';

class ChatSlideMenu extends ConsumerWidget {
  final ChatRoom chatRoom;

  const ChatSlideMenu({
    super.key,
    required this.chatRoom,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(chatDetailNotifierProvider(chatRoom));
    final currentUser = ref.watch(userProfileNotifierProvider).userProfile;
    final List<User> participants = detailState.participants;

    final double menuWidth = MediaQuery.of(context).size.width * 0.7;

    return Align(
      alignment: Alignment.centerRight,
      child: SafeArea(
        child: Material(
          elevation: 6,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            bottomLeft: Radius.circular(24),
          ),
          color: const Color(0xFFF9F9F9),
          child: SizedBox(
            width: menuWidth,
            height: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '참여자 목록',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: ListView.separated(
                      itemCount: participants.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final user = participants[index];
                        final bool isSelf = currentUser?.id == user.id;
                        final String? profileUrl = user.profile;
                        final bool hasProfile = profileUrl != null &&
                            profileUrl.isNotEmpty &&
                            Uri.tryParse(profileUrl)?.hasAbsolutePath == true;

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundImage:
                            hasProfile ? NetworkImage(profileUrl) : null,
                            backgroundColor: Colors.grey.shade300,
                            child: hasProfile
                                ? null
                                : const Icon(Icons.person, color: Colors.white),
                          ),
                          title: Row(
                            children: [
                              Text(user.name),
                              if (isSelf)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Text(
                                    "(나)",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: isSelf
                              ? null
                              : PopupMenuButton<String>(
                            color: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            onSelected: (value) {
                              Navigator.pop(context); // 슬라이드 닫기
                              if (value == 'report') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ReportPage(
                                      reportedUserName: user.name,
                                      reportedUserId: user.id,
                                      reportedUserProfile: user.profile,
                                    ),
                                  ),
                                );
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'report',
                                child: Text(
                                  '신고하기',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 30),
                  const Divider(),

                  // 채팅방 나가기 버튼
                  ListTile(
                    leading: const Icon(Icons.exit_to_app, color: Colors.red),
                    title: const Text(
                      '채팅방 나가기',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      final chatRoomNotifier =
                      ref.read(chatRoomNotifierProvider.notifier);

                      try {
                        await chatRoomNotifier.unsubscribe(chatRoom.streamId);
                        Navigator.pop(context); // 슬라이드 닫기
                        Navigator.pop(context); // 이전 페이지로
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('채팅방에서 나갔습니다.')),
                        );
                      } catch (e) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('채팅방 나가기 실패 😢')),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
