class AppUser {
  final String id;
  final String fullName;
  final String? phoneNumber;
  final String role;
  final String? avatarUrl;
  final double walletBalance;
  final bool isActive;
  final String? fcmToken;
  final String? address;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.fullName,
    this.phoneNumber,
    this.role = 'customer',
    this.avatarUrl,
    this.walletBalance = 0,
    this.isActive = true,
    this.fcmToken,
    this.address,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      fullName: map['full_name'] as String? ?? '',
      phoneNumber: map['phone_number'] as String?,
      role: map['role'] as String? ?? 'customer',
      avatarUrl: map['avatar_url'] as String?,
      walletBalance: (map['wallet_balance'] as num?)?.toDouble() ?? 0,
      isActive: map['is_active'] as bool? ?? true,
      fcmToken: map['fcm_token'] as String?,
      address: map['address'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'full_name': fullName,
    'phone_number': phoneNumber,
    'role': role,
    'avatar_url': avatarUrl,
    'wallet_balance': walletBalance,
    'is_active': isActive,
    'fcm_token': fcmToken,
    'address': address,
  };

  bool get isAdmin => role == 'admin';
  bool get isDriver => role == 'driver';
  bool get isStore => role == 'store';
  bool get isCustomer => role == 'customer';
}
