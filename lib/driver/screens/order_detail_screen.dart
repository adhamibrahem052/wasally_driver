import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../shared/services/order_service.dart';
import '../../shared/services/invoice_service.dart';
import '../../shared/models/order_model.dart';
import '../../shared/models/invoice_model.dart';
import '../../shared/models/user_model.dart';
import '../../shared/localization/app_localizations.dart';
import '../../shared/providers/locale_provider.dart';
import '../../shared/constants/route_paths.dart';
import '../../shared/providers/supabase_client_provider.dart';
import '../../shared/widgets/common_widgets.dart';
import '../providers/auth_provider.dart';

final detailOrderProvider = FutureProvider.family.autoDispose<OrderModel?, String>((ref, id) async {
  return ref.read(_detailOrderServiceProvider).getOrderById(id);
});
final _detailOrderServiceProvider = Provider.autoDispose<OrderService>((ref) => OrderService(ref.read(supabaseClientProvider)));
final _detailCustomerProvider = FutureProvider.family.autoDispose<AppUser?, String>((ref, id) async {
  if (id.isEmpty) return null;
  final res = await Supabase.instance.client.from('profiles').select().eq('id', id).single();
  return AppUser.fromMap(res);
});
final detailInvoiceProvider = FutureProvider.family.autoDispose<InvoiceModel?, String>((ref, orderId) async {
  return ref.read(_detailInvoiceServiceProvider).getInvoiceByOrderId(orderId);
});
final _detailInvoiceServiceProvider = Provider.autoDispose<InvoiceService>((ref) => InvoiceService(ref.read(supabaseClientProvider)));

final _detailDriverLocationProvider = StreamProvider.family.autoDispose<LatLng?, String>((ref, driverId) {
  if (driverId.isEmpty) return const Stream.empty();
  return Supabase.instance.client
      .from('driver_locations')
      .stream(primaryKey: ['driver_id'])
      .eq('driver_id', driverId)
      .map((maps) {
    if (maps.isEmpty) return null;
    final loc = maps.last;
    final lat = (loc['lat'] as num?)?.toDouble();
    final lng = (loc['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  });
});

class DriverOrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  const DriverOrderDetailScreen({super.key, required this.orderId});
  @override
  ConsumerState<DriverOrderDetailScreen> createState() => _DriverOrderDetailScreenState();
}

class _DriverOrderDetailScreenState extends ConsumerState<DriverOrderDetailScreen> {
  bool _isUpdating = false;
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _orderRealtimeSub;
  StreamSubscription<List<Map<String, dynamic>>>? _invoiceRealtimeSub;
  List<LatLng> _routePoints = [];
  double? _distanceKm;
  int? _etaMinutes;
  bool _routeLoading = false;

  @override
  void initState() {
    super.initState();
    _orderRealtimeSub = Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', widget.orderId)
        .listen((_) => ref.invalidate(detailOrderProvider(widget.orderId)));
    _invoiceRealtimeSub = Supabase.instance.client
        .from('invoices')
        .stream(primaryKey: ['id'])
        .eq('order_id', widget.orderId)
        .listen((_) => ref.invalidate(detailInvoiceProvider(widget.orderId)));
  }

  @override
  void dispose() {
    _stopLocationTracking();
    _orderRealtimeSub?.cancel();
    _invoiceRealtimeSub?.cancel();
    super.dispose();
  }

  String tr(String key) => AppLocalizations(ref.watch(localeProvider)).get(key);

  Future<void> _fetchRoute(LatLng from, LatLng to) async {
    if (_routeLoading) return;
    setState(() => _routeLoading = true);
    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}?overview=full&geometries=geojson';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok') {
          final coords = data['routes'][0]['geometry']['coordinates'] as List;
          final points = coords.map((c) => LatLng(c[1], c[0])).cast<LatLng>().toList();
          final distance = (data['routes'][0]['distance'] as num) / 1000;
          final duration = (data['routes'][0]['duration'] as num) ~/ 60;
          if (mounted) {
            setState(() {
              _routePoints = points;
              _distanceKm = distance;
              _etaMinutes = duration;
            });
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _routeLoading = false);
  }

  Future<void> _startLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    const locSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
    _locationSubscription = Geolocator.getPositionStream(locationSettings: locSettings).listen((pos) async {
      try {
        await Supabase.instance.client.from('driver_locations').upsert({
          'driver_id': ref.read(driverAuthProvider).supabaseUser!.id,
          'lat': pos.latitude,
          'lng': pos.longitude,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    });
  }

  void _stopLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  Future<void> _acceptOrder() async {
    developer.log('_acceptOrder: START', name: 'WASALLY_SYNC');
    setState(() => _isUpdating = true);
    try {
      final driverId = ref.read(driverAuthProvider).supabaseUser!.id;
      developer.log('_acceptOrder: calling assignDriver orderId=${widget.orderId} driverId=$driverId', name: 'WASALLY_SYNC');
      await ref.read(_detailOrderServiceProvider).assignDriver(widget.orderId, driverId);
      developer.log('_acceptOrder: assignDriver COMPLETE', name: 'WASALLY_SYNC');
      _startLocationTracking();
      developer.log('_acceptOrder: refreshing detailOrderProvider', name: 'WASALLY_SYNC');
      ref.refresh(detailOrderProvider(widget.orderId));
      developer.log('_acceptOrder: showSnackBar mounted=$mounted', name: 'WASALLY_SYNC');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('orderUpdatedToast'), style: GoogleFonts.cairo()),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      developer.log('_acceptOrder: ERROR $e', name: 'WASALLY_SYNC');
      if (mounted) showErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
      developer.log('_acceptOrder: END', name: 'WASALLY_SYNC');
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _isUpdating = true);
    try {
      await ref.read(_detailOrderServiceProvider).updateOrderStatus(widget.orderId, status);
      if (status == 'on_the_way') {
        _startLocationTracking();
      }
      if (status == 'delivered' || status == 'cancelled') {
        _stopLocationTracking();
      }
      ref.refresh(detailOrderProvider(widget.orderId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('orderUpdatedToast'), style: GoogleFonts.cairo()),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) showErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(detailOrderProvider(widget.orderId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = tr;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('orderDetails'), style: GoogleFonts.cairo()),
        actions: [
          if (orderAsync.asData?.value != null)
            IconButton(
              icon: const Icon(Icons.qr_code),
              tooltip: t('generateQR'),
              onPressed: () => context.push(RoutePaths.dashboardQrCode(widget.orderId)),
            ),
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => WasallyError(message: t('orderLoadError'), onRetry: () => ref.refresh(detailOrderProvider(widget.orderId))),
        data: (order) {
          if (order == null) return Center(child: Text(t('orderNotFound'), style: GoogleFonts.cairo()));
          return _buildContent(order, isDark);
        },
      ),
    );
  }

  Widget _buildContent(OrderModel order, bool isDark) {
    final invoiceAsync = ref.watch(detailInvoiceProvider(widget.orderId));
    final invoice = invoiceAsync.asData?.value;
    return RefreshIndicator(
      onRefresh: () async {
        ref.refresh(detailOrderProvider(widget.orderId));
        ref.refresh(detailInvoiceProvider(widget.orderId));
        ref.refresh(_detailCustomerProvider(order.customerId));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(order, invoice, isDark),
            const SizedBox(height: 16),
            if (order.deliveryLat != null && order.deliveryLng != null) _buildMapCard(order, invoice, isDark),
            const SizedBox(height: 16),
            _buildCustomerCard(order, isDark),
            const SizedBox(height: 16),
            _buildInvoiceCard(order, isDark),
            const SizedBox(height: 24),
            _buildActionButtons(order),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(OrderModel order, InvoiceModel? invoice, bool isDark) {
    final t = tr;
    final displayTotal = invoice?.grandTotal ?? order.finalTotal;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.start, children: [
            Text(t('orderInfo'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 8),
            const Icon(Icons.info_outline, color: Color(0xFFFF9800)),
          ]),
          const Divider(height: 20),
          _detailRow(t('orderNumber'), order.id.substring(0, 12)),
          _detailRow(t('orderDetails'), order.orderDetails ?? t('quickOrder')),
          _detailRow(t('deliveryAddress'), order.deliveryAddress ?? t('notAvailable')),
          if (order.deliveryLat != null && order.deliveryLng != null)
            _detailRow('GPS', '${order.deliveryLat!.toStringAsFixed(6)}, ${order.deliveryLng!.toStringAsFixed(6)}'),
          _detailRow(t('grandTotal'), '${displayTotal.toStringAsFixed(0)} ج.م'),
          _detailRow(t('paymentMethod'), order.paymentMethod == 'wallet' ? t('wallet') : t('cashOnDelivery')),
          _detailRow(t('invoiceStatus'), order.statusText),
        ],
      ),
    );
  }

  Widget _buildMapCard(OrderModel order, InvoiceModel? invoice, bool isDark) {
    final lat = order.deliveryLat!;
    final lng = order.deliveryLng!;
    final dest = LatLng(lat, lng);
    final driverLatLng = ref.watch(_detailDriverLocationProvider(order.driverId ?? ''));
    final driverPos = driverLatLng.asData?.value;
    final isAssignedToMe = order.driverId == ref.read(driverAuthProvider).supabaseUser?.id;

    if (driverPos != null && _routePoints.isEmpty && !_routeLoading && isAssignedToMe) {
      Future.microtask(() => _fetchRoute(driverPos, dest));
    }

    final markers = <Marker>[
      Marker(point: dest, width: 40, height: 40, child: const Icon(Icons.location_on, size: 40, color: Colors.red)),
    ];
    if (driverPos != null) {
      markers.add(Marker(point: driverPos, width: 40, height: 40, child: const Icon(Icons.near_me, size: 32, color: Colors.blue)));
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 220,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: dest,
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.wasally.driver',
                ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        color: Colors.blue,
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if (_etaMinutes != null) ...[
                      Text('${_etaMinutes} ${tr('minute')} · ${_distanceKm?.toStringAsFixed(1)} ${tr('km')}',
                          style: GoogleFonts.cairo(fontSize: 11, color: Colors.green[700], fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      const Icon(Icons.timer_outlined, size: 14, color: Colors.green),
                      const SizedBox(width: 16),
                    ],
                    if (driverPos != null)
                      Text('${tr('driver')} ●', style: GoogleFonts.cairo(fontSize: 11, color: Colors.blue)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(order.deliveryAddress ?? tr('deliveryAddress'),
                    style: GoogleFonts.cairo(fontSize: 12), textAlign: TextAlign.start),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(OrderModel order, bool isDark) {
    final t = tr;
    final customerAsync = ref.watch(_detailCustomerProvider(order.customerId));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withValues(alpha: 0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.start, children: [
            Text(t('customer'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 8),
            const Icon(Icons.person_outline, color: Color(0xFF0D47A1)),
          ]),
          const Divider(height: 20),
          customerAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, __) => Text(t('notAvailable'), style: GoogleFonts.cairo()),
            data: (customer) {
              final c = customer;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                    Text(c?.fullName ?? t('unknown'), style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    CircleAvatar(radius: 20, backgroundColor: const Color(0xFFFF9800), backgroundImage: c?.avatarUrl != null ? NetworkImage(c!.avatarUrl!) : null, child: c?.avatarUrl == null ? const Icon(Icons.person, color: Colors.white) : null),
                  ]),
                  if (c?.phoneNumber != null) ...[
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                      Text(c!.phoneNumber!, style: GoogleFonts.cairo(color: Colors.grey[600])),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => launchUrl(Uri.parse('tel:${c.phoneNumber}')),
                        child: const Icon(Icons.phone, size: 18, color: Color(0xFFFF9800)),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      TextButton.icon(
                        onPressed: () => context.push(RoutePaths.dashboardChat(widget.orderId, order.customerId)),
                        icon: const Icon(Icons.chat, size: 18),
                        label: Text(t('chat'), style: GoogleFonts.cairo()),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF9800)),
                      ),
                      if (c?.phoneNumber != null)
                        TextButton.icon(
                          onPressed: () => launchUrl(Uri.parse('tel:${c!.phoneNumber}')),
                          icon: const Icon(Icons.phone, size: 18),
                          label: Text(t('call'), style: GoogleFonts.cairo()),
                          style: TextButton.styleFrom(foregroundColor: Colors.green),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(OrderModel order, bool isDark) {
    final t = tr;
    final invoiceAsync = ref.watch(detailInvoiceProvider(widget.orderId));
    return invoiceAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (invoice) {
        final hasInvoice = invoice != null;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: (hasInvoice ? Colors.green : Colors.orange).withValues(alpha: 0.3))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                Text(t('invoice'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 8),
                Icon(hasInvoice ? Icons.receipt_long : Icons.add_circle_outline, color: hasInvoice ? Colors.green : Colors.orange),
              ]),
              const Divider(height: 20),
              if (hasInvoice) ...[
                Text('${t('invoiceStatus')} ${invoice.statusText}', style: GoogleFonts.cairo(color: Colors.grey[600])),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${invoice.totalAmount.toStringAsFixed(0)} ج.م', style: GoogleFonts.cairo(color: Colors.grey[600])),
                    Text('${t('itemTotal')}:', style: GoogleFonts.cairo(color: Colors.grey[600])),
                  ],
                ),
                if (invoice.deliveryFee > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${invoice.deliveryFee.toStringAsFixed(0)} ج.م', style: GoogleFonts.cairo(color: Colors.grey[600])),
                      Text('${t('deliveryFee')}:', style: GoogleFonts.cairo(color: Colors.grey[600])),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${invoice.grandTotal.toStringAsFixed(0)} ج.م', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.green)),
                    Text('${t('grandTotal')}:', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                ...invoice.items.map((item) => Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[50], borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                    Text('${item.totalPrice.toStringAsFixed(0)} ج.م', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text('x${item.quantity}', style: GoogleFonts.cairo(color: Colors.grey)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item.name, style: GoogleFonts.cairo(), textAlign: TextAlign.start)),
                  ]),
                )),
                const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await context.push(RoutePaths.dashboardInvoice(widget.orderId, order.customerId));
                        ref.refresh(detailInvoiceProvider(widget.orderId));
                        ref.refresh(detailOrderProvider(widget.orderId));
                      },
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: Text(t('invoice'), style: GoogleFonts.cairo()),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.green, side: const BorderSide(color: Colors.green)),
                    ),
                  ),
                ] else ...[
                  Text(t('noInvoiceYet'), style: GoogleFonts.cairo(color: Colors.grey[600])),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await context.push(RoutePaths.dashboardInvoice(widget.orderId, order.customerId));
                        ref.refresh(detailInvoiceProvider(widget.orderId));
                        ref.refresh(detailOrderProvider(widget.orderId));
                      },
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(t('createInvoiceBtn'), style: GoogleFonts.cairo()),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(OrderModel order) {
    final t = tr;
    if (order.status == 'delivered' || order.status == 'cancelled') return const SizedBox.shrink();

    return Column(
      children: [
        if (order.status == 'pending' && order.driverId == null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isUpdating ? null : () => _acceptOrder(),
              icon: const Icon(Icons.check_circle_outline),
              label: Text(t('acceptOrder'), style: GoogleFonts.cairo()),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        if (order.status == 'driver_assigned') ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isUpdating ? null : () => _updateStatus('on_the_way'),
              icon: const Icon(Icons.directions_car),
              label: Text(t('startDelivery'), style: GoogleFonts.cairo()),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (order.status == 'on_the_way') ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isUpdating ? null : () => context.push(RoutePaths.dashboardQrCode(widget.orderId)),
              icon: const Icon(Icons.qr_code),
              label: Text(t('generateQRForDelivery'), style: GoogleFonts.cairo()),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(value, style: GoogleFonts.cairo(fontWeight: FontWeight.w600), textAlign: TextAlign.end)),
          const SizedBox(width: 8),
          Text('$label:', style: GoogleFonts.cairo(color: Colors.grey[600])),
        ],
      ),
    );
  }
}
