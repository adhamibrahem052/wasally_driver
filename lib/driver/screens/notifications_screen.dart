import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/models/other_models.dart';
import '../../shared/localization/app_localizations.dart';
import '../../shared/providers/locale_provider.dart';
import '../../shared/widgets/common_widgets.dart';
import '../providers/auth_provider.dart';
import '../providers/driver_providers.dart';

class DriverNotificationsScreen extends ConsumerStatefulWidget {
  const DriverNotificationsScreen({super.key});
  @override
  ConsumerState<DriverNotificationsScreen> createState() => _DriverNotificationsScreenState();
}

class _DriverNotificationsScreenState extends ConsumerState<DriverNotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifAsync = ref.watch(driverNotificationsProvider);
    final t = (String key) => AppLocalizations(ref.watch(localeProvider)).get(key);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('notifications'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF9800),
          labelColor: const Color(0xFFFF9800),
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.receipt_long, size: 18),
                  const SizedBox(width: 6),
                  Text(t('customerNotifications'), style: GoogleFonts.cairo(fontSize: 13)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.store_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text(t('storeNotifications'), style: GoogleFonts.cairo(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
                final user = ref.read(driverAuthProvider).supabaseUser;
              if (user != null) {
                await ref.read(driverNotifServiceProvider).markAllAsRead(user.id!);
              }
            },
            child: Text(t('markAllRead'), style: GoogleFonts.cairo(color: const Color(0xFFFF9800), fontSize: 13)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          invalidateAll(ref);
          if (mounted) ref.invalidate(driverNotificationsProvider);
        },
        child: notifAsync.when(
          loading: () => const SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: WasallyLoading(),
          ),
          error: (_, __) => WasallyError(
            message: t('notificationLoadError'),
            onRetry: () => ref.invalidate(driverNotificationsProvider),
          ),
          data: (notifs) {
            final customerNotifs = notifs.where((n) => n.type == 'order' || n.type == 'message').toList();
            final storeNotifs = notifs.where((n) => n.type == 'invoice' || n.type == 'payment' || n.type == 'store').toList();

            return TabBarView(
              controller: _tabController,
              children: [
                _buildList(customerNotifs, t('noCustomerNotifications'), Icons.receipt_long_outlined),
                _buildList(storeNotifs, t('noStoreNotifications'), Icons.store_outlined),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(List<NotificationModel> notifs, String emptyMsg, IconData emptyIcon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (notifs.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: EmptyState(message: emptyMsg, icon: emptyIcon),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: notifs.length,
      itemBuilder: (context, i) {
        final n = notifs[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: n.isRead ? (isDark ? Colors.grey[700] : Colors.grey[200]) : const Color(0xFFFF9800).withValues(alpha: 0.1),
            child: Icon(_icon(n.type), color: n.isRead ? Colors.grey : const Color(0xFFFF9800)),
          ),
          title: Text(n.title, style: GoogleFonts.cairo(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold, fontSize: 14)),
          subtitle: Text(n.body, style: GoogleFonts.cairo(fontSize: 12)),
          trailing: !n.isRead
              ? Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF9800)))
              : null,
          onTap: () async {
            if (!n.isRead) {
              await ref.read(driverNotifServiceProvider).markAsRead(n.id);
            }
          },
        );
      },
    );
  }

  IconData _icon(String type) {
    switch (type) {
      case 'order': return Icons.receipt_long;
      case 'invoice': return Icons.description;
      case 'payment': return Icons.account_balance_wallet;
      case 'store': return Icons.store;
      case 'message': return Icons.chat;
      default: return Icons.notifications;
    }
  }
}
