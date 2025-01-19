import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

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
                borderRadius: BorderRadius.circular(24), // 각도 24도 곡선
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24), // 내부 콘텐츠도 곡선 적용
                child: const SizedBox(
                  width: 400,
                  height: 530,
                  child: MapModalContent(),
                ),
              ),
            );
          },
        );
      },
      child: SvgPicture.asset(
        'assets/icons/location.svg', // SVG 파일 경로
        width: 54,                  // 아이콘 너비
        height: 54,                 // 아이콘 높이
      ),
    );
  }
}

/// 지도 모달(Dialog 내부 콘텐츠)
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
    // (A) circles 목록을 watch 하여 변경 시 build 재호출
    final circles = ref.watch(mapNotifierProvider);

    return Stack(
      children: [
        // (1) NaverMap
        ClipRRect(
          borderRadius: BorderRadius.circular(24), // 지도 모서리 곡선
          child: NaverMap(
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
        ),

        // (2) 사용자 아이콘 Row (하단)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color: Colors.white.withOpacity(0.8),
            padding: const EdgeInsets.all(10),
            child: _buildUserIcons(),
          ),
        ),
      ],
    );
  }

  /// (B) didUpdateWidget을 통해 맵 컨트롤러 준비 후 circles 반영
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

  /// 사용자 아이콘 Row (유저별 Circle 클릭 이동, 수평 스크롤 추가)
  Widget _buildUserIcons() {
    // (C) mapNotifier
    final mapNotifier = ref.read(mapNotifierProvider.notifier);
    final userIds = mapNotifier.userIds; // 등록된 userId 목록

    if (userIds.isEmpty) {
      return const Center(child: Text('사용자 없음'));
    }

    // userIds만큼 아이콘 생성
    final icons = userIds.map((id) {
      return Padding(
        padding: const EdgeInsets.only(right: 10), // 사용자 간 간격 10 추가
        child: GestureDetector(
          onTap: () => _moveCameraToUser(id),
          child: CircleAvatar(
            backgroundImage: AssetImage('assets/user$id.png'),
            radius: 21, // 아이콘 크기 42x42
          ),
        ),
      );
    }).toList();

    return SizedBox(
      height: 50, // 스크롤 가능한 Row의 높이 (CircleAvatar 크기 + 여백)
      child: ListView(
        scrollDirection: Axis.horizontal, // 가로 스크롤 설정
        children: icons, // 생성된 아이콘 목록 추가
      ),
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
        ),
      );
    }
  }
}
