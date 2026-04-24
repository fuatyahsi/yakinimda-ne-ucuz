# Play Store Assets

Bu klasor Android yayin hazirligi icin temel varliklari ve metinleri tutar.

Hazirlanan dosyalar:
- `metadata/tr-TR/` : Turkce Play Store metinleri
- `metadata/en-US/` : Ingilizce Play Store metinleri
- `checklist.md` : Yayina cikmadan once kontrol listesi
- `google_signin_setup.md` : Debug ve release Google giris ayarlari

Gorsel varliklar:
- Uygulama ikon kaynagi: `assets/images/app_icon_source.jpeg`
- Feature graphic: `assets/images/play_feature_graphic.png`

Ikonlari uretmek icin:
```powershell
flutter pub get
dart run flutter_launcher_icons
```

Android icin release bundle:
```powershell
flutter build appbundle --release
```

Yerel release signing:
- `android/key.properties.example` dosyasini `android/key.properties` olarak hazirla
- `android/upload-keystore.jks` dosyasini olustur
- Release SHA-1 / SHA-256 degerlerini Firebase Android uygulamasina ekle

GitHub Actions release build:
- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_STORE_PASSWORD`
