import 'package:flutter/material.dart';

// --- UPDATED showSnackBar function ---
void showSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  int durationSeconds = 4, 
}) {
  // Remove any existing snackbar first to avoid overlap
  ScaffoldMessenger.of(context).removeCurrentSnackBar();
  // Show the new snackbar
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError
          ? Theme.of(context).colorScheme.error // Use error color from theme
          : Theme.of(context).colorScheme.secondary, // Use secondary color for success/info
      duration: Duration(seconds: durationSeconds), // <-- USE the duration parameter
      behavior: SnackBarBehavior.floating, // Optional: Makes it float slightly above bottom
      shape: RoundedRectangleBorder( // Optional: Add rounded corners
        borderRadius: BorderRadius.circular(8.0),
      ),
       action: SnackBarAction( // Optional: Add a dismiss button
         label: 'Dismiss',
         textColor: Colors.white,
         onPressed: () {
           ScaffoldMessenger.of(context).hideCurrentSnackBar();
         },
       ),
    ),
  );
}

