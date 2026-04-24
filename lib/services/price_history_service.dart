import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/price_history.dart';
import '../models/smart_actueller.dart';
import '../utils/market_registry.dart';

/// Persists and retrieves product price history using SharedPreferences.
class PriceHistoryService {
  static const _storageKey = 'price_history_v1';
  static const int maxTrackedProducts = 500;

  /// Loads all stored price histories.
  Future<Map<String, ProductPriceHistory>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      return decoded.map(
        (key, dynamic value) => MapEntry(
          key,
          ProductPriceHistory.fromJson(value as Map<String, dynamic>),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  /// Saves all price histories.
  Future<void> saveAll(Map<String, ProductPriceHistory> histories) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(
      histories.map(
        (key, history) => MapEntry(key, history.toJson()),
      ),
    );
    await prefs.setString(_storageKey, encoded);
  }

  /// Records price snapshots from a catalog sync result into history.
  /// Returns the updated histories map.
  Future<Map<String, ProductPriceHistory>> recordFromCatalogItems({
    required List<ActuellerCatalogItem> items,
    required Map<String, ProductPriceHistory> existing,
  }) async {
    final now = DateTime.now();
    final updated = Map<String, ProductPriceHistory>.from(existing);

    for (final item in items) {
      final productId = item.sourceProductId;
      if (productId == null || productId.isEmpty) continue;
      if (item.price <= 0) continue;

      final marketId = normalizeMarketId(item.marketName) ?? item.marketName;
      final snapshot = PriceSnapshot(
        price: item.price,
        recordedAt: now,
        isDiscount: item.rawBlock.contains('indirim') ||
            item.rawBlock.contains('f\u0131rsat'),
      );

      final history = updated[productId] ??
          ProductPriceHistory(
            productId: productId,
            productTitle: item.productTitle,
          );

      updated[productId] = history.withSnapshot(
        marketId: marketId,
        snapshot: snapshot,
      );
    }

    // Trim to max size: keep the most recently updated products.
    if (updated.length > maxTrackedProducts) {
      final sorted = updated.entries.toList()
        ..sort((a, b) {
          final aLatest = a.value.allSnapshots.lastOrNull?.recordedAt;
          final bLatest = b.value.allSnapshots.lastOrNull?.recordedAt;
          if (aLatest == null && bLatest == null) return 0;
          if (aLatest == null) return 1;
          if (bLatest == null) return -1;
          return bLatest.compareTo(aLatest);
        });

      updated.clear();
      for (final entry in sorted.take(maxTrackedProducts)) {
        updated[entry.key] = entry.value;
      }
    }

    await saveAll(updated);
    return updated;
  }

  /// Returns the price history for a specific product, if available.
  ProductPriceHistory? getHistory(
    Map<String, ProductPriceHistory> histories,
    String? productId,
  ) {
    if (productId == null || productId.isEmpty) return null;
    return histories[productId];
  }

  /// Returns products whose price dropped since the last recording.
  List<ProductPriceHistory> findPriceDrops(
    Map<String, ProductPriceHistory> histories,
  ) {
    return histories.values
        .where((history) => history.trend == PriceTrend.falling)
        .toList()
      ..sort((a, b) {
        final aChange = a.changePercentLabel ?? '0';
        final bChange = b.changePercentLabel ?? '0';
        return aChange.compareTo(bChange);
      });
  }

  /// Returns products currently at or near their historic low.
  List<ProductPriceHistory> findAtHistoricLow(
    Map<String, ProductPriceHistory> histories,
  ) {
    return histories.values
        .where((history) => history.isNearHistoricLow)
        .toList();
  }
}
