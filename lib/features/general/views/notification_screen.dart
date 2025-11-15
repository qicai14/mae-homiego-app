import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/notification.dart' as models;
import 'package:homiego/core/providers/auth_providers.dart';
import 'package:homiego/core/services/notification_service.dart';
import 'package:homiego/core/utils/show_snackbar.dart';
import 'package:homiego/widgets/notification_box.dart';
import 'package:homiego/widgets/notification_detail_dialog.dart';

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
    ref.invalidate(notificationsProvider(userId));
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

  void _showNotificationDetail(models.Notification notification, String userId) {
    // Refetch notifications when a notification is clicked
    _refreshNotifications(userId);
    
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
              error: (error, stackTrace) => Center(
                child: Text('Error: $error'),
              ),
              data: (notifications) {
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
                      onTap: () => _showNotificationDetail(notification, userId),
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

