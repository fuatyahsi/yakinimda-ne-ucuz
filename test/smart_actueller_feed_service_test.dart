import 'package:flutter_test/flutter_test.dart';
import 'package:yakinimda_en_ucuz/services/smart_actueller_feed_service.dart';

void main() {
  group('SmartActuellerFeedService', () {
    test('parses brochure feed into catalog items and brochure reports', () {
      const payload = '''
      {
        "sourceLabel": "Akakce Daily Brochures",
        "updatedAt": "2026-03-19T05:00:00Z",
        "brochureCount": 1,
        "brochures": [
          {
            "id": "55944",
            "detailUrl": "https://www.akakce.com/brosurler/bim-18-mart-2026-aktuel-katalogu-indirim-brosuru-55944",
            "title": "Bim 18 Mart 2026 AktÃ¼el KataloÄŸu",
            "marketName": "BIM",
            "imageUrls": [
              "https://cdn.akakce.com/_bro/u/3200/55944/55944_000001.jpg"
            ]
          }
        ],
        "items": [
          {
            "id": "55944-01-lav-kilitli-saklama-kabi",
            "brochureId": "55944",
            "marketName": "BIM",
            "productName": "Lav Kilitli Saklama KabÄ±",
            "discountPrice": 79.0,
            "confidence": 0.96,
            "ocrText": "LAV KILITLI SAKLAMA KABI 79 TL"
          }
        ]
      }
      ''';

      final service = SmartActuellerFeedService();
      final snapshot = service.parseFeed(payload);

      expect(snapshot.sourceLabel, 'Akakce Daily Brochures');
      expect(snapshot.brochureCount, 1);
      expect(snapshot.catalogItems, hasLength(1));
      expect(snapshot.catalogItems.first.marketName, 'BIM');
      expect(snapshot.catalogItems.first.productTitle, 'Lav Kilitli Saklama KabÄ±');
      expect(snapshot.brochureReports, hasLength(1));
      expect(snapshot.brochureReports.first.itemCount, 1);
      expect(snapshot.brochureReports.first.marketName, 'BIM');
    });
  });
}

