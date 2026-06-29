import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/localization/app_localizations.dart';
import '../../shared/models/order_model.dart';
import '../../shared/providers/locale_provider.dart';
import '../../shared/constants/route_paths.dart';
import '../../shared/widgets/common_widgets.dart';
import '../providers/driver_providers.dart';

class DriverDashboardScreen extends ConsumerWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(driverOrdersProvider);
    final pendingCount = ref.watch(driverPendingCountProvider);
    final t = (String key) => AppLocalizations(ref.watch(localeProvider)).get(key);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('driverAppName'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push(RoutePaths.dashboardNotifications),
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () => context.push(RoutePaths.dashboardCollections),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push(RoutePaths.dashboardProfile),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => invalidateAll(ref),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFF57C00)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t('welcomeDriver'), style: GoogleFonts.cairo(fontSize: 18, color: Colors.white70)),
                          const SizedBox(height: 4),
                          Text(pendingCount == 0
                              ? t('noPendingOrders')
                              : (pendingCount == 1 ? t('pendingOrders') : t('pendingOrdersPlural'))
                                  .replaceAll('%s', pendingCount.toString()),
                              style: GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(pendingCount == 0 ? '' : t('waitingForDelivery'),
                              style: GoogleFonts.cairo(fontSize: 14, color: Colors.white70)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.delivery_dining, size: 64, color: Colors.white24),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(t('currentOrders'), style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ordersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(child: Text(t('ordersLoadError'), style: GoogleFonts.cairo())),
                data: (orders) {
                  final active = orders.where((o) => o.status != 'delivered' && o.status != 'cancelled').toList();
                  if (active.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(t('noCurrentOrders'), style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey[600])),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: active.map((order) => _OrderCard(order: order)).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push(RoutePaths.dashboardOrders),
                  icon: const Icon(Icons.receipt_long),
                  label: Text(t('viewAllOrders'), style: GoogleFonts.cairo()),
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF9800), padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations(ref.watch(localeProvider));
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(RoutePaths.dashboardOrderDetail(order.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusBadge(status: order.status, loc: loc),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.orderDetails ?? '${loc.get('orderNumber')} ${order.id.substring(0, 8)}',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.start,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${order.finalTotal.toStringAsFixed(0)} ج.م', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: const Color(0xFFFF9800))),
                  const SizedBox(width: 16),
                  Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(order.deliveryAddress ?? '', style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
