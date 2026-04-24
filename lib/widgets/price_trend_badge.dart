import 'package:flutter/material.dart';

import '../models/price_history.dart';

/// A compact badge that shows the price trend for a product.
///
/// Shows an arrow icon (up/down/stable) with an optional percentage label.
/// Tapping it opens a mini price chart in a bottom sheet.
class PriceTrendBadge extends StatelessWidget {
  final ProductPriceHistory history;

  const PriceTrendBadge({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    final trend = history.trend;
    if (trend == PriceTrend.unknown) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final changeLabel = history.changePercentLabel;
    final isLow = history.isNearHistoricLow;

    final Color badgeColor;
    final IconData badgeIcon;
    switch (trend) {
      case PriceTrend.falling:
        badgeColor = Colors.green.shade700;
        badgeIcon = Icons.trending_down_rounded;
        break;
      case PriceTrend.rising:
        badgeColor = Colors.red.shade600;
        badgeIcon = Icons.trending_up_rounded;
        break;
      case PriceTrend.stable:
        badgeColor = Colors.blueGrey.shade600;
        badgeIcon = Icons.trending_flat_rounded;
        break;
      case PriceTrend.unknown:
        badgeColor = Colors.grey;
        badgeIcon = Icons.remove_rounded;
        break;
    }

    return GestureDetector(
      onTap: () => _showPriceHistory(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: badgeColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(badgeIcon, size: 14, color: badgeColor),
            if (changeLabel != null) ...[
              const SizedBox(width: 3),
              Text(
                changeLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: badgeColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ],
            if (isLow) ...[
              const SizedBox(width: 3),
              Icon(Icons.star_rounded, size: 12, color: Colors.amber.shade700),
            ],
          ],
        ),
      ),
    );
  }

  void _showPriceHistory(BuildContext context) {
    final theme = Theme.of(context);
    final snapshots = history.allSnapshots;
    final historicLow = history.historicLow;
    final historicHigh = history.historicHigh;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  history.productTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  'Fiyat Trendi: ${history.trendLabelTr}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                // Stats row
                Row(
                  children: [
                    _StatChip(
                      label: 'En D\u00FC\u015F\u00FCk',
                      value: historicLow != null
                          ? '${historicLow.toStringAsFixed(2)} TL'
                          : '-',
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 10),
                    _StatChip(
                      label: 'En Y\u00FCksek',
                      value: historicHigh != null
                          ? '${historicHigh.toStringAsFixed(2)} TL'
                          : '-',
                      color: Colors.red.shade600,
                    ),
                    const SizedBox(width: 10),
                    _StatChip(
                      label: 'Kay\u0131t',
                      value: '${snapshots.length} g\u00F6zlem',
                      color: Colors.blueGrey.shade600,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Simple bar chart of recent prices
                if (snapshots.length >= 2) ...[
                  Text(
                    'Son Fiyatlar',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 100,
                    child: _MiniPriceChart(
                      snapshots: snapshots.length > 14
                          ? snapshots.sublist(snapshots.length - 14)
                          : snapshots,
                      minPrice: historicLow ?? 0,
                      maxPrice: historicHigh ?? 1,
                    ),
                  ),
                ],

                if (history.isNearHistoricLow) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.star_rounded,
                            size: 18, color: Colors.amber.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Bu \u00FCr\u00FCn \u015Fu an tarihsel en d\u00FC\u015F\u00FCk fiyat\u0131na yak\u0131n!',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPriceChart extends StatelessWidget {
  final List<PriceSnapshot> snapshots;
  final double minPrice;
  final double maxPrice;

  const _MiniPriceChart({
    required this.snapshots,
    required this.minPrice,
    required this.maxPrice,
  });

  @override
  Widget build(BuildContext context) {
    final range = maxPrice - minPrice;
    final effectiveRange = range > 0 ? range : 1.0;

    return CustomPaint(
      size: const Size(double.infinity, 100),
      painter: _MiniChartPainter(
        snapshots: snapshots,
        minPrice: minPrice,
        effectiveRange: effectiveRange,
        barColor: Theme.of(context).colorScheme.primary,
        discountColor: Colors.green.shade600,
      ),
    );
  }
}

class _MiniChartPainter extends CustomPainter {
  final List<PriceSnapshot> snapshots;
  final double minPrice;
  final double effectiveRange;
  final Color barColor;
  final Color discountColor;

  _MiniChartPainter({
    required this.snapshots,
    required this.minPrice,
    required this.effectiveRange,
    required this.barColor,
    required this.discountColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (snapshots.isEmpty) return;

    final barWidth = (size.width - (snapshots.length - 1) * 3) / snapshots.length;
    final clampedBarWidth = barWidth.clamp(4.0, 28.0);
    final totalBarsWidth =
        clampedBarWidth * snapshots.length + 3 * (snapshots.length - 1);
    final startX = (size.width - totalBarsWidth) / 2;

    for (var i = 0; i < snapshots.length; i++) {
      final snapshot = snapshots[i];
      final normalizedHeight =
          ((snapshot.price - minPrice) / effectiveRange).clamp(0.08, 1.0);
      final barHeight = normalizedHeight * (size.height - 16);
      final x = startX + i * (clampedBarWidth + 3);
      final y = size.height - barHeight - 8;

      final paint = Paint()
        ..color = snapshot.isDiscount ? discountColor : barColor
        ..style = PaintingStyle.fill;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, clampedBarWidth, barHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniChartPainter oldDelegate) {
    return snapshots != oldDelegate.snapshots;
  }
}
