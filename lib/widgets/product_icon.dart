import 'package:flutter/material.dart';

/// Ürün adına göre emoji + arka plan rengi döndürür.
/// ProductCategory enum'u ile uyumlu ek refinement yapılmış.
///
/// Kullanım:
/// ```dart
/// ProductIcon(title: item.productTitle, size: 52)
/// ```
class ProductIcon extends StatelessWidget {
  final String title;
  final double size;
  final double borderRadius;

  const ProductIcon({
    super.key,
    required this.title,
    this.size = 52,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final visual = ProductIconResolver.resolve(title);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: visual.bg,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Text(
        visual.emoji,
        style: TextStyle(fontSize: size * 0.52),
      ),
    );
  }
}

/// Ürün adından emoji + arka plan rengi belirleyen statik resolver.
class ProductIconResolver {
  const ProductIconResolver._();

  static _ProductVisual resolve(String productTitle) {
    final t = _norm(productTitle);

    // ── Süt & Kahvaltılık ──────────────────────────────────
    if (_has(t, ['tam yagli sut', 'yari yagli sut', 'suttas', 'pinar sut', 'sek sut', ' sut ']))
      return const _ProductVisual('🥛', Color(0xFFEFF6FF)); // mavi-beyaz
    if (_has(t, ['ayran']))
      return const _ProductVisual('🥛', Color(0xFFF0FDF4)); // yeşil-beyaz
    if (_has(t, ['kefir']))
      return const _ProductVisual('🍶', Color(0xFFECFDF5));
    if (_has(t, ['yogurt', 'suzme', 'labne']))
      return const _ProductVisual('🥣', Color(0xFFF0FDF4));
    if (_has(t, ['kaymak', 'krema']))
      return const _ProductVisual('🍮', Color(0xFFFFF7ED));
    if (_has(t, ['kasar', 'kashar']))
      return const _ProductVisual('🧀', Color(0xFFFEF9C3)); // sarı bg
    if (_has(t, ['tulum peynir', 'beyaz peynir', 'lor peynir', 'peynir']))
      return const _ProductVisual('🧀', Color(0xFFF8FAFC)); // gri-beyaz bg
    if (_has(t, ['tereyagi', 'tereyag']))
      return const _ProductVisual('🧈', Color(0xFFFEF9C3));
    if (_has(t, ['margarin']))
      return const _ProductVisual('🧈', Color(0xFFFFF3E0));
    if (_has(t, ['yumurta']))
      return const _ProductVisual('🥚', Color(0xFFFEF3C7));

    // ── Et & Tavuk ─────────────────────────────────────────
    if (_has(t, ['pilic gogus', 'pilic but', 'piliç', 'pilic', 'tavuk', 'hindi']))
      return const _ProductVisual('🍗', Color(0xFFFFF7ED));
    if (_has(t, ['dana kiyma', 'kuzu kiyma', 'kiyma']))
      return const _ProductVisual('🥩', Color(0xFFFFE4E6));
    if (_has(t, ['biftek', 'antrikot', 'bonfile', 'dana et']))
      return const _ProductVisual('🥩', Color(0xFFFFE4E6));
    if (_has(t, ['sucuk']))
      return const _ProductVisual('🌭', Color(0xFFFFEDD5));
    if (_has(t, ['salam', 'sosis', 'jambon']))
      return const _ProductVisual('🥩', Color(0xFFFEE2E2));
    if (_has(t, ['balik', 'somon', 'ton balik', 'karides']))
      return const _ProductVisual('🐟', Color(0xFFDBEAFE));

    // ── Meyve & Sebze ─────────────────────────────────────
    if (_has(t, ['domates']))
      return const _ProductVisual('🍅', Color(0xFFFEE2E2)); // KIRMIZI bg
    if (_has(t, ['elma']))
      return const _ProductVisual('🍎', Color(0xFFDCFCE7)); // YEŞİL bg — domatesle zıt
    if (_has(t, ['muz']))
      return const _ProductVisual('🍌', Color(0xFFFEFCE8));
    if (_has(t, ['portakal', 'mandalina']))
      return const _ProductVisual('🍊', Color(0xFFFFEDD5));
    if (_has(t, ['limon']))
      return const _ProductVisual('🍋', Color(0xFFFEFCE8));
    if (_has(t, ['uzum', 'cilek']))
      return const _ProductVisual('🍇', Color(0xFFF3E8FF));
    if (_has(t, ['karpuz']))
      return const _ProductVisual('🍉', Color(0xFFFEE2E2));
    if (_has(t, ['kavun']))
      return const _ProductVisual('🍈', Color(0xFFECFDF5));
    if (_has(t, ['patates']))
      return const _ProductVisual('🥔', Color(0xFFFEF3C7));
    if (_has(t, ['sogan']))
      return const _ProductVisual('🧅', Color(0xFFFFF7ED));
    if (_has(t, ['sarimsak']))
      return const _ProductVisual('🧄', Color(0xFFFAFAF9));
    if (_has(t, ['biber', 'dolmalik biber']))
      return const _ProductVisual('🫑', Color(0xFFDCFCE7));
    if (_has(t, ['salatalik']))
      return const _ProductVisual('🥒', Color(0xFFDCFCE7));
    if (_has(t, ['patlican']))
      return const _ProductVisual('🍆', Color(0xFFF3E8FF));
    if (_has(t, ['havuc']))
      return const _ProductVisual('🥕', Color(0xFFFFEDD5));
    if (_has(t, ['ispanak', 'marul', 'lahana', 'brokoli', 'karnabahar']))
      return const _ProductVisual('🥦', Color(0xFFDCFCE7));
    if (_has(t, ['mantar']))
      return const _ProductVisual('🍄', Color(0xFFF5F5F4));
    if (_has(t, ['kabak']))
      return const _ProductVisual('🥬', Color(0xFFDCFCE7));

    // ── Fırın & Ekmek ──────────────────────────────────────
    if (_has(t, ['simit']))
      return const _ProductVisual('🥯', Color(0xFFFFEDD5)); // amber — ekmekten farklı
    if (_has(t, ['pogaca', 'acma', 'borek']))
      return const _ProductVisual('🥐', Color(0xFFFFF7ED));
    if (_has(t, ['ekmek', 'somun', 'pide', 'lavas', 'tortilla']))
      return const _ProductVisual('🍞', Color(0xFFFEF3C7)); // buğday tonu

    // ── İçecek ────────────────────────────────────────────
    // Kola: kırmızı kutu — KIRMIZI bg ama açık ton
    if (_has(t, ['coca cola', 'pepsi', 'cola', 'fanta', 'sprite', 'gazoz', 'soda']))
      return const _ProductVisual('🥤', Color(0xFFFEE2E2));
    // Su: şeffaf şişe — MAVİ bg; koladan farklı
    if (_has(t, [' su ', 'maden suyu', 'dogal kaynak', 'sise su']))
      return const _ProductVisual('💧', Color(0xFFEFF6FF));
    // Ayran (üstte zaten yakalandı, burada limonata vb.)
    if (_has(t, ['limonata', 'meyve suyu', 'meyve suyu', 'ice tea']))
      return const _ProductVisual('🧃', Color(0xFFFEF9C3));
    if (_has(t, ['enerji icecegi', 'red bull', 'monster', 'burn']))
      return const _ProductVisual('⚡', Color(0xFFFEFCE8));
    if (_has(t, ['kahve', 'nescafe', 'kapucino', 'latte']))
      return const _ProductVisual('☕', Color(0xFFF5F0EB));
    if (_has(t, ['cay', 'bitki cayi']))
      return const _ProductVisual('🍵', Color(0xFFECFDF5));
    if (_has(t, ['bira']))
      return const _ProductVisual('🍺', Color(0xFFFEF9C3));

    // ── Temel Gıda ────────────────────────────────────────
    if (_has(t, ['makarna', 'spagetti', 'penne', 'fusilli']))
      return const _ProductVisual('🍝', Color(0xFFFFF7ED));
    if (_has(t, ['pirinc']))
      return const _ProductVisual('🍚', Color(0xFFF8FAFC));
    if (_has(t, ['bulgur', 'irmik']))
      return const _ProductVisual('🌾', Color(0xFFFEF3C7));
    if (_has(t, ['mercimek', 'nohut', 'fasulye', 'baklagil']))
      return const _ProductVisual('🫘', Color(0xFFFFEDD5));
    if (_has(t, ['un', 'misir unu']))
      return const _ProductVisual('🌾', Color(0xFFFFF7ED));
    if (_has(t, ['seker']))
      return const _ProductVisual('🍬', Color(0xFFFFF0F5));
    if (_has(t, ['tuz']))
      return const _ProductVisual('🧂', Color(0xFFF8FAFC));
    if (_has(t, ['zeytinyagi']))
      return const _ProductVisual('🫙', Color(0xFFECFDF5));
    if (_has(t, ['aycicek yagi', 'sivi yag']))
      return const _ProductVisual('🫙', Color(0xFFFEF9C3));
    if (_has(t, ['salca', 'domates salca']))
      return const _ProductVisual('🫙', Color(0xFFFEE2E2));
    if (_has(t, ['recel', 'bal', 'pekmez']))
      return const _ProductVisual('🍯', Color(0xFFFEF3C7));
    if (_has(t, ['tahin']))
      return const _ProductVisual('🫙', Color(0xFFFFF7ED));
    if (_has(t, ['zeytin']))
      return const _ProductVisual('🫒', Color(0xFFECFDF5));
    if (_has(t, ['tursu']))
      return const _ProductVisual('🥒', Color(0xFFECFDF5));

    // ── Atıştırmalık ──────────────────────────────────────
    if (_has(t, ['cips', 'cips', 'corn']))
      return const _ProductVisual('🍟', Color(0xFFFEF9C3));
    if (_has(t, ['cikolata', 'chocolate']))
      return const _ProductVisual('🍫', Color(0xFFFFF0E5));
    if (_has(t, ['biskuvi', 'gofret', 'kraker']))
      return const _ProductVisual('🍪', Color(0xFFFEF3C7));
    if (_has(t, ['findik', 'ceviz', 'badem', 'fistik', 'kuruyemis']))
      return const _ProductVisual('🥜', Color(0xFFFFEDD5));
    if (_has(t, ['dondurma']))
      return const _ProductVisual('🍦', Color(0xFFF0F9FF));

    // ── Temizlik ──────────────────────────────────────────
    // Çamaşır Suyu: camgöbeği bg — deterjan (mor) dan farklı
    if (_has(t, ['camasir suyu', 'cif', 'javel', 'deterjan suyu']))
      return const _ProductVisual('🫧', Color(0xFFCFFAFE));
    // Sıvı/Toz Deterjan: mor/lavanta bg
    if (_has(t, ['deterjan', 'camasir deterjan', 'bulasik', 'yumusatici']))
      return const _ProductVisual('🧴', Color(0xFFF3E8FF));
    if (_has(t, ['cop torbasi', 'cop poset']))
      return const _ProductVisual('🗑️', Color(0xFFE5E7EB));
    if (_has(t, ['sabun', 'el sabunu']))
      return const _ProductVisual('🧼', Color(0xFFECFDF5));
    if (_has(t, ['tuvalet kagidi', 'kagit havlu', 'islak mendil', 'pecete']))
      return const _ProductVisual('🧻', Color(0xFFF8FAFC));

    // ── Kişisel Bakım ─────────────────────────────────────
    if (_has(t, ['sampuan', 'sac']))
      return const _ProductVisual('🧴', Color(0xFFEDE9FE));
    if (_has(t, ['dis macunu']))
      return const _ProductVisual('🪥', Color(0xFFEFF6FF));
    if (_has(t, ['dis fircasi']))
      return const _ProductVisual('🪥', Color(0xFFDBEAFE));
    if (_has(t, ['deodorant', 'roll on']))
      return const _ProductVisual('🧴', Color(0xFFF0FDF4));
    if (_has(t, ['tiras', 'jilet']))
      return const _ProductVisual('🪒', Color(0xFFF8FAFC));
    if (_has(t, ['parfum', 'kolonya']))
      return const _ProductVisual('🌸', Color(0xFFFDF4FF));

    // ── Bebek ──────────────────────────────────────────────
    if (_has(t, ['bebek bezi', 'pampers', 'molfix']))
      return const _ProductVisual('👶', Color(0xFFFFF7ED));
    if (_has(t, ['bebek mamasi', 'bebek sutu']))
      return const _ProductVisual('🍼', Color(0xFFFEF3C7));

    // ── Evcil Hayvan ──────────────────────────────────────
    if (_has(t, ['kedi mamas', 'kopek mamas', 'kedi kumu']))
      return const _ProductVisual('🐾', Color(0xFFFFF7ED));

    // ── Fallback ──────────────────────────────────────────
    return const _ProductVisual('🛒', Color(0xFFFFF5F2));
  }

  static String _norm(String value) => value
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');

  static bool _has(String normalized, List<String> keywords) {
    for (final kw in keywords) {
      if (normalized.contains(_norm(kw))) return true;
    }
    return false;
  }
}

class _ProductVisual {
  final String emoji;
  final Color bg;
  const _ProductVisual(this.emoji, this.bg);
}
