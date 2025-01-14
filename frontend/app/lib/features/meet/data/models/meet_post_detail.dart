import '../../../auth/data/models/user.dart';

class MeetDetail {
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
  final bool isSubscribed;

  MeetDetail({
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
    required this.isSubscribed,
  });

  // JSON 데이터를 모델로 변환하는 factory 생성자
  factory MeetDetail.fromJson(Map<String, dynamic> json) {
    return MeetDetail(
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
      isSubscribed: json['is_subscribed'],
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
      'is_subscribed': isSubscribed,
    };
  }
}
