class InvoiceModel {
  final String id;
  final String orderId;
  final String driverId;
  final String customerId;
  final String? storeId;
  final String status;
  final double totalAmount;
  final double deliveryFee;
  final double grandTotal;
  final String paymentMethod;
  final String? storeNotes;
  final String? driverNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<InvoiceItem> items;

  InvoiceModel({
    required this.id,
    required this.orderId,
    required this.driverId,
    required this.customerId,
    this.storeId,
    this.status = 'pending',
    this.totalAmount = 0,
    this.deliveryFee = 0,
    this.grandTotal = 0,
    this.paymentMethod = 'cash',
    this.storeNotes,
    this.driverNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.items = const [],
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory InvoiceModel.fromMap(Map<String, dynamic> map) => InvoiceModel(
    id: map['id'] as String,
    orderId: map['order_id'] as String,
    driverId: map['driver_id'] as String,
    customerId: map['customer_id'] as String,
    storeId: map['store_id'] as String?,
    status: map['status'] as String? ?? 'pending',
    totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
    deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ?? 0,
    grandTotal: (map['grand_total'] as num?)?.toDouble() ?? 0,
    paymentMethod: map['payment_method'] as String? ?? 'cash',
    storeNotes: map['store_notes'] as String?,
    driverNotes: map['driver_notes'] as String?,
    createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
    updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : DateTime.now(),
    items: map['items'] != null
        ? (map['items'] as List).map((m) => InvoiceItem.fromMap(m)).toList()
        : const [],
  );

  Map<String, dynamic> toMap() => {
    'order_id': orderId,
    'driver_id': driverId,
    'customer_id': customerId,
    'store_id': storeId,
    'status': status,
    'total_amount': totalAmount,
    'delivery_fee': deliveryFee,
    'grand_total': grandTotal,
    'payment_method': paymentMethod,
    'store_notes': storeNotes,
    'driver_notes': driverNotes,
  };

  String get statusText {
    switch (status) {
      case 'pending': return 'قيد المراجعة';
      case 'store_accepted': return 'تم قبول المتجر';
      case 'store_rejected': return 'رفض المتجر';
      case 'modified': return 'تم التعديل';
      case 'customer_confirmed': return 'تأكيد العميل';
      case 'paid': return 'مدفوع';
      default: return status;
    }
  }
}

class InvoiceItem {
  final String id;
  final String invoiceId;
  final String? productId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final bool isAvailable;
  final String? substituteNotes;

  InvoiceItem({
    required this.id,
    required this.invoiceId,
    this.productId,
    required this.name,
    this.quantity = 1,
    required this.unitPrice,
    required this.totalPrice,
    this.isAvailable = true,
    this.substituteNotes,
  });

  factory InvoiceItem.fromMap(Map<String, dynamic> map) => InvoiceItem(
    id: map['id'] as String,
    invoiceId: map['invoice_id'] as String,
    productId: map['product_id'] as String?,
    name: map['name'] as String,
    quantity: map['quantity'] as int? ?? 1,
    unitPrice: (map['unit_price'] as num).toDouble(),
    totalPrice: (map['total_price'] as num).toDouble(),
    isAvailable: map['is_available'] as bool? ?? true,
    substituteNotes: map['substitute_notes'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'invoice_id': invoiceId,
    'product_id': productId,
    'name': name,
    'quantity': quantity,
    'unit_price': unitPrice,
    'total_price': totalPrice,
    'is_available': isAvailable,
    'substitute_notes': substituteNotes,
  };
}
