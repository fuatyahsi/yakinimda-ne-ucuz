class CosmeticSourceDefinition {
  final String id;
  final String name;
  final String emoji;
  final List<String> seedUrls;

  const CosmeticSourceDefinition({
    required this.id,
    required this.name,
    required this.emoji,
    required this.seedUrls,
  });
}

enum CosmeticNodeKind { root, category, listing }

class CosmeticCategoryNode {
  final String id;
  final String title;
  final String url;
  final CosmeticNodeKind kind;
  final int? itemCount;

  const CosmeticCategoryNode({
    required this.id,
    required this.title,
    required this.url,
    required this.kind,
    this.itemCount,
  });
}

class CosmeticProductCard {
  final String title;
  final String url;
  final String? imageUrl;
  final double? price;
  final String priceText;
  final String? unitPriceText;
  final String? badgeText;
  final int? offerCount;

  const CosmeticProductCard({
    required this.title,
    required this.url,
    required this.imageUrl,
    required this.price,
    required this.priceText,
    required this.unitPriceText,
    required this.badgeText,
    required this.offerCount,
  });
}

class CosmeticCategorySnapshot {
  final String requestUrl;
  final String title;
  final List<String> breadcrumbs;
  final List<CosmeticCategoryNode> childCategories;
  final List<CosmeticProductCard> productCards;
  final List<String> filterTags;
  final int? totalProductCount;

  const CosmeticCategorySnapshot({
    required this.requestUrl,
    required this.title,
    required this.breadcrumbs,
    required this.childCategories,
    required this.productCards,
    required this.filterTags,
    required this.totalProductCount,
  });

  bool get isListingPage =>
      productCards.isNotEmpty ||
      (totalProductCount != null && totalProductCount! > 0);
}
