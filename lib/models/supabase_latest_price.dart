/// `latest_prices` MV'den gelen tek (product, market, branch) satir.
///
/// Materialized view pg_cron ile her 15 dakikada bir refresh edilir.
class SupabaseLatestPrice {
  const SupabaseLatestPrice({
    required this.productId,
    required this.marketId,
    this.branchId,
    required this.price,
    this.unitPrice,
    this.unitPriceLabel,
    this.currency = 'TRY',
    this.isOnSale = false,
    required this.observedAt,
    this.source,
    this.sourceUrl,
  });

  final String productId;
  final String marketId;
  final int? branchId;
  final double price;
  final double? unitPrice;
  final String? unitPriceLabel;
  final String currency;
  final bool isOnSale;
  final DateTime observedAt;
  final String? source;
  final String? sourceUrl;

  factory SupabaseLatestPrice.fromJson(Map<String, dynamic> json) {
    return SupabaseLatestPrice(
      productId: json['product_id'] as String,
      marketId: json['market_id'] as String,
      branchId: json['branch_id'] as int?,
      price: _toDouble(json['price']) ?? 0,
      unitPrice: _toDouble(json['unit_price']),
      unitPriceLabel: json['unit_price_label'] as String?,
      currency: (json['currency'] as String?) ?? 'TRY',
      isOnSale: (json['is_on_sale'] as bool?) ?? false,
      observedAt: DateTime.parse(json['observed_at'] as String),
      source: json['source'] as String?,
      sourceUrl: json['source_url'] as String?,
    );
  }
}

double? _toDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
