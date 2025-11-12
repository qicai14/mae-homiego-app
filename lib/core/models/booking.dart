enum BookingStatus { pending, confirmed, declined, cancelled }
enum PaymentStatus { unpaid, paid, refunded }

class Booking {
  final int id;
  final String tenantId;
  final int propertyId;
  final DateTime checkInDate;
  final double totalPrice;
  final BookingStatus status;
  final PaymentStatus paymentStatus;
  final String cancellationPolicy;
  final DateTime createdAt;

  Booking({
    required this.id,
    required this.tenantId,
    required this.propertyId,
    required this.checkInDate,
    required this.totalPrice,
    required this.status,
    required this.paymentStatus,
    required this.cancellationPolicy,
    required this.createdAt,
  });

  factory Booking.fromMap(Map<String, dynamic> map) {
    return Booking(
      id: map['id'],
      tenantId: map['tenant_id'],
      propertyId: map['property_id'],
      checkInDate: DateTime.parse(map['check_in_date']),
      totalPrice: (map['total_price'] as num).toDouble(),
      status: BookingStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => BookingStatus.pending,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
        (e) => e.name == map['payment_status'],
        orElse: () => PaymentStatus.unpaid,
      ),
      cancellationPolicy: map['cancellation_policy'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'property_id': propertyId,
      'check_in_date': checkInDate.toIso8601String().split('T')[0], // Date only
      'total_price': totalPrice,
      'status': status.name,
      'payment_status': paymentStatus.name,
      'cancellation_policy': cancellationPolicy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

