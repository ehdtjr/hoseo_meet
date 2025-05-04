import 'package:flutter/material.dart';

import 'delete_confirm_dialog.dart';

Future<void> showPostOptionsBottomSheet({
  required BuildContext context,
  required VoidCallback onDelete,
}) async {
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('삭제하기', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.of(context).pop(); // 바텀시트 닫기
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => const DeleteConfirmDialog(
                      title: '정말 삭제할까요?',
                      content: '삭제하면 복구할 수 없습니다.',
                    ),
                  );

                  if (confirm == true) {
                    onDelete();
                  }
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
