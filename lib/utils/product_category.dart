import 'package:flutter/material.dart';

enum ProductCategory {
  food,
  cleaning,
  home,
  electronics,
  clothing,
  other,
}

extension ProductCategoryExtension on ProductCategory {
  String get labelTr {
    switch (this) {
      case ProductCategory.food:
        return 'G\u0131da & \u0130\u00e7ecek';
      case ProductCategory.cleaning:
        return 'Temizlik & Bak\u0131m';
      case ProductCategory.home:
        return 'Ev & Mutfak';
      case ProductCategory.electronics:
        return 'Teknoloji & Elektronik';
      case ProductCategory.clothing:
        return 'Giyim & Ayakkab\u0131';
      case ProductCategory.other:
        return 'Di\u011fer';
    }
  }

  String get labelEn {
    switch (this) {
      case ProductCategory.food:
        return 'Food & Beverages';
      case ProductCategory.cleaning:
        return 'Cleaning & Care';
      case ProductCategory.home:
        return 'Home & Kitchen';
      case ProductCategory.electronics:
        return 'Technology & Electronics';
      case ProductCategory.clothing:
        return 'Clothing & Footwear';
      case ProductCategory.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case ProductCategory.food:
        return Icons.restaurant_rounded;
      case ProductCategory.cleaning:
        return Icons.cleaning_services_rounded;
      case ProductCategory.home:
        return Icons.chair_rounded;
      case ProductCategory.electronics:
        return Icons.devices_other_rounded;
      case ProductCategory.clothing:
        return Icons.checkroom_rounded;
      case ProductCategory.other:
        return Icons.category_rounded;
    }
  }

  String get emoji {
    switch (this) {
      case ProductCategory.food:
        return '\u{1F37D}\uFE0F';
      case ProductCategory.cleaning:
        return '\u{1F9FC}';
      case ProductCategory.home:
        return '\u{1F3E0}';
      case ProductCategory.electronics:
        return '\u{1F4F1}';
      case ProductCategory.clothing:
        return '\u{1F45F}';
      case ProductCategory.other:
        return '\u{1F4E6}';
    }
  }
}

const Map<ProductCategory, List<String>> _categoryKeywordMap = {
  ProductCategory.food: [
    // Süt ürünleri
    'sut',
    'peynir',
    'yogurt',
    'ayran',
    'tereyagi',
    'kaymak',
    'kefir',
    'labne',
    'lor',
    'krema',
    'kasar',
    'beyaz peynir',
    'tulum',
    'suzme',
    // Et & balık
    'tavuk',
    'pilic',
    'dana',
    'kiyma',
    'kuzu',
    'kofte',
    'salam',
    'sucuk',
    'balik',
    'sosis',
    'pastirma',
    'doner',
    'hindi',
    'karides',
    'ton balik',
    'somon',
    'jambon',
    'kavurma',
    // Temel gıda
    'makarna',
    'bulgur',
    'pirinc',
    'mercimek',
    'nohut',
    'fasulye',
    'seker',
    'tuz',
    'un',
    'irmik',
    'misir',
    'bogurtlen',
    // Atıştırmalık & tatlı
    'cikolata',
    'gofret',
    'biskuvi',
    'kraker',
    'cips',
    'kuruyemis',
    'findik',
    'ceviz',
    'badem',
    'antep fistigi',
    'leblebi',
    'kek',
    'muffin',
    'brownie',
    'kurabiye',
    'sakiz',
    'sekerleme',
    // Dondurma
    'dondurma',
    'magnum',
    'cornetto',
    'buzlu',
    // Konserve & sos
    'corba',
    'salca',
    'tursu',
    'zeytin',
    'pekmez',
    'tahin',
    'recel',
    'bal',
    'ketcap',
    'mayonez',
    'hardal',
    'sos',
    'konserve',
    // Kahvaltılık
    'yumurta',
    'helva',
    'gevrek',
    'musli',
    'granola',
    'protein bar',
    // Yağ
    'zeytinyagi',
    'aycicek yagi',
    'misir yagi',
    'sivi yag',
    'margarin',
    // İçecek
    'maden suyu',
    'limonata',
    'kahve',
    'cay',
    'icecek',
    'su',
    'meyve suyu',
    'gazoz',
    'kola',
    'enerji icecegi',
    'soda',
    'ayran',
    'bitki cayi',
    // Fırın & unlu
    'ekmek',
    'simit',
    'pogaca',
    'baklava',
    'kadayif',
    'lokum',
    'borek',
    'pide',
    'lavas',
    'galeta',
    'tost',
    // Meyve & sebze
    'meyve',
    'sebze',
    'domates',
    'biber',
    'patates',
    'sogan',
    'salatalik',
    'havuc',
    'elma',
    'portakal',
    'muz',
    'uzum',
    'cilek',
    'karpuz',
    'kavun',
    'mandalina',
    'limon',
    'ispanak',
    'marul',
    'lahana',
    'brokoli',
    'karnabahar',
    'mantar',
    'patlican',
    'kabak',
    'bamya',
    'enginar',
    // Dondurulmuş
    'dondurulmus',
    'donuk',
    'buzda',
    // Pratik yemek
    'hazir yemek',
    'pratik',
    'pizza',
    'lahmacun',
    'nugget',
    // Baharat
    'baharat',
    'karabiber',
    'kekik',
    'kimyon',
    'tarcin',
    'pul biber',
    'nane',
    'defne',
    'sumak',
  ],
  ProductCategory.cleaning: [
    // Ev temizlik
    'temizlik',
    'deterjan',
    'sabun',
    'camasir',
    'bulasik',
    'tuvalet kagidi',
    'kagit havlu',
    'yuzey temizleyici',
    'dezenfektan',
    'camasir suyu',
    'cif',
    'domestos',
    'tuz ruhu',
    'amonyak',
    'leke cikartici',
    // Kişisel bakım
    'sampuan',
    'krem',
    'losyon',
    'deodorant',
    'dis macunu',
    'dis fircasi',
    'sac maskesi',
    'tiras',
    'ped',
    'parlatici',
    'lavabo acici',
    'kirec cozucu',
    'yumusatici',
    'cop torbasi',
    'agda',
    'parfum',
    'kolonya',
    'duus jeli',
    'vucut losyonu',
    'el kremi',
    'gunes kremi',
    'sac boyasi',
    'sac jeli',
    'sac spreyi',
    'makyaj',
    'fondoten',
    'maskara',
    'ruj',
    'oje',
    'pamuk',
    'kulak cubugu',
    'pecete',
    'islak mendil',
    'bez',
    // Bebek bakım
    'bebek bezi',
    'biberon',
    'emzik',
    'bebek mamasi',
    'bebek sampuani',
    'bebek kremi',
    'bebek pudrasi',
    'bebek mendili',
    // Evcil hayvan
    'kedi mamasi',
    'kopek mamasi',
    'kedi kumu',
    'pet food',
    'evcil hayvan',
    'kedi',
    'kopek',
    'hayvan mamasi',
  ],
  ProductCategory.home: [
    'tencere',
    'tava',
    'bardak',
    'bardag',
    'tabak',
    'fincan',
    'surahi',
    'saklama kabi',
    'termos',
    'caydanlik',
    'sahan',
    'kavanoz',
    'tepsi',
    'bicak',
    'soyacak',
    'organizer',
    'duzenleyici',
    'dolap',
    'sehpa',
    'raf',
    'ayakkabilik',
    'sifonyer',
    'gardirop',
    'tv unitesi',
    'konsol',
    'masa',
    'sandalye',
    'yastik',
    'yorgan',
    'nevresim',
    'carsaf',
    'alez',
    'paspas',
    'havlu',
    'seccade',
    'matara',
    'baharatlik',
    'sekerlik',
    'sabunluk',
    'buzdolabi organizeri',
    'sineklik',
    'mum',
    'koku',
    'saksak',
    'hali',
    'perde',
    'catal',
    'kasik',
    'supla',
    'servis',
    'koltuk',
    'berjer',
    'komdin',
    'ayna',
    'saat',
    'cerceve',
    'askisi',
    'sepet',
    'kutu',
    'poset',
    'streç',
    'folyo',
    'yagli kagit',
    'firinlama kagidi',
  ],
  ProductCategory.electronics: [
    'telefon',
    'smartphone',
    'tablet',
    'televizyon',
    'tv',
    'kulaklik',
    'hoparlor',
    'soundbar',
    'kamera',
    'guvenlik kamerasi',
    'akilli saat',
    'mouse',
    'hub',
    'sarj',
    'adaptor',
    'powerbank',
    'yazici',
    'bulasik makinesi',
    'camasir makinesi',
    'kurutma makinesi',
    'buzdolabi',
    'mikrodalga',
    'supurge',
    'fon makinesi',
    'epilasyon',
    'airfryer',
    'kahve makinesi',
    'cay makinesi',
    'blender seti',
    'mikser',
    'ankastre',
    'baskul',
    'elektrikli bisiklet',
    'capa makinesi',
    'airshape',
    'lazer epilasyon',
    'laptop',
    'notebook',
    'bilgisayar',
    'monitor',
    'klavye',
    'usb',
    'hdmi',
    'kablo',
    'pil',
    'batarya',
    'led',
    'ampul',
    'avize',
    'aplik',
    'lamba',
    'robot supurge',
    'utu',
    'tost makinesi',
    'ekmek makinesi',
    'mutfak robotu',
    'el blenderi',
    'sicak hava',
    'klima',
    'vantilatör',
    'isitici',
    'nem alma',
    'hava temizleyici',
    'firini',
    'ocak',
    'davlumbaz',
    'bulaşık',
  ],
  ProductCategory.clothing: [
    'ayakkabi',
    'spor ayakkabi',
    'terlik',
    'corap',
    'sutyen',
    'slip',
    'pijama',
    'pantolon',
    'sort',
    'esofman',
    'tisort',
    'gomlek',
    'elbise',
    'sal',
    'canta',
    'valiz',
    'kol saati',
    'mont',
    'kaban',
    'yelek',
    'kazak',
    'hirka',
    'sweatshirt',
    'etek',
    'sapka',
    'atki',
    'bere',
    'eldiven',
    'sandalet',
    'bot',
    'cizme',
    'ic camasir',
    'tayt',
    'elbise',
    'jean',
    'kot',
    'ince mont',
    'yagmurluk',
    'mayo',
    'bikini',
    'sirt cantasi',
    'el cantasi',
    'bel cantasi',
    'kemer',
    'gozluk',
    'gunes gozlugu',
  ],
};

const _knownBrands = [
  'Aknaz',
  'Activia',
  'Addison',
  'Ak\u015feker',
  'Alberto',
  'Alpro',
  'Arnica',
  'Asperox',
  'Balparmak',
  'Baroness',
  'Bee\'o',
  'Bifa',
  'B\u0130M',
  'Binvezir',
  'Bingo',
  'Bonera',
  'Casilda',
  'Casilli',
  'Chef\'s',
  'Childgen',
  'Dagi',
  'Dalan',
  'Dijitsu',
  'Dost',
  'Efsane',
  'Ekmecik',
  'Emin',
  'Eti',
  'Fakir',
  'Fushia',
  'Glass In Love',
  'Gokidy',
  'Haribo',
  'Heifer',
  'Hisar',
  'Homendra',
  'House Pratik',
  '\u0130\u00e7im',
  '\u0130nci',
  'Kumtel',
  'Lav',
  'LG',
  'Maybelline',
  'Mikado',
  'Molped',
  'Nescafe',
  'Nivea',
  'Olux',
  'Onvo',
  'Pa\u015fabah\u00e7e',
  'Papilla',
  'Philips',
  'Piccolo Mondi',
  'Pirge',
  'Polosmart',
  'Queen',
  'Rakle',
  'Sek',
  'Serel',
  'Sole',
  'Stanley',
  'SuperFresh',
  'Sunny',
  'Teks\u00fct',
  'Tombik',
  'Torku',
  'Vip',
  'Y\u00f6rsan',
];

/// Maps well-known API menu/main categories to local product categories.
const Map<String, ProductCategory> _apiCategoryMap = {
  'meyve ve sebze': ProductCategory.food,
  'et, tavuk ve balik': ProductCategory.food,
  'sut urunleri': ProductCategory.food,
  'kahvaltilik': ProductCategory.food,
  'sut urunleri ve kahvaltilik': ProductCategory.food,
  'temel gida': ProductCategory.food,
  'icecek': ProductCategory.food,
  'atistirmalik ve tatli': ProductCategory.food,
  'dondurma': ProductCategory.food,
  'dondurulmus': ProductCategory.food,
  'pratik yemek': ProductCategory.food,
  'fit form': ProductCategory.food,
  'kisisel bakim': ProductCategory.cleaning,
  'ev bakim': ProductCategory.cleaning,
  'kagit urunleri': ProductCategory.cleaning,
  'bebek': ProductCategory.cleaning,
  'evcil hayvan': ProductCategory.cleaning,
  'temizlik ve kisisel bakim urunleri': ProductCategory.cleaning,
  'cinsel saglik': ProductCategory.cleaning,
  'ev ve yasam': ProductCategory.home,
  'elektronik': ProductCategory.electronics,
};

ProductCategory categorizeProduct(String productTitle) {
  final normalizedTitle = _normalizeTr(productTitle);

  // First try to match API category info embedded in the title string.
  for (final entry in _apiCategoryMap.entries) {
    if (normalizedTitle.contains(entry.key)) {
      return entry.value;
    }
  }

  // Fall back to keyword matching with word-boundary awareness.
  for (final entry in _categoryKeywordMap.entries) {
    final hasMatch = entry.value.any((keyword) {
      final index = normalizedTitle.indexOf(keyword);
      if (index < 0) return false;
      // Check word boundary: either at start or preceded by a non-letter.
      if (index > 0) {
        final charBefore = normalizedTitle[index - 1];
        if (charBefore != ' ' &&
            charBefore != ',' &&
            charBefore != '/' &&
            charBefore != '-' &&
            charBefore != '(' &&
            charBefore != ')') {
          return false;
        }
      }
      return true;
    });
    if (hasMatch) {
      return entry.key;
    }
  }
  return ProductCategory.other;
}

String? parseProductWeight(String productTitle) {
  final normalizedTitle = _normalizeTr(productTitle);
  final match = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(kg|g|gr|gram|ml|cl|cc|l|lt|litre|paket|adet|rulo|parca|li)',
    caseSensitive: false,
  ).firstMatch(normalizedTitle);
  if (match == null) {
    final dimensionMatch = RegExp(
      r'(\d+\s*x\s*\d+(?:\s*x\s*\d+)?)\s*(cm|mm|m)',
      caseSensitive: false,
    ).firstMatch(normalizedTitle);
    if (dimensionMatch != null) {
      return '${dimensionMatch.group(1)} ${dimensionMatch.group(2)}';
    }
    final sizeMatch = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(cm|mm|m)',
      caseSensitive: false,
    ).firstMatch(normalizedTitle);
    if (sizeMatch == null) {
      return null;
    }
    return '${sizeMatch.group(1)} ${sizeMatch.group(2)}';
  }
  return '${match.group(1)} ${match.group(2)}';
}

String? parseProductBrand(String productTitle) {
  final normalizedTitle = _normalizeTr(productTitle);
  for (final brand in _knownBrands) {
    if (normalizedTitle.startsWith(_normalizeTr(brand))) {
      return brand;
    }
  }
  return null;
}

String _normalizeTr(String value) {
  return value
      .toLowerCase()
      .replaceAll('\u0131', 'i')
      .replaceAll('\u011f', 'g')
      .replaceAll('\u00fc', 'u')
      .replaceAll('\u015f', 's')
      .replaceAll('\u00f6', 'o')
      .replaceAll('\u00e7', 'c');
}
