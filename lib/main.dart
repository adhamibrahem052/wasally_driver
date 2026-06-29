import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'shared/providers/locale_provider.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/services/local_notification_service.dart';
import 'driver/providers/router_provider.dart';
import 'shared/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _SplashApp());
}

class _SplashApp extends StatefulWidget {
  const _SplashApp();
  @override
  State<_SplashApp> createState() => _SplashAppState();
}

class _SplashAppState extends State<_SplashApp> with SingleTickerProviderStateMixin {
  bool _ready = false;
  double _progress = 0;
  SharedPreferences? _prefs;
  late AnimationController _animCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut));
    _animCtrl.repeat(reverse: true);
    _prepare();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _setProgress(double target) {
    final start = _progress;
    if (target <= start || !mounted) return;
    _progress = target;
    setState(() {});
  }

  Future<void> _prepare() async {
    await Supabase.initialize(
      url: 'https://oyrexsyebgplfretcvko.supabase.co',
      publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95cmV4c3llYmdwbGZyZXRjdmtvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyNTIyMzAsImV4cCI6MjA5NTgyODIzMH0.-qOC-QW8vP0mjP5aEAP8dzQLkOeQbO-84q0kma0L5RA',
    );
    _setProgress(0.30);
    try {
      await LocalNotificationService.init();
    } catch (_) {}
    _setProgress(0.50);
    _prefs = await SharedPreferences.getInstance();
    _setProgress(0.70);
    // Confirm auth session is resolved before transitioning
    Supabase.instance.client.auth.currentSession;
    _setProgress(0.85);
    // Small settle delay for GoRouter initial routing
    await Future.delayed(const Duration(milliseconds: 300));
    _setProgress(1.0);
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _ready
            ? ProviderScope(
                key: const ValueKey('app'),
                overrides: [
                  sharedPreferencesProvider.overrideWithValue(_prefs!),
                ],
                child: const WasallyDriverApp(),
              )
            : Scaffold(
                key: const ValueKey('splash'),
                backgroundColor: const Color(0xFFFF9800),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _pulseAnim,
                        child: const Icon(Icons.delivery_dining, size: 80, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      const Text('وصلى', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text('تطبيق السائق', style: TextStyle(fontSize: 16, color: Colors.white70)),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: 200,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: _progress,
                            minHeight: 6,
                            backgroundColor: Colors.white30,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('${(_progress * 100).toInt()}%', style: TextStyle(fontSize: 14, color: Colors.white70)),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

class WasallyDriverApp extends ConsumerWidget {
  const WasallyDriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(driverRouterProvider);
    final locale = ref.watch(localeProvider);
    final theme = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Wasally Driver',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale == null) return supportedLocales.first;
        for (final supported in supportedLocales) {
          if (supported.languageCode == locale.languageCode) return supported;
        }
        return supportedLocales.first;
      },
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: theme.mode,
      routerConfig: router,
    );
  }
}
