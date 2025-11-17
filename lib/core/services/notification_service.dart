import '../models/notification.dart';
import '../services/supabase_client.dart';

class NotificationService {
  /// Get all notifications for user
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

  /// Mark notification as read
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

  /// Mark all notifications as read
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

  /// Delete notification
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

  /// Clear all notifications
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

  /// Create notification (prevents duplicates)
  static Future<bool> createNotification({
    required String userId,
    required String title,
    required String description,
    NotificationAction? type,
    int? bookingId,
  }) async {
    try {
      // Check for duplicates
      if (type != null && bookingId != null) {
        final existing = await supabase
            .from('notifications')
            .select()
            .eq('user_id', userId)
            .eq('type', type.name)
            .eq('booking_id', bookingId)
            .maybeSingle();

        if (existing != null) {
          print('NotificationService: Duplicate notification prevented - ${type.name} for booking $bookingId');
          return true;
        }
      } else if (type != null) {
        // Check by type and title
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
        // Check by title and description
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
  
  /// Delete notification by booking and type
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

