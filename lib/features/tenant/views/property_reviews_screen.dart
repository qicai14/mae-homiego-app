import 'package:flutter/material.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/models/review.dart';
import 'package:homiego/core/services/property_service.dart';
import 'package:intl/intl.dart';

enum ReviewFilter {
  latest,
  oldest,
  highRated, // 4-5 stars
  lowRated, // 1-3 stars
}

class PropertyReviewsScreen extends StatefulWidget {
  final Property property;

  const PropertyReviewsScreen({
    super.key,
    required this.property,
  });

  @override
  State<PropertyReviewsScreen> createState() => _PropertyReviewsScreenState();
}

class _PropertyReviewsScreenState extends State<PropertyReviewsScreen> {
  List<Review> _allReviews = [];
  List<Review> _filteredReviews = [];
  ReviewFilter _selectedFilter = ReviewFilter.latest;
  bool _isLoading = true;
  Map<int, String> _tenantNames = {}; // Cache for tenant names

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final reviews = await PropertyService.getPropertyReviews(widget.property.id);
      
      // Load tenant names for all reviews
      final tenantNameFutures = reviews.map((review) async {
        try {
          final booking = await PropertyService.getBookingById(review.bookingId);
          if (booking != null) {
            final tenantName = await PropertyService.getTenantName(booking.tenantId);
            return MapEntry(review.id, tenantName ?? 'Anonymous');
          }
        } catch (e) {
          print('Error loading tenant name for review ${review.id}: $e');
        }
        return MapEntry(review.id, 'Anonymous');
      });

      final tenantNames = await Future.wait(tenantNameFutures);
      final tenantNameMap = Map<int, String>.fromEntries(tenantNames);

      if (mounted) {
        setState(() {
          _allReviews = reviews;
          _tenantNames = tenantNameMap;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilter() {
    List<Review> filtered = List.from(_allReviews);

    switch (_selectedFilter) {
      case ReviewFilter.latest:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case ReviewFilter.oldest:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case ReviewFilter.highRated:
        filtered = filtered.where((r) => r.rating >= 4).toList();
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by latest within high rated
        break;
      case ReviewFilter.lowRated:
        filtered = filtered.where((r) => r.rating <= 3).toList();
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by latest within low rated
        break;
    }

    setState(() {
      _filteredReviews = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reviews - ${widget.property.title}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allReviews.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.reviews_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No reviews yet',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Filter buttons
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('Latest', ReviewFilter.latest),
                            const SizedBox(width: 8),
                            _buildFilterChip('Oldest', ReviewFilter.oldest),
                            const SizedBox(width: 8),
                            _buildFilterChip('High Rated (4-5)', ReviewFilter.highRated),
                            const SizedBox(width: 8),
                            _buildFilterChip('Low Rated (1-3)', ReviewFilter.lowRated),
                          ],
                        ),
                      ),
                    ),
                    // Reviews count
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(
                            '${_filteredReviews.length} review${_filteredReviews.length != 1 ? 's' : ''}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          if (_selectedFilter != ReviewFilter.latest && _filteredReviews.length != _allReviews.length)
                            Text(
                              ' of ${_allReviews.length}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                        ],
                      ),
                    ),
                    // Reviews list
                    Expanded(
                      child: _filteredReviews.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.filter_alt_outlined, size: 64, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No reviews match this filter',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _filteredReviews.length,
                              itemBuilder: (context, index) {
                                return _buildReviewCard(_filteredReviews[index]);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildFilterChip(String label, ReviewFilter filter) {
    final isSelected = _selectedFilter == filter;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = filter;
          });
          _applyFilter();
        }
      },
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
      checkmarkColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    final userName = _tenantNames[review.id] ?? 'Anonymous';
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (index) => Icon(
                              index < review.rating ? Icons.star : Icons.star_border,
                              size: 18,
                              color: Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dateFormat.format(review.createdAt),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (review.comment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                review.comment,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

