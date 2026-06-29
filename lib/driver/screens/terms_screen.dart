import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/localization/app_localizations.dart';
import '../../shared/providers/locale_provider.dart';

class DriverTermsScreen extends ConsumerWidget {
  const DriverTermsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = (String key) => AppLocalizations(ref.watch(localeProvider)).get(key);

    return Scaffold(
      appBar: AppBar(title: Text(t('terms'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section(t('intro'), t('termsIntro')),
            _section(t('services'), t('termsServices')),
            _section(t('responsibility'), t('termsResponsibilities')),
            _section(t('collections'), t('termsCollections')),
            _section(t('termsCommission'), t('termsCommission')),
            _section(t('termsTermination'), t('termsTermination')),
            const SizedBox(height: 20),
            Text(t('termsUpdated'), style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFFF9800))),
          const SizedBox(height: 8),
          Text(content, style: GoogleFonts.cairo(fontSize: 14, height: 1.6), textAlign: TextAlign.right),
          const Divider(height: 24),
        ],
      ),
    );
  }
}
