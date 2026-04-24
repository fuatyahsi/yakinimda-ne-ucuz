import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yakinimda_en_ucuz/features/cosmetics/services/cosmetic_source_service.dart';

void main() {
  group('CosmeticSourceService', () {
    test('parses Akakce category hierarchy pages', () async {
      final client = MockClient((request) async {
        return _htmlResponse('''
          <html>
            <head>
              <title>Kisisel Bakim | En Ucuzu Akakce</title>
              <script type="application/ld+json">
                {
                  "@context": "https://schema.org",
                  "@type": "BreadcrumbList",
                  "itemListElement": [
                    {"@type": "ListItem", "position": 1, "name": "Kozmetik, Kisisel Bakim"},
                    {"@type": "ListItem", "position": 2, "name": "Kisisel Bakim"}
                  ]
                }
              </script>
            </head>
            <body>
              <h1>Kisisel Bakim</h1>
              <ul>
                <li>
                  <a href="/agiz-dis-bakimi.html">Agiz, Dis Bakimi (17.642)</a>
                  <a href="/agiz-gargarasi.html">Agiz Gargarasi</a>
                </li>
                <li>
                  <a href="/tiras-makinasi.html">Tiras Makinesi (4.221)</a>
                </li>
              </ul>
            </body>
          </html>
        ''');
      });

      final service = CosmeticSourceService(client: client);
      final snapshot = await service.fetchCategorySnapshot(
        'https://www.akakce.com/kisisel-bakim.html',
      );

      expect(snapshot.title, 'Kisisel Bakim');
      expect(
        snapshot.breadcrumbs,
        equals(['Kozmetik, Kisisel Bakim', 'Kisisel Bakim']),
      );
      expect(snapshot.childCategories, hasLength(2));
      expect(snapshot.childCategories.first.title, 'Agiz, Dis Bakimi');
      expect(snapshot.childCategories.first.itemCount, 17642);
      expect(snapshot.productCards, isEmpty);
      expect(snapshot.isListingPage, isFalse);
    });

    test('parses Akakce listing pages with products and filters', () async {
      final client = MockClient((request) async {
        return _htmlResponse('''
          <html>
            <head>
              <title>Agiz Gargarasi | En Ucuzu Akakce</title>
              <script type="application/ld+json">
                {
                  "@context": "https://schema.org",
                  "@type": "BreadcrumbList",
                  "itemListElement": [
                    {"@type": "ListItem", "position": 1, "name": "Kozmetik, Kisisel Bakim"},
                    {"@type": "ListItem", "position": 2, "name": "Kisisel Bakim"},
                    {"@type": "ListItem", "position": 3, "name": "Agiz, Dis Bakimi"},
                    {"@type": "ListItem", "position": 4, "name": "Agiz Gargarasi"}
                  ]
                }
              </script>
            </head>
            <body>
              <h1>Agiz Gargarasi</h1>
              <div>Boyut 1 lt</div>
              <div>Boyut 500 ml</div>
              <div>Ozellikler Alkolsuz</div>
              <div>973 farkli Agiz Gargarasi icin fiyatlar listeleniyor.</div>
              <ul>
                <li>
                  <a href="/listerine-cool-mint-500-ml-gargara-fiyati,123456.html">
                    Listerine Cool Mint 500 ml Gargara
                  </a>
                  En Ucuz 186,12 TL +115 FIYAT 372,24 TL/Lt
                </li>
                <li>
                  <a href="/parodontax-extra-500-ml-gargara-fiyati,654321.html">
                    Parodontax Extra 500 ml Gargara
                  </a>
                  En Ucuz %19 280,99 TL +60 FIYAT 561,98 TL/Lt
                </li>
              </ul>
            </body>
          </html>
        ''');
      });

      final service = CosmeticSourceService(client: client);
      final snapshot = await service.fetchCategorySnapshot(
        'https://www.akakce.com/agiz-gargarasi.html',
      );

      expect(snapshot.title, 'Agiz Gargarasi');
      expect(snapshot.totalProductCount, 973);
      expect(snapshot.filterTags, containsAll(['Boyut 1 lt', 'Boyut 500 ml']));
      expect(snapshot.filterTags, contains('Ozellikler Alkolsuz'));
      expect(snapshot.productCards, hasLength(2));
      expect(snapshot.productCards.first.title,
          'Listerine Cool Mint 500 ml Gargara');
      expect(snapshot.productCards.first.price, 186.12);
      expect(snapshot.productCards.first.priceText, '186,12 TL');
      expect(snapshot.productCards.first.unitPriceText, '372,24 TL/Lt');
      expect(snapshot.productCards.first.offerCount, 115);
      expect(snapshot.productCards.first.url, contains('listerine-cool-mint'));
      expect(snapshot.productCards.last.badgeText, '%19');
      expect(snapshot.isListingPage, isTrue);
    });
  });
}

http.Response _htmlResponse(String body) {
  return http.Response.bytes(
    utf8.encode(body),
    200,
    headers: {'content-type': 'text/html; charset=utf-8'},
  );
}
