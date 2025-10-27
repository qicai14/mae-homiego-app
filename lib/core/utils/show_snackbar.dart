import 'package:flutter/material.dart';

void showSnackBar(BuildContext context, String message, {bool isError = false}) {
  // Ensure we don't try to show a snackbar if the widget is no longer in the tree
  if (!context.mounted) return;
  
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError
          ? Theme.of(context).colorScheme.error
          : Theme.of(context).colorScheme.secondary,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

