import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/profile.dart';
import 'package:homiego/core/models/property.dart' as property_model;
import 'package:homiego/features/homeowner/providers/booking_providers.dart';
import 'package:homiego/features/homeowner/providers/dashboard_providers.dart';
import 'package:homiego/core/services/supabase_client.dart';
import 'package:homiego/features/homeowner/views/homeowner_main_screen.dart';

// --- DASHBOARD WIDGET ---

class HomeownerDashboardScreen extends ConsumerWidget {
  const HomeownerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(homeownerProfileProvider);

    final pendingCount = ref.watch(
        dashboardPropertyCountProvider(property_model.PropertyStatus.pending));
    final approvedCount = ref.watch(
        dashboardPropertyCountProvider(property_model.PropertyStatus.approved));

    final bookingsAsync = ref.watch(dashboardPendingBookingsProvider);

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'Welcome Back, ${profile.fullName ?? ''}!',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              // My Property
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StatusCard(
                    title: 'Inactive Property Listing',
                    icon: Icons.lock_outline,
                    count:
                        pendingCount.maybeWhen(data: (c) => c, orElse: () => 0),
                  ),
                  _StatusCard(
                    title: 'Active Property Listing',
                    icon: Icons.lock_open,
                    count: approvedCount.maybeWhen(
                        data: (c) => c, orElse: () => 0),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              // Pending Booking Request Section
              Text('Pending Booking Request',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              bookingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    _PlaceholderBox('Failed to load requests: ${e.toString()}'),
                data: (bookings) {
                  // --- APPLY .take(3) LIMIT HERE ---
                  final limitedBookings = bookings.take(3).toList();

                  return limitedBookings.isEmpty
                      ? _PlaceholderBox('No pending requests.')
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: limitedBookings.length, // Use limited count
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) => _BookingRequestCard(
                              bookingMap:
                                  limitedBookings[idx]), // Pass map
                        );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Helper Card Widgets (StatusCard unchanged) ---

class _StatusCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;
  const _StatusCard(
      {required this.title, required this.icon, required this.count});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, width: 1.2),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 28, color: theme.colorScheme.primary.withOpacity(0.80)),
            const SizedBox(height: 6),
            Text(title,
                textAlign: TextAlign.center, style: theme.textTheme.labelLarge),
            const SizedBox(height: 10),
            Text('$count',
                style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary)),
          ],
        ),
      ),
    );
  }
}

class _BookingRequestCard extends ConsumerWidget {
  final Map<String, dynamic> bookingMap;
  const _BookingRequestCard({required this.bookingMap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Parse the map data
    final tenantProfile = bookingMap['profiles'] as Map<String, dynamic>? ?? {};
    final tenantName = tenantProfile['full_name'] as String? ?? 'Unknown';
    final tenantAvatarUrl = tenantProfile['avatar_url'] as String?;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.grey[300],
              backgroundImage:
                  tenantAvatarUrl != null ? NetworkImage(tenantAvatarUrl) : null,
              child: tenantAvatarUrl == null
                  ? const Icon(Icons.person, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Request From:',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: Colors.grey[700])),
                  Text(tenantName, 
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          textStyle: theme.textTheme.labelMedium,
                        ),
                        onPressed: () {
                          // Navigate to Inbox (index 2)
                          ref.read(homeownerNavIndexProvider.notifier).state = 2;
                        },
                        child: const Text('View Details'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _PlaceholderBox extends StatelessWidget {
  final String label;
  const _PlaceholderBox(this.label);
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey[700])),
    );
  }
}
