import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/localization/app_localizations.dart';
import '../../shared/providers/locale_provider.dart';
import '../../shared/constants/route_paths.dart';
import '../providers/auth_provider.dart';
import '../providers/driver_providers.dart';

class DriverProfileScreen extends ConsumerWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(driverProfileProvider);
    final t = (String key) => AppLocalizations(ref.watch(localeProvider)).get(key);

    return Scaffold(
      appBar: AppBar(title: Text(t('profile'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),),
      body: RefreshIndicator(
        onRefresh: () async => invalidateAll(ref),
        child: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(child: Padding(
            padding: EdgeInsets.only(top: 40),
            child: Text(t('profileLoadError'), style: GoogleFonts.cairo()),
          )),
        ),
        data: (profile) {
          if (profile == null) return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Center(child: Padding(
              padding: EdgeInsets.only(top: 40),
              child: Text(t('profileNotAvailable'), style: GoogleFonts.cairo()),
            )),
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFFFF9800),
                      backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                      child: profile.avatarUrl == null ? const Icon(Icons.person, size: 48, color: Colors.white) : null,
                    ),
                    const SizedBox(height: 12),
                    Text(profile.fullName, style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(t('driver'), style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Column(
                  children: [
                    ListTile(leading: const Icon(Icons.phone_outlined), title: Text(profile.phoneNumber ?? '', style: GoogleFonts.cairo()), trailing: Text(t('phone'), style: GoogleFonts.cairo(color: Colors.grey))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text(t('orders'), style: GoogleFonts.cairo()),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => context.push(RoutePaths.dashboardOrders),
                    ),
                    ListTile(
                      leading: const Icon(Icons.notifications_outlined),
                      title: Text(t('notifications'), style: GoogleFonts.cairo()),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => context.push(RoutePaths.dashboardNotifications),
                    ),
                    ListTile(
                      leading: const Icon(Icons.account_balance_wallet_outlined),
                      title: Text(t('collectionsAndSupply'), style: GoogleFonts.cairo()),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => context.push(RoutePaths.dashboardCollections),
                    ),
                    ListTile(
                      leading: const Icon(Icons.store_outlined),
                      title: Text(t('storesAndInvoices'), style: GoogleFonts.cairo()),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => context.push(RoutePaths.dashboardStoreInvoices),
                    ),
                    ListTile(
                      leading: const Icon(Icons.qr_code_outlined),
                      title: Text(t('generateQRCode'), style: GoogleFonts.cairo()),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => _showQrOrderPicker(context, t),
                    ),
                    ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: Text(t('settings'), style: GoogleFonts.cairo()),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => context.push(RoutePaths.dashboardSettings),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(driverAuthProvider.notifier).signOut();
                    if (context.mounted) context.go(RoutePaths.login);
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: Text(t('logout'), style: GoogleFonts.cairo(color: Colors.red)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }

  void _showQrOrderPicker(BuildContext context, String Function(String) t) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(t('generateQRCode'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t('selectOrderForQR'), style: GoogleFonts.cairo(fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              textAlign: TextAlign.start,
              decoration: InputDecoration(
                labelText: t('orderNumber'),
                hintText: t('orderID'),
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
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.of(ctx).pop();
                context.push(RoutePaths.dashboardQrCode(controller.text.trim()));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800)),
            child: Text(t('generate'), style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
