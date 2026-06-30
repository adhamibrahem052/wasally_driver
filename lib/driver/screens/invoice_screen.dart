import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../shared/services/order_service.dart';
import '../../shared/services/invoice_service.dart';
import '../../shared/models/order_model.dart';
import '../../shared/models/invoice_model.dart';
import '../../shared/models/store_models.dart';
import '../../shared/localization/app_localizations.dart';
import '../../shared/providers/locale_provider.dart';
import '../../shared/constants/route_paths.dart';
import '../../shared/providers/supabase_client_provider.dart';
import '../../shared/widgets/common_widgets.dart';
import '../providers/auth_provider.dart';

final _invoiceServiceProvider = Provider.autoDispose<InvoiceService>((ref) => InvoiceService(ref.read(supabaseClientProvider)));
final _invoiceOrderProvider = FutureProvider.family.autoDispose<OrderModel?, String>((ref, orderId) async {
  return ref.read(_invoiceOrderServiceProvider).getOrderById(orderId);
});
final _invoiceOrderServiceProvider = Provider.autoDispose<OrderService>((ref) => OrderService(ref.read(supabaseClientProvider)));
final _invoiceProvider = FutureProvider.family.autoDispose<InvoiceModel?, String>((ref, orderId) async {
  return ref.read(_invoiceServiceProvider).getInvoiceByOrderId(orderId);
});
final _invoiceStoreProvider = FutureProvider.family.autoDispose<StoreModel?, String>((ref, storeId) async {
  if (storeId.isEmpty) return null;
  final supabase = ref.read(supabaseClientProvider);
  final res = await supabase.from('stores').select().eq('id', storeId).single();
  return StoreModel.fromMap(res);
});

class DriverInvoiceScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String customerId;
  const DriverInvoiceScreen({super.key, required this.orderId, required this.customerId});

  @override
  ConsumerState<DriverInvoiceScreen> createState() => _DriverInvoiceScreenState();
}

class _DriverInvoiceScreenState extends ConsumerState<DriverInvoiceScreen> {
  final _itemNameCtrl = TextEditingController();
  final _itemQtyCtrl = TextEditingController(text: '1');
  final _itemPriceCtrl = TextEditingController();
  final _deliveryFeeCtrl = TextEditingController();
  final _items = <_InvoiceItem>[];
  final _existingItems = <_InvoiceItem>[];
  double _deliveryFee = 0;
  bool _saving = false;
  bool _editing = false;
  String? _existingInvoiceId;
  StreamSubscription<List<Map<String, dynamic>>>? _invoiceRealtimeSub;

  @override
  void initState() {
    super.initState();
    final supabase = ref.read(supabaseClientProvider);
    _invoiceRealtimeSub = supabase
        .from('invoices')
        .stream(primaryKey: ['id'])
        .eq('order_id', widget.orderId)
        .listen((_) {
      ref.invalidate(_invoiceProvider(widget.orderId));
      ref.invalidate(_invoiceOrderProvider(widget.orderId));
    });
  }

  @override
  void dispose() {
    _itemNameCtrl.dispose();
    _itemQtyCtrl.dispose();
    _itemPriceCtrl.dispose();
    _deliveryFeeCtrl.dispose();
    _invoiceRealtimeSub?.cancel();
    super.dispose();
  }

  double get _totalAmount => _items.fold<double>(0, (sum, i) => sum + i.totalPrice) + _existingItems.fold<double>(0, (sum, i) => sum + i.totalPrice);
  double get _grandTotal => _totalAmount + _deliveryFee;

  void _addItem() {
    final name = _itemNameCtrl.text.trim();
    final qty = int.tryParse(_itemQtyCtrl.text) ?? 1;
    final price = double.tryParse(_itemPriceCtrl.text) ?? 0;
    if (name.isEmpty || price <= 0) {
      showErrorDialog(context, tr('enterItemNameAndPrice'));
      return;
    }
    setState(() {
      _items.add(_InvoiceItem(name: name, quantity: qty, unitPrice: price, totalPrice: qty * price));
      _itemNameCtrl.clear();
      _itemQtyCtrl.text = '1';
      _itemPriceCtrl.clear();
    });
  }

  void _removeItem(int i) => setState(() => _items.removeAt(i));
  void _removeExistingItem(int i) => setState(() => _existingItems.removeAt(i));

  String tr(String key) => AppLocalizations(ref.watch(localeProvider)).get(key);

  Future<void> _saveInvoice() async {
    final allItems = [..._existingItems, ..._items];
    if (allItems.isEmpty) {
      showErrorDialog(context, tr('addAtLeastOneItem'));
      return;
    }
    setState(() => _saving = true);
    try {
      final user = ref.read(driverAuthProvider).supabaseUser;
      if (user == null) throw Exception('يجب تسجيل الدخول');
      final service = ref.read(_invoiceServiceProvider);
      await service.createInvoice(
        orderId: widget.orderId,
        driverId: user.id,
        customerId: widget.customerId,
        totalAmount: allItems.fold(0, (sum, i) => sum + i.totalPrice),
        deliveryFee: _deliveryFee,
        paymentMethod: 'cash',
        items: allItems.map((i) => {
          'name': i.name,
          'quantity': i.quantity,
          'unit_price': i.unitPrice,
          'total_price': i.totalPrice,
        }).toList(),
      );
      await ref.read(supabaseClientProvider).from('orders').update({'final_total': _grandTotal}).eq('id', widget.orderId);
      ref.invalidate(_invoiceProvider(widget.orderId));
      ref.invalidate(_invoiceOrderProvider(widget.orderId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('invoiceCreated'), style: GoogleFonts.cairo()),
          backgroundColor: Colors.green,
        ));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateInvoice() async {
    final allItems = [..._existingItems, ..._items];
    if (allItems.isEmpty) {
      showErrorDialog(context, tr('addAtLeastOneItem'));
      return;
    }
    setState(() => _saving = true);
    try {
      if (_existingInvoiceId != null) {
        final supabase = ref.read(supabaseClientProvider);
        await supabase.from('invoice_items').delete().eq('invoice_id', _existingInvoiceId!);
        for (final item in allItems) {
          await supabase.from('invoice_items').insert({
            'invoice_id': _existingInvoiceId,
            'name': item.name,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'total_price': item.totalPrice,
          });
        }
        final newTotalAmount = allItems.fold<double>(0, (sum, i) => sum + i.totalPrice);
        final newGrandTotal = newTotalAmount + _deliveryFee;
        await supabase.from('invoices').update({
          'total_amount': newTotalAmount,
          'delivery_fee': _deliveryFee,
          'grand_total': newGrandTotal,
        }).eq('id', _existingInvoiceId!);
        await supabase.from('orders').update({
          'final_total': newGrandTotal,
          'delivery_fee': _deliveryFee,
        }).eq('id', widget.orderId);
      }
      ref.invalidate(_invoiceProvider(widget.orderId));
      ref.invalidate(_invoiceOrderProvider(widget.orderId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('changesSavedToast'), style: GoogleFonts.cairo()),
          backgroundColor: Colors.green,
        ));
        setState(() {
          _editing = false;
          _items.clear();
        });
      }
    } catch (e) {
      if (mounted) showErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoiceAsync = ref.watch(_invoiceProvider(widget.orderId));
    final orderAsync = ref.watch(_invoiceOrderProvider(widget.orderId));
    final t = tr;

    return Scaffold(
      appBar: AppBar(title: Text(t('invoice'), style: GoogleFonts.cairo())),
      body: invoiceAsync.when(
        loading: () => const WasallyLoading(message: 'جارٍ تحميل الفاتورة...'),
        error: (_, __) => WasallyError(message: t('errorOccurred')),
        data: (invoice) {
          if (invoice != null) return _buildExistingInvoice(invoice, orderAsync);
          return _buildCreateInvoice(orderAsync);
        },
      ),
    );
  }

  Widget _buildAddressSection(OrderModel? order) {
    if (order == null) return const SizedBox.shrink();
    final t = tr;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(t('deliveryAddress'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF0D47A1))),
              const SizedBox(width: 6),
              const Icon(Icons.location_on, size: 18, color: Color(0xFF0D47A1)),
            ],
          ),
          const Divider(height: 16),
          if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty) ...[
            _addressRow(t('manualAddress'), order.deliveryAddress!),
          ],
          if (order.deliveryLat != null && order.deliveryLng != null) ...[
            const SizedBox(height: 6),
            _addressRow('GPS', '${order.deliveryLat!.toStringAsFixed(6)}, ${order.deliveryLng!.toStringAsFixed(6)}'),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(order.deliveryLat!, order.deliveryLng!),
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(flags: ~InteractiveFlag.all),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.wasally.driver',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(order.deliveryLat!, order.deliveryLng!),
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on, size: 36, color: Colors.red),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _addressRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Expanded(
          child: Text(value, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.end),
        ),
        const SizedBox(width: 8),
        Text('$label:', style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildChatSection(OrderModel? order) {
    if (order == null) return const SizedBox.shrink();
    final t = tr;
    final storeAsync = order.storeId != null ? ref.watch(_invoiceStoreProvider(order.storeId!)) : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(t('chat'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green[700])),
              const SizedBox(width: 6),
              const Icon(Icons.chat, size: 18, color: Colors.green),
            ],
          ),
          const Divider(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push(RoutePaths.dashboardChat(widget.orderId, order.customerId)),
              icon: const Icon(Icons.person, size: 18),
              label: Text(t('customerChat'), style: GoogleFonts.cairo()),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.green, side: const BorderSide(color: Colors.green)),
            ),
          ),
          if (storeAsync != null) ...[
            const SizedBox(height: 8),
            storeAsync.when(
              loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              error: (_, __) => const SizedBox.shrink(),
              data: (store) {
                if (store == null) return const SizedBox.shrink();
                return SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(RoutePaths.dashboardChat(widget.orderId, store.ownerId)),
                    icon: const Icon(Icons.store, size: 18),
                    label: Text('${t('storeChat')} ${store.name}', style: GoogleFonts.cairo()),
                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF9800), side: const BorderSide(color: const Color(0xFFFF9800))),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    t('chatInfo'),
                    style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey[600]),
                    textAlign: TextAlign.start,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.info_outline, size: 14, color: Colors.grey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingInvoice(InvoiceModel invoice, AsyncValue<OrderModel?> orderAsync) {
    final order = orderAsync.asData?.value;
    final t = tr;

    if (_editing) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && mounted) {
            setState(() => _editing = false);
          }
        },
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(_invoiceProvider(widget.orderId)),
          child: _buildEditInvoice(order, invoice),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(_invoiceProvider(widget.orderId)),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(t('invoice'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 8),
                    const Icon(Icons.description, color: Colors.orange),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(invoice.statusText, style: GoogleFonts.cairo(color: Colors.grey[600])),
                    Text('${t('invoiceStatus')} ', style: GoogleFonts.cairo(color: Colors.grey[600])),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${invoice.totalAmount.toStringAsFixed(0)} ج.م', style: GoogleFonts.cairo(color: Colors.grey[600])),
                    Text('${t('itemTotal')}:', style: GoogleFonts.cairo(color: Colors.grey[600])),
                  ],
                ),
                if (invoice.deliveryFee > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${invoice.deliveryFee.toStringAsFixed(0)} ج.م', style: GoogleFonts.cairo(color: Colors.grey[600])),
                      Text('${t('deliveryFee')}:', style: GoogleFonts.cairo(color: Colors.grey[600])),
                    ],
                  ),
                ],
                const Divider(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${invoice.grandTotal.toStringAsFixed(0)} ج.م',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange)),
                    Text(t('grandTotal'), style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...invoice.items.map((item) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                        Text('${t('quantity')}: ${item.quantity}', style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${item.totalPrice.toStringAsFixed(0)} ج.م',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.orange)),
                ],
              ),
            ),
          )),
          const SizedBox(height: 16),
          _buildAddressSection(order),
          const SizedBox(height: 16),
          _buildChatSection(order),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
                onPressed: () => context.push(RoutePaths.dashboardQrCode(widget.orderId)),
              icon: const Icon(Icons.qr_code, size: 20),
              label: Text(t('generateQR'), style: GoogleFonts.cairo()),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _populateFromInvoice(invoice);
                setState(() => _editing = true);
              },
              icon: const Icon(Icons.edit, size: 20),
              label: Text(t('editInvoice'), style: GoogleFonts.cairo()),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange), padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ],
      ),
    ),
    );
  }

  void _populateFromInvoice(InvoiceModel invoice) {
    _existingInvoiceId = invoice.id;
    _deliveryFee = invoice.deliveryFee;
    _deliveryFeeCtrl.text = invoice.deliveryFee > 0 ? invoice.deliveryFee.toStringAsFixed(0) : '';
    _existingItems.clear();
    for (final item in invoice.items) {
      _existingItems.add(_InvoiceItem(
        name: item.name,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        totalPrice: item.totalPrice,
      ));
    }
  }

  Widget _buildEditInvoice(OrderModel? order, InvoiceModel invoice) {
    final t = tr;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('editInvoice'), style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(t('addMoreItems'), style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 8),
          TextField(
            controller: _itemNameCtrl,
            textAlign: TextAlign.start,
            decoration: InputDecoration(
              labelText: t('itemName'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _itemPriceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: t('price'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _itemQtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: t('quantity'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: Text(t('addMoreItems'), style: GoogleFonts.cairo()),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange)),
            ),
          ),
          const SizedBox(height: 16),
          ..._existingItems.map((item) => _buildExistingItemRow(item)),
          if (_items.isNotEmpty) const Divider(height: 16),
          ..._items.map((item) => _buildNewItemRow(item)),
          const SizedBox(height: 12),
          TextField(
            keyboardType: TextInputType.number,
            textAlign: TextAlign.start,
            decoration: InputDecoration(
              labelText: t('deliveryFee'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            controller: _deliveryFeeCtrl,
            onChanged: (v) => setState(() => _deliveryFee = double.tryParse(v) ?? 0),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_grandTotal.toStringAsFixed(0)} ج.م', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
              Text(t('grandTotal'), style: GoogleFonts.cairo(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _updateInvoice,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(t('saveChanges'), style: GoogleFonts.cairo(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingItemRow(_InvoiceItem item) {
    final i = _existingItems.indexOf(item);
    return Card(
      child: ListTile(
        title: Text(item.name, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        subtitle: Text('${item.quantity} × ${item.unitPrice.toStringAsFixed(0)} = ${item.totalPrice.toStringAsFixed(0)} ج.م',
            style: GoogleFonts.cairo(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.orange),
              onPressed: () => _editExistingItem(i),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _removeExistingItem(i),
            ),
          ],
        ),
        onTap: () => _editExistingItem(i),
      ),
    );
  }

  Future<void> _editExistingItem(int index) async {
    if (index < 0 || index >= _existingItems.length) return;
    final item = _existingItems[index];
    final nameCtrl = TextEditingController(text: item.name);
    final qtyCtrl = TextEditingController(text: item.quantity.toString());
    final priceCtrl = TextEditingController(text: item.unitPrice.toStringAsFixed(0));
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr('editInvoice'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textAlign: TextAlign.start,
              decoration: InputDecoration(labelText: tr('itemName'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: tr('price'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: tr('quantity'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('cancel'), style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop({
              'name': nameCtrl.text.trim(),
              'quantity': int.tryParse(qtyCtrl.text) ?? 1,
              'unitPrice': double.tryParse(priceCtrl.text) ?? 0,
            }),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800)),
            child: Text(tr('save'), style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() {
        final name = result['name'] as String? ?? item.name;
        final quantity = result['quantity'] as int? ?? item.quantity;
        final unitPrice = result['unitPrice'] as double? ?? item.unitPrice;
        _existingItems[index] = _InvoiceItem(
          name: name.isNotEmpty ? name : item.name,
          quantity: quantity > 0 ? quantity : item.quantity,
          unitPrice: unitPrice > 0 ? unitPrice : item.unitPrice,
          totalPrice: (quantity > 0 ? quantity : item.quantity) * (unitPrice > 0 ? unitPrice : item.unitPrice),
        );
      });
    }
    nameCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }

  Widget _buildNewItemRow(_InvoiceItem item) {
    final i = _items.indexOf(item);
    return Card(
      child: ListTile(
        title: Text(item.name, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        subtitle: Text('${item.quantity} × ${item.unitPrice.toStringAsFixed(0)} = ${item.totalPrice.toStringAsFixed(0)} ج.م',
            style: GoogleFonts.cairo(fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _removeItem(i),
        ),
      ),
    );
  }

  Widget _buildCreateInvoice(AsyncValue<OrderModel?> orderAsync) {
    final order = orderAsync.asData?.value;
    final t = tr;
    return RefreshIndicator(
      onRefresh: () async {
        ref.refresh(_invoiceOrderProvider(widget.orderId));
        ref.refresh(_invoiceProvider(widget.orderId));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('createInvoice'), style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (orderAsync.isLoading)
              const WasallyLoading(message: 'جارٍ تحميل عنوان العميل...')
            else
              _buildAddressSection(order),
            const SizedBox(height: 12),
            if (!orderAsync.isLoading) _buildChatSection(order),
            const SizedBox(height: 12),
            TextField(
              controller: _itemNameCtrl,
              textAlign: TextAlign.start,
              decoration: InputDecoration(
                labelText: t('itemName'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _itemPriceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: t('price'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _itemQtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: t('quantity'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
                label: Text(t('addItem'), style: GoogleFonts.cairo()),
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(_items.length, (i) {
              final item = _items[i];
              return Card(
                child: ListTile(
                  title: Text(item.name, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  subtitle: Text('${item.quantity} × ${item.unitPrice.toStringAsFixed(0)} = ${item.totalPrice.toStringAsFixed(0)} ج.م',
                      style: GoogleFonts.cairo(fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeItem(i),
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            TextField(
              keyboardType: TextInputType.number,
              textAlign: TextAlign.start,
              decoration: InputDecoration(
                labelText: t('deliveryFee'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => setState(() => _deliveryFee = double.tryParse(v) ?? 0),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_grandTotal.toStringAsFixed(0)} ج.م', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
                Text(t('grandTotal'), style: GoogleFonts.cairo(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
              onPressed: () => context.push(RoutePaths.dashboardQrCode(widget.orderId)),
                icon: const Icon(Icons.qr_code, size: 20),
                label: Text(t('generateQR'), style: GoogleFonts.cairo()),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF0D47A1), side: const BorderSide(color: const Color(0xFF0D47A1)), padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveInvoice,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(t('saveInvoice'), style: GoogleFonts.cairo(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceItem {
  final String name;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  _InvoiceItem({required this.name, required this.quantity, required this.unitPrice, required this.totalPrice});
}
