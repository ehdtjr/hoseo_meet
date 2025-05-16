import 'package:flutter/material.dart';
import '../../../../../widgets/showConfirmDialog.dart';

Future<void> showPostOptionsBottomSheet({
  required BuildContext context,
  required VoidCallback onDelete,
}) async {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white, // ✅ 흰 바탕 명시
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

                  await showConfirmDialog(
                    context: context,
                    title: '정말 삭제할까요?',
                    description: '삭제하면 복구할 수 없습니다.',
                    confirmText: '삭제',
                    confirmColor: Colors.redAccent,
                    onConfirm: onDelete,
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
