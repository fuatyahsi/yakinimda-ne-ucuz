import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/market_fiyati.dart';
import '../models/market_shopping_list.dart';
import '../models/smart_actueller.dart';
import 'market_shopping_list_screen.dart';
import '../providers/app_provider.dart';
import '../models/supabase_market.dart';
import '../services/supabase_service.dart';
import '../utils/app_theme.dart';
import '../utils/market_registry.dart';
import '../utils/product_category.dart';
import '../utils/text_repair.dart';

const _officialMarketEmojiById = <String, String>{
  'a101': '🟡',
  'bim': '🔴',
  'sok': '🟠',
  'migros': '🟢',
  'carrefoursa': '🔵',
  'hakmar': '🟤',
  'metro': '🟣',
  'tarim-kredi': '🌾',
  'file': '🟩',
  'bildirici': '📣',
  'altunbilekler': '🛒',
  'macrocenter': '🥩',
  'gimsa': '🏬',
  'akyurt': '🧺',
};

class _OfficialMarketOption {
  final String id;
  final String label;
  final String emoji;

  const _OfficialMarketOption({
    required this.id,
    required this.label,
    required this.emoji,
  });
}

List<_OfficialMarketOption> _officialMarketOptionsFor(
    Iterable<String> marketIds) {
  final uniqueIds = normalizeMarketIds(marketIds).toSet().toList()
    ..sort(
      (a, b) => displayNameForMarket(
        a,
      ).toLowerCase().compareTo(displayNameForMarket(b).toLowerCase()),
    );

  return uniqueIds
      .map(
        (marketId) => _OfficialMarketOption(
          id: marketId,
          label: displayNameForMarket(marketId),
          emoji: _officialMarketEmojiById[marketId] ?? '🏪',
        ),
      )
      .toList(growable: false);
}

class SmartActuellerScreen extends StatefulWidget {
  final bool autoSyncOnOpen;

  const SmartActuellerScreen({
    super.key,
    this.autoSyncOnOpen = false,
  });

  @override
  State<SmartActuellerScreen> createState() => _SmartActuellerScreenState();
}

class _SmartActuellerScreenState extends State<SmartActuellerScreen> {
  static const _distanceOptionsKm = [5, 10, 20, 30, 50];

  bool _isScanning = false;
  bool _didTriggerAutoSync = false;
  bool _isApplyingFilters = false;
  ProductCategory? _selectedCategory;
  String? _selectedDisplayCategoryId;
  String? _selectedMarketFilter;
  String _searchQuery = '';
  List<ActuellerCatalogItem> _searchResultItems = const [];
  String? _filterStatusLabel;
  Map<String, List<ActuellerCatalogItem>> _loadedDisplayCategoryItemsById =
      const {};
  final TextEditingController _searchController = TextEditingController();
  final List<ActuellerCatalogItem> _recentViewedItems = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !widget.autoSyncOnOpen || _didTriggerAutoSync) return;
      final provider = context.read<AppProvider>();
      if (provider.smartKitchenPreferences.preferredMarkets.isEmpty) return;
      if (provider.marketFiyatiSession == null) return;
      _didTriggerAutoSync = true;
      await _syncCatalog(provider);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    final query = value.trim();
    if (query.isEmpty &&
        (_searchQuery.isNotEmpty || _searchResultItems.isNotEmpty)) {
      setState(() {
        _searchQuery = '';
        _searchResultItems = const [];
      });
    }
  }

  Future<void> _syncCatalog(AppProvider provider) async {
    if (provider.marketFiyatiSession == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('\u00D6nce konum se\u00E7.'),
        ),
      );
      return;
    }
    setState(() {
      _isScanning = true;
      _selectedDisplayCategoryId = null;
      _selectedCategory = null;
      _selectedMarketFilter = null;
      _searchQuery = '';
      _searchResultItems = const [];
      _loadedDisplayCategoryItemsById = const {};
      _searchController.clear();
    });
    try {
      await provider.syncPreferredActuellerCatalog(force: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _rememberViewedItem(ActuellerCatalogItem item) {
    final identity = item.sourceProductId ?? item.id;
    final updated = [
      item,
      ..._recentViewedItems.where(
        (candidate) => (candidate.sourceProductId ?? candidate.id) != identity,
      ),
    ].take(6).toList();

    setState(() {
      _recentViewedItems
        ..clear()
        ..addAll(updated);
    });
  }

  Future<void> _runSearchQuery() async {
    final query = _searchController.text.trim();
    FocusScope.of(context).unfocus();
    if (_selectedDisplayCategoryId != null) {
      setState(() {
        _filterStatusLabel =
            'Kategori açık. Önce kategoriyi temizle, sonra ürün ara.';
      });
      return;
    }
    setState(() {
      _isApplyingFilters = true;
      _filterStatusLabel =
          query.isEmpty ? '\u00DCr\u00FCnler Getiriliyor' : 'Aran\u0131yor';
    });
    try {
      final results = query.isEmpty
          ? const <ActuellerCatalogItem>[]
          : await context.read<AppProvider>().searchOfficialCatalogItems(query);
      if (!mounted) return;
      setState(() {
        _searchQuery = query;
        _searchResultItems = results;
        _selectedDisplayCategoryId = null;
        _selectedCategory = null;
        _selectedMarketFilter = null;
        _isApplyingFilters = false;
        _filterStatusLabel = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isApplyingFilters = false;
        _filterStatusLabel = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(repairTurkishText(error.toString()))),
      );
    }
  }

  Future<void> _runDisplayCategoryFilter(String? categoryId) async {
    FocusScope.of(context).unfocus();
    final category = _findBrowseCategory(categoryId);
    final sourceCategories = category?.fallbackOfficialCategories ?? const [];
    setState(() {
      _isApplyingFilters = true;
      _filterStatusLabel = '\u00DCr\u00FCnler Getiriliyor';
    });
    try {
      final results = categoryId == null
          ? const <ActuellerCatalogItem>[]
          : await context
              .read<AppProvider>()
              .fetchOfficialItemsForSourceCategories(
                sourceCategories: sourceCategories,
                categoryId: categoryId,
              );
      if (!mounted) return;
      setState(() {
        _selectedDisplayCategoryId = categoryId;
        _selectedCategory = null;
        _selectedMarketFilter = null;
        _searchQuery = '';
        _searchResultItems = const [];
        _searchController.clear();
        _loadedDisplayCategoryItemsById = categoryId == null
            ? const {}
            : {
                ..._loadedDisplayCategoryItemsById,
                categoryId: results,
              };
        _isApplyingFilters = false;
        _filterStatusLabel = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isApplyingFilters = false;
        _filterStatusLabel = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(repairTurkishText(error.toString()))),
      );
    }
  }

  _MarketBrowseCategory? _findBrowseCategory(String? categoryId) {
    if (categoryId == null) {
      return null;
    }
    for (final category in _marketBrowseCategories) {
      if (category.id == categoryId) {
        return category;
      }
    }
    return null;
  }

  int _browseCategoryItemCount(_MarketBrowseCategory category) {
    final loadedItems = _loadedDisplayCategoryItemsById[category.id];
    if (loadedItems != null) {
      return loadedItems.length;
    }
    return -1;
  }

  Future<void> _showMarketSelectorSheet(
    BuildContext context, {
    required AppProvider provider,
    required bool isTr,
  }) async {
    if (provider.marketFiyatiSession == null) {
      await _showLocationPicker(
        context,
        provider: provider,
        isTr: isTr,
      );
      return;
    }

    // Backend'den tum destekli marketleri cek. Basarisizsa null doner ve
    // sheet eski (marketfiyati.org.tr) moduna duser.
    List<SupabaseMarket>? backendMarkets;
    if (SupabaseService.instance.isReady) {
      try {
        backendMarkets = await SupabaseService.instance.fetchMarkets();
        if (backendMarkets.isEmpty) backendMarkets = null;
      } catch (_) {
        backendMarkets = null;
      }
    }

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        // Backend modundaysak tum destekli marketler secilebilir; degilse
        // sadece marketfiyati.org.tr'nin bu konum icin dondurdugu liste.
        final selectableIds = backendMarkets != null
            ? backendMarkets.map((m) => m.id).toSet()
            : provider.marketFiyatiAvailableMarketIds.toSet();
        final prefsRaw =
            provider.smartKitchenPreferences.preferredMarkets.toSet();
        var initialSelectedIds =
            prefsRaw.where(selectableIds.contains).toSet();
        // Eski registry ID'leri (ornegin 'kooperatif' -> backend'de
        // 'tarim-kredi') uyusmadigi durumu migration sayiyoruz: kullanici
        // prefs kaydetmis ama bir kismi backend'de yok. Bu durumda tier 1+2
        // baseline'i ekleyerek kullaniciya dolu bir varsayilan gosteriyoruz.
        final hasLegacyIds = backendMarkets != null &&
            prefsRaw.any((id) => !selectableIds.contains(id));
        // Kullanici hic secim yapmadiysa ya da eski ID'ler varsa backend
        // modunda tier 1+2 default (12 ulusal/orta olcekli zincir).
        if (backendMarkets != null &&
            (initialSelectedIds.isEmpty || hasLegacyIds)) {
          final tierDefaults = backendMarkets
              .where((m) => (m.tier ?? 99) <= 2)
              .map((m) => m.id)
              .toSet();
          initialSelectedIds = {...initialSelectedIds, ...tierDefaults};
        }
        final draftSelectedIds = <String>{...initialSelectedIds};
        var isSaving = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return FractionallySizedBox(
              heightFactor: 0.86,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                    child: Column(
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
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isTr ? 'Marketlerini Seç' : 'Choose stores',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isTr
                                        ? 'Sadece gezeceğin marketleri işaretle. Seçimi bitirince listeyi tek seferde güncelleyelim.'
                                        : 'Pick only the stores you plan to visit, then apply once.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _SearchMetaChip(
                              icon: Icons.storefront_rounded,
                              label: isTr
                                  ? '${draftSelectedIds.length} market seçili'
                                  : '${draftSelectedIds.length} stores selected',
                              accent: true,
                            ),
                            if (!setEquals(
                                draftSelectedIds, initialSelectedIds))
                              _SearchMetaChip(
                                icon: Icons.auto_awesome_rounded,
                                label:
                                    isTr ? 'Yeni seçim hazır' : 'Changes ready',
                                accent: false,
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Builder(
                              builder: (context) {
                                if (backendMarkets != null) {
                                  return _TierGroupedMarketPicker(
                                    markets: backendMarkets,
                                    draftSelectedIds: draftSelectedIds,
                                    locallyAvailableIds: provider
                                        .marketFiyatiAvailableMarketIds
                                        .toSet(),
                                    enabled: !isSaving,
                                    isTr: isTr,
                                    onToggle: (id) {
                                      if (isSaving) return;
                                      setSheetState(() {
                                        if (draftSelectedIds.contains(id)) {
                                          draftSelectedIds.remove(id);
                                        } else {
                                          draftSelectedIds.add(id);
                                        }
                                      });
                                    },
                                  );
                                }
                                // Fallback: backend yoksa eski davranis.
                                final availableOfficialMarkets =
                                    _officialMarketOptionsFor(
                                  provider.marketFiyatiAvailableMarketIds,
                                );
                                if (availableOfficialMarkets.isEmpty) {
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      isTr
                                          ? 'Bu konum için resmî fiyat desteği olan market bulunamadı.'
                                          : 'No official-price stores found for this location.',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        height: 1.35,
                                      ),
                                    ),
                                  );
                                }

                                return Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children:
                                      availableOfficialMarkets.map((market) {
                                    final isSelected =
                                        draftSelectedIds.contains(market.id);
                                    return _ShowcaseMarketPill(
                                      emoji: market.emoji,
                                      label: market.label,
                                      isSelected: isSelected,
                                      enabled: !isSaving,
                                      onTap: () {
                                        if (isSaving) {
                                          return;
                                        }
                                        setSheetState(() {
                                          if (draftSelectedIds
                                              .contains(market.id)) {
                                            draftSelectedIds.remove(market.id);
                                          } else {
                                            draftSelectedIds.add(market.id);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (setEquals(
                                      draftSelectedIds,
                                      initialSelectedIds,
                                    )) {
                                      Navigator.of(sheetContext).pop();
                                      return;
                                    }
                                    setSheetState(() => isSaving = true);
                                    try {
                                      await provider.setPreferredMarkets(
                                        draftSelectedIds,
                                        forceSync: false,
                                      );
                                      if (!sheetContext.mounted) {
                                        return;
                                      }
                                      Navigator.of(sheetContext).pop();
                                      Future<void>.microtask(() async {
                                        try {
                                          await provider
                                              .syncPreferredActuellerCatalog(
                                            force: true,
                                          );
                                        } catch (_) {
                                          // Keep the selector responsive; sync errors surface in screen state.
                                        }
                                      });
                                    } finally {
                                      if (sheetContext.mounted) {
                                        setSheetState(() => isSaving = false);
                                      }
                                    }
                                  },
                            icon: Icon(
                              isSaving
                                  ? Icons.hourglass_top_rounded
                                  : Icons.check_rounded,
                            ),
                            label: Text(
                              isSaving
                                  ? (isTr ? 'Güncelleniyor...' : 'Applying...')
                                  : (isTr
                                      ? 'Seçimi Bitir'
                                      : 'Done with selection'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openComparisonForItem(
    BuildContext context, {
    required AppProvider provider,
    required ActuellerCatalogItem item,
    required bool isTr,
  }) async {
    if (provider.smartKitchenPreferences.preferredMarkets.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isTr
                ? 'Kar\u015F\u0131la\u015Ft\u0131rma i\u00E7in en az 2 market se\u00E7.'
                : 'Select at least 2 stores for comparison.',
          ),
        ),
      );
      return;
    }

    _rememberViewedItem(item);
    await _showMarketComparison(
      context,
      item: item,
      isTr: isTr,
    );
  }

  Future<void> _addItemToShoppingList(
    BuildContext context, {
    required AppProvider provider,
    required ActuellerCatalogItem item,
    List<ActuellerCatalogItem> seededAlternatives = const [],
    required bool isTr,
  }) async {
    try {
      final alternatives = await _resolveShoppingListAlternatives(
        provider,
        item,
        seededAlternatives: seededAlternatives,
      );
      final isNew = await provider.addShoppingListEntry(
        item,
        alternatives: alternatives,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(
            isNew
                ? '\u00DCr\u00FCn al\u0131\u015Fveri\u015F listene eklendi.'
                : '\u00DCr\u00FCn al\u0131\u015Fveri\u015F listende g\u00FCncellendi.',
          ),
          action: SnackBarAction(
            label: 'Liste',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MarketShoppingListScreen(),
                ),
              );
            },
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _toggleItemInShoppingList(
    BuildContext context, {
    required AppProvider provider,
    required ActuellerCatalogItem item,
    required bool isTr,
  }) async {
    final existingEntry = _shoppingListEntryForItem(provider, item);
    if (existingEntry != null) {
      await provider.removeShoppingListEntry(existingEntry.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ürün alışveriş listesinden çıkarıldı.'),
        ),
      );
      return;
    }

    await _addItemToShoppingList(
      context,
      provider: provider,
      item: item,
      isTr: isTr,
    );
  }

  MarketShoppingListEntry? _shoppingListEntryForItem(
    AppProvider provider,
    ActuellerCatalogItem item,
  ) {
    final identityKey = _shoppingIdentityForItem(item);
    for (final entry in provider.shoppingListEntries) {
      if (entry.identityKey == identityKey) {
        return entry;
      }
    }
    return null;
  }

  String _shoppingIdentityForItem(ActuellerCatalogItem item) {
    final sourceProductId = item.sourceProductId?.trim();
    if (sourceProductId != null && sourceProductId.isNotEmpty) {
      return 'product:$sourceProductId';
    }

    final marketId = normalizeMarketId(item.marketName) ??
        item.marketName.toLowerCase().trim();
    final title = _normalizeCatalogDisplayValue(item.productTitle);
    final weight = _normalizeCatalogDisplayValue(item.weight ?? '');
    return 'fallback:$marketId:$title:$weight';
  }

  Future<List<ActuellerCatalogItem>> _resolveShoppingListAlternatives(
      AppProvider provider, ActuellerCatalogItem item,
      {List<ActuellerCatalogItem> seededAlternatives = const []}) async {
    final mergedByMarket = <String, ActuellerCatalogItem>{};
    final currentMarketId =
        normalizeMarketId(item.marketName) ?? item.marketName.toLowerCase();

    void mergeItems(Iterable<ActuellerCatalogItem> candidates) {
      for (final candidate in candidates) {
        final marketId = normalizeMarketId(candidate.marketName) ??
            candidate.marketName.toLowerCase();
        if (marketId == currentMarketId) {
          continue;
        }
        final previous = mergedByMarket[marketId];
        if (previous == null || candidate.price < previous.price) {
          mergedByMarket[marketId] = candidate;
        }
      }
    }

    if (seededAlternatives.isNotEmpty) {
      mergeItems(seededAlternatives);
    }

    if (item.sourceProductId != null && provider.marketFiyatiSession != null) {
      try {
        final officialItems = await provider.fetchOfficialSimilarProducts(item);
        mergeItems(
          _buildShoppingOfficialAlternatives(
            base: item,
            candidates: officialItems,
          ),
        );
      } catch (_) {
        // Keep list adding resilient even if official lookup fails.
      }
    }

    if (mergedByMarket.isEmpty) {
      final allCatalog =
          provider.lastActuellerScanResult?.catalogItems ?? const [];
      mergeItems(
        _buildShoppingBrochureAlternatives(
          base: item,
          allItems: allCatalog,
        ),
      );
    }

    final sorted = mergedByMarket.values.toList()
      ..sort((a, b) => a.price.compareTo(b.price));
    return sorted;
  }

  Future<void> _showLocationPicker(
    BuildContext context, {
    required AppProvider provider,
    required bool isTr,
  }) async {
    final controller = TextEditingController();
    final currentSession = provider.marketFiyatiSession;
    var suggestions = <MarketFiyatiLocationSuggestion>[];
    MarketFiyatiLocationSuggestion? selectedSuggestion;
    var selectedDistanceKm = currentSession?.distance ?? 20;
    var isSearching = false;
    var isSaving = false;
    String? errorMessage;

    Future<void> runSearch(StateSetter setSheetState) async {
      final query = controller.text.trim();
      if (query.length < 2) {
        setSheetState(() {
          suggestions = const [];
          errorMessage =
              isTr ? 'En az 2 harf gir.' : 'Enter at least 2 characters.';
        });
        return;
      }

      setSheetState(() {
        isSearching = true;
        errorMessage = null;
      });

      try {
        final results = await provider.searchMarketFiyatiLocations(query);
        if (!mounted) return;
        setSheetState(() {
          suggestions = results;
          selectedSuggestion = null;
          if (results.isEmpty) {
            errorMessage = isTr
                ? 'Sonu\u00E7 bulunamad\u0131.'
                : 'No locations were found.';
          }
        });
      } catch (error) {
        if (!mounted) return;
        final raw = error.toString();
        // Harici API'nin timeout'unu kullaniciya anlamli hale getir.
        final isTimeout = raw.contains('TimeoutException');
        setSheetState(() {
          // Eski arama sonuclarini temizle; yanliltici olmasin.
          suggestions = const [];
          selectedSuggestion = null;
          if (isTimeout) {
            errorMessage = isTr
                ? 'Konum servisi \u015Fu an yan\u0131t vermiyor. Birka\u00E7 saniye sonra tekrar dene.'
                : 'Location service is not responding. Please retry in a few seconds.';
          } else {
            errorMessage = raw.replaceFirst('Exception: ', '');
          }
        });
      } finally {
        if (mounted) {
          setSheetState(() => isSearching = false);
        }
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final locationLabel = provider.marketFiyatiLocationLabel;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.86,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                        const SizedBox(height: 18),
                        Text(
                          isTr
                              ? 'Konum ve Mesafe Se\u00E7'
                              : 'Choose Location and Distance',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isTr
                              ? 'Konumu arat, sonra yak\u0131n marketleri hangi yar\u0131\u00E7apta getirece\u011Fimizi se\u00E7.'
                              : 'Search a location, then choose how far nearby stores should be fetched.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        if (locationLabel != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer
                                  .withValues(alpha: 0.38),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    locationLabel,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await provider.clearMarketFiyatiLocation();
                                    if (!mounted) return;
                                    setSheetState(() {
                                      selectedSuggestion = null;
                                    });
                                  },
                                  child: Text(isTr ? 'Temizle' : 'Clear'),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                keyboardType: TextInputType.text,
                                enableSuggestions: true,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => runSearch(setSheetState),
                                decoration: InputDecoration(
                                  hintText: isTr
                                      ? '\u00D6ve\u00E7ler / ovecler, Balgat...'
                                      : 'Search a location...',
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton(
                              onPressed: isSearching || isSaving
                                  ? null
                                  : () => runSearch(setSheetState),
                              child: Text(isTr ? 'Ara' : 'Search'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: selectedDistanceKm,
                              isExpanded: true,
                              borderRadius: BorderRadius.circular(18),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                              ),
                              items: _distanceOptionsKm
                                  .map(
                                    (distance) => DropdownMenuItem<int>(
                                      value: distance,
                                      child: Text(
                                        isTr
                                            ? 'Mesafe: $distance km'
                                            : 'Distance: $distance km',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: isSaving
                                  ? null
                                  : (value) {
                                      if (value == null) return;
                                      setSheetState(
                                        () => selectedDistanceKm = value,
                                      );
                                    },
                            ),
                          ),
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            errorMessage!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Flexible(
                          child: isSearching
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: suggestions.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final suggestion = suggestions[index];
                                    final subtitle = repairTurkishText(
                                      suggestion.fullLabel,
                                    ).trim();
                                    final isSelected = identical(
                                        selectedSuggestion, suggestion);
                                    return Material(
                                      color: isSelected
                                          ? theme.colorScheme.primaryContainer
                                              .withValues(alpha: 0.48)
                                          : theme.colorScheme
                                              .surfaceContainerHighest
                                              .withValues(alpha: 0.38),
                                      borderRadius: BorderRadius.circular(18),
                                      child: ListTile(
                                        onTap: isSaving
                                            ? null
                                            : () {
                                                controller.text =
                                                    suggestion.displayLabel;
                                                setSheetState(() {
                                                  selectedSuggestion =
                                                      suggestion;
                                                  errorMessage = null;
                                                });
                                              },
                                        leading: Icon(
                                          suggestion.pointOfInterestName
                                                  .trim()
                                                  .isNotEmpty
                                              ? Icons.place_rounded
                                              : Icons.map_outlined,
                                        ),
                                        title: Text(
                                          repairTurkishText(
                                            suggestion.displayLabel,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        subtitle: Text(
                                          subtitle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: isSelected
                                            ? Icon(
                                                Icons.check_circle_rounded,
                                                color:
                                                    theme.colorScheme.primary,
                                              )
                                            : null,
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (selectedSuggestion == null) {
                                      setSheetState(() {
                                        errorMessage = isTr
                                            ? '\u00D6nce bir konum se\u00E7.'
                                            : 'Select a location first.';
                                      });
                                      return;
                                    }

                                    setSheetState(() {
                                      isSaving = true;
                                      errorMessage = null;
                                    });

                                    try {
                                      await provider.setMarketFiyatiLocation(
                                        selectedSuggestion!,
                                        nearestDistance: selectedDistanceKm,
                                        sessionDistance: selectedDistanceKm,
                                      );
                                      if (!sheetContext.mounted ||
                                          !context.mounted) {
                                        return;
                                      }
                                      Navigator.of(sheetContext).pop();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            isTr
                                                ? 'Konum kaydedildi: ${selectedSuggestion!.displayLabel}'
                                                : 'Location saved: ${selectedSuggestion!.displayLabel}',
                                          ),
                                        ),
                                      );
                                    } catch (error) {
                                      if (!sheetContext.mounted) {
                                        return;
                                      }
                                      setSheetState(() {
                                        errorMessage = error
                                            .toString()
                                            .replaceFirst('Exception: ', '');
                                      });
                                    } finally {
                                      if (sheetContext.mounted) {
                                        setSheetState(
                                          () => isSaving = false,
                                        );
                                      }
                                    }
                                  },
                            icon: Icon(
                              isSaving
                                  ? Icons.hourglass_top_rounded
                                  : Icons.save_rounded,
                            ),
                            label: Text(
                              isSaving
                                  ? (isTr ? 'Kaydediliyor...' : 'Saving...')
                                  : (isTr ? 'Kaydet' : 'Save'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
    const isTr = true;
    final theme = Theme.of(context);
    String clean(String value) => repairTurkishText(value);
    final scanResult = provider.lastActuellerScanResult;
    final isCatalogSyncing = provider.isActuellerCatalogSyncing;
    final catalogSyncAt = provider.lastActuellerCatalogSyncAt;
    final catalogBrochureCount = provider.lastActuellerCatalogBrochureCount;
    final catalogMessage = provider.actuellerCatalogSyncMessage;
    final hasSelectedMarkets =
        provider.smartKitchenPreferences.preferredMarkets.isNotEmpty;
    final marketFiyatiLocationLabel = provider.marketFiyatiLocationLabel;
    final hasLocation = marketFiyatiLocationLabel != null &&
        marketFiyatiLocationLabel.isNotEmpty;
    final hasOfficialSession = provider.marketFiyatiSession != null;
    final shoppingListCount = provider.shoppingListCount;

    final allItems = scanResult?.catalogItems ?? const <ActuellerCatalogItem>[];
    final hasActiveCategoryFilter = _selectedDisplayCategoryId != null;
    final hasActiveSearchQuery = _searchQuery.trim().isNotEmpty;
    final hasActiveProductFilter =
        hasOfficialSession && (hasActiveCategoryFilter || hasActiveSearchQuery);
    final filteredItems = !hasActiveProductFilter
        ? const <ActuellerCatalogItem>[]
        : hasActiveSearchQuery
            ? List<ActuellerCatalogItem>.unmodifiable(_searchResultItems)
            : List<ActuellerCatalogItem>.unmodifiable(
                _loadedDisplayCategoryItemsById[_selectedDisplayCategoryId!] ??
                    const <ActuellerCatalogItem>[],
              );
    final visibleAllItems =
        hasOfficialSession ? allItems : const <ActuellerCatalogItem>[];
    final visibleFilteredItems =
        hasActiveProductFilter ? filteredItems : const <ActuellerCatalogItem>[];
    final displayCategories = visibleAllItems.isEmpty
        ? const <_MarketBrowseCategory>[]
        : _marketBrowseCategories;
    final displayCategoryCounts = {
      for (final category in displayCategories)
        category.id: _browseCategoryItemCount(category),
    };

    return Scaffold(
      backgroundColor: AppTheme.shellBackground,
      appBar: AppBar(
        title: const Text('Markette Bug\u00FCn Ne Ucuz?'),
        actions: [
          IconButton(
            onPressed: () => _showLocationPicker(
              context,
              provider: provider,
              isTr: isTr,
            ),
            icon: Icon(
              marketFiyatiLocationLabel == null
                  ? Icons.location_on_outlined
                  : Icons.location_on_rounded,
            ),
          ),
          if (hasSelectedMarkets)
            IconButton(
              onPressed: isCatalogSyncing || !hasOfficialSession
                  ? null
                  : () => _syncCatalog(provider),
              icon: Icon(
                isCatalogSyncing
                    ? Icons.hourglass_top_rounded
                    : Icons.refresh_rounded,
              ),
            ),
          IconButton(
            tooltip: 'Al\u0131\u015fveri\u015f Listem',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MarketShoppingListScreen(),
                ),
              );
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart_outlined),
                if (shoppingListCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        shoppingListCount > 9 ? '9+' : '$shoppingListCount',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primaryContainer.withValues(alpha: 0.18),
              theme.colorScheme.surface,
              theme.colorScheme.surface,
            ],
            stops: const [0.0, 0.18, 1.0],
          ),
        ),
        child: visibleAllItems.isEmpty
            ? _buildEmptyState(
                context,
                provider: provider,
                isTr: isTr,
                hasSelectedMarkets: hasSelectedMarkets,
                isSyncing: isCatalogSyncing || _isScanning,
                catalogSyncAt: catalogSyncAt,
                catalogMessage:
                    catalogMessage == null ? null : clean(catalogMessage),
                marketFiyatiLocationLabel: marketFiyatiLocationLabel,
                usesOfficialSource: true,
              )
            : _buildMarketHomeView(
                context,
                isTr: isTr,
                theme: theme,
                allItems: visibleAllItems,
                filteredItems: visibleFilteredItems,
                displayCategories: displayCategories,
                displayCategoryCounts: displayCategoryCounts,
                catalogBrochureCount: catalogBrochureCount,
                catalogSyncAt: catalogSyncAt,
                isSyncing: isCatalogSyncing || _isScanning,
                provider: provider,
                marketFiyatiLocationLabel: marketFiyatiLocationLabel,
                hasLocation: hasLocation,
                hasActiveProductFilter: hasActiveProductFilter,
                usesOfficialSource: true,
              ),
      ),
    );
  }

  // •
  //  EMPTY STATE • no products yet
  // •
  Widget _buildEmptyState(
    BuildContext context, {
    required AppProvider provider,
    required bool isTr,
    required bool hasSelectedMarkets,
    required bool isSyncing,
    required DateTime? catalogSyncAt,
    required String? catalogMessage,
    required String? marketFiyatiLocationLabel,
    required bool usesOfficialSource,
  }) {
    final theme = Theme.of(context);
    final hasLocation = marketFiyatiLocationLabel != null &&
        marketFiyatiLocationLabel.isNotEmpty;
    final needsLocation = !hasLocation;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeroCard(
          isTr: isTr,
          usesOfficialSource: usesOfficialSource,
        ),
        const SizedBox(height: 16),
        _LocationSessionCard(
          isTr: isTr,
          locationLabel: marketFiyatiLocationLabel,
          onTap: () => _showLocationPicker(
            context,
            provider: provider,
            isTr: isTr,
          ),
        ),
        const SizedBox(height: 16),
        _MarketSelectionSummaryCard(
          isTr: isTr,
          provider: provider,
          enabled: hasLocation,
          onOpenMarkets: () => _showMarketSelectorSheet(
            context,
            provider: provider,
            isTr: isTr,
          ),
          onChooseLocation: () => _showLocationPicker(
            context,
            provider: provider,
            isTr: isTr,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                !hasSelectedMarkets
                    ? Icons.storefront_outlined
                    : needsLocation
                        ? Icons.location_on_outlined
                        : Icons.cloud_download_outlined,
                size: 48,
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 14),
              Text(
                needsLocation
                    ? (isTr
                        ? '\u00D6nce konumunu se\u00E7'
                        : 'Choose your location first')
                    : !hasSelectedMarkets
                        ? (isTr
                            ? '\u015Eimdi marketlerini se\u00E7'
                            : 'Now choose your stores')
                        : (isTr
                            ? 'Resm\u00EE fiyatlar\u0131 getir'
                            : 'Load official prices'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: isSyncing
                      ? null
                      : needsLocation
                          ? () => _showLocationPicker(
                                context,
                                provider: provider,
                                isTr: isTr,
                              )
                          : hasSelectedMarkets
                              ? () => _syncCatalog(provider)
                              : null,
                  icon: Icon(
                    isSyncing
                        ? Icons.hourglass_top_rounded
                        : needsLocation
                            ? Icons.location_on_rounded
                            : hasSelectedMarkets
                                ? Icons.search_rounded
                                : Icons.storefront_rounded,
                  ),
                  label: Text(
                    isSyncing
                        ? (isTr
                            ? 'Fiyatlar getiriliyor...'
                            : 'Loading prices...')
                        : needsLocation
                            ? (isTr ? 'Konum Se\u00E7' : 'Choose Location')
                            : hasSelectedMarkets
                                ? (isTr
                                    ? 'Fiyatlar\u0131 Getir'
                                    : 'Load Prices')
                                : (isTr
                                    ? 'Market Se\u00E7mek \u0130\u00E7in Konum Haz\u0131r'
                                    : 'Location Ready'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              if (catalogSyncAt != null || catalogMessage != null) ...[
                const SizedBox(height: 12),
                if (catalogMessage != null)
                  Text(
                    catalogMessage,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // •
  //  PRODUCT VIEW • categories + items
  // •
  // Kept temporarily as a fallback while the new market-first home layout settles.
  // ignore: unused_element
  Widget _buildProductView(
    BuildContext context, {
    required bool isTr,
    required ThemeData theme,
    required List<ActuellerCatalogItem> allItems,
    required List<ActuellerCatalogItem> filteredItems,
    required List<ProductCategory> sortedCategories,
    required Set<String> availableMarkets,
    required int catalogBrochureCount,
    required DateTime? catalogSyncAt,
    required bool isSyncing,
    required AppProvider provider,
    required String? marketFiyatiLocationLabel,
    required bool usesOfficialSource,
  }) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppTheme.heroGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppTheme.softShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(
                  Icons.local_offer_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTr
                          ? (usesOfficialSource
                              ? '$catalogBrochureCount resm\u00EE kategoriden ${allItems.length} \u00FCr\u00FCn'
                              : '$catalogBrochureCount bro\u015F\u00FCrden ${allItems.length} \u00FCr\u00FCn')
                          : (usesOfficialSource
                              ? '$catalogBrochureCount official categories, ${allItems.length} items'
                              : '$catalogBrochureCount flyers, ${allItems.length} items'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isTr
                          ? (usesOfficialSource
                              ? 'Yak\u0131ndaki marketlerde ayn\u0131 \u00FCr\u00FCn\u00FC kar\u015F\u0131la\u015Ft\u0131r, en iyi fiyat\u0131 h\u0131zl\u0131ca g\u00F6r.'
                              : 'Kategori se\u00E7, market filtrele, en iyi f\u0131rsat\u0131 h\u0131zl\u0131ca g\u00F6r.')
                          : (usesOfficialSource
                              ? 'Compare the same product across nearby stores and spot the best price fast.'
                              : 'Pick a category, filter by market, and see the best deal fast.'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // • Sticky filter bar •
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary line
              Row(
                children: [
                  Icon(Icons.local_offer_rounded,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isTr
                          ? (usesOfficialSource
                              ? '${allItems.length} \u00FCr\u00FCn \u2022 $catalogBrochureCount resm\u00EE kategori'
                              : '${allItems.length} \u00FCr\u00FCn \u2022 $catalogBrochureCount bro\u015F\u00FCr')
                          : (usesOfficialSource
                              ? '${allItems.length} items • $catalogBrochureCount official categories'
                              : '${allItems.length} items • $catalogBrochureCount flyers'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isSyncing)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              if (marketFiyatiLocationLabel != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        repairTurkishText(
                          isTr
                              ? 'Resm\u00EE fiyat konumu: $marketFiyatiLocationLabel'
                              : 'Official price location: $marketFiyatiLocationLabel',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _runSearchQuery(),
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: isTr
                      ? '\u00DCr\u00FCn ara: s\u00FCt, zeytinya\u011F\u0131, makarna...'
                      : 'Search products: milk, olive oil, pasta...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.45),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Category chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChipWidget(
                      label: isTr ? 'T\u00FCm\u00FC' : 'All',
                      isSelected: _selectedCategory == null,
                      onTap: () => setState(() => _selectedCategory = null),
                    ),
                    const SizedBox(width: 6),
                    ...sortedCategories.map((cat) {
                      final count =
                          allItems.where((i) => i.category == cat).length;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _FilterChipWidget(
                          label:
                              '${cat.emoji} ${isTr ? cat.labelTr : cat.labelEn} ($count)',
                          isSelected: _selectedCategory == cat,
                          onTap: () => setState(() {
                            _selectedCategory =
                                _selectedCategory == cat ? null : cat;
                          }),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Market filter chips
              if (availableMarkets.length > 1)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChipWidget(
                        label: isTr ? 'T\u00FCm marketler' : 'All stores',
                        isSelected: _selectedMarketFilter == null,
                        onTap: () =>
                            setState(() => _selectedMarketFilter = null),
                      ),
                      const SizedBox(width: 6),
                      ...availableMarkets.map((market) {
                        final displayName = displayNameForMarket(market);
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _FilterChipWidget(
                            label: displayName.isEmpty ? market : displayName,
                            isSelected: _selectedMarketFilter == market,
                            onTap: () => setState(() {
                              _selectedMarketFilter =
                                  _selectedMarketFilter == market
                                      ? null
                                      : market;
                            }),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const Divider(height: 1),

        // • Product list •
        Expanded(
          child: filteredItems.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      isTr
                          ? 'Bu filtreyle e\u015Fle\u015Fen \u00FCr\u00FCn yok.'
                          : 'No products match this filter.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return _ProductCard(
                      item: item,
                      isTr: isTr,
                      onCompare: () async {
                        if (provider.smartKitchenPreferences.preferredMarkets
                                .length <
                            2) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isTr
                                    ? 'Kar\u015F\u0131la\u015Ft\u0131rma i\u00E7in en az 2 market se\u00E7.'
                                    : 'Select at least 2 stores for comparison.',
                              ),
                            ),
                          );
                          return;
                        }
                        await _showMarketComparison(
                          context,
                          item: item,
                          isTr: isTr,
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  // •
  //  MARKET COMPARISON BOTTOM SHEET
  // •
  Widget _buildMarketHomeView(
    BuildContext context, {
    required bool isTr,
    required ThemeData theme,
    required List<ActuellerCatalogItem> allItems,
    required List<ActuellerCatalogItem> filteredItems,
    required List<_MarketBrowseCategory> displayCategories,
    required Map<String, int> displayCategoryCounts,
    required int catalogBrochureCount,
    required DateTime? catalogSyncAt,
    required bool isSyncing,
    required AppProvider provider,
    required String? marketFiyatiLocationLabel,
    required bool hasLocation,
    required bool hasActiveProductFilter,
    required bool usesOfficialSource,
  }) {
    final selectedCategory = displayCategories.where(
      (category) => category.id == _selectedDisplayCategoryId,
    );
    final activeCategory =
        selectedCategory.isEmpty ? null : selectedCategory.first;
    final summaryLabel = hasActiveProductFilter
        ? (isTr
            ? '${filteredItems.length}/${allItems.length} \u00FCr\u00FCn \u2022 $catalogBrochureCount kaynak kategori'
            : '${filteredItems.length}/${allItems.length} items \u2022 $catalogBrochureCount source categories')
        : (isTr
            ? '${allItems.length} \u00FCr\u00FCn haz\u0131r \u2022 $catalogBrochureCount kaynak kategori'
            : '${allItems.length} items ready \u2022 $catalogBrochureCount source categories');

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _CompactMarketHeroShowcase(
              isTr: isTr,
              usesOfficialSource: usesOfficialSource,
              totalItems: allItems.length,
              categoryCount: catalogBrochureCount,
              selectedMarketCount:
                  provider.smartKitchenPreferences.preferredMarkets.length,
              locationLabel: marketFiyatiLocationLabel,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _MarketSearchOverviewCard(
              isTr: isTr,
              summaryLabel: summaryLabel,
              isSyncing: isSyncing,
              catalogSyncAt: catalogSyncAt,
              marketFiyatiLocationLabel: marketFiyatiLocationLabel,
              controller: _searchController,
              onSearch: _runSearchQuery,
              onSearchChanged: _onSearchChanged,
              isSearching: _isApplyingFilters &&
                  _searchController.text.trim().isNotEmpty,
              hasActiveCategory: activeCategory != null,
              activeCategoryLabel: activeCategory?.labelTr,
              isSearchLocked: activeCategory != null,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _ShowcaseLocationSessionCard(
              isTr: isTr,
              locationLabel: marketFiyatiLocationLabel,
              onTap: () => _showLocationPicker(
                context,
                provider: provider,
                isTr: isTr,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _CompactMarketSelectorCard(
              isTr: isTr,
              provider: provider,
              enabled: hasLocation,
              onOpenMarkets: () => _showMarketSelectorSheet(
                context,
                provider: provider,
                isTr: isTr,
              ),
              onChooseLocation: () => _showLocationPicker(
                context,
                provider: provider,
                isTr: isTr,
              ),
            ),
          ),
        ),
        if (displayCategories.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _ShowcaseSectionCard(
                title: isTr ? 'Kategori Se\u00E7imi' : 'Categories',
                subtitle: isTr
                    ? (_searchQuery.isNotEmpty
                        ? 'Arama a\u00E7\u0131kken kategori kapal\u0131 kal\u0131r. Kategori se\u00E7ersen arama temizlenir.'
                        : '\u00D6nce hangi rafta gezmek istedi\u011Fini se\u00E7.')
                    : 'Choose which shelf you want to browse first.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (activeCategory != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceTint,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              activeCategory.icon,
                              size: 18,
                              color: AppTheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isTr
                                    ? 'A\u00E7\u0131k kategori: ${activeCategory.labelTr}'
                                    : 'Active category: ${activeCategory.labelEn}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _runDisplayCategoryFilter(null),
                              child: Text(isTr ? 'Temizle' : 'Clear'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      height: 142,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: displayCategories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final category = displayCategories[index];
                          final count = displayCategoryCounts[category.id] ?? 0;
                          final canOpenCategory =
                              category.fallbackOfficialCategories.isNotEmpty;
                          return SizedBox(
                            width: 118,
                            child: _ShowcaseDisplayCategoryTileCard(
                              category: category,
                              count: count,
                              isSelected:
                                  _selectedDisplayCategoryId == category.id,
                              isEnabled: canOpenCategory,
                              isTr: isTr,
                              onTap: !canOpenCategory
                                  ? null
                                  : () => _runDisplayCategoryFilter(
                                        _selectedDisplayCategoryId ==
                                                category.id
                                            ? null
                                            : category.id,
                                      ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_recentViewedItems.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _ShowcaseSectionCard(
                title: isTr ? 'Son Gezdiklerin' : 'Recently Viewed',
                subtitle: isTr
                    ? 'Kar\u015F\u0131la\u015Ft\u0131rd\u0131\u011F\u0131n \u00FCr\u00FCnlere buradan h\u0131zl\u0131ca d\u00F6n.'
                    : 'Jump back into products you already compared.',
                child: SizedBox(
                  height: 148,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _recentViewedItems.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final item = _recentViewedItems[index];
                      return _RecentViewedCard(
                        item: item,
                        isTr: isTr,
                        onTap: () => _openComparisonForItem(
                          context,
                          provider: provider,
                          item: item,
                          isTr: isTr,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        if (_isApplyingFilters)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(strokeWidth: 2.6),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _filterStatusLabel ?? '\u00DCr\u00FCnler Getiriliyor',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (!hasActiveProductFilter)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              child: _ShowcaseSectionCard(
                title: isTr ? '\u00DCr\u00FCnleri A\u00E7' : 'Open products',
                subtitle: isTr
                    ? 'Konum ve marketler haz\u0131r. Kategori se\u00E7 ya da \u00FCr\u00FCn ara; \u00FCr\u00FCnleri o zaman g\u00F6sterelim.'
                    : 'Location and stores are ready. Pick a category or search for a product to open the list.',
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.warmSurface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: AppTheme.heroGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isSyncing
                              ? (isTr
                                  ? 'Yak\u0131ndaki marketlerden \u00FCr\u00FCnleri haz\u0131rl\u0131yoruz. Biter bitmez kategori veya aramayla filtreleyebilirsin.'
                                  : 'We are preparing products from nearby markets. Filter them as soon as sync finishes.')
                              : (isTr
                                  ? '\u00DCr\u00FCnler haz\u0131r. \u015Eimdi kategori se\u00E7 veya \u00FCr\u00FCn ara.'
                                  : 'Products are ready. Pick a category or search now.'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        else if (filteredItems.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  isTr
                      ? 'Bu filtreyle e\u015Fle\u015Fen \u00FCr\u00FCn yok.'
                      : 'No products match this filter.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isTr ? '\u00DCr\u00FCnler' : 'Products',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    _SearchMetaChip(
                      icon: Icons.search_rounded,
                      label: '"$_searchQuery" i\u00E7in arama',
                      accent: true,
                    ),
                  if (activeCategory != null)
                    _SearchMetaChip(
                      icon: activeCategory.icon,
                      label: activeCategory.labelTr,
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = filteredItems[index];
                  final shoppingEntry = _shoppingListEntryForItem(
                    provider,
                    item,
                  );
                  return _ShowcaseProductCard(
                    item: item,
                    isTr: isTr,
                    isInShoppingList: shoppingEntry != null,
                    onToggleShoppingList: () => _toggleItemInShoppingList(
                      context,
                      provider: provider,
                      item: item,
                      isTr: isTr,
                    ),
                    onCompare: () => _openComparisonForItem(
                      context,
                      provider: provider,
                      item: item,
                      isTr: isTr,
                    ),
                  );
                },
                childCount: filteredItems.length,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showMarketComparison(
    BuildContext context, {
    required ActuellerCatalogItem item,
    required bool isTr,
  }) async {
    final provider = context.read<AppProvider>();
    var comparisonSourceLabel = isTr
        ? 'Yaln\u0131zca g\u00FCvenilir ayn\u0131 \u00FCr\u00FCn e\u015Fle\u015Fmeleri g\u00F6sterilir'
        : 'Only reliable same-product matches are shown';
    var marketMatches = <_CompareEntry>[];
    var officialLookupCompleted = false;

    if (item.sourceProductId != null && provider.marketFiyatiSession != null) {
      try {
        final officialItems = await provider.fetchOfficialSimilarProducts(item);
        officialLookupCompleted = true;
        marketMatches = _buildOfficialCompareEntries(
          base: item,
          candidates: officialItems,
        );
        if (marketMatches.isNotEmpty) {
          comparisonSourceLabel =
              isTr ? 'Resm\u00EE market verisi' : 'Official market data';
        }
      } catch (_) {
        // Keep the sheet usable even if the official lookup fails.
      }
    }

    if (marketMatches.isEmpty && officialLookupCompleted) {
      comparisonSourceLabel = isTr
          ? 'Resm\u00EE veride g\u00FCvenilir e\u015Fle\u015Fme bulunamad\u0131'
          : 'No reliable official match was found';
    }

    // Fallback: bro•r verileri aras•nda •r•n ad• + gramaj e•le•tirmesi
    if (marketMatches.isEmpty) {
      final scanResult = provider.lastActuellerScanResult;
      final allCatalog = scanResult?.catalogItems ?? [];
      if (allCatalog.isNotEmpty) {
        final brochureMatches = _buildBrochureCompareEntries(
          base: item,
          allItems: allCatalog,
        );
        if (brochureMatches.isNotEmpty) {
          marketMatches = brochureMatches;
          comparisonSourceLabel = isTr
              ? 'Bro\u015F\u00FCr verisi kar\u015F\u0131la\u015Ft\u0131rmas\u0131'
              : 'Brochure data comparison';
        }
      }
    }

    if (!context.mounted) return;

    final allCompareItems = <_CompareEntry>[
      _CompareEntry(
        item: item,
        marketName: item.marketName,
        productTitle: item.productTitle,
        price: item.price,
        weight: item.weight,
        isCurrent: true,
      ),
      ...marketMatches,
    ];

    final cheapestPrice = allCompareItems
        .map((entry) => entry.price)
        .reduce((best, price) => price < best ? price : best);

    final theme = Theme.of(context);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        var selectedShoppingItem = item;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final selectedMarketLabel =
                displayNameForMarket(selectedShoppingItem.marketName)
                        .trim()
                        .isNotEmpty
                    ? displayNameForMarket(selectedShoppingItem.marketName)
                        .trim()
                    : repairTurkishText(selectedShoppingItem.marketName).trim();
            final seededAlternatives = allCompareItems
                .where((entry) => entry.item.id != selectedShoppingItem.id)
                .map((entry) => entry.item)
                .toList();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.outlineVariant,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isTr
                              ? 'Market Kar\u015F\u0131la\u015Ft\u0131rma'
                              : 'Price Comparison',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _displayCatalogTitle(item.productTitle, item.weight),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          comparisonSourceLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () async {
                              Navigator.of(sheetContext).pop();
                              await _addItemToShoppingList(
                                context,
                                provider: provider,
                                item: selectedShoppingItem,
                                seededAlternatives: seededAlternatives,
                                isTr: isTr,
                              );
                            },
                            icon: const Icon(Icons.playlist_add_rounded),
                            label: const Text(
                                'Se\u00E7ti\u011Fim \u00DCr\u00FCn\u00FC Ekle'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isTr
                              ? '\u015Eu an se\u00E7ilen market: $selectedMarketLabel'
                              : 'Selected store: $selectedMarketLabel',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (marketMatches.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            isTr
                                ? 'Listeye eklemek istedi\u011Fin market \u00FCr\u00FCn\u00FCn sat\u0131r\u0131na dokun.'
                                : 'Tap the store row you want to add to the shopping list.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (marketMatches.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Text(
                                isTr
                                    ? 'Bu \u00FCr\u00FCn i\u00E7in di\u011Fer marketlerde benzer \u00FCr\u00FCn bulunamad\u0131. Daha fazla market se\u00E7ersen kar\u015F\u0131la\u015Ft\u0131rma \u015Fans\u0131n artar.'
                                    : 'No similar product found in other stores. Selecting more stores improves match chances.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            )
                          else
                            ...allCompareItems.map(
                              (entry) => _ComparisonRow(
                                marketName: entry.marketName,
                                productTitle: entry.productTitle,
                                price: entry.price,
                                weight: entry.weight,
                                isCurrent: entry.isCurrent,
                                isCheapest: entry.price <= cheapestPrice,
                                isSelected:
                                    entry.item.id == selectedShoppingItem.id,
                                onTap: () {
                                  setSheetState(() {
                                    selectedShoppingItem = entry.item;
                                  });
                                },
                                theme: theme,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Bro•r verilerinden •r•n ana ad• + gramaj e•le•tirmesi.
  /// Marka farkl• olabilir: "Ekin Beyaz Peynir 500gr" • "Simge Beyaz Peynir 500gr"
  List<ActuellerCatalogItem> _buildShoppingBrochureAlternatives({
    required ActuellerCatalogItem base,
    required List<ActuellerCatalogItem> allItems,
  }) {
    final baseMarketId =
        normalizeMarketId(base.marketName) ?? base.marketName.toLowerCase();
    final baseCoreTokens = _extractProductCoreNameTokens(base);
    final baseMeasure = _parseComparableMeasure(base);

    if (baseCoreTokens.isEmpty) return [];

    final bestByMarket = <String, ({ActuellerCatalogItem item, int score})>{};

    for (final candidate in allItems) {
      if (candidate.id == base.id) continue;

      final candidateMarketId = normalizeMarketId(candidate.marketName) ??
          candidate.marketName.toLowerCase();
      if (candidateMarketId == baseMarketId) continue;

      final candidateMeasure = _parseComparableMeasure(candidate);
      final measCompat =
          _measureCompatibility(base: base, candidate: candidate);
      if (measCompat == _MeasureCompatibility.mismatch) continue;

      final candidateCoreTokens = _extractProductCoreNameTokens(candidate);
      if (candidateCoreTokens.isEmpty) continue;

      final coreOverlap = baseCoreTokens.intersection(candidateCoreTokens);
      final distinctiveOverlap = coreOverlap
          .where((token) => !_genericBrochureCoreTokens.contains(token))
          .toSet();
      final minCoreCount = baseCoreTokens.length < candidateCoreTokens.length
          ? baseCoreTokens.length
          : candidateCoreTokens.length;

      final sameMeasure = measCompat == _MeasureCompatibility.exact ||
          measCompat == _MeasureCompatibility.close;
      final hasMeasure = baseMeasure != null && candidateMeasure != null;

      if (coreOverlap.isEmpty) continue;

      final bool acceptable;
      if (hasMeasure && sameMeasure && distinctiveOverlap.isNotEmpty) {
        acceptable = true;
      } else if (coreOverlap.length >= 2 && minCoreCount <= 3) {
        acceptable = true;
      } else if (coreOverlap.length >= 2 &&
          coreOverlap.length / minCoreCount >= 0.6) {
        acceptable = true;
      } else {
        acceptable = false;
      }

      if (!acceptable) continue;

      var score = coreOverlap.length * 10;
      if (sameMeasure) score += 20;
      if (hasMeasure && measCompat == _MeasureCompatibility.exact) {
        score += 10;
      }
      if (candidate.category == base.category) score += 6;

      final previous = bestByMarket[candidateMarketId];
      if (previous == null ||
          score > previous.score ||
          (score == previous.score && candidate.price < previous.item.price)) {
        bestByMarket[candidateMarketId] = (item: candidate, score: score);
      }
    }

    return bestByMarket.values.map((match) => match.item).toList()
      ..sort((a, b) => a.price.compareTo(b.price));
  }

  List<ActuellerCatalogItem> _buildShoppingOfficialAlternatives({
    required ActuellerCatalogItem base,
    required List<ActuellerCatalogItem> candidates,
  }) {
    final currentMarketId =
        normalizeMarketId(base.marketName) ?? base.marketName.toLowerCase();
    final bestByMarket = <String, ({ActuellerCatalogItem item, int score})>{};

    for (final candidate in candidates) {
      final candidateMarketId = normalizeMarketId(candidate.marketName) ??
          candidate.marketName.toLowerCase();
      if (candidateMarketId == currentMarketId) {
        continue;
      }
      if (base.sourceDepotId != null &&
          candidate.sourceDepotId == base.sourceDepotId) {
        continue;
      }
      final score = _officialCrossMarketMatchScore(
        base: base,
        candidate: candidate,
      );
      if (score < 0) {
        continue;
      }

      final previous = bestByMarket[candidateMarketId];
      if (previous == null ||
          score > previous.score ||
          (score == previous.score && candidate.price < previous.item.price)) {
        bestByMarket[candidateMarketId] = (item: candidate, score: score);
      }
    }

    return bestByMarket.values.map((match) => match.item).toList()
      ..sort((a, b) => a.price.compareTo(b.price));
  }

  List<_CompareEntry> _buildBrochureCompareEntries({
    required ActuellerCatalogItem base,
    required List<ActuellerCatalogItem> allItems,
  }) {
    final baseMarketId =
        normalizeMarketId(base.marketName) ?? base.marketName.toLowerCase();
    final baseCoreTokens = _extractProductCoreNameTokens(base);
    final baseMeasure = _parseComparableMeasure(base);

    if (baseCoreTokens.isEmpty) return [];

    final bestByMarket = <String, ({ActuellerCatalogItem item, int score})>{};

    for (final candidate in allItems) {
      if (candidate.id == base.id) continue;

      final candidateMarketId = normalizeMarketId(candidate.marketName) ??
          candidate.marketName.toLowerCase();
      if (candidateMarketId == baseMarketId) continue;

      // Measure must be compatible (exact or close)
      final candidateMeasure = _parseComparableMeasure(candidate);
      final measCompat =
          _measureCompatibility(base: base, candidate: candidate);
      if (measCompat == _MeasureCompatibility.mismatch) continue;

      // Core product name tokens (without brand & stop words) must overlap enough
      final candidateCoreTokens = _extractProductCoreNameTokens(candidate);
      if (candidateCoreTokens.isEmpty) continue;

      final coreOverlap = baseCoreTokens.intersection(candidateCoreTokens);
      final distinctiveOverlap = coreOverlap
          .where((token) => !_genericBrochureCoreTokens.contains(token))
          .toSet();
      final minCoreCount = baseCoreTokens.length < candidateCoreTokens.length
          ? baseCoreTokens.length
          : candidateCoreTokens.length;

      // Need at least 1 distinctive token + same measure, or 2+ core token matches
      final sameMeasure = measCompat == _MeasureCompatibility.exact ||
          measCompat == _MeasureCompatibility.close;
      final hasMeasure = baseMeasure != null && candidateMeasure != null;

      if (coreOverlap.isEmpty) continue;

      final bool acceptable;
      if (hasMeasure && sameMeasure && distinctiveOverlap.isNotEmpty) {
        acceptable = true;
      } else if (coreOverlap.length >= 2 && minCoreCount <= 3) {
        acceptable = true;
      } else if (coreOverlap.length >= 2 &&
          coreOverlap.length / minCoreCount >= 0.6) {
        acceptable = true;
      } else {
        acceptable = false;
      }

      if (!acceptable) continue;

      var score = coreOverlap.length * 10;
      if (sameMeasure) score += 20;
      if (hasMeasure && measCompat == _MeasureCompatibility.exact) {
        score += 10;
      }
      if (candidate.category == base.category) score += 6;

      final previous = bestByMarket[candidateMarketId];
      if (previous == null ||
          score > previous.score ||
          (score == previous.score && candidate.price < previous.item.price)) {
        bestByMarket[candidateMarketId] = (item: candidate, score: score);
      }
    }

    return bestByMarket.values
        .map(
          (match) => _CompareEntry(
            item: match.item,
            marketName: match.item.marketName,
            productTitle: match.item.productTitle,
            price: match.item.price,
            weight: match.item.weight,
            isCurrent: false,
          ),
        )
        .toList()
      ..sort((a, b) => a.price.compareTo(b.price));
  }

  /// •r•n ba•l•ndan marka ve birim bilgilerini •kar•p sadece
  /// •r•n t•r•n• belirleyen "•ekirdek" kelimeleri d•nd•r•r.
  /// •r: "Ekin Beyaz Peynir 500 gr" • {"beyaz", "peynir"}
  Set<String> _extractProductCoreNameTokens(ActuellerCatalogItem item) {
    final title = _normalizeMarketCompareValue(item.productTitle);
    final brandTokens = _normalizeMarketCompareValue(item.brand ?? '')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2)
        .toSet();

    // Remove brand tokens, unit tokens, and pure numbers
    return title
        .split(RegExp(r'\s+'))
        .where((token) =>
            token.length >= 2 &&
            !brandTokens.contains(token) &&
            !_marketCompareStopWords.contains(token) &&
            !_officialCompareSoftStopWords.contains(token) &&
            !_brochureCoreStopWords.contains(token) &&
            !RegExp(r'^\d+$').hasMatch(token))
        .toSet();
  }

  List<_CompareEntry> _buildOfficialCompareEntries({
    required ActuellerCatalogItem base,
    required List<ActuellerCatalogItem> candidates,
  }) {
    final currentMarketId =
        normalizeMarketId(base.marketName) ?? base.marketName.toLowerCase();
    final bestByMarket = <String, ({ActuellerCatalogItem item, int score})>{};

    for (final candidate in candidates) {
      final candidateMarketId = normalizeMarketId(candidate.marketName) ??
          candidate.marketName.toLowerCase();
      if (candidateMarketId == currentMarketId) {
        continue;
      }
      if (base.sourceDepotId != null &&
          candidate.sourceDepotId == base.sourceDepotId) {
        continue;
      }
      final score = _officialCrossMarketMatchScore(
        base: base,
        candidate: candidate,
      );
      if (score < 0) {
        continue;
      }

      final previous = bestByMarket[candidateMarketId];
      if (previous == null ||
          score > previous.score ||
          (score == previous.score && candidate.price < previous.item.price)) {
        bestByMarket[candidateMarketId] = (item: candidate, score: score);
      }
    }

    return bestByMarket.values
        .map(
          (match) => _CompareEntry(
            item: match.item,
            marketName: match.item.marketName,
            productTitle: match.item.productTitle,
            price: match.item.price,
            weight: match.item.weight,
            isCurrent: false,
          ),
        )
        .toList()
      ..sort((a, b) => a.price.compareTo(b.price));
  }

  int _officialCrossMarketMatchScore({
    required ActuellerCatalogItem base,
    required ActuellerCatalogItem candidate,
  }) {
    final baseTitle = _normalizeMarketCompareValue(base.productTitle);
    final candidateTitle = _normalizeMarketCompareValue(candidate.productTitle);
    final baseBrand = _normalizeMarketCompareValue(base.brand ?? '');
    final candidateBrand = _normalizeMarketCompareValue(candidate.brand ?? '');
    final genericScore =
        _crossMarketMatchScore(base: base, candidate: candidate);
    final overlap = _extractMarketCompareTokens(base)
        .intersection(_extractMarketCompareTokens(candidate));
    final baseCoreTokens = _extractOfficialCoreTokens(base);
    final candidateCoreTokens = _extractOfficialCoreTokens(candidate);
    final coreOverlap = baseCoreTokens.intersection(candidateCoreTokens);
    final distinctiveCoreOverlap = coreOverlap
        .where((token) => !_genericBrochureCoreTokens.contains(token))
        .toSet();
    final exactTitle = baseTitle == candidateTitle;
    final sameBrand = baseBrand.isNotEmpty &&
        candidateBrand.isNotEmpty &&
        baseBrand == candidateBrand;
    final hasModelToken = overlap.any(_isProductModelToken);
    final hasMeaningfulSingleCoreToken =
        coreOverlap.length == 1 && coreOverlap.first.length >= 4;
    final minCoreCount = baseCoreTokens.length < candidateCoreTokens.length
        ? baseCoreTokens.length
        : candidateCoreTokens.length;
    final coreSimilarity =
        minCoreCount == 0 ? 0 : coreOverlap.length / minCoreCount;
    final measureCompatibility =
        _measureCompatibility(base: base, candidate: candidate);
    final sameMeasure = measureCompatibility == _MeasureCompatibility.exact ||
        measureCompatibility == _MeasureCompatibility.close;

    if (base.sourceProductId != null &&
        candidate.sourceProductId != null &&
        base.sourceProductId == candidate.sourceProductId) {
      return 100;
    }

    if (measureCompatibility == _MeasureCompatibility.mismatch) {
      return -1;
    }

    if (exactTitle) {
      return 90 + (genericScore < 0 ? 0 : genericScore);
    }

    if (genericScore < 0 && !hasModelToken) {
      return -1;
    }

    if (hasModelToken && sameMeasure) {
      return 78 + (genericScore < 0 ? 0 : genericScore);
    }

    if (sameMeasure &&
        hasMeaningfulSingleCoreToken &&
        (baseCoreTokens.length == 1 || candidateCoreTokens.length == 1)) {
      return 72 + (genericScore < 0 ? 0 : genericScore);
    }

    if (sameMeasure && distinctiveCoreOverlap.isNotEmpty) {
      return 68 + (genericScore < 0 ? 0 : genericScore);
    }

    if (sameBrand && sameMeasure && coreOverlap.isNotEmpty) {
      return 70 + (genericScore < 0 ? 0 : genericScore);
    }

    if (coreOverlap.length >= 2 && coreSimilarity >= 0.5) {
      return 64 + (genericScore < 0 ? 0 : genericScore);
    }

    if (sameBrand && coreOverlap.length >= 2) {
      return 60 + (genericScore < 0 ? 0 : genericScore);
    }

    if (sameMeasure && coreOverlap.length >= 2) {
      return 56 + (genericScore < 0 ? 0 : genericScore);
    }

    return -1;
  }

  int _crossMarketMatchScore({
    required ActuellerCatalogItem base,
    required ActuellerCatalogItem candidate,
  }) {
    if (candidate.id == base.id) return -1;
    if (candidate.marketName == base.marketName) return -1;

    final baseTitle = _normalizeMarketCompareValue(base.productTitle);
    final candidateTitle = _normalizeMarketCompareValue(candidate.productTitle);
    final baseBrand = _normalizeMarketCompareValue(base.brand ?? '');
    final candidateBrand = _normalizeMarketCompareValue(candidate.brand ?? '');
    final baseTokens = _extractMarketCompareTokens(base);
    final candidateTokens = _extractMarketCompareTokens(candidate);
    final overlap = baseTokens.intersection(candidateTokens);
    final sameCategory = candidate.category == base.category;
    final sameBrand = baseBrand.isNotEmpty &&
        candidateBrand.isNotEmpty &&
        baseBrand == candidateBrand;
    final exactTitle = baseTitle == candidateTitle;
    final hasModelToken = overlap.any(_isProductModelToken);
    final measureCompatibility =
        _measureCompatibility(base: base, candidate: candidate);
    final sameMeasure = measureCompatibility == _MeasureCompatibility.exact ||
        measureCompatibility == _MeasureCompatibility.close;

    if (measureCompatibility == _MeasureCompatibility.mismatch) {
      return -1;
    }

    final hasStrongMatch = exactTitle ||
        hasModelToken ||
        (sameBrand && overlap.length >= 2) ||
        overlap.length >= 3 ||
        (sameMeasure && overlap.length >= 2);
    if (!hasStrongMatch) {
      return -1;
    }

    var score = overlap.length;
    if (sameBrand) score += 3;
    if (sameMeasure) score += 2;
    if (exactTitle) score += 4;
    if (hasModelToken) score += 5;
    if (sameCategory) score += 1;
    return score;
  }

  Set<String> _extractMarketCompareTokens(ActuellerCatalogItem item) {
    final combined = [item.brand ?? '', item.productTitle, item.weight ?? '']
        .join(' \u2022 ');
    return _normalizeMarketCompareValue(combined)
        .split(RegExp(r'\s+'))
        .where(
          (token) =>
              token.length >= 2 && !_marketCompareStopWords.contains(token),
        )
        .toSet();
  }

  Set<String> _extractOfficialCoreTokens(ActuellerCatalogItem item) {
    final brandTokens = _normalizeMarketCompareValue(item.brand ?? '')
        .split(RegExp(r'\s+'))
        .where((token) => token.length >= 2)
        .toSet();
    return _extractMarketCompareTokens(item)
        .where(
          (token) =>
              !brandTokens.contains(token) &&
              !_officialCompareSoftStopWords.contains(token) &&
              !RegExp(r'^\d+$').hasMatch(token),
        )
        .toSet();
  }

  String _normalizeMarketCompareValue(String value) {
    return repairTurkishText(value)
        .toLowerCase()
        .replaceAll('\u00E7', 'c')
        .replaceAll('\u011F', 'g')
        .replaceAll('\u0131', 'i')
        .replaceAll('\u00F6', 'o')
        .replaceAll('\u015F', 's')
        .replaceAll('\u00FC', 'u')
        .replaceAll('\u00C7', 'c')
        .replaceAll('\u011E', 'g')
        .replaceAll('\u0130', 'i')
        .replaceAll('\u00D6', 'o')
        .replaceAll('\u015E', 's')
        .replaceAll('\u00DC', 'u')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  bool _isProductModelToken(String token) {
    return RegExp(r'[a-z]+\d', caseSensitive: false).hasMatch(token) ||
        RegExp(r'\d+[a-z]', caseSensitive: false).hasMatch(token) ||
        RegExp(r'^\d{4,}$').hasMatch(token);
  }

  _MeasureCompatibility _measureCompatibility({
    required ActuellerCatalogItem base,
    required ActuellerCatalogItem candidate,
  }) {
    final baseMeasure = _parseComparableMeasure(base);
    final candidateMeasure = _parseComparableMeasure(candidate);

    if (baseMeasure == null || candidateMeasure == null) {
      return _MeasureCompatibility.unknown;
    }

    if (baseMeasure.kind != candidateMeasure.kind) {
      return _MeasureCompatibility.mismatch;
    }

    if (baseMeasure.kind == _ComparableMeasureKind.count) {
      return (baseMeasure.value - candidateMeasure.value).abs() < 0.01
          ? _MeasureCompatibility.exact
          : _MeasureCompatibility.mismatch;
    }

    final maxValue = baseMeasure.value > candidateMeasure.value
        ? baseMeasure.value
        : candidateMeasure.value;
    if (maxValue <= 0) {
      return _MeasureCompatibility.unknown;
    }

    final ratio = (baseMeasure.value - candidateMeasure.value).abs() / maxValue;
    if (ratio <= 0.03) {
      return _MeasureCompatibility.exact;
    }
    if (ratio <= 0.08) {
      return _MeasureCompatibility.close;
    }
    return _MeasureCompatibility.mismatch;
  }

  _ComparableMeasure? _parseComparableMeasure(ActuellerCatalogItem item) {
    final source = repairTurkishText(
      [item.weight ?? '', item.productTitle]
          .where((part) => part.isNotEmpty)
          .join(' '),
    ).toLowerCase();

    final asciiSource = source
        .replaceAll('\u00E7', 'c')
        .replaceAll('\u011F', 'g')
        .replaceAll('\u0131', 'i')
        .replaceAll('\u00F6', 'o')
        .replaceAll('\u015F', 's')
        .replaceAll('\u00FC', 'u');

    final countPackMatch = RegExp(
            r"(\d+(?:[.,]\d+)?)\s*['•]?(li|lu)\b")
        .firstMatch(asciiSource);
    if (countPackMatch != null) {
      return _ComparableMeasure(
        kind: _ComparableMeasureKind.count,
        value: _parseMeasureNumber(countPackMatch.group(1)!),
      );
    }

    final countMatch =
        RegExp(r'(\d+(?:[.,]\d+)?)\s*(adet|ad)\b').firstMatch(asciiSource);
    if (countMatch != null) {
      return _ComparableMeasure(
        kind: _ComparableMeasureKind.count,
        value: _parseMeasureNumber(countMatch.group(1)!),
      );
    }

    final weightMatch =
        RegExp(r'(\d+(?:[.,]\d+)?)\s*(kg|gr|g)\b').firstMatch(asciiSource);
    if (weightMatch != null) {
      final value = _parseMeasureNumber(weightMatch.group(1)!);
      final unit = weightMatch.group(2)!;
      return _ComparableMeasure(
        kind: _ComparableMeasureKind.weight,
        value: unit == 'kg' ? value * 1000 : value,
      );
    }

    final volumeMatch =
        RegExp(r'(\d+(?:[.,]\d+)?)\s*(lt|l|ml)\b').firstMatch(asciiSource);
    if (volumeMatch != null) {
      final value = _parseMeasureNumber(volumeMatch.group(1)!);
      final unit = volumeMatch.group(2)!;
      return _ComparableMeasure(
        kind: _ComparableMeasureKind.volume,
        value: unit == 'ml' ? value : value * 1000,
      );
    }

    return null;
  }

  double _parseMeasureNumber(String raw) {
    return double.tryParse(raw.replaceAll(',', '.')) ?? 0;
  }
}

const _marketCompareStopWords = {
  'erkek',
  'kadin',
  'cocuk',
  'spor',
  'ayakkabi',
  'terlik',
  'gri',
  'siyah',
  'lacivert',
  'mavi',
  'kirmizi',
  'yesil',
  'adet',
  'paket',
  'gr',
  'g',
  'kg',
  'ml',
  'lt',
  'cm',
};

const _officialCompareSoftStopWords = {
  'meyve',
  'sebze',
  'urun',
  'urunu',
  'urunleri',
  'temizlik',
  'adet',
  'paket',
  'gr',
  'g',
  'kg',
  'ml',
  'lt',
  'klasik',
  'normal',
  'ultra',
};

const _brochureCoreStopWords = {
  'x',
  'li',
  'lu',
  'lik',
  'luk',
  'ozel',
  'super',
  'extra',
  'yeni',
  'taze',
  'dogal',
  'ekonomik',
  'buyuk',
  'kucuk',
  'orta',
  'mini',
  'indirimli',
  'kampanyali',
  'firsat',
  'avantajli',
};

const _genericBrochureCoreTokens = {
  'urun',
  'urunleri',
  'gida',
  'market',
  'sivi',
  'tam',
  'yarim',
  'klasik',
  'dogal',
  'peynir',
  'sut',
  'yogurt',
  'sabun',
  'makarna',
};

// •
//  WIDGETS
// •

class _FilterChipWidget extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChipWidget({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ActuellerCatalogItem item;
  final bool isTr;
  final VoidCallback onCompare;

  const _ProductCard({
    required this.item,
    required this.isTr,
    required this.onCompare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final marketDisplay = displayNameForMarket(item.marketName);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onCompare,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              // Left: product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Market badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        marketDisplay.isEmpty ? item.marketName : marketDisplay,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Product title
                    Text(
                      _displayCatalogTitle(item.productTitle, item.weight),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Details row: brand • weight • category
                    Row(
                      children: [
                        if (item.brand != null) ...[
                          Text(
                            item.brand!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (item.weight != null)
                            Text(
                              ' \u2022 ',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                        ],
                        if (_shouldShowSeparateWeight(
                          item.productTitle,
                          item.weight,
                        ))
                          Text(
                            item.weight!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right: price + compare button
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatPrice(item.price),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    'TL',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Market Kar\u015F\u0131la\u015Ft\u0131r',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.secondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price == price.roundToDouble()) {
      return price.toStringAsFixed(0);
    }
    return price.toStringAsFixed(2).replaceAll('.', ',');
  }
}

class _MarketBrowseCategory {
  final String id;
  final String labelTr;
  final String labelEn;
  final String shortLabelTr;
  final String shortLabelEn;
  final IconData icon;
  final List<String> keywords;
  final List<String> fallbackOfficialCategories;

  const _MarketBrowseCategory({
    required this.id,
    required this.labelTr,
    required this.labelEn,
    required this.shortLabelTr,
    required this.shortLabelEn,
    required this.icon,
    required this.keywords,
    this.fallbackOfficialCategories = const [],
  });
}

const _marketBrowseCategories = [
  _MarketBrowseCategory(
    id: 'meyve-sebze',
    labelTr: 'Meyve & Sebze',
    labelEn: 'Fruit & Veg',
    shortLabelTr: 'Meyve\nSebze',
    shortLabelEn: 'Fruit\nVeg',
    icon: Icons.eco_rounded,
    keywords: ['meyve', 'sebze', 'domates', 'salatalik', 'patates', 'muz'],
    fallbackOfficialCategories: ['Meyve', 'Sebze'],
  ),
  _MarketBrowseCategory(
    id: 'sut-urunleri',
    labelTr: 'S\u00FCt \u00DCr\u00FCnleri',
    labelEn: 'Dairy',
    shortLabelTr: 'S\u00FCt\n\u00DCr\u00FCnleri',
    shortLabelEn: 'Dairy',
    icon: Icons.local_drink_rounded,
    keywords: [
      'sut',
      'peynir',
      'yogurt',
      'ayran',
      'kefir',
      'labne',
      'tereyag',
      'lor',
      'krema',
      'kasar',
    ],
    fallbackOfficialCategories: [
      'S\u00FCt',
      'Peynir',
      'Yo\u011Furt',
      'Kaymak ve Krema',
      'Tereya\u011F\u0131 ve Margarin',
    ],
  ),
  _MarketBrowseCategory(
    id: 'kahvaltilik',
    labelTr: 'Kahvalt\u0131l\u0131k',
    labelEn: 'Breakfast',
    shortLabelTr: 'Kahvalt\u0131',
    shortLabelEn: 'Breakfast',
    icon: Icons.egg_alt_rounded,
    keywords: [
      'yumurta',
      'zeytin',
      'bal',
      'recel',
      'pekmez',
      'tahin',
      'gevrek',
      'cornflakes',
      'salam',
      'sucuk',
      'sosis',
    ],
    fallbackOfficialCategories: [
      'Yumurta',
      'Zeytin',
      'S\u00FCr\u00FClebilir \u00DCr\u00FCnler ve Kahvalt\u0131l\u0131k Soslar',
      'Helva Tahin ve Pekmez',
      'Bal ve Re\u00E7el',
      'Kahvalt\u0131l\u0131k Gevrek Bar ve Granola',
    ],
  ),
  _MarketBrowseCategory(
    id: 'firindan',
    labelTr: 'F\u0131r\u0131ndan',
    labelEn: 'Bakery',
    shortLabelTr: 'F\u0131r\u0131ndan',
    shortLabelEn: 'Bakery',
    icon: Icons.bakery_dining_rounded,
    keywords: ['ekmek', 'simit', 'pogaca', 'borek', 'lavas', 'bazlama'],
    fallbackOfficialCategories: ['Ekmek ve Unlu Mam\u00FCller'],
  ),
  _MarketBrowseCategory(
    id: 'atistirmalik',
    labelTr: 'At\u0131\u015Ft\u0131rmal\u0131k',
    labelEn: 'Snacks',
    shortLabelTr: 'At\u0131\u015Ft\u0131r',
    shortLabelEn: 'Snacks',
    icon: Icons.cookie_rounded,
    keywords: ['cips', 'kraker', 'gofret', 'cikolata', 'biskuvi', 'kuruyemis'],
    fallbackOfficialCategories: [
      '\u00C7ikolata',
      'Gofret',
      'Bisk\u00FCvi ve Kraker',
      'Kek',
      'Cips',
      'Kuruyemi\u015F ve Kuru Meyve',
      'Sak\u0131z ve \u015Eekerleme',
      'Tatl\u0131lar',
    ],
  ),
  _MarketBrowseCategory(
    id: 'su-icecek',
    labelTr: 'Su & \u0130\u00E7ecek',
    labelEn: 'Drinks',
    shortLabelTr: 'Su &\n\u0130\u00E7ecek',
    shortLabelEn: 'Drinks',
    icon: Icons.local_cafe_rounded,
    keywords: [
      'su',
      'icecek',
      'maden suyu',
      'kola',
      'gazoz',
      'meyve suyu',
      'kahve',
      'cay',
    ],
    fallbackOfficialCategories: [
      'Su',
      'Meyve Suyu',
      'Gazl\u0131 \u0130\u00E7ecekler',
      'Gazs\u0131z \u0130\u00E7ecekler',
      'Ayran ve Kefir',
      'Maden Suyu',
      '\u00C7ay ve Bitki \u00C7aylar\u0131',
      'Kahve',
    ],
  ),
  _MarketBrowseCategory(
    id: 'dondurma',
    labelTr: 'Dondurma',
    labelEn: 'Ice Cream',
    shortLabelTr: 'Dondurma',
    shortLabelEn: 'Ice Cream',
    icon: Icons.icecream_rounded,
    keywords: ['dondurma', 'ice cream'],
    fallbackOfficialCategories: ['Dondurmalar'],
  ),
  _MarketBrowseCategory(
    id: 'dondurulmus',
    labelTr: 'Dondurulmu\u015F',
    labelEn: 'Frozen',
    shortLabelTr: 'Dondurul\nmu\u015F',
    shortLabelEn: 'Frozen',
    icon: Icons.ac_unit_rounded,
    keywords: ['dondurulmus', 'donuk', 'buzlu'],
  ),
  _MarketBrowseCategory(
    id: 'temel-gida',
    labelTr: 'Temel G\u0131da',
    labelEn: 'Staples',
    shortLabelTr: 'Temel\nG\u0131da',
    shortLabelEn: 'Staples',
    icon: Icons.grain_rounded,
    keywords: [
      'makarna',
      'pirinc',
      'bulgur',
      'un',
      'bakliyat',
      'mercimek',
      'nohut'
    ],
    fallbackOfficialCategories: [
      'S\u0131v\u0131 Ya\u011Flar',
      'Bakliyat',
      '\u015Eeker ve Tatland\u0131r\u0131c\u0131lar',
      'Pasta Malzemeleri',
      'Un ve \u0130rmik',
      'Mant\u0131 Makarna ve Eri\u015Fte',
      'Ket\u00E7ap Mayonez Sos ve Sirkeler',
      'Tuz Baharat ve Har\u00E7lar',
      'Sal\u00E7a',
      'Tur\u015Fu',
      'Konserve',
    ],
  ),
  _MarketBrowseCategory(
    id: 'pratik-yemek',
    labelTr: 'Pratik Yemek',
    labelEn: 'Ready Meals',
    shortLabelTr: 'Pratik\nYemek',
    shortLabelEn: 'Ready\nMeals',
    icon: Icons.lunch_dining_rounded,
    keywords: ['hazir', 'pizza', 'manti', 'noodle', 'sandvic', 'burger'],
    fallbackOfficialCategories: ['Haz\u0131r G\u0131da'],
  ),
  _MarketBrowseCategory(
    id: 'et-tavuk-balik',
    labelTr: 'Et, Tavuk & Bal\u0131k',
    labelEn: 'Meat & Fish',
    shortLabelTr: 'Et &\nTavuk',
    shortLabelEn: 'Meat &\nFish',
    icon: Icons.set_meal_rounded,
    keywords: ['et', 'tavuk', 'balik', 'kiyma', 'kofte', 'doner', 'hindi'],
    fallbackOfficialCategories: [
      'K\u0131rm\u0131z\u0131 Et',
      'Beyaz Et',
      'Deniz \u00DCr\u00FCnleri',
      '\u015Eark\u00FCteri',
      'Sakatat',
    ],
  ),
  _MarketBrowseCategory(
    id: 'fit-form',
    labelTr: 'Fit & Form',
    labelEn: 'Fit & Form',
    shortLabelTr: 'Fit &\nForm',
    shortLabelEn: 'Fit &\nForm',
    icon: Icons.fitness_center_rounded,
    keywords: ['protein', 'granola', 'yulaf', 'light', 'organik', 'glutensiz'],
    fallbackOfficialCategories: ['Kahvalt\u0131l\u0131k Gevrek Bar ve Granola'],
  ),
  _MarketBrowseCategory(
    id: 'kisisel-bakim',
    labelTr: 'Ki\u015Fisel Bak\u0131m',
    labelEn: 'Personal Care',
    shortLabelTr: 'Ki\u015Fisel\nBak\u0131m',
    shortLabelEn: 'Personal\nCare',
    icon: Icons.spa_rounded,
    keywords: [
      'sampuan',
      'deodorant',
      'dis macunu',
      'dis fircasi',
      'sabun',
      'ped',
      'tiras',
      'bakim',
    ],
    fallbackOfficialCategories: [
      'Sa\u00E7 Bak\u0131m',
      'Du\u015F Banyo ve Sabun',
      'A\u011F\u0131z Bak\u0131m',
      'Hijyenik Ped',
      'Parf\u00FCm Deodorant Kolonya ve Kokular',
      'Cilt Bak\u0131m\u0131',
      'Makyaj',
    ],
  ),
  _MarketBrowseCategory(
    id: 'ev-bakim',
    labelTr: 'Ev Bak\u0131m',
    labelEn: 'Home Care',
    shortLabelTr: 'Ev\nBak\u0131m',
    shortLabelEn: 'Home\nCare',
    icon: Icons.cleaning_services_rounded,
    keywords: [
      'deterjan',
      'camasir',
      'bulasik',
      'temizlik',
      'yumusatici',
      'cop torbasi'
    ],
    fallbackOfficialCategories: [
      'Bula\u015F\u0131k Temizlik \u00DCr\u00FCnleri',
      '\u00C7ama\u015F\u0131r Temizlik \u00DCr\u00FCnleri',
      'Genel Temizlik \u00DCr\u00FCnleri',
      'Mutfak Sarf Malzemeleri',
    ],
  ),
  _MarketBrowseCategory(
    id: 'kagit-urunleri',
    labelTr: 'Ka\u011F\u0131t \u00DCr\u00FCnleri',
    labelEn: 'Paper Goods',
    shortLabelTr: 'Ka\u011F\u0131t\n\u00DCr\u00FCnleri',
    shortLabelEn: 'Paper\nGoods',
    icon: Icons.description_rounded,
    keywords: [
      'pecete',
      'havlu kagit',
      'tuvalet kagidi',
      'islak mendil',
      'mendil'
    ],
    fallbackOfficialCategories: [
      'Tuvalet Ka\u011F\u0131d\u0131',
      'Ka\u011F\u0131t Havlu',
      'Ka\u011F\u0131t Pe\u00E7ete ve Mendil',
      'Islak Mendil',
    ],
  ),
  _MarketBrowseCategory(
    id: 'bebek',
    labelTr: 'Bebek',
    labelEn: 'Baby',
    shortLabelTr: 'Bebek',
    shortLabelEn: 'Baby',
    icon: Icons.child_care_rounded,
    keywords: ['bebek', 'biberon', 'mama', 'bez'],
    fallbackOfficialCategories: ['Bebek Mamalar\u0131', 'Bebek ve Hasta Bezi'],
  ),
  _MarketBrowseCategory(
    id: 'evcil-hayvan',
    labelTr: 'Evcil Hayvan',
    labelEn: 'Pet',
    shortLabelTr: 'Evcil\nHayvan',
    shortLabelEn: 'Pet',
    icon: Icons.pets_rounded,
    keywords: ['kedi', 'kopek', 'mama', 'kum'],
  ),
  _MarketBrowseCategory(
    id: 'ev-yasam',
    labelTr: 'Ev & Ya\u015Fam',
    labelEn: 'Home & Living',
    shortLabelTr: 'Ev &\nYa\u015Fam',
    shortLabelEn: 'Home &\nLiving',
    icon: Icons.home_rounded,
    keywords: [
      'saklama',
      'organizasyon',
      'servis',
      'bardak',
      'tabak',
      'mutfak'
    ],
  ),
  _MarketBrowseCategory(
    id: 'cinsel-saglik',
    labelTr: 'Cinsel Sa\u011Fl\u0131k',
    labelEn: 'Sexual Health',
    shortLabelTr: 'Cinsel\nSa\u011Fl\u0131k',
    shortLabelEn: 'Sexual\nHealth',
    icon: Icons.favorite_outline_rounded,
    keywords: ['prezervatif', 'kayganlastirici', 'kondom'],
  ),
  _MarketBrowseCategory(
    id: 'elektronik',
    labelTr: 'Elektronik',
    labelEn: 'Electronics',
    shortLabelTr: 'Elektronik',
    shortLabelEn: 'Electronics',
    icon: Icons.headphones_rounded,
    keywords: ['pil', 'kulaklik', 'sarj', 'ampul', 'batarya'],
  ),
  _MarketBrowseCategory(
    id: 'diger',
    labelTr: 'Diğer',
    labelEn: 'Other',
    shortLabelTr: 'Diğer',
    shortLabelEn: 'Other',
    icon: Icons.more_horiz_rounded,
    keywords: [],
  ),
];

class _RecentViewedCard extends StatelessWidget {
  final ActuellerCatalogItem item;
  final bool isTr;
  final VoidCallback onTap;

  const _RecentViewedCard({
    required this.item,
    required this.isTr,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final marketDisplay = displayNameForMarket(item.marketName);
    return SizedBox(
      width: 220,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.28),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.55,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  marketDisplay.isEmpty ? item.marketName : marketDisplay,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Text(
                  _displayCatalogTitle(item.productTitle, item.weight),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${_formatCompactPrice(item.price)} TL',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (_shouldShowSeparateWeight(
                item.productTitle,
                item.weight,
              ))
                Text(
                  item.weight!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCompactPrice(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }
}

class _ComparisonRow extends StatelessWidget {
  final String marketName;
  final String productTitle;
  final double price;
  final String? weight;
  final bool isCurrent;
  final bool isCheapest;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  const _ComparisonRow({
    required this.marketName,
    required this.productTitle,
    required this.price,
    required this.weight,
    required this.isCurrent,
    required this.isCheapest,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final display = displayNameForMarket(marketName);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: isSelected ? AppTheme.heroGradient : null,
              color: isSelected
                  ? null
                  : isCurrent
                      ? AppTheme.surfaceTint
                      : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : AppTheme.primary.withValues(alpha: 0.08),
                width: 1,
              ),
              boxShadow: isSelected ? AppTheme.softShadow : AppTheme.cardShadow,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        display.isEmpty ? marketName : display,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : isCheapest
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _displayCatalogTitle(productTitle, weight),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.88)
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_shouldShowSeparateWeight(productTitle, weight))
                        Text(
                          weight!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.72)
                                : theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${price.toStringAsFixed(2).replaceAll('.', ',')} TL',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? Colors.white
                            : isCheapest
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (isSelected)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Se\u00E7ildi',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else if (isCheapest)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF2E7D32).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'En ucuz',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF2E7D32),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompareEntry {
  final ActuellerCatalogItem item;
  final String marketName;
  final String productTitle;
  final double price;
  final String? weight;
  final bool isCurrent;

  const _CompareEntry({
    required this.item,
    required this.marketName,
    required this.productTitle,
    required this.price,
    required this.weight,
    required this.isCurrent,
  });
}

String _displayCatalogTitle(String productTitle, String? weight) {
  final cleanedTitle = _collapseRepeatedMeasurePhrases(
    repairTurkishText(productTitle).trim(),
  );
  final cleanedWeight = repairTurkishText(weight ?? '').trim();
  if (cleanedWeight.isEmpty) {
    return cleanedTitle;
  }

  final normalizedTitle = _normalizeCatalogDisplayValue(cleanedTitle);
  final normalizedWeight = _normalizeCatalogDisplayValue(cleanedWeight);
  if (normalizedWeight.isNotEmpty &&
      normalizedTitle.contains(normalizedWeight)) {
    return cleanedTitle;
  }

  return '$cleanedTitle $cleanedWeight';
}

String _collapseRepeatedMeasurePhrases(String value) {
  var text = value;
  final repeatedMeasurePattern = RegExp(
    r'\b(\d+(?:[.,]\d+)?)\s*(kg|gr|g|ml|lt|l|adet)\b(?:\s+\1\s*\2\b)+',
    caseSensitive: false,
  );
  for (var i = 0; i < 3; i++) {
    final next = text.replaceAllMapped(
      repeatedMeasurePattern,
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    if (next == text) {
      break;
    }
    text = next;
  }
  return text;
}

bool _shouldShowSeparateWeight(String productTitle, String? weight) {
  final cleanedWeight = repairTurkishText(weight ?? '').trim();
  if (cleanedWeight.isEmpty) {
    return false;
  }

  final normalizedTitle = _normalizeCatalogDisplayValue(
    _displayCatalogTitle(productTitle, weight),
  );
  final normalizedWeight = _normalizeCatalogDisplayValue(cleanedWeight);
  return normalizedWeight.isNotEmpty &&
      !normalizedTitle.contains(normalizedWeight);
}

String _normalizeCatalogDisplayValue(String value) {
  return value
      .toLowerCase()
      .replaceAll('\u00E7', 'c')
      .replaceAll('\u011F', 'g')
      .replaceAll('\u0131', 'i')
      .replaceAll('\u00F6', 'o')
      .replaceAll('\u015F', 's')
      .replaceAll('\u00FC', 'u')
      .replaceAll('\u00C7', 'c')
      .replaceAll('\u011E', 'g')
      .replaceAll('\u0130', 'i')
      .replaceAll('\u00D6', 'o')
      .replaceAll('\u015E', 's')
      .replaceAll('\u00DC', 'u')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}

enum _ComparableMeasureKind { count, weight, volume }

enum _MeasureCompatibility { exact, close, mismatch, unknown }

class _ComparableMeasure {
  final _ComparableMeasureKind kind;
  final double value;

  const _ComparableMeasure({
    required this.kind,
    required this.value,
  });
}

class _LocationSessionCard extends StatelessWidget {
  final bool isTr;
  final String? locationLabel;
  final VoidCallback? onTap;

  const _LocationSessionCard({
    required this.isTr,
    required this.locationLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLocation =
        locationLabel != null && locationLabel!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasLocation
                    ? Icons.location_on_rounded
                    : Icons.location_searching_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isTr ? 'Resm\u00EE Fiyat Konumu' : 'Official Price Location',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hasLocation
                ? locationLabel!
                : (isTr
                    ? 'Kar\u015F\u0131la\u015Ft\u0131rmada yak\u0131ndaki marketleri kullanmak i\u00E7in konum se\u00E7.'
                    : 'Pick a location so comparison uses nearby stores.'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: hasLocation
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
              height: 1.4,
              fontWeight: hasLocation ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(
                hasLocation ? Icons.edit_location_alt_rounded : Icons.search,
              ),
              label: Text(
                hasLocation
                    ? (isTr ? 'Konumu G\u00FCncelle' : 'Change Location')
                    : (isTr ? 'Konum Se\u00E7' : 'Choose Location'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final bool isTr;
  final bool usesOfficialSource;

  const _HeroCard({
    required this.isTr,
    required this.usesOfficialSource,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isTr
                      ? (usesOfficialSource
                          ? 'Yak\u0131ndaki Market Fiyatlar\u0131'
                          : 'Markette Bug\u00FCn Ne Ucuz?')
                      : (usesOfficialSource
                          ? 'Nearby Market Prices'
                          : 'Deal Radar'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            isTr
                ? (usesOfficialSource
                    ? 'Konumunu se\u00E7, yak\u0131n marketlerde ayn\u0131 \u00FCr\u00FCn\u00FCn fiyat\u0131n\u0131 kar\u015F\u0131la\u015Ft\u0131ral\u0131m. Resm\u00EE veriyi net ve h\u0131zl\u0131 g\u00F6r.'
                    : 'Marketini se\u00E7, bro\u015F\u00FCrleri tarayal\u0131m. \u0130ndirimli \u00FCr\u00FCnleri kategorili ve net bir \u015Fekilde g\u00F6r.')
                : (usesOfficialSource
                    ? 'Choose your location and compare the same product across nearby stores with official pricing data.'
                    : 'Pick your stores, we scan flyers. See discounted products clearly by category.'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactMarketHeroShowcase extends StatelessWidget {
  final bool isTr;
  final bool usesOfficialSource;
  final int totalItems;
  final int categoryCount;
  final int selectedMarketCount;
  final String? locationLabel;

  const _CompactMarketHeroShowcase({
    required this.isTr,
    required this.usesOfficialSource,
    required this.totalItems,
    required this.categoryCount,
    required this.selectedMarketCount,
    required this.locationLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLocation =
        locationLabel != null && locationLabel!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
        borderRadius: BorderRadius.circular(22),
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
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        usesOfficialSource
                            ? 'Yak\u0131n market modu'
                            : 'Bro\u015F\u00FCr modu',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sepetini daha ak\u0131ll\u0131 kur',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        height: 1.02,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      usesOfficialSource
                          ? 'Konumunu se\u00E7, marketlerini a\u00E7 ve ayn\u0131 \u00FCr\u00FCnleri tek ekranda topla.'
                          : 'Marketlerini se\u00E7, bro\u015F\u00FCr f\u0131rsatlar\u0131n\u0131 tek ekranda toparla.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        height: 1.32,
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
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
                child: const Icon(
                  Icons.shopping_bag_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CompactHeroPill(
                  icon: Icons.storefront_rounded,
                  label: '$selectedMarketCount ${isTr ? 'market' : 'stores'}',
                ),
                _CompactHeroPill(
                  icon: Icons.location_on_rounded,
                  label: hasLocation
                      ? (isTr ? 'Konum Haz\u0131r' : 'Location Ready')
                      : (isTr ? 'Konum Bekliyor' : 'Waiting Location'),
                ),
                _CompactHeroPill(
                  icon: Icons.inventory_2_rounded,
                  label: '$totalItems ${isTr ? '\u00FCr\u00FCn' : 'items'}',
                ),
                _CompactHeroPill(
                  icon: Icons.grid_view_rounded,
                  label: '$categoryCount ${isTr ? 'kategori' : 'categories'}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactHeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CompactHeroPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
          ),
        ],
      ),
    );
  }
}

class _MarketSearchOverviewCard extends StatelessWidget {
  final bool isTr;
  final String summaryLabel;
  final bool isSyncing;
  final DateTime? catalogSyncAt;
  final String? marketFiyatiLocationLabel;
  final TextEditingController controller;
  final Future<void> Function() onSearch;
  final void Function(String)? onSearchChanged;
  final bool isSearching;
  final bool hasActiveCategory;
  final String? activeCategoryLabel;
  final bool isSearchLocked;

  const _MarketSearchOverviewCard({
    required this.isTr,
    required this.summaryLabel,
    required this.isSyncing,
    required this.catalogSyncAt,
    required this.marketFiyatiLocationLabel,
    required this.controller,
    required this.onSearch,
    this.onSearchChanged,
    required this.isSearching,
    required this.hasActiveCategory,
    required this.activeCategoryLabel,
    required this.isSearchLocked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLocation = marketFiyatiLocationLabel != null &&
        marketFiyatiLocationLabel!.trim().isNotEmpty;

    String? formattedSyncAt;
    if (catalogSyncAt != null) {
      formattedSyncAt =
          '${catalogSyncAt!.day.toString().padLeft(2, '0')}.${catalogSyncAt!.month.toString().padLeft(2, '0')} ${catalogSyncAt!.hour.toString().padLeft(2, '0')}:${catalogSyncAt!.minute.toString().padLeft(2, '0')}';
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  gradient: AppTheme.heroGradient,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  summaryLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (isSyncing)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !isSearchLocked,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) {
                    if (!isSearchLocked) {
                      onSearch();
                    }
                  },
                  onChanged: isSearchLocked ? null : onSearchChanged,
                  decoration: InputDecoration(
                    hintText: isTr
                        ? (isSearchLocked
                            ? 'Arama i\u00e7in \u00f6nce a\u00e7\u0131k kategoriyi temizle'
                            : '\u00DCr\u00FCn ara: s\u00FCt, zeytinya\u011F\u0131, makarna...')
                        : 'Search products: milk, olive oil, pasta...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppTheme.warmSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: isSearching || isSearchLocked ? null : onSearch,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(82, 56),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                ),
                child: Text(isTr ? 'Ara' : 'Search'),
              ),
            ],
          ),
          if (hasActiveCategory) ...[
            const SizedBox(height: 10),
            Text(
              isTr
                  ? 'Kategori açık: ${activeCategoryLabel ?? ''}. Bu sırada ürün araması kapalı.'
                  : 'A category is active. Product search is disabled right now.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.inkSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (formattedSyncAt != null)
                _SearchMetaChip(
                  icon: Icons.schedule_rounded,
                  label: 'Son yenileme $formattedSyncAt',
                ),
              _SearchMetaChip(
                icon: hasLocation
                    ? Icons.location_on_rounded
                    : Icons.location_searching_rounded,
                label: hasLocation
                    ? marketFiyatiLocationLabel!
                    : 'Önce konum, sonra market seçimiyle liste gelir',
                accent: hasLocation,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool accent;

  const _SearchMetaChip({
    required this.icon,
    required this.label,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cleanLabel = repairTurkishText(label);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent ? AppTheme.surfaceTint : AppTheme.warmSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color:
                accent ? AppTheme.primary : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              cleanLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: accent ? AppTheme.primary : AppTheme.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShowcaseSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _ShowcaseSectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
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
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  gradient: AppTheme.heroGradient,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(width: 12),
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
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.inkSoft,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (child is! SizedBox) const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ShowcaseDisplayCategoryTileCard extends StatelessWidget {
  final _MarketBrowseCategory category;
  final int count;
  final bool isSelected;
  final bool isEnabled;
  final bool isTr;
  final VoidCallback? onTap;

  const _ShowcaseDisplayCategoryTileCard({
    required this.category,
    required this.count,
    required this.isSelected,
    required this.isEnabled,
    required this.isTr,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = isTr ? category.shortLabelTr : category.shortLabelEn;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: isEnabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF17345F)
                : Colors.white.withValues(alpha: isEnabled ? 0.96 : 0.8),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF17345F)
                  : AppTheme.primary.withValues(alpha: 0.08),
            ),
            boxShadow: isSelected ? AppTheme.softShadow : AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.16)
                      : AppTheme.warmSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  category.icon,
                  size: 18,
                  color: isSelected
                      ? Colors.white
                      : isEnabled
                          ? AppTheme.primary
                          : AppTheme.inkSoft,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  color: isSelected
                      ? Colors.white
                      : isEnabled
                          ? AppTheme.ink
                          : AppTheme.inkSoft,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.14)
                      : AppTheme.warmSurface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  count > 0
                      ? (isTr ? '$count \u00FCr\u00FCn' : '$count items')
                      : count == 0
                          ? (isTr ? 'Bo\u015F' : 'Empty')
                          : (isTr ? 'A\u00E7' : 'Open'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? Colors.white
                        : isEnabled
                            ? AppTheme.primary
                            : AppTheme.inkSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactMarketSelectorCard extends StatelessWidget {
  final bool isTr;
  final AppProvider provider;
  final bool enabled;
  final VoidCallback onOpenMarkets;
  final VoidCallback onChooseLocation;

  const _CompactMarketSelectorCard({
    required this.isTr,
    required this.provider,
    required this.enabled,
    required this.onOpenMarkets,
    required this.onChooseLocation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Seçilebilir marketler önce Supabase'den; Supabase hazır değilse
    // marketfiyati.org.tr'nin bu konum icin dondurdugu listeye dusulur.
    final selectableIds = provider.supabaseMarketIds.isNotEmpty
        ? provider.supabaseMarketIds.toSet()
        : provider.marketFiyatiAvailableMarketIds.toSet();
    final availableMarketCount = selectableIds.length;
    final selectedIds = provider.smartKitchenPreferences.preferredMarkets
        .where(selectableIds.contains)
        .toSet();
    final selectedMarkets = _officialMarketOptionsFor(selectedIds);

    return _ShowcaseSectionCard(
      title: isTr ? 'Marketlerin' : 'Your stores',
      subtitle: enabled
          ? (isTr
              ? 'Konum hazır. Uygun marketleri gör, seçimini tek yerden yönet.'
              : 'Location ready. Review available stores and manage your picks.')
          : (isTr
              ? 'Önce konumunu seç. Market alanı bundan sonra açılır.'
              : 'Choose your location first.'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.warmSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF17345F),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              enabled
                                  ? (isTr
                                      ? '${selectedIds.length} market seçili'
                                      : '${selectedIds.length} stores selected')
                                  : (isTr
                                      ? 'Önce konum seç'
                                      : 'Choose location first'),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              enabled
                                  ? (isTr
                                      ? '$availableMarketCount market uygun. Seçimini açıp düzenleyebilirsin.'
                                      : '$availableMarketCount stores available. Open the list to edit your picks.')
                                  : (isTr
                                      ? 'Konumdan sonra market listesi açılır.'
                                      : 'Choose a location to unlock stores.'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.inkSoft,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: enabled ? onOpenMarkets : onChooseLocation,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(76, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                child: Text(enabled ? 'Aç' : 'Konum'),
              ),
            ],
          ),
          if (selectedMarkets.isNotEmpty) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...selectedMarkets.take(3).map((market) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          '${market.emoji} ${market.label}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    );
                  }),
                  if (selectedMarkets.length > 3)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceTint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '+${selectedMarkets.length - 3}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  if (availableMarketCount > selectedMarkets.length) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceTint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isTr
                            ? '$availableMarketCount uygun'
                            : '$availableMarketCount available',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (!enabled) ...[
            const SizedBox(height: 12),
            Text(
              isTr
                  ? 'Önce konumunu seç. Sonra marketlerini açarız.'
                  : 'Choose your location first.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFFB54A5E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else if (selectedIds.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              isTr
                  ? 'Önce en az bir market seç. Ürünleri buna göre göstereceğiz.'
                  : 'Choose at least one store first.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFFB54A5E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MarketSelectionSummaryCard extends StatelessWidget {
  final bool isTr;
  final AppProvider provider;
  final bool enabled;
  final VoidCallback onOpenMarkets;
  final VoidCallback onChooseLocation;

  const _MarketSelectionSummaryCard({
    required this.isTr,
    required this.provider,
    required this.enabled,
    required this.onOpenMarkets,
    required this.onChooseLocation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Seçilebilir marketler önce Supabase'den; Supabase hazır değilse
    // marketfiyati.org.tr'nin bu konum icin dondurdugu listeye dusulur.
    final selectableIds = provider.supabaseMarketIds.isNotEmpty
        ? provider.supabaseMarketIds.toSet()
        : provider.marketFiyatiAvailableMarketIds.toSet();
    final availableMarketCount = selectableIds.length;
    final selectedIds = provider.smartKitchenPreferences.preferredMarkets
        .where(selectableIds.contains)
        .toSet();
    final selectedMarkets = _officialMarketOptionsFor(selectedIds);

    return _ShowcaseSectionCard(
      title: isTr ? 'Marketlerin' : 'Your stores',
      subtitle: enabled
          ? (isTr
              ? 'Konum hazır. Uygun marketleri gör, seçimini tek yerden yönet.'
              : 'Pick your stores, then load products once.')
          : (isTr
              ? 'Önce konumunu seç. Market alanı bundan sonra açılır.'
              : 'Choose your location first.'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.warmSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF17345F),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              enabled
                                  ? (isTr
                                      ? '${selectedIds.length} market seçili'
                                      : '${selectedIds.length} stores selected')
                                  : (isTr
                                      ? 'Önce konum seç'
                                      : 'Choose location first'),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              enabled
                                  ? (isTr
                                      ? '$availableMarketCount market uygun. Seçimini açıp düzenleyebilirsin.'
                                      : '$availableMarketCount stores available. Open the store list to edit picks.')
                                  : (isTr
                                      ? 'Konumdan sonra market listesi açılır.'
                                      : 'Stores unlock after location.'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.inkSoft,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: enabled ? onOpenMarkets : onChooseLocation,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(78, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                child: Text(isTr ? (enabled ? 'Aç' : 'Konum') : 'Open'),
              ),
            ],
          ),
          if (selectedMarkets.isNotEmpty) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...selectedMarkets.take(3).map((market) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          '${market.emoji} ${market.label}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    );
                  }),
                  if (selectedMarkets.length > 3)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceTint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '+${selectedMarkets.length - 3}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  if (availableMarketCount > selectedMarkets.length) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceTint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isTr
                            ? '$availableMarketCount uygun'
                            : '$availableMarketCount available',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShowcaseMarketPill extends StatelessWidget {
  final String emoji;
  final String label;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  const _ShowcaseMarketPill({
    required this.emoji,
    required this.label,
    required this.isSelected,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            gradient: isSelected ? AppTheme.heroGradient : null,
            color: isSelected
                ? null
                : enabled
                    ? AppTheme.warmSurface
                    : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : AppTheme.primary.withValues(alpha: 0.08),
            ),
            boxShadow: isSelected
                ? AppTheme.softShadow
                : enabled
                    ? null
                    : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isSelected
                      ? Colors.white
                      : enabled
                          ? AppTheme.ink
                          : AppTheme.inkSoft,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShowcaseLocationSessionCard extends StatelessWidget {
  final bool isTr;
  final String? locationLabel;
  final VoidCallback? onTap;

  const _ShowcaseLocationSessionCard({
    required this.isTr,
    required this.locationLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLocation =
        locationLabel != null && locationLabel!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.08),
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient:
                  hasLocation ? AppTheme.heroGradient : AppTheme.panelGradient,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              hasLocation
                  ? Icons.location_on_rounded
                  : Icons.location_searching_rounded,
              color: hasLocation ? Colors.white : AppTheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTr ? 'Konumun' : 'Your location',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasLocation
                      ? locationLabel!
                      : (isTr
                          ? 'Yak\u0131ndaki marketleri kullanabilmek i\u00E7in konum se\u00E7.'
                          : 'Choose a location to use nearby stores.'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: hasLocation ? AppTheme.ink : AppTheme.inkSoft,
                    height: 1.4,
                    fontWeight: hasLocation ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onTap,
                  icon: Icon(
                    hasLocation
                        ? Icons.edit_location_alt_rounded
                        : Icons.location_searching_rounded,
                  ),
                  label: Text(
                    hasLocation
                        ? (isTr ? 'Konumu G\u00FCncelle' : 'Change location')
                        : (isTr ? 'Konum Se\u00E7' : 'Choose location'),
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

class _ShowcaseProductCard extends StatelessWidget {
  final ActuellerCatalogItem item;
  final bool isTr;
  final bool isInShoppingList;
  final VoidCallback onToggleShoppingList;
  final VoidCallback onCompare;

  const _ShowcaseProductCard({
    required this.item,
    required this.isTr,
    required this.isInShoppingList,
    required this.onToggleShoppingList,
    required this.onCompare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.08),
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onCompare,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppTheme.heroGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: const Icon(
                    Icons.shopping_bag_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _displayCatalogTitle(item.productTitle, item.weight),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1.08,
                        ),
                      ),
                      if ((item.brand != null &&
                              item.brand!.trim().isNotEmpty) ||
                          _shouldShowSeparateWeight(
                            item.productTitle,
                            item.weight,
                          )) ...[
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (item.brand != null &&
                                item.brand!.trim().isNotEmpty)
                              repairTurkishText(item.brand!).trim(),
                            if (_shouldShowSeparateWeight(
                              item.productTitle,
                              item.weight,
                            ))
                              repairTurkishText(item.weight!).trim(),
                          ].join(' \u2022 '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.inkSoft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppTheme.heroGradient,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: AppTheme.softShadow,
                            ),
                            child: Text(
                              '${_formatPrice(item.price)} TL',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const Spacer(),
                          _ProductActionIconButton(
                            icon: isInShoppingList
                                ? Icons.check_circle_rounded
                                : Icons.add_circle_outline_rounded,
                            tooltip: isInShoppingList
                                ? 'Listeden \u00E7\u0131kar'
                                : 'Listeye ekle',
                            accent: isInShoppingList,
                            onTap: onToggleShoppingList,
                          ),
                          const SizedBox(width: 6),
                          _ProductActionIconButton(
                            icon: Icons.compare_arrows_rounded,
                            tooltip: isTr
                                ? 'Kar\u015F\u0131la\u015Ft\u0131r'
                                : 'Compare',
                            onTap: onCompare,
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
      ),
    );
  }

  String _formatPrice(double price) {
    if (price == price.roundToDouble()) {
      return price.toStringAsFixed(0);
    }
    return price.toStringAsFixed(2).replaceAll('.', ',');
  }
}

class _ProductActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool accent;
  final VoidCallback onTap;

  const _ProductActionIconButton({
    required this.icon,
    required this.tooltip,
    this.accent = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: accent ? AppTheme.heroGradient : null,
            color: accent ? null : AppTheme.warmSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accent
                  ? Colors.transparent
                  : AppTheme.primary.withValues(alpha: 0.1),
            ),
          ),
          child: Icon(
            icon,
            size: 17,
            color: accent ? Colors.white : AppTheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Backend'den cekilen marketleri tier bazli grupluyor ve secim UI'si
/// sunuyor. marketfiyati.org.tr'nin bu konum icin dondurdugu marketler
/// "Burada var" rozetiyle isaretleniyor.
class _TierGroupedMarketPicker extends StatelessWidget {
  const _TierGroupedMarketPicker({
    required this.markets,
    required this.draftSelectedIds,
    required this.locallyAvailableIds,
    required this.onToggle,
    required this.enabled,
    required this.isTr,
  });

  final List<SupabaseMarket> markets;
  final Set<String> draftSelectedIds;
  final Set<String> locallyAvailableIds;
  final void Function(String marketId) onToggle;
  final bool enabled;
  final bool isTr;

  static const _tierTitlesTr = <int, String>{
    1: 'Ulusal Zincirler',
    2: 'Orta Olcekli Zincirler',
    3: 'Bolgesel Zincirler',
    4: 'Online / Hizli Market',
  };
  static const _tierTitlesEn = <int, String>{
    1: 'National Chains',
    2: 'Mid-Size Chains',
    3: 'Regional Chains',
    4: 'Online / Quick Commerce',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = <int, List<SupabaseMarket>>{};
    for (final m in markets) {
      final t = m.tier ?? 3;
      grouped.putIfAbsent(t, () => []).add(m);
    }
    final sortedTiers = grouped.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final tier in sortedTiers) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  (isTr ? _tierTitlesTr : _tierTitlesEn)[tier] ?? 'Tier $tier',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${grouped[tier]!.length})',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: grouped[tier]!.map((market) {
              final selected = draftSelectedIds.contains(market.id);
              final local = locallyAvailableIds.contains(market.id);
              final emoji = _officialMarketEmojiById[market.id] ?? '🏪';
              return _ShowcaseMarketPill(
                emoji: emoji,
                label: market.displayName +
                    (local ? (isTr ? ' • konumunda' : ' • local') : ''),
                isSelected: selected,
                enabled: enabled,
                onTap: () => onToggle(market.id),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}
