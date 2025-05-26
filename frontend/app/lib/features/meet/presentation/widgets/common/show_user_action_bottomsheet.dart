import 'package:campusmeet/features/auth/data/models/user.dart';
import 'package:flutter/material.dart';


Future<void> showUserActionBottomSheet({
  required BuildContext context,
  required User user,
  required VoidCallback onReport,
  required VoidCallback onBlock,
}) async {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.report, color: Color(0xFFE72410)),
                title: const Text('신고하기', style: TextStyle(color: Color(0xFFE72410))),
                onTap: () {
                  Navigator.pop(context);
                  onReport();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.black87),
                title: const Text('차단하기', style: TextStyle(color: Colors.black87)),
                onTap: () async {
                  await Navigator.of(context).maybePop();
                  onBlock();
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

