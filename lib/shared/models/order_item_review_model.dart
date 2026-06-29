class OrderItemReview {
  final String id;
  final String orderId;
  final String itemName;
  final int itemQuantity;
  final double itemPrice;
  final String status;
  final String? rejectionReason;
  final DateTime? reviewedAt;

  OrderItemReview({
    required this.id,
    required this.orderId,
    required this.itemName,
    required this.itemQuantity,
    required this.itemPrice,
    this.status = 'pending',
    this.rejectionReason,
    this.reviewedAt,
  });

  factory OrderItemReview.fromMap(Map<String, dynamic> map) => OrderItemReview(
    id: map['id'] as String,
    orderId: map['order_id'] as String,
    itemName: map['item_name'] as String,
    itemQuantity: map['item_quantity'] as int? ?? 1,
    itemPrice: (map['item_price'] as num).toDouble(),
    status: map['status'] as String? ?? 'pending',
    rejectionReason: map['rejection_reason'] as String?,
    reviewedAt: map['reviewed_at'] != null ? DateTime.parse(map['reviewed_at'] as String) : null,
  );

  Map<String, dynamic> toMap() => {
    'order_id': orderId,
    'item_name': itemName,
    'item_quantity': itemQuantity,
    'item_price': itemPrice,
    'status': status,
    'rejection_reason': rejectionReason,
    'reviewed_at': reviewedAt?.toIso8601String(),
  };
}
