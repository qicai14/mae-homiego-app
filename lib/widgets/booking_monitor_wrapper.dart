import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/providers/auth_providers.dart';
import 'package:homiego/core/providers/booking_timer_provider.dart';
import 'package:homiego/core/models/profile.dart' as profile_models;
import 'package:homiego/core/services/booking_monitoring_service.dart';
import 'package:homiego/core/utils/show_snackbar.dart';
import 'package:homiego/features/general/views/notification_screen.dart' as notification_screen;

/// Wrapper widget that monitors bookings and shows notifications/timers
/// Should be placed at the root level after login
class BookingMonitorWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const BookingMonitorWrapper({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<BookingMonitorWrapper> createState() => _BookingMonitorWrapperState();
}

class _BookingMonitorWrapperState extends ConsumerState<BookingMonitorWrapper> {
  bool _hasCheckedNotifications = false;
  bool _isCheckingNotifications = false;

  @override
  void initState() {
    super.initState();
    // Start monitoring when widget is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startMonitoring();
    });
  }

  void _startMonitoring() {
    final authState = ref.read(authNotifierProvider);
    authState.whenData((state) {
      final user = state.user;
      final profile = state.profile;

      // Only start monitoring for tenants
      if (user != null && profile != null && profile.role == profile_models.UserRole.tenant) {
        // Start timer monitoring (but don't check immediately - let _checkNotifications handle it)
        ref.read(bookingTimerProvider.notifier).startMonitoring(user.id, skipImmediateCheck: true);
        _checkNotifications(user.id);
      }
    });
  }

  Future<void> _checkNotifications(String tenantId) async {
    if (_hasCheckedNotifications || _isCheckingNotifications) return;
    
    _isCheckingNotifications = true;

    try {
      // Only check for CONFIRMED bookings (pending bookings are handled by synchronizeBookings)
      final notifications = await BookingMonitoringService.checkBookings(tenantId);
      
      // Create notifications in database (duplicate prevention is handled in NotificationService and BookingMonitoringService)
      final created = await BookingMonitoringService.createNotifications(tenantId, notifications);
      
      // Refresh notification provider if any notifications were created
      if (created.isNotEmpty && mounted) {
        ref.invalidate(notification_screen.notificationsProvider(tenantId));
        print('BookingMonitorWrapper: Invalidated notification provider after creating ${created.length} notifications');
      }
      
      final reviewNotifications = created
          .where((n) => n.type == BookingNotificationType.reviewRequested)
          .toList();

      if (!mounted) return;

      // Show snackbar for review notifications
      if (reviewNotifications.isNotEmpty && mounted) {
        final notif = reviewNotifications.first;
        showSnackBar(
          context,
          'How was your stay? Leave a review for ${notif.property.title}',
          durationSeconds: 5,
        );
      }

      _hasCheckedNotifications = true;
    } catch (e) {
      debugPrint('Error checking notifications: $e');
    } finally {
      _isCheckingNotifications = false;
    }
  }

  @override
  void dispose() {
    // Stop monitoring when widget is disposed
    ref.read(bookingTimerProvider.notifier).stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth state to restart monitoring on login/logout
    final authStateAsync = ref.watch(authNotifierProvider);

    authStateAsync.whenData((state) {
      final user = state.user;
      final profile = state.profile;

      if (user != null && profile != null && profile.role == profile_models.UserRole.tenant) {
        // Start monitoring if not already started
        // Only check if we haven't already checked (to prevent duplicate checks on rebuild)
        if (!_hasCheckedNotifications && !_isCheckingNotifications) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(bookingTimerProvider.notifier).startMonitoring(user.id, skipImmediateCheck: true);
            _checkNotifications(user.id);
          });
        } else {
          // Just start the timer monitoring without checking notifications
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(bookingTimerProvider.notifier).startMonitoring(user.id, skipImmediateCheck: true);
          });
        }
      } else {
        // Stop monitoring if user logs out or is not a tenant
        ref.read(bookingTimerProvider.notifier).stopMonitoring();
        _hasCheckedNotifications = false;
      }
    });

    return widget.child;
  }
}

