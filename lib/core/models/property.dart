enum PropertyStatus { pending, approved, rejected }

class Property {
  final int id;
  final String hostId;
  final DateTime createdAt;
  final String title;
  final String description;
  final String propertyType;
  final double pricePerNight;
  final int maxGuest;
  final String address;
  final double latitude;
  final double longitude;
  final List<String> amenities;
  final PropertyStatus status;
  final bool verified;
  final double cleaningFee;
  final double serviceFee;

  Property({
    required this.id,
    required this.hostId,
    required this.createdAt,
    required this.title,
    required this.description,
    required this.propertyType,
    required this.pricePerNight,
    required this.maxGuest,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.amenities,
    required this.status,
    required this.verified,
    required this.cleaningFee,
    required this.serviceFee,
  });

  factory Property.fromMap(Map<String, dynamic> map) {
    return Property(
      id: map['id'] as int? ?? 0,
      hostId: map['host_id'] as String? ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      propertyType: map['property_type'] as String? ?? '',
      pricePerNight: (map['price_per_night'] as num?)?.toDouble() ?? 0.0,
      maxGuest: map['max_guests'] as int? ?? map['max_guest'] as int? ?? 0,
      address: map['address'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      amenities: List<String>.from(map['amenities'] ?? []),
      status: PropertyStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PropertyStatus.pending,
      ),
      verified: map['verified'] as bool? ?? false,
      cleaningFee: (map['cleaning_fee'] as num?)?.toDouble() ?? 0.0,
      serviceFee: (map['service_fee'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'host_id': hostId,
      'created_at': createdAt.toIso8601String(),
      'title': title,
      'description': description,
      'property_type': propertyType,
      'price_per_night': pricePerNight,
      'max_guest': maxGuest,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'amenities': amenities,
      'status': status.name,
      'verified': verified,
      'cleaning_fee': cleaningFee,
      'service_fee': serviceFee,
    };
  }
}

