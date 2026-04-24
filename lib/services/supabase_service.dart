import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/smart_actueller.dart';
import '../models/supabase_campaign.dart';
import '../models/supabase_latest_price.dart';
import '../models/supabase_market.dart';
import '../models/supabase_product.dart';
import '../utils/product_category.dart';

/// Tum Supabase erisiminin tek giris noktasi.
///
/// - `initialize()` uygulama acilisinda bir kez cagirilir (main.dart).
/// - Public tablolari (markets, products, latest_prices, current_campaigns)
///   anon key ile okur. RLS zaten izin veriyor.
/// - Auth'a baglanmis ozel tablolar (user_watches, notifications) ileride
///   eklendiginde `currentUserId` ile filtrelenir.
/// - Config eksikse `isReady=false` doner ve tum calls bos liste dondurur —
///   boylece offline/dev-time'da app crash etmez.
class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  bool _initialized = false;

  /// Uygulama acilisinda main.dart'ta cagrilir. Idempotent.
  static Future<void> initialize() async {
    if (instance._initialized) return;
    if (!SupabaseConfig.isConfigured) {
      // Config yoksa sessizce geri don — UI offline mode gosterir.
      return;
    }
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      debug: false,
    );
    instance._initialized = true;
  }

  bool get isReady => _initialized && SupabaseConfig.isConfigured;

  SupabaseClient get _client => Supabase.instance.client;

  // -------------------------------------------------------------------
  // Markets (public read)
  // -------------------------------------------------------------------
  Future<List<SupabaseMarket>> fetchMarkets({bool onlyActive = true}) async {
    if (!isReady) return const [];
    var query = _client
        .from('markets')
        .select('id, display_name, tier, logo_url, website, is_active');
    if (onlyActive) {
      query = query.eq('is_active', true);
    }
    final rows = await query.order('tier').order('display_name');
    return (rows as List)
        .map((e) => SupabaseMarket.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // -------------------------------------------------------------------
  // Current campaigns (public read, view-backed)
  // -------------------------------------------------------------------
  Future<List<SupabaseCampaign>> fetchCurrentCampaigns({
    String? marketId,
    int limit = 50,
  }) async {
    if (!isReady) return const [];
    var query = _client.from('current_campaigns').select();
    if (marketId != null) {
      query = query.eq('market_id', marketId);
    }
    final rows = await query.order('valid_until').limit(limit);
    return (rows as List)
        .map((e) => SupabaseCampaign.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // -------------------------------------------------------------------
  // Products search (public read)
  // -------------------------------------------------------------------
  Future<List<SupabaseProduct>> searchProducts({
    required String query,
    int limit = 30,
  }) async {
    if (!isReady || query.trim().isEmpty) return const [];
    // `search_text` column'u normalize edilmis: "coca cola 1l" gibi.
    final term = query.trim().toLowerCase();
    final rows = await _client
        .from('products')
        .select('id, canonical_name, brand, package_size, package_unit, image_url')
        .ilike('search_text', '%$term%')
        .limit(limit);
    return (rows as List)
        .map((e) => SupabaseProduct.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // -------------------------------------------------------------------
  // Latest prices for a given product (all markets)
  // -------------------------------------------------------------------
  Future<List<SupabaseLatestPrice>> fetchLatestPricesForProduct(
    String productId,
  ) async {
    if (!isReady) return const [];
    final rows = await _client
        .from('latest_prices')
        .select()
        .eq('product_id', productId)
        .order('price');
    return (rows as List)
        .map((e) => SupabaseLatestPrice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // -------------------------------------------------------------------
  // RPC: search_products_with_prices
  //
  // Kullanici aramasi icin. Donen satirlar (product + market + price)
  // ActuellerCatalogItem'a map'lenir ki app icindeki mevcut UI/state
  // kodlarina dokunmadan marketfiyati.org.tr yerine Supabase'e baglanabilsin.
  // -------------------------------------------------------------------
  Future<List<ActuellerCatalogItem>> searchCatalogItems({
    required String query,
    Iterable<String>? marketIds,
    int limit = 80,
  }) async {
    if (!isReady || query.trim().isEmpty) return const [];
    final params = <String, dynamic>{
      'p_query': query.trim(),
      'p_market_ids': marketIds == null || marketIds.isEmpty
          ? null
          : marketIds.toList(),
      'p_limit': limit,
    };
    final rows =
        await _client.rpc('search_products_with_prices', params: params);
    return _mapRpcRows(rows as List, sourceLabel: 'Supabase');
  }

  // -------------------------------------------------------------------
  // RPC: browse_category_products
  //
  // Kategori ID listesi + (opsiyonel) tercihli market listesi.
  // Parent kategori verildiginde (ör. 'temizlik') path prefix ile
  // alt kategoriler de dahil edilir (RPC icinde).
  // -------------------------------------------------------------------
  Future<List<ActuellerCatalogItem>> browseCategoryItems({
    required Iterable<String> categoryIds,
    Iterable<String>? marketIds,
    int limit = 200,
  }) async {
    if (!isReady || categoryIds.isEmpty) return const [];
    final params = <String, dynamic>{
      'p_category_ids': categoryIds.toList(),
      'p_market_ids': marketIds == null || marketIds.isEmpty
          ? null
          : marketIds.toList(),
      'p_limit': limit,
    };
    final rows =
        await _client.rpc('browse_category_products', params: params);
    return _mapRpcRows(rows as List, sourceLabel: 'Supabase');
  }

  // -------------------------------------------------------------------
  // Helper: RPC satirlarini ActuellerCatalogItem'a donustur.
  // -------------------------------------------------------------------
  List<ActuellerCatalogItem> _mapRpcRows(
    List rows, {
    required String sourceLabel,
  }) {
    return rows
        .map((raw) => _rowToCatalogItem(
              raw as Map<String, dynamic>,
              sourceLabel: sourceLabel,
            ))
        .toList(growable: false);
  }

  ActuellerCatalogItem _rowToCatalogItem(
    Map<String, dynamic> row, {
    required String sourceLabel,
  }) {
    final productId = row['product_id']?.toString() ?? '';
    final marketId = row['market_id']?.toString() ?? '';
    final canonicalName = (row['canonical_name'] as String?) ?? '';
    final brand = row['brand'] as String?;
    final marketName = (row['market_name'] as String?) ?? marketId;
    final price = _toDouble(row['price']) ?? 0;
    final score = _toDouble(row['match_score']) ?? 1.0;
    final categoryId = row['category_id'] as String?;
    final size = _toDouble(row['package_size']);
    final unit = row['package_unit'] as String?;
    final unitPriceLabel = row['unit_price_label'] as String?;

    return ActuellerCatalogItem(
      // id: urun-market cifti benzersiz olmali (ayni urun birden fazla markette
      // ayri satir dondurur).
      id: '$productId::$marketId',
      marketName: marketName,
      productTitle: canonicalName,
      price: price,
      confidence: score.clamp(0.0, 1.0),
      rawBlock: canonicalName,
      sourceLabel: sourceLabel,
      category: _mapCategoryIdToEnum(categoryId),
      brand: brand,
      weight: _formatWeight(size, unit, unitPriceLabel),
      sourceProductId: productId,
      sourceDepotId: marketId,
      sourceMenuCategory: categoryId,
      sourceMainCategory: null,
    );
  }

  /// Supabase kategori ID'sini app'in 6-bucket ProductCategory enum'una esler.
  /// Bilinmeyenler `other` doner.
  ProductCategory _mapCategoryIdToEnum(String? categoryId) {
    if (categoryId == null) return ProductCategory.other;
    const foodPrefixes = [
      'atistirmalik', 'cikolata', 'cips-cerezler', 'dondurma', 'sakiz',
      'seker-sekerleme',
      'bebek-mama',
      'dondurulmus', 'dondurulmus-et', 'hazir-yemek', 'mantici',
      'pizza-hamur', 'dondurulmus-sebze',
      'et-tavuk', 'balik', 'deniz-urunu', 'hindi', 'kirmizi-et', 'kiyma',
      'salam-sosis', 'sarkuteri', 'sucuk', 'tavuk',
      'firin', 'bisk-kraker', 'ekmek', 'pasta-kek', 'simit-poğaca',
      'gida', 'temel-gida', 'bahorat-cesni', 'bakliyat', 'konserve',
      'makarna', 'pirinc-bulgur', 'seker', 'sirke', 'sos-soslar',
      'tuz', 'un', 'yag', 'zeytinyagi',
      'icecek', 'cay', 'enerji-icecek', 'gazli-icecek', 'kahve',
      'meyve-suyu', 'sicak-icecek-diger', 'soguk-cay', 'su',
      'kahvaltilik', 'bal', 'fistik-ezmesi', 'gevrek', 'kakaolu-krem',
      'pekmez', 'recel', 'tahin',
      'meyve-sebze', 'kuru-meyve', 'kuruyemis', 'mantar', 'meyve',
      'organik', 'sebze', 'yesillik',
      'sut-urunleri', 'ayran', 'kaymak', 'kefir', 'krem', 'peynir',
      'yogurt', 'sut',
    ];
    const cleaningPrefixes = [
      'temizlik', 'camasir-deterjan', 'bulasik-deterjan', 'kagit',
      'kisisel-bakim', 'cilt-bakim', 'deodorant', 'dis-bakim', 'dus-jeli',
      'kadin-hijyen', 'kozmetik', 'sac-bakim', 'sampuan', 'tras-bakim',
      'yetiskin-bezi',
      'bebek', 'bebek-bakim', 'bebek-bezi', 'islak-mendil',
    ];
    const homePrefixes = [
      'ev-yasam', 'ampul', 'kucuk-ev-aletleri', 'mutfak-esya',
      'pil-batarya', 'saklama-kaplari',
      'evcil-hayvan', 'evcil-aksesuar', 'kedi-kumu', 'kedi-mama',
      'kopek-mama',
      'kirtasiye',
    ];
    const electronicsPrefixes = ['elektronik'];

    if (foodPrefixes.contains(categoryId)) return ProductCategory.food;
    if (cleaningPrefixes.contains(categoryId)) return ProductCategory.cleaning;
    if (homePrefixes.contains(categoryId)) return ProductCategory.home;
    if (electronicsPrefixes.contains(categoryId)) {
      return ProductCategory.electronics;
    }
    return ProductCategory.other;
  }

  String? _formatWeight(double? size, String? unit, String? unitPriceLabel) {
    if (size != null && unit != null && unit.isNotEmpty) {
      final asInt = size.truncateToDouble() == size;
      return '${asInt ? size.toInt() : size}$unit';
    }
    return unitPriceLabel;
  }

  static double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  // -------------------------------------------------------------------
  // Ham count helpers (smoke test icin)
  // -------------------------------------------------------------------
  Future<int> countProducts() async {
    if (!isReady) return 0;
    final rows = await _client.from('products').select('id').count();
    return rows.count;
  }

  Future<int> countActiveCampaigns() async {
    if (!isReady) return 0;
    final rows =
        await _client.from('current_campaigns').select('id').count();
    return rows.count;
  }
}
