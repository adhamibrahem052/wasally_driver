import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';

final themeProvider = ChangeNotifierProvider<AppTheme>((ref) {
  final theme = AppTheme();
  theme.loadTheme();
  return theme;
});
