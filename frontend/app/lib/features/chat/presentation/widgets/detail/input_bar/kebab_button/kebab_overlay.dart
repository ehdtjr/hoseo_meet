import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
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
    super.key,
    required this.left,
    required this.top,
    required this.onTapOutside,
    required this.onTapEmoticonButton,
    required this.onTapPhotoButton,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent, // 오버레이 배경 투명
      child: GestureDetector(
        onTap: onTapOutside, // 바깥을 탭하면 오버레이 닫기
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
              bottom: 90, // 최하단 기준으로 100px 위
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // (1) 지도 버튼
                  MapButton(
                    onCloseOverlay: onTapOutside,
                  ),

                  const SizedBox(height: 15), // 버튼 간격 추가

                  // (2) 이모티콘 버튼
                  InkWell(
                    onTap: () {
                      onTapOutside(); // 먼저 오버레이 닫고
                      onTapEmoticonButton(); // 이모티콘 로직
                      debugPrint('이모티콘 버튼 탭');
                    },
                    child: SvgPicture.asset(
                      'assets/icons/camera.svg', // SVG 파일 경로
                      width: 54, // 아이콘 너비
                      height: 54, // 아이콘 높이
                    ),
                  ),

                  const SizedBox(height: 15), // 버튼 간격 추가

                  // (3) 사진 버튼
                  InkWell(
                    onTap: () {
                      onTapOutside(); // 먼저 오버레이 닫고
                      onTapPhotoButton(); // 사진 선택 로직
                      debugPrint('사진 버튼 탭');
                    },
                    child: SvgPicture.asset(
                      'assets/icons/image.svg', // SVG 파일 경로
                      width: 54, // 아이콘 너비
                      height: 54, // 아이콘 높이
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
