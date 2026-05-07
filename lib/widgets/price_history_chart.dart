import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/price_history.dart';
import '../utils/app_theme.dart';

/// Fiyat geçmişi sparkline grafiği.
/// [ProductPriceHistory] modeliyle doğrudan çalışır — harici paket gerekmez.
///
/// Kullanım (smart_actueller_screen.dart içinde):
/// ```dart
/// final history = priceHistories[item.sourceProductId];
/// if (history != null)
///   PriceHistoryChart(history: history, marketId: selectedMarketId)
/// ```
class PriceHistoryChart extends StatelessWidget {
  final ProductPriceHistory history;

  /// Hangi market için grafik gösterilecek. null ise tüm marketlerin ortalaması.
  final String? marketId;

  /// Grafik rengi — varsayılan AppTheme.primary
  final Color? color;

  /// Grafik yüksekliği (px)
  final double chartHeight;

  const PriceHistoryChart({
    super.key,
    required this.history,
    this.marketId,
    this.color,
    this.chartHeight = 100,
  });

  List<PriceSnapshot> _snapshots() {
    final mid = marketId;
    if (mid != null) {
      return history.snapshotsByMarket[mid] ?? const [];
    }
    return history.allSnapshots;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lineColor = color ?? AppTheme.primary;
    final snapshots = _snapshots();

    if (snapshots.isEmpty) {
      return _EmptyState(color: lineColor);
    }

    final prices = snapshots.map((s) => s.price).toList();
    final first = prices.first;
    final last = prices.last;
    final isUp = last > first;
    final diff = (last - first).abs();
    final trendColor =
        isUp ? const Color(0xFFEF4444) : const Color(0xFF22C55E);
    final trendLabel =
        '${isUp ? '↑ +' : '↓ -'}${diff.toStringAsFixed(2)} TL (${snapshots.length} kayıt)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Trend başlık satırı ──────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Fiyat Geçmişi',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.inkSoft,
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: trendColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                trendLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: trendColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Grafik ──────────────────────────────────────────
        Container(
          height: chartHeight,
          decoration: BoxDecoration(
            color: lineColor.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.fromLTRB(8, 10, 32, 6),
          child: CustomPaint(
            painter: _SparklinePainter(
              prices: prices,
              isDiscount: snapshots.map((s) => s.isDiscount).toList(),
              color: lineColor,
            ),
            size: Size.infinite,
          ),
        ),
        const SizedBox(height: 6),

        // ── Zaman etiketleri ─────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _buildTimeLabels(snapshots, theme),
        ),
      ],
    );
  }

  List<Widget> _buildTimeLabels(
      List<PriceSnapshot> snapshots, ThemeData theme) {
    if (snapshots.isEmpty) return [];

    // En fazla 7 etiket göster, eşit aralıklı seç
    final n = snapshots.length;
    final indices = n <= 7
        ? List.generate(n, (i) => i)
        : List.generate(7, (i) => (i * (n - 1) ~/ 6));

    return indices.map((i) {
      final date = snapshots[i].recordedAt;
      final label = DateFormat('d MMM', 'tr').format(date);
      return Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 9,
          color: AppTheme.inkSoft,
        ),
      );
    }).toList();
  }
}

// ── Boş durum ────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final Color color;
  const _EmptyState({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        'Henüz fiyat geçmişi yok',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.inkSoft,
            ),
      ),
    );
  }
}

// ── CustomPainter ─────────────────────────────────────────
class _SparklinePainter extends CustomPainter {
  final List<double> prices;
  final List<bool> isDiscount;
  final Color color;

  const _SparklinePainter({
    required this.prices,
    required this.isDiscount,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.length < 2) {
      // Tek nokta: merkeze dot çiz
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        4,
        Paint()..color = color,
      );
      return;
    }

    final n = prices.length;
    final minVal = prices.reduce((a, b) => a < b ? a : b) * 0.97;
    final maxVal = prices.reduce((a, b) => a > b ? a : b) * 1.03;
    final range = (maxVal - minVal).clamp(0.01, double.infinity);

    Offset toOffset(int i) {
      final x = (i / (n - 1)) * size.width;
      final y =
          size.height - ((prices[i] - minVal) / range) * size.height;
      return Offset(x, y.clamp(4.0, size.height - 4.0));
    }

    final pts = List.generate(n, toOffset);

    // ── Yatay kılavuz çizgileri ──────────────────────────
    final guidePaint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (final f in [0.25, 0.5, 0.75]) {
      final y = f * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guidePaint);
    }

    // ── Alan dolgusu ─────────────────────────────────────
    final areaPath = _buildCurvePath(pts)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();

    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.01),
          ],
        ).createShader(
            Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // ── Eğri çizgi ───────────────────────────────────────
    canvas.drawPath(
      _buildCurvePath(pts),
      Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // ── Noktalar ─────────────────────────────────────────
    for (int i = 0; i < n; i++) {
      final isLast = i == n - 1;
      final isDisc = i < isDiscount.length && isDiscount[i];
      final dotColor =
          isDisc ? const Color(0xFF22C55E) : (isLast ? color : Colors.white);
      final r = isLast ? 4.5 : (isDisc ? 3.5 : 2.5);

      canvas.drawCircle(pts[i], r, Paint()..color = dotColor);
      canvas.drawCircle(
        pts[i],
        r,
        Paint()
          ..color = isDisc ? const Color(0xFF22C55E) : color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }

    // ── Son nokta fiyat etiketi ───────────────────────────
    final lastPt = pts.last;
    final priceText = '${prices.last.toStringAsFixed(2)} TL';
    final tp = TextPainter(
      text: TextSpan(
        text: priceText,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Etiket sağa sığmıyorsa sola yaz
    final labelX = lastPt.dx + 7;
    tp.paint(canvas, Offset(labelX, lastPt.dy - tp.height / 2));
  }

  Path _buildCurvePath(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final cx = (pts[i - 1].dx + pts[i].dx) / 2;
      path.cubicTo(
          cx, pts[i - 1].dy, cx, pts[i].dy, pts[i].dx, pts[i].dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.prices != prices || old.color != color;
}

/// Market seçici + grafik birleşik widget.
/// [SmartActuellerScreen] içinde ürün karşılaştırma sheet'inde kullanılır.
class PriceHistoryPanel extends StatefulWidget {
  final ProductPriceHistory history;
  final List<String> availableMarketIds;

  const PriceHistoryPanel({
    super.key,
    required this.history,
    required this.availableMarketIds,
  });

  @override
  State<PriceHistoryPanel> createState() => _PriceHistoryPanelState();
}

class _PriceHistoryPanelState extends State<PriceHistoryPanel> {
  late String? _selectedMarketId;

  @override
  void initState() {
    super.initState();
    _selectedMarketId =
        widget.availableMarketIds.isNotEmpty
            ? widget.availableMarketIds.first
            : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Market seçici
        if (widget.availableMarketIds.length > 1) ...[
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.availableMarketIds.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final mid = widget.availableMarketIds[i];
                final sel = mid == _selectedMarketId;
                return GestureDetector(
                  onTap: () => setState(() => _selectedMarketId = mid),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppTheme.primary
                          : AppTheme.surfaceTint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      mid,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: sel ? Colors.white : AppTheme.inkSoft,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],

        PriceHistoryChart(
          history: widget.history,
          marketId: _selectedMarketId,
          color: AppTheme.primary,
        ),
      ],
    );
  }
}
