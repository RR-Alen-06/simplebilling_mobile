class ProductModel {
  final String id;
  final String? userId;
  final String? productCode;
  final String name;
  final String category;
  final double price;
  final String? createdAt;

  ProductModel({
    required this.id,
    this.userId,
    this.productCode,
    required this.name,
    this.category = 'General',
    required this.price,
    this.createdAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      productCode: json['product_code'] as String?,
      name: json['name'] as String? ?? 'Product',
      category: json['category'] as String? ?? 'General',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      if (productCode != null) 'product_code': productCode,
      'name': name,
      'category': category,
      'price': price,
      if (createdAt != null) 'created_at': createdAt,
    };
  }
}
