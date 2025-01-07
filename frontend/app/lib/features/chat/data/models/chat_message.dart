import '../../../auth/data/models/user.dart';

/// [ChatMessage] 모델
class ChatMessage {
  final int id;
  final int senderId;
  final int recipientId;
  final String content;
  final String? renderedContent;
  final DateTime dateSent;
  final int unreadCount;
  final int type;
  final int streamId; // ★ stream_id 필드 추가

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.content,
    required this.renderedContent,
    required this.dateSent,
    required this.unreadCount,
    required this.type,
    required this.streamId,
  });

  /// JSON을 [ChatMessage]로 변환
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: _toInt(json['id']),
      senderId: _toInt(json['sender_id']),
      recipientId: _toInt(json['recipient_id']),
      content: (json['content'] as String?) ?? '',
      renderedContent: json['rendered_content'] as String?,
      type: _toInt(json['type']),
      unreadCount: _toInt(json['unread_count']),
      dateSent: _parseDateSent(json['date_sent']),
      // ★ "stream_id"도 함께 파싱
      streamId: _toInt(json['stream_id']),
    );
  }

  /// 일부 필드만 바꿔서 새로운 [ChatMessage] 반환
  ChatMessage copyWith({
    int? id,
    int? senderId,
    int? recipientId,
    String? content,
    String? renderedContent,
    DateTime? dateSent,
    int? unreadCount,
    int? type,
    int? streamId, // ★ 추가
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
      streamId: streamId ?? this.streamId, // ★ 반영
    );
  }

  /// date_sent 파싱 로직 (유닉스 타임 or ISO8601 문자열)
  static DateTime _parseDateSent(dynamic raw) {
    if (raw is int) {
      // 유닉스 타임(초) 가정 → 밀리초로 바꾸기 위해 * 1000
      return DateTime.fromMillisecondsSinceEpoch(raw * 1000).toLocal();
    } else if (raw is String) {
      // ISO8601 날짜 문자열 (예: "2025-01-05T10:21:36.429983Z")
      return DateTime.parse(raw).toLocal();
    }
    // null이거나 알 수 없는 형식이면 현재 시각으로 처리
    return DateTime.now();
  }

  /// dynamic → int 변환 헬퍼
  static int _toInt(dynamic raw) {
    if (raw is int) {
      return raw;
    } else if (raw is String) {
      return int.tryParse(raw) ?? 0;
    }
    return 0;
  }

  @override
  String toString() {
    return 'ChatMessage(id:$id, senderId:$senderId, recipientId:$recipientId, '
        'content:$content, dateSent:$dateSent, unreadCount:$unreadCount, '
        'type:$type, streamId:$streamId)';
  }
}

class ChatDetailState {
  final bool isLoadingMore;
  final List<ChatMessage> messages;
  final List<User> participants;

  ChatDetailState({
    this.isLoadingMore = false,
    this.messages = const [],
    this.participants = const [],
  });

  /// copyWith → 일부 필드만 변경해 새 [ChatDetailState] 반환
  ChatDetailState copyWith({
    int? myUserId,
    bool? isLoadingMore,
    List<ChatMessage>? messages,
    List<User>? participants,
  }) {
    return ChatDetailState(
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      messages: messages ?? this.messages,
      participants: participants ?? this.participants,
    );
  }

  @override
  String toString() {
    return
        'isLoadingMore:$isLoadingMore, '
        'messages.length:${messages.length}, '
        'participants.length:${participants.length})';
  }
}
