import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/providers/auth_providers.dart';
import 'package:homiego/features/admin/providers/admin_providers.dart';
import 'package:homiego/features/admin/views/manage_listing_screen.dart';
import 'package:homiego/features/admin/views/manage_user_screen.dart';

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
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authNotifierProvider.notifier).signOut();
            },
          )
        ],
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
            label: 'Manage Listing',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Manage User',
          ),
        ],
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
                    'No bookings yet',
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
                    'Has bookings',
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

