import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/localization/app_localizations.dart';
import '../../shared/providers/locale_provider.dart';
import '../../shared/constants/route_paths.dart';
import '../../shared/widgets/common_widgets.dart';
import '../providers/driver_providers.dart';

class DriverOrdersScreen extends ConsumerStatefulWidget {
  const DriverOrdersScreen({super.key});
  @override
  ConsumerState<DriverOrdersScreen> createState() => _DriverOrdersScreenState();
}

class _DriverOrdersScreenState extends ConsumerState<DriverOrdersScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(driverOrdersProvider);
    }
  }

  String tr(String key) => AppLocalizations(ref.watch(localeProvider)).get(key);

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(driverOrdersProvider);
    final t = tr;

    return Scaffold(
      appBar: AppBar(title: Text(t('allOrders'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold))),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(t('ordersLoadError'), style: GoogleFonts.cairo())),
        data: (orders) {
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(t('noOrders'), style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey[600])),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(driverOrdersProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, i) {
                final order = orders[i];
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
                                  order.orderDetails ?? '${t('orderNumber')} ${order.id.substring(0, 8)}',
                                  style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                                  textAlign: TextAlign.start,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text('${order.finalTotal.toStringAsFixed(0)} ج.م', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: const Color(0xFFFF9800))),
                              const Spacer(),
                              Text('${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}', style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  AppLocalizations get loc => AppLocalizations(ref.watch(localeProvider));
}
