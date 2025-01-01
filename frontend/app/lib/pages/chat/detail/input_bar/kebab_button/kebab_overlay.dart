// kebab_overlay.dart
import 'package:flutter/material.dart';
import 'map_button.dart';

class KebabOverlay extends StatelessWidget {
  final double left;
  final double top;

  /// 바깥 영역 탭 시 실행되는 콜백
  final VoidCallback onTapOutside;

  /// 이모티콘 버튼 콜백
  final VoidCallback onTapEmoticonButton;

  /// 사진 버튼 콜백
  final VoidCallback onTapPhotoButton;

  const KebabOverlay({
    Key? key,
    required this.left,
    required this.top,
    required this.onTapOutside,
    required this.onTapEmoticonButton,
    required this.onTapPhotoButton,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent, // 오버레이 배경 투명
      child: GestureDetector(
        onTap: onTapOutside,      // 바깥을 탭하면 오버레이 닫기
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // 반투명 배경
            Positioned.fill(
              child: Container(color: Colors.black45),
            ),

            // 3개 버튼 배치
            Positioned(
              left: left,
              top: top,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // (1) 지도 버튼
                  MapButton(
                    onCloseOverlay: onTapOutside,
                  ),

                  // (2) 이모티콘 버튼
                  InkWell(
                    onTap: () {
                      onTapOutside();        // 먼저 오버레이 닫고
                      onTapEmoticonButton(); // 이모티콘 로직
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
                      onTapOutside();       // 먼저 오버레이 닫고
                      onTapPhotoButton();   // 사진 선택 로직
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
  }
}
