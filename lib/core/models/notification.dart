enum NotificationAction { review, payment }

class Notification {
  final int id;
  final String userId;
  final String title;
  final String description;
  final bool isRead;
  final DateTime createdAt;
  final NotificationAction? type;
  final int? bookingId;

  Notification({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.isRead,
    required this.createdAt,
    this.type,
    this.bookingId,
  });

  factory Notification.fromMap(Map<String, dynamic> map) {
    try {
      return Notification(
        id: map['id'] as int? ?? 0,
        userId: map['user_id'] as String? ?? '',
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        isRead: map['is_read'] as bool? ?? false,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : DateTime.now(),
        type: map['type'] != null && map['type'].toString().isNotEmpty
            ? NotificationAction.values.firstWhere(
                (e) => e.name == map['type'],
                orElse: () => NotificationAction.review,
              )
            : null,
        bookingId: map['booking_id'] as int?,
      );
    } catch (e) {
      print('Notification.fromMap error: $e, map: $map');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'type': type?.name,
      'booking_id': bookingId,
    };
  }
}

