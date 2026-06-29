class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final String? referenceId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.type = 'general',
    this.referenceId,
    this.isRead = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory NotificationModel.fromMap(Map<String, dynamic> map) => NotificationModel(
    id: map['id'] as String,
    userId: map['user_id'] as String,
    title: map['title'] as String,
    body: map['body'] as String,
    type: map['type'] as String? ?? 'general',
    referenceId: map['reference_id'] as String?,
    isRead: map['is_read'] as bool? ?? false,
    createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
  );
}

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String? orderId;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.orderId,
    required this.message,
    this.isRead = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MessageModel.fromMap(Map<String, dynamic> map) => MessageModel(
    id: map['id'] as String,
    senderId: map['sender_id'] as String,
    receiverId: map['receiver_id'] as String,
    orderId: map['order_id'] as String?,
    message: map['message'] as String,
    isRead: map['is_read'] as bool? ?? false,
    createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'sender_id': senderId,
    'receiver_id': receiverId,
    'order_id': orderId,
    'message': message,
  };
}

class ComplaintModel {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String description;
  final String status;
  final String? adminReply;
  final bool isRead;
  final DateTime createdAt;

  ComplaintModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.description,
    this.status = 'pending',
    this.adminReply,
    this.isRead = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ComplaintModel.fromMap(Map<String, dynamic> map) => ComplaintModel(
    id: map['id'] as String,
    userId: map['user_id'] as String,
    type: map['type'] as String,
    title: map['title'] as String,
    description: map['description'] as String,
    status: map['status'] as String? ?? 'pending',
    adminReply: map['admin_reply'] as String?,
    isRead: map['is_read'] as bool? ?? false,
    createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'type': type,
    'title': title,
    'description': description,
  };

  String get complaintNumber => '#${id.substring(0, 6).toUpperCase()}';
}

class RatingModel {
  final String id;
  final String orderId;
  final String userId;
  final int? driverRating;
  final int? appRating;
  final int? deliveryRating;
  final String? comment;
  final DateTime createdAt;

  RatingModel({
    required this.id,
    required this.orderId,
    required this.userId,
    this.driverRating,
    this.appRating,
    this.deliveryRating,
    this.comment,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory RatingModel.fromMap(Map<String, dynamic> map) => RatingModel(
    id: map['id'] as String,
    orderId: map['order_id'] as String,
    userId: map['user_id'] as String,
    driverRating: map['driver_rating'] as int?,
    appRating: map['app_rating'] as int?,
    deliveryRating: map['delivery_rating'] as int?,
    comment: map['comment'] as String?,
    createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'order_id': orderId,
    'user_id': userId,
    'driver_rating': driverRating,
    'app_rating': appRating,
    'delivery_rating': deliveryRating,
    'comment': comment,
  };
}

class PaymentMethod {
  final String id;
  final String type;
  final String name;
  final String details;
  final String? accountNumber;
  final String? accountId;
  final bool isActive;

  PaymentMethod({
    required this.id,
    required this.type,
    required this.name,
    required this.details,
    this.accountNumber,
    this.accountId,
    this.isActive = true,
  });

  factory PaymentMethod.fromMap(Map<String, dynamic> map) => PaymentMethod(
    id: map['id'] as String,
    type: map['type'] as String,
    name: map['name'] as String,
    details: map['details'] as String,
    accountNumber: map['account_number'] as String?,
    accountId: map['account_id'] as String?,
    isActive: map['is_active'] as bool? ?? true,
  );
}

class WalletTransaction {
  final String id;
  final String userId;
  final String type;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String? referenceId;
  final String? description;
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.referenceId,
    this.description,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory WalletTransaction.fromMap(Map<String, dynamic> map) => WalletTransaction(
    id: map['id'] as String,
    userId: map['user_id'] as String,
    type: map['type'] as String,
    amount: (map['amount'] as num).toDouble(),
    balanceBefore: (map['balance_before'] as num).toDouble(),
    balanceAfter: (map['balance_after'] as num).toDouble(),
    referenceId: map['reference_id'] as String?,
    description: map['description'] as String?,
    createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
  );
}

class PaymentModel {
  final String id;
  final String userId;
  final String? orderId;
  final double amount;
  final String paymentMethod;
  final String status;
  final String? transactionRef;
  final DateTime createdAt;

  PaymentModel({
    required this.id,
    required this.userId,
    this.orderId,
    required this.amount,
    required this.paymentMethod,
    this.status = 'pending',
    this.transactionRef,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory PaymentModel.fromMap(Map<String, dynamic> map) => PaymentModel(
    id: map['id'] as String,
    userId: map['user_id'] as String,
    orderId: map['order_id'] as String?,
    amount: (map['amount'] as num).toDouble(),
    paymentMethod: map['payment_method'] as String,
    status: map['status'] as String? ?? 'pending',
    transactionRef: map['transaction_ref'] as String?,
    createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
  );
}
