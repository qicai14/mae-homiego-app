import 'package:flutter/material.dart';

/// Shows a confirmation dialog with customizable title, description, and buttons.
/// 
/// [button1] is displayed as a TextButton (typically used for Cancel).
/// [button2] is displayed as an ElevatedButton (typically used for Confirm).
/// 
/// Example usage:
/// ```dart
/// showConfirmationDialog(
///   context: context,
///   title: 'Delete Property',
///   description: 'Are you sure you want to delete this property?',
///   button1Text: 'Cancel',
///   button2Text: 'Delete',
///   button2Callback: () {
///     deleteProperty(propertyId);
///   },
/// );
/// ```
void showConfirmationDialog({
  required BuildContext context,
  required String title,
  required String description,
  String button1Text = 'Confirm',
  String button2Text = 'Cancel',
  VoidCallback? button1Callback,
  VoidCallback? button2Callback,
}) {
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          description,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        actions: [
          // Button 1 (TextButton - typically Cancel)
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (button1Callback != null) {
                button1Callback();
              }
            },
            child: Text(button1Text),
          ),
          // Button 2 (ElevatedButton - typically Confirm)
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (button2Callback != null) {
                button2Callback();
              }
            },
            child: Text(button2Text),
          ),
        ],
        actionsAlignment: MainAxisAlignment.end,
      );
    },
  );
}

