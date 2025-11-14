import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/profile.dart';
import 'package:homiego/core/providers/auth_providers.dart';
import 'package:homiego/core/services/supabase_client.dart';
import 'package:homiego/core/utils/confirmation_dialog.dart';
import 'package:homiego/core/utils/show_snackbar.dart';

/// Provider to fetch current authenticated profile (only emits Profile when non-null)
final homeownerProfileProvider = Provider<Profile>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.maybeWhen(
    data: (data) => data.profile!,
    orElse: () => throw Exception('Profile not found'),
  );
});

/// StreamProvider for all bookings for homeowner's properties
/// Uses a StreamController to manually manage the stream with complex queries
final homeownerBookingsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) async* {
  final profile = ref.watch(homeownerProfileProvider);
  
  // First, get all property IDs owned by this homeowner
  final propertyRows = await supabase
      .from('properties')
      .select('id')
      .eq('host_id', profile.id);
  
  final propertyIds = (propertyRows as List<dynamic>).map((e) => e['id'] as int).toList();
  
  if (propertyIds.isEmpty) {
    yield [];
    return;
  }
  
  // Initial fetch
  final initialRows = await supabase
      .from('bookings')
      .select('*, properties:property_id(title), profiles:tenant_id(full_name, avatar_url)')
      .inFilter('property_id', propertyIds)
      .order('created_at', ascending: false);
  
  // Set up a stream that listens to booking changes via Supabase Realtime
  // For now, we'll use a periodic refresh approach since complex joins don't work well with .stream()
  final controller = StreamController<List<Map<String, dynamic>>>();
  
  // Seed the controller with initial data immediately
  controller.add(List<Map<String, dynamic>>.from(initialRows));
  
  // Listen to booking changes for these properties
  final subscription = supabase
      .from('bookings')
      .stream(primaryKey: ['id'])
      .inFilter('property_id', propertyIds)
      .listen((data) async {
        // When bookings change, refetch with joins
        try {
          final refreshedRows = await supabase
              .from('bookings')
              .select('*, properties:property_id(title), profiles:tenant_id(full_name, avatar_url)')
              .inFilter('property_id', propertyIds)
              .order('created_at', ascending: false);
          controller.add(List<Map<String, dynamic>>.from(refreshedRows));
        } catch (e) {
          controller.addError(e);
        }
      });
  
  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });
  
  yield* controller.stream;
});

class HomeownerInboxScreen extends ConsumerWidget {
  const HomeownerInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(homeownerBookingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        centerTitle: true,
      ),
      body: bookingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Failed to load bookings. Please try again later.',
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (bookings) {
          if (bookings.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(36.0),
                child: Text(
                  'No bookings yet.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: bookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final booking = bookings[index];
              final property = booking['properties'] as Map<String, dynamic>? ?? {};
              final tenantProfile = booking['profiles'] as Map<String, dynamic>? ?? {};
              
              final bookingStatus = booking['status'] as String? ?? 'pending';
              final isPending = bookingStatus == 'pending';
              final tenantName = tenantProfile['full_name'] as String? ?? 'Unknown';
              final tenantAvatarUrl = tenantProfile['avatar_url'] as String?;
              final propertyTitle = property['title'] as String? ?? 'Unknown Property';
              final checkInDate = booking['check_in_date'] as String? ?? '';
              final totalPrice = (booking['total_price'] as num?)?.toDouble() ?? 0.0;
              
              // Calculate number of nights (simplified - you might want to use check_out_date if available)
              // For now, we'll just show the check-in date
              
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: tenantAvatarUrl != null
                                ? NetworkImage(tenantAvatarUrl)
                                : null,
                            child: tenantAvatarUrl == null
                                ? const Icon(Icons.person, color: Colors.grey)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tenantName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  propertyTitle,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Check-in: $checkInDate',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[700],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'RM ${totalPrice.toStringAsFixed(2)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(bookingStatus).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              bookingStatus.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: _getStatusColor(bookingStatus),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isPending) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _handleDecline(context, ref, booking['id'] as int),
                                child: const Text('Decline'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _handleAccept(context, ref, booking['id'] as int),
                                child: const Text('Accept'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'declined':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Future<void> _handleAccept(BuildContext context, WidgetRef ref, int bookingId) async {
    showConfirmationDialog(
      context: context,
      title: 'Accept Booking',
      description: 'Are you sure you want to accept this booking request?',
      button1Text: 'Cancel',
      button2Text: 'Accept',
      button2Callback: () async {
        try {
          await supabase
              .from('bookings')
              .update({'status': 'confirmed'})
              .eq('id', bookingId);

          if (context.mounted) {
            showSnackBar(context, 'Booking accepted successfully!');
            // StreamProvider will automatically refresh via Realtime subscription
          }
        } catch (e) {
          if (context.mounted) {
            showSnackBar(context, 'Failed to accept booking: $e', isError: true);
          }
        }
      },
    );
  }

  Future<void> _handleDecline(BuildContext context, WidgetRef ref, int bookingId) async {
    showConfirmationDialog(
      context: context,
      title: 'Decline Booking',
      description: 'Are you sure you want to decline this booking request?',
      button1Text: 'Cancel',
      button2Text: 'Decline',
      button2Callback: () async {
        try {
          await supabase
              .from('bookings')
              .update({'status': 'declined'})
              .eq('id', bookingId);

          if (context.mounted) {
            showSnackBar(context, 'Booking declined.');
            // StreamProvider will automatically refresh via Realtime subscription
          }
        } catch (e) {
          if (context.mounted) {
            showSnackBar(context, 'Failed to decline booking: $e', isError: true);
          }
        }
      },
    );
  }
}
