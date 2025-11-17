import 'package:flutter_test/flutter_test.dart';
import 'package:homiego/core/models/booking.dart' hide UserRole, PropertyStatus; 
import 'package:homiego/core/models/fraud_detection.dart';
import 'package:homiego/core/models/notification.dart';
import 'package:homiego/core/models/profile.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/models/property_image.dart'; 
import 'package:homiego/core/models/review.dart';
import 'package:homiego/core/models/wishlist.dart';

void main() {
  group('Homiego Data Models - Comprehensive Suite', () {
    
    // --- 1. PROFILE TEST ---
    test('Profile.fromMap parses generic Supabase response correctly', () {
      final map = {
        'id': 'user-123',
        'role': 'homeowner', 
        'full_name': 'Lim Qi Cai',
        'contact_no': '+60123456789',
        'is_verified': true,
      };
      final profile = Profile.fromMap(map);
      
      expect(profile.id, 'user-123');
      expect(profile.role, UserRole.homeowner);
      expect(profile.isVerified, true);
      expect(profile.isProfileComplete, true);
    });

    // --- 2. PROPERTY TEST ---
    test('Property.fromMap parses numeric prices and nested images', () {
      final map = {
        'id': 101,
        'host_id': 'host-abc',
        'title': 'Cozy Condo',
        'price_per_night': 200, 
        'amenities': ['Wifi', 'Pool'],
        'status': 'approved',
        'property_images': [
          {
            'id': 1, 
            'property_id': 101, 
            'storage_path': 'path/to/img1.jpg', 
            'position': 0
          },
          {
            'id': 2, 
            'property_id': 101, 
            'storage_path': 'path/to/img2.jpg', 
            'position': 1
          }
        ]
      };
      final property = Property.fromMap(map);
      
      expect(property.pricePerNight, 200.0);
      expect(property.status, PropertyStatus.approved);
      expect(property.images.length, 2);
      expect(property.images.first.storagePath, 'path/to/img1.jpg');
    });

    // --- 3. BOOKING TEST ---
    test('Booking.fromMap parses Supabase date formats correctly', () {
      final map = {
        'id': 505,
        'tenant_id': 'tenant-1',
        'property_id': 101,
        'check_in_date': '2025-10-01', 
        'check_out_date': '2025-10-05T12:00:00',
        'total_price': 500.50,
        'status': 'confirmed',
        'payment_status': 'paid',
        'created_at': DateTime.now().toIso8601String(),
      };
      final booking = Booking.fromMap(map);
      
      expect(booking.status, BookingStatus.confirmed);
      expect(booking.checkInDate.year, 2025);
      expect(booking.checkInDate.month, 10);
      expect(booking.totalPrice, 500.50);
    });

    // --- 4. REVIEW TEST ---
    test('Review.fromMap parses basic review data', () {
      final map = {
        'id': 1,
        'booking_id': 505,
        'rating': 5,
        'comment': 'Great stay!',
        'created_at': DateTime.now().toIso8601String(),
      };
      final review = Review.fromMap(map);
      
      expect(review.rating, 5);
      expect(review.comment, 'Great stay!');
    });

    // --- 5. NOTIFICATION TEST ---
    test('Notification.fromMap handles read status and type', () {
      final map = {
        'id': 99,
        'title': 'New Booking',
        'is_read': false,
        'type': 'payment',
      };
      final notif = Notification.fromMap(map);
      
      expect(notif.isRead, false);
      expect(notif.type, NotificationAction.payment);
    });

    // --- 6. WISHLIST TEST ---
    test('Wishlist.fromMap parses linking IDs', () {
      final map = {'id': 77, 'tenant_id': 't-1', 'property_id': 101};
      final wish = Wishlist.fromMap(map);
      
      expect(wish.propertyId, 101);
    });

    // --- 7. FRAUD DETECTION TEST ---
    test('UserFraudScore parses nested flags properly', () {
      final flag = FraudFlag(
        type: 'rapid_bookings', 
        description: 'Too fast', 
        detectedAt: DateTime.now()
      );
      
      final score = UserFraudScore(
        userId: 'u-bad',
        score: 85.5,
        flags: [flag],
        totalBookings: 10,
        cancelledBookings: 8,
        totalSpent: 0
      );

      expect(score.score, 85.5);
      expect(score.flags.first.type, 'rapid_bookings');
    });

    // --- 8. PROPERTY IMAGE TEST ---
    test('PropertyImage.fromMap parses storage path and position', () {
      final map = {
        'id': 20,
        'property_id': 101,
        'storage_path': 'properties/101/living_room.jpg',
        'position': 1,
      };
      final image = PropertyImage.fromMap(map);
      
      expect(image.id, 20);
      expect(image.storagePath, 'properties/101/living_room.jpg');
      expect(image.position, 1);
    });
  });
}