import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/ingredient.dart';
import '../models/remote_market_quote.dart';
import '../models/market_fiyati.dart';
import '../models/smart_actueller.dart';
import '../utils/market_registry.dart';
import '../utils/product_category.dart';

class MarketFiyatiSourceService {
  static const apiBaseUrl = 'https://api.marketfiyati.org.tr/api/v2';
  static const _apiInfoBaseUrl = 'https://api.marketfiyati.org.tr/api';
  static const _mapApiBaseUrl =
      'https://harita.marketfiyati.org.tr/Service/api/v1';

  static const _defaultHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Origin': 'https://marketfiyati.org.tr',
    'Referer': 'https://marketfiyati.org.tr/',
  };

  final http.Client _client;

  MarketFiyatiSourceService({http.Client? client})
      : _client = client ?? http.Client();

  Future<MarketFiyatiSearchResponse> searchByIdentity({
    required MarketFiyatiSession session,
    required String identity,
    required String keywords,
    int page = 0,
    int size = 1,
    String identityType = 'id',
  }) async {
    final payload = session.toIdentityPayload(
      identity: identity,
      keywords: keywords,
      page: page,
      size: size,
      identityType: identityType,
    );
    return _postSearch('searchByIdentity', payload);
  }

  Future<List<MarketFiyatiOfficialCategory>> fetchOfficialCategories() async {
    final uri = Uri.parse('$_apiInfoBaseUrl/info/categories');
    Object? lastError;

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await _client
            .get(
              uri,
              headers: _defaultHeaders,
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode >= 500 && attempt < 2) {
          lastError = Exception(
            'Market Fiyatı kategori ağacı sunucu hatası verdi (${response.statusCode}).',
          );
          await Future<void>.delayed(
            Duration(milliseconds: 350 * (attempt + 1)),
          );
          continue;
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(
            'Market Fiyatı kategori ağacı isteği başarısız oldu (${response.statusCode}).',
          );
        }

        final decoded = json.decode(response.body);
        final rawContent =
            decoded is Map<String, dynamic> ? decoded['content'] : decoded;
        if (rawContent is! List) {
          throw Exception('Market Fiyatı kategori ağacı yanıtı geçersiz.');
        }

        return rawContent
            .whereType<Map<String, dynamic>>()
            .map(MarketFiyatiOfficialCategory.fromJson)
            .where((category) => category.name.trim().isNotEmpty)
            .toList(growable: false);
      } on TimeoutException catch (error) {
        lastError = error;
      } on SocketException catch (error) {
        lastError = error;
      } on HttpException catch (error) {
        lastError = error;
      } on http.ClientException catch (error) {
        lastError = error;
      }

      if (attempt < 2) {
        await Future<void>.delayed(
          Duration(milliseconds: 350 * (attempt + 1)),
        );
      }
    }

    throw Exception(
      'Market Fiyatı kategori ağacı alınamadı.'
      '${lastError == null ? '' : ' (${lastError.toString()})'}',
    );
  }

  Future<List<MarketFiyatiOfficialCategory>>
      fetchOfficialCategoriesResilient() async {
    const categoryUrls = [
      '$_apiInfoBaseUrl/info/categories',
      '$apiBaseUrl/info/categories',
    ];
    const getHeaders = {
      'Accept': 'application/json',
      'Origin': 'https://marketfiyati.org.tr',
      'Referer': 'https://marketfiyati.org.tr/',
    };
    Object? lastError;

    for (final url in categoryUrls) {
      final uri = Uri.parse(url);
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          final response = await _client
              .get(
                uri,
                headers: getHeaders,
              )
              .timeout(const Duration(seconds: 20));

          if (response.statusCode >= 500 && attempt < 2) {
            lastError = Exception(
              'Market Fiyatı kategori ağacı sunucu hatası verdi (${response.statusCode}) @ $url.',
            );
            await Future<void>.delayed(
              Duration(milliseconds: 350 * (attempt + 1)),
            );
            continue;
          }

          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw Exception(
              'Market Fiyatı kategori ağacı isteği başarısız oldu (${response.statusCode}) @ $url.',
            );
          }

          final decoded = json.decode(response.body);
          final rawContent =
              decoded is Map<String, dynamic> ? decoded['content'] : decoded;
          if (rawContent is! List) {
            throw Exception(
              'Market Fiyatı kategori ağacı yanıtı geçersiz @ $url.',
            );
          }

          return rawContent
              .whereType<Map<String, dynamic>>()
              .map(MarketFiyatiOfficialCategory.fromJson)
              .where((category) => category.name.trim().isNotEmpty)
              .toList(growable: false);
        } on TimeoutException catch (error) {
          lastError = error;
        } on SocketException catch (error) {
          lastError = error;
        } on HttpException catch (error) {
          lastError = error;
        } on http.ClientException catch (error) {
          lastError = error;
        }

        if (attempt < 2) {
          await Future<void>.delayed(
            Duration(milliseconds: 350 * (attempt + 1)),
          );
        }
      }
    }

    throw Exception(
      'Market Fiyatı kategori ağacı alınamadı.'
      '${lastError == null ? '' : ' (${lastError.toString()})'}',
    );
  }

  Future<List<MarketFiyatiLocationSuggestion>> searchLocationSuggestions({
    required String words,
  }) async {
    final trimmedWords = words.trim();
    if (trimmedWords.isEmpty) {
      return const [];
    }

    final results = <String, MarketFiyatiLocationSuggestion>{};

    for (final variant in _buildLocationQueryVariants(trimmedWords)) {
      final suggestions = await _fetchLocationSuggestions(words: variant);
      for (final suggestion in suggestions) {
        final key =
            '${suggestion.displayLabel}|${suggestion.latitude}|${suggestion.longitude}';
        results.putIfAbsent(key, () => suggestion);
      }
      if (results.isNotEmpty) {
        break;
      }
    }

    return results.values.toList();
  }

  Future<List<MarketFiyatiNearestDepot>> fetchNearestDepots({
    required double latitude,
    required double longitude,
    int distance = 1,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/nearest');
    final response = await _client
        .post(
          uri,
          headers: _defaultHeaders,
          body: json.encode({
            'latitude': latitude,
            'longitude': longitude,
            'distance': distance,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Market Fiyat\u0131 yak\u0131n market iste\u011Fi ba\u015Far\u0131s\u0131z oldu (${response.statusCode}).',
      );
    }

    final decoded = json.decode(response.body);
    if (decoded is! List) {
      throw Exception(
          'Market Fiyat\u0131 yak\u0131n market yan\u0131t\u0131 ge\u00E7ersiz.');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(MarketFiyatiNearestDepot.fromJson)
        .toList();
  }

  MarketFiyatiSession buildSessionFromNearest({
    String? locationLabel,
    required double latitude,
    required double longitude,
    required List<MarketFiyatiNearestDepot> depots,
    int distance = 5,
    int maxDepots = 24,
  }) {
    final depotIds = depots
        .map((depot) => depot.id)
        .where((id) => id.trim().isNotEmpty)
        .take(maxDepots)
        .toList();

    return MarketFiyatiSession(
      locationLabel: locationLabel,
      depots: depotIds,
      distance: distance,
      latitude: latitude,
      longitude: longitude,
    );
  }

  MarketFiyatiSession buildSessionFromSuggestion({
    required MarketFiyatiLocationSuggestion suggestion,
    required List<MarketFiyatiNearestDepot> depots,
    int distance = 5,
    int maxDepots = 24,
  }) {
    return buildSessionFromNearest(
      locationLabel: suggestion.displayLabel,
      latitude: suggestion.latitude,
      longitude: suggestion.longitude,
      depots: depots,
      distance: distance,
      maxDepots: maxDepots,
    );
  }

  Future<MarketFiyatiSearchResponse> searchByCategories({
    required MarketFiyatiSession session,
    required String keywords,
    int page = 0,
    int size = 24,
    bool menuCategory = true,
  }) async {
    final payload = session.toCategoryPayload(
      keywords: keywords,
      page: page,
      size: size,
      menuCategory: menuCategory,
    );
    return _postSearch('searchByCategories', payload);
  }

  Future<MarketFiyatiSearchResponse> search({
    required MarketFiyatiSession session,
    required String keywords,
    int page = 0,
    int size = 24,
  }) async {
    final payload = session.toSearchPayload(
      keywords: keywords,
      page: page,
      size: size,
    );
    return _postSearch('search', payload);
  }

  Future<MarketFiyatiSearchResponse> searchSimilarProduct({
    required MarketFiyatiSession session,
    required String id,
    required String keywords,
    int page = 0,
    int size = 24,
  }) async {
    final payload = session.toSimilarProductPayload(
      id: id,
      keywords: keywords,
      page: page,
      size: size,
    );
    return _postSearch('searchSimilarProduct', payload);
  }

  List<ActuellerCatalogItem> toCatalogItems(
    MarketFiyatiSearchResponse response, {
    String sourceLabel = 'Market Fiyat\u0131',
  }) {
    final items = <ActuellerCatalogItem>[];

    for (final product in response.content) {
      final category = categorizeProduct(
        [
          product.title,
          ...product.categories,
          product.mainCategory ?? '',
          product.menuCategory ?? '',
        ].join(' '),
      );

      for (final offer in product.offers) {
        final weight = product.refinedMeasure;
        final marketName = displayNameForMarket(offer.marketId);
        final title = _mergeTitleAndMeasure(product.title, weight);
        final rawBlock = '$title ${offer.price.toStringAsFixed(2)} TL';

        items.add(
          ActuellerCatalogItem(
            id: '${product.id}-${offer.depotId}',
            marketName: marketName.isEmpty ? offer.marketId : marketName,
            productTitle: title,
            price: offer.price,
            confidence: 0.99,
            rawBlock: rawBlock,
            sourceLabel: sourceLabel,
            category: category,
            brand: product.brand,
            weight: weight,
            sourceProductId: product.id,
            sourceDepotId: offer.depotId,
            sourceMenuCategory: product.menuCategory,
            sourceMainCategory: product.mainCategory,
          ),
        );
      }
    }

    return items;
  }

  List<RemoteMarketQuote> toRemoteQuotes(
    MarketFiyatiSearchResponse response, {
    required List<Ingredient> ingredients,
  }) {
    final quotes = <RemoteMarketQuote>[];

    for (final product in response.content) {
      final ingredientId = _matchIngredientId(
        product: product,
        ingredients: ingredients,
      );
      if (ingredientId == null) continue;

      for (final offer in product.offers) {
        quotes.add(
          RemoteMarketQuote(
            ingredientId: ingredientId,
            market: displayNameForMarket(offer.marketId),
            unitPrice: offer.price,
            isCampaign: offer.discount,
            campaignLabelTr: offer.discount
                ? 'Market Fiyat\u0131 f\u0131rsat\u0131'
                : 'Market Fiyat\u0131 raf fiyat\u0131',
            campaignLabelEn: offer.discount
                ? 'Market Fiyati deal'
                : 'Market Fiyati shelf price',
          ),
        );
      }
    }

    return quotes;
  }

  Future<MarketFiyatiSearchResponse> _postSearch(
    String endpoint,
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse('$apiBaseUrl/$endpoint');
    Object? lastError;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _client
            .post(
              uri,
              headers: _defaultHeaders,
              body: json.encode(payload),
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode >= 500 && attempt < 1) {
          lastError = Exception(
            'Market Fiyat\u0131 iste\u011Fi sunucu hatas\u0131 verdi (${response.statusCode}).',
          );
          await Future<void>.delayed(
            Duration(milliseconds: 400 * (attempt + 1)),
          );
          continue;
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(
            'Market Fiyat\u0131 iste\u011Fi ba\u015Far\u0131s\u0131z oldu (${response.statusCode}).',
          );
        }

        final decoded = json.decode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw Exception('Market Fiyat\u0131 yan\u0131t\u0131 ge\u00E7ersiz.');
        }
        return MarketFiyatiSearchResponse.fromJson(decoded);
      } on TimeoutException catch (error) {
        lastError = error;
      } on SocketException catch (error) {
        lastError = error;
      } on HttpException catch (error) {
        lastError = error;
      } on http.ClientException catch (error) {
        lastError = error;
      }

      if (attempt < 1) {
        await Future<void>.delayed(
          Duration(milliseconds: 400 * (attempt + 1)),
        );
      }
    }

    throw Exception(
      'Market Fiyat\u0131 ba\u011flant\u0131s\u0131 ge\u00e7ici olarak kesildi. Tekrar dener misin?'
      '${lastError == null ? '' : ' (${lastError.toString()})'}',
    );
  }

  String _mergeTitleAndMeasure(String title, String? measure) {
    final trimmedTitle = title.trim();
    final trimmedMeasure = measure?.trim() ?? '';
    if (trimmedMeasure.isEmpty) {
      return trimmedTitle;
    }

    final normalizedTitle = _normalizeComparableText(trimmedTitle);
    final normalizedMeasure = _normalizeComparableText(trimmedMeasure);
    if (normalizedMeasure.isNotEmpty &&
        normalizedTitle.contains(normalizedMeasure)) {
      return trimmedTitle;
    }

    return '$trimmedTitle $trimmedMeasure';
  }

  String _normalizeComparableText(String value) {
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

  Future<List<MarketFiyatiLocationSuggestion>> _fetchLocationSuggestions({
    required String words,
  }) async {
    final uri = Uri.parse(
      '$_mapApiBaseUrl/AutoSuggestion/Search?words=${Uri.encodeQueryComponent(words)}',
    );
    final response = await _client.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Origin': 'https://marketfiyati.org.tr',
        'Referer': 'https://marketfiyati.org.tr/',
      },
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Market Fiyat\u0131 lokasyon aramas\u0131 ba\u015Far\u0131s\u0131z oldu (${response.statusCode}).',
      );
    }

    final decoded = json.decode(response.body);
    if (decoded is! List) {
      throw Exception(
          'Market Fiyat\u0131 lokasyon arama yan\u0131t\u0131 ge\u00E7ersiz.');
    }

    return decoded
        .whereType<List<dynamic>>()
        .map(MarketFiyatiLocationSuggestion.fromList)
        .toList();
  }

  List<String> _buildLocationQueryVariants(String rawQuery) {
    final trimmed = rawQuery.trim();
    final variants = <String>{trimmed};
    const replacements = {
      'c': '\u00E7',
      'g': '\u011F',
      'i': '\u0131',
      'o': '\u00F6',
      's': '\u015F',
      'u': '\u00FC',
    };

    for (final entry in replacements.entries) {
      final snapshot = variants.toList();
      for (final variant in snapshot) {
        if (variant.contains(entry.key)) {
          variants.add(variant.replaceAll(entry.key, entry.value));
        }
        final upperSource = entry.key.toUpperCase();
        final upperTarget = entry.value.toUpperCase();
        if (variant.contains(upperSource)) {
          variants.add(variant.replaceAll(upperSource, upperTarget));
        }
      }
    }

    return variants.take(16).toList();
  }

  String? _matchIngredientId({
    required MarketFiyatiProduct product,
    required List<Ingredient> ingredients,
  }) {
    final candidates = [
      product.title,
      product.brand ?? '',
      ...product.categories,
      product.mainCategory ?? '',
      product.menuCategory ?? '',
    ].where((value) => value.trim().isNotEmpty);

    final normalizedCandidate = _normalize(candidates.join(' '));
    for (final ingredient in ingredients) {
      final names = [
        ingredient.id,
        ingredient.nameTr,
        ingredient.nameEn,
      ].map(_normalize);
      if (names.any(
        (name) =>
            normalizedCandidate.contains(name) ||
            name.contains(normalizedCandidate),
      )) {
        return ingredient.id;
      }
    }
    return null;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('\u0131', 'i')
        .replaceAll('\u011F', 'g')
        .replaceAll('\u00FC', 'u')
        .replaceAll('\u015F', 's')
        .replaceAll('\u00F6', 'o')
        .replaceAll('\u00E7', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }
}
