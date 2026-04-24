/// A single price snapshot for a product at a specific market depot.
class PriceSnapshot {
  final double price;
  final DateTime recordedAt;
  final bool isDiscount;

  const PriceSnapshot({
    required this.price,
    required this.recordedAt,
    this.isDiscount = false,
  });

  Map<String, dynamic> toJson() => {
        'price': price,
        'recordedAt': recordedAt.toIso8601String(),
        'isDiscount': isDiscount,
      };

  factory PriceSnapshot.fromJson(Map<String, dynamic> json) {
    return PriceSnapshot(
      price: (json['price'] as num?)?.toDouble() ?? 0,
      recordedAt: DateTime.tryParse(json['recordedAt']?.toString() ?? '') ??
          DateTime.now(),
      isDiscount: json['isDiscount'] as bool? ?? false,
    );
  }
}

/// The price trend direction for a product.
enum PriceTrend { rising, falling, stable, unknown }

/// Price history for a single product across one or more markets.
class ProductPriceHistory {
  /// Unique product identity (typically the Market Fiyati product ID).
  final String productId;

  /// Human-readable product title for display purposes.
  final String productTitle;

  /// Map of marketId -> list of price snapshots, ordered oldest-first.
  final Map<String, List<PriceSnapshot>> snapshotsByMarket;

  const ProductPriceHistory({
    required this.productId,
    required this.productTitle,
    this.snapshotsByMarket = const {},
  });

  /// Returns all snapshots across all markets, sorted oldest-first.
  List<PriceSnapshot> get allSnapshots {
    final all = <PriceSnapshot>[];
    for (final snapshots in snapshotsByMarket.values) {
      all.addAll(snapshots);
    }
    all.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return all;
  }

  /// Returns the overall minimum price ever recorded.
  double? get historicLow {
    final snapshots = allSnapshots;
    if (snapshots.isEmpty) return null;
    return snapshots
        .map((snapshot) => snapshot.price)
        .reduce((a, b) => a < b ? a : b);
  }

  /// Returns the overall maximum price ever recorded.
  double? get historicHigh {
    final snapshots = allSnapshots;
    if (snapshots.isEmpty) return null;
    return snapshots
        .map((snapshot) => snapshot.price)
        .reduce((a, b) => a > b ? a : b);
  }

  /// Returns the most recent price across all markets.
  double? get latestPrice {
    final snapshots = allSnapshots;
    if (snapshots.isEmpty) return null;
    return snapshots.last.price;
  }

  /// Returns the price trend by comparing the latest price to the average
  /// of the previous snapshots.
  PriceTrend get trend {
    final snapshots = allSnapshots;
    if (snapshots.length < 2) return PriceTrend.unknown;

    final latest = snapshots.last.price;
    final previousPrices =
        snapshots.sublist(0, snapshots.length - 1).map((s) => s.price);
    final previousAverage =
        previousPrices.reduce((a, b) => a + b) / previousPrices.length;

    final changeRatio = (latest - previousAverage) / previousAverage;
    if (changeRatio > 0.02) return PriceTrend.rising;
    if (changeRatio < -0.02) return PriceTrend.falling;
    return PriceTrend.stable;
  }

  /// Returns a human-readable trend label in Turkish.
  String get trendLabelTr {
    switch (trend) {
      case PriceTrend.rising:
        return 'Y\u00FCkseliyor';
      case PriceTrend.falling:
        return 'D\u00FC\u015F\u00FCyor';
      case PriceTrend.stable:
        return 'Sabit';
      case PriceTrend.unknown:
        return 'Yeterli veri yok';
    }
  }

  /// Returns a percentage change string (e.g., "+12%", "-5%").
  String? get changePercentLabel {
    final snapshots = allSnapshots;
    if (snapshots.length < 2) return null;

    final latest = snapshots.last.price;
    final previousPrices =
        snapshots.sublist(0, snapshots.length - 1).map((s) => s.price);
    final previousAverage =
        previousPrices.reduce((a, b) => a + b) / previousPrices.length;
    if (previousAverage == 0) return null;

    final changePercent =
        ((latest - previousAverage) / previousAverage * 100).round();
    if (changePercent == 0) return null;
    return changePercent > 0 ? '+$changePercent%' : '$changePercent%';
  }

  /// Whether the current price is at or near the historic low (within 5%).
  bool get isNearHistoricLow {
    final low = historicLow;
    final current = latestPrice;
    if (low == null || current == null || low == 0) return false;
    return (current - low) / low <= 0.05;
  }

  /// Creates a new history with an additional snapshot appended.
  ProductPriceHistory withSnapshot({
    required String marketId,
    required PriceSnapshot snapshot,
    int maxSnapshotsPerMarket = 60,
  }) {
    final updatedMap = Map<String, List<PriceSnapshot>>.from(
      snapshotsByMarket.map(
        (key, value) => MapEntry(key, List<PriceSnapshot>.from(value)),
      ),
    );

    final marketSnapshots = updatedMap.putIfAbsent(marketId, () => []);

    // Avoid duplicate entries for the same day.
    final snapshotDate = _dateKey(snapshot.recordedAt);
    marketSnapshots.removeWhere(
      (existing) => _dateKey(existing.recordedAt) == snapshotDate,
    );
    marketSnapshots.add(snapshot);

    // Trim old entries.
    if (marketSnapshots.length > maxSnapshotsPerMarket) {
      marketSnapshots.removeRange(
        0,
        marketSnapshots.length - maxSnapshotsPerMarket,
      );
    }

    return ProductPriceHistory(
      productId: productId,
      productTitle: productTitle,
      snapshotsByMarket: updatedMap,
    );
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productTitle': productTitle,
        'snapshotsByMarket': snapshotsByMarket.map(
          (marketId, snapshots) => MapEntry(
            marketId,
            snapshots.map((snapshot) => snapshot.toJson()).toList(),
          ),
        ),
      };

  factory ProductPriceHistory.fromJson(Map<String, dynamic> json) {
    final rawMap =
        json['snapshotsByMarket'] as Map<String, dynamic>? ?? const {};
    final snapshotsByMarket = rawMap.map(
      (marketId, dynamic rawSnapshots) {
        final snapshots = (rawSnapshots as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PriceSnapshot.fromJson)
            .toList()
          ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
        return MapEntry(marketId, snapshots);
      },
    );

    return ProductPriceHistory(
      productId: json['productId']?.toString() ?? '',
      productTitle: json['productTitle']?.toString() ?? '',
      snapshotsByMarket: snapshotsByMarket,
    );
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
