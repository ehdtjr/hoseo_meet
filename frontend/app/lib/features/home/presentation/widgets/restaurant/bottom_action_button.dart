import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../widgets/showConfirmDialog.dart';
import '../../../../auth/presentation/pages/report_page.dart';
import '../../../../auth/providers/user_profile_provider.dart';
import '../../../providers/restaurant/menu/restaurant_menu_provider.dart';
import '../../pages/restaurant/create_menu_page.dart';
import 'bottom/menu_history_bottom_sheet.dart';

class BottomActionButton extends ConsumerStatefulWidget {
  final int tabIndex;
  final int postId;

  const BottomActionButton({
    super.key,
    required this.tabIndex,
    required this.postId,
  });

  @override
  ConsumerState<BottomActionButton> createState() => _BottomActionButtonState();
}

class _BottomActionButtonState extends ConsumerState<BottomActionButton> {
  bool _isExpanded = false;

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tabIndex != 1 && widget.tabIndex != 2) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 20,
      right: 20,
      child: _buildExpandable(),
    );
  }

  Widget _buildExpandable() {
    final isMenuTab = widget.tabIndex == 1;

    final actions = isMenuTab
        ? [
      _buildMiniAction(
        "메뉴 생성하기",
            () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MenuCreatePage(postId: widget.postId),
            ),
          );
        },
      ),
      _buildMiniAction(
        "메뉴 수정하기",
            () {
          ref.read(restaurantMenuProvider.notifier).toggleEditMode();
        },
      ),
      _buildMiniAction(
        "메뉴 수정 이력 보기",
            () async {
          // 사용자 이름 불러오기 예시
          final versions = await ref
              .read(restaurantMenuProvider.notifier)
              .loadMenuVersions(widget.postId, skip: 0, limit: 20);

          final editorIds = versions.map((v) => v.editorId).toSet();
          final userService = ref.read(userServiceProvider);
          final Map<int, String> editorNames = {};

          for (final id in editorIds) {
            try {
              final user = await userService.getUser(id);
              editorNames[id] = user.name;
            } catch (e) {
              editorNames[id] = '사용자 $id';
            }
          }

          if (!context.mounted) return;

          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => MenuHistoryBottomSheet(
              fetchVersions: ({required int skip, required int limit}) {
                return ref
                    .read(restaurantMenuProvider.notifier)
                    .loadMenuVersions(
                  widget.postId,
                  skip: skip,
                  limit: limit,
                );
              },
              editorNames: editorNames,
              onTapEditor: (userId, userName) async {
                final userService = ref.read(userServiceProvider);
                final user = await userService.getUser(userId);
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportPage(
                      reportedUserId: user.id,
                      reportedUserName: userName.isNotEmpty ? userName : user.name,
                      reportedUserProfile: user.profile,
                    ),
                  ),
                );
              },
              onRestore: (version) async {
                await showConfirmDialog(
                  context: context,
                  title: '이전 메뉴 버전으로 되돌리기',
                  description: '선택한 메뉴 버전으로 복원할까요?',
                  confirmText: '되돌리기',
                  onConfirm: () async {
                    await ref.read(restaurantMenuProvider.notifier).rollbackMenuInState(
                      menuVersionId: version.version,
                      postId: widget.postId,
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('메뉴가 이전 버전으로 복원되었습니다.')),
                      );
                      Navigator.of(context).pop();
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    ]
        : [
      _buildMiniAction("리뷰 추가하기", () {
        print("리뷰 추가하기");
      }),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isExpanded)
          ...actions
              .map(
                (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: e,
            ),
          )
              .toList(),
        FloatingActionButton(
          onPressed: _toggleExpand,
          backgroundColor: Colors.red,
          mini: true,
          child: Icon(
            _isExpanded ? Icons.close : Icons.add,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniAction(String label, VoidCallback onPressed) {
    return Material(
      color: Colors.red,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () {
          onPressed();
          setState(() => _isExpanded = false);
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
