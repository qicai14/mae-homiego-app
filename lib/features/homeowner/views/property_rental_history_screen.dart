import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/booking.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/models/profile.dart';
import 'package:homiego/core/providers/auth_providers.dart';
import 'package:homiego/core/services/property_service.dart';
import 'package:homiego/core/services/supabase_client.dart';
import 'package:homiego/core/constants/app_constants.dart';
import 'package:intl/intl.dart';

class PropertyRentalHistoryScreen extends ConsumerStatefulWidget {
  const PropertyRentalHistoryScreen({super.key});

  @override
  ConsumerState<PropertyRentalHistoryScreen> createState() =>
      _PropertyRentalHistoryScreenState();
}

class _PropertyRentalHistoryScreenState
    extends ConsumerState<PropertyRentalHistoryScreen> {
  List<Booking> _bookings = [];
  Map<int, Property> _properties = {};
  Map<String, Profile> _tenantProfiles = {};
  bool _isLoading = true;
  String? _error;

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
          _error = 'Please log in to view your rental history';
          _isLoading = false;
        });
        return;
      }

      // Get all property IDs owned by this homeowner
      final propertyRows = await supabase
          .from('properties')
          .select('id')
          .eq('host_id', user.id);

      final propertyIds =
          (propertyRows as List<dynamic>).map((e) => e['id'] as int).toList();

      if (propertyIds.isEmpty) {
        setState(() {
          _bookings = [];
          _properties = {};
          _tenantProfiles = {};
          _isLoading = false;
        });
        return;
      }

      // Get all bookings for these properties
      final allBookingsResponse = await supabase
          .from('bookings')
          .select()
          .inFilter('property_id', propertyIds)
          .eq('status', BookingStatus.confirmed.name)
          .order('created_at', ascending: false);

      final allBookings = (allBookingsResponse as List)
          .map((json) => Booking.fromMap(json))
          .toList();

      final now = DateTime.now();

      // Filter: Only show bookings where current date/time > checkout date/time (completed bookings)
      final completedBookings = allBookings.where((booking) {
        // Calculate checkout datetime (checkout date + checkout time from constants)
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

        // Only include if current time is after checkout time
        return now.isAfter(checkOutDateTime);
      }).toList();

      // Sort by check-in date descending (most recent check-in dates first)
      completedBookings.sort((a, b) => b.checkInDate.compareTo(a.checkInDate));

      final properties = <int, Property>{};
      final tenantProfiles = <String, Profile>{};

      // Fetch properties and tenant profiles for all bookings
      for (final booking in completedBookings) {
        try {
          final property =
              await PropertyService.getPropertyById(booking.propertyId);
          if (property != null) {
            properties[booking.propertyId] = property;
          }
        } catch (e) {
          print('Error loading property ${booking.propertyId}: $e');
        }

        try {
          final tenantProfile =
              await supabase.from('profiles').select().eq('id', booking.tenantId).maybeSingle();
          if (tenantProfile != null) {
            tenantProfiles[booking.tenantId] = Profile.fromMap(tenantProfile);
          }
        } catch (e) {
          print('Error loading tenant profile ${booking.tenantId}: $e');
        }
      }

      if (mounted) {
        setState(() {
          _bookings = completedBookings;
          _properties = properties;
          _tenantProfiles = tenantProfiles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading rental history: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Rental History'),
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
              : _bookings.isEmpty
                  ? Center(
                      child: Text(
                        'No rental history found.',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadBookings,
                      child: ListView.builder(
                        itemCount: _bookings.length,
                        itemBuilder: (context, index) {
                          final booking = _bookings[index];
                          final property = _properties[booking.propertyId];
                          final tenantProfile = _tenantProfiles[booking.tenantId];

                          return _BookingAccordion(
                            booking: booking,
                            property: property,
                            tenantProfile: tenantProfile,
                          );
                        },
                      ),
                    ),
    );
  }
}

class _BookingAccordion extends StatefulWidget {
  final Booking booking;
  final Property? property;
  final Profile? tenantProfile;

  const _BookingAccordion({
    required this.booking,
    this.property,
    this.tenantProfile,
  });

  @override
  State<_BookingAccordion> createState() => _BookingAccordionState();
}

class _BookingAccordionState extends State<_BookingAccordion> {
  String _getStatusText(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.declined:
        return 'Declined';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _getPaymentStatusText(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.unpaid:
        return 'Unpaid';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return Colors.green;
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.declined:
        return Colors.red;
      case BookingStatus.cancelled:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final propertyTitle = widget.property?.title ?? 'Unknown Property';
    final tenantName = widget.tenantProfile?.fullName ?? 'Unknown Tenant';
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(
          propertyTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${dateFormat.format(widget.booking.checkInDate)} - ${dateFormat.format(widget.booking.checkOutDate)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(widget.booking.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getStatusText(widget.booking.status),
                    style: TextStyle(
                      fontSize: 12,
                      color: _getStatusColor(widget.booking.status),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _getPaymentStatusText(widget.booking.paymentStatus),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Text(
          'RM ${widget.booking.totalPrice.toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(
                  label: 'Tenant Name',
                  value: tenantName,
                ),
                const SizedBox(height: 8),
                if (widget.property != null) ...[
                  _DetailRow(
                    label: 'Property Type',
                    value: widget.property!.propertyType,
                  ),
                  const SizedBox(height: 8),
                  _DetailRow(
                    label: 'Address',
                    value: widget.property!.address,
                  ),
                  const SizedBox(height: 8),
                ],
                _DetailRow(
                  label: 'Check-in Date',
                  value: dateFormat.format(widget.booking.checkInDate),
                ),
                const SizedBox(height: 8),
                _DetailRow(
                  label: 'Check-out Date',
                  value: dateFormat.format(widget.booking.checkOutDate),
                ),
                const SizedBox(height: 8),
                _DetailRow(
                  label: 'Total Price',
                  value: 'RM ${widget.booking.totalPrice.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 8),
                _DetailRow(
                  label: 'Booking Status',
                  value: _getStatusText(widget.booking.status),
                ),
                const SizedBox(height: 8),
                _DetailRow(
                  label: 'Payment Status',
                  value: _getPaymentStatusText(widget.booking.paymentStatus),
                ),
                const SizedBox(height: 8),
                _DetailRow(
                  label: 'Booking Created',
                  value: DateFormat('MMM dd, yyyy HH:mm')
                      .format(widget.booking.createdAt),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

