import '../models/chat_message.dart';

typedef MessageLoader = Future<List<ChatMessage>> Function({
  required int streamId,
  String anchor,
  int numBefore,
  int numAfter,
});

/// Reads to a fixed server watermark so ongoing traffic cannot move the cursor
/// past an unfilled gap or make recovery run forever. Anchors are inclusive.
class MessageRecoveryService {
  MessageRecoveryService(this._load, {this.pageSize = 100});

  final MessageLoader _load;
  final int pageSize;

  Future<List<ChatMessage>> recover({
    required int streamId,
    int? afterId,
    required bool Function() isActive,
  }) async {
    final newest = await _load(
      streamId: streamId,
      anchor: 'newest',
      numBefore: 0,
      numAfter: 0,
    );
    if (!isActive() || newest.isEmpty) return [];
    final target = newest.last.id;
    if (afterId != null && afterId >= target) return newest;

    final recovered = <int, ChatMessage>{};
    var cursor = afterId;
    while (isActive()) {
      final page = await _load(
        streamId: streamId,
        anchor: cursor?.toString() ?? 'oldest',
        numBefore: 0,
        numAfter: pageSize,
      );
      if (!isActive()) return [];
      for (final message in page) {
        if (message.streamId == streamId && message.id <= target) {
          recovered[message.id] = message;
        }
      }
      final next = page.fold<int>(
        cursor ?? 0,
        (id, message) => message.id > id ? message.id : id,
      );
      if (next >= target) {
        return recovered.values.toList()..sort((a, b) => a.id.compareTo(b.id));
      }
      if (next == (cursor ?? 0)) {
        throw StateError('Message recovery did not reach the server watermark');
      }
      cursor = next;
    }
    return [];
  }

  /// Refresh affected cached pages instead of decrementing counts from events.
  /// HTTP snapshots and delayed/read replay events can overlap, so deltas are
  /// not safe. Count values are authoritative and monotonically decrease.
  Future<List<ChatMessage>> refreshReadStates({
    required int streamId,
    required List<ChatMessage> cachedMessages,
    required Set<int> messageIds,
    required bool Function() isActive,
  }) async {
    final refreshed = <int, ChatMessage>{};
    final requested = cachedMessages
        .where((m) => messageIds.contains(m.id))
        .map((m) => m.id)
        .toSet();
    final cachedIds = cachedMessages.map((m) => m.id).toSet();
    for (var start = 0; start < cachedMessages.length; start += pageSize) {
      if (!isActive()) return [];
      final end = start + pageSize < cachedMessages.length
          ? start + pageSize
          : cachedMessages.length;
      final page = cachedMessages.sublist(start, end);
      if (!page.any((m) => requested.contains(m.id))) continue;
      final snapshot = await _load(
          streamId: streamId,
          anchor: page.last.id.toString(),
          numBefore: page.length - 1,
          numAfter: 0);
      if (!isActive()) return [];
      for (final message in snapshot) {
        if (message.streamId == streamId && cachedIds.contains(message.id)) {
          refreshed[message.id] = message;
        }
      }
    }
    // Live traffic can temporarily leave holes in the cache during catch-up.
    // Backwards pages may then omit requested IDs; fetch those exact anchors.
    for (final id in requested.difference(refreshed.keys.toSet())) {
      if (!isActive()) return [];
      final snapshot = await _load(
          streamId: streamId, anchor: id.toString(), numBefore: 0, numAfter: 0);
      if (!isActive()) return [];
      for (final message in snapshot) {
        if (message.id == id && message.streamId == streamId) {
          refreshed[id] = message;
        }
      }
    }
    return refreshed.values.toList();
  }
}
