import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel { debug, info, warning, error }

final logService = LoggerService._();

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final String? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.stackTrace,
  });

  String get formatted {
    final t = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}.${timestamp.millisecond.toString().padLeft(3, '0')}';
    final lvl = level.name.toUpperCase().padRight(7);
    return '$t [$lvl] [${tag.padRight(20)}] $message${stackTrace != null ? '\n$stackTrace' : ''}';
  }

  String get short => '$tag: $message';
}

class LoggerService {
  LoggerService._();
  static const _maxEntries = 500;
  final List<LogEntry> _entries = [];
  final List<void Function(LogEntry)> _listeners = [];
  IOSink? _fileSink;
  Timer? _flushTimer;
  String? _logDir;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final dir = await getApplicationDocumentsDirectory();
    _logDir = dir.path;
    final file = File('$_logDir/wasally.log');
    _fileSink = file.openWrite(mode: FileMode.append);
    _rotateIfNeeded(file);
    debugPrint('[Logger] Logger initialized at ${file.path}');
  }

  bool _initialized = false;
  Future<void> _ensureInit() async {
    if (!_initialized) await init();
  }

  Future<void> _rotateIfNeeded(File file) async {
    if (await file.length() > 5 * 1024 * 1024) {
      await file.rename('$_logDir/wasally.old.log');
      final newFile = File('$_logDir/wasally.log');
      _fileSink = newFile.openWrite(mode: FileMode.append);
    }
  }

  void _write(LogEntry entry) {
    if (_fileSink != null) {
      _fileSink!.writeln(entry.formatted);
      _flushTimer ??= Timer(const Duration(seconds: 5), () {
        _fileSink?.flush();
        _flushTimer = null;
      });
    }
    debugPrint(entry.formatted);
  }

  void _log(LogLevel level, String tag, String message, [Object? error, StackTrace? stack]) {
    _ensureInit().then((_) {
      final entry = LogEntry(
        timestamp: DateTime.now(),
        level: level,
        tag: tag,
        message: message,
        stackTrace: error != null ? '$error\n$stack' : null,
      );
      _entries.add(entry);
      if (_entries.length > _maxEntries) _entries.removeAt(0);
      _write(entry);
      for (final listener in _listeners) {
        listener(entry);
      }
    });
  }

  void debug(String tag, String message) => _log(LogLevel.debug, tag, message);
  void info(String tag, String message) => _log(LogLevel.info, tag, message);
  void warning(String tag, String message, [Object? error, StackTrace? stack]) => _log(LogLevel.warning, tag, message, error, stack);
  void error(String tag, String message, [Object? error, StackTrace? stack]) => _log(LogLevel.error, tag, message, error, stack);

  List<LogEntry> get recent => List.unmodifiable(_entries.reversed.toList());

  List<LogEntry> filter({LogLevel? minLevel, String? tag}) {
    var list = _entries.reversed;
    if (minLevel != null) list = list.where((e) => e.level.index >= minLevel.index);
    if (tag != null) list = list.where((e) => e.tag.contains(tag));
    return list.toList();
  }

  void listen(void Function(LogEntry) cb) => _listeners.add(cb);
  void unlisten(void Function(LogEntry) cb) => _listeners.remove(cb);

  Future<String> exportLogs() async {
    final buf = StringBuffer();
    for (final entry in _entries) {
      buf.writeln(entry.formatted);
    }
    return buf.toString();
  }

  Future<void> clear() async {
    _entries.clear();
    _fileSink?.flush();
    final file = File('$_logDir/wasally.log');
    if (await file.exists()) await file.writeAsString('');
  }

  void dispose() {
    _fileSink?.flush();
    _fileSink?.close();
    _flushTimer?.cancel();
  }
}
