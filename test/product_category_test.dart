import 'package:flutter_test/flutter_test.dart';
import 'package:yakinimda_en_ucuz/utils/product_category.dart';

void main() {
  test('categorizeProduct matches Turkish grocery titles', () {
    expect(
      categorizeProduct('S\u00fct ve Yo\u011furt Paketi'),
      ProductCategory.food,
    );
    expect(
      categorizeProduct('Bula\u015f\u0131k Deterjan\u0131 4 L'),
      ProductCategory.cleaning,
    );
    expect(
      categorizeProduct('Pa\u015fabah\u00e7e Su Barda\u011f\u0131 6\'l\u0131'),
      ProductCategory.home,
    );
    expect(
      categorizeProduct('Kablosuz Bluetooth Kulakl\u0131k'),
      ProductCategory.electronics,
    );
    expect(
      categorizeProduct('Kad\u0131n Spor Ayakkab\u0131'),
      ProductCategory.clothing,
    );
  });

  test('product category labels and emoji stay readable', () {
    expect(ProductCategory.food.labelTr, 'G\u0131da & \u0130\u00e7ecek');
    expect(ProductCategory.cleaning.labelTr, 'Temizlik & Bak\u0131m');
    expect(ProductCategory.home.emoji, '\u{1F3E0}');
  });

  test('brand and weight parsing keep expected values', () {
    expect(
      parseProductBrand('\u0130\u00e7im Az Ya\u011fl\u0131 S\u00fct 1 L'),
      '\u0130\u00e7im',
    );
    expect(
      parseProductWeight(
          'GRAN TOYS Oyun Arkada\u015f\u0131m Pelu\u015f Z\u00fcrafa 100cm'),
      '100 cm',
    );
  });
}

