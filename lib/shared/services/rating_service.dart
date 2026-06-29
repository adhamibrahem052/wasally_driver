import 'package:supabase_flutter/supabase_flutter.dart';

class RatingService {
  final SupabaseClient _supabase;
  RatingService(this._supabase);

  Future<void> submitRating({
    required String orderId,
    required String userId,
    int? driverRating,
    int? appRating,
    int? deliveryRating,
    String? comment,
  }) async {
    await _supabase.from('ratings').insert({
      'order_id': orderId,
      'user_id': userId,
      'driver_rating': driverRating,
      'app_rating': appRating,
      'delivery_rating': deliveryRating,
      'comment': comment,
    });
  }
}
