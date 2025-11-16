import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/providers/auth_providers.dart';
import 'package:homiego/core/services/booking_service.dart';
import 'package:homiego/core/utils/show_snackbar.dart';

class PaymentGatewayScreen extends ConsumerStatefulWidget {
  final Property property;
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final double totalPrice;
  final int numberOfNights;

  const PaymentGatewayScreen({
    super.key,
    required this.property,
    required this.checkInDate,
    required this.checkOutDate,
    required this.totalPrice,
    required this.numberOfNights,
  });

  @override
  ConsumerState<PaymentGatewayScreen> createState() => _PaymentGatewayScreenState();
}

class _PaymentGatewayScreenState extends ConsumerState<PaymentGatewayScreen> {
  String? _selectedPaymentMethod;
  bool _isProcessing = false;

  final List<Map<String, String>> _paymentMethods = [
    {'name': 'Visa', 'icon': 'lib/assets/visa_logo.png'},
    {'name': 'Mastercard', 'icon': 'lib/assets/mastercard_logo.png'},
    {'name': 'PayPal', 'icon': 'lib/assets/paypal_logo.png'},
  ];

  Future<void> _handleProceedWithPayment() async {
    if (_selectedPaymentMethod == null) {
      showSnackBar(context, 'Please select a payment method', isError: true);
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    final authState = ref.read(authNotifierProvider);
    final user = authState.value?.user;

    if (user == null) {
      if (mounted) {
        showSnackBar(context, 'Please log in to make a booking', isError: true);
        setState(() {
          _isProcessing = false;
        });
      }
      return;
    }

    try {
      final booking = await BookingService.createBooking(
        tenantId: user.id,
        propertyId: widget.property.id,
        checkInDate: widget.checkInDate,
        checkOutDate: widget.checkOutDate,
        totalPrice: widget.totalPrice,
      );

      if (mounted) {
        if (booking != null) {
          showSnackBar(context, 'Booking confirmed successfully!');
          // Navigate back to property detail or home screen
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          showSnackBar(context, 'Failed to create booking', isError: true);
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
        title: const Text('Payment'),
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
                      _buildSummaryRow('Check-in', _formatDate(widget.checkInDate)),
                      _buildSummaryRow('Check-out', _formatDate(widget.checkOutDate)),
                      _buildSummaryRow('Nights', '${widget.numberOfNights} night${widget.numberOfNights > 1 ? 's' : ''}'),
                      const Divider(),
                      _buildSummaryRow(
                        'Total Amount',
                        'RM ${widget.totalPrice.toStringAsFixed(2)}',
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
                          // Payment method logo
                          Image.asset(
                            method['icon']!,
                            width: 50,
                            height: 30,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Container(
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
          child: SizedBox(
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

