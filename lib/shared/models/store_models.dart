class StoreModel {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? coverUrl;
  final String? phone;
  final String? address;
  final double? lat;
  final double? lng;
  final bool isActive;
  final bool deliveryAvailable;
  final DateTime createdAt;

  StoreModel({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.logoUrl,
    this.coverUrl,
    this.phone,
    this.address,
    this.lat,
    this.lng,
    this.isActive = true,
    this.deliveryAvailable = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory StoreModel.fromMap(Map<String, dynamic> map) => StoreModel(
    id: map['id'] as String,
    ownerId: map['owner_id'] as String,
    name: map['name'] as String,
    description: map['description'] as String?,
    logoUrl: map['logo_url'] as String?,
    coverUrl: map['cover_url'] as String?,
    phone: map['phone'] as String?,
    address: map['address'] as String?,
    lat: (map['lat'] as num?)?.toDouble(),
    lng: (map['lng'] as num?)?.toDouble(),
    isActive: map['is_active'] as bool? ?? true,
    deliveryAvailable: map['delivery_available'] as bool? ?? true,
    createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'owner_id': ownerId,
    'name': name,
    'description': description,
    'logo_url': logoUrl,
    'cover_url': coverUrl,
    'phone': phone,
    'address': address,
    'lat': lat,
    'lng': lng,
    'is_active': isActive,
    'delivery_available': deliveryAvailable,
  };
}

class ProductModel {
  final String id;
  final String storeId;
  final String? categoryId;
  final String name;
  final String? description;
  final double price;
  final double? comparePrice;
  final List<String> images;
  final String unit;
  final int stock;
  final bool isAvailable;
  final DateTime createdAt;

  ProductModel({
    required this.id,
    required this.storeId,
    this.categoryId,
    required this.name,
    this.description,
    required this.price,
    this.comparePrice,
    this.images = const [],
    this.unit = 'قطعة',
    this.stock = 0,
    this.isAvailable = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ProductModel.fromMap(Map<String, dynamic> map) => ProductModel(
    id: map['id'] as String,
    storeId: map['store_id'] as String,
    categoryId: map['category_id'] as String?,
    name: map['name'] as String,
    description: map['description'] as String?,
    price: (map['price'] as num).toDouble(),
    comparePrice: (map['compare_price'] as num?)?.toDouble(),
    images: (map['images'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
    unit: map['unit'] as String? ?? 'قطعة',
    stock: map['stock'] as int? ?? 0,
    isAvailable: map['is_available'] as bool? ?? true,
    createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'store_id': storeId,
    'category_id': categoryId,
    'name': name,
    'description': description,
    'price': price,
    'compare_price': comparePrice,
    'images': images,
    'unit': unit,
    'stock': stock,
    'is_available': isAvailable,
  };
}

class CategoryModel {
  final String id;
  final String name;
  final String? icon;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;

  CategoryModel({
    required this.id,
    required this.name,
    this.icon,
    this.imageUrl,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) => CategoryModel(
    id: map['id'] as String,
    name: map['name'] as String,
    icon: map['icon'] as String?,
    imageUrl: map['image_url'] as String?,
    sortOrder: map['sort_order'] as int? ?? 0,
    isActive: map['is_active'] as bool? ?? true,
  );
}
