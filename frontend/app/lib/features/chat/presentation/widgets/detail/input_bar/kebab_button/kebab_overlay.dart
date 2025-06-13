import 'package:flutter/material.dart';
import '../../../../../data/models/chat_room.dart';
import 'map_button.dart';

class KebabOverlay extends StatelessWidget {
  final LayerLink layerLink;
  final VoidCallback onTapOutside;
  final ChatRoom chatRoom;

  const KebabOverlay({
    super.key,
    required this.layerLink,
    required this.onTapOutside,
    required this.chatRoom,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 바깥 탭 시 오버레이 제거
        Positioned.fill(
          child: GestureDetector(
            onTap: onTapOutside,
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.black45),
          ),
        ),

        // 오버레이 내용 (버튼들)
        CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, -100), // 버튼 기준으로 위쪽에 위치
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MapButton(
                  chatRoom: chatRoom,
                  onCloseOverlay: onTapOutside,
                ),
                const SizedBox(height: 15),
                // 추가 버튼들 여기에
              ],
            ),
          ),
        ),
      ],
    );
  }
}
