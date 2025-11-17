import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/features/homeowner/providers/booking_providers.dart';
import 'package:homiego/core/services/supabase_client.dart';
import 'package:homiego/core/services/notification_service.dart';
import 'package:homiego/core/services/property_service.dart';
import 'package:homiego/core/utils/confirmation_dialog.dart';
import 'package:homiego/core/utils/show_snackbar.dart';

final _updatingBookingProvider = StateProvider<int?>((ref) => null);

class HomeownerInboxScreen extends ConsumerWidget {
  const HomeownerInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(homeownerBookingsStreamProvider);
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
              final bool isThisLoading =
                  updatingBookingId == (booking['id'] as int);

              final tenantName =
                  tenantProfile['full_name'] as String? ?? 'Unknown';
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
                        ],
                      ),
                      if (isPending) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
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
        ref.read(_updatingBookingProvider.notifier).state = bookingId;
        try {
          // Get booking details to fetch tenant_id and property info
          final bookingResponse = await supabase
              .from('bookings')
              .select()
              .eq('id', bookingId)
              .maybeSingle();

          if (bookingResponse == null) {
            if (context.mounted) {
              showSnackBar(context, 'Booking not found', isError: true);
              ref.read(_updatingBookingProvider.notifier).state = null;
            }
            return;
          }

          final tenantId = bookingResponse['tenant_id'] as String;
          final propertyId = bookingResponse['property_id'] as int;

          // Update booking status
          await supabase
              .from('bookings')
              .update({'status': 'confirmed'})
              .eq('id', bookingId);

          // Get property details for notification
          final property = await PropertyService.getPropertyById(propertyId);
          final propertyTitle = property?.title ?? 'the property';

          // Create notification for tenant
          await NotificationService.createNotification(
            userId: tenantId,
            title: 'Booking Accepted - $propertyTitle',
            description: 'Great news! Your booking request for $propertyTitle has been accepted.',
            type: null, // General notification type
            bookingId: bookingId,
          );

          if (context.mounted) {
            ref.invalidate(homeownerBookingsStreamProvider);
            showSnackBar(context, 'Booking accepted successfully!');
          }
        } catch (e) {
          if (context.mounted) {
            showSnackBar(context, 'Failed to accept booking: $e',
                isError: true);
          }
        } finally {
          if (context.mounted) {
            ref.read(_updatingBookingProvider.notifier).state = null;
          }
        }
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
        ref.read(_updatingBookingProvider.notifier).state = bookingId;
        try {
          // Get booking details to fetch tenant_id and property info
          final bookingResponse = await supabase
              .from('bookings')
              .select()
              .eq('id', bookingId)
              .maybeSingle();

          if (bookingResponse == null) {
            if (context.mounted) {
              showSnackBar(context, 'Booking not found', isError: true);
              ref.read(_updatingBookingProvider.notifier).state = null;
            }
            return;
          }

          final tenantId = bookingResponse['tenant_id'] as String;
          final propertyId = bookingResponse['property_id'] as int;

          // Update booking status
          await supabase
              .from('bookings')
              .update({'status': 'declined'})
              .eq('id', bookingId);

          // Get property details for notification
          final property = await PropertyService.getPropertyById(propertyId);
          final propertyTitle = property?.title ?? 'the property';

          // Create notification for tenant
          await NotificationService.createNotification(
            userId: tenantId,
            title: 'Booking Declined - $propertyTitle',
            description: 'Unfortunately, your booking request for $propertyTitle has been declined.',
            type: null, // General notification type
            bookingId: bookingId,
          );

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
          if (context.mounted) {
            ref.read(_updatingBookingProvider.notifier).state = null;
          }
        }
      },
    );
  }
}
