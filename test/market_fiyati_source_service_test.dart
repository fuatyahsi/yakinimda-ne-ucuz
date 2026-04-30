import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yakinimda_en_ucuz/models/ingredient.dart';
import 'package:yakinimda_en_ucuz/models/market_fiyati.dart';
import 'package:yakinimda_en_ucuz/services/market_fiyati_source_service.dart';
import 'package:yakinimda_en_ucuz/utils/market_registry.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('MarketFiyatiSourceService', () {
    test('parses searchByIdentity style product response', () {
      final service = MarketFiyatiSourceService();
      final response = MarketFiyatiSearchResponse.fromJson({
        'numberOfFound': 1,
        'searchResultType': 0,
        'content': [
          {
            'id': '0E28',
            'title': 'Ovon Camasir Makine Temizleyici 250 Ml',
            'brand': 'Ovon',
            'imageUrl':
                'https://cdn.marketfiyati.org.tr/tarimkrediimages/118165.png',
            'refinedVolumeOrWeight': '250 Ml',
            'main_category': 'Genel Temizlik Urunleri',
            'menu_category': 'Temizlik ve Kisisel Bakim Urunleri',
            'productDepotInfoList': [
              {
                'depotId': 'tarim_kredi-5199',
                'depotName': 'Ankara Ceyhun Atuf Market',
                'price': 40.5,
                'unitPrice': '162,00 TL/Lt',
                'unitPriceValue': 162.0,
                'marketAdi': 'tarim_kredi',
                'percentage': 0.0,
                'longitude': 32.81537,
                'latitude': 39.8838,
                'indexTime': '29.03.2026 12:08',
                'discount': false,
                'discountRatio': null,
                'promotionText': null,
              },
            ],
          },
        ],
        'facetMap': null,
      });

      expect(response.numberOfFound, 1);
      expect(response.content, hasLength(1));
      expect(response.content.first.offers, hasLength(1));
      expect(response.content.first.refinedMeasure, '250 Ml');

      final items = service.toCatalogItems(response);
      expect(items, hasLength(1));
      expect(normalizeMarketId(items.first.marketName), 'tarim-kredi');
      expect(
        items.first.productTitle,
        contains('Ovon Camasir Makine Temizleyici'),
      );
      expect(items.first.price, 40.5);
    });

    test('sends expected payload to identity endpoint', () async {
      late Map<String, dynamic> capturedBody;
      final client = MockClient((request) async {
        capturedBody = json.decode(request.body) as Map<String, dynamic>;
        return http.Response(
          json.encode({
            'numberOfFound': 0,
            'searchResultType': 0,
            'content': [],
            'facetMap': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = MarketFiyatiSourceService(client: client);
      const session = MarketFiyatiSession(
        locationLabel: 'AÅŸaÄŸÄ± Ã–veÃ§ler',
        depots: ['bim-C741', 'tarim_kredi-5199'],
        distance: 5,
        latitude: 39.88677969953312,
        longitude: 32.8167366992369,
      );

      await service.searchByIdentity(
        session: session,
        identity: '0E28',
        keywords: 'ovon camasir makine temizleyici 250 ml',
      );

      expect(capturedBody['identity'], '0E28');
      expect(capturedBody['identityType'], 'id');
      expect(
        capturedBody['keywords'],
        'ovon camasir makine temizleyici 250 ml',
      );
      expect(capturedBody['depots'], isA<List<dynamic>>());
      expect(capturedBody['distance'], 5);
    });

    test('parses location suggestion response', () async {
      final client = MockClient((request) async {
        return http.Response(
          json.encode([
            [
              'Asagi Ovecler Mh. Ovecler 1 Alt Gecidi Cankaya Ankara ',
              'Y',
              '',
              'Ovecler 1 Alt Gecidi',
              'Asagi Ovecler Mh.',
              'Cankaya',
              'Ankara',
              32.82538811194,
              39.885826135396,
              6,
              1231,
              14095,
              199798,
              0,
              0,
              '1071 Malazgirt Blv.; Mimar Cd.',
              0,
              '',
            ],
            [
              'Ovecler Dilhan Aile Sagligi Merkezi, Asagi Ovecler Mh. 1071 Malazgirt Blv. Cankaya Ankara ',
              'P',
              'Ovecler Dilhan Aile Sagligi Merkezi',
              '1071 Malazgirt Blv.',
              'Asagi Ovecler Mh.',
              'Cankaya',
              'Ankara',
              32.827652,
              39.884712,
              6,
              1231,
              14095,
              6073095,
              0,
              327615,
              '55. Sk.;1297/1. Sk.;Mimar Cd.',
              0,
              '',
            ],
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = MarketFiyatiSourceService(client: client);
      final suggestions = await service.searchLocationSuggestions(
        words: 'ovecler',
      );

      expect(suggestions, hasLength(2));
      expect(suggestions.first.district, 'Cankaya');
      expect(suggestions.first.city, 'Ankara');
      expect(suggestions.first.latitude, 39.885826135396);
      expect(
        suggestions.first.displayLabel,
        contains('Ovecler 1 Alt Gecidi'),
      );
      expect(
        suggestions.last.displayLabel,
        'Ovecler Dilhan Aile Sagligi Merkezi',
      );
    });

    test('sends expected payload to category endpoint', () async {
      late Map<String, dynamic> capturedBody;
      final client = MockClient((request) async {
        capturedBody = json.decode(request.body) as Map<String, dynamic>;
        return http.Response(
          json.encode({
            'numberOfFound': 0,
            'searchResultType': 1,
            'content': [],
            'facetMap': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = MarketFiyatiSourceService(client: client);
      const session = MarketFiyatiSession(
        locationLabel: 'AÅŸaÄŸÄ± Ã–veÃ§ler',
        depots: ['bim-C741', 'a101-8887', 'migros-8926'],
        distance: 5,
        latitude: 39.88677969953312,
        longitude: 32.8167366992369,
      );

      await service.searchByCategories(
        session: session,
        keywords: 'Temizlik ve Kisisel Bakim Urunleri',
      );

      expect(capturedBody['keywords'], 'Temizlik ve Kisisel Bakim Urunleri');
      expect(capturedBody['menuCategory'], isTrue);
      expect(capturedBody['identity'], isNull);
      expect(capturedBody['depots'], hasLength(3));
      expect(capturedBody['size'], 24);
    });

    test('sends expected payload to similar product endpoint', () async {
      late Map<String, dynamic> capturedBody;
      final client = MockClient((request) async {
        capturedBody = json.decode(request.body) as Map<String, dynamic>;
        return http.Response(
          json.encode({
            'numberOfFound': 0,
            'searchResultType': 1,
            'content': [],
            'facetMap': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = MarketFiyatiSourceService(client: client);
      const session = MarketFiyatiSession(
        locationLabel: 'AÅŸaÄŸÄ± Ã–veÃ§ler',
        depots: ['bim-C741', 'a101-8887', 'migros-8926'],
        distance: 5,
        latitude: 39.88677969953312,
        longitude: 32.8167366992369,
      );

      await service.searchSimilarProduct(
        session: session,
        id: '0E28',
        keywords: 'Ovon Camasir Makine Temizleyici 250 Ml',
      );

      expect(capturedBody['id'], '0E28');
      expect(
        capturedBody['keywords'],
        'Ovon Camasir Makine Temizleyici 250 Ml',
      );
      expect(capturedBody['identity'], isNull);
      expect(capturedBody['identityType'], isNull);
      expect(capturedBody['depots'], hasLength(3));
      expect(capturedBody['size'], 24);
    });

    test('maps response into remote quotes when ingredient matches', () {
      final service = MarketFiyatiSourceService();
      final response = MarketFiyatiSearchResponse.fromJson({
        'numberOfFound': 1,
        'searchResultType': 0,
        'content': [
          {
            'id': 'milk-01',
            'title': 'Tam Yagli Sut 1 L',
            'brand': 'Dost',
            'refinedQuantityUnit': '1 Adet',
            'refinedVolumeOrWeight': '1 L',
            'categories': ['Sut Urunleri', 'Kahvaltilik'],
            'productDepotInfoList': [
              {
                'depotId': 'bim-C741',
                'depotName': 'BIM Sube',
                'price': 33.75,
                'marketAdi': 'bim',
                'discount': false,
              },
            ],
          },
        ],
        'facetMap': null,
      });

      const ingredients = [
        Ingredient(
          id: 'milk',
          nameTr: 'Sut',
          nameEn: 'Milk',
          category: IngredientCategory.dairy,
        ),
      ];

      final quotes = service.toRemoteQuotes(
        response,
        ingredients: ingredients,
      );

      expect(quotes, hasLength(1));
      expect(normalizeMarketId(quotes.first.market), 'bim');
      expect(quotes.first.unitPrice, 33.75);
    });

    test('parses similar product response with multiple market offers', () {
      final service = MarketFiyatiSourceService();
      final response = MarketFiyatiSearchResponse.fromJson({
        'numberOfFound': 1,
        'searchResultType': 1,
        'content': [
          {
            'id': '0XIH',
            'title': 'Domestos Camasir Suyu Ultra 3240 ML',
            'brand': 'Domestos',
            'refinedVolumeOrWeight': '3.24 lt',
            'categories': [
              'Ultra Camasir Suyu',
              'Genel Temizlik Urunleri',
            ],
            'main_category': 'Genel Temizlik ÃœrÃ¼nleri',
            'menu_category': 'Temizlik ve KiÅŸisel BakÄ±m ÃœrÃ¼nleri',
            'productDepotInfoList': [
              {
                'depotId': 'bim-C741',
                'depotName': 'BIM Sube',
                'price': 169.0,
                'unitPrice': '52,16 TL/Lt',
                'unitPriceValue': 52.160496,
                'marketAdi': 'bim',
                'discount': false,
              },
              {
                'depotId': 'a101-8887',
                'depotName': 'A101 Sube',
                'price': 169.0,
                'unitPrice': '52,16 TL/Lt',
                'unitPriceValue': 52.160496,
                'marketAdi': 'a101',
                'discount': false,
              },
              {
                'depotId': 'tarim_kredi-5199',
                'depotName': 'Tarim Kredi Sube',
                'price': 219.0,
                'unitPrice': '67,59 TL/Lt',
                'unitPriceValue': 67.59259,
                'marketAdi': 'tarim_kredi',
                'discount': false,
              },
            ],
          },
        ],
        'facetMap': null,
      });

      final items = service.toCatalogItems(response);
      expect(items, hasLength(3));
      expect(
        items.map((item) => normalizeMarketId(item.marketName)).toSet(),
        containsAll(<String>{'bim', 'a101', 'tarim-kredi'}),
      );
      expect(items.first.sourceProductId, '0XIH');
      expect(items.first.sourceDepotId, isNotNull);
      expect(
          items.map((item) => item.price), containsAll(<double>[169.0, 219.0]));
    });

    test('parses nearest depot response', () async {
      final client = MockClient((request) async {
        return http.Response(
          json.encode([
            {
              'id': 'bim-C726',
              'sellerName': 'Asagi Ovecler Cankaya',
              'location': {
                'lon': 32.82376,
                'lat': 39.883568,
              },
              'marketName': 'bim',
              'distance': 286.84937423551213,
            },
            {
              'id': 'tarim_kredi-5402',
              'sellerName': 'Ankara Cankaya Ovecler',
              'location': {
                'lon': 32.82918,
                'lat': 39.8871,
              },
              'marketName': 'tarim_kredi',
              'distance': 352.9903724619072,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = MarketFiyatiSourceService(client: client);
      final depots = await service.fetchNearestDepots(
        latitude: 39.885826135396,
        longitude: 32.82538811194,
      );

      expect(depots, hasLength(2));
      expect(depots.first.id, 'bim-C726');
      expect(normalizeMarketId(depots.first.marketName), 'bim');
      expect(depots.first.distanceMeters, greaterThan(200));
    });

    test('builds session from nearest depots', () {
      final service = MarketFiyatiSourceService();
      const depots = [
        MarketFiyatiNearestDepot(
          id: 'bim-C726',
          sellerName: 'Asagi Ovecler Cankaya',
          marketName: 'bim',
          latitude: 39.883568,
          longitude: 32.82376,
          distanceMeters: 286.84,
        ),
        MarketFiyatiNearestDepot(
          id: 'tarim_kredi-5402',
          sellerName: 'Ankara Cankaya Ovecler',
          marketName: 'tarim_kredi',
          latitude: 39.8871,
          longitude: 32.82918,
          distanceMeters: 352.99,
        ),
      ];

      final session = service.buildSessionFromNearest(
        locationLabel: 'AÅŸaÄŸÄ± Ã–veÃ§ler',
        latitude: 39.885826135396,
        longitude: 32.82538811194,
        depots: depots,
      );

      expect(session.locationLabel, 'AÅŸaÄŸÄ± Ã–veÃ§ler');
      expect(session.depots, ['bim-C726', 'tarim_kredi-5402']);
      expect(session.distance, 5);
    });

    test('builds session from location suggestion', () {
      final service = MarketFiyatiSourceService();
      const suggestion = MarketFiyatiLocationSuggestion(
        fullLabel: 'AÅŸaÄŸÄ± Ã–veÃ§ler Mh. Ã–veÃ§ler 1 Alt GeÃ§idi Ã‡ankaya Ankara',
        resultType: 'Y',
        pointOfInterestName: '',
        roadName: 'Ã–veÃ§ler 1 Alt GeÃ§idi',
        neighborhood: 'AÅŸaÄŸÄ± Ã–veÃ§ler Mh.',
        district: 'Ã‡ankaya',
        city: 'Ankara',
        longitude: 32.82538811194,
        latitude: 39.885826135396,
        roadContext: '1071 Malazgirt Blv.; Mimar Cd.',
        doorNumber: null,
      );
      const depots = [
        MarketFiyatiNearestDepot(
          id: 'bim-C726',
          sellerName: 'AÅŸaÄŸÄ± Ã–veÃ§ler Ã‡ankaya',
          marketName: 'bim',
          latitude: 39.883568,
          longitude: 32.82376,
          distanceMeters: 286.84,
        ),
        MarketFiyatiNearestDepot(
          id: 'carrefour-5107',
          sellerName: 'Ankara Ã–veÃ§ler Mini',
          marketName: 'carrefour',
          latitude: 39.882896,
          longitude: 32.82831,
          distanceMeters: 409.8,
        ),
      ];

      final session = service.buildSessionFromSuggestion(
        suggestion: suggestion,
        depots: depots,
      );

      expect(
        session.locationLabel,
        'Ã–veÃ§ler 1 Alt GeÃ§idi, AÅŸaÄŸÄ± Ã–veÃ§ler Mh., Ã‡ankaya, Ankara',
      );
      expect(session.latitude, 39.885826135396);
      expect(session.longitude, 32.82538811194);
      expect(session.depots, ['bim-C726', 'carrefour-5107']);
    });
  });
}

