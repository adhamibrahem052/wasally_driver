import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/other_models.dart';

class MessageService {
  final SupabaseClient _supabase;
  MessageService(this._supabase);

  Future<List<MessageModel>> getMessages({
    required String userId1,
    required String userId2,
    String? orderId,
  }) async {
    var query = _supabase.from('messages').select();
    if (orderId != null) {
      query = query.eq('order_id', orderId);
    }
    final response = await query.order('created_at', ascending: true);
    return (response as List)
        .where((m) =>
            (m['sender_id'] == userId1 && m['receiver_id'] == userId2) ||
            (m['sender_id'] == userId2 && m['receiver_id'] == userId1))
        .map((m) => MessageModel.fromMap(m))
        .toList();
  }

  Stream<List<MessageModel>> getMessagesStream(String userId1, String userId2, {String? orderId}) {
    final builder = _supabase.from('messages').stream(primaryKey: ['id']);
    final stream = orderId != null ? builder.eq('order_id', orderId) : builder;
    return stream.order('created_at', ascending: true).map((maps) {
      final filtered = maps.where((m) =>
          (m['sender_id'] == userId1 && m['receiver_id'] == userId2) ||
          (m['sender_id'] == userId2 && m['receiver_id'] == userId1));
      return filtered.map((m) => MessageModel.fromMap(m)).toList();
    });
  }

  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String message,
    String? orderId,
  }) async {
    await _supabase.from('messages').insert({
      'sender_id': senderId,
      'receiver_id': receiverId,
      'order_id': orderId,
      'message': message,
    });
  }

  Future<int> getUnreadCount(String userId) async {
    final response = await _supabase
        .from('messages')
        .select('id')
        .eq('receiver_id', userId)
        .eq('is_read', false);
    return (response as List).length;
  }
}
