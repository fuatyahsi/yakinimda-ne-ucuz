/// `current_campaigns` VIEW'indan gelen aktif kampanya satiri.
///
/// View, `campaigns` tablosundan su an gecerli olanlari filtreliyor:
///   status = 'active' AND valid_from <= today AND valid_until >= today
class SupabaseCampaign {
  const SupabaseCampaign({
    required this.id,
    required this.marketId,
    required this.rawProductName,
    this.brand,
    required this.discountPrice,
    this.regularPrice,
    this.currency = 'TRY',
    required this.validFrom,
    required this.validUntil,
    required this.daysRemaining,
    this.brochureImageUrl,
    this.sourceUrl,
    this.productId,
  });

  final String id;
  final String marketId;
  final String rawProductName;
  final String? brand;
  final double discountPrice;
  final double? regularPrice;
  final String currency;
  final DateTime validFrom;
  final DateTime validUntil;
  final int daysRemaining;
  final String? brochureImageUrl;
  final String? sourceUrl;
  final String? productId;

  factory SupabaseCampaign.fromJson(Map<String, dynamic> json) {
    return SupabaseCampaign(
      id: json['id'] as String,
      marketId: json['market_id'] as String,
      rawProductName: (json['raw_product_name'] ?? '') as String,
      brand: json['brand'] as String?,
      discountPrice: _toDouble(json['discount_price']) ?? 0,
      regularPrice: _toDouble(json['regular_price']),
      currency: (json['currency'] as String?) ?? 'TRY',
      validFrom: DateTime.parse(json['valid_from'] as String),
      validUntil: DateTime.parse(json['valid_until'] as String),
      daysRemaining: (json['days_remaining'] as num?)?.toInt() ?? 0,
      brochureImageUrl: json['brochure_image_url'] as String?,
      sourceUrl: json['source_url'] as String?,
      productId: json['product_id'] as String?,
    );
  }

  double? get discountRatio {
    if (regularPrice == null || regularPrice == 0) return null;
    return (regularPrice! - discountPrice) / regularPrice!;
  }
}

double? _toDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
