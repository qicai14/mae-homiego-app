import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/providers/auth_providers.dart';
import 'package:homiego/core/utils/confirmation_dialog.dart';
import 'package:homiego/core/utils/show_snackbar.dart';
import 'package:homiego/features/homeowner/views/edit_homeowner_profile_screen.dart';
import 'package:homiego/features/homeowner/views/host_verification_screen.dart';

class HomeownerAccountScreen extends ConsumerWidget {
  const HomeownerAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStateAsync = ref.watch(authNotifierProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Account'),
        centerTitle: true,
        actions: [
          authStateAsync.when(
            data: (state) {
              final profile = state.profile;
              if (profile != null && profile.isVerified) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Chip(
                    avatar: const Icon(Icons.verified, color: Colors.green),
                    label: const Text('Verified Account'),
                    backgroundColor: colorScheme.surface,
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
          )
        ],
      ),
      body: authStateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Failed to load account information.',
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (authState) {
          final profile = authState.profile;

          if (profile == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Profile not found. Please log in again.',
                  style:
                      theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Profile Avatar
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  backgroundImage:
                      profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                          ? NetworkImage(profile.avatarUrl!)
                          : null,
                  child: profile.avatarUrl == null || profile.avatarUrl!.isEmpty
                      ? const Icon(Icons.person, size: 50, color: Colors.grey)
                      : null,
                ),
                const SizedBox(height: 24),
                // Profile Information Section
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Name
                        _ProfileInfoRow(
                          label: 'Name',
                          value: profile.fullName ?? 'Not set',
                          onEdit: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const EditHomeownerProfileScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 32),
                        // Contact No
                        _ProfileInfoRow(
                          label: 'Contact No',
                          value: profile.contactNo ?? 'Not set',
                          onEdit: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const EditHomeownerProfileScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 32),
                        // Gender
                        _ProfileInfoRow(
                          label: 'Gender',
                          value: profile.gender ?? 'Not set',
                          onEdit: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const EditHomeownerProfileScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Account Settings Section
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Account Settings',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      // --- 3. ADD CONDITIONAL VERIFICATION TILE ---
                      if (!profile.isVerified) ...[
                        ListTile(
                          leading: const Icon(Icons.shield_outlined),
                          title: const Text('Verify Your Account'),
                          subtitle:
                              const Text('Get a verified badge to build trust'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const HostVerificationScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                      ],
                      ListTile(
                        leading: const Icon(Icons.history),
                        title: const Text('View Property Rental History'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          showSnackBar(context,
                              'Property Rental History feature coming soon!');
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text(
                          'Logout',
                          style: TextStyle(color: Colors.red),
                        ),
                        trailing:
                            const Icon(Icons.chevron_right, color: Colors.red),
                        onTap: () => _handleLogout(context, ref),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleLogout(BuildContext context, WidgetRef ref) {
    showConfirmationDialog(
      context: context,
      title: 'Logout',
      description: 'Are you sure you want to log out?',
      button1Text: 'Cancel',
      button2Text: 'Logout',
      button2Callback: () async {
        try {
          await ref.read(authNotifierProvider.notifier).signOut();
          // Navigation will be handled automatically by AuthGate
        } catch (e) {
          if (context.mounted) {
            showSnackBar(context, 'Failed to log out: $e', isError: true);
          }
        }
      },
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onEdit;

  const _ProfileInfoRow({
    required this.label,
    required this.value,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit, size: 20),
          onPressed: onEdit,
          tooltip: 'Edit $label',
        ),
      ],
    );
  }
}
