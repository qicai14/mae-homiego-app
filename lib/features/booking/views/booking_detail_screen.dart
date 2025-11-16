import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/models/booking.dart';
import 'package:homiego/core/providers/auth_providers.dart';
import 'package:homiego/core/services/booking_service.dart';
import 'package:homiego/core/utils/show_snackbar.dart';
import 'package:homiego/features/booking/views/payment_gateway_screen.dart';
import 'package:intl/intl.dart';

class BookingDetailScreen extends ConsumerStatefulWidget {
  final Property property;

  const BookingDetailScreen({
    super.key,
    required this.property,
  });

  @override
  ConsumerState<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  DateTime? _checkInDate;
  DateTime? _checkOutDate;
  List<Booking> _existingBookings = [];

  @override
  void initState() {
    super.initState();
    _loadExistingBookings();
  }

  Future<void> _loadExistingBookings() async {
    try {
      final bookings = await BookingService.getBookingsByPropertyAndStatus(
        propertyId: widget.property.id,
        statuses: [BookingStatus.pending, BookingStatus.confirmed],
      );
      if (mounted) {
        setState(() {
          _existingBookings = bookings;
        });
      }
    } catch (e) {
      // Silently fail - bookings will be empty, dates won't be blocked
      if (mounted) {
        setState(() {
          _existingBookings = [];
        });
      }
    }
  }

  /// Check if a date overlaps with any existing booking
  /// Returns true if the date is unavailable (overlaps with a booking)
  /// A date is unavailable if:
  /// - It equals check-in (can't check in on same day as another booking's check-in)
  /// - It falls between check-in (exclusive) and check-out (exclusive)
  /// Note: Same-day checkout/check-in is allowed (check-out day = check-in day is OK)
  bool _isDateUnavailable(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    for (final booking in _existingBookings) {
      final checkInOnly = DateTime(
        booking.checkInDate.year,
        booking.checkInDate.month,
        booking.checkInDate.day,
      );
      final checkOutOnly = DateTime(
        booking.checkOutDate.year,
        booking.checkOutDate.month,
        booking.checkOutDate.day,
      );
      
      // Block check-in dates (exact match with another booking's check-in)
      if (dateOnly.isAtSameMomentAs(checkInOnly)) {
        return true;
      }
      
      // Block dates that fall between check-in and check-out (exclusive)
      // Allow check-out day to be used as check-in for next booking (same-day transition)
      if (dateOnly.isAfter(checkInOnly) && dateOnly.isBefore(checkOutOnly)) {
        return true;
      }
    }
    return false;
  }

  int get _numberOfNights {
    if (_checkInDate == null || _checkOutDate == null) return 0;
    return _checkOutDate!.difference(_checkInDate!).inDays;
  }

  double get _subtotal {
    return widget.property.pricePerNight * _numberOfNights;
  }

  double get _totalPrice {
    return _subtotal + widget.property.cleaningFee + widget.property.serviceFee;
  }

  Future<void> _selectCheckInDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _checkInDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: (DateTime date) {
        // Disable dates that overlap with existing bookings
        return !_isDateUnavailable(date);
      },
      helpText: 'Select Check-in Date',
      errorInvalidText: 'This date is unavailable',
    );
    if (picked != null) {
      setState(() {
        _checkInDate = picked;
        // Reset checkout date if it's before or equal to check-in date, or if it overlaps with bookings
        if (_checkOutDate != null && 
            (_checkOutDate!.isBefore(picked.add(const Duration(days: 1))) ||
             _isDateUnavailable(_checkOutDate!))) {
          _checkOutDate = null;
        }
      });
    }
  }

  Future<void> _selectCheckOutDate() async {
    if (_checkInDate == null) {
      showSnackBar(context, 'Please select check-in date first', isError: true);
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _checkOutDate ?? _checkInDate!.add(const Duration(days: 1)),
      firstDate: _checkInDate!.add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: (DateTime date) {
        // Disable dates that overlap with existing bookings
        // Also ensure check-out is after check-in
        if (date.isBefore(_checkInDate!.add(const Duration(days: 1)))) {
          return false;
        }
        return !_isDateUnavailable(date);
      },
      helpText: 'Select Check-out Date',
      errorInvalidText: 'This date is unavailable',
    );
    if (picked != null) {
      // Validate that the selected date range doesn't overlap with any booking
      if (_doesDateRangeOverlap(_checkInDate!, picked)) {
        showSnackBar(context, 'Selected dates overlap with an existing booking', isError: true);
        return;
      }
      setState(() {
        _checkOutDate = picked;
      });
    }
  }

  /// Check if a date range (check-in to check-out) overlaps with any existing booking
  /// Two date ranges overlap if one starts before the other ends and one ends after the other starts
  /// BUT allows same-day checkout/check-in transitions (e.g., existing checkout on Jan 5, new check-in on Jan 5 is OK)
  bool _doesDateRangeOverlap(DateTime checkIn, DateTime checkOut) {
    final checkInOnly = DateTime(checkIn.year, checkIn.month, checkIn.day);
    final checkOutOnly = DateTime(checkOut.year, checkOut.month, checkOut.day);
    
    for (final booking in _existingBookings) {
      final bookingCheckIn = DateTime(
        booking.checkInDate.year,
        booking.checkInDate.month,
        booking.checkInDate.day,
      );
      final bookingCheckOut = DateTime(
        booking.checkOutDate.year,
        booking.checkOutDate.month,
        booking.checkOutDate.day,
      );
      
      // Two ranges overlap if: newCheckIn < bookingCheckOut AND newCheckOut > bookingCheckIn
      // BUT exclude adjacent dates where same-day checkout/check-in is allowed:
      // - If new checkout == existing check-in (new ends when existing starts) → OK, no overlap
      // - If new check-in == existing checkout (new starts when existing ends) → OK, no overlap
      if (checkInOnly.isBefore(bookingCheckOut) && 
          checkOutOnly.isAfter(bookingCheckIn) &&
          !(checkOutOnly.isAtSameMomentAs(bookingCheckIn) || 
            checkInOnly.isAtSameMomentAs(bookingCheckOut))) {
        return true;
      }
    }
    return false;
  }

  void _handleConfirmBooking() {
    if (_checkInDate == null || _checkOutDate == null) {
      showSnackBar(context, 'Please select both check-in and check-out dates', isError: true);
      return;
    }

    if (_numberOfNights <= 0) {
      showSnackBar(context, 'Check-out date must be after check-in date', isError: true);
      return;
    }

    // Final validation: check if the selected date range overlaps with any booking
    if (_doesDateRangeOverlap(_checkInDate!, _checkOutDate!)) {
      showSnackBar(context, 'Selected dates overlap with an existing booking. Please choose different dates.', isError: true);
      return;
    }

    final authState = ref.read(authNotifierProvider);
    final user = authState.value?.user;
    
    if (user == null) {
      showSnackBar(context, 'Please log in to make a booking', isError: true);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentGatewayScreen(
          property: widget.property,
          checkInDate: _checkInDate!,
          checkOutDate: _checkOutDate!,
          totalPrice: _totalPrice,
          numberOfNights: _numberOfNights,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Property Info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.property.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.property.address,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Date Selectors
              Text(
                'Select Dates',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              // Check-in Date
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Check-in Date'),
                  subtitle: Text(
                    _checkInDate == null
                        ? 'Select check-in date'
                        : DateFormat('MMM dd, yyyy').format(_checkInDate!),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _selectCheckInDate,
                ),
              ),
              const SizedBox(height: 12),
              // Check-out Date
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Check-out Date'),
                  subtitle: Text(
                    _checkOutDate == null
                        ? 'Select check-out date'
                        : DateFormat('MMM dd, yyyy').format(_checkOutDate!),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _selectCheckOutDate,
                ),
              ),
              const SizedBox(height: 24),
              // Price Breakdown (shown at bottom)
              if (_numberOfNights > 0) ...[
                Text(
                  'Price Breakdown',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildPriceRow(
                          'RM ${widget.property.pricePerNight.toStringAsFixed(2)} x $_numberOfNights night${_numberOfNights > 1 ? 's' : ''}',
                          'RM ${_subtotal.toStringAsFixed(2)}',
                        ),
                        _buildPriceRow(
                          'Cleaning Fee',
                          'RM ${widget.property.cleaningFee.toStringAsFixed(2)}',
                        ),
                        _buildPriceRow(
                          'Service Fee',
                          'RM ${widget.property.serviceFee.toStringAsFixed(2)}',
                        ),
                        _buildPriceRow(
                          'Total',
                          'RM ${_totalPrice.toStringAsFixed(2)}',
                          isTotal: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_numberOfNights > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      'RM ${_totalPrice.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleConfirmBooking,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Confirm Booking',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                ),
          ),
        ],
      ),
    );
  }
}

