class ChatRoom {
  final int streamId;
  final String type;      // "delivery", "meet", "taxi" 등 (서버 원본)
  final String name;      // 채팅방 이름
  final int unreadCount;  // 안 읽은 메시지 수
  final String lastMessageContent;  // 마지막 메시지 내용
  final String time;      // 메시지 시각 (문자열 형태)

  ChatRoom({
    required this.streamId,
    required this.type,
    required this.name,
    required this.unreadCount,
    required this.lastMessageContent,
    required this.time,
  });

  // (1) 타입을 한국어로 변환하는 getter
  String get typeKr {
    switch (type) {
      case 'delivery':
        return '배달';
      case 'meet':
        return '모임';
      case 'taxi':
        return '택시';
      default:
        return '일반';
    }
  }

  // (2) copyWith 구현
  ChatRoom copyWith({
    int? streamId,
    String? type,
    String? name,
    int? unreadCount,
    String? lastMessageContent,
    String? time,
  }) {
    return ChatRoom(
      streamId: streamId ?? this.streamId,
      type: type ?? this.type,
      name: name ?? this.name,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      time: time ?? this.time,
    );
  }

  // JSON -> ChatRoom 변환 (factory constructor)
  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    final dynamic lastMsg = json['last_message'];
    String content = '';
    String dateTimeString = '';

    if (lastMsg is String && lastMsg == 'No messages') {
      content = 'No messages';
      dateTimeString = '';
    } else if (lastMsg is Map<String, dynamic>) {
      content = lastMsg['content'] ?? '';
      dateTimeString = lastMsg['date_sent'] ?? '';
    }

    return ChatRoom(
      streamId: json['stream_id'] ?? 0,
      type: json['type'] ?? '',   // "delivery", "meet", "taxi", etc.
      name: json['name'] ?? '',
      unreadCount: json['unread_message_count'] ?? 0,
      lastMessageContent: content,
      time: dateTimeString,
    );
  }
}
