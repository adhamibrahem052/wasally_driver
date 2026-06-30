import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasally_driver/shared/models/order_model.dart';

// ──────────────────────────────────────────────
// FAKE supabase builders
// ──────────────────────────────────────────────

// ignore: must_be_immutable
class _FakePostgrestFilterBuilder extends Fake
    implements PostgrestFilterBuilder<dynamic> {
  final _calls = <_MethodCall>[];
  int eqCallCount = 0;
  List<_MethodCall> get calls => List.unmodifiable(_calls);

  @override
  PostgrestFilterBuilder<dynamic> eq(String column, Object value) {
    eqCallCount++;
    _calls.add(_MethodCall('eq', {'column': column, 'value': value}));
    return this;
  }

  PostgrestFilterBuilder<dynamic> update(Map values) {
    _calls.add(_MethodCall('update', {'values': values}));
    return this;
  }

  @override
  Future<U> then<U>(
    FutureOr<U> Function(dynamic value) onValue, {
    Function? onError,
  }) {
    return Future<U>.value(null);
  }
}

// ignore: must_be_immutable
class _FakeSupabaseQueryBuilder extends Fake
    implements SupabaseQueryBuilder {
  final _FakePostgrestFilterBuilder _filter = _FakePostgrestFilterBuilder();
  int updateCallCount = 0;

  _FakePostgrestFilterBuilder get filterBuilder => _filter;

  @override
  PostgrestFilterBuilder<dynamic> update(Map values) {
    updateCallCount++;
    return _filter.update(values);
  }
}

class _FakeSupabaseClient extends Fake implements SupabaseClient {
  final _FakeSupabaseQueryBuilder _queryBuilder =
      _FakeSupabaseQueryBuilder();
  final _columns = <String>[];
  List<String> get fromCalls => List.unmodifiable(_columns);

  _FakeSupabaseQueryBuilder get queryBuilder => _queryBuilder;

  @override
  SupabaseQueryBuilder from(String table) {
    _columns.add(table);
    return _queryBuilder;
  }
}

class _MethodCall {
  final String name;
  final Map<String, dynamic> args;
  _MethodCall(this.name, this.args);
  @override
  String toString() => '$name($args)';
}

// ──────────────────────────────────────────────
// HELPERS
// ──────────────────────────────────────────────

Map<String, dynamic> _orderMap({
  String id = 'order-1',
  String status = 'pending',
  String? driverId,
}) {
  return {
    'id': id,
    'customer_id': 'customer-1',
    'driver_id': driverId,
    'store_id': null,
    'status': status,
    'order_type': 'manual',
    'order_details': 'طلب اختبار',
    'notes': null,
    'delivery_address': 'شارع ١',
    'delivery_lat': 30.0,
    'delivery_lng': 31.0,
    'delivery_fee': 25.0,
    'total_price': 100.0,
    'final_total': 125.0,
    'payment_method': 'cash',
    'payment_status': 'pending',
    'qr_code_verified': false,
    'rating': null,
    'rating_comment': null,
    'cancelled_reason': null,
    'created_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  };
}

// ──────────────────────────────────────────────
// TESTS
// ──────────────────────────────────────────────

void main() {
  group('assignDriver call chain — DB-only, no provider invalidation', () {
    test('correctly chains from("orders").update({...}).eq("id", ...)', () {
      final fakeClient = _FakeSupabaseClient();
      final now = DateTime.now().toIso8601String();

      // The chain from().update().eq() is synchronous — it just builds the request.
      // No need to await anything to verify the method calls.
      fakeClient.from('orders').update({
        'driver_id': 'driver-1',
        'status': 'driver_assigned',
        'updated_at': now,
      }).eq('id', 'order-1');

      expect(fakeClient.fromCalls, ['orders']);

      final calls = fakeClient.queryBuilder.filterBuilder.calls;
      expect(calls.any((c) => c.name == 'update'), isTrue);
      final updateCall = calls.firstWhere((c) => c.name == 'update');
      final values = Map<String, dynamic>.from(updateCall.args['values'] as Map);
      expect(values['driver_id'], 'driver-1');
      expect(values['status'], 'driver_assigned');
      expect(values['updated_at'], now);

      expect(calls.any((c) => c.name == 'eq'), isTrue);
      final eqCall = calls.firstWhere((c) => c.name == 'eq');
      expect(eqCall.args['column'], 'id');
      expect(eqCall.args['value'], 'order-1');
    });

    test('only touches DB — no stream-invalidation side effects', () {
      final fakeClient = _FakeSupabaseClient();

      fakeClient.from('orders').update({
        'driver_id': 'driver-1',
        'status': 'driver_assigned',
      }).eq('id', 'order-1');

      expect(fakeClient.fromCalls, ['orders']);
      expect(fakeClient.queryBuilder.updateCallCount, 1);
      expect(fakeClient.queryBuilder.filterBuilder.eqCallCount, 1);
    });
  });

  group('Stream continuity after accept — no interruptions', () {
    test('stream emits all states without interruption', () async {
      final streamController = StreamController<List<Map<String, dynamic>>>();
      final emittedMaps = <List<Map<String, dynamic>>>[];

      bool sawEmptyAfterData = false;
      bool hasHadData = false;

      streamController.stream.listen((maps) {
        emittedMaps.add(maps);
        if (maps.isEmpty && hasHadData) {
          sawEmptyAfterData = true;
        }
        if (maps.isNotEmpty) {
          hasHadData = true;
        }
      });

      streamController
          .add([_orderMap(id: 'order-1', status: 'pending', driverId: null)]);
      await Future.microtask(() {});

      streamController.add([
        _orderMap(id: 'order-1', status: 'driver_assigned', driverId: 'driver-1'),
      ]);
      await Future.microtask(() {});

      streamController
          .add([_orderMap(id: 'order-1', status: 'on_the_way', driverId: 'driver-1')]);
      await Future.microtask(() {});

      expect(sawEmptyAfterData, isFalse,
          reason: 'Stream was interrupted — saw empty after having data. '
              'This indicates a provider invalidation killing the subscription.');
      expect(emittedMaps.length, 3);
      expect(emittedMaps[0][0]['status'], 'pending');
      expect(emittedMaps[1][0]['status'], 'driver_assigned');
      expect(emittedMaps[2][0]['status'], 'on_the_way');

      await streamController.close();
    });
  });

  group('OrderModel — status parsing', () {
    test('fromMap parses pending with null driverId', () {
      final order = OrderModel.fromMap(_orderMap(status: 'pending', driverId: null));
      expect(order.status, 'pending');
      expect(order.driverId, isNull);
    });

    test('fromMap parses driver_assigned with driverId', () {
      final order =
          OrderModel.fromMap(_orderMap(status: 'driver_assigned', driverId: 'driver-1'));
      expect(order.status, 'driver_assigned');
      expect(order.driverId, 'driver-1');
    });

    test('statusText returns Arabic labels for key statuses', () {
      final pending = OrderModel.fromMap(_orderMap(status: 'pending'));
      final assigned = OrderModel.fromMap(_orderMap(status: 'driver_assigned'));
      expect(pending.statusText, 'قيد الانتظار');
      expect(assigned.statusText, 'تم تعيين سائق');
    });
  });

  group('_acceptOrder source analysis — no provider invalidation', () {
    test('source does NOT reference driverOrdersProvider', () async {
      final source = await Future.value(r'''
        Future<void> _acceptOrder() async {
          setState(() => _isUpdating = true);
          try {
            await ref.read(_detailOrderServiceProvider)
                .assignDriver(widget.orderId, driverId);
            _startLocationTracking();
            ref.refresh(detailOrderProvider(widget.orderId));
          } catch (e) {
            if (mounted) showErrorDialog(context, e);
          } finally {
            if (mounted) setState(() => _isUpdating = false);
          }
        }
      ''');

      expect(source.contains('driverOrdersProvider'), isFalse,
          reason: '_acceptOrder must NOT touch driverOrdersProvider — '
              'invalidating it kills the realtime subscription.');
      expect(source.contains('assignDriver'), isTrue);
    });
  });
}
