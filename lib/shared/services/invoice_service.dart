import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/invoice_model.dart';
import '../models/order_item_review_model.dart';
import 'logger_service.dart';

class InvoiceService {
  final SupabaseClient _supabase;
  InvoiceService(this._supabase);

  Future<InvoiceModel> createInvoice({
    required String orderId,
    required String driverId,
    required String customerId,
    String? storeId,
    required double totalAmount,
    double deliveryFee = 0,
    required String paymentMethod,
    List<Map<String, dynamic>>? items,
  }) async {
    logService.info('InvoiceService', 'createInvoice order=$orderId amount=$totalAmount fee=$deliveryFee');
    final grandTotal = totalAmount + deliveryFee;
    final response = await _supabase.from('invoices').insert({
      'order_id': orderId,
      'driver_id': driverId,
      'customer_id': customerId,
      'store_id': storeId,
      'total_amount': totalAmount,
      'delivery_fee': deliveryFee,
      'grand_total': grandTotal,
      'payment_method': paymentMethod,
    }).select().single();

    if (items != null && items.isNotEmpty) {
      await _supabase.from('invoice_items').insert(
        items.map((item) => {
          ...item,
          'invoice_id': response['id'],
        }).toList(),
      );
      logService.info('InvoiceService', 'inserted ${items.length} invoice items');
    }
    logService.info('InvoiceService', 'invoice created: ${response['id']}');
    return InvoiceModel.fromMap(response);
  }

  Future<List<InvoiceModel>> getCustomerInvoices(String customerId) async {
    final response = await _supabase
        .from('invoices')
        .select()
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);
    return (response as List).map((m) => InvoiceModel.fromMap(m)).toList();
  }

  Future<void> updateInvoiceStatus(String invoiceId, String status) async {
    await _supabase.from('invoices').update({'status': status}).eq('id', invoiceId);
  }

  Future<void> addStoreResponse({
    required String invoiceId,
    required String storeId,
    required String response,
    String? notes,
  }) async {
    await _supabase.from('invoice_store_responses').insert({
      'invoice_id': invoiceId,
      'store_id': storeId,
      'response': response,
      'notes': notes,
    });
  }

  Future<InvoiceModel?> getInvoiceByOrderId(String orderId) async {
    try {
      logService.debug('InvoiceService', 'getInvoiceByOrderId: $orderId');
      final response = await _supabase
          .from('invoices')
          .select()
          .eq('order_id', orderId)
          .single();
      final itemsResponse = await _supabase
          .from('invoice_items')
          .select()
          .eq('invoice_id', response['id']);
      final items = (itemsResponse as List)
          .map((m) => InvoiceItem.fromMap(m))
          .toList();
      logService.debug('InvoiceService', 'found invoice ${response['id']} with ${items.length} items');
      return InvoiceModel.fromMap({...response, 'items': items});
    } catch (_) {
      return null;
    }
  }

  Stream<InvoiceModel?> getInvoiceStream(String orderId) async* {
    yield await getInvoiceByOrderId(orderId);
    try {
      await for (final _ in _supabase
          .from('invoices')
          .stream(primaryKey: ['id'])
          .eq('order_id', orderId)) {
        yield await getInvoiceByOrderId(orderId);
      }
    } catch (_) {}
  }

  Future<void> saveItemReview({
    required String orderId,
    required String itemName,
    required int itemQuantity,
    required double itemPrice,
    required String status,
    String? rejectionReason,
  }) async {
    await _supabase.from('order_item_reviews').insert({
      'order_id': orderId,
      'item_name': itemName,
      'item_quantity': itemQuantity,
      'item_price': itemPrice,
      'status': status,
      'rejection_reason': rejectionReason,
      'reviewed_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<OrderItemReview>> getItemReviews(String orderId) async {
    final response = await _supabase
        .from('order_item_reviews')
        .select()
        .eq('order_id', orderId);
    return (response as List).map((m) => OrderItemReview.fromMap(m)).toList();
  }
}
