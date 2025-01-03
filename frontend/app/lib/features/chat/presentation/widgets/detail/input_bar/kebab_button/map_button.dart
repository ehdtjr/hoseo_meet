// file: features/chat/presentation/widgets/input_bar/kebab_button/map_button.dart

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../providers/map_provider.dart';

/// 지도 버튼 (Kebab 메뉴 아이템)
class MapButton extends ConsumerWidget {
  /// 이미 열려있던 UI(오버레이 등)를 닫는 콜백
  final VoidCallback onCloseOverlay;

  const MapButton({
    Key? key,
    required this.onCloseOverlay,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        // (1) 기존 오버레이(UI) 닫기
        onCloseOverlay();

        // (2) 지도 모달(Dialog) 열기
        showDialog(
          context: context,
          barrierDismissible: true,
          barrierColor: Colors.black45,
          builder: (ctx) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: const SizedBox(
                width: 300,
                height: 400,
                child: MapModalContent(),
              ),
            );
          },
        );
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
}

/// 지도 모달(Dialog 내부 컨텐츠)
class MapModalContent extends ConsumerStatefulWidget {
  const MapModalContent({Key? key}) : super(key: key);

  @override
  ConsumerState<MapModalContent> createState() => _MapModalContentState();
}

class _MapModalContentState extends ConsumerState<MapModalContent> {
  NaverMapController? _mapController;
  bool _isMapReady = false;

  // 한 번만 listen 등록을 위한 플래그
  bool _listening = false;

  @override
  Widget build(BuildContext context) {
    // (A) build 시점에서 한 번만 listen 등록
    if (!_listening) {
      _listening = true;

      // mapNotifierProvider 상태(List<NCircleOverlay>)를 listen
      ref.listen<List<NCircleOverlay>>(mapNotifierProvider, (prev, next) {
        // 지도 준비된 상태일 때에만 오버레이 적용
        if (_isMapReady && _mapController != null) {
          // 기존 원(Circle) 지우고
          _mapController!.clearOverlays(type: NOverlayType.circleOverlay);

          // 새 목록을 추가
          _mapController!.addOverlayAll(next.toSet());
        }
      });
    }

    return Stack(
      children: [
        // (1) NaverMap 위젯
        NaverMap(
          options: const NaverMapViewOptions(
            initialCameraPosition: NCameraPosition(
              target: NLatLng(37.5666102, 126.9783881), // 초기 카메라 위치(서울 광화문 근처)
              zoom: 15,
            ),
            scrollGesturesEnable: true,
            zoomGesturesEnable: true,
            rotationGesturesEnable: true,
          ),
          onMapReady: (controller) {
            // 지도 준비 완료
            _mapController = controller;
            _isMapReady = true;
            debugPrint('[MapModalContent] NaverMap 준비 완료');

            // (B) 지도 준비된 후, 기존 state에 이미 있던 overlay 반영
            final circles = ref.read(mapNotifierProvider);
            if (circles.isNotEmpty) {
              controller.addOverlayAll(circles.toSet());
            }
          },
        ),

        // (2) 하단: 사용자 아이콘 Row
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color: Colors.white.withOpacity(0.8),
            padding: const EdgeInsets.all(8),
            child: _buildUserIcons(),
          ),
        ),
      ],
    );
  }

  /// (C) 사용자 아이콘 Row (유저별 Circle 클릭 이동)
  Widget _buildUserIcons() {
    final mapNotifier = ref.read(mapNotifierProvider.notifier);
    final userIds = mapNotifier.userIds; // 등록된 userId 목록

    if (userIds.isEmpty) {
      return const Center(child: Text('사용자 없음'));
    }

    // userIds만큼 아이콘 생성
    final icons = userIds.map((id) {
      return GestureDetector(
        onTap: () => _moveCameraToUser(id),
        child: CircleAvatar(
          // 예시로 user$id.png 이미지 사용 (존재해야 함)
          backgroundImage: AssetImage('assets/user$id.png'),
          radius: 18,
        ),
      );
    }).toList();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: icons,
    );
  }

  /// (D) 특정 userId로 카메라 이동
  void _moveCameraToUser(int userId) {
    final mapNotifier = ref.read(mapNotifierProvider.notifier);
    final userLatLng = mapNotifier.getUserLatLng(userId);

    if (userLatLng == null) {
      debugPrint('[MapModalContent] No location for user=$userId');
      return;
    }
    if (_isMapReady && _mapController != null) {
      debugPrint('[MapModalContent] 카메라 이동 -> user:$userId');
      _mapController!.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: userLatLng,
          zoom: 17,
        )..setAnimation(
          animation: NCameraAnimation.easing,
          duration: const Duration(milliseconds: 500),
        ),
      );
    }
  }
}
