class RestaurantPostDetail {
  final int id;
  final String name;
  final String address;
  final String? comment;
  final String? contact;
  final String? businessHours;
  final double distance;
  final double latitude;
  final double longitude;
  final double avgRating;
  final int reviewCount;
  final bool isHearted;
  final List<String> images;
  final Map<int, int> reviewRatingCounts;

  RestaurantPostDetail({
    required this.id,
    required this.name,
    required this.address,
    this.comment,
    this.contact,
    this.businessHours,
    required this.distance,
    required this.latitude,
    required this.longitude,
    required this.avgRating,
    required this.reviewCount,
    required this.isHearted,
    required this.images,
    required this.reviewRatingCounts,
  });

  factory RestaurantPostDetail.fromJson(Map<String, dynamic> json) {
    return RestaurantPostDetail(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      comment: json['comment'],
      contact: json['contact'],                   // ✅ 파싱 추가
      businessHours: json['business_hours'],      // ✅ 파싱 추가
      distance: (json['distance'] as num).toDouble(),
      latitude: (json['location']['latitude'] as num).toDouble(),
      longitude: (json['location']['longitude'] as num).toDouble(),
      avgRating: (json['avg_rating'] as num).toDouble(),
      reviewCount: json['review_count'] as int,
      isHearted: json['is_hearted'] as bool,
      images: List<String>.from(json['images'] ?? []),
      reviewRatingCounts: Map<int, int>.from(
        (json['review_rating_counts'] as Map).map(
              (key, value) => MapEntry(int.parse(key), value),
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'comment': comment,
      'contact': contact,                     // ✅ 직렬화 추가
      'business_hours': businessHours,       // ✅ 직렬화 추가
      'distance': distance,
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'avg_rating': avgRating,
      'review_count': reviewCount,
      'is_hearted': isHearted,
      'images': images,
      'review_rating_counts': reviewRatingCounts.map(
            (key, value) => MapEntry(key.toString(), value),
      ),
    };
  }

  RestaurantPostDetail copyWith({
    int? id,
    String? name,
    String? address,
    String? comment,
    String? contact,
    String? businessHours,
    double? distance,
    double? latitude,
    double? longitude,
    double? avgRating,
    int? reviewCount,
    bool? isHearted,
    List<String>? images,
    Map<int, int>? reviewRatingCounts,
  }) {
    return RestaurantPostDetail(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      comment: comment ?? this.comment,
      contact: contact ?? this.contact,
      businessHours: businessHours ?? this.businessHours,
      distance: distance ?? this.distance,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      avgRating: avgRating ?? this.avgRating,
      reviewCount: reviewCount ?? this.reviewCount,
      isHearted: isHearted ?? this.isHearted,
      images: images ?? this.images,
      reviewRatingCounts: reviewRatingCounts ?? this.reviewRatingCounts,
    );
  }
}
