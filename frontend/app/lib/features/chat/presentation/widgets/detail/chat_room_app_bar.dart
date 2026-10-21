import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../data/models/chat_room.dart';
import 'chat_room_slide.dart';

class ChatRoomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ChatRoom chatRoom;

  const ChatRoomAppBar({
    super.key,
    required this.chatRoom,
  });

  void _openRightSlideMenu(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "닫기",
      barrierColor: Colors.black.withOpacity(0.3),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox(),
      transitionBuilder: (_, animation, __, ___) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic));

        return SlideTransition(
          position: offsetAnimation,
          child: ChatSlideMenu(chatRoom: chatRoom), // ChatRoom 전달
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        chatRoom.name.isEmpty ? 'No Title' : chatRoom.name,
      ),
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.red),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1.0),
        child: Divider(color: Colors.red, thickness: 1.0),
      ),
      actions: [
        IconButton(
          icon: SvgPicture.asset(
            'assets/icons/fi-rr-menu-burger.svg',
            width: 18,
            height: 18,
          ),
          onPressed: () => _openRightSlideMenu(context),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
