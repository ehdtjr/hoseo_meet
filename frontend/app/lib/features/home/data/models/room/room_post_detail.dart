class RoomDetail {
  final int id;
  final String name;
  final int reviewsCount;
  final double avgRating;
  final double distance;
  final List<String> images;
  final String address;
  final String contact;
  final String price;
  final String fee;
  final String options;
  final String gasType;
  final String comment;
  final String place;
  final Map<int, int> reviewRatingCounts; // 추가된 필드

  RoomDetail({
    required this.id,
    required this.name,
    required this.reviewsCount,
    required this.avgRating,
    required this.distance,
    required this.images,
    required this.address,
    required this.contact,
    required this.price,
    required this.fee,
    required this.options,
    required this.gasType,
    required this.comment,
    required this.place,
    required this.reviewRatingCounts, // 추가된 필드
  });

  factory RoomDetail.fromJson(Map<String, dynamic> json) {
    return RoomDetail(
      id: json['id'],
      name: json['name'],
      reviewsCount: json['reviews_count'],
      avgRating: (json['avg_rating'] as num).toDouble(),
      distance: (json['distance'] as num).toDouble(),
      images: List<String>.from(json['images']),
      address: json['address'],
      contact: json['contact'],
      price: json['price'],
      fee: json['fee'],
      options: json['options'],
      gasType: json['gas_type'],
      comment: json['comment'],
      place: json['place'],
      reviewRatingCounts: Map<int, int>.from(
        (json['review_rating_counts'] as Map).map(
              (key, value) => MapEntry(int.parse(key.toString()), value),
        ),
      ), // 평점별 개수 변환
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'reviews_count': reviewsCount,
      'avg_rating': avgRating,
      'distance': distance,
      'images': images,
      'address': address,
      'contact': contact,
      'price': price,
      'fee': fee,
      'options': options,
      'gas_type': gasType,
      'comment': comment,
      'place': place,
      'review_rating_counts': reviewRatingCounts.map(
            (key, value) => MapEntry(key.toString(), value),
      ), // Map<int, int> → Map<String, int> 변환
    };
  }

  RoomDetail copyWith({
    int? id,
    String? name,
    int? reviewsCount,
    double? avgRating,
    double? distance,
    List<String>? images,
    String? address,
    String? contact,
    String? price,
    String? fee,
    String? options,
    String? gasType,
    String? comment,
    String? place,
    Map<int, int>? reviewRatingCounts,
  }) {
    return RoomDetail(
      id: id ?? this.id,
      name: name ?? this.name,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      avgRating: avgRating ?? this.avgRating,
      distance: distance ?? this.distance,
      images: images ?? this.images,
      address: address ?? this.address,
      contact: contact ?? this.contact,
      price: price ?? this.price,
      fee: fee ?? this.fee,
      options: options ?? this.options,
      gasType: gasType ?? this.gasType,
      comment: comment ?? this.comment,
      place: place ?? this.place,
      reviewRatingCounts: reviewRatingCounts ?? this.reviewRatingCounts,
    );
  }
}
