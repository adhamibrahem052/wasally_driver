import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/models/store_models.dart';
import '../../shared/providers/supabase_client_provider.dart';
import '../../shared/localization/app_localizations.dart';
import '../../shared/providers/locale_provider.dart';
import '../../shared/widgets/common_widgets.dart';
import '../providers/auth_provider.dart';
import '../providers/driver_providers.dart';
class DriverStoreInvoicesScreen extends ConsumerStatefulWidget {
  const DriverStoreInvoicesScreen({super.key});
  @override
  ConsumerState<DriverStoreInvoicesScreen> createState() => _DriverStoreInvoicesScreenState();
}

class _DriverStoreInvoicesScreenState extends ConsumerState<DriverStoreInvoicesScreen> {
  String tr(String key) => AppLocalizations(ref.watch(localeProvider)).get(key);

  @override
  Widget build(BuildContext context) {
    final storesAsync = ref.watch(driverStoresProvider);
    final t = tr;

    return Scaffold(
      appBar: AppBar(title: Text(t('storesAndInvoices'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold))),
      body: RefreshIndicator(
        onRefresh: () async => invalidateAll(ref),
        child: storesAsync.when(
        loading: () => const SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: WasallyLoading(message: 'جارٍ تحميل المتاجر...'),
        ),
        error: (_, __) => SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: WasallyError(message: t('storesLoadError')),
        ),
        data: (stores) {
          if (stores.isEmpty) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: EmptyState(message: t('noStoresAvailable'), icon: Icons.store_outlined),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: stores.length,
            itemBuilder: (_, i) {
              final store = stores[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showStoreInvoiceDialog(store),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(store.name, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(store.address ?? '', style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey[600])),
                            const SizedBox(height: 4),
                            Text(store.phone ?? '', style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: store.logoUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(store.logoUrl!, fit: BoxFit.cover),
                                )
                              : const Icon(Icons.store, color: Color(0xFFFF9800), size: 28),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        ),
      ),
    );
  }

  final _amountCtrl = TextEditingController();
  String _paymentMethod = 'cash';
  bool _savingStoreInvoice = false;

  void _showStoreInvoiceDialog(StoreModel store) {
    _amountCtrl.clear();
    _paymentMethod = 'cash';
    final t = tr;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(t('storeInvoiceTitle'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${t('storeLabel')} ${store.name}', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: t('amount'),
                  prefixText: 'ج.م ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _paymentMethod,
                decoration: InputDecoration(
                  labelText: t('paymentMethod'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                  DropdownMenuItem(value: 'instapay', child: Text('إنستاباي')),
                  DropdownMenuItem(value: 'wallet', child: Text('محفظة')),
                  DropdownMenuItem(value: 'bank', child: Text('تحويل بنكي')),
                ],
                onChanged: (v) {
                  setDialogState(() => _paymentMethod = v ?? 'cash');
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(t('cancel'), style: GoogleFonts.cairo()),
            ),
            ElevatedButton(
              onPressed: _savingStoreInvoice ? null : () async {
                final amount = double.tryParse(_amountCtrl.text);
                if (amount == null || amount <= 0) return;
                setDialogState(() => _savingStoreInvoice = true);
                try {
                  final user = ref.read(driverAuthProvider).supabaseUser;
                  if (user == null) throw Exception('يجب تسجيل الدخول');
                  await ref.read(supabaseClientProvider).from('driver_store_invoices').insert({
                    'driver_id': user.id,
                    'store_id': store.id,
                    'total_amount': amount,
                    'payment_method': _paymentMethod,
                    'status': 'pending',
                  });
                  if (mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(t('storeInvoiceSent'), style: GoogleFonts.cairo()),
                      backgroundColor: Colors.green,
                    ));
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.of(ctx).pop();
                    showErrorDialog(context, e);
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800)),
              child: _savingStoreInvoice
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(t('save'), style: GoogleFonts.cairo(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }
}
