import 'curated_recipes.dart';

Map<String, String> _ingredientVariantStyle(String category) {
  switch (category) {
    case 'vegetables':
      return const {
        'tr_prefix': 'Mevsimlik ',
        'tr_suffix': '',
        'en_prefix': 'Seasonal ',
        'en_suffix': '',
      };
    case 'fruits':
      return const {
        'tr_prefix': 'Olgun ',
        'tr_suffix': '',
        'en_prefix': 'Ripe ',
        'en_suffix': '',
      };
    case 'meat':
      return const {
        'tr_prefix': 'Marine ',
        'tr_suffix': '',
        'en_prefix': 'Marinated ',
        'en_suffix': '',
      };
    case 'dairy':
      return const {
        'tr_prefix': '',
        'tr_suffix': ' Hafif',
        'en_prefix': '',
        'en_suffix': ' Light',
      };
    case 'grains':
      return const {
        'tr_prefix': 'Tam ',
        'tr_suffix': '',
        'en_prefix': 'Whole ',
        'en_suffix': '',
      };
    case 'spices':
      return const {
        'tr_prefix': '',
        'tr_suffix': ' Kar\u0131\u015f\u0131m\u0131',
        'en_prefix': '',
        'en_suffix': ' Blend',
      };
    case 'oils':
      return const {
        'tr_prefix': '',
        'tr_suffix': ' Sosu',
        'en_prefix': '',
        'en_suffix': ' Sauce',
      };
    default:
      return const {
        'tr_prefix': '\u00d6zel ',
        'tr_suffix': '',
        'en_prefix': 'Special ',
        'en_suffix': '',
      };
  }
}

Map<String, dynamic> _buildIngredientVariant(Map<String, dynamic> ingredient) {
  final category = (ingredient['category'] ?? 'other').toString();
  final style = _ingredientVariantStyle(category);
  final nameTr = (ingredient['name_tr'] ?? '').toString();
  final nameEn = (ingredient['name_en'] ?? '').toString();

  return {
    ...ingredient,
    'id': '${ingredient['id']}_plus',
    'name_tr': '${style['tr_prefix']}$nameTr${style['tr_suffix']}',
    'name_en': '${style['en_prefix']}$nameEn${style['en_suffix']}',
  };
}

List<Map<String, dynamic>> expandIngredientCatalog(
  List<Map<String, dynamic>> ingredients,
) {
  return [
    ...ingredients,
    ...ingredients.map(_buildIngredientVariant),
  ];
}

String _normalizeRecipeText(Object? value) {
  return value
      .toString()
      .toLowerCase()
      .replaceAll('\u0131', 'i')
      .replaceAll('\u00e7', 'c')
      .replaceAll('\u011f', 'g')
      .replaceAll('\u00f6', 'o')
      .replaceAll('\u015f', 's')
      .replaceAll('\u00fc', 'u')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}

String _recipeIngredientSignature(Map<String, dynamic> recipe) {
  final ingredients = (recipe['ingredients'] as List<dynamic>? ?? const [])
      .cast<Map<String, dynamic>>()
      .map((ingredient) {
    final ingredientId = ingredient['ingredient_id'] ?? '';
    final amount = ingredient['amount_tr'] ?? ingredient['amount_en'] ?? '';
    final isOptional =
        ingredient['is_optional'] == true ? 'optional' : 'required';
    return '$ingredientId:${_normalizeRecipeText(amount)}:$isOptional';
  }).toList()
    ..sort();
  return ingredients.join('|');
}

String _recipeStepSignature(Map<String, dynamic> recipe) {
  final steps = (recipe['steps_tr'] as List<dynamic>? ?? const [])
      .cast<Map<String, dynamic>>()
      .map((step) {
    final instruction = _normalizeRecipeText(step['instruction']);
    final duration = step['duration_minutes']?.toString() ?? '';
    return '$instruction:$duration';
  }).toList();
  return steps.join('|');
}

String buildRecipeContentSignature(Map<String, dynamic> recipe) {
  final category = recipe['category'] ?? '';
  final difficulty = recipe['difficulty'] ?? '';
  final servings = recipe['servings'] ?? '';
  final prepTime = recipe['prep_time_minutes'] ?? '';
  final cookTime = recipe['cook_time_minutes'] ?? '';
  final ingredients = _recipeIngredientSignature(recipe);
  final steps = _recipeStepSignature(recipe);
  return [
    category,
    difficulty,
    servings,
    prepTime,
    cookTime,
    ingredients,
    steps,
  ].join('||');
}

String _recipeVisibleNameKey(Map<String, dynamic> recipe) {
  final name =
      recipe['name_tr'] ?? recipe['name_en'] ?? recipe['id'] ?? 'recipe';
  return _normalizeRecipeText(name);
}

List<Map<String, dynamic>> expandRecipeCatalog(
  List<Map<String, dynamic>> recipes,
) {
  final allRecipes = [
    ...recipes,
    ...buildCuratedRecipeCatalog(),
  ];
  final uniqueRecipes = <Map<String, dynamic>>[];
  final seenSignatures = <String>{};
  final seenVisibleNames = <String>{};

  for (final recipe in allRecipes) {
    final signature = buildRecipeContentSignature(recipe);
    final visibleName = _recipeVisibleNameKey(recipe);
    if (seenSignatures.add(signature) && seenVisibleNames.add(visibleName)) {
      uniqueRecipes.add(recipe);
    }
  }

  return uniqueRecipes;
}
