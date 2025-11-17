import 'dart:async';
import '../models/booking.dart';
import '../models/property.dart';
import '../models/notification.dart';
import '../constants/app_constants.dart';
import 'booking_service.dart';
import 'notification_service.dart';
import 'supabase_client.dart';

// Lock for concurrent notification creation
final _notificationCreationLock = <String, bool>{};

enum BookingNotificationType {
  reviewRequested, // Checkout review
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
  /// Get check-in datetime
  static DateTime getCheckInDateTime(DateTime checkInDate) {
    return DateTime(
      checkInDate.year,
      checkInDate.month,
      checkInDate.day,
      AppConstants.checkInHour,
      AppConstants.checkInMinute,
    );
  }

  /// Get check-out datetime
  static DateTime getCheckOutDateTime(DateTime checkOutDate) {
    return DateTime(
      checkOutDate.year,
      checkOutDate.month,
      checkOutDate.day,
      AppConstants.checkOutHour,
      AppConstants.checkOutMinute,
    );
  }

  /// Check bookings for review notifications at checkout
  static Future<List<BookingNotification>> checkBookings(String tenantId) async {
    final notifications = <BookingNotification>[];
    final now = DateTime.now();

    // Fetch upcoming bookings
    final bookings = await BookingService.getUpcomingBookings(tenantId);

    for (final booking in bookings) {
      // Process only confirmed bookings
      if (booking.status != BookingStatus.confirmed) {
        continue; // Skip pending/declined/cancelled bookings
      }

      final checkOutTime = getCheckOutDateTime(booking.checkOutDate);
      
      // Fetch property
      final propertyResponse = await supabase
          .from('properties')
          .select()
          .eq('id', booking.propertyId)
          .maybeSingle();

      if (propertyResponse == null) continue;
      final property = Property.fromMap(propertyResponse);

      // Check if checkout time reached for paid booking
      if (booking.paymentStatus == PaymentStatus.paid) {
        if (now.isAfter(checkOutTime) || now.isAtSameMomentAs(checkOutTime)) {
          // Create review notification if not sent yet
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

  /// Create notifications with lock to prevent duplicates
  static Future<List<BookingNotification>> createNotifications(
    String tenantId,
    List<BookingNotification> notifications,
  ) async {
    // Lock by tenant ID
    final lockKey = 'notifications_$tenantId';
    
    // Skip if already processing
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
          // Create review notification
          success = await NotificationService.createNotification(
            userId: tenantId,
            title: 'How was your stay at ${notif.property.title}?',
            description: 'Your booking has ended. Please leave a review to help other tenants.',
            type: NotificationAction.review,
            bookingId: notif.booking.id,
          );
          
          // Update review status to pending
          if (success) {
            try {
              await supabase
                  .from('bookings')
                  .update({'review_status': ReviewStatus.pending.name})
                  .eq('id', notif.booking.id);
            } catch (e) {
              print('BookingMonitoringService: Error updating review_status to pending: $e');
              // Continue on error
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
      // Release lock after delay
      Future.delayed(const Duration(milliseconds: 500), () {
        _notificationCreationLock[lockKey] = false;
      });
    }
  }

  /// Get next notification time (checkout for review)
  static DateTime? getNextNotificationTime(Booking booking, DateTime now) {
    final checkOutTime = getCheckOutDateTime(booking.checkOutDate);

    if (booking.paymentStatus == PaymentStatus.paid) {
      // Return checkout time if before, null if past
      if (now.isBefore(checkOutTime)) {
        return checkOutTime;
      }
      return null;
    }

    return null;
  }

  /// Calculate duration until next notification
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

