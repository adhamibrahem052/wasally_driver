import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class DriverSplashScreen extends ConsumerStatefulWidget {
  const DriverSplashScreen({super.key});
  @override
  ConsumerState<DriverSplashScreen> createState() => _DriverSplashScreenState();
}

class _DriverSplashScreenState extends ConsumerState<DriverSplashScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delivery_dining, size: 80, color: Color(0xFFFF9800)),
            const SizedBox(height: 16),
            Text('وصلى', style: GoogleFonts.cairo(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFFFF9800))),
            const SizedBox(height: 8),
            Text('تطبيق السائق', style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: Color(0xFFFF9800)),
          ],
        ),
      ),
    );
  }
}
