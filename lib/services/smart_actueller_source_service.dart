import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/market_registry.dart';

class MarketSource {
  final String id;
  final String name;
  final String emoji;
  final String akakceSlug;

  const MarketSource({
    required this.id,
    required this.name,
    required this.emoji,
    required this.akakceSlug,
  });

  String get brochureListUrl =>
      '${SmartActuellerSourceService.akakceListingUrl}$akakceSlug';
}

class PreparedActuellerSource {
  final String requestUrl;
  final String sourceLabel;
  final String? detectedStore;
  final List<String> imageUrls;
  final List<String> localImagePaths;
  final String extractedText;
  final bool usedStructuredCatalogData;
  final bool shouldUseImageFallback;

  const PreparedActuellerSource({
    required this.requestUrl,
    required this.sourceLabel,
    required this.detectedStore,
    required this.imageUrls,
    required this.localImagePaths,
    this.extractedText = '',
    this.usedStructuredCatalogData = false,
    this.shouldUseImageFallback = true,
  });
}

class _AkakceStructuredSource {
  final String? title;
  final String? detectedStore;
  final List<String> productLines;
  final List<String> fallbackImageUrls;
  final List<String> brochureLinks;

  const _AkakceStructuredSource({
    required this.title,
    required this.detectedStore,
    required this.productLines,
    required this.fallbackImageUrls,
    required this.brochureLinks,
  });
}

class SmartActuellerSourceService {
  static const akakceListingUrl = 'https://www.akakce.com/brosurler/';

    static const List<MarketSource> availableMarkets = [
    MarketSource(
      id: 'a101',
      name: 'A101',
      emoji: '🟡',
      akakceSlug: 'a101',
    ),
    MarketSource(
      id: 'bim',
      name: 'BİM',
      emoji: '🔴',
      akakceSlug: 'bim',
    ),
    MarketSource(
      id: 'sok',
      name: 'ŞOK',
      emoji: '🟠',
      akakceSlug: 'sok',
    ),
    MarketSource(
      id: 'migros',
      name: 'Migros',
      emoji: '🟢',
      akakceSlug: 'migros',
    ),
    MarketSource(
      id: 'carrefoursa',
      name: 'CarrefourSA',
      emoji: '🔵',
      akakceSlug: 'carrefoursa',
    ),
    MarketSource(
      id: 'hakmar',
      name: 'Hakmar Express',
      emoji: '🟤',
      akakceSlug: 'hakmarexpress',
    ),
    MarketSource(
      id: 'metro',
      name: 'Metro',
      emoji: '🟣',
      akakceSlug: 'metro-tr',
    ),
    MarketSource(
      id: 'tarim-kredi',
      name: 'Tarım Kredi',
      emoji: '🌾',
      akakceSlug: 'kooperatifmarket',
    ),
    MarketSource(
      id: 'file',
      name: 'File Market',
      emoji: '🟩',
      akakceSlug: 'filemarket',
    ),
    MarketSource(
      id: 'bildirici',
      name: 'Bildirici',
      emoji: '📢',
      akakceSlug: 'bildirici',
    ),
    MarketSource(
      id: 'altunbilekler',
      name: 'Altunbilekler',
      emoji: '🛒',
      akakceSlug: 'altunbilekler',
    ),
    MarketSource(
      id: 'macrocenter',
      name: 'Macrocenter',
      emoji: '🥩',
      akakceSlug: 'macrocenter',
    ),
    MarketSource(
      id: 'gimsa',
      name: 'GİMSA',
      emoji: '🏬',
      akakceSlug: 'gimsa',
    ),
    MarketSource(
      id: 'akyurt',
      name: 'Akyurt Süpermarket',
      emoji: '🧺',
      akakceSlug: 'akyurtsupermarket',
    ),
  ];

  static const _defaultHeaders = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/*,*/*;q=0.8',
    'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.5',
    'Referer': 'https://www.akakce.com/',
  };

  static final _detailSlugPattern = RegExp(r'-\d{3,}$');

  final http.Client _client;

  SmartActuellerSourceService({http.Client? client})
      : _client = client ?? http.Client();

  Future<List<String>> discoverBrochureUrls({
    List<String>? selectedMarketIds,
    int maxPerMarket = 10,
    int maxTotal = 80,
  }) async {
    final selectedIds = normalizeMarketIds(
      selectedMarketIds ?? availableMarkets.map((market) => market.id),
    );
    final marketsById = {
      for (final market in availableMarkets) market.id: market,
    };
    final marketsToScan = selectedIds
        .map((marketId) => marketsById[marketId])
        .whereType<MarketSource>()
        .toList();

    final discoveredUrls = <String>[];
    final seenUrls = <String>{};
    Map<String, String> marketPageUrls = const {};

    try {
      final rootHtml = await _fetchHtml(Uri.parse(akakceListingUrl));
      marketPageUrls = _extractMarketPageUrls(rootHtml);
    } catch (error) {
      debugPrint('[Aktüeller] Kök Akakçe sayfası alınamadı: $error');
    }

    for (final market in marketsToScan) {
      if (discoveredUrls.length >= maxTotal) {
        break;
      }

      final marketPageUrl = marketPageUrls[market.id] ?? market.brochureListUrl;
      try {
        final urls = await _discoverMarketBrochures(
          market: market,
          marketPageUrl: marketPageUrl,
          maxCount: maxPerMarket,
        );
        for (final url in urls) {
          if (discoveredUrls.length >= maxTotal) {
            break;
          }
          if (seenUrls.add(url)) {
            discoveredUrls.add(url);
          }
        }
      } catch (error) {
        debugPrint('[Aktüeller] ${market.name} keşif hatası: $error');
      }
    }

    return discoveredUrls;
  }

  Future<PreparedActuellerSource> prepareSource(String inputUrl) async {
    final trimmed = inputUrl.trim();
    if (trimmed.isEmpty) {
      throw Exception('Broşür bağlantısı boş.');
    }

    final uri = Uri.parse(trimmed);
    final detectedStore = _detectStore(trimmed);

    if (_looksLikeImage(uri)) {
      final localPath = await _downloadImage(uri);
      final sourceLabel = detectedStore == null
          ? 'Aktüel ürün görseli'
          : '$detectedStore aktüel görseli';
      return PreparedActuellerSource(
        requestUrl: trimmed,
        sourceLabel: sourceLabel,
        detectedStore: detectedStore,
        imageUrls: [uri.toString()],
        localImagePaths: [localPath],
        shouldUseImageFallback: true,
      );
    }

    final html = await _fetchHtml(uri);
    final structuredSource = _extractAkakceStructuredSource(html, uri);
    final effectiveStore = structuredSource?.detectedStore ?? detectedStore;
    final extractedText = structuredSource == null
        ? ''
        : structuredSource.productLines.join('\n').trim();

    final shouldUseImageFallback = extractedText.isEmpty;
    final fallbackImageUrls = <String>[
      if (shouldUseImageFallback) ...?structuredSource?.fallbackImageUrls,
    ];
    if (shouldUseImageFallback && fallbackImageUrls.isEmpty) {
      fallbackImageUrls.addAll(_extractBrochurePageImages(html, uri));
    }

    final localImagePaths = <String>[];
    if (shouldUseImageFallback) {
      for (final imageUrl in fallbackImageUrls.take(20)) {
        try {
          localImagePaths.add(await _downloadImage(Uri.parse(imageUrl)));
        } catch (error) {
          debugPrint('[Aktüeller] Görsel indirilemedi: $imageUrl ($error)');
        }
      }
    }

    final sourceLabel = structuredSource?.title ??
        _extractTitle(html) ??
        _buildSourceLabel(
          effectiveStore,
        );

    if (extractedText.isEmpty && localImagePaths.isEmpty) {
      throw Exception('Broşürde okunabilir ürün verisi bulunamadı.');
    }

    return PreparedActuellerSource(
      requestUrl: trimmed,
      sourceLabel: sourceLabel,
      detectedStore: effectiveStore,
      imageUrls: fallbackImageUrls,
      localImagePaths: localImagePaths,
      extractedText: extractedText,
      usedStructuredCatalogData: extractedText.isNotEmpty,
      shouldUseImageFallback: shouldUseImageFallback,
    );
  }

  Future<List<String>> _discoverMarketBrochures({
    required MarketSource market,
    required String marketPageUrl,
    required int maxCount,
  }) async {
    final uri = Uri.parse(marketPageUrl);
    final html = await _fetchHtml(uri);
    final discovered = <String>{};

    final structured = _extractAkakceStructuredSource(html, uri);
    if (structured != null) {
      for (final url in structured.brochureLinks) {
        if (_matchesBrochureSlug(url, market.akakceSlug)) {
          discovered.add(url);
          if (discovered.length >= maxCount) {
            return discovered.take(maxCount).toList();
          }
        }
      }
    }

    for (final url in _extractBrochureDetailLinks(
      html,
      uri,
      slugPrefix: market.akakceSlug,
    )) {
      discovered.add(url);
      if (discovered.length >= maxCount) {
        break;
      }
    }

    if (discovered.isEmpty) {
      final fallback = uri.toString();
      if (_matchesBrochureSlug(fallback, market.akakceSlug)) {
        discovered.add(fallback);
      }
    }

    return discovered.take(maxCount).toList();
  }

  Future<String> _fetchHtml(Uri uri) async {
    final response = await _client
        .get(uri, headers: _defaultHeaders)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Aktüel sayfası alınamadı (${response.statusCode}).');
    }
    return _decodeResponseBody(response);
  }

  Map<String, String> _extractMarketPageUrls(String html) {
    final discovered = <String, String>{};
    for (final market in availableMarkets) {
      final pattern = RegExp(
        r'''href=["'](/brosurler/''' +
            RegExp.escape(market.akakceSlug) +
            r'''/?(?:[#?][^"']*)?)["']''',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(html);
      if (match == null) continue;
      discovered[market.id] = _resolveUrl(
        Uri.parse(akakceListingUrl),
        match.group(1)!,
      );
    }
    return discovered;
  }

  _AkakceStructuredSource? _extractAkakceStructuredSource(
    String html,
    Uri pageUri,
  ) {
    final productLines = <String>{};
    final fallbackImages = <String>{};
    final brochureLinks = <String>{};
    String? title;
    String? detectedStore;

    for (final rawProps in _extractAstroPropsPayloads(html)) {
      try {
        final decodedProps = _decodeHtmlEntities(rawProps);
        final parsed = json.decode(decodedProps);
        final decoded = _decodeAstroSerializedValue(parsed);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }

        final response = decoded['response'];
        if (response is! Map<String, dynamic>) {
          continue;
        }

        final metadata = response['metadata'];
        if (metadata is Map<String, dynamic>) {
          title ??= _firstNonEmptyString([
            metadata['bt'],
            metadata['title'],
            metadata['n'],
          ]);
          detectedStore ??= _normalizeMarketDisplay(
            _firstNonEmptyString([
              metadata['vn'],
              metadata['v'],
            ]),
          );
          final currentBrochurePath = _firstNonEmptyString([
            metadata['su'],
            metadata['bu'],
          ]);
          if (currentBrochurePath != null) {
            brochureLinks.add(_resolveUrl(pageUri, currentBrochurePath));
          }
        }

        final pages = response['pages'];
        if (pages is List) {
          for (final page in pages.whereType<Map<String, dynamic>>()) {
            final pageImageUrl = _firstNonEmptyString([
              page['hriURL'],
              page['hriUrl'],
              page['lriURL'],
              page['lriUrl'],
              page['img'],
              page['u'],
            ]);

            final clips = page['clips'];
            var pageHadStructuredItems = false;
            if (clips is List) {
              final clipLines = _extractClipProductLines(clips).toList();
              if (clipLines.isNotEmpty) {
                productLines.addAll(clipLines);
                pageHadStructuredItems = true;
              }
            }

            if (!pageHadStructuredItems && pageImageUrl != null) {
              fallbackImages.add(_resolveUrl(pageUri, pageImageUrl));
            }
          }
        }

        final brochureCollections = [
          response['vdBrochures'],
          response['brochures'],
          response['relatedBrochures'],
        ];
        for (final collection in brochureCollections) {
          if (collection is! List) continue;
          for (final brochure in collection.whereType<Map<String, dynamic>>()) {
            final brochurePath = _firstNonEmptyString([
              brochure['bu'],
              brochure['u'],
              brochure['href'],
            ]);
            if (brochurePath == null) continue;
            brochureLinks.add(_resolveUrl(pageUri, brochurePath));
          }
        }
      } catch (error) {
        debugPrint('[Aktüeller] Astro props parse hatası: $error');
      }
    }

    if (brochureLinks.isEmpty) {
      brochureLinks.addAll(_extractBrochureDetailLinks(html, pageUri));
    }

    if (productLines.isEmpty) {
      final rctTitles = _extractRctTitles(html);
      if (rctTitles.isNotEmpty) {
        title ??= _extractTitle(html);
        detectedStore ??= _detectStore(pageUri.toString());
      }
    }

    if (fallbackImages.isEmpty && productLines.isEmpty) {
      fallbackImages.addAll(_extractBrochurePageImages(html, pageUri));
    }

    if (productLines.isEmpty &&
        fallbackImages.isEmpty &&
        brochureLinks.isEmpty &&
        title == null &&
        detectedStore == null) {
      return null;
    }

    return _AkakceStructuredSource(
      title: title ?? _extractTitle(html),
      detectedStore: detectedStore ?? _detectStore(pageUri.toString()),
      productLines: productLines.toList(),
      fallbackImageUrls: fallbackImages.toList(),
      brochureLinks:
          brochureLinks.where((url) => url != pageUri.toString()).toList(),
    );
  }

  Iterable<String> _extractClipProductLines(List<dynamic> clips) sync* {
    for (final clip in clips.whereType<Map<String, dynamic>>()) {
      final name = _firstNonEmptyString([
            clip['n'],
            clip['title'],
            clip['t'],
            clip['pn'],
            clip['name'],
            clip['uTitle'],
          ]) ??
          '';
      final price = _normalizeStructuredPrice(
        _firstNonEmptyString([
          clip['p'],
          clip['price'],
          clip['sp'],
          clip['salePrice'],
          clip['amount'],
        ]),
      );
      if (name.isEmpty || price.isEmpty) {
        continue;
      }
      if (!RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(name)) {
        continue;
      }
      yield '$name $price TL';
    }
  }

  List<String> _extractAstroPropsPayloads(String html) {
    final payloads = <String>[];
    final pattern = RegExp(
      r'''<astro-island[^>]*\sprops=(["'])([\s\S]*?)\1''',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(html)) {
      final payload = match.group(2);
      if (payload != null && payload.isNotEmpty) {
        payloads.add(payload);
      }
    }
    return payloads;
  }

  dynamic _decodeAstroSerializedValue(dynamic value) {
    if (value is List) {
      if (value.length == 2 && value.first is int) {
        final tag = value.first as int;
        final payload = value[1];
        if (tag == 0) {
          return _decodeAstroSerializedValue(payload);
        }
        if (tag == 1 && payload is List) {
          return payload.map(_decodeAstroSerializedValue).toList();
        }
        return _decodeAstroSerializedValue(payload);
      }
      return value.map(_decodeAstroSerializedValue).toList();
    }

    if (value is Map) {
      return value.map(
        (key, dynamic nestedValue) => MapEntry(
          key.toString(),
          _decodeAstroSerializedValue(nestedValue),
        ),
      );
    }

    return value;
  }

  List<String> _extractBrochureDetailLinks(
    String html,
    Uri pageUri, {
    String? slugPrefix,
  }) {
    final links = <String>{};
    final pattern = RegExp(
      r'''href=["'](/brosurler/([a-z0-9-]+))["']''',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(html)) {
      final path = match.group(1);
      final slug = match.group(2);
      if (path == null || slug == null) continue;
      if (slugPrefix != null) {
        if (slug == slugPrefix || !slug.startsWith('$slugPrefix-')) {
          continue;
        }
      }
      if (!_detailSlugPattern.hasMatch(slug)) {
        continue;
      }
      links.add(_resolveUrl(pageUri, path));
    }
    return links.toList();
  }

  List<String> _extractBrochurePageImages(String html, Uri pageUri) {
    final urls = <String>{};
    final pattern = RegExp(
      r'''(?:src|data-src)=["']((?:https?:)?//[^"']+/_bro/(?:u|l)/[^"']+\.(?:jpg|jpeg|png|webp)|/[^"']+/_bro/(?:u|l)/[^"']+\.(?:jpg|jpeg|png|webp))["']''',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(html)) {
      final rawUrl = match.group(1);
      if (rawUrl == null) continue;
      urls.add(_resolveUrl(pageUri, rawUrl));
    }
    return urls.toList();
  }

  List<String> _extractRctTitles(String html) {
    final titles = <String>{};
    final pattern = RegExp(
      r'''class=["'][^"']*\brct\b[^"']*["'][^>]*title=["']([^"']+)["']''',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(html)) {
      final title = _decodeHtmlEntities(match.group(1) ?? '').trim();
      if (title.isNotEmpty) {
        titles.add(title);
      }
    }
    return titles.toList();
  }

  Future<String> _downloadImage(Uri uri) async {
    final response = await _client
        .get(uri, headers: _defaultHeaders)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Görsel indirilemedi (${response.statusCode}).');
    }

    final extension = _imageExtensionForUri(uri);
    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'fridgechef_actueller_${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    await file.writeAsBytes(response.bodyBytes);
    return file.path;
  }

  bool _looksLikeImage(Uri uri) {
    final path = uri.path.toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp');
  }

  String _resolveUrl(Uri pageUri, String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return pageUri.toString();
    if (trimmed.startsWith('/_bro/')) {
      return 'https://cdn.akakce.com$trimmed';
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final resolved = Uri.parse(trimmed);
      if (resolved.path.startsWith('/_bro/') &&
          resolved.host.toLowerCase() == 'www.akakce.com') {
        return resolved.replace(host: 'cdn.akakce.com').toString();
      }
      return trimmed;
    }
    if (trimmed.startsWith('//')) {
      final resolved = Uri.parse('${pageUri.scheme}:$trimmed');
      if (resolved.path.startsWith('/_bro/') &&
          resolved.host.toLowerCase() == 'www.akakce.com') {
        return resolved.replace(host: 'cdn.akakce.com').toString();
      }
      return resolved.toString();
    }
    final resolved = pageUri.resolve(trimmed);
    if (resolved.path.startsWith('/_bro/') &&
        resolved.host.toLowerCase() == 'www.akakce.com') {
      return resolved.replace(host: 'cdn.akakce.com').toString();
    }
    return resolved.toString();
  }

  String _buildSourceLabel(String? detectedStore) {
    return detectedStore == null ? 'Aktüel ürünler' : '$detectedStore aktüel';
  }

  String _decodeResponseBody(http.Response response) {
    final bodyBytes = response.bodyBytes;
    if (bodyBytes.isEmpty) {
      return response.body;
    }
    try {
      return utf8.decode(bodyBytes);
    } catch (_) {
      return utf8.decode(bodyBytes, allowMalformed: true);
    }
  }

  String? _extractTitle(String html) {
    final titlePatterns = [
      RegExp(r'''<h1[^>]*>([\s\S]*?)</h1>''', caseSensitive: false),
      RegExp(r'''<title[^>]*>([\s\S]*?)</title>''', caseSensitive: false),
    ];
    for (final pattern in titlePatterns) {
      final match = pattern.firstMatch(html);
      if (match == null) continue;
      final title = _stripHtml(match.group(1) ?? '');
      if (title.isNotEmpty) {
        return title;
      }
    }
    return null;
  }

  String _stripHtml(String input) {
    return _decodeHtmlEntities(
      input.replaceAll(RegExp(r'<[^>]+>'), ' '),
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _decodeHtmlEntities(String input) {
    var output = input
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&#x27;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');

    output = output.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
      final value = int.tryParse(match.group(1)!, radix: 16);
      return value == null ? match.group(0)! : String.fromCharCode(value);
    });
    output = output.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final value = int.tryParse(match.group(1)!);
      return value == null ? match.group(0)! : String.fromCharCode(value);
    });
    return output;
  }

  String _cleanStructuredText(dynamic value) {
    final text = _decodeHtmlEntities(value?.toString() ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.isEmpty) {
      return '';
    }
    return text;
  }

  String _normalizeStructuredPrice(dynamic value) {
    if (value == null) return '';
    if (value is num) {
      if (value == value.roundToDouble()) {
        return value.toInt().toString();
      }
      return value.toStringAsFixed(2).replaceAll('.', ',');
    }

    var text = _cleanStructuredText(value);
    if (text.isEmpty) return '';
    final match = RegExp(r'\d[\d.,]*').firstMatch(text);
    if (match == null) return '';
    text = match.group(0)!;

    if (text.contains('.') && !text.contains(',')) {
      final parts = text.split('.');
      if (parts.length == 2 && parts.last.length <= 2) {
        text = '${parts.first},${parts.last.padRight(2, '0')}';
      } else {
        text = parts.join();
      }
    }

    if (text.contains(',') && text.contains('.')) {
      final commaIndex = text.lastIndexOf(',');
      final dotIndex = text.lastIndexOf('.');
      if (commaIndex > dotIndex) {
        text = text.replaceAll('.', '');
      } else {
        text = text.replaceAll(',', '');
      }
    }

    return text;
  }

  String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      final text = _cleanStructuredText(value);
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  String? _detectStore(String raw) {
    final marketId = normalizeMarketId(raw);
    if (marketId == null) {
      return null;
    }
    return marketDisplayNamesById[marketId];
  }

  String? _normalizeMarketDisplay(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final id = normalizeMarketId(raw);
    return id == null ? raw.trim() : marketDisplayNamesById[id];
  }

  bool _matchesBrochureSlug(String url, String slugPrefix) {
    final pathSegment = Uri.tryParse(url)?.pathSegments.last.toLowerCase();
    if (pathSegment == null || pathSegment == slugPrefix) {
      return false;
    }
    return pathSegment.startsWith('$slugPrefix-');
  }

  String _imageExtensionForUri(Uri uri) {
    final lowerPath = uri.path.toLowerCase();
    if (lowerPath.endsWith('.png')) return '.png';
    if (lowerPath.endsWith('.webp')) return '.webp';
    if (lowerPath.endsWith('.jpeg')) return '.jpeg';
    return '.jpg';
  }
}

