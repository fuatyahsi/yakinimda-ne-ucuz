import '../utils/product_category.dart';
import 'ingredient.dart';

class ActuellerDeal {
  final String id;
  final Ingredient ingredient;
  final String marketName;
  final String productTitle;
  final String? brand;
  final double discountPrice;
  final double? regularPrice;
  final DateTime? validUntil;
  final double confidence;
  final String rawBlock;
  final String sourceLabel;
  final bool fromImageOcr;

  const ActuellerDeal({
    required this.id,
    required this.ingredient,
    required this.marketName,
    required this.productTitle,
    required this.brand,
    required this.discountPrice,
    required this.regularPrice,
    required this.validUntil,
    required this.confidence,
    required this.rawBlock,
    required this.sourceLabel,
    required this.fromImageOcr,
  });

  double get unitSavings {
    final baseline = regularPrice ?? (discountPrice * 1.18);
    return (baseline - discountPrice).clamp(0, 9999).toDouble();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ingredientId': ingredient.id,
        'marketName': marketName,
        'productTitle': productTitle,
        'brand': brand,
        'discountPrice': discountPrice,
        'regularPrice': regularPrice,
        'validUntil': validUntil?.toIso8601String(),
        'confidence': confidence,
        'rawBlock': rawBlock,
        'sourceLabel': sourceLabel,
        'fromImageOcr': fromImageOcr,
      };

  static ActuellerDeal? fromJson(
    Map<String, dynamic> json,
    Ingredient? Function(String ingredientId) ingredientResolver,
  ) {
    final ingredientId = json['ingredientId']?.toString();
    if (ingredientId == null || ingredientId.isEmpty) return null;
    final ingredient = ingredientResolver(ingredientId);
    if (ingredient == null) return null;
    return ActuellerDeal(
      id: json['id']?.toString() ?? '',
      ingredient: ingredient,
      marketName: json['marketName']?.toString() ?? '',
      productTitle: json['productTitle']?.toString() ?? '',
      brand: json['brand']?.toString(),
      discountPrice: (json['discountPrice'] as num?)?.toDouble() ?? 0,
      regularPrice: (json['regularPrice'] as num?)?.toDouble(),
      validUntil: DateTime.tryParse(json['validUntil']?.toString() ?? ''),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      rawBlock: json['rawBlock']?.toString() ?? '',
      sourceLabel: json['sourceLabel']?.toString() ?? '',
      fromImageOcr: json['fromImageOcr'] as bool? ?? false,
    );
  }
}

class ActuellerCatalogItem {
  final String id;
  final String marketName;
  final String productTitle;
  final double price;
  final double confidence;
  final String rawBlock;
  final String sourceLabel;
  final ProductCategory category;
  final String? brand;
  final String? weight;
  final String? sourceProductId;
  final String? sourceDepotId;
  final String? sourceMenuCategory;
  final String? sourceMainCategory;

  const ActuellerCatalogItem({
    required this.id,
    required this.marketName,
    required this.productTitle,
    required this.price,
    required this.confidence,
    required this.rawBlock,
    required this.sourceLabel,
    this.category = ProductCategory.other,
    this.brand,
    this.weight,
    this.sourceProductId,
    this.sourceDepotId,
    this.sourceMenuCategory,
    this.sourceMainCategory,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'marketName': marketName,
        'productTitle': productTitle,
        'price': price,
        'confidence': confidence,
        'rawBlock': rawBlock,
        'sourceLabel': sourceLabel,
        'category': category.name,
        'brand': brand,
        'weight': weight,
        'sourceProductId': sourceProductId,
        'sourceDepotId': sourceDepotId,
        'sourceMenuCategory': sourceMenuCategory,
        'sourceMainCategory': sourceMainCategory,
      };

  static ActuellerCatalogItem fromJson(Map<String, dynamic> json) {
    final title = json['productTitle']?.toString() ?? '';
    return ActuellerCatalogItem(
      id: json['id']?.toString() ?? '',
      marketName: json['marketName']?.toString() ?? '',
      productTitle: title,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      rawBlock: json['rawBlock']?.toString() ?? '',
      sourceLabel: json['sourceLabel']?.toString() ?? '',
      category: ProductCategory.values.firstWhere(
        (c) => c.name == (json['category']?.toString() ?? ''),
        orElse: () => categorizeProduct(title),
      ),
      brand: json['brand']?.toString(),
      weight: json['weight']?.toString(),
      sourceProductId: json['sourceProductId']?.toString(),
      sourceDepotId: json['sourceDepotId']?.toString(),
      sourceMenuCategory: json['sourceMenuCategory']?.toString(),
      sourceMainCategory: json['sourceMainCategory']?.toString(),
    );
  }
}

class ActuellerScanResult {
  final String rawText;
  final List<String> blocks;
  final List<ActuellerCatalogItem> catalogItems;
  final List<ActuellerDeal> deals;
  final List<String> unmatchedBlocks;
  final String? detectedStore;
  final String sourceLabel;
  final String? capturedImagePath;
  final DateTime scannedAt;
  final double confidence;

  const ActuellerScanResult({
    required this.rawText,
    required this.blocks,
    required this.catalogItems,
    required this.deals,
    required this.unmatchedBlocks,
    required this.detectedStore,
    required this.sourceLabel,
    required this.capturedImagePath,
    required this.scannedAt,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
        'rawText': rawText,
        'blocks': blocks,
        'catalogItems': catalogItems.map((item) => item.toJson()).toList(),
        'deals': deals.map((deal) => deal.toJson()).toList(),
        'unmatchedBlocks': unmatchedBlocks,
        'detectedStore': detectedStore,
        'sourceLabel': sourceLabel,
        'capturedImagePath': capturedImagePath,
        'scannedAt': scannedAt.toIso8601String(),
        'confidence': confidence,
      };

  static ActuellerScanResult fromJson(
    Map<String, dynamic> json,
    Ingredient? Function(String ingredientId) ingredientResolver,
  ) {
    final catalogItems = (json['catalogItems'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ActuellerCatalogItem.fromJson)
        .toList();
    final deals = (json['deals'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((item) => ActuellerDeal.fromJson(item, ingredientResolver))
        .whereType<ActuellerDeal>()
        .toList();
    return ActuellerScanResult(
      rawText: json['rawText']?.toString() ?? '',
      blocks: (json['blocks'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      catalogItems: catalogItems,
      deals: deals,
      unmatchedBlocks: (json['unmatchedBlocks'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      detectedStore: json['detectedStore']?.toString(),
      sourceLabel: json['sourceLabel']?.toString() ?? '',
      capturedImagePath: json['capturedImagePath']?.toString(),
      scannedAt: DateTime.tryParse(json['scannedAt']?.toString() ?? '') ??
          DateTime.now(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ActuellerSuggestion {
  final ActuellerDeal deal;
  final int score;
  final int pantryCount;
  final int neededCount;
  final List<String> relatedRecipes;
  final double estimatedSavings;
  final String titleTr;
  final String titleEn;
  final String bodyTr;
  final String bodyEn;

  const ActuellerSuggestion({
    required this.deal,
    required this.score,
    required this.pantryCount,
    required this.neededCount,
    required this.relatedRecipes,
    required this.estimatedSavings,
    required this.titleTr,
    required this.titleEn,
    required this.bodyTr,
    required this.bodyEn,
  });

  String title(String locale) => locale == 'tr' ? titleTr : titleEn;
  String body(String locale) => locale == 'tr' ? bodyTr : bodyEn;
}

class ActuellerVisionCapture {
  final String imagePath;
  final String rawText;
  final List<String> blocks;
  final List<String> labels;
  final String? detectedStore;
  final double confidence;

  const ActuellerVisionCapture({
    required this.imagePath,
    required this.rawText,
    required this.blocks,
    required this.labels,
    required this.detectedStore,
    required this.confidence,
  });
}

class ActuellerCatalogBrochureReport {
  final String brochureUrl;
  final String sourceLabel;
  final String? marketName;
  final int imageCount;
  final int blockCount;
  final int itemCount;
  final int dealCount;
  final bool hadReadableText;
  final List<String> productNames;
  final String? note;

  const ActuellerCatalogBrochureReport({
    required this.brochureUrl,
    required this.sourceLabel,
    required this.marketName,
    required this.imageCount,
    required this.blockCount,
    required this.itemCount,
    required this.dealCount,
    required this.hadReadableText,
    required this.productNames,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
        'brochureUrl': brochureUrl,
        'sourceLabel': sourceLabel,
        'marketName': marketName,
        'imageCount': imageCount,
        'blockCount': blockCount,
        'itemCount': itemCount,
        'dealCount': dealCount,
        'hadReadableText': hadReadableText,
        'productNames': productNames,
        'note': note,
      };

  static ActuellerCatalogBrochureReport fromJson(Map<String, dynamic> json) {
    return ActuellerCatalogBrochureReport(
      brochureUrl: json['brochureUrl']?.toString() ?? '',
      sourceLabel: json['sourceLabel']?.toString() ?? '',
      marketName: json['marketName']?.toString(),
      imageCount: (json['imageCount'] as num?)?.toInt() ?? 0,
      blockCount: (json['blockCount'] as num?)?.toInt() ?? 0,
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      dealCount: (json['dealCount'] as num?)?.toInt() ?? 0,
      hadReadableText: json['hadReadableText'] as bool? ?? false,
      productNames: (json['productNames'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      note: json['note']?.toString(),
    );
  }
}

class ActuellerFeedSnapshot {
  final String sourceLabel;
  final DateTime updatedAt;
  final int brochureCount;
  final List<ActuellerCatalogBrochureReport> brochureReports;
  final List<ActuellerCatalogItem> catalogItems;

  const ActuellerFeedSnapshot({
    required this.sourceLabel,
    required this.updatedAt,
    required this.brochureCount,
    required this.brochureReports,
    required this.catalogItems,
  });
}
