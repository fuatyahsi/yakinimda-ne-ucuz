import 'package:flutter/material.dart';

import '../models/market_shopping_list.dart';
import '../utils/market_registry.dart';

/// A card that shows the total cost of the shopping list broken down by market.
///
/// Helps the user see: "A101'den alırsan X TL, BİM'den alırsan Y TL"
/// and highlights the cheapest market option.
class BudgetSummaryCard extends StatelessWidget {
  final List<MarketShoppingListEntry> entries;
  final bool isTr;

  const BudgetSummaryCard({
    super.key,
    required this.entries,
    this.isTr = true,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final summary = _computeBudgetSummary(entries);
    if (summary.isEmpty) return const SizedBox.shrink();

    final cheapest = summary.entries.reduce(
      (a, b) => a.value.totalCost < b.value.totalCost ? a : b,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                isTr ? 'B\u00FCtçe Özeti' : 'Budget Summary',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Per-market totals
          ...summary.entries.map((entry) {
            final marketId = entry.key;
            final data = entry.value;
            final isCheapest = marketId == cheapest.key;
            final displayName = displayNameForMarket(marketId);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  if (isCheapest)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isTr ? 'En Ucuz' : 'Cheapest',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      displayName.isEmpty ? marketId : displayName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isCheapest ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${data.totalCost.toStringAsFixed(2)} TL',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isCheapest
                          ? Colors.green.shade700
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${data.itemCount} \u00FCr\u00FCn)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }),

          // Savings indicator
          if (summary.length > 1) ...[
            const Divider(height: 16),
            _SavingsRow(
              theme: theme,
              isTr: isTr,
              cheapestTotal: cheapest.value.totalCost,
              mostExpensiveTotal: summary.values
                  .map((data) => data.totalCost)
                  .reduce((a, b) => a > b ? a : b),
            ),
          ],
        ],
      ),
    );
  }

  /// Computes the total cost per market using the shopping list entries.
  ///
  /// For each entry, finds the cheapest offer from each market (using
  /// alternatives) and sums them up.
  Map<String, _MarketBudgetData> _computeBudgetSummary(
    List<MarketShoppingListEntry> entries,
  ) {
    // Collect all unique market IDs across all items.
    final allMarketIds = <String>{};
    for (final entry in entries) {
      for (final item in entry.allItems) {
        final marketId = normalizeMarketId(item.marketName) ?? item.marketName;
        allMarketIds.add(marketId);
      }
    }

    final result = <String, _MarketBudgetData>{};

    for (final marketId in allMarketIds) {
      var total = 0.0;
      var count = 0;
      var hasAllItems = true;

      for (final entry in entries) {
        // Find the cheapest item from this market for this entry.
        final marketItems = entry.allItems.where((item) {
          final itemMarketId =
              normalizeMarketId(item.marketName) ?? item.marketName;
          return itemMarketId == marketId;
        }).toList()
          ..sort((a, b) => a.price.compareTo(b.price));

        if (marketItems.isNotEmpty) {
          total += marketItems.first.price;
          count++;
        } else {
          hasAllItems = false;
        }
      }

      if (count > 0) {
        result[marketId] = _MarketBudgetData(
          totalCost: total,
          itemCount: count,
          hasAllItems: hasAllItems,
        );
      }
    }

    // Sort by total cost ascending.
    final sorted = result.entries.toList()
      ..sort((a, b) => a.value.totalCost.compareTo(b.value.totalCost));
    return Map.fromEntries(sorted);
  }
}

class _MarketBudgetData {
  final double totalCost;
  final int itemCount;
  final bool hasAllItems;

  const _MarketBudgetData({
    required this.totalCost,
    required this.itemCount,
    required this.hasAllItems,
  });
}

class _SavingsRow extends StatelessWidget {
  final ThemeData theme;
  final bool isTr;
  final double cheapestTotal;
  final double mostExpensiveTotal;

  const _SavingsRow({
    required this.theme,
    required this.isTr,
    required this.cheapestTotal,
    required this.mostExpensiveTotal,
  });

  @override
  Widget build(BuildContext context) {
    final savings = mostExpensiveTotal - cheapestTotal;
    if (savings <= 0) return const SizedBox.shrink();

    final savingsPercent =
        mostExpensiveTotal > 0 ? (savings / mostExpensiveTotal * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.savings_rounded, size: 18, color: Colors.green.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isTr
                  ? 'En ucuz marketten alarak ${savings.toStringAsFixed(2)} TL (%$savingsPercent) tasarruf edebilirsin!'
                  : 'Save ${savings.toStringAsFixed(2)} TL ($savingsPercent%) by shopping at the cheapest store!',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.green.shade800,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
