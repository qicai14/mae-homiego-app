class PropertyImage {
  final int id;
  final int propertyId;
  final String storagePath;
  final int position;

  PropertyImage({
    required this.id,
    required this.propertyId,
    required this.storagePath,
    required this.position,
  });

  factory PropertyImage.fromMap(Map<String, dynamic> map) {
    return PropertyImage(
      id: map['id'],
      propertyId: map['property_id'],
      storagePath: map['storage_path'],
      position: map['position'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'property_id': propertyId,
      'storage_path': storagePath,
      'position': position,
    };
  }
}

