class Restaurant {
  final int id;
  final String name;
  final String address;
  final int distance;
  final double latitude;
  final double longitude;
  final double avgRating;
  final int reviewCount;
  final bool isHearted;
  final List<String> images;
  final String? comment;         // ✅ 선택적 설명
  final String? contact;         // ✅ 전화번호 (nullable)
  final String? businessHours;   // ✅ 영업시간 (nullable)

  Restaurant({
    required this.id,
    required this.name,
    required this.address,
    required this.distance,
    required this.latitude,
    required this.longitude,
    required this.avgRating,
    required this.reviewCount,
    required this.isHearted,
    required this.images,
    this.comment,
    this.contact,
    this.businessHours,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] as int,
      name: json['name'] as String,
      address: json['address'] as String,
      distance: (json['distance'] as num).toInt(),
      latitude: (json['location']['latitude'] as num).toDouble(),
      longitude: (json['location']['longitude'] as num).toDouble(),
      avgRating: (json['avg_rating'] as num).toDouble(),
      reviewCount: json['review_count'] as int,
      isHearted: json['is_hearted'] as bool,
      images: List<String>.from(json['images']),
      comment: json['comment'] as String?,
      contact: json['contact'] as String?,
      businessHours: json['business_hours'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'distance': distance,
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'avg_rating': avgRating,
      'review_count': reviewCount,
      'is_hearted': isHearted,
      'images': images,
      if (comment != null) 'comment': comment,
      if (contact != null) 'contact': contact,
      if (businessHours != null) 'business_hours': businessHours,
    };
  }

  Restaurant copyWith({
    int? id,
    String? name,
    String? address,
    int? distance,
    double? latitude,
    double? longitude,
    double? avgRating,
    int? reviewCount,
    bool? isHearted,
    List<String>? images,
    String? comment,
    String? contact,
    String? businessHours,
  }) {
    return Restaurant(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      distance: distance ?? this.distance,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      avgRating: avgRating ?? this.avgRating,
      reviewCount: reviewCount ?? this.reviewCount,
      isHearted: isHearted ?? this.isHearted,
      images: images ?? this.images,
      comment: comment ?? this.comment,
      contact: contact ?? this.contact,
      businessHours: businessHours ?? this.businessHours,
    );
  }
}
