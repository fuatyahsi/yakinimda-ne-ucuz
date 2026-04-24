/// `products` tablosunun Dart karsiligi (public read).
class SupabaseProduct {
  const SupabaseProduct({
    required this.id,
    required this.canonicalName,
    this.brand,
    this.packageSize,
    this.packageUnit,
    this.imageUrl,
    this.categoryId,
  });

  final String id;
  final String canonicalName;
  final String? brand;
  final double? packageSize;
  final String? packageUnit;
  final String? imageUrl;
  final String? categoryId;

  factory SupabaseProduct.fromJson(Map<String, dynamic> json) {
    return SupabaseProduct(
      id: json['id'] as String,
      canonicalName: (json['canonical_name'] ?? '') as String,
      brand: json['brand'] as String?,
      packageSize: _toDouble(json['package_size']),
      packageUnit: json['package_unit'] as String?,
      imageUrl: json['image_url'] as String?,
      categoryId: json['category_id']?.toString(),
    );
  }

  String get displaySize {
    if (packageSize == null || packageUnit == null) return '';
    final size = packageSize!;
    final asInt = size.truncateToDouble() == size;
    return '${asInt ? size.toInt() : size}$packageUnit';
  }
}

double? _toDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
