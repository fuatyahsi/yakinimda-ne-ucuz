import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/smart_actueller.dart';

class SmartActuellerFeedService {
  final http.Client _client;

  SmartActuellerFeedService({http.Client? client})
      : _client = client ?? http.Client();

  Future<ActuellerFeedSnapshot> fetchFeed({
    required String feedUrl,
  }) async {
    final response = await _client.get(Uri.parse(feedUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Smart Actueller feed failed: ${response.statusCode}');
    }
    return parseFeed(response.body);
  }

  ActuellerFeedSnapshot parseFeed(String payload) {
    final decoded = json.decode(payload);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Smart Actueller feed format is invalid.');
    }

    final sourceLabel =
        decoded['sourceLabel']?.toString() ?? 'Akakce Daily Brochures';
    final updatedAt =
        DateTime.tryParse(decoded['updatedAt']?.toString() ?? '') ??
            DateTime.now();

    final rawItems = decoded['items'];
    final catalogItems = <ActuellerCatalogItem>[];
    final itemsByBrochure = <String, List<ActuellerCatalogItem>>{};
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is! Map<String, dynamic>) continue;
        final title =
            raw['productName']?.toString() ?? raw['productTitle']?.toString();
        if (title == null || title.trim().isEmpty) continue;
        final price = (raw['discountPrice'] as num?)?.toDouble() ??
            (raw['price'] as num?)?.toDouble();
        if (price == null) continue;

        final item = ActuellerCatalogItem(
          id: raw['id']?.toString() ?? '',
          marketName: raw['marketName']?.toString() ??
              raw['market']?.toString() ??
              'Akakce',
          productTitle: title,
          price: price,
          confidence: (raw['confidence'] as num?)?.toDouble() ?? 0,
          rawBlock: raw['ocrText']?.toString() ?? title,
          sourceLabel: raw['sourceLabel']?.toString() ?? sourceLabel,
        );
        catalogItems.add(item);
        final brochureId = raw['brochureId']?.toString();
        if (brochureId == null || brochureId.isEmpty) continue;
        itemsByBrochure.putIfAbsent(brochureId, () => []).add(item);
      }
    }

    final rawBrochures = decoded['brochures'];
    final brochureReports = <ActuellerCatalogBrochureReport>[];
    if (rawBrochures is List) {
      for (final raw in rawBrochures) {
        if (raw is! Map<String, dynamic>) continue;
        final brochureId = raw['id']?.toString() ?? '';
        final brochureItems = itemsByBrochure[brochureId] ?? const [];
        brochureReports.add(
          ActuellerCatalogBrochureReport(
            brochureUrl: raw['detailUrl']?.toString() ?? '',
            sourceLabel: sourceLabel,
            marketName: raw['marketName']?.toString(),
            imageCount: (raw['imageUrls'] as List<dynamic>? ?? const []).length,
            blockCount: brochureItems.length,
            itemCount: brochureItems.length,
            dealCount: 0,
            hadReadableText: brochureItems.isNotEmpty,
            productNames: brochureItems
                .take(8)
                .map((item) => item.productTitle)
                .toList(),
            note: raw['title']?.toString(),
          ),
        );
      }
    }

    return ActuellerFeedSnapshot(
      sourceLabel: sourceLabel,
      updatedAt: updatedAt,
      brochureCount: (decoded['brochureCount'] as num?)?.toInt() ??
          brochureReports.length,
      brochureReports: brochureReports,
      catalogItems: catalogItems,
    );
  }
}
