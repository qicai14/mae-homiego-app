import 'dart:async';
import '../models/booking.dart';
import '../models/property.dart';
import '../models/notification.dart';
import '../constants/app_constants.dart';
import 'booking_service.dart';
import 'notification_service.dart';
import 'supabase_client.dart';

// Lock to prevent concurrent notification creation
final _notificationCreationLock = <String, bool>{};

enum BookingNotificationType {
  reviewRequested, // At check-out time, paid booking
}

class BookingNotification {
  final BookingNotificationType type;
  final Booking booking;
  final Property property;
  final DateTime notificationTime;

  BookingNotification({
    required this.type,
    required this.booking,
    required this.property,
    required this.notificationTime,
  });
}

class BookingMonitoringService {
  /// Get the check-in datetime for a booking
  static DateTime getCheckInDateTime(DateTime checkInDate) {
    return DateTime(
      checkInDate.year,
      checkInDate.month,
      checkInDate.day,
      AppConstants.checkInHour,
      AppConstants.checkInMinute,
    );
  }

  /// Get the check-out datetime for a booking
  static DateTime getCheckOutDateTime(DateTime checkOutDate) {
    return DateTime(
      checkOutDate.year,
      checkOutDate.month,
      checkOutDate.day,
      AppConstants.checkOutHour,
      AppConstants.checkOutMinute,
    );
  }

  /// Check bookings and return list of notifications that need to be created
  /// This checks for:
  /// 1. Check-out time reached for paid CONFIRMED bookings -> review notification
  /// NOTE: PENDING bookings should be declined by synchronizeBookings, not processed here
  /// NOTE: Payment is done at booking creation, so no payment notifications needed
  static Future<List<BookingNotification>> checkBookings(String tenantId) async {
    final notifications = <BookingNotification>[];
    final now = DateTime.now();

    // Fetch all upcoming bookings (both paid and unpaid)
    final bookings = await BookingService.getUpcomingBookings(tenantId);

    for (final booking in bookings) {
      // PRIORITY FIX: Only process CONFIRMED bookings
      // PENDING bookings should be handled by synchronizeBookings (auto-decline)
      if (booking.status != BookingStatus.confirmed) {
        continue; // Skip pending/declined/cancelled bookings
      }

      final checkOutTime = getCheckOutDateTime(booking.checkOutDate);
      
      // Fetch property for notification
      final propertyResponse = await supabase
          .from('properties')
          .select()
          .eq('id', booking.propertyId)
          .maybeSingle();

      if (propertyResponse == null) continue;
      final property = Property.fromMap(propertyResponse);

      // Check-out time reached, booking is paid
      // Only send review notification if review_status is null (not yet sent/declined)
      if (booking.paymentStatus == PaymentStatus.paid) {
        if (now.isAfter(checkOutTime) || now.isAtSameMomentAs(checkOutTime)) {
          // Only create review notification if review_status is null
          if (booking.reviewStatus == null) {
            notifications.add(BookingNotification(
              type: BookingNotificationType.reviewRequested,
              booking: booking,
              property: property,
              notificationTime: checkOutTime,
            ));
          }
        }
      }
    }

    return notifications;
  }

  /// Create notifications in the database and return created notifications
  /// Uses a lock to prevent concurrent creation of the same notifications
  static Future<List<BookingNotification>> createNotifications(
    String tenantId,
    List<BookingNotification> notifications,
  ) async {
    // Use a lock key based on tenant ID to prevent concurrent notification creation
    final lockKey = 'notifications_$tenantId';
    
    // If another process is already creating notifications for this tenant, wait
    if (_notificationCreationLock[lockKey] == true) {
      print('BookingMonitoringService: Notification creation already in progress for tenant $tenantId, skipping...');
      return [];
    }

    // Acquire lock
    _notificationCreationLock[lockKey] = true;
    
    try {
      final created = <BookingNotification>[];

      for (final notif in notifications) {
        bool success = false;

        switch (notif.type) {
        case BookingNotificationType.reviewRequested:
          // Create notification and set review_status to pending
          success = await NotificationService.createNotification(
            userId: tenantId,
            title: 'How was your stay at ${notif.property.title}?',
            description: 'Your booking has ended. Please leave a review to help other tenants.',
            type: NotificationAction.review,
            bookingId: notif.booking.id,
          );
          
          // Update booking review_status to pending when notification is created
          if (success) {
            try {
              await supabase
                  .from('bookings')
                  .update({'review_status': ReviewStatus.pending.name})
                  .eq('id', notif.booking.id);
            } catch (e) {
              print('BookingMonitoringService: Error updating review_status to pending: $e');
              // Don't fail the whole operation if status update fails
            }
          }
          break;
        }

        if (success) {
          created.add(notif);
        }
      }

      return created;
    } finally {
      // Release lock after a short delay to ensure all notifications are processed
      Future.delayed(const Duration(milliseconds: 500), () {
        _notificationCreationLock[lockKey] = false;
      });
    }
  }

  /// Get the next notification time for a booking
  /// Returns null if no notification is needed
  /// Only handles review notifications (payment is done at booking creation)
  static DateTime? getNextNotificationTime(Booking booking, DateTime now) {
    final checkOutTime = getCheckOutDateTime(booking.checkOutDate);

    if (booking.paymentStatus == PaymentStatus.paid) {
      // If before check-out time, return check-out time
      if (now.isBefore(checkOutTime)) {
        return checkOutTime;
      }
      // Already past checkout, notification needed immediately
      return null;
    }

    return null;
  }

  /// Calculate duration until next notification
  /// Returns null if notification should happen immediately
  static Duration? getDurationUntilNotification(
    Booking booking,
    DateTime now,
  ) {
    final nextTime = getNextNotificationTime(booking, now);
    if (nextTime == null) return null;

    final difference = nextTime.difference(now);
    return difference.isNegative ? null : difference;
  }
}

