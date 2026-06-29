import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/services/message_service.dart';
import '../../shared/models/other_models.dart';
import '../../shared/providers/supabase_client_provider.dart';
import '../providers/auth_provider.dart';
import '../../shared/widgets/common_widgets.dart';

final _chatServiceProvider = Provider<MessageService>((ref) => MessageService(ref.read(supabaseClientProvider)));

class DriverChatScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String customerId;
  const DriverChatScreen({super.key, required this.orderId, required this.customerId});

  @override
  ConsumerState<DriverChatScreen> createState() => _DriverChatScreenState();
}

class _DriverChatScreenState extends ConsumerState<DriverChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <MessageModel>[];
  StreamSubscription? _sub;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _sub?.cancel();
    super.dispose();
  }

  void _init() {
    final userId = ref.read(driverAuthProvider).supabaseUser?.id ?? '';
    ref.read(_chatServiceProvider).getMessages(
      userId1: userId,
      userId2: widget.customerId,
      orderId: widget.orderId,
    ).then((msgs) {
      if (mounted) setState(() { _messages.addAll(msgs); _loading = false; });
      _scrollDown();
    });

    _sub = ref.read(_chatServiceProvider)
        .getMessagesStream(userId, widget.customerId, orderId: widget.orderId)
        .listen((msgs) {
      if (!mounted) return;
      setState(() {
        for (final m in msgs) {
          final i = _messages.indexWhere((x) => x.id == m.id || x.id.startsWith('local_'));
          if (i >= 0) { _messages[i] = m; } else { _messages.add(m); }
        }
        _messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });
      _scrollDown();
    });
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.animateTo(0, duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
    });
  }

  void _send() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    final userId = ref.read(driverAuthProvider).supabaseUser?.id ?? '';
    if (userId.isEmpty) return;

    final temp = MessageModel(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      senderId: userId,
      receiverId: widget.customerId,
      message: text,
      orderId: widget.orderId,
      createdAt: DateTime.now(),
    );
    setState(() { _messages.insert(0, temp); });
    _msgController.clear();
    _scrollDown();

    try {
      await ref.read(_chatServiceProvider).sendMessage(
        senderId: userId,
        receiverId: widget.customerId,
        message: text,
        orderId: widget.orderId,
      );
    } catch (e) {
      if (mounted) showErrorDialog(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text('محادثة العميل', style: GoogleFonts.cairo())),
      body: Column(
        children: [
          Expanded(child: _buildMessages(isDark)),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildMessages(bool isDark) {
    final userId = ref.read(driverAuthProvider).supabaseUser?.id ?? '';
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_messages.isEmpty) return Center(child: Text('لا توجد رسائل بعد', style: GoogleFonts.cairo(color: Colors.grey)));
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      reverse: true,
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final m = _messages[i];
        final isMe = m.senderId == userId;
        return Align(
          alignment: isMe ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFFFF9800) : (isDark ? Colors.grey[800] : Colors.grey[100]),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                bottomRight: isMe ? Radius.zero : const Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.message, style: GoogleFonts.cairo(color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87), fontSize: 14)),
                const SizedBox(height: 4),
                Text('${m.createdAt.hour}:${m.createdAt.minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.cairo(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgController,
                decoration: InputDecoration(
                  hintText: 'اكتب رسالة...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100],
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: const Color(0xFFFF9800),
              child: IconButton(
                icon: const Icon(Icons.send, size: 18, color: Colors.white),
                onPressed: _send,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
