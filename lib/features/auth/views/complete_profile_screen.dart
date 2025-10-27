import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/providers/auth_providers.dart';
import 'package:homiego/core/utils/show_snackbar.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  // Pre-fill name from signup if it exists
  late final TextEditingController _fullNameController;
  final _contactController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    final initialName = ref.read(authNotifierProvider).value?.profile?.fullName ?? '';
    _fullNameController = TextEditingController(text: initialName);
  }
  
  @override
  void dispose() {
    _fullNameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (_fullNameController.text.isEmpty) {
      showSnackBar(context, 'Please enter your full name', isError: true);
      return;
    }
    
    try {
      await ref.read(authNotifierProvider.notifier).completeProfile(
        _fullNameController.text.trim(),
        _contactController.text.trim(),
      );
      // AuthGate will see the profile is complete and navigate
    } catch(e) {
      showSnackBar(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    ref.listen(authNotifierProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        showSnackBar(context, next.error.toString(), isError: true);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
            },
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Just one last step!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Please confirm your details to continue.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(labelText: 'Full Name*', prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _contactController,
                    decoration: const InputDecoration(labelText: 'Contact No (Optional)', prefixIcon: Icon(Icons.phone_outlined)),
                    keyboardType: TextInputType.phone,
                  ),
                  // You could add more fields here like 'gender', 'location' etc.
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: isLoading ? null : _updateProfile,
                    child: isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                          )
                        : const Text('Save & Continue'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

