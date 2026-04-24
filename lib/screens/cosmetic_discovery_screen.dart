import 'package:flutter/material.dart';

import '../features/cosmetics/models/cosmetic_source_definition.dart';
import '../features/cosmetics/services/cosmetic_source_service.dart';
import '../utils/app_theme.dart';
import '../utils/text_repair.dart';

class CosmeticDiscoveryScreen extends StatefulWidget {
  const CosmeticDiscoveryScreen({super.key});

  @override
  State<CosmeticDiscoveryScreen> createState() =>
      _CosmeticDiscoveryScreenState();
}

class _CosmeticDiscoveryScreenState extends State<CosmeticDiscoveryScreen> {
  final CosmeticSourceService _service = CosmeticSourceService();
  final List<CosmeticCategorySnapshot> _history = [];

  late final List<CosmeticSourceDefinition> _sources;
  bool _didBootstrap = false;
  bool _isLoading = false;
  String _searchQuery = '';
  String? _errorMessage;

  CosmeticCategorySnapshot? get _currentSnapshot =>
      _history.isEmpty ? null : _history.last;

  CosmeticSourceDefinition? get _primarySource =>
      _sources.isEmpty ? null : _sources.first;

  String? get _rootUrl {
    final source = _primarySource;
    if (source == null || source.seedUrls.isEmpty) {
      return null;
    }
    return source.seedUrls.first;
  }

  @override
  void initState() {
    super.initState();
    _sources = _service.availableSources;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    if (_didBootstrap) {
      return;
    }
    _didBootstrap = true;
    final rootUrl = _rootUrl;
    if (rootUrl == null) {
      return;
    }
    await _openSnapshot(rootUrl);
  }

  Future<void> _openSnapshot(
    String url, {
    bool replaceCurrent = false,
  }) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await _service.fetchCategorySnapshot(url);
      if (!mounted) {
        return;
      }

      setState(() {
        _searchQuery = '';
        if (replaceCurrent && _history.isNotEmpty) {
          _history[_history.length - 1] = snapshot;
        } else {
          _history.add(snapshot);
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = repairTurkishText(
          error.toString().replaceFirst('Exception: ', ''),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _goBack() {
    if (_history.length <= 1) {
      return;
    }
    setState(() {
      _history.removeLast();
      _searchQuery = '';
      _errorMessage = null;
    });
  }

  void _goToRoot() {
    if (_history.isEmpty) {
      return;
    }
    setState(() {
      final first = _history.first;
      _history
        ..clear()
        ..add(first);
      _searchQuery = '';
      _errorMessage = null;
    });
  }

  String _normalizeSearchValue(String value) {
    return repairTurkishText(value)
        .toLowerCase()
        .replaceAll('\u00E7', 'c')
        .replaceAll('\u011F', 'g')
        .replaceAll('\u0131', 'i')
        .replaceAll('\u00F6', 'o')
        .replaceAll('\u015F', 's')
        .replaceAll('\u00FC', 'u')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  bool _matchesQuery(String value) {
    final normalizedQuery = _normalizeSearchValue(_searchQuery);
    if (normalizedQuery.isEmpty) {
      return true;
    }
    return _normalizeSearchValue(value).contains(normalizedQuery);
  }

  String _formatSourceName(String value) {
    return value
        .replaceAll('Akakce', 'Akak\u00E7e')
        .replaceAll('Kisisel', 'Ki\u015Fisel')
        .replaceAll('Bakim', 'Bak\u0131m');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshot = _currentSnapshot;
    final canGoBack = _history.length > 1;
    final canGoRoot = _history.length > 1;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: canGoBack
            ? IconButton(
                onPressed: _isLoading ? null : _goBack,
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        title: Text(
          snapshot == null
              ? 'Kozmetikte En Ucuz'
              : repairTurkishText(snapshot.title),
        ),
        actions: [
          if (canGoRoot)
            IconButton(
              onPressed: _isLoading ? null : _goToRoot,
              icon: const Icon(Icons.home_rounded),
            ),
          if (snapshot != null)
            IconButton(
              onPressed: _isLoading
                  ? null
                  : () => _openSnapshot(
                        snapshot.requestUrl,
                        replaceCurrent: true,
                      ),
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFDEDE8),
              theme.colorScheme.surface,
              theme.colorScheme.surface,
            ],
            stops: const [0.0, 0.2, 1.0],
          ),
        ),
        child: snapshot == null
            ? _buildBootView(context)
            : _buildSnapshotView(context, snapshot),
      ),
    );
  }

  Widget _buildBootView(BuildContext context) {
    final theme = Theme.of(context);
    final rootUrl = _rootUrl;
    final source = _primarySource;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _CosmeticHeroCard(
          title: 'Kozmetik ve Ki\u015Fisel Bak\u0131m',
          subtitle:
              'Bu tarafta hiyerar\u015Fiyi d\u00FCz kuruyoruz: \u00F6nce \u00FCst kategori, sonra alt kategori, sonra \u00FCr\u00FCn listesi. Derin linkleri ayn\u0131 seviyede g\u00F6stermiyorum.',
        ),
        const SizedBox(height: 16),
        if (source != null)
          _SectionCard(
            title: 'Kaynak',
            subtitle:
                'Kozmetik taraf\u0131n\u0131 Akak\u00E7e kategori a\u011Fac\u0131ndan okuyup ad\u0131m ad\u0131m geziyoruz.',
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.spa_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatSourceName(source.name),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'K\u00F6kten ba\u015Fl\u0131yoruz, sonra alt ba\u015Fl\u0131klara iniyoruz.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        const _SectionCard(
          title: 'Ornek Yol',
          subtitle:
              'Senin verdi\u011Fin zinciri bu mant\u0131kla gezece\u011Fiz.',
          child: Column(
            children: [
              _RouteStep(index: 1, label: 'Kozmetik, Ki\u015Fisel Bak\u0131m'),
              SizedBox(height: 10),
              _RouteStep(index: 2, label: 'Ki\u015Fisel Bak\u0131m'),
              SizedBox(height: 10),
              _RouteStep(
                  index: 3, label: 'A\u011F\u0131z, Di\u015F Bak\u0131m\u0131'),
              SizedBox(height: 10),
              _RouteStep(index: 4, label: 'A\u011F\u0131z Gargaras\u0131'),
            ],
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          _ErrorCard(
            title: 'Kozmetik verisi al\u0131namad\u0131',
            message: _errorMessage!,
            onRetry: rootUrl == null || _isLoading
                ? null
                : () => _openSnapshot(rootUrl),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: rootUrl == null || _isLoading
                ? null
                : () => _openSnapshot(rootUrl),
            icon: Icon(
              _isLoading
                  ? Icons.hourglass_top_rounded
                  : Icons.arrow_forward_rounded,
            ),
            label: Text(
              _isLoading
                  ? 'Kategori a\u011Fac\u0131 y\u00FCkleniyor...'
                  : 'K\u00F6k Kategoriden Ba\u015Fla',
            ),
          ),
        ),
        if (_isLoading) ...[
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }

  Widget _buildSnapshotView(
    BuildContext context,
    CosmeticCategorySnapshot snapshot,
  ) {
    final theme = Theme.of(context);
    final filteredCategories = snapshot.childCategories
        .where((node) => _matchesQuery(node.title))
        .toList();
    final filteredProducts = snapshot.productCards
        .where((card) => _matchesQuery(card.title))
        .toList();
    final totalCountLabel = snapshot.totalProductCount == null
        ? null
        : '${snapshot.totalProductCount} farkl\u0131 \u00FCr\u00FCn';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CosmeticHeroCard(
          title: repairTurkishText(snapshot.title),
          subtitle: snapshot.isListingPage
              ? 'Bu bir \u00FCr\u00FCn listesi. Burada marka bazl\u0131 bir\u00E7ok ayn\u0131 tip \u00FCr\u00FCn var; bir sonraki ad\u0131mda bunlar\u0131 teklif ve sat\u0131c\u0131 baz\u0131nda k\u0131yaslayaca\u011F\u0131z.'
              : 'Bu ekranda alt kategoriler var. Bir alt dala indik\u00E7e sonunda \u00FCr\u00FCn listesine varaca\u011F\u0131z.',
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Hiyerar\u015Fi',
          subtitle: 'Bulundu\u011Fun yerin tam yolu.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: snapshot.breadcrumbs
                .map(
                  (crumb) => Chip(
                    label: Text(repairTurkishText(crumb)),
                    avatar: const Icon(Icons.chevron_right_rounded, size: 18),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Ara',
          subtitle:
              'Bu sayfadaki alt kategorileri veya \u00FCr\u00FCnleri s\u00FCz.',
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Orn: gargara, listerine, alkolsuz...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.trim().isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => setState(() => _searchQuery = ''),
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
        if (snapshot.filterTags.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Filtre Etiketleri',
            subtitle:
                'Akak\u00E7e sayfas\u0131ndaki yard\u0131mc\u0131 filtreler.',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: snapshot.filterTags
                  .map(
                    (tag) => Chip(
                      label: Text(repairTurkishText(tag)),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        if (filteredCategories.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Alt Kategoriler',
            subtitle: 'Bir alt kategoriye in ve listeye do\u011Fru ilerle.',
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredCategories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 154,
              ),
              itemBuilder: (context, index) {
                final category = filteredCategories[index];
                return _CategoryCard(
                  category: category,
                  onTap: _isLoading ? null : () => _openSnapshot(category.url),
                );
              },
            ),
          ),
        ],
        if (filteredProducts.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionCard(
            title: totalCountLabel == null
                ? 'Ur\u00FCnler'
                : 'Ur\u00FCnler - $totalCountLabel',
            subtitle:
                'Buradaki kartlar A\u011F\u0131z Gargaras\u0131 gibi bir alt \u00FCr\u00FCn grubunun i\u00E7indeki marka ve varyant listesini veriyor.',
            child: Column(
              children: [
                for (final product in filteredProducts) ...[
                  _ProductCard(product: product),
                  if (product != filteredProducts.last)
                    const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
        if (filteredCategories.isEmpty &&
            filteredProducts.isEmpty &&
            !_isLoading) ...[
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Sonu\u00E7 Yok',
            subtitle:
                'Bu aramayla e\u015Fle\u015Fen kategori veya \u00FCr\u00FCn bulunamad\u0131.',
            child: Text(
              'Aramay\u0131 temizleyip tekrar deneyebilirsin.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          _ErrorCard(
            title: 'Sayfa al\u0131namad\u0131',
            message: _errorMessage!,
            onRetry: _isLoading
                ? null
                : () =>
                    _openSnapshot(snapshot.requestUrl, replaceCurrent: true),
          ),
        ],
        if (_isLoading) ...[
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }
}

class _CosmeticHeroCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _CosmeticHeroCard({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF502A63),
            Color(0xFF9C4D8B),
            Color(0xFFE78A6A),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.spa_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  repairTurkishText(title),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  repairTurkishText(subtitle),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            repairTurkishText(title),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            repairTurkishText(subtitle),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _RouteStep extends StatelessWidget {
  final int index;
  final String label;

  const _RouteStep({
    required this.index,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            repairTurkishText(label),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CosmeticCategoryNode category;
  final VoidCallback? onTap;

  const _CategoryCard({
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  category.kind == CosmeticNodeKind.listing
                      ? Icons.inventory_2_rounded
                      : Icons.folder_open_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                repairTurkishText(category.title),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                category.itemCount == null
                    ? 'Kategoriye gir'
                    : '${category.itemCount} urun',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final CosmeticProductCard product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProductImage(imageUrl: product.imageUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.badgeText != null) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      product.badgeText!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF2E7D32),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  repairTurkishText(product.title),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  repairTurkishText(product.priceText),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (product.unitPriceText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    repairTurkishText(product.unitPriceText!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (product.offerCount != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '+${product.offerCount} fiyat',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String? imageUrl;

  const _ProductImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null || imageUrl!.trim().isEmpty
          ? Icon(
              Icons.spa_outlined,
              color: theme.colorScheme.primary,
            )
          : Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Icon(
                  Icons.spa_outlined,
                  color: theme.colorScheme.primary,
                );
              },
            ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const _ErrorCard({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  repairTurkishText(title),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            repairTurkishText(message),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ],
      ),
    );
  }
}
