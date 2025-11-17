import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/providers/auth_providers.dart';
import 'package:homiego/features/general/views/notification_screen.dart' as notification_screen;
import 'package:homiego/core/models/notification.dart' as models;
import 'package:homiego/features/tenant/views/review_screen.dart';
import 'package:homiego/core/services/booking_service.dart';
import 'package:homiego/core/services/property_service.dart';
import 'package:homiego/core/services/supabase_client.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/models/booking.dart';
import 'package:homiego/core/constants/app_constants.dart';
import 'package:homiego/widgets/review_choice_dialog.dart';

/// Widget that listens for new review notifications and shows snackbars
/// This allows real-time notification features across the app
class NotificationSnackbarListener extends ConsumerStatefulWidget {
  final Widget child;

  const NotificationSnackbarListener({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<NotificationSnackbarListener> createState() =>
      _NotificationSnackbarListenerState();
}

class _NotificationSnackbarListenerState
    extends ConsumerState<NotificationSnackbarListener> {
  Set<int> _seenNotificationIds = {};
  bool _hasInitialized = false;

  void _checkForNewReviewNotifications(
      BuildContext context, List<models.Notification> notifications) {
    final authState = ref.read(authNotifierProvider);
    final userId = authState.value?.user?.id;
    
    if (userId == null) return;

    // On first load, just track existing notifications
    if (!_hasInitialized) {
      _seenNotificationIds = notifications.map((n) => n.id).toSet();
      _hasInitialized = true;
      return;
    }

    // Find new review notifications that we haven't seen
    final newReviewNotifications = notifications.where((notification) {
      return notification.type == models.NotificationAction.review &&
          !_seenNotificationIds.contains(notification.id);
    }).toList();

    // Show snackbar for each new review notification
    if (newReviewNotifications.isNotEmpty && mounted) {
      for (final notification in newReviewNotifications) {
        // Add to seen set
        _seenNotificationIds.add(notification.id);

        // Show snackbar prompting user to leave a review
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your booking has ended! Please leave a review.',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.blue.shade700,
                action: SnackBarAction(
                  label: 'Review',
                  textColor: Colors.white,
                  onPressed: () async {
                    await _handleReviewNotification(context, notification, userId);
                  },
                ),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        });
      }
    }

    // Update seen notifications set
    _seenNotificationIds = notifications.map((n) => n.id).toSet();
  }

  Future<void> _handleReviewNotification(
      BuildContext context,
      models.Notification notification,
      String userId) async {
    try {
      Booking? booking;
      Property? property;

      // Use booking_id from notification if available
      if (notification.bookingId != null) {
        booking = await PropertyService.getBookingById(notification.bookingId!);
        if (booking != null) {
          final propertyResponse = await supabase
              .from('properties')
              .select()
              .eq('id', booking.propertyId)
              .maybeSingle();
          if (propertyResponse != null) {
            property = Property.fromMap(propertyResponse);
          }
        }
      }

      // Fallback: fetch user's paid bookings that have passed checkout
      if (booking == null || property == null) {
        final now = DateTime.now();
        final upcomingBookings = await BookingService.getUpcomingBookings(userId);

        // Find paid bookings that have passed checkout
        final reviewableBookings = upcomingBookings.where((booking) {
          if (booking.paymentStatus != PaymentStatus.paid) return false;

          final checkOutTime = DateTime(
            booking.checkOutDate.year,
            booking.checkOutDate.month,
            booking.checkOutDate.day,
            AppConstants.checkOutHour,
            AppConstants.checkOutMinute,
          );

          return now.isAfter(checkOutTime) ||
              now.isAtSameMomentAs(checkOutTime);
        }).toList();

        if (reviewableBookings.isEmpty) {
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No bookings available for review'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        booking = reviewableBookings.first;

        final propertyResponse = await supabase
            .from('properties')
            .select()
            .eq('id', booking.propertyId)
            .maybeSingle();
        if (propertyResponse != null) {
          property = Property.fromMap(propertyResponse);
        }
      }

      if (!mounted || !context.mounted) {
        return;
      }

      // After fallback logic, booking should always be non-null, but property might be null
      if (property == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error loading property'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final bookingId = booking.id;
      final propertyTitle = property.title;

      // Show dialog asking if user wants to review
      final wantsToReview = await ReviewChoiceDialog.show(
        context: context,
        propertyTitle: propertyTitle,
      );

      if (!mounted || !context.mounted) return;

      if (wantsToReview == false) {
        // User declined - update review_status to declined and delete notification
        final success = await BookingService.updateReviewStatus(
          bookingId: bookingId,
          reviewStatus: ReviewStatus.declined,
        );

        if (success) {
          // Refresh notifications
          ref.invalidate(notification_screen.notificationsProvider(userId));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Review request declined')),
          );
        }
      } else if (wantsToReview == true) {
        // User wants to review - navigate to review screen
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewScreen(
              bookingId: bookingId,
            ),
          ),
        );

        // Refresh notifications after returning
        if (mounted) {
          ref.invalidate(notification_screen.notificationsProvider(userId));
        }
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authStateAsync = ref.watch(authNotifierProvider);

    return authStateAsync.when(
      loading: () => widget.child,
      error: (_, __) => widget.child,
      data: (authState) {
        final userId = authState.user?.id;
        if (userId == null) return widget.child;

        // Listen for new review notifications
        ref.listen(
          notification_screen.notificationsProvider(userId),
          (previous, next) {
            next.whenData((notifications) {
              _checkForNewReviewNotifications(context, notifications);
            });
          },
        );

        return widget.child;
      },
    );
  }
}

