class MarketFiyatiSession {
  final String? locationLabel;
  final List<String> depots;
  final int distance;
  final double latitude;
  final double longitude;

  const MarketFiyatiSession({
    this.locationLabel,
    required this.depots,
    required this.distance,
    required this.latitude,
    required this.longitude,
  });

  bool get isReady => depots.isNotEmpty;

  MarketFiyatiSession copyWith({
    String? locationLabel,
    List<String>? depots,
    int? distance,
    double? latitude,
    double? longitude,
  }) {
    return MarketFiyatiSession(
      locationLabel: locationLabel ?? this.locationLabel,
      depots: depots ?? this.depots,
      distance: distance ?? this.distance,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toIdentityPayload({
    required String identity,
    required String keywords,
    int page = 0,
    int size = 20,
    String identityType = 'id',
  }) {
    return {
      'identity': identity,
      'identityType': identityType,
      'keywords': keywords,
      'pages': page,
      'size': size,
      'distance': distance,
      'latitude': latitude,
      'longitude': longitude,
      'depots': depots,
    };
  }

  Map<String, dynamic> toCategoryPayload({
    required String keywords,
    int page = 0,
    int size = 24,
    bool menuCategory = true,
  }) {
    return {
      'keywords': keywords,
      'pages': page,
      'size': size,
      'distance': distance,
      'latitude': latitude,
      'longitude': longitude,
      'depots': depots,
      'menuCategory': menuCategory,
    };
  }

  Map<String, dynamic> toSearchPayload({
    required String keywords,
    int page = 0,
    int size = 24,
  }) {
    return {
      'keywords': keywords,
      'pages': page,
      'size': size,
      'distance': distance,
      'latitude': latitude,
      'longitude': longitude,
      'depots': depots,
    };
  }

  Map<String, dynamic> toSimilarProductPayload({
    required String id,
    required String keywords,
    int page = 0,
    int size = 24,
  }) {
    return {
      'id': id,
      'keywords': keywords,
      'pages': page,
      'size': size,
      'distance': distance,
      'latitude': latitude,
      'longitude': longitude,
      'depots': depots,
    };
  }

  factory MarketFiyatiSession.fromJson(Map<String, dynamic> json) {
    return MarketFiyatiSession(
      locationLabel: json['locationLabel']?.toString(),
      depots: (json['depots'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .where((value) => value.trim().isNotEmpty)
          .toList(),
      distance: (json['distance'] as num?)?.toInt() ?? 5,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'locationLabel': locationLabel,
        'depots': depots,
        'distance': distance,
        'latitude': latitude,
        'longitude': longitude,
      };
}

class MarketFiyatiLocationSuggestion {
  final String fullLabel;
  final String resultType;
  final String pointOfInterestName;
  final String roadName;
  final String neighborhood;
  final String district;
  final String city;
  final double longitude;
  final double latitude;
  final String? roadContext;
  final String? doorNumber;

  const MarketFiyatiLocationSuggestion({
    required this.fullLabel,
    required this.resultType,
    required this.pointOfInterestName,
    required this.roadName,
    required this.neighborhood,
    required this.district,
    required this.city,
    required this.longitude,
    required this.latitude,
    required this.roadContext,
    required this.doorNumber,
  });

  String get displayLabel {
    final poi = pointOfInterestName.trim();
    if (poi.isNotEmpty) {
      return poi;
    }

    final parts = <String>[
      roadName.trim(),
      neighborhood.trim(),
      district.trim(),
      city.trim(),
    ].where((part) => part.isNotEmpty).toList();

    if (parts.isNotEmpty) {
      return parts.join(', ');
    }
    return fullLabel.trim();
  }

  factory MarketFiyatiLocationSuggestion.fromList(List<dynamic> values) {
    String stringAt(int index) =>
        index < values.length ? values[index]?.toString() ?? '' : '';
    double doubleAt(int index) =>
        index < values.length ? (values[index] as num?)?.toDouble() ?? 0 : 0;

    return MarketFiyatiLocationSuggestion(
      fullLabel: stringAt(0),
      resultType: stringAt(1),
      pointOfInterestName: stringAt(2),
      roadName: stringAt(3),
      neighborhood: stringAt(4),
      district: stringAt(5),
      city: stringAt(6),
      longitude: doubleAt(7),
      latitude: doubleAt(8),
      roadContext: stringAt(16).isEmpty ? null : stringAt(16),
      doorNumber: stringAt(18).isEmpty ? null : stringAt(18),
    );
  }
}

class MarketFiyatiNearestDepot {
  final String id;
  final String sellerName;
  final String marketName;
  final double latitude;
  final double longitude;
  final double distanceMeters;

  const MarketFiyatiNearestDepot({
    required this.id,
    required this.sellerName,
    required this.marketName,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
  });

  factory MarketFiyatiNearestDepot.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>? ?? const {};
    return MarketFiyatiNearestDepot(
      id: json['id']?.toString() ?? '',
      sellerName: json['sellerName']?.toString() ?? '',
      marketName: json['marketName']?.toString() ?? '',
      latitude: (location['lat'] as num?)?.toDouble() ?? 0,
      longitude: (location['lon'] as num?)?.toDouble() ?? 0,
      distanceMeters: (json['distance'] as num?)?.toDouble() ?? 0,
    );
  }
}

class MarketFiyatiDepotOffer {
  final String depotId;
  final String depotName;
  final double price;
  final String? unitPriceText;
  final double? unitPriceValue;
  final String marketId;
  final double? latitude;
  final double? longitude;
  final String? indexTime;
  final bool discount;
  final double? discountRatio;
  final String? promotionText;

  const MarketFiyatiDepotOffer({
    required this.depotId,
    required this.depotName,
    required this.price,
    required this.unitPriceText,
    required this.unitPriceValue,
    required this.marketId,
    required this.latitude,
    required this.longitude,
    required this.indexTime,
    required this.discount,
    required this.discountRatio,
    required this.promotionText,
  });

  factory MarketFiyatiDepotOffer.fromJson(Map<String, dynamic> json) {
    return MarketFiyatiDepotOffer(
      depotId: json['depotId']?.toString() ?? '',
      depotName: json['depotName']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      unitPriceText: json['unitPrice']?.toString(),
      unitPriceValue: (json['unitPriceValue'] as num?)?.toDouble(),
      marketId: json['marketAdi']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      indexTime: json['indexTime']?.toString(),
      discount: json['discount'] as bool? ?? false,
      discountRatio: (json['discountRatio'] as num?)?.toDouble(),
      promotionText: json['promotionText']?.toString(),
    );
  }
}

class MarketFiyatiProduct {
  final String id;
  final String title;
  final String? brand;
  final String? imageUrl;
  final String? refinedVolumeOrWeight;
  final String? refinedQuantityUnit;
  final String? mainCategory;
  final String? menuCategory;
  final List<String> categories;
  final List<MarketFiyatiDepotOffer> offers;

  const MarketFiyatiProduct({
    required this.id,
    required this.title,
    required this.brand,
    required this.imageUrl,
    required this.refinedVolumeOrWeight,
    required this.refinedQuantityUnit,
    required this.mainCategory,
    required this.menuCategory,
    required this.categories,
    required this.offers,
  });

  String? get refinedMeasure {
    final volume = refinedVolumeOrWeight?.trim();
    if (volume != null && volume.isNotEmpty) {
      return volume;
    }
    final quantity = refinedQuantityUnit?.trim();
    if (quantity != null && quantity.isNotEmpty) {
      return quantity;
    }
    return null;
  }

  factory MarketFiyatiProduct.fromJson(Map<String, dynamic> json) {
    final offers = (json['productDepotInfoList'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MarketFiyatiDepotOffer.fromJson)
        .toList();
    final categories = (json['categories'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .toList();

    return MarketFiyatiProduct(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      brand: json['brand']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      refinedVolumeOrWeight: json['refinedVolumeOrWeight']?.toString(),
      refinedQuantityUnit: json['refinedQuantityUnit']?.toString(),
      mainCategory: json['main_category']?.toString(),
      menuCategory: json['menu_category']?.toString(),
      categories: categories,
      offers: offers,
    );
  }
}

class MarketFiyatiSearchResponse {
  final int numberOfFound;
  final int searchResultType;
  final List<MarketFiyatiProduct> content;
  final Map<String, dynamic>? facetMap;

  const MarketFiyatiSearchResponse({
    required this.numberOfFound,
    required this.searchResultType,
    required this.content,
    required this.facetMap,
  });

  factory MarketFiyatiSearchResponse.fromJson(Map<String, dynamic> json) {
    final products = (json['content'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MarketFiyatiProduct.fromJson)
        .toList();

    return MarketFiyatiSearchResponse(
      numberOfFound: (json['numberOfFound'] as num?)?.toInt() ?? 0,
      searchResultType: (json['searchResultType'] as num?)?.toInt() ?? 0,
      content: products,
      facetMap: json['facetMap'] as Map<String, dynamic>?,
    );
  }
}

class MarketFiyatiOfficialCategory {
  final String id;
  final String name;
  final List<String> subcategories;

  const MarketFiyatiOfficialCategory({
    required this.id,
    required this.name,
    required this.subcategories,
  });

  factory MarketFiyatiOfficialCategory.fromJson(Map<String, dynamic> json) {
    final rawSubcategories = json['subcategories'];
    final subcategories = <String>[];

    if (rawSubcategories is List) {
      for (final value in rawSubcategories) {
        if (value == null) {
          continue;
        }

        if (value is String) {
          final trimmedValue = value.trim();
          if (trimmedValue.isNotEmpty) {
            subcategories.add(trimmedValue);
          }
          continue;
        }

        if (value is Map<String, dynamic>) {
          final nestedName = value['name']?.toString().trim() ?? '';
          if (nestedName.isNotEmpty) {
            subcategories.add(nestedName);
          }
        }
      }
    }

    return MarketFiyatiOfficialCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString().trim() ?? '',
      subcategories: List<String>.unmodifiable(subcategories),
    );
  }
}
