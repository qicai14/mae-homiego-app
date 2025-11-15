import 'package:flutter/material.dart';

/// Shows a confirmation dialog with customizable title, description, and buttons.
/// 
/// [context] - The build context required to show the dialog
/// [title] - The title text displayed in bold
/// [description] - The description text displayed in smaller, greyish color
/// [button1Text] - Text for the first button (default: 'Confirm')
/// [button2Text] - Text for the second button (default: 'Cancel')
/// [button1Callback] - Optional callback for the first button
/// [button2Callback] - Optional callback for the second button
/// 
/// When a button is pressed, the dialog is closed first, then the respective
/// callback is triggered if provided. If no callback is provided, the button
/// will only close the dialog.
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
            color: Colors.grey[600],
          ),
        ),
        actions: [
          // Button 1 (Cancel) - TextButton
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (button1Callback != null) {
                button1Callback();
              }
            },
            child: Text(button1Text),
          ),
          // Button 2 (Confirm/Action) - ElevatedButton
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

