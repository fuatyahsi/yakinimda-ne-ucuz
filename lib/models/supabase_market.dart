/// `markets` tablosunun Dart karsiligi (public read).
class SupabaseMarket {
  const SupabaseMarket({
    required this.id,
    required this.displayName,
    this.tier,
    this.logoUrl,
    this.website,
    this.active = true,
  });

  final String id;
  final String displayName;
  final int? tier;
  final String? logoUrl;
  final String? website;
  final bool active;

  factory SupabaseMarket.fromJson(Map<String, dynamic> json) {
    return SupabaseMarket(
      id: json['id'] as String,
      displayName: (json['display_name'] ?? json['id']) as String,
      tier: json['tier'] as int?,
      logoUrl: json['logo_url'] as String?,
      website: json['website'] as String?,
      active: (json['is_active'] as bool?) ?? true,
    );
  }
}
