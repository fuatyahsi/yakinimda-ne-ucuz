import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/price_watch.dart';
import '../models/smart_actueller.dart';

/// Manages price watch persistence and evaluation.
class PriceWatchService {
  static const _storageKey = 'price_watches_v1';
  static const int maxWatches = 50;

  /// Load all saved watches.
  Future<List<PriceWatch>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PriceWatch.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Save all watches.
  Future<void> saveAll(List<PriceWatch> watches) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(watches.map((w) => w.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  /// Add a new watch. Returns updated list.
  Future<List<PriceWatch>> addWatch({
    required List<PriceWatch> existing,
    required String productId,
    required String productTitle,
    required double currentPrice,
    double? targetPrice,
    String? marketId,
  }) async {
    // Don't add duplicate for same product.
    final alreadyExists =
        existing.any((watch) => watch.productId == productId);
    if (alreadyExists) return existing;

    final watch = PriceWatch(
      id: '${DateTime.now().microsecondsSinceEpoch}-$productId',
      productId: productId,
      productTitle: productTitle,
      marketId: marketId,
      originalPrice: currentPrice,
      targetPrice: targetPrice,
      createdAt: DateTime.now(),
    );

    final updated = [watch, ...existing];
    if (updated.length > maxWatches) {
      updated.removeRange(maxWatches, updated.length);
    }

    await saveAll(updated);
    return updated;
  }

  /// Remove a watch by ID. Returns updated list.
  Future<List<PriceWatch>> removeWatch({
    required List<PriceWatch> existing,
    required String watchId,
  }) async {
    final updated = existing.where((w) => w.id != watchId).toList();
    await saveAll(updated);
    return updated;
  }

  /// Check all watches against the current catalog items.
  /// Returns the check result and the updated watches list (with triggers set).
  Future<PriceWatchCheckResult> checkWatches({
    required List<PriceWatch> watches,
    required List<ActuellerCatalogItem> catalogItems,
  }) async {
    // Build a quick lookup: productId -> lowest price.
    final lowestPriceByProduct = <String, double>{};
    for (final item in catalogItems) {
      final productId = item.sourceProductId;
      if (productId == null || productId.isEmpty) continue;
      if (item.price <= 0) continue;

      final existing = lowestPriceByProduct[productId];
      if (existing == null || item.price < existing) {
        lowestPriceByProduct[productId] = item.price;
      }
    }

    final triggeredWatches = <PriceWatch>[];
    final updatedWatches = <PriceWatch>[];

    for (final watch in watches) {
      final currentPrice = lowestPriceByProduct[watch.productId];
      if (currentPrice != null && watch.isSatisfiedBy(currentPrice)) {
        final triggered = watch.copyWith(
          isTriggered: true,
          triggeredAt: DateTime.now(),
        );
        triggeredWatches.add(triggered);
        updatedWatches.add(triggered);
      } else {
        updatedWatches.add(watch);
      }
    }

    if (triggeredWatches.isNotEmpty) {
      await saveAll(updatedWatches);
    }

    return PriceWatchCheckResult(
      triggeredWatches: triggeredWatches,
      allWatches: updatedWatches,
    );
  }

  /// Whether a product is already being watched.
  bool isWatched(List<PriceWatch> watches, String? productId) {
    if (productId == null || productId.isEmpty) return false;
    return watches.any((watch) => watch.productId == productId);
  }
}
