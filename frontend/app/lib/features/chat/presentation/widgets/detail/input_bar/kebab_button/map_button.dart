import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../providers/map_provider.dart';

/// 지도 버튼 (Kebab 메뉴 아이템)
class MapButton extends ConsumerWidget {
  /// 이미 열려있던 UI(오버레이 등)를 닫는 콜백
  final VoidCallback onCloseOverlay;

  const MapButton({
    super.key,
    required this.onCloseOverlay,
  });

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
  const MapModalContent({super.key});

  @override
  ConsumerState<MapModalContent> createState() => _MapModalContentState();
}

class _MapModalContentState extends ConsumerState<MapModalContent> {
  NaverMapController? _mapController;
  bool _isMapReady = false;

  @override
  Widget build(BuildContext context) {
    // (A) circles 목록을 watch 하여, 변경 시 build 재호출
    final circles = ref.watch(mapNotifierProvider);

    return Stack(
      children: [
        // (1) NaverMap
        NaverMap(
          options: const NaverMapViewOptions(
            initialCameraPosition: NCameraPosition(
              target: NLatLng(37.5666102, 126.9783881),
              zoom: 15,
            ),
            scrollGesturesEnable: true,
            zoomGesturesEnable: true,
            rotationGesturesEnable: true,
          ),
          onMapReady: (controller) {
            _mapController = controller;
            _isMapReady = true;
            debugPrint('[MapModalContent] NaverMap 준비 완료');

            // 초기 오버레이 설정
            if (circles.isNotEmpty) {
              controller.addOverlayAll(circles.toSet());
            }
          },
        ),

        // (2) 사용자 아이콘 Row (하단)
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

  /// (B) didUpdateWidget / didChangeDependencies / addPostFrameCallback 등을 통해
  ///     맵 컨트롤러 준비 후 circles 반영
  @override
  void didUpdateWidget(MapModalContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // build 직후 한 프레임 뒤에 오버레이 재설정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateMapOverlays();
    });
  }

  void _updateMapOverlays() {
    if (_isMapReady && _mapController != null) {
      final circles = ref.read(mapNotifierProvider);
      _mapController!.clearOverlays(type: NOverlayType.circleOverlay);
      _mapController!.addOverlayAll(circles.toSet());
      debugPrint('[MapModalContent] 오버레이 갱신 완료. circles=${circles.length}');
    }
  }

  /// 사용자 아이콘 Row (유저별 Circle 클릭 이동)
  Widget _buildUserIcons() {
    // (C) mapNotifier
    final mapNotifier = ref.read(mapNotifierProvider.notifier);
    final userIds = mapNotifier.userIds; // 등록된 userId 목록

    if (userIds.isEmpty) {
      return const Center(child: Text('사용자 없음'));
    }

    // userIds만큼 아이콘
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

  /// 특정 userId로 카메라 이동
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
