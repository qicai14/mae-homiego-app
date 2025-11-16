import 'package:flutter/material.dart';
import 'package:homiego/core/models/notification.dart' as models;

class NotificationDetailDialog extends StatelessWidget {
  final models.Notification notification;
  final VoidCallback onMarkAsRead;
  final VoidCallback onDelete;

  const NotificationDetailDialog({
    super.key,
    required this.notification,
    required this.onMarkAsRead,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              notification.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            // Description
            Text(
              notification.description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!notification.isRead)
                  TextButton(
                    onPressed: onMarkAsRead,
                    child: const Text('Mark as read'),
                  ),
                TextButton(
                  onPressed: () {
                    onDelete();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('Delete'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

