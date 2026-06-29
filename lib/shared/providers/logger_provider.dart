import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/logger_service.dart';

final loggerProvider = Provider<LoggerService>((ref) {
  ref.onDispose(() => logService.dispose());
  return logService;
});
