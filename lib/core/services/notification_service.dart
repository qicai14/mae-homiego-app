import '../models/notification.dart';
import '../services/supabase_client.dart';

class NotificationService {
  /// Fetch all notifications for the current user
  static Future<List<Notification>> getNotifications(String userId) async {
    try {
      print('NotificationService: Fetching notifications for user $userId');
      final response = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      print('NotificationService: Raw response: $response');
      
      final notifications = (response as List)
          .map((json) {
            try {
              return Notification.fromMap(json);
            } catch (e) {
              print('NotificationService: Error parsing notification: $e, json: $json');
              return null;
            }
          })
          .whereType<Notification>()
          .toList();
      
      print('NotificationService: Parsed ${notifications.length} notifications');
      return notifications;
    } catch (e) {
      print('Error fetching notifications: $e');
      return [];
    }
  }

  /// Mark a notification as read
  static Future<bool> markAsRead(int notificationId) async {
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
      return true;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read for a user
  static Future<bool> markAllAsRead(String userId) async {
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
      return true;
    } catch (e) {
      print('Error marking all notifications as read: $e');
      return false;
    }
  }

  /// Delete a notification
  static Future<bool> deleteNotification(int notificationId) async {
    try {
      await supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);
      return true;
    } catch (e) {
      print('Error deleting notification: $e');
      return false;
    }
  }

  /// Clear all notifications for a user (delete all)
  static Future<bool> clearInbox(String userId) async {
    try {
      await supabase
          .from('notifications')
          .delete()
          .eq('user_id', userId);
      return true;
    } catch (e) {
      print('Error clearing inbox: $e');
      return false;
    }
  }

  /// Create a notification for a user
  /// Prevents duplicates by checking for existing notifications with same type and booking_id
  /// Does NOT check is_read status to prevent duplicates even if notification was read
  static Future<bool> createNotification({
    required String userId,
    required String title,
    required String description,
    NotificationAction? type,
    int? bookingId,
  }) async {
    try {
      // Check if notification already exists (to avoid duplicates)
      // For payment/review notifications, check by type and booking_id (most reliable)
      // This ensures we don't create duplicate notifications for the same booking
      if (type != null && bookingId != null) {
        final existing = await supabase
            .from('notifications')
            .select()
            .eq('user_id', userId)
            .eq('type', type.name)
            .eq('booking_id', bookingId)
            .maybeSingle();

        if (existing != null) {
          // Notification already exists, don't create duplicate (regardless of read status)
          print('NotificationService: Duplicate notification prevented - ${type.name} for booking $bookingId');
          return true; // Return true because notification exists (successful state)
        }
      } else if (type != null) {
        // Fallback: check by type and title if booking_id is not available
        final existing = await supabase
            .from('notifications')
            .select()
            .eq('user_id', userId)
            .eq('type', type.name)
            .eq('title', title)
            .maybeSingle();

        if (existing != null) {
          print('NotificationService: Duplicate notification prevented - ${type.name} for "$title"');
          return true;
        }
      } else {
        // For notifications without type, check by title and description to prevent duplicates
        final existing = await supabase
            .from('notifications')
            .select()
            .eq('user_id', userId)
            .eq('title', title)
            .eq('description', description)
            .maybeSingle();

        if (existing != null) {
          print('NotificationService: Duplicate notification prevented - "$title"');
          return true;
        }
      }

      await supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'description': description,
        'type': type?.name,
        'booking_id': bookingId,
        'is_read': false,
      });
      print('NotificationService: Created notification - ${type?.name ?? "no type"} for "$title" (booking_id: $bookingId)');
      return true;
    } catch (e) {
      print('Error creating notification: $e');
      return false;
    }
  }
  
  /// Delete notification by booking ID and type (used when payment is completed)
  static Future<bool> deleteNotificationByBooking({
    required String userId,
    required int bookingId,
    required NotificationAction type,
  }) async {
    try {
      await supabase
          .from('notifications')
          .delete()
          .eq('user_id', userId)
          .eq('booking_id', bookingId)
          .eq('type', type.name);
      print('NotificationService: Deleted notification for booking $bookingId (type: ${type.name})');
      return true;
    } catch (e) {
      print('Error deleting notification by booking: $e');
      return false;
    }
  }
}

