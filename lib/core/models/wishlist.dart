class Wishlist {
  final int id;
  final String tenantId;
  final int propertyId;

  Wishlist({
    required this.id,
    required this.tenantId,
    required this.propertyId,
  });

  factory Wishlist.fromMap(Map<String, dynamic> map) {
    return Wishlist(
      id: map['id'],
      tenantId: map['tenant_id'],
      propertyId: map['property_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'property_id': propertyId,
    };
  }
}

