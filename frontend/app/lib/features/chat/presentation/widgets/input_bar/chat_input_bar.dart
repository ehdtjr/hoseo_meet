import 'package:flutter/material.dart';

import 'kebab_button/kebab_overlay.dart';

class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final double height;

  const ChatInputBar({
    Key? key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    this.height = 72,
  }) : super(key: key);

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  OverlayEntry? _overlayEntry;
  final GlobalKey _inputBarKey = GlobalKey(); // 입력 바 위치 계산용

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _inputBarKey,
      width: double.infinity,
      height: widget.height,
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 19),

          // 케밥 아이콘
          SizedBox(
            width: 24,
            height: 24,
            child: InkWell(
              onTap: _toggleKebabOverlay,
              child: const Icon(Icons.more_vert, color: Colors.red),
            ),
          ),

          const SizedBox(width: 10),

          // 메시지 입력부
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color.fromRGBO(236, 236, 236, 1),
                borderRadius: BorderRadius.circular(115),
              ),
              child: TextField(
                focusNode: widget.focusNode,
                controller: widget.controller,
                decoration: const InputDecoration(
                  hintText: '메시지를 입력하세요...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 15,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // 전송 버튼
          InkWell(
            onTap: widget.onSend,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: const Color.fromRGBO(231, 36, 16, 1),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_upward,
                  color: Colors.red,
                  size: 18,
                ),
              ),
            ),
          ),

          const SizedBox(width: 19),
        ],
      ),
    );
  }

  void _toggleKebabOverlay() {
    if (_overlayEntry == null) {
      _showKebabOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showKebabOverlay() {
    final box = _inputBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final Offset pos = box.localToGlobal(Offset.zero);
    const double totalHeightApprox = 160;
    final double top = pos.dy - totalHeightApprox;
    final double left = pos.dx + 20;

    _overlayEntry = OverlayEntry(
      builder: (BuildContext context) {
        return KebabOverlay(
          left: left,
          top: top,
          onTapOutside: _removeOverlay,
          onTapEmoticonButton: () {
            print('이모티콘 버튼 탭 → 여기서 원하는 로직');
          },
          onTapPhotoButton: () {
            print('사진 버튼 탭 → 여기서 원하는 로직');
          },
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}
