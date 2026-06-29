import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../localization/app_localizations.dart';

void showErrorDialog(BuildContext context, dynamic error) {
  String title = 'حدث خطأ';
  String message;
  if (error is AuthException) {
    message = _translateAuthError(error.message);
  } else if (error is Exception) {
    message = error.toString().replaceFirst('Exception: ', '');
  } else {
    message = '$error';
  }
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 56, color: Colors.red),
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey[700])),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('حسناً', style: GoogleFonts.cairo(color: const Color(0xFFFF9800))),
        ),
      ],
    ),
  );
}

String _translateAuthError(String message) {
  if (message.contains('Email not confirmed')) return 'البريد الإلكتروني غير مؤكد. يرجى التحقق من بريدك.';
  if (message.contains('Invalid login credentials')) return 'بيانات الدخول غير صحيحة. تأكد من البريد وكلمة المرور.';
  if (message.contains('Email already registered')) return 'البريد الإلكتروني مسجل مسبقاً. استخدم بريد آخر أو سجل دخول.';
  if (message.contains('Password should be at least')) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل.';
  if (message.contains('rate limit')) return 'طلبات كثيرة جداً. حاول مرة أخرى بعد دقيقة.';
  if (message.contains('network') || message.contains('Network')) return 'مشكلة في الاتصال. تحقق من الإنترنت وحاول مرة أخرى.';
  if (message.contains('timeout')) return 'انتهت المهلة. تحقق من اتصالك وحاول مرة أخرى.';
  return message;
}

class WasallyButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? textColor;
  final IconData? icon;
  final bool isLoading;
  final double? width;
  final double height;

  const WasallyButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color,
    this.textColor,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? const Color(0xFFFF9800),
          foregroundColor: textColor ?? Colors.white,
          disabledBackgroundColor: Colors.grey[300],
        ),
        child: isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon), const SizedBox(width: 8)],
                  Text(text, style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class WasallyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int? maxLines;

  const WasallyTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintTextDirection: TextDirection.rtl,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      ),
    );
  }
}

class WasallyLoading extends StatelessWidget {
  final String? message;
  const WasallyLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFFFF9800)),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: GoogleFonts.cairo(color: Colors.grey)),
          ],
        ],
      ),
    );
  }
}

class WasallyError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;
  const WasallyError({super.key, required this.message, this.onRetry, this.retryLabel});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey[600])),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              WasallyButton(text: retryLabel ?? 'Retry', onPressed: onRetry, width: 200),
            ],
          ],
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  final AppLocalizations? loc;
  const StatusBadge({super.key, required this.status, this.loc});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'pending': color = Colors.orange; break;
      case 'driver_assigned': case 'store_confirmed': color = Colors.blue; break;
      case 'preparing': color = Colors.amber; break;
      case 'on_the_way': color = Colors.green; break;
      case 'delivered': color = const Color(0xFF0D47A1); break;
      case 'cancelled': case 'rejected': color = Colors.red; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(_getText(), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  String _getText() {
    if (loc != null) {
      switch (status) {
        case 'pending': return loc!.get('pending');
        case 'driver_assigned': return loc!.get('assigned');
        case 'store_confirmed': return loc!.get('storeConfirmed');
        case 'preparing': return loc!.get('preparing');
        case 'on_the_way': return loc!.get('onTheWay');
        case 'delivered': return loc!.get('delivered');
        case 'cancelled': return loc!.get('cancelled');
        case 'rejected': return loc!.get('rejected');
        default: return status;
      }
    }
    switch (status) {
      case 'pending': return 'قيد الانتظار';
      case 'driver_assigned': return 'تم تعيين سائق';
      case 'store_confirmed': return 'تم تأكيد المتجر';
      case 'preparing': return 'جاري التجهيز';
      case 'on_the_way': return 'في الطريق';
      case 'delivered': return 'تم التسليم';
      case 'cancelled': return 'ملغي';
      case 'rejected': return 'مرفوض';
      default: return status;
    }
  }
}

class OrderStatusStepper extends StatelessWidget {
  final int currentStep;
  const OrderStatusStepper({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const steps = ['قيد الانتظار', 'تم التجهيز', 'في الطريق', 'تم التسليم'];
    return Row(
      children: List.generate(steps.length, (i) {
        final isDone = i <= currentStep;
        final isLast = i == steps.length - 1;
        return Expanded(
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone ? Colors.orange : Colors.grey[300],
                    ),
                    child: Icon(isDone ? Icons.check : Icons.more_horiz, color: Colors.white, size: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(steps[i], style: TextStyle(fontSize: 10, color: isDone ? Colors.orange : Colors.grey)),
                ],
              ),
              if (!isLast)
                Expanded(
                  child: Container(height: 2, color: i < currentStep ? Colors.orange : Colors.grey[300]),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 16)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              WasallyButton(text: actionLabel!, onPressed: onAction, width: 200),
            ],
          ],
        ),
      ),
    );
  }
}
