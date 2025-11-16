import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/booking.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/services/booking_service.dart';
import 'package:homiego/core/services/notification_service.dart';
import 'package:homiego/core/services/supabase_client.dart';
import 'package:homiego/core/models/notification.dart';
import 'package:homiego/core/utils/show_snackbar.dart';
import 'package:intl/intl.dart';

class BookingPaymentDetailScreen extends ConsumerStatefulWidget {
  final Booking booking;
  final Property property;

  const BookingPaymentDetailScreen({
    super.key,
    required this.booking,
    required this.property,
  });

  @override
  ConsumerState<BookingPaymentDetailScreen> createState() => _BookingPaymentDetailScreenState();
}

class _BookingPaymentDetailScreenState extends ConsumerState<BookingPaymentDetailScreen> {
  String? _selectedPaymentMethod;
  bool _isProcessing = false;

  final List<Map<String, String>> _paymentMethods = [
    {'name': 'Visa', 'icon': 'assets/images/visa.png'},
    {'name': 'Mastercard', 'icon': 'assets/images/mastercard.png'},
    {'name': 'PayPal', 'icon': 'assets/images/paypal.png'},
    {'name': 'GrabPay', 'icon': 'assets/images/grabpay.png'},
  ];

  int get _numberOfNights {
    return widget.booking.checkOutDate.difference(widget.booking.checkInDate).inDays;
  }

  Future<void> _handleProceedWithPayment() async {
    if (_selectedPaymentMethod == null) {
      showSnackBar(context, 'Please select a payment method', isError: true);
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final success = await BookingService.updatePaymentStatus(
        bookingId: widget.booking.id,
        paymentStatus: PaymentStatus.paid,
      );

      if (mounted) {
        if (success) {
          // Delete payment notification when payment is completed
          final currentUser = supabase.auth.currentUser;
          if (currentUser != null) {
            await NotificationService.deleteNotificationByBooking(
              userId: currentUser.id,
              bookingId: widget.booking.id,
              type: NotificationAction.payment,
            );
          }
          
          showSnackBar(context, 'Payment successful!');
          Navigator.pop(context, true); // Return true to indicate payment completed
        } else {
          showSnackBar(context, 'Failed to process payment', isError: true);
          setState(() {
            _isProcessing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Error: $e', isError: true);
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Booking Summary
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Booking Summary',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _buildSummaryRow('Property', widget.property.title),
                      _buildSummaryRow('Check-in', DateFormat('MMM dd, yyyy').format(widget.booking.checkInDate)),
                      _buildSummaryRow('Check-out', DateFormat('MMM dd, yyyy').format(widget.booking.checkOutDate)),
                      _buildSummaryRow('Nights', '$_numberOfNights night${_numberOfNights > 1 ? 's' : ''}'),
                      const Divider(),
                      _buildSummaryRow(
                        'Total Amount',
                        'RM ${widget.booking.totalPrice.toStringAsFixed(2)}',
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Payment Methods
              Text(
                'Select Payment Method',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              ..._paymentMethods.map((method) => Card(
                    child: RadioListTile<String>(
                      value: method['name']!,
                      groupValue: _selectedPaymentMethod,
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentMethod = value;
                        });
                      },
                      title: Row(
                        children: [
                          // Placeholder for payment icon
                          Container(
                            width: 50,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Center(
                              child: Text(
                                method['name']![0],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(method['name']!),
                        ],
                      ),
                    ),
                  )),
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
                    'RM ${widget.booking.totalPrice.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _handleProceedWithPayment,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Proceed with Payment',
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

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                ),
          ),
        ],
      ),
    );
  }
}

