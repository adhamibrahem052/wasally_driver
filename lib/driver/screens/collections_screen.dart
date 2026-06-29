import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/services/collection_service.dart';
import '../../shared/localization/app_localizations.dart';
import '../../shared/providers/locale_provider.dart';
import '../../shared/providers/supabase_client_provider.dart';
import '../../shared/widgets/common_widgets.dart';
import '../providers/auth_provider.dart';
import '../providers/driver_providers.dart';

final _collectionsProvider = FutureProvider<List<DriverCollection>>((ref) async {
  final user = ref.read(driverAuthProvider).supabaseUser;
  if (user == null) return [];
  return ref.read(_collectionsServiceProvider).getDriverCollections(user.id);
});

final _totalDueProvider = FutureProvider<double>((ref) async {
  final user = ref.read(driverAuthProvider).supabaseUser;
  if (user == null) return 0;
  return ref.read(_collectionsServiceProvider).getTotalDueForDriver(user.id);
});

final _totalSupplyProvider = FutureProvider<double>((ref) async {
  final user = ref.read(driverAuthProvider).supabaseUser;
  if (user == null) return 0;
  return ref.read(_collectionsServiceProvider).getTotalSupplyForDriver(user.id);
});

final _totalConfirmedProvider = FutureProvider<double>((ref) async {
  final user = ref.read(driverAuthProvider).supabaseUser;
  if (user == null) return 0;
  return ref.read(_collectionsServiceProvider).getTotalConfirmedSupplyForDriver(user.id);
});

final _remainingProvider = FutureProvider<double>((ref) async {
  final user = ref.read(driverAuthProvider).supabaseUser;
  if (user == null) return 0;
  return ref.read(_collectionsServiceProvider).getRemainingForDriver(user.id);
});

final _collectionsServiceProvider = Provider<CollectionService>((ref) => CollectionService(ref.read(supabaseClientProvider)));

class DriverCollectionsScreen extends ConsumerStatefulWidget {
  const DriverCollectionsScreen({super.key});
  @override
  ConsumerState<DriverCollectionsScreen> createState() => _DriverCollectionsScreenState();
}

class _DriverCollectionsScreenState extends ConsumerState<DriverCollectionsScreen> {
  final _amountCtrl = TextEditingController();
  bool _submitting = false;

  String tr(String key) => AppLocalizations(ref.watch(localeProvider)).get(key);

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _showSupplyDialog() {
    final t = tr;
    _amountCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(t('submitSupply'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t('supplyDialogDesc'), style: GoogleFonts.cairo(fontSize: 13)),
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t('cancel'), style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: _submitting ? null : () async {
              final amount = double.tryParse(_amountCtrl.text);
              if (amount == null || amount <= 0) return;
              setState(() => _submitting = true);
              try {
                final user = ref.read(driverAuthProvider).supabaseUser;
                if (user == null) throw Exception('يجب تسجيل الدخول');
                await ref.read(_collectionsServiceProvider).submitSupply(
                  driverId: user.id,
                  amount: amount,
                );
                if (mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(t('supplySubmitted'), style: GoogleFonts.cairo()),
                    backgroundColor: Colors.green,
                  ));
                  ref.invalidate(_collectionsProvider);
                  ref.invalidate(_totalDueProvider);
                  ref.invalidate(_totalSupplyProvider);
                  ref.invalidate(_totalConfirmedProvider);
                  ref.invalidate(_remainingProvider);
                }
              } catch (e) {
                if (mounted) {
                  Navigator.of(ctx).pop();
                  showErrorDialog(context, e);
                }
              } finally {
                if (mounted) setState(() => _submitting = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800)),
            child: Text(t('submit'), style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalDueAsync = ref.watch(_totalDueProvider);
    final totalSupplyAsync = ref.watch(_totalSupplyProvider);
    final totalConfirmedAsync = ref.watch(_totalConfirmedProvider);
    final remainingAsync = ref.watch(_remainingProvider);
    final collectionsAsync = ref.watch(_collectionsProvider);
    final t = tr;

    return Scaffold(
      appBar: AppBar(title: Text(t('collections'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold))),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_collectionsProvider);
          ref.invalidate(_totalDueProvider);
          ref.invalidate(_totalSupplyProvider);
          ref.invalidate(_totalConfirmedProvider);
          ref.invalidate(_remainingProvider);
          invalidateAll(ref);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF1976D2)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _summaryRow(t('totalDue'), totalDueAsync),
                    const Divider(color: Colors.white24, height: 24),
                    _summaryRow(t('totalSupply'), totalSupplyAsync),
                    const Divider(color: Colors.white24, height: 24),
                    _summaryRow(t('totalConfirmed'), totalConfirmedAsync),
                    const Divider(color: Colors.white24, height: 24),
                    _summaryRow(t('remaining'), remainingAsync, isRemaining: true),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showSupplyDialog,
                        icon: const Icon(Icons.upload, size: 18),
                        label: Text(t('submitSupply'), style: GoogleFonts.cairo()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0D47A1),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(t('collectionHistory'), style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              collectionsAsync.when(
                loading: () => const WasallyLoading(),
                error: (_, _) => WasallyError(message: t('errorOccurred')),
                data: (items) {
                  if (items.isEmpty) {
                    return EmptyState(message: t('noTransactions'), icon: Icons.receipt_long_outlined);
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (item.status == 'approved' ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            item.status == 'approved' ? Icons.check_circle : Icons.upload,
                            color: item.status == 'approved' ? Colors.green : Colors.orange,
                          ),
                        ),
                        title: Text(item.typeText, style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                        subtitle: Text(item.statusText, style: GoogleFonts.cairo(fontSize: 12, color: _statusColor(item.status))),
                        trailing: Text(item.amountFormatted, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.orange)),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, AsyncValue<double> asyncValue, {bool isRemaining = false}) {
    final value = asyncValue.asData?.value ?? 0;
    return Column(
      children: [
        Text(label, style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(0)} ج.م',
          style: GoogleFonts.cairo(
            color: isRemaining ? (value > 0 ? const Color(0xFFFFCC80) : Colors.greenAccent) : Colors.white,
            fontSize: isRemaining ? 22 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSummarySkeleton() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF1976D2)]),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
  );

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }
}
