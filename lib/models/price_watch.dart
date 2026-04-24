/// A user-set price watch on a product.
///
/// When the product's price drops below [targetPrice] or drops by any amount
/// relative to [originalPrice], the app should notify the user.
class PriceWatch {
  final String id;
  final String productId;
  final String productTitle;
  final String? marketId;
  final double originalPrice;
  final double? targetPrice;
  final DateTime createdAt;
  final bool isTriggered;
  final DateTime? triggeredAt;

  const PriceWatch({
    required this.id,
    required this.productId,
    required this.productTitle,
    this.marketId,
    required this.originalPrice,
    this.targetPrice,
    required this.createdAt,
    this.isTriggered = false,
    this.triggeredAt,
  });

  /// Whether the given price satisfies the watch condition.
  bool isSatisfiedBy(double currentPrice) {
    if (targetPrice != null) {
      return currentPrice <= targetPrice!;
    }
    return currentPrice < originalPrice;
  }

  PriceWatch copyWith({
    bool? isTriggered,
    DateTime? triggeredAt,
  }) {
    return PriceWatch(
      id: id,
      productId: productId,
      productTitle: productTitle,
      marketId: marketId,
      originalPrice: originalPrice,
      targetPrice: targetPrice,
      createdAt: createdAt,
      isTriggered: isTriggered ?? this.isTriggered,
      triggeredAt: triggeredAt ?? this.triggeredAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'productTitle': productTitle,
        'marketId': marketId,
        'originalPrice': originalPrice,
        'targetPrice': targetPrice,
        'createdAt': createdAt.toIso8601String(),
        'isTriggered': isTriggered,
        'triggeredAt': triggeredAt?.toIso8601String(),
      };

  factory PriceWatch.fromJson(Map<String, dynamic> json) {
    return PriceWatch(
      id: json['id']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      productTitle: json['productTitle']?.toString() ?? '',
      marketId: json['marketId']?.toString(),
      originalPrice: (json['originalPrice'] as num?)?.toDouble() ?? 0,
      targetPrice: (json['targetPrice'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      isTriggered: json['isTriggered'] as bool? ?? false,
      triggeredAt:
          DateTime.tryParse(json['triggeredAt']?.toString() ?? ''),
    );
  }
}

/// Result of evaluating all watches against the current catalog.
class PriceWatchCheckResult {
  final List<PriceWatch> triggeredWatches;
  final List<PriceWatch> allWatches;

  const PriceWatchCheckResult({
    required this.triggeredWatches,
    required this.allWatches,
  });

  bool get hasNewTriggers =>
      triggeredWatches.any((watch) => !watch.isTriggered);
}
