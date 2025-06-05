class ChatBotChunk {
  final int userId;
  final String role; // 'user' or 'assistant'
  final String content;

  ChatBotChunk({
    required this.userId,
    required this.role,
    required this.content,
  });

  factory ChatBotChunk.fromJson(Map<String, dynamic> json) {
    return ChatBotChunk(
      userId: json['user_id'],
      role: json['role'],
      content: json['content'],
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'role': role,
    'content': content,
  };
}

class ChatState {
  final List<ChatBotChunk> messages;
  final bool isStreaming;
  final bool isFinished;

  const ChatState({
    required this.messages,
    required this.isStreaming,
    this.isFinished = false,
  });

  ChatState copyWith({
    List<ChatBotChunk>? messages,
    bool? isStreaming,
    bool? isFinished,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      isFinished: isFinished ?? this.isFinished,
    );
  }
}
