import 'package:supabase_flutter/supabase_flutter.dart';
import 'logger_service.dart';

class DriverCollection {
  final String id;
  final String driverId;
  final String type;
  final double amount;
  final String status;
  final String? adminNotes;
  final DateTime createdAt;

  DriverCollection({
    required this.id,
    required this.driverId,
    required this.type,
    required this.amount,
    required this.status,
    this.adminNotes,
    required this.createdAt,
  });

  factory DriverCollection.fromMap(Map<String, dynamic> map) => DriverCollection(
    id: map['id'] as String,
    driverId: map['driver_id'] as String,
    type: map['type'] as String,
    amount: (map['amount'] as num).toDouble(),
    status: map['status'] as String,
    adminNotes: map['admin_notes'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
  );

  String get amountFormatted => '${amount.toStringAsFixed(0)} ج.م';

  String get statusText {
    switch (status) {
      case 'pending': return 'قيد المراجعة';
      case 'approved': return 'تم الموافقة';
      case 'rejected': return 'مرفوض';
      default: return status;
    }
  }

  String get typeText => type == 'supply' ? 'توريد' : 'تحصيل';
}

class DriverStoreInvoice {
  final String id;
  final String driverId;
  final String storeId;
  final String? orderId;
  final double totalAmount;
  final String paymentMethod;
  final String status;
  final String? driverNotes;
  final String? storeNotes;
  final DateTime createdAt;

  DriverStoreInvoice({
    required this.id,
    required this.driverId,
    required this.storeId,
    this.orderId,
    required this.totalAmount,
    required this.paymentMethod,
    required this.status,
    this.driverNotes,
    this.storeNotes,
    required this.createdAt,
  });

  factory DriverStoreInvoice.fromMap(Map<String, dynamic> map) => DriverStoreInvoice(
    id: map['id'] as String,
    driverId: map['driver_id'] as String,
    storeId: map['store_id'] as String,
    orderId: map['order_id'] as String?,
    totalAmount: (map['total_amount'] as num).toDouble(),
    paymentMethod: map['payment_method'] as String,
    status: map['status'] as String,
    driverNotes: map['driver_notes'] as String?,
    storeNotes: map['store_notes'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
  );

  String get paymentMethodText {
    switch (paymentMethod) {
      case 'cash': return 'نقدي';
      case 'instapay': return 'إنستاباي';
      case 'wallet': return 'محفظة';
      case 'bank': return 'تحويل بنكي';
      default: return paymentMethod;
    }
  }
}

class CollectionService {
  final SupabaseClient _supabase;
  CollectionService(this._supabase);

  Future<List<DriverCollection>> getDriverCollections(String driverId) async {
    logService.debug('CollectionService', 'getDriverCollections: $driverId');
    final res = await _supabase
        .from('driver_collections')
        .select()
        .eq('driver_id', driverId)
        .eq('type', 'supply')
        .order('created_at', ascending: false);
    final list = (res as List).map((m) => DriverCollection.fromMap(m)).toList();
    logService.debug('CollectionService', 'found ${list.length} collections');
    return list;
  }

  Future<void> submitSupply({
    required String driverId,
    required double amount,
  }) async {
    logService.info('CollectionService', 'submitSupply driver=$driverId amount=$amount');
    try {
      await _supabase.from('driver_collections').insert({
        'driver_id': driverId,
        'type': 'supply',
        'amount': amount,
      });
      logService.info('CollectionService', 'supply submitted');
    } catch (e, s) {
      logService.error('CollectionService', 'submitSupply failed', e, s);
      rethrow;
    }
  }

  Future<double> getTotalDueForDriver(String driverId) async {
    logService.debug('CollectionService', 'getTotalDueForDriver: $driverId');
    final res = await _supabase
        .from('invoices')
        .select('grand_total')
        .eq('driver_id', driverId)
        .eq('payment_method', 'cash');
    double total = 0;
    for (final r in res as List) {
      total += (r['grand_total'] as num).toDouble();
    }
    logService.debug('CollectionService', 'totalDue=$total');
    return total;
  }

  Future<double> getTotalSupplyForDriver(String driverId) async {
    final res = await _supabase
        .from('driver_collections')
        .select('amount')
        .eq('driver_id', driverId)
        .eq('type', 'supply');
    double total = 0;
    for (final r in res as List) {
      total += (r['amount'] as num).toDouble();
    }
    return total;
  }

  Future<double> getTotalConfirmedSupplyForDriver(String driverId) async {
    final res = await _supabase
        .from('driver_collections')
        .select('amount')
        .eq('driver_id', driverId)
        .eq('type', 'supply')
        .eq('status', 'approved');
    double total = 0;
    for (final r in res as List) {
      total += (r['amount'] as num).toDouble();
    }
    return total;
  }

  Future<double> getRemainingForDriver(String driverId) async {
    final totalDue = await getTotalDueForDriver(driverId);
    final totalConfirmed = await getTotalConfirmedSupplyForDriver(driverId);
    return totalDue - totalConfirmed;
  }
}
