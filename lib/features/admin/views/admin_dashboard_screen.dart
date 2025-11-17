import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/features/admin/providers/admin_providers.dart';
import 'package:homiego/features/admin/views/manage_listing_screen.dart';
import 'package:homiego/features/admin/views/manage_user_screen.dart';
import 'package:homiego/features/admin/views/fraud_detection_screen.dart';
import 'package:homiego/features/general/views/profile_screen.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const _DashboardTab(),
    const ManageListingScreen(),
    const ManageUserScreen(),
    const FraudDetectionScreen(),
    const ProfileScreen(),
  ];

  void changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_work),
            label: 'Listings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shield),
            label: 'Anti-Fraud',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statisticsAsync = ref.watch(rentalStatisticsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rental Statistics',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          statisticsAsync.when(
            data: (stats) => _StatisticsCards(stats: stats),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Card(
              color: Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'Error loading statistics',
                      style: TextStyle(color: Colors.red[700]),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(rentalStatisticsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Analytics Dashboard',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const _AnalyticsDashboard(),
          const SizedBox(height: 32),
          const Text(
            'Bookings Analytics',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const _BookingsAnalyticsDashboard(),
          const SizedBox(height: 32),
          const Text(
            'Fraud Detection',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const _FraudDetectionSummary(),
        ],
      ),
    );
  }
}

class _StatisticsCards extends StatelessWidget {
  final RentalStatistics stats;

  const _StatisticsCards({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Card(
            elevation: 4,
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.home_outlined, size: 48, color: Colors.blue[700]),
                  const SizedBox(height: 12),
                  Text(
                    '${stats.inactiveProperties}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Inactive Properties',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pending or Rejected',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            elevation: 4,
            color: Colors.green[50],
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.home, size: 48, color: Colors.green[700]),
                  const SizedBox(height: 12),
                  Text(
                    '${stats.activeProperties}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[900],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Active Properties',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Approved',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnalyticsDashboard extends ConsumerWidget {
  const _AnalyticsDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fetch additional analytics data
    final statisticsAsync = ref.watch(rentalStatisticsProvider);

    return statisticsAsync.when(
      data: (stats) {
        final totalProperties = stats.activeProperties + stats.inactiveProperties;
        final activePercentage = totalProperties > 0
            ? (stats.activeProperties / totalProperties * 100)
            : 0.0;

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Property Performance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _AnalyticsRow(
                  label: 'Total Properties',
                  value: totalProperties.toString(),
                  icon: Icons.home_work,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                _AnalyticsRow(
                  label: 'Active Rate',
                  value: '${activePercentage.toStringAsFixed(1)}%',
                  icon: Icons.trending_up,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                _AnalyticsRow(
                  label: 'Inactive Rate',
                  value: '${(100 - activePercentage).toStringAsFixed(1)}%',
                  icon: Icons.trending_down,
                  color: Colors.orange,
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                _ProgressBar(
                  label: 'Property Utilization',
                  active: stats.activeProperties,
                  total: totalProperties,
                  activeColor: Colors.green,
                  inactiveColor: Colors.orange,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stack) => Card(
        color: Colors.red[50],
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              Text(
                'Error loading analytics',
                style: TextStyle(color: Colors.red[700]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyticsRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _AnalyticsRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final String label;
  final int active;
  final int total;
  final Color activeColor;
  final Color inactiveColor;

  const _ProgressBar({
    required this.label,
    required this.active,
    required this.total,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    if (total == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No properties available',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      );
    }

    final activePercentage = active / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[200],
              ),
            ),
            FractionallySizedBox(
              widthFactor: activePercentage,
              child: Container(
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: activeColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active: $active',
              style: TextStyle(
                fontSize: 12,
                color: activeColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Inactive: ${total - active}',
              style: TextStyle(
                fontSize: 12,
                color: inactiveColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BookingsAnalyticsDashboard extends ConsumerWidget {
  const _BookingsAnalyticsDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fetch booking analytics data
    final bookingStatsAsync = ref.watch(bookingStatisticsProvider);

    return bookingStatsAsync.when(
      data: (stats) {
        final confirmedPercentage = stats.totalBookings > 0
            ? (stats.confirmedBookings / stats.totalBookings * 100)
            : 0.0;

        return Column(
          children: [
            // Booking Status Cards
            Row(
              children: [
                Expanded(
                  child: _BookingStatusCard(
                    icon: Icons.hourglass_bottom,
                    label: 'Pending',
                    count: stats.pendingBookings,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BookingStatusCard(
                    icon: Icons.check_circle,
                    label: 'Confirmed',
                    count: stats.confirmedBookings,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BookingStatusCard(
                    icon: Icons.cancel,
                    label: 'Declined',
                    count: stats.declinedBookings,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Booking Details Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.event_note, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Booking Performance',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _AnalyticsRow(
                      label: 'Total Bookings',
                      value: stats.totalBookings.toString(),
                      icon: Icons.event_note,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    _AnalyticsRow(
                      label: 'Total Revenue',
                      value: '\$${stats.totalRevenue.toStringAsFixed(2)}',
                      icon: Icons.attach_money,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 16),
                    _AnalyticsRow(
                      label: 'Confirmation Rate',
                      value: '${confirmedPercentage.toStringAsFixed(1)}%',
                      icon: Icons.trending_up,
                      color: Colors.teal,
                    ),
                    const SizedBox(height: 16),
                    _AnalyticsRow(
                      label: 'Paid Bookings',
                      value: '${stats.paidBookings}',
                      icon: Icons.payment,
                      color: Colors.purple,
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    _ProgressBar(
                      label: 'Booking Status Distribution',
                      active: stats.confirmedBookings,
                      total: stats.totalBookings,
                      activeColor: Colors.green,
                      inactiveColor: Colors.orange,
                    ),
                    const SizedBox(height: 24),
                    _ProgressBar(
                      label: 'Payment Collection',
                      active: stats.paidBookings,
                      total: stats.totalBookings,
                      activeColor: Colors.purple,
                      inactiveColor: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stack) => Card(
        color: Colors.red[50],
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              Text(
                'Error loading bookings analytics',
                style: TextStyle(color: Colors.red[700]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingStatusCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _BookingStatusCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FraudDetectionSummary extends ConsumerWidget {
  const _FraudDetectionSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fraudSummaryAsync = ref.watch(systemFraudSummaryProvider);

    return fraudSummaryAsync.when(
      data: (summary) {
        Color getScoreColor(double score) {
          if (score >= 70) return Colors.red;
          if (score >= 40) return Colors.orange;
          return Colors.green;
        }

        return Card(
          elevation: 2,
          child: InkWell(
            onTap: () {
              // Navigate to fraud detection screen
              final adminState = context.findAncestorStateOfType<_AdminDashboardScreenState>();
              if (adminState != null && adminState.mounted) {
                adminState.changeTab(3); // Fraud Detection tab index
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Fraud Detection Overview',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        Icons.arrow_forward,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _FraudStatItem(
                          label: 'Risk Score',
                          value: '${summary.overallScore.toStringAsFixed(1)}%',
                          color: getScoreColor(summary.overallScore),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _FraudStatItem(
                          label: 'Flagged Users',
                          value: '${summary.flaggedUsers}',
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _FraudStatItem(
                          label: 'Flagged Properties',
                          value: '${summary.flaggedProperties}',
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  if (summary.overallScore > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: getScoreColor(summary.overallScore).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: getScoreColor(summary.overallScore).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: getScoreColor(summary.overallScore),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tap to view detailed fraud analysis',
                              style: TextStyle(
                                color: getScoreColor(summary.overallScore),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stack) => Card(
        color: Colors.red[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 32),
              const SizedBox(height: 8),
              Text(
                'Error loading fraud data',
                style: TextStyle(color: Colors.red[700], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FraudStatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _FraudStatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

