// lib/features/homeowner/views/homeowner_inbox_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// --- IMPORT THE CENTRALIZED PROVIDER ---
import 'package:homiego/features/homeowner/providers/booking_providers.dart';
import 'package:homiego/core/services/supabase_client.dart';
import 'package:homiego/core/utils/confirmation_dialog.dart';
import 'package:homiego/core/utils/show_snackbar.dart';

// --- ADDED: Provider to track which booking is currently being updated ---
final _updatingBookingProvider = StateProvider<int?>((ref) => null);

class HomeownerInboxScreen extends ConsumerWidget {
  const HomeownerInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // --- USE THE NEW, REFACTORED STREAM PROVIDER ---
    final bookingsAsync = ref.watch(homeownerBookingsStreamProvider);
    // --- ADDED: Watch the loading state ---
    final updatingBookingId = ref.watch(_updatingBookingProvider);
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
                  'You have no booking requests yet.',
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
              final property =
                  booking['properties'] as Map<String, dynamic>? ?? {};
              final tenantProfile =
                  booking['profiles'] as Map<String, dynamic>? ?? {};

              final bookingStatus = booking['status'] as String? ?? 'pending';
              final isPending = bookingStatus == 'pending';
              // --- ADDED: Check if this specific card is loading ---
              final bool isThisLoading =
                  updatingBookingId == (booking['id'] as int);

              final tenantName =
                  tenantProfile['full_name'] as String? ?? 'Unknown';
              // --- ADDED: Parse the new is_verified boolean ---
              final isTenantVerified =
                  tenantProfile['is_verified'] as bool? ?? false;

              final tenantAvatarUrl = tenantProfile['avatar_url'] as String?;
              final propertyTitle =
                  property['title'] as String? ?? 'Unknown Property';
              final checkInDate = booking['check_in_date'] as String? ?? '';
              final totalPrice =
                  (booking['total_price'] as num?)?.toDouble() ?? 0.0;

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
                                // --- MODIFIED: Replaced Text with Row for verified badge ---
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        tenantName,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    if (isTenantVerified)
                                      Icon(
                                        Icons.verified,
                                        color: theme.primaryColor,
                                        size: 16,
                                      ),
                                  ],
                                ),
                                // --- END MODIFICATION ---
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
                          Icon(Icons.calendar_today,
                              size: 16, color: Colors.grey[600]),
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
                          // --- ADDED: Show loading indicator or status ---
                          if (isThisLoading)
                            const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(bookingStatus)
                                    .withOpacity(0.1),
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
                          // --- END ADDED ---
                        ],
                      ),
                      if (isPending) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                // --- CHANGED: Disable button when loading ---
                                onPressed: isThisLoading
                                    ? null
                                    : () => _handleDecline(
                                        context, ref, booking['id'] as int),
                                child: const Text('Decline'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                // --- CHANGED: Disable button when loading ---
                                onPressed: isThisLoading
                                    ? null
                                    : () => _handleAccept(
                                        context, ref, booking['id'] as int),
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

  Future<void> _handleAccept(
      BuildContext context, WidgetRef ref, int bookingId) async {
    showConfirmationDialog(
      context: context,
      title: 'Accept Booking',
      description: 'Are you sure you want to accept this booking request?',
      button1Text: 'Cancel',
      button2Text: 'Accept',
      button2Callback: () async {
        // --- CHANGED: Set loading state and add finally block ---
        ref.read(_updatingBookingProvider.notifier).state = bookingId;
        try {
          await supabase
              .from('bookings')
              .update({'status': 'confirmed'})
              .eq('id', bookingId);

          if (context.mounted) {
            // --- ADDED: Manually invalidate the stream to force refresh ---
            ref.invalidate(homeownerBookingsStreamProvider);
            showSnackBar(context, 'Booking accepted successfully!');
          }
        } catch (e) {
          if (context.mounted) {
            showSnackBar(context, 'Failed to accept booking: $e',
                isError: true);
          }
        } finally {
          // --- ADDED: Clear loading state ---
          if (context.mounted) {
            ref.read(_updatingBookingProvider.notifier).state = null;
          }
        }
        // --- END CHANGED ---
      },
    );
  }

  Future<void> _handleDecline(
      BuildContext context, WidgetRef ref, int bookingId) async {
    showConfirmationDialog(
      context: context,
      title: 'Decline Booking',
      description: 'Are you sure you want to decline this booking request?',
      button1Text: 'Cancel',
      button2Text: 'Decline',
      button2Callback: () async {
        // --- CHANGED: Set loading state and add finally block ---
        ref.read(_updatingBookingProvider.notifier).state = bookingId;
        try {
          await supabase
              .from('bookings')
              .update({'status': 'declined'})
              .eq('id', bookingId);

          if (context.mounted) {
            // --- ADDED: Manually invalidate the stream to force refresh ---
            ref.invalidate(homeownerBookingsStreamProvider);
            showSnackBar(context, 'Booking declined.');
          }
        } catch (e) {
          if (context.mounted) {
            showSnackBar(context, 'Failed to decline booking: $e',
                isError: true);
          }
        } finally {
          // --- ADDED: Clear loading state ---
          if (context.mounted) {
            ref.read(_updatingBookingProvider.notifier).state = null;
          }
        }
        // --- END CHANGED ---
      },
    );
  }
}