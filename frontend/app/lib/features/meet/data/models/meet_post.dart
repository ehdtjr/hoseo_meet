import '../../../auth/data/models/user.dart';

class MeetPost {
  final int id;
  final String title;
  final String type;
  final User author;
  final int streamId;
  final String content;
  final int pageViews;
  final DateTime createdAt;
  final int maxPeople;
  final int currentPeople;
  final String shortContent;
  final bool isSubscribed; // is_subscribed 필드 추가

  MeetPost({
    required this.id,
    required this.title,
    required this.type,
    required this.author,
    required this.streamId,
    required this.content,
    required this.pageViews,
    required this.createdAt,
    required this.maxPeople,
    required this.currentPeople,
    required this.shortContent,
    required this.isSubscribed, // 필드 초기화
  });

  // JSON 데이터를 모델로 변환하는 factory 생성자
  factory MeetPost.fromJson(Map<String, dynamic> json) {
    return MeetPost(
      id: json['id'],
      title: json['title'],
      type: json['type'],
      author: User.fromJson(json['author']),
      streamId: json['stream_id'],
      content: json['content'],
      pageViews: json['page_views'],
      createdAt: DateTime.parse(json['created_at']),
      maxPeople: json['max_people'],
      currentPeople: json['current_people'],
      shortContent: json['short_content'],
      isSubscribed: json['is_subscribed'], // JSON에서 is_subscribed 값 할당
    );
  }

  // 모델을 JSON으로 변환하는 메서드
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'author': author.toJson(),
      'stream_id': streamId,
      'content': content,
      'page_views': pageViews,
      'created_at': createdAt.toIso8601String(),
      'max_people': maxPeople,
      'current_people': currentPeople,
      'short_content': shortContent,
      'is_subscribed': isSubscribed, // is_subscribed 값 포함
    };
  }

  // copyWith 메서드: 변경할 필드만 지정하여 새로운 MeetPost 객체 반환
  MeetPost copyWith({
    int? id,
    String? title,
    String? type,
    User? author,
    int? streamId,
    String? content,
    int? pageViews,
    DateTime? createdAt,
    int? maxPeople,
    int? currentPeople,
    String? shortContent,
    bool? isSubscribed,
  }) {
    return MeetPost(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      author: author ?? this.author,
      streamId: streamId ?? this.streamId,
      content: content ?? this.content,
      pageViews: pageViews ?? this.pageViews,
      createdAt: createdAt ?? this.createdAt,
      maxPeople: maxPeople ?? this.maxPeople,
      currentPeople: currentPeople ?? this.currentPeople,
      shortContent: shortContent ?? this.shortContent,
      isSubscribed: isSubscribed ?? this.isSubscribed,
    );
  }
}
