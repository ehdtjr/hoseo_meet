import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

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

  // InputBar 위치 계산용
  final GlobalKey _inputBarKey = GlobalKey();

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

    // 아이콘 3개가 inputBar 위에 보이도록 예시 좌표 계산
    final double top = pos.dy - totalHeightApprox;
    final double left = pos.dx + 20;

    _overlayEntry = OverlayEntry(
      builder: (BuildContext context) {
        return Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: _removeOverlay,
            behavior: HitTestBehavior.translucent,
            child: Stack(
              children: [
                // 반투명 배경
                Positioned.fill(
                  child: Container(color: Colors.black45),
                ),

                // 3개 원형 아이콘
                Positioned(
                  left: left,
                  top: top,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // (1) OFF 버튼 -> 지도 모달
                      InkWell(
                        onTap: () {
                          _removeOverlay();
                          _showMapDialog();
                          print('OFF 버튼 탭 → 지도 모달');
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.power_settings_new, color: Colors.white),
                        ),
                      ),
                      // (2) 이모티콘 버튼
                      InkWell(
                        onTap: () {
                          _removeOverlay();
                          print('이모티콘 버튼 탭');
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.emoji_emotions, color: Colors.white),
                        ),
                      ),
                      // (3) 사진 버튼
                      InkWell(
                        onTap: () {
                          _removeOverlay();
                          print('사진 버튼 탭');
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.photo, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// 지도 표시용 Dialog
  void _showMapDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Map',
      barrierColor: Colors.black45,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: SizedBox(
            width: 300,
            height: 400,
            child: Stack(
              children: [
                // (A) 실제 지도 위젯
                Container(
                  color: Colors.blueGrey,
                  child: Center(
                    child: Scaffold(
                      body: NaverMap(
                        options: const NaverMapViewOptions(),
                        onMapReady: (controller) {
                          print('지도 준비 완료');
                        },
                      ),
                    ),
                  ),
                ),

                // (B) 닫기 버튼
                Positioned(
                  top: 8,
                  right: 8,
                  child: InkWell(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
