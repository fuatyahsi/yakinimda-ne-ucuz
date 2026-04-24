import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yakinimda_en_ucuz/services/smart_actueller_source_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('SmartActuellerSourceService', () {
    test('discovers brochure detail urls from root and market pages', () async {
      final client = MockClient((request) async {
        final url = request.url.toString();
        if (url == SmartActuellerSourceService.akakceListingUrl) {
          return _htmlResponse('''
            <html>
              <body>
                <a href="/brosurler/bim">BIM</a>
                <a href="/brosurler/a101">A101</a>
              </body>
            </html>
          ''');
        }

        if (url == 'https://www.akakce.com/brosurler/bim') {
          return _htmlResponse('''
            <html>
              <body>
                <a href="/brosurler/bim-21-mart-2026-aktuel-111">Yeni BIM</a>
                <a href="/brosurler/bim-18-mart-2026-aktuel-110">Eski BIM</a>
              </body>
            </html>
          ''');
        }

        if (url == 'https://www.akakce.com/brosurler/a101') {
          return _htmlResponse('''
            <html>
              <body>
                <a href="/brosurler/a101-21-mart-2026-aktuel-222">Yeni A101</a>
              </body>
            </html>
          ''');
        }

        return http.Response('Not found', 404);
      });

      final service = SmartActuellerSourceService(client: client);
      final urls = await service.discoverBrochureUrls(
        selectedMarketIds: const ['bim', 'a101'],
        maxPerMarket: 2,
      );

      expect(
        urls,
        equals([
          'https://www.akakce.com/brosurler/bim-21-mart-2026-aktuel-111',
          'https://www.akakce.com/brosurler/bim-18-mart-2026-aktuel-110',
          'https://www.akakce.com/brosurler/a101-21-mart-2026-aktuel-222',
        ]),
      );
    });

    test('extracts structured products and skips OCR fallback images',
        () async {
      final client = MockClient((request) async {
        final url = request.url.toString();
        if (url == 'https://www.akakce.com/brosurler/bim-21-mart-2026') {
          return _htmlResponse('''
            <html>
              <head>
                <title>BIM 21 Mart 2026 Aktuel Katalogu</title>
              </head>
              <body>
                <astro-island props="{&quot;response&quot;:[0,{&quot;metadata&quot;:[0,{&quot;vn&quot;:[0,&quot;BIM&quot;],&quot;bt&quot;:[0,&quot;BIM 21 Mart 2026 Aktuel Katalogu&quot;],&quot;su&quot;:[0,&quot;/brosurler/bim-21-mart-2026&quot;]}],&quot;pages&quot;:[1,[[0,{&quot;hriURL&quot;:[0,&quot;https://cdn.akakce.com/_bro/u/111/222/222_000001.jpg&quot;],&quot;clips&quot;:[1,[[0,{&quot;n&quot;:[0,&quot;Kasar Peyniri&quot;],&quot;p&quot;:[0,&quot;129,90&quot;]}],[0,{&quot;n&quot;:[0,&quot;Yumurta 10'lu&quot;],&quot;p&quot;:[0,&quot;62,50&quot;]}]]]}],[0,{&quot;hriURL&quot;:[0,&quot;https://cdn.akakce.com/_bro/u/111/222/222_000002.jpg&quot;],&quot;clips&quot;:[1,[]]}]]],&quot;vdBrochures&quot;:[1,[[0,{&quot;bu&quot;:[0,&quot;/brosurler/bim-18-mart-2026-aktuel-110&quot;]}]]]}]}"></astro-island>
              </body>
            </html>
          ''');
        }

        return http.Response.bytes(<int>[1, 2, 3, 4], 200);
      });

      final service = SmartActuellerSourceService(client: client);
      final result = await service.prepareSource(
        'https://www.akakce.com/brosurler/bim-21-mart-2026',
      );

      expect(result.detectedStore, 'BİM');
      expect(result.usedStructuredCatalogData, isTrue);
      expect(result.shouldUseImageFallback, isFalse);
      expect(result.extractedText, contains('Kasar Peyniri 129,90 TL'));
      expect(result.extractedText, contains("Yumurta 10'lu 62,50 TL"));
      expect(result.imageUrls, isEmpty);
      expect(result.localImagePaths, isEmpty);
    });

    test('accepts direct brochure image urls', () async {
      final client = MockClient((request) async {
        return http.Response.bytes(<int>[9, 8, 7, 6], 200);
      });

      final service = SmartActuellerSourceService(client: client);
      final result = await service.prepareSource(
        'https://cdn.akakce.com/_bro/u/3267/55790/55790_461152.jpg',
      );

      expect(result.imageUrls, hasLength(1));
      expect(result.localImagePaths, hasLength(1));
      expect(result.shouldUseImageFallback, isTrue);
      expect(
        result.localImagePaths.first.toLowerCase().endsWith('.jpg'),
        isTrue,
      );

      final file = File(result.localImagePaths.first);
      if (file.existsSync()) {
        file.deleteSync();
      }
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


