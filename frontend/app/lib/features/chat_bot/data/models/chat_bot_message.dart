class ChatBotChunk {
  final int userId;
  final String role;    // 'user' 또는 'assistant'
  final String content; // 이번 청크에 담긴 텍스트

  ChatBotChunk({
    required this.userId,
    required this.role,
    required this.content,
  });

  /// JSON → ChatBotChunk 객체로 변환
  factory ChatBotChunk.fromJson(Map<String, dynamic> json) {
    return ChatBotChunk(
      userId: json['user_id'] as int,
      role: json['role'] as String,
      content: json['content'] as String,
    );
  }

  /// ChatBotChunk 객체 → JSON으로 변환 (필요 시)
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'role': role,
      'content': content,
    };
  }

  @override
  String toString() {
    return 'ChatBotChunk(userId: $userId, role: $role, content: $content)';
  }
}
