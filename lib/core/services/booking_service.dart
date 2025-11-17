import '../models/booking.dart';
import '../services/supabase_client.dart';
import '../constants/app_constants.dart';
import 'notification_service.dart';
import 'property_service.dart';

class BookingService {
  /// Create a new booking
  static Future<Booking?> createBooking({
    required String tenantId,
    required int propertyId,
    required DateTime checkInDate,
    required DateTime checkOutDate,
    required double totalPrice,
  }) async {
    try {
      final response = await supabase.from('bookings').insert({
        'tenant_id': tenantId,
        'property_id': propertyId,
        'check_in_date': checkInDate.toIso8601String().split('T')[0],
        'check_out_date': checkOutDate.toIso8601String().split('T')[0],
        'total_price': totalPrice,
        'status': BookingStatus.pending.name,
        'payment_status': PaymentStatus.paid.name,
      }).select().single();

      return Booking.fromMap(response);
    } catch (e) {
      print('Error creating booking: $e');
      return null;
    }
  }

  /// Update booking payment status
  static Future<bool> updatePaymentStatus({
    required int bookingId,
    required PaymentStatus paymentStatus,
  }) async {
    try {
      await supabase
          .from('bookings')
          .update({'payment_status': paymentStatus.name})
          .eq('id', bookingId);
      return true;
    } catch (e) {
      print('Error updating payment status: $e');
      return false;
    }
  }

  /// Update booking review status
  static Future<bool> updateReviewStatus({
    required int bookingId,
    required ReviewStatus reviewStatus,
  }) async {
    try {
      await supabase
          .from('bookings')
          .update({'review_status': reviewStatus.name})
          .eq('id', bookingId);
      return true;
    } catch (e) {
      print('Error updating review status: $e');
      return false;
    }
  }

  /// Get upcoming unpaid bookings (confirmed only)
  static Future<List<Booking>> getUpcomingUnpaidBookings(String tenantId) async {
    try {
      final today = DateTime.now();
      final todayDateOnly = DateTime(today.year, today.month, today.day);

      final response = await supabase
          .from('bookings')
          .select()
          .eq('tenant_id', tenantId)
          .eq('payment_status', PaymentStatus.unpaid.name)
          .eq('status', BookingStatus.confirmed.name)
          .gte('check_out_date', todayDateOnly.toIso8601String().split('T')[0])
          .order('check_in_date', ascending: true);

      return (response as List)
          .map((json) => Booking.fromMap(json))
          .toList();
    } catch (e) {
      print('Error fetching upcoming unpaid bookings: $e');
      return [];
    }
  }

  /// Get upcoming bookings
  static Future<List<Booking>> getUpcomingBookings(String tenantId) async {
    try {
      final today = DateTime.now();
      final todayDateOnly = DateTime(today.year, today.month, today.day);

      final response = await supabase
          .from('bookings')
          .select()
          .eq('tenant_id', tenantId)
          .gte('check_out_date', todayDateOnly.toIso8601String().split('T')[0])
          .order('check_in_date', ascending: true);

      return (response as List)
          .map((json) => Booking.fromMap(json))
          .toList();
    } catch (e) {
      print('Error fetching upcoming bookings: $e');
      return [];
    }
  }

  /// Get all bookings for tenant
  static Future<List<Booking>> getAllBookings(String tenantId) async {
    try {
      final response = await supabase
          .from('bookings')
          .select()
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Booking.fromMap(json))
          .toList();
    } catch (e) {
      print('Error fetching all bookings: $e');
      return [];
    }
  }

  /// Cancel booking with 24-hour refund policy
  static Future<Map<String, dynamic>> cancelBooking({
    required int bookingId,
      required String tenantId,
    }) async {
    try {
      final bookingResponse = await supabase
          .from('bookings')
          .select()
          .eq('id', bookingId)
          .eq('tenant_id', tenantId)
          .maybeSingle();

      if (bookingResponse == null) {
        return {'success': false, 'refundEligible': false, 'error': 'Booking not found'};
      }

      final booking = Booking.fromMap(bookingResponse);

      if (booking.status == BookingStatus.cancelled || booking.status == BookingStatus.declined) {
        return {'success': false, 'refundEligible': false, 'error': 'Booking is already cancelled or declined'};
      }

      // Calculate check-in datetime
      final checkInDateOnly = DateTime(
        booking.checkInDate.year,
        booking.checkInDate.month,
        booking.checkInDate.day,
      );
      final checkInDateTime = DateTime(
        checkInDateOnly.year,
        checkInDateOnly.month,
        checkInDateOnly.day,
        AppConstants.checkInHour,
        AppConstants.checkInMinute,
      );

      final now = DateTime.now();
      final timeDifference = checkInDateTime.difference(now);
      final hoursUntilCheckIn = timeDifference.inHours;
      final bool refundEligible = hoursUntilCheckIn > 24;

      await supabase
          .from('bookings')
          .update({
            'status': BookingStatus.cancelled.name,
            if (refundEligible && booking.paymentStatus == PaymentStatus.paid)
              'payment_status': PaymentStatus.refunded.name,
          })
          .eq('id', bookingId);

      final property = await PropertyService.getPropertyById(booking.propertyId);
      if (property == null) {
        return {'success': false, 'refundEligible': false, 'error': 'Property not found'};
      }

      // Notify homeowner
      await NotificationService.createNotification(
        userId: property.hostId,
        title: 'Booking Cancelled - ${property.title}',
        description: 'A tenant has cancelled their booking for ${property.title}. Check-in was scheduled for ${booking.checkInDate.toIso8601String().split('T')[0]}.',
        type: null,
        bookingId: bookingId,
      );

      // Notify tenant if refund eligible
      if (refundEligible && booking.paymentStatus == PaymentStatus.paid) {
        await NotificationService.createNotification(
          userId: tenantId,
          title: 'Refund Processed for ${property.title}',
          description: 'Your booking cancellation has been processed. A refund of RM ${booking.totalPrice.toStringAsFixed(2)} will be credited to your original payment method within 7-14 business days.',
          type: null,
          bookingId: bookingId,
        );
      }

      return {
        'success': true,
        'refundEligible': refundEligible,
        'booking': booking,
        'property': property,
      };
    } catch (e) {
      print('Error cancelling booking: $e');
      return {'success': false, 'refundEligible': false, 'error': e.toString()};
    }
  }

  /// Sync bookings: decline pending past check-in
  static Future<int> synchronizeBookings() async {
    try {
      final now = DateTime.now();
      
      final response = await supabase
          .from('bookings')
          .select()
          .eq('status', BookingStatus.pending.name);

      final pendingBookings = (response as List)
          .map((json) => Booking.fromMap(json))
          .toList();

      int declinedCount = 0;
      int refundedCount = 0;

      for (final booking in pendingBookings) {
        final checkInDate = booking.checkInDate;
        final checkInDateOnly = DateTime(checkInDate.year, checkInDate.month, checkInDate.day);
        
        final checkInDateTime = DateTime(
          checkInDateOnly.year,
          checkInDateOnly.month,
          checkInDateOnly.day,
          AppConstants.checkInHour,
          AppConstants.checkInMinute,
        );

        print('BookingService: Checking booking ${booking.id} - checkInDateTime: $checkInDateTime, now: $now');

        if (now.isAfter(checkInDateTime) || now.isAtSameMomentAs(checkInDateTime)) {
          if (booking.paymentStatus == PaymentStatus.paid) {
            // Decline and refund
            await supabase
                .from('bookings')
                .update({
                  'status': BookingStatus.declined.name,
                  'payment_status': PaymentStatus.refunded.name,
                })
                .eq('id', booking.id);
            
            refundedCount++;
            print('BookingService: Declined and refunded booking ${booking.id} (past check-in time, was paid)');
            
            try {
              final property = await PropertyService.getPropertyById(booking.propertyId);
              if (property != null) {
                await NotificationService.createNotification(
                  userId: booking.tenantId,
                  title: 'Refund Processed for ${property.title}',
                  description: 'Your booking has been declined and a refund of RM ${booking.totalPrice.toStringAsFixed(2)} has been processed. The refund will be credited to your original payment method within 7-14 business days.',
                  type: null,
                  bookingId: booking.id,
                );
                print('BookingService: Sent refund notification to tenant ${booking.tenantId}');
              }
            } catch (e) {
              print('BookingService: Error sending refund notification: $e');
            }
          } else {
            // Decline unpaid booking
            await supabase
                .from('bookings')
                .update({'status': BookingStatus.declined.name})
                .eq('id', booking.id);
            declinedCount++;
            print('BookingService: Declined booking ${booking.id} (past check-in time, was unpaid)');
          }
        }
      }

      if (declinedCount > 0 || refundedCount > 0) {
        print('BookingService: Synchronized ${declinedCount + refundedCount} booking(s) - declined $declinedCount unpaid, declined and refunded $refundedCount paid bookings past check-in');
      }

      return declinedCount + refundedCount;
    } catch (e) {
      print('Error synchronizing bookings: $e');
      return 0;
    }
  }

  /// Get bookings by property and status
  static Future<List<Booking>> getBookingsByPropertyAndStatus({
    required int propertyId,
    List<BookingStatus>? statuses,
  }) async {
    try {
      final statusList = statuses ?? [BookingStatus.pending, BookingStatus.confirmed];
      
      final response = await supabase
          .from('bookings')
          .select()
          .eq('property_id', propertyId)
          .inFilter('status', statusList.map((s) => s.name).toList())
          .order('check_in_date', ascending: true);

      return (response as List)
          .map((json) => Booking.fromMap(json))
          .toList();
    } catch (e) {
      print('Error fetching bookings by property and status: $e');
      return [];
    }
  }
}

