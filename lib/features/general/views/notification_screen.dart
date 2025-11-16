import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/notification.dart' as models;
import 'package:homiego/core/models/notification.dart' show NotificationAction;
import 'package:homiego/core/providers/auth_providers.dart';
import 'package:homiego/core/services/notification_service.dart';
import 'package:homiego/core/services/supabase_client.dart';
import 'package:homiego/core/utils/show_snackbar.dart';
import 'package:homiego/widgets/notification_box.dart';
import 'package:homiego/widgets/notification_detail_dialog.dart';
import 'package:homiego/features/tenant/views/review_screen.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/models/booking.dart';
import 'package:homiego/core/services/booking_service.dart';
import 'package:homiego/core/services/property_service.dart';
import 'package:homiego/core/constants/app_constants.dart';
import 'package:homiego/widgets/review_choice_dialog.dart';

// Provider for notifications
final notificationsProvider = FutureProvider.family<List<models.Notification>, String>((ref, userId) {
  return NotificationService.getNotifications(userId);
});

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  Future<void> _refreshNotifications(String userId) async {
    print('NotificationScreen: Refreshing notifications for user $userId');
    try {
      ref.invalidate(notificationsProvider(userId));
      // Force a rebuild by reading the provider again
      await ref.read(notificationsProvider(userId).future);
    } catch (e) {
      print('NotificationScreen: Error refreshing notifications: $e');
    }
  }

  Future<void> _handleMarkAllAsRead(String userId) async {
    final success = await NotificationService.markAllAsRead(userId);
    if (mounted) {
      if (success) {
        showSnackBar(context, 'All notifications marked as read');
        _refreshNotifications(userId);
      } else {
        showSnackBar(context, 'Failed to mark all as read', isError: true);
      }
    }
  }

  Future<void> _handleClearInbox(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Inbox'),
        content: const Text('Are you sure you want to delete all notifications? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await NotificationService.clearInbox(userId);
      if (mounted) {
        if (success) {
          showSnackBar(context, 'Inbox cleared');
          _refreshNotifications(userId);
        } else {
          showSnackBar(context, 'Failed to clear inbox', isError: true);
        }
      }
    }
  }

  Future<void> _handleNotificationTap(models.Notification notification, String userId) async {
    // Refetch notifications when a notification is clicked
    _refreshNotifications(userId);

    // Handle different action types
    if (notification.type == null) {
      // Default behavior: mark as read and show popup detail box
      await NotificationService.markAsRead(notification.id);
      _refreshNotifications(userId);
      _showNotificationDetail(notification, userId);
    } else if (notification.type == models.NotificationAction.review) {
      // Show dialog asking if user wants to review or decline
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
            
            return now.isAfter(checkOutTime) || now.isAtSameMomentAs(checkOutTime);
          }).toList();

          if (reviewableBookings.isEmpty) {
            showSnackBar(context, 'No bookings available for review', isError: true);
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

        if (!mounted || booking == null) {
          showSnackBar(context, 'Error loading booking', isError: true);
          return;
        }
        
        if (property == null) {
          showSnackBar(context, 'Error loading property', isError: true);
          return;
        }

        final bookingId = booking.id; // Store in local variable to avoid null issues
        final propertyTitle = property.title; // Store in local variable

        // Show dialog asking if user wants to review
        final wantsToReview = await ReviewChoiceDialog.show(
          context: context,
          propertyTitle: propertyTitle,
        );

        if (!mounted) return;

        if (wantsToReview == false) {
          // User declined - update review_status to declined and delete notification
          final success = await BookingService.updateReviewStatus(
            bookingId: bookingId,
            reviewStatus: ReviewStatus.declined,
          );
          
          if (success) {
            // Delete the review notification
            await NotificationService.deleteNotificationByBooking(
              userId: userId,
              bookingId: bookingId,
              type: NotificationAction.review,
            );
            _refreshNotifications(userId);
            showSnackBar(context, 'Review request declined');
          } else {
            showSnackBar(context, 'Failed to update review status', isError: true);
          }
        } else if (wantsToReview == true) {
          // User wants to review - navigate to review screen
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReviewScreen(
                bookingId: bookingId,
              ),
            ),
          );
          
          // If review was submitted, refresh notifications (notification will be deleted)
          if (result == true) {
            _refreshNotifications(userId);
          }
        }
        // If wantsToReview is null, user cancelled the dialog - do nothing
      } catch (e) {
        if (mounted) {
          showSnackBar(context, 'Error loading booking: $e', isError: true);
        }
      }
    }
  }

  void _showNotificationDetail(models.Notification notification, String userId) {
    showDialog(
      context: context,
      builder: (context) => NotificationDetailDialog(
        notification: notification,
        onMarkAsRead: () async {
          final success = await NotificationService.markAsRead(notification.id);
          if (mounted) {
            if (success) {
              showSnackBar(context, 'Notification marked as read');
              _refreshNotifications(userId);
              Navigator.pop(context);
            } else {
              showSnackBar(context, 'Failed to mark as read', isError: true);
            }
          }
        },
        onDelete: () async {
          final success = await NotificationService.deleteNotification(notification.id);
          if (mounted) {
            if (success) {
              showSnackBar(context, 'Notification deleted');
              _refreshNotifications(userId);
              Navigator.pop(context);
            } else {
              showSnackBar(context, 'Failed to delete notification', isError: true);
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authStateAsync = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        actions: [
          authStateAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (authState) {
              final userId = authState.user?.id;
              if (userId == null) return const SizedBox.shrink();

              final notificationsAsync = ref.watch(notificationsProvider(userId));
              
              return notificationsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (notifications) {
                  // Hide buttons when notifications are empty
                  if (notifications.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => _handleMarkAllAsRead(userId),
                        child: const Text('Mark all as read'),
                      ),
                      TextButton(
                        onPressed: () => _handleClearInbox(userId),
                        child: const Text('Clear Inbox'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: authStateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('Error loading notifications: $error'),
        ),
        data: (authState) {
          final userId = authState.user?.id;
          if (userId == null) {
            return const Center(
              child: Text('Please log in to view notifications'),
            );
          }

          final notificationsAsync = ref.watch(notificationsProvider(userId));

          return RefreshIndicator(
            onRefresh: () => _refreshNotifications(userId),
            child: notificationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) {
                print('NotificationScreen: Error loading notifications: $error');
                print('NotificationScreen: Stack trace: $stackTrace');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error loading notifications: $error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _refreshNotifications(userId),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              },
              data: (notifications) {
                print('NotificationScreen: Received ${notifications.length} notifications');
                if (notifications.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "You're all catch up!", 
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text("No notifications",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w300,
                            color: Colors.grey,
                          ),
                        )
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) => const Divider(
                    color: Colors.grey,
                    indent: 24,
                    endIndent: 24,
                  ),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return GestureDetector(
                      onTap: () => _handleNotificationTap(notification, userId),
                      child: NotificationBox(notification: notification),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

