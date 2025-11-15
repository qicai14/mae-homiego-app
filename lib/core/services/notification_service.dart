import '../models/notification.dart';
import '../services/supabase_client.dart';

class NotificationService {
  /// Fetch all notifications for the current user
  static Future<List<Notification>> getNotifications(String userId) async {
    try {
      final response = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Notification.fromMap(json))
          .toList();
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
}

