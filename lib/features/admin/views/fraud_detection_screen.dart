import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/fraud_detection.dart';
import 'package:homiego/features/admin/providers/admin_providers.dart';

class FraudDetectionScreen extends ConsumerWidget {
  const FraudDetectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fraudSummaryAsync = ref.watch(systemFraudSummaryProvider);
    final userScoresAsync = ref.watch(userFraudScoresProvider);
    final propertyScoresAsync = ref.watch(propertyFraudScoresProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fraud Detection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(systemFraudSummaryProvider);
              ref.invalidate(userFraudScoresProvider);
              ref.invalidate(propertyFraudScoresProvider);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // System Overview
            fraudSummaryAsync.when(
              data: (summary) => _SystemOverviewCard(summary: summary),
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
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        'Error loading fraud summary',
                        style: TextStyle(color: Colors.red[700]),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(systemFraudSummaryProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Flagged Users Section
            const Text(
              'Flagged Users',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            userScoresAsync.when(
              data: (scores) => scores.isEmpty
                  ? const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text('No flagged users found'),
                        ),
                      ),
                    )
                  : Column(
                      children: scores
                          .map((score) => _UserFraudCard(score: score))
                          .toList(),
                    ),
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
                  child: Text(
                    'Error: $error',
                    style: TextStyle(color: Colors.red[700]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Flagged Properties Section
            const Text(
              'Flagged Properties',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            propertyScoresAsync.when(
              data: (scores) => scores.isEmpty
                  ? const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text('No flagged properties found'),
                        ),
                      ),
                    )
                  : Column(
                      children: scores
                          .map((score) => _PropertyFraudCard(score: score))
                          .toList(),
                    ),
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
                  child: Text(
                    'Error: $error',
                    style: TextStyle(color: Colors.red[700]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemOverviewCard extends StatelessWidget {
  final SystemFraudSummary summary;

  const _SystemOverviewCard({required this.summary});

  Color _getScoreColor(double score) {
    if (score >= 70) return Colors.red;
    if (score >= 40) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.shield, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'System Fraud Overview',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Overall Risk Score',
                    value: '${summary.overallScore.toStringAsFixed(1)}%',
                    color: _getScoreColor(summary.overallScore),
                    icon: Icons.assessment,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Flagged Users',
                    value: '${summary.flaggedUsers}',
                    color: Colors.orange,
                    icon: Icons.person_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Flagged Properties',
                    value: '${summary.flaggedProperties}',
                    color: Colors.purple,
                    icon: Icons.home_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Fraud Type Distribution',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...summary.flagCounts.entries.map((entry) {
              final typeLabels = {
                'excessive_cancellations': 'Excessive Cancellations',
                'multiple_accounts': 'Multiple Accounts',
                'high_value_anomaly': 'High Value Anomalies',
                'rapid_bookings': 'Rapid Bookings',
              };
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      typeLabels[entry.key] ?? entry.key,
                      style: const TextStyle(fontSize: 14),
                    ),
                    Chip(
                      label: Text('${entry.value}'),
                      backgroundColor: Colors.blue[100],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
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
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _UserFraudCard extends StatelessWidget {
  final UserFraudScore score;

  const _UserFraudCard({required this.score});

  Color _getScoreColor(double score) {
    if (score >= 70) return Colors.red;
    if (score >= 40) return Colors.orange;
    return Colors.yellow;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getScoreColor(score.score),
          child: Text(
            score.score.toStringAsFixed(0),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          score.userName ?? 'User ${score.userId.substring(0, 8)}...',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Score: ${score.score.toStringAsFixed(1)}% | '
          'Bookings: ${score.totalBookings} | '
          'Cancelled: ${score.cancelledBookings}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (score.userEmail != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Email: ${score.userEmail}'),
                  ),
                Text('User ID: ${score.userId}'),
                const SizedBox(height: 8),
                Text('Total Spent: \$${score.totalSpent.toStringAsFixed(2)}'),
                const SizedBox(height: 16),
                const Text(
                  'Fraud Flags:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ...score.flags.map((flag) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning, color: Colors.red[700], size: 20),
                              const SizedBox(width: 8),
                              Text(
                                flag.type.replaceAll('_', ' ').toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            flag.description,
                            style: const TextStyle(fontSize: 13),
                          ),
                          if (flag.metadata.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Details: ${flag.metadata.toString()}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    // Navigate to user details or show more info
                    // You can implement navigation to user management screen
                  },
                  icon: const Icon(Icons.person),
                  label: const Text('View User Details'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyFraudCard extends StatelessWidget {
  final PropertyFraudScore score;

  const _PropertyFraudCard({required this.score});

  Color _getScoreColor(double score) {
    if (score >= 70) return Colors.red;
    if (score >= 40) return Colors.orange;
    return Colors.yellow;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getScoreColor(score.score),
          child: Text(
            score.score.toStringAsFixed(0),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          score.propertyTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Score: ${score.score.toStringAsFixed(1)}% | '
          'Bookings: ${score.totalBookings} | '
          'Avg Price: \$${score.averagePrice.toStringAsFixed(2)}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Property ID: ${score.propertyId}'),
                if (score.hostName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Host: ${score.hostName}'),
                  ),
                const SizedBox(height: 8),
                Text('Highest Price: \$${score.highestPrice.toStringAsFixed(2)}'),
                const SizedBox(height: 16),
                const Text(
                  'Fraud Flags:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ...score.flags.map((flag) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning, color: Colors.red[700], size: 20),
                              const SizedBox(width: 8),
                              Text(
                                flag.type.replaceAll('_', ' ').toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            flag.description,
                            style: const TextStyle(fontSize: 13),
                          ),
                          if (flag.metadata.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Details: ${flag.metadata.toString()}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    // Navigate to property details or show more info
                    // You can implement navigation to property management screen
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('View Property Details'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

