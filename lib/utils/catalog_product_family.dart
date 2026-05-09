import '../models/smart_actueller.dart';
import 'text_repair.dart';

List<ActuellerCatalogItem> groupCatalogItemsByProductFamily(
  Iterable<ActuellerCatalogItem> items,
) {
  final grouped = <String, ActuellerCatalogItem>{};
  for (final item in items) {
    final key = catalogProductFamilyKey(item);
    final existing = grouped[key];
    if (existing == null || _isBetterFamilyRepresentative(item, existing)) {
      grouped[key] = item;
    }
  }

  final result = grouped.values.toList(growable: false);
  final titleCache = <String, String>{};
  String titleFor(ActuellerCatalogItem item) {
    return titleCache.putIfAbsent(
        item.id, () => catalogProductFamilyTitle(item));
  }

  result.sort((a, b) {
    final categoryCompare =
        (a.sourceMenuCategory ?? '').compareTo(b.sourceMenuCategory ?? '');
    if (categoryCompare != 0) return categoryCompare;
    final titleCompare = titleFor(a).compareTo(titleFor(b));
    if (titleCompare != 0) return titleCompare;
    return a.price.compareTo(b.price);
  });
  return result;
}

List<ActuellerCatalogItem> dedupeCatalogItemsById(
  Iterable<ActuellerCatalogItem> items,
) {
  final seen = <String>{};
  final result = <ActuellerCatalogItem>[];
  for (final item in items) {
    if (seen.add(item.id)) {
      result.add(item);
    }
  }
  return result;
}

bool sameCatalogProductFamily(
  ActuellerCatalogItem a,
  ActuellerCatalogItem b,
) {
  return catalogProductFamilyKey(a) == catalogProductFamilyKey(b);
}

String catalogProductFamilyKey(ActuellerCatalogItem item) {
  final signature = _familySignature(item);
  return [
    signature.categoryKey,
    signature.coreKey,
    signature.measureKey,
  ].join('::');
}

Set<String> catalogShoppingIdentityKeys(ActuellerCatalogItem item) {
  final keys = <String>{catalogProductFamilyKey(item)};
  final sourceProductId = item.sourceProductId?.trim() ?? '';
  if (sourceProductId.isNotEmpty) {
    keys
      ..add(sourceProductId)
      ..add('product:$sourceProductId');
  }

  final titleKey = _normalize(item.productTitle);
  if (titleKey.isNotEmpty) {
    keys.add(titleKey);
  }
  return keys;
}

String catalogProductFamilySearchQuery(ActuellerCatalogItem item) {
  return catalogProductFamilyTitle(item);
}

String catalogProductFamilyTitle(ActuellerCatalogItem item) {
  final signature = _familySignature(item);
  var words = _dropLeadingBrandWords(_words(item.productTitle), item);
  if (signature.isPlainWater) {
    words = words
        .where((word) => !_plainWaterDescriptorWords.contains(word.normalized))
        .toList(growable: false);
  }

  var title = words.map((word) => word.raw).join(' ').trim();
  if (title.isEmpty) {
    title = repairTurkishText(item.productTitle).trim();
  }

  final measure = signature.measure;
  if (measure != null && !_titleContainsMeasure(title, measure)) {
    title = '$title ${measure.label}'.trim();
  }
  return title;
}

String catalogVariantLabel(ActuellerCatalogItem item) {
  final rawTitle = repairTurkishText(item.productTitle).trim();
  final familyTitle = catalogProductFamilyTitle(item);
  final brand = repairTurkishText(item.brand ?? '').trim();
  final normalizedRaw = _normalize(rawTitle);
  final normalizedFamily = _normalize(familyTitle);

  if (rawTitle.isNotEmpty && normalizedRaw != normalizedFamily) {
    return rawTitle;
  }
  if (brand.isNotEmpty) {
    return brand;
  }
  if (item.weight != null && item.weight!.trim().isNotEmpty) {
    return repairTurkishText(item.weight!).trim();
  }
  return rawTitle.isEmpty ? familyTitle : rawTitle;
}

bool _isBetterFamilyRepresentative(
  ActuellerCatalogItem candidate,
  ActuellerCatalogItem current,
) {
  if (candidate.price != current.price) {
    return candidate.price < current.price;
  }
  final candidateBrand = candidate.brand?.trim() ?? '';
  final currentBrand = current.brand?.trim() ?? '';
  if (candidateBrand.isNotEmpty != currentBrand.isNotEmpty) {
    return candidateBrand.isNotEmpty;
  }
  return candidate.productTitle.length < current.productTitle.length;
}

_FamilySignature _familySignature(ActuellerCatalogItem item) {
  final sourceCategoryKey = _normalize(
    item.sourceMenuCategory ?? item.sourceMainCategory ?? item.category.name,
  );
  final measure = _parseMeasure(item);
  var words = _dropLeadingBrandWords(_words(item.productTitle), item);
  final normalizedWords = words.map((word) => word.normalized).toList();
  final plainWater = _isPlainWaterLike(sourceCategoryKey, normalizedWords);
  final categoryKey = _familyCategoryKey(
    item,
    sourceCategoryKey: sourceCategoryKey,
    plainWater: plainWater,
  );

  if (plainWater) {
    words = words
        .where((word) => !_plainWaterDescriptorWords.contains(word.normalized))
        .toList(growable: false);
  }

  final coreTokens = <String>[];
  for (final word in words) {
    final token = word.normalized;
    if (token.isEmpty ||
        _measureWords.contains(token) ||
        _numericPattern.hasMatch(token)) {
      continue;
    }
    if (plainWater && token != 'su') {
      continue;
    }
    coreTokens.add(token);
  }

  final coreKey = coreTokens.isEmpty
      ? _normalize(item.productTitle).replaceAll(' ', '-')
      : coreTokens.join('-');
  return _FamilySignature(
    categoryKey: categoryKey,
    coreKey: coreKey,
    measureKey: measure?.key ?? 'no-measure',
    measure: measure,
    isPlainWater: plainWater,
  );
}

String _familyCategoryKey(
  ActuellerCatalogItem item, {
  required String sourceCategoryKey,
  required bool plainWater,
}) {
  if (plainWater) {
    return 'food';
  }

  final localCategoryKey = item.category.name;
  if (localCategoryKey != 'other') {
    return localCategoryKey;
  }

  final broadSourceKey = _broadSourceCategoryKey(sourceCategoryKey);
  if (broadSourceKey != null) {
    return broadSourceKey;
  }

  return sourceCategoryKey.isEmpty ? 'unknown' : sourceCategoryKey;
}

String? _broadSourceCategoryKey(String sourceCategoryKey) {
  if (sourceCategoryKey.isEmpty) return null;

  const foodSignals = {
    'atistirmalik',
    'bebek-mama',
    'dondurulmus',
    'et-tavuk',
    'firin',
    'gida',
    'icecek',
    'kahvaltilik',
    'meyve-sebze',
    'meyve-suyu',
    'peynir',
    'su',
    'sut',
    'sut-urunleri',
    'temel-gida',
    'yogurt',
  };
  if (foodSignals.any(sourceCategoryKey.contains)) {
    return 'food';
  }

  const cleaningSignals = {
    'agiz-bakim',
    'bebek-bakim',
    'deterjan',
    'ev-bakim',
    'hijyen',
    'kagit',
    'kisisel-bakim',
    'kozmetik',
    'sampuan',
    'temizlik',
  };
  if (cleaningSignals.any(sourceCategoryKey.contains)) {
    return 'cleaning';
  }

  const homeSignals = {
    'ev-yasam',
    'ev-ve-yasam',
    'mutfak',
    'sofra',
  };
  if (homeSignals.any(sourceCategoryKey.contains)) {
    return 'home';
  }

  return null;
}

bool _isPlainWaterLike(String categoryKey, List<String> words) {
  if (!words.contains('su')) return false;
  if (words.contains('meyve') ||
      words.contains('suyu') ||
      words.contains('maden') ||
      words.contains('soda') ||
      words.contains('gazli')) {
    return false;
  }
  return categoryKey == 'su' || words.length <= 5;
}

List<_Word> _dropLeadingBrandWords(
  List<_Word> words,
  ActuellerCatalogItem item,
) {
  if (words.isEmpty) return words;
  final brandPhrases = <List<String>>[];
  final itemBrand = item.brand?.trim();
  if (itemBrand != null && itemBrand.isNotEmpty) {
    brandPhrases.add(_normalize(itemBrand).split(' '));
  }
  for (final brand in _commonLeadingBrands) {
    brandPhrases.add(_normalize(brand).split(' '));
  }

  brandPhrases.sort((a, b) => b.length.compareTo(a.length));
  for (final phrase in brandPhrases) {
    if (phrase.isEmpty || words.length < phrase.length) continue;
    var matches = true;
    for (var i = 0; i < phrase.length; i++) {
      if (words[i].normalized != phrase[i]) {
        matches = false;
        break;
      }
    }
    if (matches) {
      return words.sublist(phrase.length);
    }
  }
  return words;
}

List<_Word> _words(String value) {
  final repaired = repairTurkishText(value);
  final matches = RegExp(
    r'[A-Za-z0-9\u00C7\u011E\u0130\u00D6\u015E\u00DC\u00E7\u011F\u0131\u00F6\u015F\u00FC]+',
  ).allMatches(repaired);
  return [
    for (final match in matches)
      _Word(match.group(0)!, _normalize(match.group(0)!)),
  ];
}

_CatalogMeasure? _parseMeasure(ActuellerCatalogItem item) {
  final source = _normalizeForMeasure(
    [item.weight ?? '', item.productTitle].join(' '),
  );

  final countPack = RegExp(r'(\d+(?:[.,]\d+)?)\s*(li|lu)\b').firstMatch(source);
  if (countPack != null) {
    final value = _parseNumber(countPack.group(1)!);
    return _CatalogMeasure.count(value);
  }

  final count = RegExp(r'(\d+(?:[.,]\d+)?)\s*(adet|ad)\b').firstMatch(source);
  if (count != null) {
    final value = _parseNumber(count.group(1)!);
    return _CatalogMeasure.count(value);
  }

  final weight =
      RegExp(r'(\d+(?:[.,]\d+)?)\s*(kg|gr|g|gram)\b').firstMatch(source);
  if (weight != null) {
    final value = _parseNumber(weight.group(1)!);
    final unit = weight.group(2)!;
    return _CatalogMeasure.weight(unit == 'kg' ? value * 1000 : value);
  }

  final volume =
      RegExp(r'(\d+(?:[.,]\d+)?)\s*(lt|l|litre|ml)\b').firstMatch(source);
  if (volume != null) {
    final value = _parseNumber(volume.group(1)!);
    final unit = volume.group(2)!;
    return _CatalogMeasure.volume(unit == 'ml' ? value : value * 1000);
  }

  return null;
}

bool _titleContainsMeasure(String title, _CatalogMeasure measure) {
  final parsed = _parseMeasure(
    ActuellerCatalogItem(
      id: 'measure-check',
      marketName: '',
      productTitle: title,
      price: 0,
      confidence: 0,
      rawBlock: title,
      sourceLabel: '',
    ),
  );
  return parsed?.key == measure.key;
}

double _parseNumber(String value) {
  return double.tryParse(value.replaceAll(',', '.')) ?? 0;
}

String _normalizeForMeasure(String value) {
  return repairTurkishText(value)
      .toLowerCase()
      .replaceAll('\u0307', '')
      .replaceAll('\u00E7', 'c')
      .replaceAll('\u011F', 'g')
      .replaceAll('\u0131', 'i')
      .replaceAll('\u00F6', 'o')
      .replaceAll('\u015F', 's')
      .replaceAll('\u00FC', 'u')
      .replaceAll(RegExp("'"), ' ')
      .replaceAll('\u2019', ' ');
}

String _normalize(String value) {
  return _normalizeForMeasure(value)
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}

final _numericPattern = RegExp(r'^\d+(?:[.,]\d+)?$');

const _measureWords = {
  'ad',
  'adet',
  'g',
  'gr',
  'gram',
  'kg',
  'l',
  'li',
  'litre',
  'lt',
  'lu',
  'ml',
  'x',
};

const _plainWaterDescriptorWords = {
  'discount',
  'dogal',
  'icme',
  'kaynak',
  'mineralli',
  'pet',
};

const _commonLeadingBrands = [
  'A101',
  'Activia',
  'Aknaz',
  'Altunbilekler',
  'Bim',
  'Binvezir',
  'Carrefour',
  'Carrefour Discount',
  'Damla',
  'Dost',
  'Erikli',
  'File',
  'Hayat',
  'Icim',
  'Icindekiler',
  'Kuzeyden',
  'Migros',
  'Munzur',
  'Nestle',
  'Pinar',
  'Saka',
  'Sek',
  'Sirma',
  'Sutas',
  'Teksut',
  'Yorsan',
];

class _Word {
  final String raw;
  final String normalized;

  const _Word(this.raw, this.normalized);
}

class _FamilySignature {
  final String categoryKey;
  final String coreKey;
  final String measureKey;
  final _CatalogMeasure? measure;
  final bool isPlainWater;

  const _FamilySignature({
    required this.categoryKey,
    required this.coreKey,
    required this.measureKey,
    required this.measure,
    required this.isPlainWater,
  });
}

class _CatalogMeasure {
  final String kind;
  final double value;

  const _CatalogMeasure._(this.kind, this.value);

  factory _CatalogMeasure.count(double value) =>
      _CatalogMeasure._('count', value);

  factory _CatalogMeasure.volume(double value) =>
      _CatalogMeasure._('volume', value);

  factory _CatalogMeasure.weight(double value) =>
      _CatalogMeasure._('weight', value);

  String get key => '$kind:${value.round()}';

  String get label {
    if (kind == 'volume') {
      if (value >= 1000 && value % 1000 == 0) {
        return '${(value / 1000).toStringAsFixed(0)} Lt';
      }
      if (value >= 1000) {
        return '${_trimDecimal(value / 1000)} Lt';
      }
      return '${value.toStringAsFixed(0)} Ml';
    }
    if (kind == 'weight') {
      if (value >= 1000 && value % 1000 == 0) {
        return '${(value / 1000).toStringAsFixed(0)} Kg';
      }
      if (value >= 1000) {
        return '${_trimDecimal(value / 1000)} Kg';
      }
      return '${value.toStringAsFixed(0)} Gr';
    }
    return '${_trimDecimal(value)} Adet';
  }

  String _trimDecimal(double value) {
    final text = value.toStringAsFixed(2);
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
