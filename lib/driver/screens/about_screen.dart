import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/localization/app_localizations.dart';
import '../../shared/providers/locale_provider.dart';

class DriverAboutScreen extends ConsumerWidget {
  const DriverAboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = (String key) => AppLocalizations(ref.watch(localeProvider)).get(key);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(t('about'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(Icons.delivery_dining, size: 80, color: Color(0xFFFF9800)),
                  const SizedBox(height: 16),
                  Text(t('appName'), style: GoogleFonts.cairo(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFFFF9800))),
                  const SizedBox(height: 4),
                  Text(t('driverVersion'), style: GoogleFonts.cairo(fontSize: 16, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text('v1.0.0', style: GoogleFonts.cairo(fontSize: 14, color: isDark ? Colors.grey[500] : Colors.grey[500])),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              t('driverAppDesc'),
              style: GoogleFonts.cairo(fontSize: 14, height: 1.6, color: isDark ? Colors.white70 : null),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  _infoRow(isDark, Icons.email_outlined, 'support@wasally.com'),
                  const SizedBox(height: 12),
                  _infoRow(isDark, Icons.phone_outlined, '+20 100 000 0000'),
                  const SizedBox(height: 12),
                  _infoRow(isDark, Icons.language_outlined, 'www.wasally.app'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(bool isDark, IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(text, style: GoogleFonts.cairo(fontSize: 14, color: isDark ? Colors.grey[300] : Colors.grey[700])),
        const SizedBox(width: 12),
        Icon(icon, size: 20, color: const Color(0xFFFF9800)),
      ],
    );
  }
}
