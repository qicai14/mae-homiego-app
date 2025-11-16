import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/profile.dart';
import 'package:homiego/features/admin/providers/admin_providers.dart';

class UserDetailScreen extends ConsumerStatefulWidget {
  final Profile profile;

  const UserDetailScreen({
    super.key,
    required this.profile,
  });

  @override
  ConsumerState<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends ConsumerState<UserDetailScreen> {
  late Profile _currentProfile;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _currentProfile = widget.profile;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue[400]!,
                    Colors.blue[600]!,
                  ],
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    backgroundImage: _currentProfile.avatarUrl != null
                        ? NetworkImage(_currentProfile.avatarUrl!)
                        : null,
                    child: _currentProfile.avatarUrl == null
                        ? Text(
                            _currentProfile.fullName?.isNotEmpty == true
                                ? _currentProfile.fullName![0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentProfile.fullName ?? 'No Name',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Chip(
                        label: Text(
                          _currentProfile.role.name.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          _currentProfile.isVerified ? 'VERIFIED' : 'PENDING',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: _currentProfile.isVerified
                            ? Colors.green.withOpacity(0.7)
                            : Colors.orange.withOpacity(0.7),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Profile Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contact Information
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Contact Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_currentProfile.contactNo != null)
                            _DetailRow(
                              icon: Icons.phone,
                              label: 'Phone',
                              value: _currentProfile.contactNo!,
                            ),
                          if (_currentProfile.location != null) ...[
                            if (_currentProfile.contactNo != null) const SizedBox(height: 12),
                            _DetailRow(
                              icon: Icons.location_on,
                              label: 'Location',
                              value: _currentProfile.location!,
                            ),
                          ],
                          if (_currentProfile.gender != null) ...[
                            if (_currentProfile.location != null || _currentProfile.contactNo != null)
                              const SizedBox(height: 12),
                            _DetailRow(
                              icon: Icons.person,
                              label: 'Gender',
                              value: _currentProfile.gender!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bio Section
                  if (_currentProfile.shortBio != null && _currentProfile.shortBio!.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bio',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _currentProfile.shortBio!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Account Information
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Account Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _InfoRow(
                            label: 'User ID',
                            value: _currentProfile.id,
                          ),
                          _InfoRow(
                            label: 'Role',
                            value: _currentProfile.role.name.toUpperCase(),
                          ),
                          _InfoRow(
                            label: 'Verification Status',
                            value: _currentProfile.isVerified ? 'Verified' : 'Not Verified',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Verification Actions
                  Card(
                    color: _currentProfile.isVerified 
                        ? Colors.orange[50] 
                        : Colors.green[50],
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _currentProfile.isVerified 
                                    ? Icons.verified_user 
                                    : Icons.pending_actions,
                                color: _currentProfile.isVerified 
                                    ? Colors.orange[700] 
                                    : Colors.green[700],
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Verification Management',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _currentProfile.isVerified 
                                      ? Colors.orange[900] 
                                      : Colors.green[900],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _currentProfile.isVerified
                                ? 'This user is currently verified. You can revoke their verification status if needed.'
                                : 'This user is not verified. You can verify them to grant access to additional features.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: _isUpdating
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                : ElevatedButton.icon(
                                    onPressed: () => _handleVerificationToggle(context, ref),
                                    icon: Icon(
                                      _currentProfile.isVerified 
                                          ? Icons.block 
                                          : Icons.check_circle,
                                      size: 20,
                                    ),
                                    label: Text(
                                      _currentProfile.isVerified 
                                          ? 'Revoke Verification' 
                                          : 'Verify User',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _currentProfile.isVerified 
                                          ? Colors.orange 
                                          : Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleVerificationToggle(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(
              _currentProfile.isVerified ? Icons.block : Icons.check_circle,
              color: _currentProfile.isVerified ? Colors.orange : Colors.green,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              _currentProfile.isVerified 
                  ? 'Revoke Verification' 
                  : 'Verify User',
            ),
          ],
        ),
        content: Text(
          _currentProfile.isVerified
              ? 'Are you sure you want to revoke verification for "${_currentProfile.fullName ?? 'this user'}"?'
              : 'Are you sure you want to verify "${_currentProfile.fullName ?? 'this user'}"?',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _currentProfile.isVerified 
                  ? Colors.orange 
                  : Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(_currentProfile.isVerified ? 'Revoke' : 'Verify'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      await ref.read(
        updateProfileVerificationProvider({
          'profile_id': _currentProfile.id,
          'is_verified': !_currentProfile.isVerified,
        }).future,
      );

      // Update local state
      setState(() {
        _currentProfile = Profile(
          id: _currentProfile.id,
          role: _currentProfile.role,
          fullName: _currentProfile.fullName,
          contactNo: _currentProfile.contactNo,
          gender: _currentProfile.gender,
          avatarUrl: _currentProfile.avatarUrl,
          shortBio: _currentProfile.shortBio,
          location: _currentProfile.location,
          isVerified: !_currentProfile.isVerified,
        );
        _isUpdating = false;
      });

      // Invalidate providers to refresh lists
      ref.invalidate(allProfilesProvider);
      ref.invalidate(unverifiedProfilesProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  _currentProfile.isVerified 
                      ? Icons.check_circle 
                      : Icons.info,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  _currentProfile.isVerified
                      ? 'User verified successfully'
                      : 'Verification revoked successfully',
                ),
              ],
            ),
            backgroundColor: _currentProfile.isVerified 
                ? Colors.green 
                : Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUpdating = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

