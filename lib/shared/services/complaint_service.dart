import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/other_models.dart';

class ComplaintService {
  final SupabaseClient _supabase;
  ComplaintService(this._supabase);

  Future<void> submitComplaint({
    required String userId,
    required String type,
    required String title,
    required String description,
  }) async {
    await _supabase.from('complaints').insert({
      'user_id': userId,
      'type': type,
      'title': title,
      'description': description,
    });
  }

  Future<List<ComplaintModel>> getUserComplaints(String userId) async {
    final response = await _supabase
        .from('complaints')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (response as List).map((m) => ComplaintModel.fromMap(m)).toList();
  }

  Stream<List<ComplaintModel>> getComplaintsStream(String userId) {
    return _supabase
        .from('complaints')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((maps) => maps.map((m) => ComplaintModel.fromMap(m)).toList());
  }

  Future<String?> getAdminId() async {
    final response = await _supabase
        .from('profiles')
        .select('id')
        .eq('role', 'admin')
        .limit(1)
        .maybeSingle();
    return response?['id'] as String?;
  }

  Future<void> markAsRead(String complaintId) async {
    await _supabase.from('complaints').update({'is_read': true}).eq('id', complaintId);
  }
}
