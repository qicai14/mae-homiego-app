import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  final double size;
  final String? name;

  const ProfileAvatar({
    super.key,
    required this.size,
    this.name,
  });

  String _getInitial(String? name) {
    if (name == null || name.isEmpty) {
      return 'A';
    }
    return name.trim()[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Text(
        _getInitial(name),
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}

