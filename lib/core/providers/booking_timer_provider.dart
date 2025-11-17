import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/services/booking_monitoring_service.dart';
import 'package:homiego/core/services/booking_service.dart' show BookingService;
import 'package:homiego/features/general/views/notification_screen.dart' as notification_screen;

class BookingTimerNotifier extends AsyncNotifier<void> {
  Timer? _timer;
  final List<Timer> _activeTimers = [];

  @override
  Future<void> build() async {
    return;
  }

  /// Start monitoring bookings
  /// [skipImmediateCheck] - skip immediate check to prevent duplicates
  Future<void> startMonitoring(String tenantId, {bool skipImmediateCheck = false}) async {
    debugPrint('BookingTimerNotifier: Starting monitoring for tenant $tenantId (skipImmediateCheck: $skipImmediateCheck)');
    
    stopMonitoring();

    if (!skipImmediateCheck) {
      await _checkAndCreateNotifications(tenantId);
    }

    // Periodic check every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkAndCreateNotifications(tenantId);
    });

    // Set timers for specific notification times
    await _setupNotificationTimers(tenantId);
  }

  /// Stop all timers
  void stopMonitoring() {
    debugPrint('BookingTimerNotifier: Stopping monitoring');
    _timer?.cancel();
    _timer = null;
    
    for (final timer in _activeTimers) {
      timer.cancel();
    }
    _activeTimers.clear();
  }

  /// Check and create notifications
  Future<List<BookingNotification>> _checkAndCreateNotifications(String tenantId) async {
    try {
      final notifications = await BookingMonitoringService.checkBookings(tenantId);
      final created = await BookingMonitoringService.createNotifications(tenantId, notifications);
      
      // Refresh notifications if created
      if (created.isNotEmpty) {
        ref.invalidate(notification_screen.notificationsProvider(tenantId));
        debugPrint('BookingTimerNotifier: Invalidated notification provider after creating ${created.length} notifications');
      }
      
      return created;
    } catch (e) {
      debugPrint('BookingTimerNotifier: Error checking notifications: $e');
      return [];
    }
  }

  /// Set timers for upcoming notifications
  Future<void> _setupNotificationTimers(String tenantId) async {
    try {
      final bookings = await BookingService.getUpcomingBookings(tenantId);
      final now = DateTime.now();

      for (final booking in bookings) {
        final duration = BookingMonitoringService.getDurationUntilNotification(booking, now);
        
        if (duration != null && duration.inMilliseconds > 0) {
          debugPrint(
            'BookingTimerNotifier: Setting timer for booking ${booking.id} in ${duration.inSeconds} seconds',
          );
          
          Timer? notificationTimer;
          notificationTimer = Timer(duration, () async {
            debugPrint('BookingTimerNotifier: Timer fired for booking ${booking.id}');
            final created = await _checkAndCreateNotifications(tenantId);
            debugPrint('BookingTimerNotifier: Created ${created.length} notifications');
            if (notificationTimer != null) {
              _activeTimers.remove(notificationTimer);
            }
          });

          _activeTimers.add(notificationTimer);
        }
      }
    } catch (e) {
      debugPrint('BookingTimerNotifier: Error setting up timers: $e');
    }
  }

  /// Cleanup on dispose
  void cleanup() {
    stopMonitoring();
  }
}

final bookingTimerProvider = AsyncNotifierProvider<BookingTimerNotifier, void>(() {
  return BookingTimerNotifier();
});

