import 'package:campusmeet/features/auth/data/models/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../commons/services/block_manager.dart';
import '../../../../auth/presentation/pages/report_page.dart';
import '../../../providers/meet_post_provider.dart';

Future<void> showUserActionBottomSheet({
  required BuildContext context,
  required WidgetRef ref, // ✅ ref 추가
  required User user
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportPage(
                        reportedUserId: user.id,
                        reportedUserName: user.name,
                        reportedUserProfile: user.profile,
                      ),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.black87),
                title: const Text('차단하기', style: TextStyle(color: Colors.black87)),
                onTap: () async {
                  Navigator.pop(context);
                  await BlockedUsers.blockUser(user.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${user.name} 님을 차단했습니다.')),
                  );
                  ref.read(meetPostProvider.notifier).resetAndLoad();
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
