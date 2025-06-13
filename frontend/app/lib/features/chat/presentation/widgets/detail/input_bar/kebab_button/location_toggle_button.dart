import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../data/models/chat_room.dart';
import '../../../../../providers/chat_detail_provider.dart';

class LocationToggleButton extends ConsumerWidget {
  final ChatRoom chatRoom;
  final VoidCallback onCloseOverlay;

  const LocationToggleButton({
    super.key,
    required this.chatRoom,
    required this.onCloseOverlay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(chatDetailNotifierProvider(chatRoom).notifier);
    final isSharing = ref.watch(
      chatDetailNotifierProvider(chatRoom).select((s) => s.isLocationSharing),
    );

    return GestureDetector(
      onTap: () {
        if (isSharing) {
          notifier.stopLocationTracking();
          notifier.state = notifier.state.copyWith(isLocationSharing: false);
          _showCenterMessage(context, '위치 공유 OFF');
        } else {
          notifier.startLocationTracking();
          notifier.state = notifier.state.copyWith(isLocationSharing: true);
          _showCenterMessage(context, '위치 공유 ON');
        }

        onCloseOverlay();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSharing ? Colors.red : Colors.grey,
          boxShadow: isSharing
              ? [
            const BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              spreadRadius: 2,
              offset: Offset(0, 4),
            ),
          ]
              : [],
        ),
        child: Icon(
          isSharing ? Icons.location_on : Icons.location_off,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  void _showCenterMessage(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).size.height * 0.42,
        left: MediaQuery.of(ctx).size.width * 0.15,
        right: MediaQuery.of(ctx).size.width * 0.15,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.85), // ✅ 반투명 회색 배경
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 1600), () => entry.remove());
  }
}
