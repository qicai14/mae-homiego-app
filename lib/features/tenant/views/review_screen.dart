import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/booking.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/models/profile.dart';
import 'package:homiego/core/models/notification.dart';
import 'package:homiego/core/services/property_service.dart';
import 'package:homiego/core/services/review_service.dart';
import 'package:homiego/core/services/notification_service.dart';
import 'package:homiego/core/services/booking_service.dart';
import 'package:homiego/core/services/supabase_client.dart';
import 'package:homiego/core/utils/show_snackbar.dart';
import 'package:homiego/widgets/profile_avatar.dart';
import 'package:homiego/features/booking/views/booking_payment_detail_screen.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  final int bookingId;

  const ReviewScreen({
    super.key,
    required this.bookingId,
  });

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  Property? _property;
  Profile? _hostProfile;
  List<String> _images = [];
  Booking? _booking;
  int _selectedRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _currentImageIndex = 0;
  final PageController _imagePageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _imagePageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // First, fetch the booking to check payment status
      _booking = await PropertyService.getBookingById(widget.bookingId);
      
      if (_booking == null) {
        if (mounted) {
          showSnackBar(context, 'Booking not found', isError: true);
          Navigator.pop(context);
        }
        return;
      }

      // Check payment status - if unpaid, redirect to booking payment detail
      if (_booking!.paymentStatus == PaymentStatus.unpaid) {
        if (mounted) {
          // Fetch property for navigation
          final propertyResponse = await supabase
              .from('properties')
              .select()
              .eq('id', _booking!.propertyId)
              .maybeSingle();
          
          if (propertyResponse != null) {
            final property = Property.fromMap(propertyResponse);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => BookingPaymentDetailScreen(
                  booking: _booking!,
                  property: property,
                ),
              ),
            );
          } else {
            showSnackBar(context, 'Property not found', isError: true);
            Navigator.pop(context);
          }
        }
        return;
      }

      // If paid, load property and host data for review
      final propertyResponse = await supabase
          .from('properties')
          .select()
          .eq('id', _booking!.propertyId)
          .maybeSingle();

      if (propertyResponse == null) {
        if (mounted) {
          showSnackBar(context, 'Property not found', isError: true);
          Navigator.pop(context);
        }
        return;
      }

      final property = Property.fromMap(propertyResponse);
      
      final results = await Future.wait([
        PropertyService.getPropertyImages(property.id),
        PropertyService.getHostProfile(property.hostId),
      ]);

      if (mounted) {
        setState(() {
          _property = property;
          _images = results[0] as List<String>;
          _hostProfile = results[1] as Profile?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        showSnackBar(context, 'Error loading data: $e', isError: true);
      }
    }
  }

  Future<void> _submitReview() async {
    if (_selectedRating == 0) {
      showSnackBar(context, 'Please select a rating', isError: true);
      return;
    }

    if (_commentController.text.trim().isEmpty) {
      showSnackBar(context, 'Please enter a comment', isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final success = await ReviewService.submitReview(
        bookingId: widget.bookingId,
        rating: _selectedRating,
        comment: _commentController.text.trim(),
      );

      if (mounted) {
        if (success) {
          // Update review_status to "sent" when review is successfully submitted
          await BookingService.updateReviewStatus(
            bookingId: widget.bookingId,
            reviewStatus: ReviewStatus.sent,
          );
          
          // Delete review notification when review is successfully submitted
          final currentUser = supabase.auth.currentUser;
          if (currentUser != null) {
            await NotificationService.deleteNotificationByBooking(
              userId: currentUser.id,
              bookingId: widget.bookingId,
              type: NotificationAction.review,
            );
          }
          
          showSnackBar(context, 'Review submitted successfully!');
          Navigator.pop(context, true); // Return true to indicate review was submitted
        } else {
          showSnackBar(context, 'Failed to submit review', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Error submitting review: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Write a Review'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_property == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Write a Review'),
        ),
        body: const Center(child: Text('Property not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Write a Review'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property Images
            if (_images.isNotEmpty) ...[
              SizedBox(
                height: 250,
                child: PageView.builder(
                  controller: _imagePageController,
                  itemCount: _images.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentImageIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return Image.network(
                      _images[index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(child: Icon(Icons.image_not_supported)),
                    );
                  },
                ),
              ),
              if (_images.length > 1)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _images.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentImageIndex == index
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
            ] else
              Container(
                height: 250,
                color: Colors.grey[300],
                child: const Center(child: Icon(Icons.image_not_supported, size: 64)),
              ),
            
            const SizedBox(height: 24),
            
            // Property Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _property!.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Property Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _property!.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Host Information
            if (_hostProfile != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Hosted by',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    ProfileAvatar(
                      size: 50,
                      name: _hostProfile!.fullName ?? 'Host',
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _hostProfile!.fullName ?? 'Host',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          if (_hostProfile!.shortBio != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _hostProfile!.shortBio!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
            
            const Divider(),
            const SizedBox(height: 16),
            
            // Rating Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'How was your stay?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedRating = index + 1;
                      });
                    },
                    child: Icon(
                      index < _selectedRating ? Icons.star : Icons.star_border,
                      size: 48,
                      color: index < _selectedRating
                          ? Colors.amber
                          : Colors.grey,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 32),
            
            // Comment Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Share your experience',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _commentController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'Tell others about your stay...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Submit Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReview,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Send Review',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

