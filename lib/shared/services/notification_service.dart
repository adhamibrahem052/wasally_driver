import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/other_models.dart';

class NotificationService {
  final SupabaseClient _supabase;
  NotificationService(this._supabase);

  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((maps) => maps.map((m) => NotificationModel.fromMap(m)).toList());
  }

  Future<void> markAsRead(String notificationId) async {
    await _supabase.from('notifications').update({'is_read': true}).eq('id', notificationId);
  }

  Future<void> markAllAsRead(String userId) async {
    await _supabase.from('notifications').update({'is_read': true}).eq('user_id', userId);
  }

  Future<int> getUnreadCount(String userId) async {
    final response = await _supabase
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);
    return (response as List).length;
  }
}
