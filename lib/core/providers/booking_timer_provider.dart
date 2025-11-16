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
    // Timer provider is initialized but doesn't need initial state
    return;
  }

  /// Start monitoring bookings for a tenant
  /// [skipImmediateCheck] - if true, skips the immediate notification check (used to prevent duplicates)
  Future<void> startMonitoring(String tenantId, {bool skipImmediateCheck = false}) async {
    debugPrint('BookingTimerNotifier: Starting monitoring for tenant $tenantId (skipImmediateCheck: $skipImmediateCheck)');
    
    // Stop any existing timers
    stopMonitoring();

    // Only do immediate check if not skipped (to prevent duplicate notifications on login)
    if (!skipImmediateCheck) {
      await _checkAndCreateNotifications(tenantId);
    }

    // Set up periodic check (every minute) to catch any missed notifications
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkAndCreateNotifications(tenantId);
    });

    // Also set up timers for specific notification times
    await _setupNotificationTimers(tenantId);
  }

  /// Stop all monitoring timers
  void stopMonitoring() {
    debugPrint('BookingTimerNotifier: Stopping monitoring');
    _timer?.cancel();
    _timer = null;
    
    for (final timer in _activeTimers) {
      timer.cancel();
    }
    _activeTimers.clear();
  }

  /// Check bookings and create notifications immediately if needed
  /// Returns list of created notifications
  Future<List<BookingNotification>> _checkAndCreateNotifications(String tenantId) async {
    try {
      final notifications = await BookingMonitoringService.checkBookings(tenantId);
      final created = await BookingMonitoringService.createNotifications(tenantId, notifications);
      
      // Refresh notification provider if any notifications were created
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

  /// Set up timers for each upcoming notification
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
            // Remove timer from active list after firing
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

  /// Cleanup method called when provider is disposed
  void cleanup() {
    stopMonitoring();
  }
}

final bookingTimerProvider = AsyncNotifierProvider<BookingTimerNotifier, void>(() {
  return BookingTimerNotifier();
});

