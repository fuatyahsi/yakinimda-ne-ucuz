import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, listEquals;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/market_app_preferences.dart';
import '../models/market_fiyati.dart';
import '../models/market_shopping_list.dart';
import '../models/price_history.dart';
import '../models/price_watch.dart';
import '../models/smart_actueller.dart';
import '../models/supabase_market.dart';
import '../services/market_fiyati_source_service.dart';
import '../services/price_history_service.dart';
import '../services/price_watch_service.dart';
import '../services/supabase_service.dart';
import '../utils/market_registry.dart';
import '../utils/text_repair.dart';

class _OfficialCategoryFetchResult {
  final List<ActuellerCatalogItem> items;
  final List<String> discoveredKeywords;

  const _OfficialCategoryFetchResult({
    required this.items,
    required this.discoveredKeywords,
  });
}

class _OfficialCatalogSourceSeed {
  final String rootCategory;
  final String subcategory;
  final String slug;

  const _OfficialCatalogSourceSeed({
    required this.rootCategory,
    required this.subcategory,
    required this.slug,
  });

  String get repairedRootCategory => repairTurkishText(rootCategory).trim();
  String get repairedSubcategory => repairTurkishText(subcategory).trim();
}

const _officialCatalogSourceSeeds = [
  _OfficialCatalogSourceSeed(
    rootCategory: 'Meyve ve Sebze',
    subcategory: 'Meyve',
    slug: 'meyve',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Meyve ve Sebze',
    subcategory: 'Sebze',
    slug: 'sebze',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Et, Tavuk ve BalÄ±k',
    subcategory: 'KÄ±rmÄ±zÄ± Et',
    slug: 'kirmizi-et',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Et, Tavuk ve BalÄ±k',
    subcategory: 'Beyaz Et',
    slug: 'beyaz-et',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Et, Tavuk ve BalÄ±k',
    subcategory: 'Deniz ÃœrÃ¼nleri',
    slug: 'deniz-urunleri',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Et, Tavuk ve BalÄ±k',
    subcategory: 'ÅarkÃ¼teri',
    slug: 'sarkuteri',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Et, Tavuk ve BalÄ±k',
    subcategory: 'Sakatat',
    slug: 'sakatat',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'SÃ¼t ÃœrÃ¼nleri ve KahvaltÄ±lÄ±k',
    subcategory: 'SÃ¼t',
    slug: 'sut',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'SÃ¼t ÃœrÃ¼nleri ve KahvaltÄ±lÄ±k',
    subcategory: 'Yumurta',
    slug: 'yumurta',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'SÃ¼t ÃœrÃ¼nleri ve KahvaltÄ±lÄ±k',
    subcategory: 'Peynir',
    slug: 'peynir',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'SÃ¼t ÃœrÃ¼nleri ve KahvaltÄ±lÄ±k',
    subcategory: 'YoÄŸurt',
    slug: 'yogurt',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'SÃ¼t ÃœrÃ¼nleri ve KahvaltÄ±lÄ±k',
    subcategory: 'Zeytin',
    slug: 'zeytin',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'SÃ¼t ÃœrÃ¼nleri ve KahvaltÄ±lÄ±k',
    subcategory: 'TereyaÄŸÄ± ve Margarin',
    slug: 'tereyagi-ve-margarin',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'SÃ¼t ÃœrÃ¼nleri ve KahvaltÄ±lÄ±k',
    subcategory: 'SÃ¼rÃ¼lebilir ÃœrÃ¼nler ve KahvaltÄ±lÄ±k Soslar',
    slug: 'surulebilir-urunler-ve-kahvaltilik-soslar',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'SÃ¼t ÃœrÃ¼nleri ve KahvaltÄ±lÄ±k',
    subcategory: 'Helva Tahin ve Pekmez',
    slug: 'helva-tahin-ve-pekmez',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'SÃ¼t ÃœrÃ¼nleri ve KahvaltÄ±lÄ±k',
    subcategory: 'Bal ve ReÃ§el',
    slug: 'bal-ve-recel',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'SÃ¼t ÃœrÃ¼nleri ve KahvaltÄ±lÄ±k',
    subcategory: 'KahvaltÄ±lÄ±k Gevrek Bar ve Granola',
    slug: 'kahvaltilik-gevrek-bar-ve-granola',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'SÃ¼t ÃœrÃ¼nleri ve KahvaltÄ±lÄ±k',
    subcategory: 'Kaymak ve Krema',
    slug: 'kaymak-ve-krema',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temel GÄ±da',
    subcategory: 'Ekmek ve Unlu MamÃ¼ller',
    slug: 'ekmek-ve-unlu-mamuller',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temel GÄ±da',
    subcategory: 'SÄ±vÄ± YaÄŸlar',
    slug: 'sivi-yaglar',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temel GÄ±da',
    subcategory: 'Bakliyat',
    slug: 'bakliyat',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temel GÄ±da',
    subcategory: 'Åeker ve TatlandÄ±rÄ±cÄ±lar',
    slug: 'seker-ve-tatlandiricilar',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temel GÄ±da',
    subcategory: 'Pasta Malzemeleri',
    slug: 'pasta-malzemeleri',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temel GÄ±da',
    subcategory: 'Un ve Ä°rmik',
    slug: 'un-ve-irmik',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temel GÄ±da',
    subcategory: 'MantÄ± Makarna ve EriÅŸte',
    slug: 'manti-makarna-ve-eriste',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temel GÄ±da',
    subcategory: 'KetÃ§ap Mayonez Sos ve Sirkeler',
    slug: 'ketcap-mayonez-sos-ve-sirkeler',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temel GÄ±da',
    subcategory: 'Tuz Baharat ve HarÃ§lar',
    slug: 'tuz-baharat-ve-harclar',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temel GÄ±da',
    subcategory: 'SalÃ§a',
    slug: 'salca',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temel GÄ±da',
    subcategory: 'TurÅŸu',
    slug: 'tursu',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temel GÄ±da',
    subcategory: 'Konserve',
    slug: 'konserve',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temel GÄ±da',
    subcategory: 'HazÄ±r GÄ±da',
    slug: 'hazir-gida',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temel GÄ±da',
    subcategory: 'Bebek MamalarÄ±',
    slug: 'bebek-mamalari',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Ä°Ã§ecek',
    subcategory: 'Su',
    slug: 'su',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Ä°Ã§ecek',
    subcategory: 'Meyve Suyu',
    slug: 'meyve-suyu',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Ä°Ã§ecek',
    subcategory: 'GazlÄ± Ä°Ã§ecekler',
    slug: 'gazli-icecekler',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Ä°Ã§ecek',
    subcategory: 'GazsÄ±z Ä°Ã§ecekler',
    slug: 'gazsiz-icecekler',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Ä°Ã§ecek',
    subcategory: 'Ayran ve Kefir',
    slug: 'ayran-ve-kefir',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Ä°Ã§ecek',
    subcategory: 'Maden Suyu',
    slug: 'maden-suyu',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Ä°Ã§ecek',
    subcategory: 'Ã‡ay ve Bitki Ã‡aylarÄ±',
    slug: 'cay-ve-bitki-caylari',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Ä°Ã§ecek',
    subcategory: 'Kahve',
    slug: 'kahve',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'AtÄ±ÅŸtÄ±rmalÄ±k ve TatlÄ±',
    subcategory: 'Ã‡ikolata',
    slug: 'cikolata',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'AtÄ±ÅŸtÄ±rmalÄ±k ve TatlÄ±',
    subcategory: 'Gofret',
    slug: 'gofret',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'AtÄ±ÅŸtÄ±rmalÄ±k ve TatlÄ±',
    subcategory: 'BiskÃ¼vi ve Kraker',
    slug: 'biskuvi-ve-kraker',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'AtÄ±ÅŸtÄ±rmalÄ±k ve TatlÄ±',
    subcategory: 'Kek',
    slug: 'kek',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'AtÄ±ÅŸtÄ±rmalÄ±k ve TatlÄ±',
    subcategory: 'Cips',
    slug: 'cips',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'AtÄ±ÅŸtÄ±rmalÄ±k ve TatlÄ±',
    subcategory: 'KuruyemiÅŸ ve Kuru Meyve',
    slug: 'kuruyemis-ve-kuru-meyve',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'AtÄ±ÅŸtÄ±rmalÄ±k ve TatlÄ±',
    subcategory: 'SakÄ±z ve Åekerleme',
    slug: 'sakiz-ve-sekerleme',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'AtÄ±ÅŸtÄ±rmalÄ±k ve TatlÄ±',
    subcategory: 'TatlÄ±lar',
    slug: 'tatlilar',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'AtÄ±ÅŸtÄ±rmalÄ±k ve TatlÄ±',
    subcategory: 'Dondurmalar',
    slug: 'dondurmalar',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temizlik ve KiÅŸisel BakÄ±m ÃœrÃ¼nleri',
    subcategory: 'BulaÅŸÄ±k Temizlik ÃœrÃ¼nleri',
    slug: 'bulasik-temizlik-urunleri',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temizlik ve KiÅŸisel BakÄ±m ÃœrÃ¼nleri',
    subcategory: 'Ã‡amaÅŸÄ±r Temizlik ÃœrÃ¼nleri',
    slug: 'camasir-temizlik-urunleri',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temizlik ve KiÅŸisel BakÄ±m ÃœrÃ¼nleri',
    subcategory: 'Genel Temizlik ÃœrÃ¼nleri',
    slug: 'genel-temizlik-urunleri',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temizlik ve KiÅŸisel BakÄ±m ÃœrÃ¼nleri',
    subcategory: 'Mutfak Sarf Malzemeleri',
    slug: 'mutfak-sarf-malzemeleri',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temizlik ve KiÅŸisel BakÄ±m ÃœrÃ¼nleri',
    subcategory: 'Tuvalet KaÄŸÄ±dÄ±',
    slug: 'tuvalet-kagidi',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temizlik ve KiÅŸisel BakÄ±m ÃœrÃ¼nleri',
    subcategory: 'KaÄŸÄ±t Havlu',
    slug: 'kagit-havlu',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temizlik ve KiÅŸisel BakÄ±m ÃœrÃ¼nleri',
    subcategory: 'KaÄŸÄ±t PeÃ§ete ve Mendil',
    slug: 'kagit-pecete-ve-mendil',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temizlik ve KiÅŸisel BakÄ±m ÃœrÃ¼nleri',
    subcategory: 'Islak Mendil',
    slug: 'islak-mendil',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temizlik ve KiÅŸisel BakÄ±m ÃœrÃ¼nleri',
    subcategory: 'SaÃ§ BakÄ±m',
    slug: 'sac-bakim',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temizlik ve KiÅŸisel BakÄ±m ÃœrÃ¼nleri',
    subcategory: 'DuÅŸ Banyo ve Sabun',
    slug: 'dus-banyo-ve-sabun',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temizlik ve KiÅŸisel BakÄ±m ÃœrÃ¼nleri',
    subcategory: 'AÄŸÄ±z BakÄ±m',
    slug: 'agiz-bakim',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temizlik ve KiÅŸisel BakÄ±m ÃœrÃ¼nleri',
    subcategory: 'Hijyenik Ped',
    slug: 'hijyenik-ped',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temizlik ve KiÅŸisel BakÄ±m ÃœrÃ¼nleri',
    subcategory: 'Bebek ve Hasta Bezi',
    slug: 'bebek-ve-hasta-bezi',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temizlik ve KiÅŸisel BakÄ±m ÃœrÃ¼nleri',
    subcategory: 'ParfÃ¼m Deodorant Kolonya ve Kokular',
    slug: 'parfum-deodorant-kolonya-ve-kokular',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temizlik ve KiÅŸisel BakÄ±m ÃœrÃ¼nleri',
    subcategory: 'Cilt BakÄ±mÄ±',
    slug: 'cilt-bakimi',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temizlik ve KiÅŸisel BakÄ±m ÃœrÃ¼nleri',
    subcategory: 'Makyaj',
    slug: 'makyaj',
  ),
  _OfficialCatalogSourceSeed(
    rootCategory: 'Temizlik ve KiÅŸisel BakÄ±m ÃœrÃ¼nleri',
    subcategory: 'DiÄŸer Temizlik ve KiÅŸisel BakÄ±m ÃœrÃ¼nleri',
    slug: 'diger-temizlik-ve-kisisel-bakim-urunleri',
  ),
];

class AppProvider extends ChangeNotifier {
  static const int _officialCatalogPreviewPageSize = 24;
  static const int _officialCatalogAllProductsPageSize = 240;
  static const int _officialCatalogCategoryPageSize = 240;
  static const int _officialCatalogCategoryMaxPageCount = 100;
  static const Duration _officialCatalogInterBatchDelay = Duration(
    milliseconds: 180,
  );
  static const int _marketFiyatiMaxDepots = 500;

  final MarketFiyatiSourceService _marketFiyatiSourceService =
      MarketFiyatiSourceService();
  final PriceHistoryService _priceHistoryService = PriceHistoryService();
  final PriceWatchService _priceWatchService = PriceWatchService();

  bool _isLoading = true;
  bool _isDarkMode = false;
  Map<String, ProductPriceHistory> _priceHistories = {};
  List<PriceWatch> _priceWatches = [];
  PriceWatchCheckResult? _lastWatchCheckResult;
  MarketAppPreferences _preferences = const MarketAppPreferences.defaults();
  ActuellerScanResult? _lastActuellerScanResult;
  bool _isActuellerCatalogSyncing = false;
  String? _actuellerCatalogSyncMessage;
  DateTime? _lastActuellerCatalogSyncAt;
  int _lastActuellerCatalogBrochureCount = 0;
  final List<MarketShoppingListEntry> _shoppingListEntries = [];
  String? _officialCatalogCacheKey;
  List<ActuellerCatalogItem>? _officialCatalogAllItemsCache;
  final Map<String, List<ActuellerCatalogItem>> _officialCatalogCache = {};
  final Map<String, List<String>> _officialCatalogFacetKeywordCache = {};
  List<MarketFiyatiOfficialCategory>? _officialCategoryTreeCache;
  List<String> _marketFiyatiAvailableMarketIds = const [];
  // Supabase `markets` tablosunun cache'lenmis kopyasi. UI burada kac market
  // secilebildigini gostermek icin bunu kullanir — marketfiyati.org.tr'nin
  // konum listesi yalnizca fallback.
  List<SupabaseMarket> _supabaseMarkets = const [];
  bool _isLoadingSupabaseMarkets = false;

  bool get isLoading => _isLoading;
  bool get isDarkMode => _isDarkMode;
  MarketAppPreferences get marketPreferences => _preferences;

  // â”€â”€ Price history getters â”€â”€
  Map<String, ProductPriceHistory> get priceHistories =>
      Map.unmodifiable(_priceHistories);

  ProductPriceHistory? priceHistoryFor(String? productId) =>
      _priceHistoryService.getHistory(_priceHistories, productId);

  List<ProductPriceHistory> get priceDropProducts =>
      _priceHistoryService.findPriceDrops(_priceHistories);

  List<ProductPriceHistory> get historicLowProducts =>
      _priceHistoryService.findAtHistoricLow(_priceHistories);

  // â”€â”€ Price watch getters â”€â”€
  List<PriceWatch> get priceWatches => List.unmodifiable(_priceWatches);

  int get activeWatchCount => _priceWatches.where((w) => !w.isTriggered).length;

  PriceWatchCheckResult? get lastWatchCheckResult => _lastWatchCheckResult;

  bool isProductWatched(String? productId) =>
      _priceWatchService.isWatched(_priceWatches, productId);

  // Compatibility alias for the current market screen until we finish the rename.
  MarketAppPreferences get smartKitchenPreferences => _preferences;

  List<String> get selectedMarketIds =>
      List.unmodifiable(_preferences.preferredMarkets);

  List<MarketShoppingListEntry> get shoppingListEntries =>
      List.unmodifiable(_shoppingListEntries);

  int get shoppingListCount => _shoppingListEntries.length;

  /// Market secim modal'i bu listeyi tuketir. Daha once SADECE marketfiyati
  /// depot listesinden ureyiyordu — HAKMAR Express ve diger Supabase-only
  /// zincirler gozukmuyordu. Simdi Supabase markets (is_active=true) UNION
  /// marketfiyati depot listesi: ne fazla ne eksik. Tier sirasi: Supabase
  /// markets[].sort_order, sonra alfabetik.
  List<String> get marketFiyatiAvailableMarketIds {
    if (_supabaseMarkets.isEmpty) {
      return List.unmodifiable(_marketFiyatiAvailableMarketIds);
    }
    final union = <String>{};
    for (final m in _supabaseMarkets) {
      union.add(m.id);
    }
    for (final mid in _marketFiyatiAvailableMarketIds) {
      union.add(mid);
    }
    return List.unmodifiable(union);
  }

  /// Supabase `markets` tablosundan cache'lenmis aktif market listesi.
  /// Supabase hazir degilse veya fetch basarisizsa bos liste doner.
  List<SupabaseMarket> get supabaseMarkets =>
      List.unmodifiable(_supabaseMarkets);

  List<String> get supabaseMarketIds =>
      List.unmodifiable(_supabaseMarkets.map((m) => m.id));

  /// UI'da "seçilebilecek market sayısı"nı gösteren tek giris noktasi.
  /// Supabase listesi varsa onun uzunlugunu, yoksa marketfiyati.org.tr
  /// konum listesine dusen fallback degerini doner.
  int get availableMarketCount => _supabaseMarkets.isNotEmpty
      ? _supabaseMarkets.length
      : _marketFiyatiAvailableMarketIds.length;

  bool get isLoadingSupabaseMarkets => _isLoadingSupabaseMarkets;

  MarketFiyatiSession? get marketFiyatiSession {
    final session = _preferences.marketFiyatiSession;
    if (session == null || !session.isReady) {
      return null;
    }

    final preferredMarketIds =
        normalizeMarketIds(_preferences.preferredMarkets).toSet();
    if (preferredMarketIds.isEmpty) {
      return session;
    }

    final filteredDepots = session.depots.where((depotId) {
      final rawMarketId = depotId.split('-').first;
      final normalizedMarketId = normalizeMarketId(rawMarketId) ?? rawMarketId;
      return preferredMarketIds.contains(normalizedMarketId);
    }).toList();

    if (filteredDepots.isEmpty) {
      return session;
    }

    return session.copyWith(depots: filteredDepots);
  }

  String? get marketFiyatiLocationLabel => marketFiyatiSession?.locationLabel;

  bool get hasOfficialMarketCatalog {
    final catalogItems = _lastActuellerScanResult?.catalogItems ??
        const <ActuellerCatalogItem>[];
    return catalogItems
        .any((item) => (item.sourceProductId ?? '').trim().isNotEmpty);
  }

  ActuellerScanResult? get lastActuellerScanResult => _lastActuellerScanResult;
  bool get isActuellerCatalogSyncing => _isActuellerCatalogSyncing;
  String? get actuellerCatalogSyncMessage =>
      _actuellerCatalogSyncMessage == null
          ? null
          : repairTurkishText(_actuellerCatalogSyncMessage!);
  DateTime? get lastActuellerCatalogSyncAt => _lastActuellerCatalogSyncAt;
  int get lastActuellerCatalogBrochureCount =>
      _lastActuellerCatalogBrochureCount;

  List<MarketShoppingListGroup> get shoppingListGroupsByMarket {
    final grouped = <String, List<MarketShoppingListEntry>>{};
    final marketNames = <String, String>{};

    for (final entry in _shoppingListEntries) {
      final marketId = _marketIdFromName(entry.selectedItem.marketName);
      grouped.putIfAbsent(marketId, () => []).add(entry);
      marketNames[marketId] = _displayMarketName(entry.selectedItem.marketName);
    }

    final groups = grouped.entries
        .map(
          (entry) => MarketShoppingListGroup(
            marketId: entry.key,
            marketName: marketNames[entry.key] ?? entry.key,
            entries: List<MarketShoppingListEntry>.unmodifiable(entry.value),
          ),
        )
        .toList()
      ..sort((a, b) => a.marketName.compareTo(b.marketName));

    return groups;
  }

  Future<void> initialize() async {
    await _loadPreferences();
    _priceHistories = await _priceHistoryService.loadAll();
    _priceWatches = await _priceWatchService.loadAll();
    _isLoading = false;
    notifyListeners();
    // UI'yi bloklamadan Supabase market listesini arka planda doldur.
    // Hata olursa sessizce yutulur — UI marketfiyati fallback'ine duser.
    unawaited(refreshSupabaseMarkets());
  }

  /// Supabase `markets` tablosunu yeniden cek ve cache'i guncelle.
  /// `initialize()` icinde bir kere cagrilir; UI refresh butonundan da
  /// tetiklenebilir. Hatalari yutar, UI bozulmasin diye notifyListeners()
  /// her durumda calisir.
  Future<void> refreshSupabaseMarkets() async {
    if (_isLoadingSupabaseMarkets) return;
    if (!SupabaseService.instance.isReady) {
      _supabaseMarkets = const [];
      return;
    }
    _isLoadingSupabaseMarkets = true;
    try {
      final markets = await SupabaseService.instance.fetchMarkets();
      _supabaseMarkets = markets;
    } catch (e) {
      debugPrint('refreshSupabaseMarkets failed: $e');
      // Cache'i silmiyoruz — onceki fetch'ten kalan liste UI icin daha iyi.
    } finally {
      _isLoadingSupabaseMarkets = false;
      notifyListeners();
    }
  }

  // â”€â”€ Price Watch methods â”€â”€

  Future<void> addPriceWatch({
    required String productId,
    required String productTitle,
    required double currentPrice,
    double? targetPrice,
    String? marketId,
  }) async {
    _priceWatches = await _priceWatchService.addWatch(
      existing: _priceWatches,
      productId: productId,
      productTitle: productTitle,
      currentPrice: currentPrice,
      targetPrice: targetPrice,
      marketId: marketId,
    );
    notifyListeners();
  }

  Future<void> removePriceWatch(String watchId) async {
    _priceWatches = await _priceWatchService.removeWatch(
      existing: _priceWatches,
      watchId: watchId,
    );
    notifyListeners();
  }

  Future<void> _checkPriceWatches(List<ActuellerCatalogItem> items) async {
    if (_priceWatches.isEmpty || items.isEmpty) return;
    final result = await _priceWatchService.checkWatches(
      watches: _priceWatches,
      catalogItems: items,
    );
    _priceWatches = result.allWatches;
    _lastWatchCheckResult = result;
  }

  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    await _savePreferences();
    notifyListeners();
  }

  Future<void> togglePreferredMarket(String marketId) async {
    final markets = [..._preferences.preferredMarkets];
    if (markets.contains(marketId)) {
      markets.remove(marketId);
    } else {
      markets.add(marketId);
    }

    await setPreferredMarkets(markets);
  }

  Future<void> setPreferredMarkets(
    Iterable<String> marketIds, {
    bool forceSync = true,
  }) async {
    // Eskiden burada marketfiyati.org.tr'nin konum icin dondurdugu 6 marketle
    // intersect aliniyordu; bu Supabase backend geldikten sonra 25 marketlik
    // secimden 5'e dusuyordu. Artik kullanicinin backend'den secimlerinin
    // aynen kaydedilmesini istiyoruz — ürün datasi zaten latest_prices'tan
    // geliyor, marketfiyati konum listesiyle kisitlamanin anlami yok.
    final normalizedMarkets = normalizeMarketIds(marketIds)
        .toSet()
        .toList()
      ..sort();
    final previousMarkets = normalizeMarketIds(_preferences.preferredMarkets)
        .toSet()
        .toList()
      ..sort();

    if (listEquals(normalizedMarkets, previousMarkets)) {
      return;
    }

    _preferences = _preferences.copyWith(preferredMarkets: normalizedMarkets);
    await _refreshMarketFiyatiSessionForPreferredMarkets();
    await _savePreferences();

    if (forceSync) {
      await syncPreferredActuellerCatalog(force: true);
      return;
    }

    notifyListeners();
  }

  Future<List<MarketFiyatiLocationSuggestion>> searchMarketFiyatiLocations(
    String query,
  ) {
    return _marketFiyatiSourceService.searchLocationSuggestions(words: query);
  }

  Future<void> setMarketFiyatiLocation(
    MarketFiyatiLocationSuggestion suggestion, {
    int nearestDistance = 20,
    int sessionDistance = 20,
  }) async {
    final nearestDepots = await _marketFiyatiSourceService.fetchNearestDepots(
      latitude: suggestion.latitude,
      longitude: suggestion.longitude,
      distance: nearestDistance,
    );

    _marketFiyatiAvailableMarketIds =
        _extractAvailableOfficialMarketIdsFromNearestDepots(nearestDepots);
    // NOT: preferredMarkets kullanicinin acik tercihi; konum kisitlamasiyla
    // silmiyoruz. Supabase backend modunda o konumda olmayan zincirler de
    // gecerli olabiliyor. Depot filtresi lokal kalsin.
    final preferredMarketIds =
        normalizeMarketIds(_preferences.preferredMarkets).toSet();
    final filteredDepots = preferredMarketIds.isEmpty
        ? nearestDepots
        : nearestDepots.where((depot) {
            final normalizedMarketId =
                normalizeMarketId(depot.marketName) ?? depot.marketName;
            return preferredMarketIds.contains(normalizedMarketId);
          }).toList();

    debugPrint(
      '[Catalog Location] "${suggestion.displayLabel}" '
      'nearest=${nearestDepots.length}, '
      'filtered=${filteredDepots.length}, '
      'markets=[${_summarizeDepots(nearestDepots.map((depot) => depot.id))}]',
    );

    final session = _marketFiyatiSourceService.buildSessionFromSuggestion(
      suggestion: suggestion,
      depots: filteredDepots.isEmpty ? nearestDepots : filteredDepots,
      distance: sessionDistance,
      maxDepots: _marketFiyatiMaxDepots,
    );

    if (!session.isReady) {
      throw Exception('Seçilen konum için yakın market bulunamadı.');
    }

    _preferences = _preferences.copyWith(marketFiyatiSession: session);
    _clearActuellerCatalogState();
    final hasPreferredMarkets = _preferences.preferredMarkets.isNotEmpty;
    _actuellerCatalogSyncMessage = hasPreferredMarkets
        ? 'Yakındaki market ürünleri hazırlanıyor.'
        : 'Konum hazır. Şimdi marketlerini seç.';
    await _savePreferences();
    notifyListeners();

    if (!hasPreferredMarkets) {
      return;
    }

    Future<void>.microtask(() async {
      try {
        await syncPreferredActuellerCatalog(force: true);
      } catch (_) {}
    });
  }

  Future<void> clearMarketFiyatiLocation() async {
    _preferences = _preferences.copyWith(clearMarketFiyatiSession: true);
    _marketFiyatiAvailableMarketIds = const [];
    _clearActuellerCatalogState();
    _actuellerCatalogSyncMessage = 'Önce konumunu seç.';
    await _savePreferences();
    notifyListeners();
  }

  Future<void> syncPreferredActuellerCatalogIfDue() async {
    await syncPreferredActuellerCatalog();
  }

  Future<void> syncPreferredActuellerCatalog({bool force = false}) async {
    final selectedMarkets = _preferences.preferredMarkets;
    final session = marketFiyatiSession;

    if (selectedMarkets.isEmpty || session == null) {
      _clearActuellerCatalogState();
      _actuellerCatalogSyncMessage = session == null
          ? 'Önce konumunu seç.'
          : 'Konum hazır. Şimdi marketlerini seç.';
      await _savePreferences();
      notifyListeners();
      return;
    }

    // PRIMARY: Supabase'den tum 7 marketin urunlerini cek. Backend cron
    // marketfiyati + sok_direct + hakmar_express'i Supabase'e yazar; UI bu
    // hazir veriyi okur (canli marketfiyati API'sine bagimli degil).
    if (SupabaseService.instance.isReady) {
      try {
        final ok = await _syncSupabaseCatalogOptimized(
          marketIds: selectedMarkets,
          force: force,
        );
        if (ok) {
          return;
        }
      } catch (err) {
        debugPrint('[Catalog Sync] Supabase primary failed: $err');
      }
    }

    // FALLBACK: marketfiyati canli API. Supabase hazir degilse veya bos
    // donerse devreye girer.
    await _syncMarketFiyatiCatalogOptimized(force: force);
  }

  /// Supabase'den 12 kok kategori uzerinden secili marketlerin tum
  /// urunlerini cekip aktuel catalog state'ine yazar. Basariyla preview
  /// olusturulduysa true; bos donerse false (caller marketfiyati
  /// fallback'ine duser).
  Future<bool> _syncSupabaseCatalogOptimized({
    required List<String> marketIds,
    required bool force,
  }) async {
    if (_isActuellerCatalogSyncing) {
      return true;
    }
    _isActuellerCatalogSyncing = true;
    _actuellerCatalogSyncMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final cacheKey = 'supabase::${marketIds.join(',')}';
      if (!force &&
          _officialCatalogCacheKey == cacheKey &&
          _officialCatalogAllItemsCache != null &&
          _officialCatalogAllItemsCache!.isNotEmpty) {
        await _applyOfficialCatalogItems(
          _officialCatalogAllItemsCache!,
          syncedAt: now,
        );
        return true;
      }

      // Supabase categories tablosundaki 12 kok kategori. browseCategoryItems
      // RPC'si parent verilince path prefix ile alt kategorileri de toplar.
      const rootCategoryIds = <String>[
        'gida',
        'icecek',
        'sut-urunleri',
        'et-tavuk',
        'meyve-sebze',
        'firin',
        'atistirmalik',
        'kahvaltilik',
        'dondurulmus',
        'bebek',
        'kisisel-bakim',
        'temizlik',
      ];

      debugPrint(
        '[Catalog Sync][supabase] Starting for ${marketIds.length} markets '
        '${marketIds.toList()}',
      );

      final allItems = <ActuellerCatalogItem>[];
      final seenKeys = <String>{};
      for (final categoryId in rootCategoryIds) {
        try {
          final results = await SupabaseService.instance.browseCategoryItems(
            categoryIds: [categoryId],
            marketIds: marketIds,
            limit: 1000,
          );
          var added = 0;
          for (final item in results) {
            if (seenKeys.add(item.id)) {
              allItems.add(item);
              added++;
            }
          }
          debugPrint(
            '[Catalog Sync][supabase] "$categoryId" '
            'fetched=${results.length} new=$added',
          );
        } catch (err) {
          debugPrint('[Catalog Sync][supabase] "$categoryId" FAIL: $err');
        }
      }

      if (allItems.isEmpty) {
        debugPrint(
          '[Catalog Sync][supabase] 0 item — fallback marketfiyati gerekli',
        );
        return false;
      }

      debugPrint(
        '[Catalog Sync][supabase] DONE total=${allItems.length} '
        'across ${rootCategoryIds.length} categories',
      );
      _officialCatalogCacheKey = cacheKey;
      _officialCatalogAllItemsCache = allItems;
      await _applyOfficialCatalogItems(allItems, syncedAt: now);
      return true;
    } catch (error) {
      _clearActuellerCatalogState();
      _actuellerCatalogSyncMessage =
          repairTurkishText(error.toString().replaceFirst('Exception: ', ''));
      return false;
    } finally {
      _isActuellerCatalogSyncing = false;
      await _savePreferences();
      notifyListeners();
    }
  }

  Future<List<ActuellerCatalogItem>> fetchOfficialItemsForSourceCategories({
    required Iterable<String> sourceCategories,
    String? categoryId,
    bool force = false,
  }) async {
    if (_preferences.preferredMarkets.isEmpty) {
      return const [];
    }

    // Supabase hazirsa ve cagiran bize Supabase category id verdiyse (Ornegin
    // 'meyve-sebze', 'kagit', 'sut-urunleri') once backend'den cek. Backend
    // bos donerse (henuz o kategoride scrape edilmis urun yok) marketfiyati
    // fallback'i devreye girer.
    if (categoryId != null &&
        categoryId.isNotEmpty &&
        SupabaseService.instance.isReady) {
      try {
        final backendResults =
            await SupabaseService.instance.browseCategoryItems(
          categoryIds: [categoryId],
          marketIds: _preferences.preferredMarkets,
        );
        if (backendResults.isNotEmpty) {
          final cacheKey = 'browse::supabase::'
              '${_preferences.preferredMarkets.join(',')}::$categoryId';
          _officialCatalogCache[cacheKey] =
              List<ActuellerCatalogItem>.unmodifiable(backendResults);
          return _officialCatalogCache[cacheKey]!;
        }
      } catch (err) {
        debugPrint('[Catalog Browse] Supabase path failed: $err');
        // marketfiyati fallback asagida devam eder
      }
    }

    final session = marketFiyatiSession;
    if (session == null) {
      return const [];
    }

    final orderedCategories = <String>[];
    final normalizedCategories = <String>{};
    for (final value in sourceCategories) {
      final repairedValue = repairTurkishText(value).trim();
      final normalizedValue = _normalizeOfficialKeyword(repairedValue);
      if (normalizedValue.isEmpty ||
          !normalizedCategories.add(normalizedValue)) {
        continue;
      }
      orderedCategories.add(repairedValue);
    }

    if (orderedCategories.isEmpty) {
      return const [];
    }

    final cacheKey = [
      'detail',
      _buildOfficialCatalogCacheKey(session),
      ...orderedCategories.map(_normalizeOfficialKeyword),
    ].join('::');

    if (!force && _officialCatalogCache.containsKey(cacheKey)) {
      return _officialCatalogCache[cacheKey]!;
    }

    final uniqueItems = <String, ActuellerCatalogItem>{};
    for (var index = 0; index < orderedCategories.length; index++) {
      final category = orderedCategories[index];
      final result = await _fetchOfficialCategoryItemsWithFacets(
        session: session,
        category: category,
        logLabel: 'detail',
      );
      for (final item in result.items) {
        uniqueItems[item.id] = item;
      }
      if (index < orderedCategories.length - 1) {
        await Future<void>.delayed(_officialCatalogInterBatchDelay);
      }
    }

    final normalizedItems = _normalizeOfficialCatalogItems(
      uniqueItems.values.toList(growable: false),
    );
    _officialCatalogCache[cacheKey] =
        List<ActuellerCatalogItem>.unmodifiable(normalizedItems);
    return _officialCatalogCache[cacheKey]!;
  }

  Future<List<ActuellerCatalogItem>> searchOfficialCatalogItems(
    String query, {
    bool force = false,
  }) async {
    final repairedQuery = repairTurkishText(query).trim();
    if (_preferences.preferredMarkets.isEmpty || repairedQuery.isEmpty) {
      return const [];
    }

    // Supabase hazirsa once backend'den ara. Konum/marketfiyati gerekmiyor —
    // latest_prices MV tum Turkiye'de calisir. Supabase sonuc dondururse
    // bunu cache'leyip doneriz; bos donerse (henuz o urunler scrape edilmedi)
    // marketfiyati.org.tr fallback'i denenir.
    if (SupabaseService.instance.isReady) {
      try {
        final backendResults = await SupabaseService.instance.searchCatalogItems(
          query: repairedQuery,
          marketIds: _preferences.preferredMarkets,
        );
        if (backendResults.isNotEmpty) {
          final cacheKey = 'search::supabase::'
              '${_preferences.preferredMarkets.join(',')}::$repairedQuery';
          _officialCatalogCache[cacheKey] =
              List<ActuellerCatalogItem>.unmodifiable(backendResults);
          return _officialCatalogCache[cacheKey]!;
        }
      } catch (err) {
        debugPrint('[Catalog Search] Supabase path failed: $err');
        // marketfiyati fallback asagida devam eder
      }
    }

    final session = marketFiyatiSession;
    if (session == null) {
      return const [];
    }

    final normalizedQuery = _normalizeOfficialKeyword(repairedQuery);
    final cacheKey =
        'search::${_buildOfficialCatalogCacheKey(session)}::$normalizedQuery';
    if (!force && _officialCatalogCache.containsKey(cacheKey)) {
      return _officialCatalogCache[cacheKey]!;
    }

    final uniqueItems = <String, ActuellerCatalogItem>{};

    Future<void> collectSearchPages() async {
      var page = 0;
      var totalFetched = 0;
      var totalFound = 0;
      var stalePageCount = 0;

      do {
        final response = await _marketFiyatiSourceService.search(
          session: session,
          keywords: repairedQuery,
          page: page,
          size: _officialCatalogAllProductsPageSize,
        );
        totalFound = response.numberOfFound;

        final pageItems = _marketFiyatiSourceService.toCatalogItems(
          response,
          sourceLabel: 'Market FiyatÄ±',
        );
        final previousUniqueCount = uniqueItems.length;
        for (final item in pageItems) {
          uniqueItems[item.id] = item;
        }
        final addedThisPage = uniqueItems.length - previousUniqueCount;

        totalFetched += response.content.length;
        page += 1;

        if (response.content.isEmpty) {
          break;
        }
        if (addedThisPage == 0) {
          stalePageCount += 1;
        } else {
          stalePageCount = 0;
        }
        if (stalePageCount >= 2) {
          break;
        }
      } while (totalFetched < totalFound &&
          page < _officialCatalogCategoryMaxPageCount);
    }

    try {
      await collectSearchPages();
    } catch (error) {
      debugPrint(
          '[Catalog Search] "$repairedQuery" primary search failed: $error');
    }

    if (uniqueItems.isEmpty) {
      final fallback = await _fetchOfficialCategoryItemsWithFacets(
        session: session,
        category: repairedQuery,
        logLabel: 'search',
      );
      for (final item in fallback.items) {
        uniqueItems[item.id] = item;
      }
    }

    final normalizedItems = _normalizeOfficialCatalogItems(
      uniqueItems.values.toList(growable: false),
    );
    _officialCatalogCache[cacheKey] =
        List<ActuellerCatalogItem>.unmodifiable(normalizedItems);
    return _officialCatalogCache[cacheKey]!;
  }

  Future<List<ActuellerCatalogItem>> fetchOfficialSimilarProducts(
    ActuellerCatalogItem item,
  ) async {
    // PRIMARY 1: Supabase EXACT product_id match. ActuellerCatalogItem.
    // sourceProductId Supabase tarafindan UUID (36 char) olarak set edilir;
    // marketfiyati'dan gelen item'larda bu UUID degil, marketfiyati'nin
    // kendi ID'si olur (kisa). UUID ise exact match (RPC), aksi halde
    // text search'e dus.
    if (SupabaseService.instance.isReady) {
      final pid = item.sourceProductId;
      if (pid != null && pid.length == 36) {
        try {
          final exact = await SupabaseService.instance
              .fetchProductAcrossMarkets(
            productId: pid,
            marketIds: _preferences.preferredMarkets.isEmpty
                ? null
                : _preferences.preferredMarkets,
          );
          if (exact.isNotEmpty) {
            return exact;
          }
        } catch (err) {
          debugPrint('[fetchOfficialSimilarProducts] exact failed: $err');
        }
      }
    }

    // PRIMARY 2: Supabase text search (fuzzy, marketfiyati origin item'lar icin).
    // PRIMARY: Supabase searchCatalogItems — RPC search_products_with_prices
    // ile ayni canonical_name/brand match edilen tum marketlerin son fiyati.
    // Marketfiyati'nin paket-size bazli bulanik match'inden cok daha temiz.
    if (SupabaseService.instance.isReady) {
      try {
        final query = item.productTitle.trim();
        if (query.isNotEmpty) {
          final results = await SupabaseService.instance.searchCatalogItems(
            query: query,
            marketIds: _preferences.preferredMarkets.isEmpty
                ? null
                : _preferences.preferredMarkets,
            limit: 20,
          );
          if (results.isNotEmpty) {
            return results;
          }
        }
      } catch (err) {
        debugPrint('[fetchOfficialSimilarProducts] Supabase failed: $err');
      }
    }

    // FALLBACK: marketfiyati canli API (eski davranis).
    final session = marketFiyatiSession;
    final sourceProductId = item.sourceProductId;
    if (session == null || sourceProductId == null || sourceProductId.isEmpty) {
      return const [];
    }
    final response = await _marketFiyatiSourceService.searchSimilarProduct(
      session: session,
      id: sourceProductId,
      keywords: item.productTitle,
    );
    return _marketFiyatiSourceService.toCatalogItems(response);
  }

  Future<bool> addShoppingListEntry(
    ActuellerCatalogItem item, {
    List<ActuellerCatalogItem> alternatives = const [],
  }) async {
    final identityKey = _shoppingIdentityForItem(item);
    final dedupedAlternatives = _dedupeAlternativeItems(
      item,
      alternatives,
    );
    final existingIndex = _shoppingListEntries.indexWhere(
      (entry) => entry.identityKey == identityKey,
    );
    final entryId = existingIndex >= 0
        ? _shoppingListEntries[existingIndex].id
        : '${DateTime.now().microsecondsSinceEpoch}-$identityKey';

    final entry = MarketShoppingListEntry(
      id: entryId,
      identityKey: identityKey,
      selectedItem: item,
      alternativeItems: existingIndex >= 0
          ? _dedupeAlternativeItems(
              item,
              [
                ..._shoppingListEntries[existingIndex].alternativeItems,
                ...dedupedAlternatives,
              ],
            )
          : dedupedAlternatives,
      addedAt: DateTime.now(),
    );

    final isNew = existingIndex < 0;
    if (isNew) {
      _shoppingListEntries.insert(0, entry);
    } else {
      _shoppingListEntries[existingIndex] = entry;
      _shoppingListEntries
        ..removeAt(existingIndex)
        ..insert(0, entry);
    }

    await _savePreferences();
    notifyListeners();
    return isNew;
  }

  Future<void> removeShoppingListEntry(String entryId) async {
    _shoppingListEntries.removeWhere((entry) => entry.id == entryId);
    await _savePreferences();
    notifyListeners();
  }

  Future<void> clearShoppingList() async {
    _shoppingListEntries.clear();
    await _savePreferences();
    notifyListeners();
  }

  MarketShoppingVisitPlan buildShoppingVisitPlan(
      Iterable<String> targetMarketIds) {
    final normalizedTargets = normalizeMarketIds(targetMarketIds.toList());
    final targetSet = normalizedTargets.toSet();
    if (targetSet.isEmpty || _shoppingListEntries.isEmpty) {
      return const MarketShoppingVisitPlan(
        targetMarketIds: [],
        groups: [],
        redirectedAssignments: [],
        unresolvedEntries: [],
      );
    }

    final groupedAssignments = <String, List<MarketShoppingRouteAssignment>>{};
    final marketNames = <String, String>{};
    final redirectedAssignments = <MarketShoppingRouteAssignment>[];
    final unresolvedEntries = <MarketShoppingListEntry>[];

    for (final entry in _shoppingListEntries) {
      final originalItem = entry.selectedItem;
      final originalMarketId = _marketIdFromName(originalItem.marketName);
      ActuellerCatalogItem? assignedItem;

      if (targetSet.contains(originalMarketId)) {
        assignedItem = originalItem;
      } else {
        final matchingAlternatives = entry.allItems.where((candidate) {
          final marketId = _marketIdFromName(candidate.marketName);
          return targetSet.contains(marketId);
        }).toList()
          ..sort((a, b) => a.price.compareTo(b.price));

        if (matchingAlternatives.isNotEmpty) {
          assignedItem = matchingAlternatives.first;
        }
      }

      if (assignedItem == null) {
        unresolvedEntries.add(entry);
        continue;
      }

      final assignedMarketId = _marketIdFromName(assignedItem.marketName);
      final assignment = MarketShoppingRouteAssignment(
        entry: entry,
        assignedItem: assignedItem,
        usesSubstitute: !_isSameCatalogChoice(originalItem, assignedItem),
      );

      groupedAssignments
          .putIfAbsent(assignedMarketId, () => [])
          .add(assignment);
      marketNames[assignedMarketId] =
          _displayMarketName(assignedItem.marketName);

      if (assignment.usesSubstitute) {
        redirectedAssignments.add(assignment);
      }
    }

    final groups = normalizedTargets
        .where(groupedAssignments.containsKey)
        .map(
          (marketId) => MarketShoppingVisitGroup(
            marketId: marketId,
            marketName: marketNames[marketId] ?? marketId,
            assignments: List<MarketShoppingRouteAssignment>.unmodifiable(
              groupedAssignments[marketId]!
                ..sort(
                  (a, b) => a.assignedItem.productTitle.compareTo(
                    b.assignedItem.productTitle,
                  ),
                ),
            ),
          ),
        )
        .toList();

    return MarketShoppingVisitPlan(
      targetMarketIds: normalizedTargets,
      groups: groups,
      redirectedAssignments: redirectedAssignments,
      unresolvedEntries: unresolvedEntries,
    );
  }

  Future<void> _syncMarketFiyatiCatalogOptimized({bool force = false}) async {
    final session = marketFiyatiSession;
    if (session == null) {
      _clearActuellerCatalogState();
      _actuellerCatalogSyncMessage =
          'Resm\u00ee fiyatlar i\u00e7in \u00f6nce konum se\u00e7.';
      notifyListeners();
      return;
    }
    if (_preferences.preferredMarkets.isEmpty) {
      _clearActuellerCatalogState();
      _actuellerCatalogSyncMessage =
          'Konum haz\u0131r. \u015eimdi marketlerini se\u00e7.';
      notifyListeners();
      return;
    }
    if (_isActuellerCatalogSyncing) {
      return;
    }

    _isActuellerCatalogSyncing = true;
    _actuellerCatalogSyncMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final cacheKey = _buildOfficialCatalogCacheKey(session);
      if (!force &&
          _officialCatalogCacheKey == cacheKey &&
          _officialCatalogAllItemsCache != null) {
        _applyOfficialCatalogItems(
          _officialCatalogAllItemsCache!,
          syncedAt: now,
        );
        return;
      }

      debugPrint(
        '[Catalog Preview] Starting sync for ${session.depots.length} depots '
        '[${_summarizeDepots(session.depots)}]',
      );
      final officialCategories = await _loadOfficialCategoryTree();
      final previewRootCategories =
          _buildOfficialRootCategoryNames(officialCategories);
      final previewItems = await _fetchOfficialPreviewItemsForRoots(
        session: session,
        rootCategories: previewRootCategories,
      );
      debugPrint(
        '[Catalog Preview] Root categories: ${previewRootCategories.length}, '
        'preview items: ${previewItems.length}',
      );
      _officialCatalogCacheKey = cacheKey;
      _officialCatalogAllItemsCache = previewItems;
      await _applyOfficialCatalogItems(
        previewItems,
        syncedAt: now,
      );
    } catch (error) {
      _clearActuellerCatalogState();
      _actuellerCatalogSyncMessage =
          repairTurkishText(error.toString().replaceFirst('Exception: ', ''));
      rethrow;
    } finally {
      _isActuellerCatalogSyncing = false;
      await _savePreferences();
      notifyListeners();
    }
  }

  Future<_OfficialCategoryFetchResult> _fetchOfficialCategoryItemsWithFacets({
    required MarketFiyatiSession session,
    required String category,
    String? logLabel,
  }) async {
    final collectedItems = <ActuellerCatalogItem>[];
    final discoveredKeywords = <String>{};
    var page = 0;
    var totalFetched = 0;
    var totalFound = 0;
    var stalePageCount = 0;

    do {
      final response = await _marketFiyatiSourceService.searchByCategories(
        session: session,
        keywords: category,
        page: page,
        size: _officialCatalogCategoryPageSize,
      );
      totalFound = response.numberOfFound;
      discoveredKeywords.addAll(_extractOfficialFacetKeywords(response));

      collectedItems.addAll(
        _marketFiyatiSourceService.toCatalogItems(
          response,
          sourceLabel: 'Market Fiyat\u0131',
        ),
      );
      final addedThisPage = response.content.length;

      totalFetched += response.content.length;
      page += 1;

      if (response.content.isEmpty) {
        break;
      }
      if (addedThisPage == 0) {
        stalePageCount += 1;
      } else {
        stalePageCount = 0;
      }
      if (stalePageCount >= 2) {
        break;
      }
    } while (totalFetched < totalFound &&
        page < _officialCatalogCategoryMaxPageCount);

    return _OfficialCategoryFetchResult(
      items: collectedItems,
      discoveredKeywords: discoveredKeywords.toList(growable: false),
    );
  }

  Future<List<ActuellerCatalogItem>> _fetchOfficialPreviewItemsForRoots({
    required MarketFiyatiSession session,
    required Iterable<String> rootCategories,
  }) async {
    final uniqueItems = <String, ActuellerCatalogItem>{};
    final orderedRoots = <String>[];
    final seenRoots = <String>{};
    for (final category in rootCategories) {
      final repairedCategory = repairTurkishText(category).trim();
      if (repairedCategory.isEmpty || !seenRoots.add(repairedCategory)) {
        continue;
      }
      orderedRoots.add(repairedCategory);
    }

    for (var index = 0; index < orderedRoots.length; index++) {
      final category = orderedRoots[index];
      final items = await _fetchOfficialCategoryPreviewItems(
        session: session,
        category: category,
        logLabel: 'preview',
      );
      for (final item in items) {
        uniqueItems[item.id] = item;
      }
      if (index < orderedRoots.length - 1) {
        await Future<void>.delayed(_officialCatalogInterBatchDelay);
      }
    }

    return _normalizeOfficialCatalogItems(
      uniqueItems.values.toList(growable: false),
    );
  }

  Future<List<ActuellerCatalogItem>> _fetchOfficialCategoryPreviewItems({
    required MarketFiyatiSession session,
    required String category,
    required String logLabel,
  }) async {
    for (final menuCategory in const [true, false]) {
      try {
        final response = await _marketFiyatiSourceService.searchByCategories(
          session: session,
          keywords: category,
          page: 0,
          size: _officialCatalogPreviewPageSize,
          menuCategory: menuCategory,
        );
        final items = _marketFiyatiSourceService.toCatalogItems(
          response,
          sourceLabel: 'Market FiyatÄ±',
        );
        if (items.isNotEmpty) {
          debugPrint(
            '[Catalog Preview][$logLabel] "${repairTurkishText(category)}" '
            '${menuCategory ? 'menu' : 'all'}: '
            '${items.length}/${response.numberOfFound}',
          );
          return items;
        }
      } catch (error) {
        debugPrint(
          '[Catalog Preview][$logLabel] "${repairTurkishText(category)}" '
          '${menuCategory ? 'menu' : 'all'} failed: $error',
        );
      }
    }

    return const [];
  }

  Future<List<MarketFiyatiOfficialCategory>> _loadOfficialCategoryTree() async {
    final cachedTree = _officialCategoryTreeCache;
    if (cachedTree != null && cachedTree.isNotEmpty) {
      return cachedTree;
    }

    try {
      final officialCategories =
          await _marketFiyatiSourceService.fetchOfficialCategoriesResilient();
      _officialCategoryTreeCache =
          List<MarketFiyatiOfficialCategory>.unmodifiable(officialCategories);
      return _officialCategoryTreeCache!;
    } catch (error) {
      debugPrint('[Catalog Sync] Official category tree unavailable: $error');
      return const [];
    }
  }

  List<String> _buildOfficialCatalogSeedKeywords({
    required List<MarketFiyatiOfficialCategory> officialCategories,
    required Iterable<String> discoveredKeywords,
  }) {
    final normalizedSeeds = <String>{};
    final orderedSeeds = <String>[];
    final knownTaxonomy = <String, String>{
      for (final seed in _officialCatalogSourceSeeds)
        _normalizeOfficialKeyword(seed.repairedSubcategory):
            seed.repairedSubcategory,
    };
    final officialSubcategories = <String, String>{};

    void addSeed(String value) {
      final repairedValue = repairTurkishText(value).trim();
      if (repairedValue.isEmpty) {
        return;
      }

      final normalizedValue = _normalizeOfficialKeyword(repairedValue);
      if (normalizedValue.isEmpty || !normalizedSeeds.add(normalizedValue)) {
        return;
      }

      orderedSeeds.add(repairedValue);
    }

    for (final category in officialCategories) {
      for (final subcategory in category.subcategories) {
        final repairedSubcategory = repairTurkishText(subcategory).trim();
        final normalizedSubcategory =
            _normalizeOfficialKeyword(repairedSubcategory);
        if (normalizedSubcategory.isEmpty) {
          continue;
        }
        officialSubcategories[normalizedSubcategory] = repairedSubcategory;
      }
    }

    if (officialSubcategories.isEmpty) {
      for (final seed in _officialCatalogSourceSeeds) {
        addSeed(seed.repairedSubcategory);
      }
    } else {
      for (final seed in _officialCatalogSourceSeeds) {
        final normalizedSeed =
            _normalizeOfficialKeyword(seed.repairedSubcategory);
        final officialName = officialSubcategories[normalizedSeed];
        if (officialName != null) {
          addSeed(officialName);
        }
      }

      for (final officialName in officialSubcategories.values) {
        addSeed(officialName);
      }
    }

    for (final keyword in discoveredKeywords) {
      final repairedKeyword = repairTurkishText(keyword).trim();
      final normalizedKeyword = _normalizeOfficialKeyword(repairedKeyword);
      if (normalizedKeyword.isEmpty) {
        continue;
      }

      final officialName = officialSubcategories[normalizedKeyword] ??
          knownTaxonomy[normalizedKeyword];
      if (officialName != null) {
        addSeed(officialName);
      }
    }

    return orderedSeeds;
  }

  int _officialCategorySeedCount() {
    final officialCategories = _officialCategoryTreeCache;
    if (officialCategories == null || officialCategories.isEmpty) {
      return _officialCatalogSourceSeeds.length;
    }

    return _buildOfficialCatalogSeedKeywords(
      officialCategories: officialCategories,
      discoveredKeywords: const [],
    ).length;
  }

  List<String> _buildOfficialRootCategoryNames(
    List<MarketFiyatiOfficialCategory> officialCategories,
  ) {
    final orderedRoots = <String>[];
    final normalizedRoots = <String>{};

    void addRoot(String value) {
      final repairedValue = repairTurkishText(value).trim();
      final normalizedValue = _normalizeOfficialKeyword(repairedValue);
      if (normalizedValue.isEmpty || !normalizedRoots.add(normalizedValue)) {
        return;
      }
      orderedRoots.add(repairedValue);
    }

    if (officialCategories.isNotEmpty) {
      for (final category in officialCategories) {
        addRoot(category.name);
      }
      if (orderedRoots.isNotEmpty) {
        return orderedRoots;
      }
    }

    for (final seed in _officialCatalogSourceSeeds) {
      addRoot(seed.repairedRootCategory);
    }
    return orderedRoots;
  }

  String _buildOfficialCatalogCacheKey(MarketFiyatiSession session) {
    final depotKey = [...session.depots]..sort();
    final preferredMarkets = [..._preferences.preferredMarkets]..sort();
    return [
      session.locationLabel,
      session.latitude.toStringAsFixed(6),
      session.longitude.toStringAsFixed(6),
      session.distance.toString(),
      preferredMarkets.join('|'),
      depotKey.join('|'),
    ].join('::');
  }

  List<String> _extractOfficialFacetKeywords(
    MarketFiyatiSearchResponse response,
  ) {
    final facetMap = response.facetMap;
    if (facetMap == null || facetMap.isEmpty) {
      return const [];
    }

    final discovered = <String>{};

    void collectFacetValues(String key) {
      final values = facetMap[key];
      if (values is! List) {
        return;
      }

      for (final entry in values.whereType<Map<String, dynamic>>()) {
        final count = (entry['count'] as num?)?.toInt() ??
            int.tryParse(entry['count']?.toString() ?? '') ??
            0;
        if (count <= 0) {
          continue;
        }

        final rawName = entry['name']?.toString() ?? '';
        final name = repairTurkishText(rawName).trim();
        if (name.isEmpty) {
          continue;
        }

        final normalizedName = _normalizeOfficialKeyword(name);
        if (normalizedName.isEmpty) {
          continue;
        }

        discovered.add(name);
      }
    }

    collectFacetValues('sub_category');
    collectFacetValues('main_category');
    collectFacetValues('menu_category');
    collectFacetValues('category');

    return discovered.toList()..sort();
  }

  String _normalizeOfficialKeyword(String value) {
    return repairTurkishText(value)
        .toLowerCase()
        .replaceAll('\u00e7', 'c')
        .replaceAll('\u011f', 'g')
        .replaceAll('\u0131', 'i')
        .replaceAll('\u00f6', 'o')
        .replaceAll('\u015f', 's')
        .replaceAll('\u00fc', 'u')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  String _summarizeDepots(Iterable<String> depotIds) {
    final counts = <String, int>{};
    for (final depotId in depotIds) {
      final rawMarketId = depotId.split('-').first;
      final normalizedMarketId = normalizeMarketId(rawMarketId) ?? rawMarketId;
      final marketName = displayNameForMarket(normalizedMarketId);
      final key = marketName.isEmpty ? normalizedMarketId : marketName;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    final parts = counts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return parts.map((entry) => '${entry.key}:${entry.value}').join(', ');
  }

  Future<void> _applyOfficialCatalogItems(
    List<ActuellerCatalogItem> catalogItems, {
    required DateTime syncedAt,
  }) async {
    final normalizedItems = _normalizeOfficialCatalogItems(catalogItems);
    final sortedItems = [...normalizedItems]..sort((a, b) {
        final categoryCompare = (a.sourceMenuCategory ?? '').compareTo(
          b.sourceMenuCategory ?? '',
        );
        if (categoryCompare != 0) return categoryCompare;
        final marketCompare = a.marketName.compareTo(b.marketName);
        if (marketCompare != 0) return marketCompare;
        return a.productTitle.compareTo(b.productTitle);
      });

    _lastActuellerScanResult = ActuellerScanResult(
      rawText: sortedItems.map((item) => item.productTitle).join('\n'),
      blocks: sortedItems.map((item) => item.productTitle).toList(),
      catalogItems: sortedItems,
      deals: const [],
      unmatchedBlocks: const [],
      detectedStore: null,
      sourceLabel: 'Market Fiyat\u0131',
      capturedImagePath: null,
      scannedAt: syncedAt,
      confidence: sortedItems.isEmpty ? 0 : 0.9,
    );
    _lastActuellerCatalogSyncAt = syncedAt;
    _lastActuellerCatalogBrochureCount =
        sortedItems.isEmpty ? 0 : _officialCategorySeedCount();
    _actuellerCatalogSyncMessage = sortedItems.isEmpty
        ? 'Se\u00e7ili konum ve marketlerde \u00fcr\u00fcn bulunamad\u0131.'
        : null;

    // Record price history from freshly synced items.
    if (sortedItems.isNotEmpty) {
      _priceHistories = await _priceHistoryService.recordFromCatalogItems(
        items: sortedItems,
        existing: _priceHistories,
      );
      // Check price watches against the fresh catalog.
      await _checkPriceWatches(sortedItems);
    }
  }

  Future<void> _refreshMarketFiyatiSessionForPreferredMarkets() async {
    final storedSession = _preferences.marketFiyatiSession;
    if (storedSession == null) {
      return;
    }

    final effectiveDistance =
        storedSession.distance < 20 ? 20 : storedSession.distance;

    final nearestDepots = await _marketFiyatiSourceService.fetchNearestDepots(
      latitude: storedSession.latitude,
      longitude: storedSession.longitude,
      distance: effectiveDistance,
    );

    _marketFiyatiAvailableMarketIds =
        _extractAvailableOfficialMarketIdsFromNearestDepots(nearestDepots);
    // preferredMarkets'i ezmiyoruz; marketfiyati konum kisitlamasi sadece
    // depot filtreleme icin kullanilir.
    final preferredMarketIds =
        normalizeMarketIds(_preferences.preferredMarkets).toSet();
    final filteredDepots = preferredMarketIds.isEmpty
        ? nearestDepots
        : nearestDepots.where((depot) {
            final normalizedMarketId =
                normalizeMarketId(depot.marketName) ?? depot.marketName;
            return preferredMarketIds.contains(normalizedMarketId);
          }).toList();

    final rebuiltSession = _marketFiyatiSourceService.buildSessionFromNearest(
      locationLabel: storedSession.locationLabel,
      latitude: storedSession.latitude,
      longitude: storedSession.longitude,
      depots: filteredDepots.isEmpty ? nearestDepots : filteredDepots,
      distance: effectiveDistance,
      maxDepots: _marketFiyatiMaxDepots,
    );

    _preferences = _preferences.copyWith(
      marketFiyatiSession: rebuiltSession.isReady ? rebuiltSession : null,
    );
  }

  void _clearActuellerCatalogState() {
    _lastActuellerScanResult = null;
    _lastActuellerCatalogSyncAt = null;
    _lastActuellerCatalogBrochureCount = 0;
    _officialCatalogCacheKey = null;
    _officialCatalogAllItemsCache = null;
    _officialCatalogCache.clear();
    _officialCatalogFacetKeywordCache.clear();
  }

  List<String> _extractAvailableOfficialMarketIdsFromNearestDepots(
    Iterable<MarketFiyatiNearestDepot> depots,
  ) {
    final ids = <String>{};
    for (final depot in depots) {
      final marketId = normalizeMarketId(depot.marketName);
      if (marketId != null && marketId.isNotEmpty) {
        ids.add(marketId);
      }
    }
    final sorted = ids.toList()
      ..sort(
        (a, b) => (marketDisplayNamesById[a] ?? a).compareTo(
          marketDisplayNamesById[b] ?? b,
        ),
      );
    return sorted;
  }

  List<String> _extractAvailableOfficialMarketIdsFromDepotIds(
    Iterable<String> depotIds,
  ) {
    final ids = <String>{};
    for (final depotId in depotIds) {
      final rawMarketId = depotId.split('-').first;
      final marketId = normalizeMarketId(rawMarketId);
      if (marketId != null && marketId.isNotEmpty) {
        ids.add(marketId);
      }
    }
    final sorted = ids.toList()
      ..sort(
        (a, b) => (marketDisplayNamesById[a] ?? a).compareTo(
          marketDisplayNamesById[b] ?? b,
        ),
      );
    return sorted;
  }

  String _marketIdFromName(String marketName) {
    return normalizeMarketId(marketName) ?? marketName.toLowerCase().trim();
  }

  String _displayMarketName(String marketName) {
    final id = normalizeMarketId(marketName);
    return id != null ? (marketDisplayNamesById[id] ?? marketName) : marketName;
  }

  String _shoppingIdentityForItem(ActuellerCatalogItem item) {
    final productId = item.sourceProductId;
    if (productId != null && productId.trim().isNotEmpty) {
      return productId.trim();
    }
    return _normalizeShoppingKey(item.productTitle);
  }

  String _normalizeShoppingKey(String value) {
    return value
        .toLowerCase()
        .replaceAll('\u0131', 'i')
        .replaceAll('\u011f', 'g')
        .replaceAll('\u00fc', 'u')
        .replaceAll('\u015f', 's')
        .replaceAll('\u00f6', 'o')
        .replaceAll('\u00e7', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  List<ActuellerCatalogItem> _normalizeOfficialCatalogItems(
    List<ActuellerCatalogItem> items,
  ) {
    final uniqueItems = <String, ActuellerCatalogItem>{};
    for (final item in items) {
      final identity = _officialCatalogIdentityForItem(item);
      final existing = uniqueItems[identity];
      if (existing == null ||
          _shouldReplaceOfficialCatalogItem(item, existing)) {
        uniqueItems[identity] = item;
      }
    }
    return uniqueItems.values.toList(growable: false);
  }

  String _officialCatalogIdentityForItem(ActuellerCatalogItem item) {
    final marketId = _marketIdFromName(item.marketName);
    final sourceProductId = item.sourceProductId?.trim() ?? '';
    final productKey = sourceProductId.isNotEmpty
        ? sourceProductId
        : _normalizeShoppingKey(item.productTitle);
    return '$marketId::$productKey';
  }

  bool _shouldReplaceOfficialCatalogItem(
    ActuellerCatalogItem candidate,
    ActuellerCatalogItem current,
  ) {
    if (candidate.price != current.price) {
      return candidate.price < current.price;
    }

    final candidateCategory = candidate.sourceMenuCategory ?? '';
    final currentCategory = current.sourceMenuCategory ?? '';
    if (candidateCategory.isNotEmpty != currentCategory.isNotEmpty) {
      return candidateCategory.isNotEmpty;
    }

    final candidateDepot = candidate.sourceDepotId?.trim() ?? '';
    final currentDepot = current.sourceDepotId?.trim() ?? '';
    if (candidateDepot.isNotEmpty != currentDepot.isNotEmpty) {
      return candidateDepot.isNotEmpty;
    }

    return candidate.productTitle.length < current.productTitle.length;
  }

  bool _isSameCatalogChoice(
    ActuellerCatalogItem a,
    ActuellerCatalogItem b,
  ) {
    return a.id == b.id;
  }

  List<ActuellerCatalogItem> _dedupeAlternativeItems(
    ActuellerCatalogItem primary,
    List<ActuellerCatalogItem> alternatives,
  ) {
    final seenIds = <String>{primary.id};
    return alternatives.where((item) => seenIds.add(item.id)).toList();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString('market_app_prefs');
    final rawDarkMode = prefs.getBool('dark_mode') ?? false;
    final rawShoppingList = prefs.getString('shopping_list');

    _isDarkMode = rawDarkMode;

    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final decoded = json.decode(rawJson);
        if (decoded is Map<String, dynamic>) {
          _preferences = MarketAppPreferences.fromJson(decoded);
        }
      } catch (_) {}
    }

    if (rawShoppingList != null && rawShoppingList.isNotEmpty) {
      try {
        final decoded = json.decode(rawShoppingList);
        if (decoded is List) {
          _shoppingListEntries
            ..clear()
            ..addAll(
              decoded
                  .whereType<Map<String, dynamic>>()
                  .map(MarketShoppingListEntry.fromJson),
            );
        }
      } catch (_) {}
    }

    final storedSession = _preferences.marketFiyatiSession;
    if (storedSession != null) {
      try {
        final effectiveDistance =
            storedSession.distance < 20 ? 20 : storedSession.distance;
        final nearestDepots =
            await _marketFiyatiSourceService.fetchNearestDepots(
          latitude: storedSession.latitude,
          longitude: storedSession.longitude,
          distance: effectiveDistance,
        );
        _marketFiyatiAvailableMarketIds =
            _extractAvailableOfficialMarketIdsFromNearestDepots(nearestDepots);
      } catch (_) {
        _marketFiyatiAvailableMarketIds =
            _extractAvailableOfficialMarketIdsFromDepotIds(
                storedSession.depots);
      }
      // _loadPreferences: preferredMarkets'i marketfiyati-only listeye
      // daraltmak kullanicinin Supabase tercihlerini (ornegin Hakmar, Metro,
      // Macrocenter) her restart'ta siliyordu. Kaldirildi — normalizeMarketIds
      // save yolunda zaten canonical ID'ye ceviriyor.
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'market_app_prefs', json.encode(_preferences.toJson()));
    await prefs.setBool('dark_mode', _isDarkMode);
    await prefs.setString(
      'shopping_list',
      json.encode(
        _shoppingListEntries.map((entry) => entry.toJson()).toList(),
      ),
    );
  }
}
