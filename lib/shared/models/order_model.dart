class OrderModel {
  final String id;
  final String customerId;
  final String? driverId;
  final String? storeId;
  final String orderType;
  final String? orderDetails;
  final String status;
  final String? notes;
  final double totalPrice;
  final double deliveryFee;
  final double finalTotal;
  final String paymentMethod;
  final String paymentStatus;
  final String? deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLng;
  final bool qrCodeVerified;
  final int? rating;
  final String? ratingComment;
  final String? cancelledReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderItem> items;

  OrderModel({
    required this.id,
    required this.customerId,
    this.driverId,
    this.storeId,
    this.orderType = 'manual',
    this.orderDetails,
    this.status = 'pending',
    this.notes,
    this.totalPrice = 0,
    this.deliveryFee = 0,
    this.finalTotal = 0,
    this.paymentMethod = 'cash',
    this.paymentStatus = 'pending',
    this.deliveryAddress,
    this.deliveryLat,
    this.deliveryLng,
    this.qrCodeVerified = false,
    this.rating,
    this.ratingComment,
    this.cancelledReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.items = const [],
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: map['id'] as String,
      customerId: map['customer_id'] as String,
      driverId: map['driver_id'] as String?,
      storeId: map['store_id'] as String?,
      orderType: map['order_type'] as String? ?? 'manual',
      orderDetails: map['order_details'] as String?,
      status: map['status'] as String? ?? 'pending',
      notes: map['notes'] as String?,
      totalPrice: (map['total_price'] as num?)?.toDouble() ?? 0,
      deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ?? 0,
      finalTotal: (map['final_total'] as num?)?.toDouble() ?? 0,
      paymentMethod: map['payment_method'] as String? ?? 'cash',
      paymentStatus: map['payment_status'] as String? ?? 'pending',
      deliveryAddress: map['delivery_address'] as String?,
      deliveryLat: (map['delivery_lat'] as num?)?.toDouble(),
      deliveryLng: (map['delivery_lng'] as num?)?.toDouble(),
      qrCodeVerified: map['qr_code_verified'] as bool? ?? false,
      rating: map['rating'] as int?,
      ratingComment: map['rating_comment'] as String?,
      cancelledReason: map['cancelled_reason'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'customer_id': customerId,
    'driver_id': driverId,
    'store_id': storeId,
    'order_type': orderType,
    'order_details': orderDetails,
    'status': status,
    'notes': notes,
    'total_price': totalPrice,
    'delivery_fee': deliveryFee,
    'final_total': finalTotal,
    'payment_method': paymentMethod,
    'payment_status': paymentStatus,
    'delivery_address': deliveryAddress,
    'delivery_lat': deliveryLat,
    'delivery_lng': deliveryLng,
    'qr_code_verified': qrCodeVerified,
    'rating': rating,
    'rating_comment': ratingComment,
    'cancelled_reason': cancelledReason,
  };

  String get statusText {
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

  int get statusIndex {
    const statuses = ['pending','driver_assigned','store_confirmed','preparing','on_the_way','delivered'];
    return statuses.indexOf(status);
  }
}

class OrderItem {
  final String id;
  final String orderId;
  final String? productId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? notes;

  OrderItem({
    required this.id,
    required this.orderId,
    this.productId,
    required this.name,
    this.quantity = 1,
    required this.unitPrice,
    required this.totalPrice,
    this.notes,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
    id: map['id'] as String,
    orderId: map['order_id'] as String,
    productId: map['product_id'] as String?,
    name: map['name'] as String,
    quantity: map['quantity'] as int? ?? 1,
    unitPrice: (map['unit_price'] as num).toDouble(),
    totalPrice: (map['total_price'] as num).toDouble(),
    notes: map['notes'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'order_id': orderId,
    'product_id': productId,
    'name': name,
    'quantity': quantity,
    'unit_price': unitPrice,
    'total_price': totalPrice,
    'notes': notes,
  };
}
