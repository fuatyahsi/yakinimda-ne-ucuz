import 'package:flutter_test/flutter_test.dart';
import 'package:yakinimda_en_ucuz/utils/product_category.dart';
import 'package:yakinimda_en_ucuz/widgets/product_icon.dart';

void main() {
  test('uses specific food icons for frozen catalog titles', () {
    expect(
      ProductIconResolver.resolve(
        'Dondurulmus Misir 450 Gr',
        categoryId: 'dondurulmus-sebze',
        category: ProductCategory.food,
      ).emoji,
      '\u{1F33D}',
    );
    expect(
      ProductIconResolver.resolve(
        'Dondurulmus Orman Meyveleri 300 Gr',
        categoryId: 'dondurulmus-sebze',
        category: ProductCategory.food,
      ).emoji,
      '\u{1F353}',
    );
  });

  test('uses category fallback instead of cart for broad catalog groups', () {
    expect(
      ProductIconResolver.resolve(
        'Saklama Kabi 4lu',
        categoryId: 'mutfak-esya',
        category: ProductCategory.home,
      ).emoji,
      '\u{1F37D}\u{FE0F}',
    );
    expect(
      ProductIconResolver.resolve(
        'ABC Yuzey Temizleyici 2.5 L',
        categoryId: 'yuzey-temizleyici',
        category: ProductCategory.cleaning,
      ).emoji,
      '\u{1F9F4}',
    );
    expect(
      ProductIconResolver.resolve(
        'Adelfa Kadin Cift Toka Terlik',
        categoryId: 'tekstil',
        category: ProductCategory.clothing,
      ).emoji,
      '\u{1F455}',
    );
  });
}
