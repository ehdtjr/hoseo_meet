class ChatRoom {
  final int streamId;             // stream_id
  final int creatorId;            // creator_id
  final String type;              // "delivery", "meet", "taxi" 등 (서버 원본)
  final String name;              // 채팅방 이름
  final bool isMuted;             // is_muted
  final List<int> subscribers;    // subscribers (참여중인 유저들의 ID 목록)
  final int unreadCount;          // 안 읽은 메시지 수
  final String lastMessageContent;// 마지막 메시지 내용
  final String time;              // 메시지 시각 (문자열 형태)

  ChatRoom({
    required this.streamId,
    required this.creatorId,
    required this.type,
    required this.name,
    required this.isMuted,
    required this.subscribers,
    required this.unreadCount,
    required this.lastMessageContent,
    required this.time,
  });

  /// (1) 타입을 한국어로 변환하는 getter
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

  /// (2) copyWith 구현
  ChatRoom copyWith({
    int? streamId,
    int? creatorId,
    String? type,
    String? name,
    bool? isMuted,
    List<int>? subscribers,
    int? unreadCount,
    String? lastMessageContent,
    String? time,
  }) {
    return ChatRoom(
      streamId: streamId ?? this.streamId,
      creatorId: creatorId ?? this.creatorId,
      type: type ?? this.type,
      name: name ?? this.name,
      isMuted: isMuted ?? this.isMuted,
      subscribers: subscribers ?? this.subscribers,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      time: time ?? this.time,
    );
  }

  /// (3) JSON -> ChatRoom 변환 (factory constructor)
  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    // last_message 필드 처리
    final dynamic lastMsg = json['last_message'];
    String content = '';
    String dateTimeString = '';

    if (lastMsg is String && lastMsg == 'No messages') {
      content = 'No messages';
      dateTimeString = '';
    } else if (lastMsg is Map<String, dynamic>) {
      content = (lastMsg['content'] ?? '').toString();
      dateTimeString = (lastMsg['date_sent'] ?? '').toString();
    }
    // else면 알 수 없는 형식 → 기본값 '' 유지

    // subscribers 필드 처리 (참여 중인 유저 ID 목록)
    List<int> subs = [];
    if (json['subscribers'] is List) {
      subs = (json['subscribers'] as List<dynamic>)
          .map((e) => e is int ? e : 0)
          .toList();
    }

    return ChatRoom(
      streamId: (json['stream_id'] ?? 0) as int,
      creatorId: (json['creator_id'] ?? 0) as int,
      type: (json['type'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      isMuted: json['is_muted'] == true,  // null → false
      subscribers: subs,
      unreadCount: (json['unread_message_count'] ?? 0) as int,
      lastMessageContent: content,
      time: dateTimeString,
    );
  }
}
