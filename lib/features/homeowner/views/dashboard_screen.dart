import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/profile.dart';
import 'package:homiego/core/models/property.dart' as property_model;
import 'package:homiego/core/models/booking.dart' as booking_model;
import 'package:homiego/core/models/review.dart';
import 'package:homiego/core/providers/auth_providers.dart';
import 'package:homiego/core/services/supabase_client.dart';

/// --- PROVIDERS ---

/// Provider to fetch current authenticated profile (only emits Profile when non-null)
final homeownerProfileProvider = Provider<Profile>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.maybeWhen(
    data: (data) => data.profile!,
    orElse: () => throw Exception('Profile not found'),
  );
});

/// Property count by status for this homeowner
final propertyCountProvider = FutureProvider.family<int, property_model.PropertyStatus>((ref, status) async {
  final profile = ref.watch(homeownerProfileProvider);
  final data = await supabase
      .from('properties')
      .select('id')
      .eq('host_id', profile.id)
      .eq('status', status.name);
  return (data as List).length;
});

/// Pending booking requests for homeowner's properties (limit 3)
final pendingBookingRequestsProvider = FutureProvider<List<booking_model.Booking>>((ref) async {
  final profile = ref.watch(homeownerProfileProvider);
  final propertyRows = await supabase
      .from('properties')
      .select('id')
      .eq('host_id', profile.id);
  final propertyIds = (propertyRows as List<dynamic>).map((e) => e['id'] as int).toList();
  if (propertyIds.isEmpty) return [];
  final rows = await supabase
      .from('bookings')
      .select()
      .inFilter('property_id', propertyIds)
      .eq('status', 'pending')
      .order('created_at', ascending: false)
      .limit(3);
  return (rows as List<dynamic>).map((map) => booking_model.Booking.fromMap(map)).toList();
});

/// Latest reviews for homeowner's properties (limit 3)
final latestReviewsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final profile = ref.watch(homeownerProfileProvider);
  final propertyRows = await supabase
      .from('properties')
      .select('id')
      .eq('host_id', profile.id);
  final propertyIds = (propertyRows as List<dynamic>).map((e) => e['id'] as int).toList();
  if (propertyIds.isEmpty) return [];
  // Join reviews + bookings + tenant profile
  final reviewRows = await supabase
      .from('reviews')
      .select('*,bookings:booking_id(tenant_id),profiles:bookings.tenant_id(full_name,avatar_url)') 
      .inFilter('bookings.property_id', propertyIds)
      .order('created_at', ascending: false)
      .limit(3);
  return List<Map<String, dynamic>>.from(reviewRows ?? []);
});

// --- DASHBOARD WIDGET ---

class HomeownerDashboardScreen extends ConsumerWidget {
  const HomeownerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(homeownerProfileProvider);
    final pendingCount = ref.watch(propertyCountProvider(property_model.PropertyStatus.pending));
    final approvedCount = ref.watch(propertyCountProvider(property_model.PropertyStatus.approved));
    final bookingsAsync = ref.watch(pendingBookingRequestsProvider);
    final reviewsAsync = ref.watch(latestReviewsProvider);
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
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              // My Property
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StatusCard(
                    title: 'Inactive Property Listing',
                    icon: Icons.lock_outline,
                    count: pendingCount.maybeWhen(data: (c) => c, orElse: () => 0),
                  ),
                  _StatusCard(
                    title: 'Active Property Listing',
                    icon: Icons.lock_open,
                    count: approvedCount.maybeWhen(data: (c) => c, orElse: () => 0),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              // Pending Booking Request Section
              Text('Pending Booking Request', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              bookingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _PlaceholderBox('Failed to load requests.'),
                data: (bookings) => bookings.isEmpty
                    ? _PlaceholderBox('No pending requests.')
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: bookings.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) => _BookingRequestCard(booking: bookings[idx]),
                      ),
              ),
              const SizedBox(height: 28),
              // Latest Review Section
              Text('Latest Review', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              reviewsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _PlaceholderBox('Failed to load reviews.'),
                data: (reviews) => reviews.isEmpty
                    ? _PlaceholderBox('No reviews yet.')
                    : SizedBox(
                        height: 138,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: reviews.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) => _ReviewCard(reviewMap: reviews[idx]),
                        ),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Helper Card Widgets ---

class _StatusCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;
  const _StatusCard({required this.title, required this.icon, required this.count});
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
            Icon(icon, size: 28, color: theme.colorScheme.primary.withOpacity(0.80)),
            const SizedBox(height: 6),
            Text(title, textAlign: TextAlign.center, style: theme.textTheme.labelLarge),
            const SizedBox(height: 10),
            Text('$count', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary)),
          ],
        ),
      ),
    );
  }
}

class _BookingRequestCard extends StatelessWidget {
  final booking_model.Booking booking;
  const _BookingRequestCard({required this.booking});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // NOTE: In a real app, you'd join with property, tenant profile for more info
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            CircleAvatar(radius: 26, child: Icon(Icons.person)), // Placeholder, replace w/ tenant avatar
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Request From:', style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey[700])),
                  Text('John Doe', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)), // TODO fetch tenant name!
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      OutlinedButton(onPressed: () {}, child: const Text('Accept')),
                      const SizedBox(width: 8),
                      OutlinedButton(onPressed: () {}, child: const Text('Decline')), // TODO
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

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> reviewMap;
  const _ReviewCard({required this.reviewMap});
  @override
  Widget build(BuildContext context) {
    final review = Review.fromMap(reviewMap);
    final profile = reviewMap['profiles'] ?? {};
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 20, backgroundColor: Colors.grey[300], backgroundImage: profile['avatar_url'] != null ? NetworkImage(profile['avatar_url']) : null, child: profile['avatar_url'] == null ? const Icon(Icons.person) : null),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Review From:', style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey[600], fontWeight: FontWeight.w500)),
                      Text(profile['full_name'] ?? 'John Doe', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Text('"${review.comment}"', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${review.rating}', style: theme.textTheme.bodyMedium),
                  const SizedBox(width: 4),
                  const Icon(Icons.star, color: Colors.amber, size: 18),
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
      child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
    );
  }
}

