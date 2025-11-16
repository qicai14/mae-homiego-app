import 'package:flutter/material.dart';

/// Dialog widget that asks user if they want to write a review or decline
class ReviewChoiceDialog extends StatelessWidget {
  final String propertyTitle;

  const ReviewChoiceDialog({
    super.key,
    required this.propertyTitle,
  });

  /// Show the review choice dialog
  /// Returns true if user wants to review, false if declined, null if cancelled
  static Future<bool?> show({
    required BuildContext context,
    required String propertyTitle,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ReviewChoiceDialog(propertyTitle: propertyTitle),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Leave a Review?',
        style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        'How was your stay at $propertyTitle? Would you like to share your experience?',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
      actions: [
        // Decline button
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Decline'),
        ),
        // Write Review button
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Write Review'),
        ),
      ],
      actionsAlignment: MainAxisAlignment.end,
    );
  }
}

