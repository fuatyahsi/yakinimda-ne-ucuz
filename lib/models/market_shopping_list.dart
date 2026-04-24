import 'smart_actueller.dart';

class MarketShoppingListEntry {
  final String id;
  final String identityKey;
  final ActuellerCatalogItem selectedItem;
  final List<ActuellerCatalogItem> alternativeItems;
  final DateTime addedAt;

  const MarketShoppingListEntry({
    required this.id,
    required this.identityKey,
    required this.selectedItem,
    required this.alternativeItems,
    required this.addedAt,
  });

  List<ActuellerCatalogItem> get allItems =>
      [selectedItem, ...alternativeItems];

  Map<String, dynamic> toJson() => {
        'id': id,
        'identityKey': identityKey,
        'selectedItem': selectedItem.toJson(),
        'alternativeItems':
            alternativeItems.map((item) => item.toJson()).toList(),
        'addedAt': addedAt.toIso8601String(),
      };

  factory MarketShoppingListEntry.fromJson(Map<String, dynamic> json) {
    return MarketShoppingListEntry(
      id: json['id']?.toString() ?? '',
      identityKey: json['identityKey']?.toString() ?? '',
      selectedItem: ActuellerCatalogItem.fromJson(
        json['selectedItem'] as Map<String, dynamic>? ?? const {},
      ),
      alternativeItems: (json['alternativeItems'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ActuellerCatalogItem.fromJson)
          .toList(),
      addedAt: DateTime.tryParse(json['addedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class MarketShoppingListGroup {
  final String marketId;
  final String marketName;
  final List<MarketShoppingListEntry> entries;

  const MarketShoppingListGroup({
    required this.marketId,
    required this.marketName,
    required this.entries,
  });

  double get totalPrice => entries.fold<double>(
        0,
        (sum, entry) => sum + entry.selectedItem.price,
      );
}

class MarketShoppingRouteAssignment {
  final MarketShoppingListEntry entry;
  final ActuellerCatalogItem assignedItem;
  final bool usesSubstitute;

  const MarketShoppingRouteAssignment({
    required this.entry,
    required this.assignedItem,
    required this.usesSubstitute,
  });

  ActuellerCatalogItem get originalItem => entry.selectedItem;

  double get priceDelta => assignedItem.price - originalItem.price;
}

class MarketShoppingVisitGroup {
  final String marketId;
  final String marketName;
  final List<MarketShoppingRouteAssignment> assignments;

  const MarketShoppingVisitGroup({
    required this.marketId,
    required this.marketName,
    required this.assignments,
  });

  double get totalPrice => assignments.fold<double>(
        0,
        (sum, assignment) => sum + assignment.assignedItem.price,
      );
}

class MarketShoppingVisitPlan {
  final List<String> targetMarketIds;
  final List<MarketShoppingVisitGroup> groups;
  final List<MarketShoppingRouteAssignment> redirectedAssignments;
  final List<MarketShoppingListEntry> unresolvedEntries;

  const MarketShoppingVisitPlan({
    required this.targetMarketIds,
    required this.groups,
    required this.redirectedAssignments,
    required this.unresolvedEntries,
  });

  double get totalPrice => groups.fold<double>(
        0,
        (sum, group) => sum + group.totalPrice,
      );

  int get assignedItemCount => groups.fold<int>(
        0,
        (sum, group) => sum + group.assignments.length,
      );
}
