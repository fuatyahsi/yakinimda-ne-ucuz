import 'market_fiyati.dart';

class MarketAppPreferences {
  final List<String> preferredMarkets;
  final MarketFiyatiSession? marketFiyatiSession;

  const MarketAppPreferences({
    required this.preferredMarkets,
    required this.marketFiyatiSession,
  });

  const MarketAppPreferences.defaults()
      : preferredMarkets = const [],
        marketFiyatiSession = null;

  MarketAppPreferences copyWith({
    List<String>? preferredMarkets,
    MarketFiyatiSession? marketFiyatiSession,
    bool clearMarketFiyatiSession = false,
  }) {
    return MarketAppPreferences(
      preferredMarkets: preferredMarkets ?? this.preferredMarkets,
      marketFiyatiSession: clearMarketFiyatiSession
          ? null
          : marketFiyatiSession ?? this.marketFiyatiSession,
    );
  }

  factory MarketAppPreferences.fromJson(Map<String, dynamic> json) {
    return MarketAppPreferences(
      preferredMarkets: (json['preferredMarkets'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .where((value) => value.trim().isNotEmpty)
          .toList(),
      marketFiyatiSession: json['marketFiyatiSession'] is Map<String, dynamic>
          ? MarketFiyatiSession.fromJson(
              json['marketFiyatiSession'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'preferredMarkets': preferredMarkets,
        'marketFiyatiSession': marketFiyatiSession?.toJson(),
      };
}
