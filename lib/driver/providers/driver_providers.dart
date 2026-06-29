import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/user_model.dart';
import '../../shared/models/order_model.dart';
import '../../shared/models/store_models.dart';
import '../../shared/models/other_models.dart';
import '../../shared/services/order_service.dart';
import '../../shared/services/collection_service.dart';
import '../../shared/services/logger_service.dart';
import '../../shared/services/notification_service.dart';
import '../../shared/services/store_service.dart';
import '../../shared/providers/supabase_client_provider.dart';
import 'auth_provider.dart';

final driverOrdersRefreshProvider = StateProvider<int>((ref) => 0);

final driverOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  final user = ref.read(driverAuthProvider).supabaseUser;
  if (user == null) {
    developer.log('driverOrdersProvider: no user, returning empty stream', name: 'WASALLY_SYNC');
    return const Stream.empty();
  }
  developer.log('driverOrdersProvider: creating stream for user=${user.id}', name: 'WASALLY_SYNC');
  final service = OrderService(ref.read(supabaseClientProvider));
  return service.getDriverOrdersStream(user.id).handleError((Object err, StackTrace st) {
    developer.log('driverOrdersProvider: STREAM ERROR $err', name: 'WASALLY_SYNC');
    logService.error('driverOrdersProvider', 'Stream error', err, st);
  }).transform(
    StreamTransformer.fromHandlers(handleData: (data, sink) {
      developer.log('driverOrdersProvider: emitted ${data.length} orders', name: 'WASALLY_SYNC');
      sink.add(data);
    }),
  );
});

final driverPendingCountProvider = Provider<int>((ref) {
  final orders = ref.watch(driverOrdersProvider).valueOrNull ?? [];
  return orders.where((o) => o.status == 'pending' || o.status == 'driver_assigned').length;
});

final driverNotificationsProvider = StreamProvider<List<NotificationModel>>((ref) {
  final user = ref.read(driverAuthProvider).supabaseUser;
  if (user == null) return const Stream.empty();
  return ref.read(driverNotifServiceProvider).getNotificationsStream(user.id).handleError((_) => <NotificationModel>[]);
});

final driverNotifServiceProvider = Provider<NotificationService>((ref) => NotificationService(ref.read(supabaseClientProvider)));

final driverProfileProvider = FutureProvider<AppUser?>((ref) async {
  final user = ref.read(driverAuthProvider).supabaseUser;
  if (user == null) return null;
  final client = ref.read(supabaseClientProvider);
  final res = await client.from('profiles').select().eq('id', user.id).single();
  return AppUser.fromMap(res);
});

final driverCollectionsProvider = FutureProvider<List<DriverCollection>>((ref) async {
  final user = ref.read(driverAuthProvider).supabaseUser;
  if (user == null) return [];
  return ref.read(driverCollectionsServiceProvider).getDriverCollections(user.id);
});

final driverRemainingProvider = FutureProvider<double>((ref) async {
  final user = ref.read(driverAuthProvider).supabaseUser;
  if (user == null) return 0;
  return ref.read(driverCollectionsServiceProvider).getRemainingForDriver(user.id);
});

final driverCollectionsServiceProvider = Provider<CollectionService>((ref) => CollectionService(ref.read(supabaseClientProvider)));

final driverStoresProvider = FutureProvider<List<StoreModel>>((ref) {
  return ref.read(driverStoreServiceProvider).getStores();
});

final driverStoreServiceProvider = Provider<StoreService>((ref) => StoreService(ref.read(supabaseClientProvider)));

void invalidateAll(WidgetRef ref) {
  ref.invalidate(driverOrdersProvider);
  ref.invalidate(driverPendingCountProvider);
  ref.invalidate(driverNotificationsProvider);
  ref.invalidate(driverProfileProvider);
  ref.invalidate(driverCollectionsProvider);
  ref.invalidate(driverRemainingProvider);
  ref.invalidate(driverStoresProvider);
}
