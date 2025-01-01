// features/chat/presentation/widgets/input_bar/kebab_button/map_button.dart

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 외부에서 import한 mapNotifierProvider
import '../../../../providers/map_provider.dart';

/// 지도 버튼
class MapButton extends ConsumerWidget {
  /// 이미 열려있던 UI(오버레이 등) 닫는 콜백
  final VoidCallback onCloseOverlay;

  const MapButton({
    Key? key,
    required this.onCloseOverlay,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        // (1) 기존 UI 닫기
        onCloseOverlay();

        // (2) 지도 모달 열기
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

/// 지도 모달
class MapModalContent extends ConsumerStatefulWidget {
  const MapModalContent({Key? key}) : super(key: key);

  @override
  ConsumerState<MapModalContent> createState() => _MapModalContentState();
}

class _MapModalContentState extends ConsumerState<MapModalContent> {
  NaverMapController? _mapController;
  bool _isMapReady = false;

  // ref.listen 중복 등록 방지용
  bool _listening = false;

  @override
  Widget build(BuildContext context) {
    // (A) build 시점에서 한 번만 listen 등록
    if (!_listening) {
      _listening = true;
      ref.listen<List<NCircleOverlay>>(mapNotifierProvider, (prev, next) {
        // 지도 준비된 상태라면
        if (_isMapReady && _mapController != null) {
          // 1) 기존 오버레이(원) 지우고
          _mapController!.clearOverlays(type: NOverlayType.circleOverlay);
          // 2) 새 목록 추가
          _mapController!.addOverlayAll(next.toSet());
        }
      });
    }

    return Stack(
      children: [
        // 1) NaverMap
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

            // 초기 목록이 있으면 추가
            final circles = ref.read(mapNotifierProvider);
            if (circles.isNotEmpty) {
              controller.addOverlayAll(circles.toSet());
            }
          },
        ),

        // 2) 닫기 버튼
        Positioned(
          top: 8,
          right: 8,
          child: InkWell(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, color: Colors.black),
          ),
        ),

        // 3) 상단 안내 문구
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.white.withOpacity(0.8),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Center(
              child: Text(
                '배달로 때문에 같이 주문하실 분?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),

        // 4) 하단 사용자 아이콘들 (동적 생성)
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

  /// (B) 사용자 아이콘 Row 동적 생성
  Widget _buildUserIcons() {
    final mapNotifier = ref.read(mapNotifierProvider.notifier);
    final userIds = mapNotifier.userIds; // 현재 등록된 userId들

    if (userIds.isEmpty) {
      return const Center(child: Text('사용자 없음'));
    }

    // userIds만큼 아이콘
    final icons = userIds.map((id) {
      return GestureDetector(
        onTap: () => _moveCameraToUser(id),
        child: CircleAvatar(
          backgroundImage: AssetImage('assets/user$id.png'),
          // ↑ user$id.png가 실제 존재해야 함 (e.g. user1.png, user2.png etc.)
          radius: 18,
        ),
      );
    }).toList();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: icons,
    );
  }

  /// (C) 특정 userId의 위치로 카메라 이동
  void _moveCameraToUser(int userId) {
    final mapNotifier = ref.read(mapNotifierProvider.notifier);
    final userLatLng = mapNotifier.getUserLatLng(userId);

    if (userLatLng == null) {
      debugPrint('No location for user=$userId');
      return;
    }
    if (_isMapReady && _mapController != null) {
      debugPrint('카메라 이동 -> user:$userId');
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
