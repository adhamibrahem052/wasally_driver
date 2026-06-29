import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../../shared/localization/app_localizations.dart';
import '../../shared/providers/locale_provider.dart';
import '../../shared/providers/theme_provider.dart';
import '../../shared/constants/route_paths.dart';
import '../providers/driver_providers.dart';

class DriverSettingsScreen extends ConsumerStatefulWidget {
  const DriverSettingsScreen({super.key});
  @override
  ConsumerState<DriverSettingsScreen> createState() => _DriverSettingsScreenState();
}

class _DriverSettingsScreenState extends ConsumerState<DriverSettingsScreen> {
  bool _gpsEnabled = false;
  bool _gpsChecking = true;

  @override
  void initState() {
    super.initState();
    _checkGpsStatus();
  }

  Future<void> _checkGpsStatus() async {
    setState(() => _gpsChecking = true);
    final enabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();
    if (mounted) {
      setState(() {
        _gpsEnabled = enabled && (permission == LocationPermission.always || permission == LocationPermission.whileInUse);
        _gpsChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);
    final t = (String key) => AppLocalizations(ref.watch(localeProvider)).get(key);

    return Scaffold(
      appBar: AppBar(title: Text(t('settings'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline, color: Color(0xFFFF9800)),
              title: Text(t('editAccount'), style: GoogleFonts.cairo()),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () async {
                await context.push(RoutePaths.dashboardEditProfile);
                ref.invalidate(driverProfileProvider);
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: Text(t('darkMode'), style: GoogleFonts.cairo()),
              secondary: Icon(theme.mode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode, color: const Color(0xFFFF9800)),
              value: theme.mode == ThemeMode.dark,
              onChanged: (v) => theme.setDarkMode(v),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language, color: Color(0xFFFF9800)),
              title: Text(t('language'), style: GoogleFonts.cairo()),
              subtitle: Text(locale.languageCode == 'ar' ? t('arabic') : t('english'), style: GoogleFonts.cairo()),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => ref.read(localeProvider.notifier).toggleLanguage(),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(_gpsEnabled ? Icons.location_on : Icons.location_off, color: _gpsEnabled ? Colors.green : const Color(0xFFFF9800)),
              title: Text(t('gpsLocation'), style: GoogleFonts.cairo()),
              subtitle: Text(
                _gpsChecking ? '...' : (_gpsEnabled ? t('active') : t('gpsSubtitle')),
                style: GoogleFonts.cairo(fontSize: 12, color: _gpsEnabled ? Colors.green : null),
              ),
              trailing: _gpsChecking
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () async {
                if (_gpsEnabled) {
                  await Geolocator.openAppSettings();
                  return;
                }
                final status = await Geolocator.requestPermission();
                if (status == LocationPermission.always || status == LocationPermission.whileInUse) {
                  final enabled = await Geolocator.isLocationServiceEnabled();
                  if (!enabled) {
                    if (mounted) {
                      await showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(t('gpsLocation'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                          content: Text(t('gpsSubtitle'), style: GoogleFonts.cairo()),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: Text(t('cancel'), style: GoogleFonts.cairo()),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                Geolocator.openLocationSettings();
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800)),
                              child: Text(t('settings'), style: GoogleFonts.cairo(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    }
                  }
                  await _checkGpsStatus();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(_gpsEnabled ? t('gpsActivated') : t('gpsSubtitle'), style: GoogleFonts.cairo()),
                      backgroundColor: _gpsEnabled ? Colors.green : Colors.orange,
                    ));
                  }
                } else if (status == LocationPermission.deniedForever) {
                  await Geolocator.openAppSettings();
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(t('aboutApp'), style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Color(0xFFFF9800)),
                  title: Text(t('about'), style: GoogleFonts.cairo()),
                  subtitle: Text(t('driverVersion'), style: GoogleFonts.cairo()),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => context.push(RoutePaths.dashboardAbout),
                  onLongPress: () => context.push(RoutePaths.dashboardLogs),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined, color: Color(0xFFFF9800)),
                  title: Text(t('terms'), style: GoogleFonts.cairo()),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => context.push(RoutePaths.dashboardTerms),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
