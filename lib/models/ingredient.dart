class Ingredient {
  final String id;
  final String nameTr;
  final String nameEn;
  final String category;
  final String icon;

  const Ingredient({
    required this.id,
    required this.nameTr,
    required this.nameEn,
    required this.category,
    this.icon = '*',
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['id'] as String,
      nameTr: json['name_tr'] as String,
      nameEn: json['name_en'] as String,
      category: json['category'] as String,
      icon: json['icon'] as String? ?? '*',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name_tr': nameTr,
        'name_en': nameEn,
        'category': category,
        'icon': icon,
      };

  String getName(String locale) => locale == 'tr' ? nameTr : nameEn;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Ingredient && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class IngredientCategory {
  static const String vegetables = 'vegetables';
  static const String fruits = 'fruits';
  static const String meat = 'meat';
  static const String dairy = 'dairy';
  static const String grains = 'grains';
  static const String spices = 'spices';
  static const String oils = 'oils';
  static const String other = 'other';

  static const List<String> orderedValues = [
    vegetables,
    fruits,
    meat,
    dairy,
    grains,
    spices,
    oils,
    other,
  ];

  static String getNameTr(String category) {
    switch (category) {
      case vegetables:
        return 'Sebzeler';
      case fruits:
        return 'Meyveler';
      case meat:
        return 'Et & Protein';
      case dairy:
        return 'Sut Urunleri';
      case grains:
        return 'Tahillar & Baklagiller';
      case spices:
        return 'Baharatlar';
      case oils:
        return 'Yaglar & Soslar';
      case other:
        return 'Diger';
      default:
        return category;
    }
  }

  static String getNameEn(String category) {
    switch (category) {
      case vegetables:
        return 'Vegetables';
      case fruits:
        return 'Fruits';
      case meat:
        return 'Meat & Protein';
      case dairy:
        return 'Dairy';
      case grains:
        return 'Grains & Legumes';
      case spices:
        return 'Spices';
      case oils:
        return 'Oils & Sauces';
      case other:
        return 'Other';
      default:
        return category;
    }
  }

  static String getName(String category, String locale) =>
      locale == 'tr' ? getNameTr(category) : getNameEn(category);
}
