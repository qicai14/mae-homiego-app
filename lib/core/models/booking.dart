enum BookingStatus { pending, confirmed, declined, cancelled }
enum PaymentStatus { unpaid, paid, refunded }
enum ReviewStatus { pending, sent, declined }
enum UserRole { tenant, homeowner, admin }
enum PropertyStatus { pending, approved, rejected }

class Booking {
  final int id;
  final String tenantId;
  final int propertyId;
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final double totalPrice;
  final BookingStatus status;
  final PaymentStatus paymentStatus;
  final ReviewStatus? reviewStatus;
  final DateTime createdAt;

  Booking({
    required this.id,
    required this.tenantId,
    required this.propertyId,
    required this.checkInDate,
    required this.checkOutDate,
    required this.totalPrice,
    required this.status,
    required this.paymentStatus,
    this.reviewStatus,
    required this.createdAt,
  });

  factory Booking.fromMap(Map<String, dynamic> map) {
    // Parse dates - handle both date-only strings (YYYY-MM-DD) and full datetime strings
    DateTime parseDate(dynamic dateValue) {
      if (dateValue == null) return DateTime.now();
      final dateStr = dateValue.toString();
      // If it's a date-only string (YYYY-MM-DD), parse it and create local DateTime
      if (dateStr.length == 10 && dateStr.contains('-')) {
        final parts = dateStr.split('-');
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
      // Otherwise, parse as full datetime string
      return DateTime.parse(dateStr);
    }

    return Booking(
      id: map['id'],
      tenantId: map['tenant_id'],
      propertyId: map['property_id'],
      checkInDate: parseDate(map['check_in_date']),
      checkOutDate: parseDate(map['check_out_date']),
      totalPrice: (map['total_price'] as num).toDouble(),
      status: BookingStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => BookingStatus.pending,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
        (e) => e.name == map['payment_status'],
        orElse: () => PaymentStatus.unpaid,
      ),
      reviewStatus: map['review_status'] != null
          ? ReviewStatus.values.firstWhere(
              (e) => e.name == map['review_status'],
              orElse: () => ReviewStatus.pending,
            )
          : null,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'property_id': propertyId,
      'check_in_date': checkInDate.toIso8601String().split('T')[0], // Date only
      'check_out_date': checkOutDate.toIso8601String().split('T')[0], // Date only
      'total_price': totalPrice,
      'status': status.name,
      'payment_status': paymentStatus.name,
      'review_status': reviewStatus?.name,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

