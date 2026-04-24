/// Akıllı Malzeme İkame Motoru
/// Her malzeme için uygun alternatif önerisi + oran bilgisi
class IngredientSubstitutes {
  static const Map<String, Map<String, String>> _substitutes = {
    // Süt Ürünleri
    'butter': {
      'tr': 'Yerine: Zeytinyağı (3:4 oran) veya margarin (1:1). Kıvam biraz farklı olur.',
      'en': 'Substitute: Olive oil (3:4 ratio) or margarine (1:1). Texture slightly different.',
    },
    'cream': {
      'tr': 'Yerine: Yoğurt + tereyağı (3:1 karışım) veya süt + un (1 su bardağı süt + 1 yk un). %85 benzer tat.',
      'en': 'Substitute: Yogurt + butter (3:1 mix) or milk + flour (1 cup milk + 1 tbsp flour). ~85% similar taste.',
    },
    'milk': {
      'tr': 'Yerine: Su + 1 yk tereyağı veya yoğurt (sulandırılmış). Pişirme için fark etmez.',
      'en': 'Substitute: Water + 1 tbsp butter or diluted yogurt. Works fine for cooking.',
    },
    'yogurt': {
      'tr': 'Yerine: Ekşi krema (1:1) veya süzme peynir + biraz su. Lezzet çok yakın.',
      'en': 'Substitute: Sour cream (1:1) or strained cheese + water. Very similar flavor.',
    },
    'cheese': {
      'tr': 'Yerine: Lor peyniri veya süzme yoğurt. Daha hafif bir tat verir.',
      'en': 'Substitute: Cottage cheese or strained yogurt. Gives a lighter taste.',
    },

    // Yağlar
    'olive_oil': {
      'tr': 'Yerine: Ayçiçek yağı (1:1) veya tereyağı. Lezzet profili değişir ama işe yarar.',
      'en': 'Substitute: Sunflower oil (1:1) or butter. Flavor profile changes but works.',
    },
    'sunflower_oil': {
      'tr': 'Yerine: Zeytinyağı veya mısırözü yağı (1:1). Kızartma için aynı sonuç.',
      'en': 'Substitute: Olive oil or corn oil (1:1). Same result for frying.',
    },

    // Proteinler
    'egg': {
      'tr': 'Yerine: 3 yk yoğurt (bağlayıcı olarak) veya 1 muz (tatlılarda). Kabartma için 1 çk sirke + 1 çk karbonat.',
      'en': 'Substitute: 3 tbsp yogurt (as binder) or 1 banana (in desserts). For leavening: 1 tsp vinegar + 1 tsp baking soda.',
    },
    'chicken': {
      'tr': 'Yerine: Hindi eti (1:1) veya balık. Pişirme süresi benzer.',
      'en': 'Substitute: Turkey (1:1) or fish. Similar cooking time.',
    },
    'ground_beef': {
      'tr': 'Yerine: Dana kıyma (1:1), tavuk kıyma veya mercimek (vegan alternatif).',
      'en': 'Substitute: Veal mince (1:1), chicken mince, or lentils (vegan option).',
    },

    // Sebzeler
    'tomato': {
      'tr': 'Yerine: 2 yk domates salçası + yarım su bardağı su. Konsantre lezzet verir.',
      'en': 'Substitute: 2 tbsp tomato paste + half cup water. Gives concentrated flavor.',
    },
    'onion': {
      'tr': 'Yerine: Pırasa (1:1) veya 1 çk soğan tozu. Doku farklı ama tat yakın.',
      'en': 'Substitute: Leek (1:1) or 1 tsp onion powder. Different texture, similar taste.',
    },
    'garlic': {
      'tr': 'Yerine: Yarım çk sarımsak tozu = 1 diş sarımsak. Taze kadar aromatik değil ama iş görür.',
      'en': 'Substitute: ½ tsp garlic powder = 1 clove. Not as aromatic but works.',
    },
    'pepper_green': {
      'tr': 'Yerine: Sivri biber veya kapya biber. Acılık seviyesine dikkat!',
      'en': 'Substitute: Banana pepper or red pepper. Watch the spice level!',
    },
    'potato': {
      'tr': 'Yerine: Tatlı patates (1:1) veya kereviz kökü. Kıvam benzer, tat farklı.',
      'en': 'Substitute: Sweet potato (1:1) or celeriac. Similar texture, different taste.',
    },
    'spinach': {
      'tr': 'Yerine: Pazı (1:1) veya semizotu. Pişirme süresi aynı.',
      'en': 'Substitute: Chard (1:1) or purslane. Same cooking time.',
    },
    'eggplant': {
      'tr': 'Yerine: Kabak (1:1). Kıvam yakın, lezzet daha hafif.',
      'en': 'Substitute: Zucchini (1:1). Similar texture, lighter flavor.',
    },
    'zucchini': {
      'tr': 'Yerine: Patlıcan veya kabak. Benzer kıvam ve pişirme süresi.',
      'en': 'Substitute: Eggplant or squash. Similar texture and cooking time.',
    },

    // Tahıllar
    'rice': {
      'tr': 'Yerine: Bulgur (1:1) veya kuskus (daha hızlı pişer). Pilav yerine bulgur pilavı dene!',
      'en': 'Substitute: Bulgur (1:1) or couscous (cooks faster). Try bulgur pilaf!',
    },
    'flour': {
      'tr': 'Yerine: Nişasta (yarısı kadar) veya irmik. Kıvam için nişasta daha iyi.',
      'en': 'Substitute: Cornstarch (half amount) or semolina. Cornstarch better for thickening.',
    },
    'pasta': {
      'tr': 'Yerine: Erişte veya bulgur. Sos uyumuna dikkat et.',
      'en': 'Substitute: Egg noodles or bulgur. Mind the sauce compatibility.',
    },
    'bread': {
      'tr': 'Yerine: Lavaş veya galeta unu (kaplama için). Bayat ekmek de kullanılabilir.',
      'en': 'Substitute: Flatbread or breadcrumbs (for coating). Stale bread also works.',
    },

    // Baharatlar
    'cumin': {
      'tr': 'Yerine: Kişniş tohumu (yarısı kadar) veya karabiber + biraz tarçın.',
      'en': 'Substitute: Coriander seeds (half amount) or black pepper + pinch of cinnamon.',
    },
    'red_pepper_flakes': {
      'tr': 'Yerine: Pul biber yerine toz biber (yarısı kadar) veya acı sos birkaç damla.',
      'en': 'Substitute: Chili powder (half amount) or few drops of hot sauce.',
    },
    'parsley': {
      'tr': 'Yerine: Dereotu veya taze nane. Farklı ama hoş bir aroma katar.',
      'en': 'Substitute: Dill or fresh mint. Different but pleasant aroma.',
    },

    // Soslar
    'tomato_paste': {
      'tr': 'Yerine: 3 domates (rendelenmiş, suyunu süz) veya biber salçası (1:1).',
      'en': 'Substitute: 3 tomatoes (grated, drained) or pepper paste (1:1).',
    },
    'lemon_juice': {
      'tr': 'Yerine: Sirke (yarısı kadar) veya sumak suyu. Asitlik oranı benzer.',
      'en': 'Substitute: Vinegar (half amount) or sumac juice. Similar acidity.',
    },
    'sugar': {
      'tr': 'Yerine: Bal (3/4 oranında, sıvıyı azalt) veya pekmez. Daha doğal tatlandırıcı.',
      'en': 'Substitute: Honey (3/4 ratio, reduce liquid) or molasses. More natural sweetener.',
    },
  };

  /// Malzeme ID'sine göre ikame önerisi getir
  static String? getSubstitute(String ingredientId, String locale) {
    final sub = _substitutes[ingredientId];
    if (sub == null) return null;
    return locale == 'tr' ? sub['tr'] : sub['en'];
  }

  /// İkame önerisi var mı kontrol et
  static bool hasSubstitute(String ingredientId) {
    return _substitutes.containsKey(ingredientId);
  }

  /// Tüm ikame önerilerinin listesi (debug/test için)
  static List<String> get allIngredientIds => _substitutes.keys.toList();
}
