import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/other_models.dart';

class PaymentService {
  final SupabaseClient _supabase;
  PaymentService(this._supabase);

  Future<void> processPayment({
    required String userId,
    String? orderId,
    required double amount,
    required String paymentMethod,
  }) async {
    await _supabase.from('payments').insert({
      'user_id': userId,
      'order_id': orderId,
      'amount': amount,
      'payment_method': paymentMethod,
      'status': 'completed',
    });
  }

  Future<List<PaymentMethod>> getPaymentMethods() async {
    final response = await _supabase.from('payment_methods').select().eq('is_active', true);
    return (response as List).map((m) => PaymentMethod.fromMap(m)).toList();
  }

  Future<List<WalletTransaction>> getWalletTransactions(String userId) async {
    final response = await _supabase
        .from('wallet_transactions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (response as List).map((m) => WalletTransaction.fromMap(m)).toList();
  }

  Future<double> getWalletBalance(String userId) async {
    final response = await _supabase
        .from('profiles')
        .select('wallet_balance')
        .eq('id', userId)
        .single();
    return (response['wallet_balance'] as num?)?.toDouble() ?? 0;
  }

  Future<void> deductWallet({
    required String userId,
    required double amount,
    String? referenceId,
    String? description,
  }) async {
    final currentBalance = await getWalletBalance(userId);
    if (currentBalance < amount) {
      throw Exception('Insufficient wallet balance');
    }
    final newBalance = currentBalance - amount;
    await _supabase.from('profiles').update({'wallet_balance': newBalance}).eq('id', userId);
    await _supabase.from('wallet_transactions').insert({
      'user_id': userId,
      'type': 'withdrawal',
      'amount': amount,
      'balance_before': currentBalance,
      'balance_after': newBalance,
      'reference_id': referenceId,
      'description': description ?? 'Order payment',
    });
  }

  Stream<double> getWalletBalanceStream(String userId) {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((maps) {
      if (maps.isEmpty) return 0.0;
      return (maps.last['wallet_balance'] as num?)?.toDouble() ?? 0;
    });
  }

  Stream<List<WalletTransaction>> getWalletTransactionsStream(String userId) {
    return _supabase
        .from('wallet_transactions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((maps) => maps.map((m) => WalletTransaction.fromMap(m)).toList());
  }
}
