import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/market_shopping_list.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/market_registry.dart';
import '../utils/text_repair.dart';

class MarketShoppingListScreen extends StatefulWidget {
  const MarketShoppingListScreen({super.key});

  @override
  State<MarketShoppingListScreen> createState() =>
      _MarketShoppingListScreenState();
}

class _MarketShoppingListScreenState extends State<MarketShoppingListScreen> {
  final Set<String> _visitMarketIds = <String>{};

  Future<void> _openListDetail(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget child,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.94,
          child: _ShoppingDetailSheet(
            title: title,
            subtitle: subtitle,
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _openVisitPlanDetail(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final provider = context.watch<AppProvider>();
            final entries = provider.shoppingListEntries;
            final marketOptions = _collectMarketOptions(entries);
            final availableMarketIds =
                marketOptions.map((option) => option.id).toSet();
            _visitMarketIds.removeWhere(
                (marketId) => !availableMarketIds.contains(marketId));
            final plan = provider.buildShoppingVisitPlan(_visitMarketIds);

            return FractionallySizedBox(
              heightFactor: 0.94,
              child: _ShoppingDetailSheet(
                title: 'Kısa Rota',
                subtitle:
                    'Sadece gideceğin marketleri seç. Listeyi bu marketlerde toplayalım.',
                child: _VisitPlanTab(
                  marketOptions: marketOptions,
                  selectedMarketIds: _visitMarketIds,
                  plan: plan,
                  onToggleMarket: (marketId) {
                    setState(() {
                      if (_visitMarketIds.contains(marketId)) {
                        _visitMarketIds.remove(marketId);
                      } else {
                        _visitMarketIds.add(marketId);
                      }
                    });
                    setSheetState(() {});
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final entries = provider.shoppingListEntries;
    final selectedMarketGroups = provider.shoppingListGroupsByMarket;
    final marketOptions = _collectMarketOptions(entries);

    final availableMarketIds = marketOptions.map((option) => option.id).toSet();
    _visitMarketIds
        .removeWhere((marketId) => !availableMarketIds.contains(marketId));

    final plan = provider.buildShoppingVisitPlan(_visitMarketIds);
    final directTotal = entries.fold<double>(
      0,
      (sum, entry) => sum + entry.selectedItem.price,
    );

    return Scaffold(
      backgroundColor: AppTheme.shellBackground,
      appBar: AppBar(
        title: const Text('Al\u0131\u015fveri\u015f Listem'),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              tooltip: 'Listeyi temizle',
              onPressed: () async {
                await provider.clearShoppingList();
              },
              icon: const Icon(Icons.delete_sweep_rounded),
            ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF10213F).withValues(alpha: 0.06),
              AppTheme.coral.withValues(alpha: 0.06),
              AppTheme.shellBackground,
            ],
            stops: const [0.0, 0.22, 0.82],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            _ShoppingHeroCard(
              entriesCount: entries.length,
              marketCount: selectedMarketGroups.length,
              directTotal: directTotal,
              plannedTotal: plan.totalPrice,
              plannedMarketCount: _visitMarketIds.length,
            ),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              const _EmptyShoppingListState()
            else ...[
              _ShoppingModeCard(
                icon: Icons.checklist_rounded,
                title: 'Se\u00E7tiklerim',
                subtitle:
                    'Se\u00E7ti\u011Fin \u00FCr\u00FCnleri tek listede g\u00F6r. Hangi market \u00FCr\u00FCn\u00FCn\u00FC se\u00E7tiysen burada o kal\u0131r.',
                trailingLabel: '${entries.length} \u00FCr\u00FCn',
                onTap: () => _openListDetail(
                  context,
                  title: 'Se\u00E7tiklerim',
                  subtitle:
                      'Hangi market \u00FCr\u00FCn\u00FCn\u00FC se\u00E7tiysen burada ayn\u0131s\u0131 durur.',
                  child: _GeneralListTab(entries: entries),
                ),
              ),
              const SizedBox(height: 12),
              _ShoppingModeCard(
                icon: Icons.storefront_rounded,
                title: 'Markete G\u00F6re',
                subtitle:
                    'Ayn\u0131 listeyi market market ay\u0131r. Hangi markette ne alaca\u011F\u0131n bir bak\u0131\u015Fta g\u00F6r.',
                trailingLabel: '${selectedMarketGroups.length} market',
                onTap: () => _openListDetail(
                  context,
                  title: 'Markete G\u00F6re',
                  subtitle:
                      'Se\u00E7tiklerini market ba\u015Fl\u0131klar\u0131 alt\u0131nda toplad\u0131k.',
                  child: _MarketGroupsTab(
                    groups: selectedMarketGroups,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _ShoppingModeCard(
                icon: Icons.route_rounded,
                title: 'K\u0131sa Rota',
                subtitle:
                    'Sadece gidece\u011Fin marketleri i\u015Faretle. Di\u011Fer marketlerde kalan se\u00E7imleri sana burada toparlayal\u0131m.',
                trailingLabel: _visitMarketIds.isEmpty
                    ? 'Market se\u00E7'
                    : '${_visitMarketIds.length} market',
                onTap: () => _openVisitPlanDetail(context),
              ),
              const SizedBox(height: 14),
              _ShoppingSelectionsPreview(
                entries: entries,
                onOpenAll: () => _openListDetail(
                  context,
                  title: 'Se\u00E7tiklerim',
                  subtitle:
                      'Hangi market \u00FCr\u00FCn\u00FCn\u00FC se\u00E7tiysen burada ayn\u0131s\u0131 durur.',
                  child: _GeneralListTab(entries: entries),
                ),
                onRemoveEntry: provider.removeShoppingListEntry,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<_MarketOption> _collectMarketOptions(
    List<MarketShoppingListEntry> entries,
  ) {
    final labels = <String, String>{};
    for (final entry in entries) {
      for (final item in entry.allItems) {
        final marketId =
            normalizeMarketId(item.marketName) ?? item.marketName.toLowerCase();
        labels[marketId] = _marketLabel(item.marketName);
      }
    }
    final options = labels.entries
        .map((entry) => _MarketOption(id: entry.key, label: entry.value))
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return options;
  }
}

class _ShoppingHeroCard extends StatelessWidget {
  final int entriesCount;
  final int marketCount;
  final double directTotal;
  final double plannedTotal;
  final int plannedMarketCount;

  const _ShoppingHeroCard({
    required this.entriesCount,
    required this.marketCount,
    required this.directTotal,
    required this.plannedTotal,
    required this.plannedMarketCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPlan = plannedMarketCount > 0 && entriesCount > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF13294B),
            Color(0xFF1D3D6F),
            Color(0xFF2B4E8B),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Al\u0131\u015Fveri\u015F ak\u0131\u015F\u0131n',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Se\u00E7tiklerini ve market rotan\u0131 tek yerde y\u00F6net',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        height: 1.02,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasPlan
                          ? 'Se\u00E7ti\u011Fin $plannedMarketCount markete g\u00F6re k\u0131sa al\u0131\u015Fveri\u015F rotan haz\u0131r. \u0130stersen ayn\u0131 listeyi market market de g\u00F6rebilirsin.'
                          : '\u00D6nce \u00FCr\u00FCnlerini ekle. Sonra ayn\u0131 se\u00E7imleri tek listede, market bazl\u0131 ya da daha k\u0131sa bir rota halinde g\u00F6r\u00FCnt\u00FCle.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Icon(
                      Icons.shopping_bag_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HeroStatChip(
                  icon: Icons.checklist_rounded,
                  label: '$entriesCount \u00FCr\u00FCn',
                ),
                _HeroStatChip(
                  icon: Icons.storefront_rounded,
                  label: '$marketCount market',
                ),
                _HeroStatChip(
                  icon: Icons.receipt_long_rounded,
                  label: 'Liste: ${_price(directTotal)} TL',
                ),
                if (hasPlan)
                  _HeroStatChip(
                    icon: Icons.route_rounded,
                    label: 'K\u0131sa Rota: ${_price(plannedTotal)} TL',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroStatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontSize: 12,
                ),
          ),
        ],
      ),
    );
  }
}

class _ShoppingModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailingLabel;
  final VoidCallback onTap;

  const _ShoppingModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailingLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.08),
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppTheme.heroGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.warmSurface,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            trailingLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppTheme.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.inkSoft,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'A\u00E7',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppTheme.primary,
                          size: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShoppingDetailSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ShoppingDetailSheet({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.shellBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _EmptyShoppingListState extends StatelessWidget {
  const _EmptyShoppingListState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppTheme.panelGradient,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  gradient: AppTheme.heroGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.playlist_add_check_circle_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Hen\u00fcz liste bo\u015f',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Kar\u015F\u0131la\u015Ft\u0131rma ekran\u0131nda hangi market \u00FCr\u00FCn\u00FCn\u00FC se\u00E7ersen burada o kaydedilir. En ucuz olan\u0131 se\u00E7mek zorunda de\u011Filsin.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  'Seçtiklerim ekranında hangi market ürününü seçtiğini görürsün. Kısa Rota ekranında ise yalnızca gideceğin marketlere göre daha kısa bir alışveriş özeti çıkarırız.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShoppingSelectionsPreview extends StatelessWidget {
  final List<MarketShoppingListEntry> entries;
  final VoidCallback onOpenAll;
  final ValueChanged<String> onRemoveEntry;

  const _ShoppingSelectionsPreview({
    required this.entries,
    required this.onOpenAll,
    required this.onRemoveEntry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewEntries = entries.take(4).toList();

    return _SectionCard(
      title: 'Se\u00E7ti\u011Fin \u00DCr\u00FCnler',
      subtitle:
          'Bu ekranda hangi \u00FCr\u00FCnleri se\u00E7ti\u011Fini h\u0131zl\u0131ca g\u00F6r. \u0130stersen tek dokunu\u015Fla tam listeyi a\u00E7.',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.warmSurface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '${entries.length} \u00FCr\u00FCn',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      child: Column(
        children: [
          ...previewEntries.map((entry) {
            final item = entry.selectedItem;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  color: AppTheme.warmSurface,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: AppTheme.heroGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.shopping_basket_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _catalogTitle(item.productTitle, item.weight),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _marketLabel(item.marketName),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.inkSoft,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_price(item.price)} TL',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Listeden kald\u0131r',
                          onPressed: () => onRemoveEntry(entry.id),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          if (entries.length > previewEntries.length)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '+${entries.length - previewEntries.length} \u00FCr\u00FCn daha var',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.inkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpenAll,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Se\u00E7tiklerim ekran\u0131n\u0131 a\u00E7'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneralListTab extends StatelessWidget {
  final List<MarketShoppingListEntry> entries;

  const _GeneralListTab({required this.entries});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: entries.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return const _SectionCard(
            title: 'Bu listede ne var?',
            subtitle:
                'Kar\u015F\u0131la\u015Ft\u0131rmada hangi market \u00FCr\u00FCn\u00FCn\u00FC se\u00E7tiysen burada o kal\u0131r. En ucuzu se\u00E7mek zorunda de\u011Filsin; liste tamamen senin karar\u0131n\u0131 tutar.',
            child: SizedBox.shrink(),
          );
        }

        final entry = entries[index - 1];
        final selectedItem = entry.selectedItem;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.08),
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: AppTheme.heroGradient,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.shopping_basket_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _catalogTitle(
                            selectedItem.productTitle,
                            selectedItem.weight,
                          ),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    height: 1.2,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Se\u00E7ilen market: ${_marketLabel(selectedItem.marketName)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Listeden kald\u0131r',
                    onPressed: () => provider.removeShoppingListEntry(entry.id),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoPill(
                    icon: Icons.sell_rounded,
                    label: '${_price(selectedItem.price)} TL',
                    accent: true,
                  ),
                  _InfoPill(
                    icon: Icons.compare_arrows_rounded,
                    label: '${entry.alternativeItems.length} alternatif market',
                  ),
                  _InfoPill(
                    icon: Icons.store_mall_directory_rounded,
                    label: _marketLabel(selectedItem.marketName),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MarketGroupsTab extends StatelessWidget {
  final List<MarketShoppingListGroup> groups;

  const _MarketGroupsTab({required this.groups});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final group = groups[index];
        return _SectionCard(
          title: group.marketName,
          trailing: _PriceBadge(total: group.totalPrice),
          child: Column(
            children: group.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _catalogTitle(
                          entry.selectedItem.productTitle,
                          entry.selectedItem.weight,
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${_price(entry.selectedItem.price)} TL',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _VisitPlanTab extends StatelessWidget {
  final List<_MarketOption> marketOptions;
  final Set<String> selectedMarketIds;
  final MarketShoppingVisitPlan plan;
  final ValueChanged<String> onToggleMarket;

  const _VisitPlanTab({
    required this.marketOptions,
    required this.selectedMarketIds,
    required this.plan,
    required this.onToggleMarket,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        _SectionCard(
          title: 'Gidece\u011Fin marketleri se\u00E7',
          subtitle:
              'Hangi marketlere gidece\u011Fini i\u015Faretle. Listeyi yaln\u0131zca bu marketlerde toplayal\u0131m.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: marketOptions.map((option) {
                  return FilterChip(
                    selected: selectedMarketIds.contains(option.id),
                    label: Text(option.label),
                    onSelected: (_) => onToggleMarket(option.id),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoPill(
                    icon: Icons.check_circle_rounded,
                    label:
                        '${plan.assignedItemCount} \u00FCr\u00FCn yerle\u015Fti',
                    accent: true,
                  ),
                  _InfoPill(
                    icon: Icons.swap_horiz_rounded,
                    label:
                        '${plan.redirectedAssignments.length} \u00FCr\u00FCn ba\u015Fka markete kayd\u0131',
                  ),
                  _InfoPill(
                    icon: Icons.payments_rounded,
                    label: 'Toplam ${_price(plan.totalPrice)} TL',
                  ),
                ],
              ),
            ],
          ),
        ),
        if (plan.groups.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: _SectionCard(
              title: 'Rota hen\u00FCz haz\u0131r de\u011Fil',
              subtitle:
                  '\u00D6nce gidece\u011Fin marketleri i\u015Faretle. Toparlanm\u0131\u015F liste burada olu\u015Facak.',
              child: SizedBox.shrink(),
            ),
          ),
        ...plan.groups.map(
          (group) => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _SectionCard(
              title: group.marketName,
              trailing: _PriceBadge(total: group.totalPrice),
              child: Column(
                children: group.assignments.map((assignment) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                _catalogTitle(
                                  assignment.assignedItem.productTitle,
                                  assignment.assignedItem.weight,
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${_price(assignment.assignedItem.price)} TL',
                              style: theme.textTheme.labelLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (assignment.usesSubstitute)
                          Text(
                            '\u0130lk se\u00E7imin ${_marketLabel(assignment.originalItem.marketName)} i\u00E7indi. Daha k\u0131sa rota i\u00E7in ${_marketLabel(assignment.assignedItem.marketName)} kar\u015F\u0131l\u0131\u011F\u0131 yerle\u015Ftirildi.',
                            style: theme.textTheme.bodySmall,
                          )
                        else
                          Text(
                            '\u00DCr\u00FCn se\u00E7ti\u011Fin marketlerden birinde do\u011Frudan bulundu.',
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        if (plan.redirectedAssignments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _SectionCard(
              title: 'Yerine al\u0131nabilecek se\u00E7enekler',
              subtitle:
                  'Gitmeyece\u011Fin markette kalan \u00FCr\u00FCnler i\u00E7in, gidece\u011Fin marketlerdeki en yak\u0131n kar\u015F\u0131l\u0131klar\u0131 g\u00F6steriyoruz.',
              child: Column(
                children: plan.redirectedAssignments.map((assignment) {
                  final delta = assignment.priceDelta;
                  final deltaLabel = delta == 0
                      ? 'ayn\u0131 fiyat'
                      : delta > 0
                          ? '+${_price(delta)} TL'
                          : '${_price(delta)} TL';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceTint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.compare_arrows_rounded,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _catalogTitle(
                                  assignment.originalItem.productTitle,
                                  assignment.originalItem.weight,
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_marketLabel(assignment.originalItem.marketName)} yerine ${_marketLabel(assignment.assignedItem.marketName)}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          deltaLabel,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: delta > 0
                                ? const Color(0xFFB54A5E)
                                : AppTheme.ink,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        if (plan.unresolvedEntries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _SectionCard(
              title: 'Se\u00E7ti\u011Fin marketlerde bulunamayanlar',
              subtitle:
                  'Bu \u00FCr\u00FCnler i\u00E7in se\u00E7ti\u011Fin marketlerde g\u00FCvenilir bir kar\u015F\u0131l\u0131k bulunamad\u0131.',
              child: Column(
                children: plan.unresolvedEntries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppTheme.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_catalogTitle(entry.selectedItem.productTitle, entry.selectedItem.weight)} - ${_marketLabel(entry.selectedItem.marketName)}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.08),
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  gradient: AppTheme.heroGradient,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(subtitle!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
          if (child is! SizedBox) const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool accent;

  const _InfoPill({
    required this.icon,
    required this.label,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: accent ? AppTheme.heroGradient : null,
        color: accent ? null : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent
              ? Colors.white.withValues(alpha: 0.12)
              : AppTheme.primary.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: accent ? Colors.white : AppTheme.inkSoft,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: accent ? Colors.white : AppTheme.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _PriceBadge extends StatelessWidget {
  final double total;

  const _PriceBadge({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.softShadow,
      ),
      child: Text(
        '${_price(total)} TL',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
            ),
      ),
    );
  }
}

class _MarketOption {
  final String id;
  final String label;

  const _MarketOption({required this.id, required this.label});
}

String _marketLabel(String marketName) {
  final displayName = displayNameForMarket(marketName);
  if (displayName.trim().isNotEmpty) {
    return displayName;
  }
  return repairTurkishText(marketName).trim();
}

String _catalogTitle(String productTitle, String? weight) {
  final cleanTitle = repairTurkishText(productTitle).trim();
  final cleanWeight = repairTurkishText(weight ?? '').trim();
  if (cleanWeight.isEmpty) {
    return cleanTitle;
  }
  final normalizedTitle = _normalize(cleanTitle);
  final normalizedWeight = _normalize(cleanWeight);
  if (normalizedTitle.contains(normalizedWeight)) {
    return cleanTitle;
  }
  return '$cleanTitle $cleanWeight';
}

String _normalize(String value) {
  const turkishMap = {
    '\u00e7': 'c',
    '\u011f': 'g',
    '\u0131': 'i',
    '\u00f6': 'o',
    '\u015f': 's',
    '\u00fc': 'u',
  };

  final buffer = StringBuffer();
  for (final codePoint in value.toLowerCase().runes) {
    final char = String.fromCharCode(codePoint);
    buffer.write(turkishMap[char] ?? char);
  }

  return buffer.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

String _price(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2).replaceAll('.', ',');
}
