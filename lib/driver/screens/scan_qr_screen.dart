import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../shared/services/order_service.dart';
import '../../shared/providers/supabase_client_provider.dart';
import '../../shared/widgets/common_widgets.dart';

final _scanServiceProvider = Provider<OrderService>((ref) => OrderService(ref.read(supabaseClientProvider)));

class DriverScanQrScreen extends ConsumerStatefulWidget {
  const DriverScanQrScreen({super.key});
  @override
  ConsumerState<DriverScanQrScreen> createState() => _DriverScanQrScreenState();
}

class _DriverScanQrScreenState extends ConsumerState<DriverScanQrScreen> {
  bool _processing = false;
  MobileScannerController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processing) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null) return;
    _processing = true;
    final orderId = code.startsWith('order_') ? code.substring(6) : code;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text('رقم الطلب: $orderId', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('هل تريد تأكيد توصيل هذا الطلب؟', style: GoogleFonts.cairo()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { _processing = false; context.pop(); },
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(_scanServiceProvider).confirmDelivery(orderId);
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('تم تأكيد التوصيل بنجاح', style: GoogleFonts.cairo()),
                    backgroundColor: Colors.green,
                  ));
                  context.pop();
                }
              } catch (e) {
                if (mounted) {
                  Navigator.of(context).pop();
                  showErrorDialog(context, e);
                  _processing = false;
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800)),
            child: Text('تأكيد التوصيل', style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('مسح QR للتوصيل', style: GoogleFonts.cairo())),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFFF9800), width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 80, left: 0, right: 0,
            child: Text(
              'وجه الكاميرا نحو QR Code الخاص بالفاتورة',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, shadows: const [Shadow(color: Colors.black54, blurRadius: 4)]),
            ),
          ),
        ],
      ),
    );
  }
}
