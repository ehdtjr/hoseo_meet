class RoomReview {
  final int id;
  final int roomId;
  final String content;
  final double rating;
  final DateTime createdAt;
  final ReviewAuthor author;
  final List<String> images;

  RoomReview({
    required this.id,
    required this.roomId,
    required this.content,
    required this.rating,
    required this.createdAt,
    required this.author,
    required this.images,
  });

  // JSON 데이터를 RoomReview 객체로 변환
  factory RoomReview.fromJson(Map<String, dynamic> json) {
    return RoomReview(
      id: json['id'] as int,
      roomId: json['room_id'] as int,
      content: json['content'] as String,
      rating: (json['rating'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at']), // 문자열을 DateTime으로 변환
      author: ReviewAuthor.fromJson(json['author']), // ReviewAuthor 변환
      images: List<String>.from(json['images']), // 이미지 리스트 변환
    );
  }

  // RoomReview 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'content': content,
      'rating': rating,
      'created_at': createdAt.toIso8601String(), // DateTime을 문자열로 변환
      'author': author.toJson(), // ReviewAuthor JSON 변환
      'images': images,
    };
  }

  // copyWith 메서드: 변경할 필드만 지정하여 새로운 RoomReview 객체 반환
  RoomReview copyWith({
    int? id,
    int? roomId,
    String? content,
    double? rating,
    DateTime? createdAt,
    ReviewAuthor? author,
    List<String>? images,
  }) {
    return RoomReview(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      content: content ?? this.content,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      author: author ?? this.author,
      images: images ?? this.images,
    );
  }
}

// 리뷰 작성자 정보 클래스
class ReviewAuthor {
  final int id;
  final String name;
  final String profile;

  ReviewAuthor({
    required this.id,
    required this.name,
    required this.profile,
  });

  // JSON 데이터를 ReviewAuthor 객체로 변환
  factory ReviewAuthor.fromJson(Map<String, dynamic> json) {
    return ReviewAuthor(
      id: json['id'] as int,
      name: json['name'] as String,
      profile: json['profile'] as String,
    );
  }

  // ReviewAuthor 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'profile': profile,
    };
  }
}

class RoomReviewImage {
  final int id;
  final int reviewId;
  final int roomId;
  final String image;
  final DateTime createdAt;

  RoomReviewImage({
    required this.id,
    required this.reviewId,
    required this.roomId,
    required this.image,
    required this.createdAt,
  });

  /// JSON 데이터를 RoomReviewImage 객체로 변환
  factory RoomReviewImage.fromJson(Map<String, dynamic> json) {
    return RoomReviewImage(
      id: json['id'] as int,
      reviewId: json['review_id'] as int,
      roomId: json['room_id'] as int,
      image: json['image'] as String,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  /// RoomReviewImage 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'review_id': reviewId,
      'room_id': roomId,
      'image': image,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
