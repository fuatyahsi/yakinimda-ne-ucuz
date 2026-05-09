import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/price_history.dart';
import '../models/smart_actueller.dart';
import '../providers/app_provider.dart';
import '../services/price_history_service.dart';
import '../utils/app_theme.dart';
import '../utils/catalog_product_family.dart';
import '../utils/market_registry.dart';
import '../utils/text_repair.dart';
import 'price_history_chart.dart';
import 'product_icon.dart';

const _kMarketEmoji = <String, String>{
  'a101': '🟡',
  'bim': '🔴',
  'sok': '🟠',
  'migros': '🟢',
  'carrefoursa': '🔵',
  'hakmar': '🟤',
  'metro': '🟣',
  'kooperatif': '🌾',
  'file': '🟩',
};

/// Ürün karşılaştırma + fiyat geçmişi bottom sheet.
///
/// [SmartActuellerScreen] içindeki `_openComparisonForItem` yerine kullan:
///
/// ```dart
/// await showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (_) => MarketComparisonSheet(
///     item: selectedItem,
///     alternatives: alternatives,
///   ),
/// );
/// ```
class MarketComparisonSheet extends StatefulWidget {
  /// Ana ürün (seçilen veya tıklanan katalog kalemi)
  final ActuellerCatalogItem item;

  /// Diğer marketlerdeki alternatifler
  /// (`_resolveShoppingListAlternatives` sonucu)
  final List<ActuellerCatalogItem> alternatives;

  const MarketComparisonSheet({
    super.key,
    required this.item,
    required this.alternatives,
  });

  @override
  State<MarketComparisonSheet> createState() => _MarketComparisonSheetState();
}

class _MarketComparisonSheetState extends State<MarketComparisonSheet> {
  late String _selectedItemId;
  bool _showHistory = false;
  bool _loadingHistory = false;
  ProductPriceHistory? _history;

  @override
  void initState() {
    super.initState();
    _selectedItemId = widget.item.id;
  }

  List<ActuellerCatalogItem> get _all => [widget.item, ...widget.alternatives]
    ..sort((a, b) => a.price.compareTo(b.price));

  ActuellerCatalogItem get _cheapest => _all.first;

  Future<void> _toggleHistory() async {
    if (_showHistory) {
      setState(() => _showHistory = false);
      return;
    }

    setState(() {
      _showHistory = true;
      _loadingHistory = true;
    });

    try {
      final provider = context.read<AppProvider>();
      final histories = provider.priceHistories;
      final productId = widget.item.sourceProductId;
      _history = productId != null
          ? PriceHistoryService().getHistory(histories, productId)
          : null;
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _addToList(AppProvider provider) async {
    final selected = _all.firstWhere(
      (i) => i.id == _selectedItemId,
      orElse: () => widget.item,
    );

    try {
      final isNew = await provider.addShoppingListEntry(
        selected,
        alternatives: _all.where((i) => i != selected).toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1200),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            content: Text(
              isNew ? '✓ Listene eklendi' : '✓ Listede güncellendi',
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final all = _all;

    final familyKeys = catalogShoppingIdentityKeys(widget.item);
    final inList = provider.shoppingListEntries.any(
      (entry) => familyKeys.contains(entry.identityKey),
    );

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.shellBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 4),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Hero ──────────────────────────────────────
                    _HeroCard(
                      item: widget.item,
                      cheapest: _cheapest,
                      count: all.length,
                    ),
                    const SizedBox(height: 18),

                    Text(
                      'Market Karşılaştırma',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 12),

                    // ── Fiyat satırları ───────────────────────────
                    ...all.asMap().entries.map((entry) {
                      final i = entry.key;
                      final itm = entry.value;
                      final mid = normalizeMarketId(itm.marketName) ??
                          itm.marketName.toLowerCase();
                      final diff = itm.price - _cheapest.price;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PriceRow(
                          item: itm,
                          marketId: mid,
                          isCheapest: i == 0,
                          isSelected: itm.id == _selectedItemId,
                          priceDiff: i == 0 ? null : diff,
                          onTap: () => setState(() => _selectedItemId = itm.id),
                        ),
                      );
                    }),

                    const SizedBox(height: 4),

                    // ── Fiyat geçmişi toggle ──────────────────────
                    _HistoryToggle(
                      isOpen: _showHistory,
                      onToggle: _toggleHistory,
                    ),

                    if (_showHistory) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: _loadingHistory
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : _history == null
                                ? _NoHistoryState()
                                : PriceHistoryPanel(
                                    history: _history!,
                                    availableMarketIds: all
                                        .map((i) =>
                                            normalizeMarketId(i.marketName) ??
                                            i.marketName.toLowerCase())
                                        .toSet()
                                        .toList(),
                                  ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // ── Listeye ekle butonu ───────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: inList
                          ? OutlinedButton.icon(
                              onPressed: () => _addToList(provider),
                              icon: const Icon(
                                  Icons.check_circle_outline_rounded),
                              label: const Text('Listede — Güncelle'),
                            )
                          : FilledButton.icon(
                              onPressed: () => _addToList(provider),
                              icon: const Icon(Icons.add_shopping_cart_rounded),
                              label: const Text('Alışveriş Listesine Ekle'),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Yardımcı widget'lar
// ─────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final ActuellerCatalogItem item;
  final ActuellerCatalogItem cheapest;
  final int count;

  const _HeroCard({
    required this.item,
    required this.cheapest,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final familyTitle = catalogProductFamilyTitle(item);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ürün ikonu
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(
              ProductIconResolver.resolve(
                familyTitle,
                categoryId: item.sourceMenuCategory,
                category: item.category,
              ).emoji,
              style: const TextStyle(fontSize: 34),
            ),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.weight != null && item.weight!.isNotEmpty)
                  Text(
                    item.weight!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  repairTurkishText(familyTitle),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _HeroPill(
                        label:
                            'En ucuz: ${cheapest.price.toStringAsFixed(2)} TL'),
                    _HeroPill(label: '$count se\u00E7enek'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String label;
  const _HeroPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final ActuellerCatalogItem item;
  final String marketId;
  final bool isCheapest;
  final bool isSelected;
  final double? priceDiff;
  final VoidCallback onTap;

  const _PriceRow({
    required this.item,
    required this.marketId,
    required this.isCheapest,
    required this.isSelected,
    required this.priceDiff,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variantLabel = catalogVariantLabel(item);
    final emoji = _kMarketEmoji[marketId] ?? '🏪';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.07)
              : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : AppTheme.primary.withValues(alpha: 0.1),
            width: isSelected ? 1.8 : 1.5,
          ),
        ),
        child: Row(
          children: [
            // Market emoji ikonu
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: isCheapest ? AppTheme.heroGradient : null,
                color:
                    isCheapest ? null : AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.marketName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (variantLabel.isNotEmpty) ...[
                    Text(
                      variantLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.inkSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    isCheapest
                        ? '✓ En ucuz seçenek'
                        : '+${priceDiff!.toStringAsFixed(2)} TL daha pahalı',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isCheapest ? AppTheme.primary : AppTheme.inkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            // Fiyat
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.price.toStringAsFixed(2)} TL',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isCheapest ? AppTheme.primary : AppTheme.ink,
                  ),
                ),
                if (isSelected)
                  Text(
                    '● Seçili',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryToggle extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onToggle;

  const _HistoryToggle({required this.isOpen, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          children: [
            const Text('📈', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Text(
              'Fiyat Geçmişi',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const Spacer(),
            Text(
              isOpen ? 'Kapat ↑' : 'Göster ↓',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoHistoryState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const Icon(Icons.bar_chart_rounded,
              size: 42, color: AppTheme.inkSoft),
          const SizedBox(height: 10),
          Text(
            'Bu ürün için henüz fiyat geçmişi yok.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.inkSoft,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Bir sonraki katalog taramasından sonra burada görünecek.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
