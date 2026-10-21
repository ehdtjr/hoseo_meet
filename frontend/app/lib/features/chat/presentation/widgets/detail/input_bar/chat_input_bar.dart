import 'package:flutter/material.dart';
import '../../../../data/models/chat_room.dart';
import 'kebab_button/kebab_overlay.dart';

class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final double height;
  final ChatRoom chatRoom;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.chatRoom,
    this.height = 72,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink(); // 케밥 위치 추적용
  bool _isSendButtonPressed = false;
  bool _isKebabPressed = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: widget.height,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.red, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 19),

          /// 케밥 버튼 - 위치 추적용 타겟
          CompositedTransformTarget(
            link: _layerLink,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _isKebabPressed = true),
              onTapUp: (_) {
                setState(() => _isKebabPressed = false);
                _toggleKebabOverlay();
              },
              onTapCancel: () => setState(() => _isKebabPressed = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: _isKebabPressed
                      ? [
                    const BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      spreadRadius: 2,
                      offset: Offset(0, 4),
                    ),
                  ]
                      : [],
                ),
                child: const Center(
                  child: Icon(Icons.more_vert, color: Colors.red),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

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

          GestureDetector(
            onTapDown: (_) => setState(() => _isSendButtonPressed = true),
            onTapUp: (_) {
              setState(() => _isSendButtonPressed = false);
              widget.onSend();
            },
            onTapCancel: () => setState(() => _isSendButtonPressed = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: const Color.fromRGBO(231, 36, 16, 1),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(40),
                boxShadow: _isSendButtonPressed
                    ? [
                  const BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: Offset(0, 4),
                  ),
                ]
                    : [],
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
    _overlayEntry = OverlayEntry(
      builder: (BuildContext context) {
        return KebabOverlay(
          layerLink: _layerLink,
          onTapOutside: _removeOverlay,
          chatRoom: widget.chatRoom,
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
