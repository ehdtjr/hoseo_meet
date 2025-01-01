import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

/// 지도 모달 열기 버튼
class MapButton extends StatelessWidget {
  /// 오버레이 닫는 콜백
  final VoidCallback onCloseOverlay;

  const MapButton({
    Key? key,
    required this.onCloseOverlay,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // (1) 다른 오버레이(UI) 먼저 닫기
        onCloseOverlay();

        // (2) 지도 모달 열기
        _showMapDialog(context);

        print('Map 버튼 탭 → 지도 모달');
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.map, color: Colors.white),
      ),
    );
  }

  /// 지도 표시용 Dialog
  void _showMapDialog(BuildContext context) {
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
                // (A) 실제 지도
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
