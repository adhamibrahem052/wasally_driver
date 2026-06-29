import 'package:supabase_flutter/supabase_flutter.dart';

class LocationService {
  final SupabaseClient _supabase;
  LocationService(this._supabase);

  Stream<Map<String, dynamic>?> getDriverLocationStream(String driverId) {
    return _supabase
        .from('driver_locations')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .map((maps) => maps.isNotEmpty ? maps.last : null);
  }
}
