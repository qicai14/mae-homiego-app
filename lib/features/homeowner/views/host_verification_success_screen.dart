import 'package:flutter/material.dart';

class HostVerificationSuccessScreen extends StatelessWidget {
  const HostVerificationSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 100,
              ),
              const SizedBox(height: 24),
              Text(
                'Account Verified!',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Your account has been successfully verified.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  // Pop all the way back to the main Account screen
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}