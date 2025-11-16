import '../services/supabase_client.dart';

class ReviewService {
  /// Submit a review for a booking
  static Future<bool> submitReview({
    required int bookingId,
    required int rating,
    required String comment,
  }) async {
    try {
      await supabase.from('reviews').insert({
        'booking_id': bookingId,
        'rating': rating,
        'comment': comment,
      });
      return true;
    } catch (e) {
      print('Error submitting review: $e');
      return false;
    }
  }

  /// Check if a review already exists for a booking
  static Future<bool> reviewExists(int bookingId) async {
    try {
      final response = await supabase
          .from('reviews')
          .select()
          .eq('booking_id', bookingId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      print('Error checking review existence: $e');
      return false;
    }
  }
}

