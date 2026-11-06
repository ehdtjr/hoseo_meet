enum RandomChatQueueStatus { idle, waiting, matched }

class RandomChatQueueSnapshot {
  final RandomChatQueueStatus status;
  final int? streamId;

  const RandomChatQueueSnapshot({required this.status, this.streamId});

  const RandomChatQueueSnapshot.idle()
    : status = RandomChatQueueStatus.idle,
      streamId = null;

  factory RandomChatQueueSnapshot.fromJson(Map<String, dynamic> json) {
    final status = switch (json['status']) {
      'idle' => RandomChatQueueStatus.idle,
      'waiting' => RandomChatQueueStatus.waiting,
      'matched' => RandomChatQueueStatus.matched,
      _ => throw const FormatException('Unknown random chat queue status'),
    };
    final rawStreamId = json['stream_id'];
    if (status == RandomChatQueueStatus.matched) {
      if (rawStreamId is! int || rawStreamId <= 0) {
        throw const FormatException('A matched queue result needs a stream id');
      }
      return RandomChatQueueSnapshot(status: status, streamId: rawStreamId);
    }
    if (rawStreamId != null) {
      throw const FormatException(
        'An unmatched queue result cannot have a stream id',
      );
    }
    return RandomChatQueueSnapshot(status: status);
  }
}
