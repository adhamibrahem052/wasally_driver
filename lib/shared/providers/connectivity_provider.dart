import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/app_localizations.dart';
import 'locale_provider.dart';

final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map((results) {
    return results.any((r) => r != ConnectivityResult.none);
  });
});

final initialConnectivityProvider = FutureProvider<bool>((ref) async {
  final results = await Connectivity().checkConnectivity();
  return results.any((r) => r != ConnectivityResult.none);
});

class ConnectivityGuard extends ConsumerStatefulWidget {
  final Widget child;
  const ConnectivityGuard({super.key, required this.child});

  @override
  ConsumerState<ConnectivityGuard> createState() => _ConnectivityGuardState();
}

class _ConnectivityGuardState extends ConsumerState<ConnectivityGuard> {
  Future<void> _retry() async {
    final results = await Connectivity().checkConnectivity();
    final connected = results.any((r) => r != ConnectivityResult.none);
    if (connected) {
      ref.invalidate(connectivityProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations(ref.watch(localeProvider));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final connectivityAsync = ref.watch(connectivityProvider);

    return connectivityAsync.when(
      loading: () => widget.child,
      error: (_, __) => widget.child,
      data: (isConnected) {
        if (!isConnected) {
          return Stack(
            children: [
              widget.child,
              Positioned.fill(
                child: Container(
                  color: (isDark ? const Color(0xFF121212) : Colors.white).withValues(alpha: 0.95),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off_rounded, size: 80, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                        const SizedBox(height: 20),
                        Text(
                          loc.get('noInternet'),
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          loc.get('checkInternet'),
                          style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: 200,
                          child: ElevatedButton.icon(
                            onPressed: _retry,
                            icon: const Icon(Icons.refresh, size: 20),
                            label: Text(loc.get('retryConnection')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF9800),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return widget.child;
      },
    );
  }
}
