# Google Play Checklist

## Build
- `flutter pub get`
- `dart run flutter_launcher_icons`
- `flutter analyze`
- `flutter test test/widget_test.dart test/smart_kitchen_test.dart test/recipe_catalog_test.dart test/recipe_amount_test.dart`
- `flutter build appbundle --release`

## Firebase ve Giris
- `Email/Password` provider acik
- `Google` provider acik
- Android SHA-1 ve SHA-256 Firebase'e ekli
- Guncel `android/app/google-services.json` projede
- Release keystore SHA-1 ve SHA-256 degerleri de Firebase'e ekli
- `play_store/google_signin_setup.md` adimlari tamamlandi

## Play Console
- Uygulama kategorisi: `Food & Drink`
- Icerik derecelendirme formu doldurulacak
- Veri guvenligi formu doldurulacak
- Gizlilik politikasi linki hazir olacak
- Store aciklamalari ve ekran goruntuleri yuklenecek
- Feature graphic yuklenecek

## Son Kontrol
- Google giris calisiyor
- E-posta ile giris/kayit calisiyor
- Akilli Mutfak Asistani akisi calisiyor
- Bildirim izni ve hatirlatmalar kontrol edildi
- Reklam kimligi test yerine production degeriyle degistirildi
