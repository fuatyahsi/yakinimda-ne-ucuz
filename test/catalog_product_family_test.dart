import 'package:flutter_test/flutter_test.dart';
import 'package:yakinimda_en_ucuz/models/smart_actueller.dart';
import 'package:yakinimda_en_ucuz/utils/catalog_product_family.dart';

void main() {
  test('groups one liter water across brands as one product family', () {
    final items = [
      _item(
        'Carrefour Discount Su 1 Lt',
        brand: 'Carrefour',
        price: 11.75,
      ),
      _item('Saka Do\u011Fal Mineralli Su 1 Lt', brand: 'Saka', price: 27),
      _item('Damla Su 1 Lt', brand: 'Damla', price: 29.90),
      _item('P\u0131nar Su 1 Lt', brand: 'P\u0131nar', price: 30.90),
      _item('Erikli Su 1 Lt', brand: 'Erikli', price: 39.25),
    ];

    final grouped = groupCatalogItemsByProductFamily(items);

    expect(grouped, hasLength(1));
    expect(catalogProductFamilyTitle(grouped.single), 'Su 1 Lt');
    expect(grouped.single.price, 11.75);
  });

  test('keeps fruit juice separate from plain water', () {
    final water = _item('Damla Su 1 Lt', brand: 'Damla');
    final juice = _item(
      'Dimes Meyve Suyu 1 Lt',
      brand: 'Dimes',
      sourceMenuCategory: 'meyve-suyu',
    );

    expect(sameCatalogProductFamily(water, juice), isFalse);
  });

  test('groups same cheese specification across brands', () {
    final sutas = _item(
      'S\u00FCta\u015F Tam Ya\u011Fl\u0131 Beyaz Peynir 1 Kg',
      brand: 'S\u00FCta\u015F',
      sourceMenuCategory: 'peynir',
      price: 220,
    );
    final yorsan = _item(
      'Y\u00F6rsan Tam Ya\u011Fl\u0131 Beyaz Peynir 1 Kg',
      brand: 'Y\u00F6rsan',
      sourceMenuCategory: 'peynir',
      price: 210,
    );

    final grouped = groupCatalogItemsByProductFamily([sutas, yorsan]);

    expect(grouped, hasLength(1));
    expect(
      catalogProductFamilyTitle(grouped.single),
      'Tam Ya\u011Fl\u0131 Beyaz Peynir 1 Kg',
    );
    expect(grouped.single.price, 210);
  });
}

ActuellerCatalogItem _item(
  String title, {
  String? brand,
  String sourceMenuCategory = 'su',
  double price = 1,
}) {
  return ActuellerCatalogItem(
    id: '$title::$price',
    marketName: 'Test Market',
    productTitle: title,
    price: price,
    confidence: 1,
    rawBlock: title,
    sourceLabel: 'test',
    brand: brand,
    sourceMenuCategory: sourceMenuCategory,
  );
}
