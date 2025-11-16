import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/booking.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/providers/auth_providers.dart';
import 'package:homiego/core/services/booking_service.dart';
import 'package:homiego/core/services/property_service.dart';
import 'package:homiego/core/utils/show_snackbar.dart';
import 'package:homiego/core/constants/app_constants.dart';
import 'package:intl/intl.dart';

class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  List<Booking> _upcomingBookings = [];
  Map<int, Property> _properties = {};
  bool _isLoading = true;
  String? _error;
  Set<int> _cancellingBookings = {}; // Track bookings being cancelled

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authState = ref.read(authNotifierProvider);
      final user = authState.value?.user;
      
      if (user == null) {
        setState(() {
          _error = 'Please log in to view your bookings';
          _isLoading = false;
        });
        return;
      }

      final allBookings = await BookingService.getAllBookings(user.id);
      final now = DateTime.now();
      
      // Filter: Only show bookings where:
      // 1. Status is pending OR confirmed
      // 2. AND current date/time < checkout date/time (still can be cancelled)
      final cancellableBookings = allBookings.where((booking) {
        // Check status
        final isValidStatus = booking.status == BookingStatus.pending || 
                             booking.status == BookingStatus.confirmed;
        
        if (!isValidStatus) return false;
        
        // Calculate checkout datetime (checkout date + 12 PM)
        final checkOutDateOnly = DateTime(
          booking.checkOutDate.year,
          booking.checkOutDate.month,
          booking.checkOutDate.day,
        );
        final checkOutDateTime = DateTime(
          checkOutDateOnly.year,
          checkOutDateOnly.month,
          checkOutDateOnly.day,
          AppConstants.checkOutHour,
          AppConstants.checkOutMinute,
        );
        
        // Only include if current time is before checkout time
        return now.isBefore(checkOutDateTime);
      }).toList();
      
      // Sort by check-in date ascending (earliest check-in first)
      // Normalize dates to date-only for accurate comparison
      cancellableBookings.sort((a, b) {
        final dateA = DateTime(a.checkInDate.year, a.checkInDate.month, a.checkInDate.day);
        final dateB = DateTime(b.checkInDate.year, b.checkInDate.month, b.checkInDate.day);
        return dateA.compareTo(dateB);
      });
      
      final properties = <int, Property>{};

      // Fetch properties for all bookings
      for (final booking in cancellableBookings) {
        try {
          final property = await PropertyService.getPropertyById(booking.propertyId);
          if (property != null) {
            properties[booking.propertyId] = property;
          }
        } catch (e) {
          print('Error loading property ${booking.propertyId}: $e');
        }
      }

      if (mounted) {
        setState(() {
          _upcomingBookings = cancellableBookings;
          _properties = properties;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading bookings: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleCancelBooking(Booking booking) async {
    // Check if already cancelling
    if (_cancellingBookings.contains(booking.id)) {
      return;
    }

    // Calculate check-in datetime
    final checkInDateOnly = DateTime(
      booking.checkInDate.year,
      booking.checkInDate.month,
      booking.checkInDate.day,
    );
    final checkInDateTime = DateTime(
      checkInDateOnly.year,
      checkInDateOnly.month,
      checkInDateOnly.day,
      AppConstants.checkInHour,
      AppConstants.checkInMinute,
    );

    final now = DateTime.now();
    final timeDifference = checkInDateTime.difference(now);
    final hoursUntilCheckIn = timeDifference.inHours;
    final bool refundEligible = hoursUntilCheckIn > 24;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to cancel this booking?'),
            const SizedBox(height: 16),
            if (refundEligible)
              Text(
                'You are eligible for a full refund (excluding service fees) as your check-in is more than 24 hours away.',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              Text(
                'Your check-in is 24 hours or less away. Cancellation will not be eligible for a refund.',
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _cancellingBookings.add(booking.id);
    });

    try {
      final authState = ref.read(authNotifierProvider);
      final user = authState.value?.user;
      
      if (user == null) {
        if (mounted) {
          showSnackBar(context, 'Error: Not logged in.', isError: true);
        }
        return;
      }

      final result = await BookingService.cancelBooking(
        bookingId: booking.id,
        tenantId: user.id,
      );

      if (mounted) {
        if (result['success'] == true) {
          // Show snackbar for refund if eligible
          if (result['refundEligible'] == true && booking.paymentStatus == PaymentStatus.paid) {
            showSnackBar(
              context,
              'Booking cancelled successfully. A refund of RM ${booking.totalPrice.toStringAsFixed(2)} will be processed within 7-14 business days.',
            );
          } else {
            showSnackBar(context, 'Booking cancelled successfully.');
          }

          // Reload bookings
          await _loadBookings();
        } else {
          showSnackBar(
            context,
            result['error'] ?? 'Failed to cancel booking.',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Error cancelling booking: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _cancellingBookings.remove(booking.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadBookings,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _upcomingBookings.isEmpty
                  ? Center(
                      child: Text(
                        'No upcoming bookings found.',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadBookings,
                      child: ListView.builder(
                        itemCount: _upcomingBookings.length,
                        itemBuilder: (context, index) {
                          final booking = _upcomingBookings[index];
                          final property = _properties[booking.propertyId];
                          final isCancelling = _cancellingBookings.contains(booking.id);
                          
                          return _BookingCard(
                            booking: booking,
                            property: property,
                            isCancelling: isCancelling,
                            onCancel: () => _handleCancelBooking(booking),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final Property? property;
  final bool isCancelling;
  final VoidCallback onCancel;

  const _BookingCard({
    required this.booking,
    this.property,
    required this.isCancelling,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final propertyTitle = property?.title ?? 'Unknown Property';
    final dateFormat = DateFormat('MMM dd, yyyy');

    // Calculate check-in datetime for refund eligibility
    final checkInDateOnly = DateTime(
      booking.checkInDate.year,
      booking.checkInDate.month,
      booking.checkInDate.day,
    );
    final checkInDateTime = DateTime(
      checkInDateOnly.year,
      checkInDateOnly.month,
      checkInDateOnly.day,
      AppConstants.checkInHour,
      AppConstants.checkInMinute,
    );

    final now = DateTime.now();
    final timeDifference = checkInDateTime.difference(now);
    final hoursUntilCheckIn = timeDifference.inHours;
    final bool refundEligible = hoursUntilCheckIn > 24;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    propertyTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                Text(
                  'RM ${booking.totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '${dateFormat.format(booking.checkInDate)} - ${dateFormat.format(booking.checkOutDate)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    property?.address ?? 'Address not available',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (refundEligible)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Refund Eligible',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'No Refund',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ElevatedButton(
                  onPressed: isCancelling ? null : onCancel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12)
                  ),
                  child: isCancelling
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Cancel Booking'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

