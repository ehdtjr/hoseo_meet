import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../../auth/data/models/user.dart';
import '../../../../../data/models/chat_room.dart';
import '../../../../../providers/chat_detail_provider.dart';
import '../../../../../providers/map_provider.dart';

class MapButton extends ConsumerWidget {
  final VoidCallback onCloseOverlay;
  final ChatRoom chatRoom;

  const MapButton({
    super.key,
    required this.onCloseOverlay,
    required this.chatRoom,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        onCloseOverlay();
        showDialog(
          context: context,
          barrierDismissible: true,
          barrierColor: Colors.black45,
          builder: (ctx) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  width: 400,
                  height: 530,
                  child: MapModalContent(chatRoom: chatRoom),
                ),
              ),
            );
          },
        );
      },
      child: SvgPicture.asset(
        'assets/icons/location.svg',
        width: 54,
        height: 54,
      ),
    );
  }
}

class MapModalContent extends ConsumerStatefulWidget {
  final ChatRoom chatRoom;
  const MapModalContent({super.key, required this.chatRoom});

  @override
  ConsumerState<MapModalContent> createState() => _MapModalContentState();
}

class _MapModalContentState extends ConsumerState<MapModalContent> {
  NaverMapController? _mapController;
  bool _isMapReady = false;
  final List<NMarker> _userMarkers = [];

  @override
  Widget build(BuildContext context) {
    final positions = ref.watch(mapNotifierProvider);

    if (_isMapReady && _mapController != null) {
      _updateUserMarkers(context, positions);
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
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
            onMapReady: (controller) async {
              _mapController = controller;
              _isMapReady = true;
              await _updateUserMarkers(context, positions);
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color: Colors.white.withOpacity(0.8),
            padding: const EdgeInsets.all(10),
            child: _buildUserIcons(positions),
          ),
        ),
      ],
    );
  }

  Future<void> _updateUserMarkers(BuildContext context, Map<int, NLatLng> positions) async {
    if (_mapController == null) return;

    await _mapController!.clearOverlays();
    _userMarkers.clear();

    final chatDetail = ref.read(chatDetailNotifierProvider(widget.chatRoom));
    final participants = chatDetail.participants;
    final markers = <NMarker>[];

    for (final user in participants) {
      final userId = user.id;
      final latLng = positions[userId];
      if (latLng == null) continue;

      final overlayImage = await NOverlayImage.fromWidget(
        widget: _buildProfileWidget(user),
        size: const Size(60, 80),
        context: context,
      );

      markers.add(NMarker(
        id: 'user_$userId',
        position: latLng,
        icon: overlayImage,
      ));
    }

    _userMarkers.addAll(markers);
    await _mapController!.addOverlayAll(_userMarkers.toSet());
  }

  Widget _buildProfileWidget(User user) {
    final profileUrl = user.profile?.trim();
    final hasValidProfile = profileUrl != null &&
        profileUrl.isNotEmpty &&
        profileUrl != 'default_profile' &&
        Uri.tryParse(profileUrl)?.hasAbsolutePath == true;

    return SizedBox(
      width: 70,
      height: 90,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 70),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              user.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade300,
              image: hasValidProfile
                  ? DecorationImage(
                image: NetworkImage(profileUrl!),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child: hasValidProfile
                ? null
                : const Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildUserIcons(Map<int, NLatLng> positions) {
    final chatDetail = ref.watch(chatDetailNotifierProvider(widget.chatRoom));
    final participants = chatDetail.participants;

    // 위치 정보가 있는 유저만 필터링 (접속 중인 유저)
    final onlineUsers = participants.where((user) => positions.containsKey(user.id)).toList();

    if (onlineUsers.isEmpty) {
      return const SizedBox(
        height: 50,
        child: Center(child: Text('접속 중인 유저 없음')),
      );
    }

    final icons = onlineUsers.map((user) {
      final profileUrl = user.profile?.trim();
      final hasValidProfile = profileUrl != null &&
          profileUrl.isNotEmpty &&
          profileUrl != 'default_profile' &&
          Uri.tryParse(profileUrl)?.hasAbsolutePath == true;

      return Padding(
        padding: const EdgeInsets.only(right: 10),
        child: GestureDetector(
          onTap: () => _moveCameraToUser(user.id),
          child: CircleAvatar(
            radius: 21,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: hasValidProfile ? NetworkImage(profileUrl!) : null,
            child: hasValidProfile
                ? null
                : const Icon(Icons.person, color: Colors.white),
          ),
        ),
      );
    }).toList();

    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: icons,
      ),
    );
  }


  void _moveCameraToUser(int userId) {
    final positions = ref.read(mapNotifierProvider);
    final userLatLng = positions[userId];

    if (_isMapReady && _mapController != null && userLatLng != null) {
      _mapController!.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: userLatLng,
          zoom: 17,
        ),
      );
    }
  }
}
