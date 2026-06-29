import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../shared/services/order_service.dart';
import '../../shared/services/invoice_service.dart';
import '../../shared/models/order_model.dart';
import '../../shared/models/invoice_model.dart';
import '../../shared/localization/app_localizations.dart';
import '../../shared/providers/locale_provider.dart';
import '../../shared/providers/supabase_client_provider.dart';
import '../../shared/widgets/common_widgets.dart';

final _qrOrderProvider = FutureProvider.family<OrderModel?, String>((ref, id) async {
  return ref.read(_qrServiceProvider).getOrderById(id);
});
final _qrServiceProvider = Provider<OrderService>((ref) => OrderService(ref.read(supabaseClientProvider)));
final _qrInvoiceProvider = StreamProvider.family<InvoiceModel?, String>((ref, orderId) {
  return ref.read(_qrInvoiceServiceProvider).getInvoiceStream(orderId);
});
final _qrInvoiceServiceProvider = Provider<InvoiceService>((ref) => InvoiceService(ref.read(supabaseClientProvider)));

class DriverQrCodeScreen extends ConsumerWidget {
  final String orderId;
  const DriverQrCodeScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(_qrOrderProvider(orderId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = (String key) => AppLocalizations(ref.watch(localeProvider)).get(key);

    return Scaffold(
      appBar: AppBar(title: Text(t('qrDelivery'), style: GoogleFonts.cairo())),
      body: orderAsync.when(
        loading: () => WasallyLoading(message: t('loading')),
        error: (_, __) => WasallyError(message: t('qrLoadError'), onRetry: () => ref.invalidate(_qrOrderProvider(orderId))),
        data: (order) {
          if (order == null) return WasallyError(message: t('orderNotFound'));
          final qrData = 'order_${order.id}';
          final invoiceAsync = ref.watch(_qrInvoiceProvider(orderId));
          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 32),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isDark ? null : [BoxShadow(color: Colors.grey.withValues(alpha: 0.2), blurRadius: 10)],
                  ),
                  child: Column(
                    children: [
                      Text(t('orderQRTitle'), style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 24),
                      QrImageView(data: qrData, version: QrVersions.auto, size: 220, backgroundColor: Colors.white),
                      const SizedBox(height: 16),
                      Text(t('qrScanInstruction'),
                          style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row(t('orderNumber'), order.id.substring(0, 12)),
                      _row(t('orderDetails'), order.orderDetails ?? t('quickOrder')),
                      if (invoiceAsync.asData?.value != null) ...[
                        const Divider(height: 16),
                        _row(t('itemTotal'), '${invoiceAsync.asData!.value!.totalAmount.toStringAsFixed(0)} ج.م'),
                        _row(t('deliveryFee'), '${invoiceAsync.asData!.value!.deliveryFee.toStringAsFixed(0)} ج.م'),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text('${invoiceAsync.asData!.value!.grandTotal.toStringAsFixed(0)} ج.م',
                                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange),
                                  textAlign: TextAlign.left),
                            ),
                            const SizedBox(width: 12),
                            Text('${t('grandTotal')}:',
                                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ] else ...[
                        _row(t('grandTotal'), '${order.finalTotal.toStringAsFixed(0)} ج.م'),
                      ],
                      const Divider(height: 16),
                      _row(t('paymentMethod'), order.paymentMethod == 'cash' ? t('cash') : order.paymentMethod),
                      _row(t('invoiceStatus'), order.statusText),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(value, style: GoogleFonts.cairo(fontWeight: FontWeight.bold), textAlign: TextAlign.left)),
          const SizedBox(width: 12),
          Text('$label:', style: GoogleFonts.cairo(color: Colors.grey[600])),
        ],
      ),
    );
  }
}
