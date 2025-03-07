import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoseomeet/commons/network/auth_http_client_provider.dart';
import '../../../data/models/room_review.dart';
import '../../../data/services/room_review_service.dart';
import 'room_review_notifier.dart'; // RoomReviewNotifier가 정의된 파일

final roomReviewServiceProvider = Provider<RoomReviewService>((ref) {
  final client = ref.watch(authHttpClientProvider);
  return RoomReviewService(client);
});

final roomReviewProvider = StateNotifierProvider.family<RoomReviewNotifier, List<RoomReview>, int>(
      (ref, roomId) {
    final service = ref.watch(roomReviewServiceProvider);
    return RoomReviewNotifier(service, roomId);
  },
);
