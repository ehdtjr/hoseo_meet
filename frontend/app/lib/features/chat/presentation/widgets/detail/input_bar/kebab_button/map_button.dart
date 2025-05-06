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
              await _addUserMarkers(context);
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
            child: _buildUserIcons(),
          ),
        ),
      ],
    );
  }

  User? _findUserById(List<User> users, int id) {
    for (final user in users) {
      if (user.id == id) return user;
    }
    return null;
  }

  Future<void> _addUserMarkers(BuildContext context) async {
    final mapNotifier = ref.read(mapNotifierProvider.notifier);
    final userIds = mapNotifier.userIds;
    final chatDetail = ref.read(chatDetailNotifierProvider(widget.chatRoom));
    final participants = chatDetail.participants;

    for (final id in userIds) {
      final user = _findUserById(participants, id);
      if (user == null) continue;

      final profileUrl = user.profile?.trim();
      final latLng = mapNotifier.getUserLatLng(id);
      if (latLng == null) continue;

      final hasValidProfile = profileUrl != null &&
          profileUrl.isNotEmpty &&
          profileUrl != 'default_profile' &&
          Uri.tryParse(profileUrl)?.hasAbsolutePath == true;

      final profileWidget = SizedBox(
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
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                ),
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
                  image: NetworkImage(profileUrl),
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

      final overlayImage = await NOverlayImage.fromWidget(
        widget: profileWidget,
        size: const Size(60, 80),
        context: context,
      );

      final marker = NMarker(
        id: 'user_$id',
        position: latLng,
        icon: overlayImage,
      );

      _userMarkers.add(marker);
    }

    _mapController?.addOverlayAll(_userMarkers.toSet());
  }

  Widget _buildUserIcons() {
    final mapNotifier = ref.read(mapNotifierProvider.notifier);
    final userIds = mapNotifier.userIds;
    final chatDetail = ref.watch(chatDetailNotifierProvider(widget.chatRoom));
    final participants = chatDetail.participants;

    if (userIds.isEmpty || participants.isEmpty) {
      return const SizedBox(
        height: 50,
        child: Center(child: Text('표시할 유저 없음')),
      );
    }

    final icons = userIds.map((id) {
      final user = _findUserById(participants, id);
      final profileUrl = user?.profile?.trim();

      final hasValidProfile = profileUrl != null &&
          profileUrl.isNotEmpty &&
          profileUrl != 'default_profile' &&
          Uri.tryParse(profileUrl)?.hasAbsolutePath == true;

      return Padding(
        padding: const EdgeInsets.only(right: 10),
        child: GestureDetector(
          onTap: () => _moveCameraToUser(id),
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
    final mapNotifier = ref.read(mapNotifierProvider.notifier);
    final userLatLng = mapNotifier.getUserLatLng(userId);

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
