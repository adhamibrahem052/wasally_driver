import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_model.dart';
import 'logger_service.dart';

class OrderService {
  final SupabaseClient _supabase;
  OrderService(this._supabase);

  Stream<List<OrderModel>> getOrdersStream(String userId) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('customer_id', userId)
        .order('created_at', ascending: false)
        .map((maps) => maps.map((m) => OrderModel.fromMap(m)).toList());
  }

  Stream<List<OrderModel>> getDriverOrdersStream(String driverId) {
    logService.info('OrderService', 'getDriverOrdersStream: $driverId');
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .inFilter('status', ['pending', 'preparing', 'on_the_way', 'driver_assigned', 'store_confirmed'])
        .order('created_at', ascending: false)
        .map((maps) {
      final orders = maps
          .map((m) => OrderModel.fromMap(m))
          .where((o) => o.status == 'pending' || o.driverId == driverId)
          .toList();
      logService.debug('OrderService', 'Stream emitted ${orders.length} orders');
      return orders;
    });
  }

  Future<List<OrderModel>> getUserOrders(String userId) async {
    final response = await _supabase
        .from('orders')
        .select()
        .eq('customer_id', userId)
        .order('created_at', ascending: false);
    return (response as List).map((m) => OrderModel.fromMap(m)).toList();
  }

  Future<OrderModel> createOrder({
    required String customerId,
    String? storeId,
    String? orderDetails,
    String? deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
    double deliveryFee = 0,
    String paymentMethod = 'cash',
  }) async {
    final response = await _supabase.from('orders').insert({
      'customer_id': customerId,
      if (storeId != null) 'store_id': storeId,
      'order_type': storeId != null ? 'store' : 'manual',
      'order_details': orderDetails,
      'delivery_address': deliveryAddress,
      'delivery_lat': deliveryLat,
      'delivery_lng': deliveryLng,
      'delivery_fee': deliveryFee,
      'payment_method': paymentMethod,
    }).select().single();
    return OrderModel.fromMap(response);
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _supabase.from('orders').update({'status': status}).eq('id', orderId);
  }

  Future<void> assignDriver(String orderId, String driverId) async {
    logService.info('OrderService', 'assignDriver order=$orderId driver=$driverId');
    try {
      await _supabase.from('orders').update({
        'driver_id': driverId,
        'status': 'driver_assigned',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);
      logService.info('OrderService', 'assignDriver success');
    } catch (e, s) {
      logService.error('OrderService', 'assignDriver failed', e, s);
      rethrow;
    }
  }

  Future<void> cancelOrder(String orderId, {String? reason}) async {
    await _supabase.from('orders').update({
      'status': 'cancelled',
      if (reason != null) 'cancelled_reason': reason,
    }).eq('id', orderId);
  }

  Future<void> confirmDelivery(String orderId) async {
    await _supabase.from('orders').update({
      'status': 'delivered',
      'qr_code_verified': true,
    }).eq('id', orderId);
  }

  Future<void> rateOrder(String orderId, int rating, {String? comment}) async {
    await _supabase.from('orders').update({
      'rating': rating,
      if (comment != null) 'rating_comment': comment,
    }).eq('id', orderId);
  }

  Future<OrderModel?> getOrderById(String orderId) async {
    final response = await _supabase.from('orders').select().eq('id', orderId).single();
    return OrderModel.fromMap(response);
  }
}
