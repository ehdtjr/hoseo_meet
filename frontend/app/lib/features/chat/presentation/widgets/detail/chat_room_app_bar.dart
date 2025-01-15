import 'package:flutter/material.dart';

class ChatRoomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String chatRoomName;

  const ChatRoomAppBar({
    super.key,
    required this.chatRoomName,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        chatRoomName.isEmpty ? 'No Title' : chatRoomName,
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
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
