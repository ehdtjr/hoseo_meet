class RoomPost {
  final int id;
  final String name;
  final int reviewsCount;
  final double avgRating;
  final int distance;
  final List<String> images;

  RoomPost({
    required this.id,
    required this.name,
    required this.reviewsCount,
    required this.avgRating,
    required this.distance,
    required this.images,
  });

  // JSON 데이터를 모델로 변환하는 factory 생성자
  factory RoomPost.fromJson(Map<String, dynamic> json) {
    return RoomPost(
      id: json['id'] as int,
      name: json['name'] as String,
      reviewsCount: json['reviews_count'] as int,
      avgRating: (json['avg_rating'] as num).toDouble(),
      distance: (json['distance'] as num).toInt(), // 정수형으로 변환
      images: List<String>.from(json['images']),
    );
  }

  // 모델을 JSON으로 변환하는 메서드
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'reviews_count': reviewsCount,
      'avg_rating': avgRating,
      'distance': distance,
      'images': images,
    };
  }

  // copyWith 메서드: 변경할 필드만 지정하여 새로운 RoomPost 객체를 반환
  RoomPost copyWith({
    int? id,
    String? name,
    int? reviewsCount,
    double? avgRating,
    int? distance, // int 타입으로 변경
    List<String>? images,
  }) {
    return RoomPost(
      id: id ?? this.id,
      name: name ?? this.name,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      avgRating: avgRating ?? this.avgRating,
      distance: distance ?? this.distance,
      images: images ?? this.images,
    );
  }
}
