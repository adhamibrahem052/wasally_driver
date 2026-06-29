import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/providers/locale_provider.dart';
import '../../shared/localization/app_localizations.dart';
import '../../shared/providers/logger_provider.dart';
import '../../shared/services/logger_service.dart';

class LogViewerScreen extends ConsumerStatefulWidget {
  const LogViewerScreen({super.key});

  @override
  ConsumerState<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends ConsumerState<LogViewerScreen> {
  LogLevel? _filter;
  String _search = '';

  String t(String key) => AppLocalizations(ref.read(localeProvider)).get(key);

  @override
  Widget build(BuildContext context) {
    final logger = ref.read(loggerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    var logs = logger.recent;
    if (_filter != null) logs = logs.where((e) => e.level == _filter).toList();
    if (_search.isNotEmpty) logs = logs.where((e) => e.tag.contains(_search) || e.message.contains(_search)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الأخطاء', style: TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await logger.clear();
              setState(() {});
            },
            tooltip: 'مسح السجلات',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              final text = await logger.exportLogs();
              await Clipboard.setData(ClipboardData(text: text));
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ السجلات')));
            },
            tooltip: 'تصدير السجلات',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(90),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'بحث...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                  ),
                  style: GoogleFonts.cairo(fontSize: 13),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _filterChip(null, 'الكل', isDark),
                    const SizedBox(width: 6),
                    _filterChip(LogLevel.debug, 'Debug', isDark),
                    const SizedBox(width: 6),
                    _filterChip(LogLevel.info, 'Info', isDark),
                    const SizedBox(width: 6),
                    _filterChip(LogLevel.warning, 'Warning', isDark),
                    const SizedBox(width: 6),
                    _filterChip(LogLevel.error, 'Error', isDark),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
      body: logs.isEmpty
          ? Center(child: Text('لا توجد سجلات', style: GoogleFonts.cairo(color: Colors.grey)))
          : ListView.builder(
              itemCount: logs.length,
              itemBuilder: (_, i) {
                final log = logs[i];
                return _logTile(log, isDark);
              },
            ),
    );
  }

  Widget _filterChip(LogLevel? level, String label, bool isDark) {
    final selected = _filter == level;
    return FilterChip(
      label: Text(label, style: GoogleFonts.cairo(fontSize: 11)),
      selected: selected,
      onSelected: (_) => setState(() => _filter = level),
      visualDensity: VisualDensity.compact,
      selectedColor: level != null
          ? {
              LogLevel.debug: Colors.grey,
              LogLevel.info: Colors.blue,
              LogLevel.warning: Colors.orange,
              LogLevel.error: Colors.red,
            }[level]
          : null,
      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
    );
  }

  Widget _logTile(LogEntry log, bool isDark) {
    final color = switch (log.level) {
      LogLevel.debug => Colors.grey,
      LogLevel.info => Colors.blue,
      LogLevel.warning => Colors.orange,
      LogLevel.error => Colors.red,
    };
    return InkWell(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: log.formatted));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم النسخ: ${log.tag}')));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!, width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}',
                    style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  Text('[${log.tag}] ${log.message}',
                      style: GoogleFonts.cairo(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
