const marketDisplayNamesById = <String, String>{
  'a101': 'A101',
  'bim': 'BİM',
  'sok': 'ŞOK',
  'migros': 'Migros',
  'carrefoursa': 'CarrefourSA',
  'hakmar': 'Hakmar',
  'hakmar-express': 'Hakmar Express',
  'metro': 'Metro',
  // Supabase `markets` tablosundaki ID ile hizalandi (eski: 'kooperatif').
  'tarim-kredi': 'Tarım Kredi',
  'file': 'File Market',
  'bildirici': 'Bildirici',
  'altunbilekler': 'Altunbilekler',
  'macrocenter': 'Macrocenter',
  'gimsa': 'GİMSA',
  'akyurt': 'Akyurt Süpermarket',
  'getir': 'Getir',
  'yemeksepeti': 'Yemeksepeti',
};

const marketAliasesById = <String, List<String>>{
  'a101': ['a101'],
  'bim': ['bim', 'bım', 'b.i.m', 'bim market'],
  'sok': ['sok', 'şok', 'şok'],
  'migros': ['migros'],
  'carrefoursa': ['carrefoursa', 'carrefour sa', 'carrefour'],
  // 2026-05-02: hakmar (ana zincir, online satis yok) ve hakmar-express
  // (Cepte Hakmar Express, online katalog) farkli market_id'ler — Supabase
  // markets tablosunda iki ayri satir, parsers/__init__.py registry'sinde
  // iki ayri parser. Onceki yapida hakmar-express alias olarak hakmar'a
  // map ediliyordu, kullanici secimi state'e yansimiyordu.
  'hakmar': ['hakmar'],
  'hakmar-express': [
    'hakmar express',
    'hakmarexpress',
    'hakmar-express',
    'cepte hakmar',
    'ceptehakmar',
  ],
  'metro': ['metro', 'metro tr', 'metro-tr'],
  // Supabase'deki kanonik ID 'tarim-kredi'. Eski 'kooperatif' ID'sini alias
  // olarak tutuyoruz ki SharedPreferences'ta saklanmis eski secimler okurken
  // otomatik normalize edilsin.
  'tarim-kredi': [
    'tarim-kredi',
    'tarim kredi',
    'tarım kredi',
    'kooperatif',
    'kooperatif market',
    'tarim kredi kooperatifi',
    'tarım kredi kooperatifi',
    'kooperatifmarket',
  ],
  'file': ['file', 'file market', 'filemarket'],
  'bildirici': ['bildirici'],
  'altunbilekler': ['altunbilekler', 'altun bilekler'],
  'macrocenter': ['macrocenter', 'macro center'],
  'gimsa': ['gimsa', 'gimsa market'],
  'akyurt': ['akyurt', 'akyurt supermarket', 'akyurt süpermarket', 'akyurtsupermarket'],
  'getir': ['getir'],
  'yemeksepeti': ['yemeksepeti', 'yemek sepeti'],
};

String normalizeMarketToken(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

String? normalizeMarketId(String? value) {
  if (value == null) return null;
  final normalized = normalizeMarketToken(value);
  if (normalized.isEmpty) return null;

  if (marketDisplayNamesById.containsKey(normalized)) {
    return normalized;
  }

  for (final entry in marketAliasesById.entries) {
    final aliases = entry.value;
    if (aliases.any((alias) => normalizeMarketToken(alias) == normalized)) {
      return entry.key;
    }
  }

  for (final entry in marketDisplayNamesById.entries) {
    if (normalizeMarketToken(entry.value) == normalized) {
      return entry.key;
    }
  }

  return null;
}

String displayNameForMarket(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '';
  }
  final id = normalizeMarketId(value);
  return id == null ? value.trim() : marketDisplayNamesById[id]!;
}

List<String> normalizeMarketIds(Iterable<String> values) {
  final ids = <String>[];
  for (final value in values) {
    final id = normalizeMarketId(value);
    if (id != null && !ids.contains(id)) {
      ids.add(id);
    }
  }
  return ids;
}
