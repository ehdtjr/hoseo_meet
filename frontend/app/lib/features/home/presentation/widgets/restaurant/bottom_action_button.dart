import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/restaurant/menu/restaurant_menu_provider.dart';


class BottomActionButton extends ConsumerStatefulWidget {
  final int tabIndex;

  const BottomActionButton({super.key, required this.tabIndex});

  @override
  ConsumerState<BottomActionButton> createState() => _BottomActionButtonState();
}

class _BottomActionButtonState extends ConsumerState<BottomActionButton>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tabIndex != 1 && widget.tabIndex != 2) return const SizedBox.shrink();

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
      _buildMiniAction("메뉴 생성하기", () => print("생성하기")),
      _buildMiniAction("메뉴 수정하기", () {
        ref.read(restaurantMenuProvider.notifier).toggleEditMode();
      }),
      _buildMiniAction("메뉴 수정 이력 보기", () => print("이력 보기")),
    ]
        : [
      _buildMiniAction("리뷰 추가하기", () => print("리뷰 추가하기")),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isExpanded)
          ...actions
              .map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: e))
              .toList(),
        FloatingActionButton(
          onPressed: _toggleExpand,
          backgroundColor: Colors.red,
          mini: true,
          child: Icon(_isExpanded ? Icons.close : Icons.add, color: Colors.white),
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
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ),
      ),
    );
  }
}
