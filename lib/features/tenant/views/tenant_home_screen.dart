import 'package:flutter/material.dart';

class TenantHomeScreen extends StatelessWidget {
  const TenantHomeScreen ({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const Center(child: Text('TenantHomeScreen')),
    );
  }
}
