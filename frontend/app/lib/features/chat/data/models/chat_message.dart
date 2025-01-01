class ChatMessage {
  final int id;
  final int senderId;
  final int recipientId;
  final String content;
  final String? renderedContent;
  final DateTime dateSent;
  final int unreadCount;

  /// type 필드가 null이거나 누락될 수 있으므로 int? 로 받고 기본값 0
  final int type;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.content,
    required this.renderedContent,
    required this.dateSent,
    required this.unreadCount,
    required this.type,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      /// id, sender_id, recipient_id, content 등은 null이 아닐 거라 가정하지만,
      /// 안전하게 처리하고 싶다면 int? ?? 0 형태로 바꿀 수도 있음
      id: (json['id'] as int?) ?? 0,
      senderId: (json['sender_id'] as int?) ?? 0,
      recipientId: (json['recipient_id'] as int?) ?? 0,
      content: (json['content'] as String?) ?? '',

      /// rendered_content는 null이면 그냥 null
      renderedContent: json['rendered_content'] as String?,

      /// type도 null이면 0
      type: (json['type'] as int?) ?? 0,

      /// unread_count도 null이면 0
      unreadCount: (json['unread_count'] as int?) ?? 0,

      /// date_sent가 숫자(timestamp)로 오면 int, 문자열(ISO8601)로 오면 String
      dateSent: _parseDateSent(json['date_sent']),
    );
  }

  /// date_sent 파싱 로직
  static DateTime _parseDateSent(dynamic raw) {
    if (raw is int) {
      // 유닉스 타임스탬프(초)인지, 밀리초인지에 따라 조정
      // 예: 초 단위라면 * 1000
      return DateTime.fromMillisecondsSinceEpoch(raw * 1000).toLocal();
    } else if (raw is String) {
      // 문자열 형태라면 parse
      return DateTime.parse(raw).toLocal();
    } else {
      // null이거나 예외 상황이면 현재 시각으로 처리(임시)
      return DateTime.now();
    }
  }

  /// 일부 필드만 바꿔서 새로운 ChatMessage 인스턴스를 반환
  ChatMessage copyWith({
    int? id,
    int? senderId,
    int? recipientId,
    String? content,
    String? renderedContent,
    DateTime? dateSent,
    int? unreadCount,
    int? type,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      content: content ?? this.content,
      renderedContent: renderedContent ?? this.renderedContent,
      dateSent: dateSent ?? this.dateSent,
      unreadCount: unreadCount ?? this.unreadCount,
      type: type ?? this.type,
    );
  }
}
