import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/cosmetic_source_definition.dart';
import '../utils/cosmetic_registry.dart';

class CosmeticSourceService {
  static const akakceBaseUrl = 'https://www.akakce.com/';

  static const _defaultHeaders = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/*,*/*;q=0.8',
    'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.5',
    'Referer': akakceBaseUrl,
  };

  final http.Client _client;

  CosmeticSourceService({http.Client? client})
      : _client = client ?? http.Client();

  List<CosmeticSourceDefinition> get availableSources => cosmeticSourceRegistry;

  Future<List<String>> discoverSeedUrls({
    required List<String> selectedSourceIds,
    int maxPerSource = 8,
  }) async {
    final selectedIds = selectedSourceIds.toSet();
    final urls = <String>[];
    final seenUrls = <String>{};

    for (final source in cosmeticSourceRegistry) {
      if (!selectedIds.contains(source.id)) {
        continue;
      }
      for (final url in source.seedUrls.take(maxPerSource)) {
        if (seenUrls.add(url)) {
          urls.add(url);
        }
      }
    }

    return urls;
  }

  Future<CosmeticCategorySnapshot> fetchCategorySnapshot(
      String inputUrl) async {
    final trimmed = inputUrl.trim();
    if (trimmed.isEmpty) {
      throw Exception('Kozmetik kategori baglantisi bos.');
    }

    final uri = Uri.parse(trimmed);
    final html = await _fetchHtml(uri);
    final title = _extractTitle(html) ?? _titleFromUri(uri);
    final anchors = _extractAnchors(html, uri);
    final lines = _extractVisibleLines(html);

    return CosmeticCategorySnapshot(
      requestUrl: trimmed,
      title: title,
      breadcrumbs: _extractBreadcrumbs(html, fallbackTitle: title),
      childCategories: _extractChildCategories(
        anchors: anchors,
        currentUri: uri,
      ),
      productCards: _extractProductCards(
        html: html,
        anchors: anchors,
        lines: lines,
      ),
      filterTags: _extractFilterTags(lines),
      totalProductCount: _extractTotalProductCount(lines),
    );
  }

  Future<String> _fetchHtml(Uri uri) async {
    final response = await _client
        .get(uri, headers: _defaultHeaders)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Kozmetik sayfasi alinamadi (${response.statusCode}).');
    }
    return _decodeResponseBody(response);
  }

  List<String> _extractBreadcrumbs(
    String html, {
    required String fallbackTitle,
  }) {
    for (final payload in _extractJsonLdPayloads(html)) {
      try {
        final decoded = json.decode(payload);
        final objects = _flattenJsonLd(decoded);
        for (final object in objects) {
          final type = object['@type']?.toString();
          if (type != 'BreadcrumbList') {
            continue;
          }

          final itemList = object['itemListElement'];
          if (itemList is! List) {
            continue;
          }

          final breadcrumbs = itemList
              .whereType<Map>()
              .map((item) {
                final name = item['name']?.toString();
                if (name != null && name.trim().isNotEmpty) {
                  return name.trim();
                }
                final nestedItem = item['item'];
                if (nestedItem is Map) {
                  final nestedName = nestedItem['name']?.toString();
                  if (nestedName != null && nestedName.trim().isNotEmpty) {
                    return nestedName.trim();
                  }
                }
                return null;
              })
              .whereType<String>()
              .toList();

          if (breadcrumbs.isNotEmpty) {
            return breadcrumbs;
          }
        }
      } catch (error) {
        debugPrint('[Kozmetik] JSON-LD breadcrumb parse hatasi: $error');
      }
    }

    return [fallbackTitle];
  }

  List<Map<String, dynamic>> _flattenJsonLd(dynamic node) {
    if (node is List) {
      return node.expand(_flattenJsonLd).toList();
    }
    if (node is! Map) {
      return const [];
    }

    final casted = node.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final objects = <Map<String, dynamic>>[casted];
    final graph = casted['@graph'];
    if (graph is List) {
      objects.addAll(
        graph.whereType<Map>().map(
              (entry) => entry.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            ),
      );
    }
    return objects;
  }

  List<CosmeticCategoryNode> _extractChildCategories({
    required List<_CosmeticAnchor> anchors,
    required Uri currentUri,
  }) {
    final seenUrls = <String>{};
    final nodes = <CosmeticCategoryNode>[];
    final pattern = RegExp(r'^(.*?)\s*\(([\d.]+)\)$');

    for (final anchor in anchors) {
      if (anchor.url == currentUri.toString()) {
        continue;
      }
      if (!_looksLikeAkakceCategoryUrl(anchor.url)) {
        continue;
      }

      final match = pattern.firstMatch(anchor.text);
      if (match == null) {
        continue;
      }

      final title = match.group(1)?.trim() ?? '';
      if (title.isEmpty || !seenUrls.add(anchor.url)) {
        continue;
      }

      nodes.add(
        CosmeticCategoryNode(
          id: _slugify(anchor.url),
          title: title,
          url: anchor.url,
          kind: CosmeticNodeKind.category,
          itemCount: _parseCount(match.group(2)),
        ),
      );
    }

    return nodes;
  }

  List<CosmeticProductCard> _extractProductCards({
    required String html,
    required List<_CosmeticAnchor> anchors,
    required List<String> lines,
  }) {
    final cards = <CosmeticProductCard>[];
    final seenKeys = <String>{};

    void collectFromTexts(Iterable<String> texts) {
      for (final text in texts) {
        final parsed = _parseProductLine(text);
        if (parsed == null) {
          continue;
        }

        final anchor = _findBestAnchorForTitle(anchors, parsed.title);
        final url = anchor?.url ?? '';
        final imageUrl = anchor?.imageUrl;
        final key = '${parsed.title}|${parsed.priceText}|$url';
        if (!seenKeys.add(key)) {
          continue;
        }

        cards.add(
          CosmeticProductCard(
            title: parsed.title,
            url: url,
            imageUrl: imageUrl,
            price: parsed.price,
            priceText: parsed.priceText,
            unitPriceText: parsed.unitPriceText,
            badgeText: parsed.badgeText,
            offerCount: parsed.offerCount,
          ),
        );
      }
    }

    final listItemBlocks = _extractListItemBlocks(html)
        .map(_stripHtml)
        .where((block) => block.isNotEmpty)
        .toList();
    collectFromTexts(listItemBlocks);

    if (cards.isEmpty) {
      collectFromTexts(lines);
    }

    return cards;
  }

  _ParsedProductLine? _parseProductLine(String line) {
    if (!line.contains('En Ucuz') || !line.contains('TL')) {
      return null;
    }

    final enUcuzIndex = line.indexOf('En Ucuz');
    if (enUcuzIndex <= 0) {
      return null;
    }

    final title = line.substring(0, enUcuzIndex).trim();
    if (title.length < 3) {
      return null;
    }

    var remainder = line.substring(enUcuzIndex + 'En Ucuz'.length).trim();
    String? badgeText;

    final badgeMatch = RegExp(r'^%\s*(\d+)').firstMatch(remainder);
    if (badgeMatch != null) {
      badgeText = '%${badgeMatch.group(1)}';
      remainder = remainder.substring(badgeMatch.end).trim();
    }

    final priceMatch = RegExp(r'(\d[\d.,]*)\s*TL').firstMatch(remainder);
    if (priceMatch == null) {
      return null;
    }

    final rawPrice = priceMatch.group(1)!;
    final afterPrice = remainder.substring(priceMatch.end).trim();
    final offerMatch = RegExp(
      r'\+(\d+)\s*F[İI]YAT',
      caseSensitive: false,
    ).firstMatch(afterPrice);
    final unitMatch = RegExp(
      r'(\d[\d.,]*\s*TL\/[^\s]+)',
    ).firstMatch(afterPrice);

    return _ParsedProductLine(
      title: title,
      price: _parsePrice(rawPrice),
      priceText: '$rawPrice TL',
      unitPriceText: unitMatch?.group(1),
      badgeText: badgeText,
      offerCount:
          offerMatch == null ? null : int.tryParse(offerMatch.group(1)!),
    );
  }

  List<String> _extractFilterTags(List<String> lines) {
    final tags = <String>[];
    final seen = <String>{};
    final pattern = RegExp(
      r'^(Boyut|Ozellikler|Özellikler|Form|Tip|Aroma|Hacim|Cilt Tipi|Etki|Renk|Miktar)\s+.+',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (!pattern.hasMatch(line)) {
        continue;
      }
      if (seen.add(line)) {
        tags.add(line);
      }
    }

    return tags;
  }

  int? _extractTotalProductCount(List<String> lines) {
    final pattern = RegExp(
      r'(\d[\d.]*)\s+farkl[ıi]\s+.+\s+i[cç]in fiyatlar listeleniyor',
      caseSensitive: false,
    );

    for (final line in lines) {
      final match = pattern.firstMatch(line);
      if (match != null) {
        return _parseCount(match.group(1));
      }
    }

    return null;
  }

  List<_CosmeticAnchor> _extractAnchors(String html, Uri baseUri) {
    final anchors = <_CosmeticAnchor>[];
    final pattern = RegExp(
      r'''<a\b[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)</a>''',
      caseSensitive: false,
    );

    for (final match in pattern.allMatches(html)) {
      final rawUrl = match.group(1);
      final innerHtml = match.group(2);
      if (rawUrl == null || innerHtml == null) {
        continue;
      }

      final text = _stripHtml(innerHtml);
      final imageMatch = RegExp(
        r'''<img\b[^>]*(?:src|data-src)=["']([^"']+)["']''',
        caseSensitive: false,
      ).firstMatch(innerHtml);
      final imageUrl = imageMatch == null
          ? null
          : _resolveUrl(baseUri, imageMatch.group(1)!);

      if (text.isEmpty && imageUrl == null) {
        continue;
      }

      anchors.add(
        _CosmeticAnchor(
          text: text,
          url: _resolveUrl(baseUri, rawUrl),
          imageUrl: imageUrl,
        ),
      );
    }

    return anchors;
  }

  _CosmeticAnchor? _findBestAnchorForTitle(
    List<_CosmeticAnchor> anchors,
    String title,
  ) {
    final normalizedTitle = _normalizeText(title);
    for (final anchor in anchors) {
      if (_normalizeText(anchor.text) == normalizedTitle) {
        return anchor;
      }
    }
    for (final anchor in anchors) {
      final normalizedAnchor = _normalizeText(anchor.text);
      if (normalizedAnchor.contains(normalizedTitle) ||
          normalizedTitle.contains(normalizedAnchor)) {
        return anchor;
      }
    }
    return null;
  }

  List<String> _extractVisibleLines(String html) {
    var buffer = html;
    buffer = buffer.replaceAll(
      RegExp(r'<script\b[^>]*>[\s\S]*?</script>', caseSensitive: false),
      ' ',
    );
    buffer = buffer.replaceAll(
      RegExp(r'<style\b[^>]*>[\s\S]*?</style>', caseSensitive: false),
      ' ',
    );
    buffer = buffer.replaceAll(
      RegExp(
        r'</(li|tr|p|div|section|article|ul|ol|h1|h2|h3|h4|nav|header|footer|aside)>',
        caseSensitive: false,
      ),
      '\n',
    );
    buffer = buffer.replaceAll(
      RegExp(r'<br\s*/?>', caseSensitive: false),
      '\n',
    );

    final stripped = _stripHtmlPreservingNewlines(buffer);
    return stripped
        .split(RegExp(r'\r?\n'))
        .map(_normalizeText)
        .where((line) => line.isNotEmpty)
        .toList();
  }

  List<String> _extractListItemBlocks(String html) {
    final blocks = <String>[];
    final pattern = RegExp(
      r'<li\b[^>]*>([\s\S]*?)</li>',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(html)) {
      final block = match.group(1)?.trim();
      if (block != null && block.isNotEmpty) {
        blocks.add(block);
      }
    }
    return blocks;
  }

  String? _extractTitle(String html) {
    final patterns = [
      RegExp(r'<h1[^>]*>([\s\S]*?)</h1>', caseSensitive: false),
      RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match == null) {
        continue;
      }
      final title = _stripHtml(match.group(1) ?? '');
      if (title.isNotEmpty) {
        return title
            .replaceAll(
              RegExp(r'\s*\|\s*En Ucuzu Akak[çc]e$', caseSensitive: false),
              '',
            )
            .trim();
      }
    }

    return null;
  }

  List<String> _extractJsonLdPayloads(String html) {
    final payloads = <String>[];
    final pattern = RegExp(
      r'''<script\b[^>]*type=["']application/ld\+json["'][^>]*>([\s\S]*?)</script>''',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(html)) {
      final payload = match.group(1)?.trim();
      if (payload != null && payload.isNotEmpty) {
        payloads.add(_decodeHtmlEntities(payload));
      }
    }
    return payloads;
  }

  String _stripHtml(String input) {
    return _normalizeText(
      _decodeHtmlEntities(input.replaceAll(RegExp(r'<[^>]+>'), ' ')),
    );
  }

  String _stripHtmlPreservingNewlines(String input) {
    final decoded = _decodeHtmlEntities(
      input.replaceAll(RegExp(r'<[^>]+>'), ' '),
    );
    return decoded
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .join('\n');
  }

  String _normalizeText(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
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

  String _resolveUrl(Uri baseUri, String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return baseUri.toString();
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('//')) {
      return '${baseUri.scheme}:$trimmed';
    }
    return baseUri.resolve(trimmed).toString();
  }

  bool _looksLikeAkakceCategoryUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.host.contains('akakce.com')) {
      return false;
    }
    final lastSegment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    if (!lastSegment.endsWith('.html')) {
      return false;
    }
    return !lastSegment.contains('-fiyati');
  }

  int? _parseCount(String? raw) {
    if (raw == null) {
      return null;
    }
    return int.tryParse(raw.replaceAll('.', '').trim());
  }

  double? _parsePrice(String rawPrice) {
    final normalized = rawPrice.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  String _titleFromUri(Uri uri) {
    final lastSegment =
        uri.pathSegments.isEmpty ? 'kozmetik' : uri.pathSegments.last;
    final withoutExtension = lastSegment.replaceAll('.html', '');
    return withoutExtension
        .split('-')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _slugify(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'https?://'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }
}

class _CosmeticAnchor {
  final String text;
  final String url;
  final String? imageUrl;

  const _CosmeticAnchor({
    required this.text,
    required this.url,
    required this.imageUrl,
  });
}

class _ParsedProductLine {
  final String title;
  final double? price;
  final String priceText;
  final String? unitPriceText;
  final String? badgeText;
  final int? offerCount;

  const _ParsedProductLine({
    required this.title,
    required this.price,
    required this.priceText,
    required this.unitPriceText,
    required this.badgeText,
    required this.offerCount,
  });
}
