import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/services/payment_service.dart';
import '../../shared/models/other_models.dart';
import '../../shared/providers/supabase_client_provider.dart';
import '../../shared/widgets/common_widgets.dart';
import '../providers/auth_provider.dart';

final _walletServiceProvider = Provider<PaymentService>((ref) => PaymentService(ref.read(supabaseClientProvider)));
final _walletBalanceProvider = StreamProvider.family<double, String>((ref, userId) {
  return ref.read(_walletServiceProvider).getWalletBalanceStream(userId);
});
final _walletTransactionsProvider = StreamProvider.family<List<WalletTransaction>, String>((ref, userId) {
  return ref.read(_walletServiceProvider).getWalletTransactionsStream(userId);
});

class DriverWalletScreen extends ConsumerWidget {
  const DriverWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.read(driverAuthProvider).supabaseUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('المحفظة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold))),
        body: WasallyError(message: 'الرجاء تسجيل الدخول'),
      );
    }

    final balanceAsync = ref.watch(_walletBalanceProvider(user.id));
    final transactionsAsync = ref.watch(_walletTransactionsProvider(user.id));

    return Scaffold(
      appBar: AppBar(title: Text('المحفظة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            balanceAsync.when(
              loading: () => _buildBalanceSkeleton(),
              error: (_, __) => WasallyError(
                message: 'خطأ في تحميل الرصيد',
                onRetry: () => ref.invalidate(_walletBalanceProvider(user.id)),
              ),
              data: (balance) => _buildBalanceCard(balance),
            ),
            const SizedBox(height: 30),
            Align(
              alignment: Alignment.centerRight,
              child: Text('المعاملات', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            transactionsAsync.when(
              loading: () => WasallyLoading(message: 'جارٍ تحميل المعاملات...'),
              error: (_, __) => WasallyError(
                message: 'خطأ في تحميل المعاملات',
                onRetry: () => ref.invalidate(_walletTransactionsProvider(user.id)),
              ),
              data: (txns) {
                if (txns.isEmpty) {
                  return EmptyState(message: 'لا توجد معاملات بعد', icon: Icons.receipt_long_outlined);
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: txns.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = txns[i];
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _txColor(t.type).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_txIcon(t.type), color: _txColor(t.type)),
                      ),
                      title: Text(_txLabel(t.type), style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                      subtitle: Text(t.description ?? '', style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey)),
                      trailing: Text(
                        '${t.type == 'earning' || t.type == 'deposit' || t.type == 'refund' ? '+' : '-'}${t.amount.toStringAsFixed(2)} ج.م',
                        style: GoogleFonts.cairo(
                          color: t.type == 'earning' || t.type == 'deposit' || t.type == 'refund' ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceSkeleton() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(30),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFF57C00)]),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
  );

  Widget _buildBalanceCard(double balance) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(30),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFF57C00)]),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        Text('رصيد المحفظة', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        Text('${balance.toStringAsFixed(2)} ج.م',
            style: GoogleFonts.cairo(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
      ],
    ),
  );

  IconData _txIcon(String type) {
    switch (type) {
      case 'earning': return Icons.trending_up;
      case 'deposit': return Icons.add_circle_outline;
      case 'withdrawal': return Icons.remove_circle_outline;
      case 'payment': return Icons.shopping_cart_outlined;
      case 'refund': return Icons.replay_circle_filled_outlined;
      default: return Icons.receipt_long_outlined;
    }
  }

  Color _txColor(String type) {
    switch (type) {
      case 'earning': return Colors.green;
      case 'deposit': return Colors.green;
      case 'withdrawal': return Colors.orange;
      case 'payment': return Colors.red;
      case 'refund': return Colors.blue;
      default: return Colors.grey;
    }
  }

  String _txLabel(String type) {
    switch (type) {
      case 'earning': return 'أرباح';
      case 'deposit': return 'إيداع';
      case 'withdrawal': return 'سحب';
      case 'payment': return 'دفع';
      case 'refund': return 'استرجاع';
      default: return type;
    }
  }
}
