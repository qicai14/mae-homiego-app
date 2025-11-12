class Review {
  final int id;
  final int bookingId;
  final String tenantId;
  final int propertyId;
  final int rating;
  final String comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.bookingId,
    required this.tenantId,
    required this.propertyId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      id: map['id'],
      bookingId: map['booking_id'],
      tenantId: map['tenant_id'],
      propertyId: map['property_id'],
      rating: map['rating'],
      comment: map['comment'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'booking_id': bookingId,
      'tenant_id': tenantId,
      'property_id': propertyId,
      'rating': rating,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

