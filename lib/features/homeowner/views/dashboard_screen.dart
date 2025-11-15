import 'package:flutter/material.dart';

class HomeownerDashboardScreen extends StatelessWidget {
  const HomeownerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const Center(child: Text('Homeowner Dashboard')),
    );
  }
}

