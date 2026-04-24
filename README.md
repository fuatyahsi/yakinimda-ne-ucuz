# FridgeChef - Buzdolabı Şef 🧑‍🍳

Buzdolabındaki malzemelere göre yemek tarifi öneren mobil uygulama.
Recipe suggestion app based on your fridge ingredients.

## Özellikler / Features

- **Malzeme Seçimi**: Buzdolabındaki ve stoğundaki malzemeleri seç
- **Akıllı Tarif Eşleştirme**: Malzemelerine göre yapabileceğin tarifleri bul
- **Eksik Malzeme Tespiti**: Hangi malzemenin eksik olduğunu gör
- **Adım Adım Hazırlanış**: Detaylı pişirme adımlarını takip et
- **Çoklu Dil**: Türkçe ve İngilizce dil desteği
- **Karanlık Mod**: Göz dostu karanlık tema
- **Favoriler**: Beğendiğin tarifleri kaydet

## Kurulum / Setup

### Gereksinimler
- Flutter SDK >= 3.2.0
- Dart SDK >= 3.2.0
- Android Studio / Xcode

### Çalıştırma

```bash
# Bağımlılıkları yükle
flutter pub get

# Uygulamayı çalıştır
flutter run

# Android APK oluştur
flutter build apk --release

# iOS build
flutter build ios --release
```

## Proje Yapısı

```
lib/
├── main.dart                    # Uygulama giriş noktası
├── l10n/
│   └── app_localizations.dart   # Çoklu dil desteği (TR/EN)
├── models/
│   ├── ingredient.dart          # Malzeme veri modeli
│   └── recipe.dart              # Tarif veri modeli
├── providers/
│   └── app_provider.dart        # State management (Provider)
├── screens/
│   ├── home_screen.dart         # Ana sayfa
│   ├── ingredient_selection_screen.dart  # Malzeme seçim ekranı
│   ├── recipe_list_screen.dart  # Tarif listesi ekranı
│   ├── recipe_detail_screen.dart # Tarif detay ekranı
│   └── settings_screen.dart     # Ayarlar ekranı
├── services/
│   └── recipe_service.dart      # Tarif eşleştirme servisi
└── utils/
    └── app_theme.dart           # Tema ayarları

assets/
├── data/
│   ├── ingredients.json         # Malzeme veritabanı (50+ malzeme)
│   └── recipes.json             # Tarif veritabanı (11 Türk yemeği)
└── images/
```

## Mağaza Yayını / Store Publishing

### Google Play Store
1. `flutter build appbundle --release` ile AAB oluştur
2. Google Play Console'da yeni uygulama oluştur
3. AAB dosyasını yükle
4. Store listing bilgilerini doldur

### Apple App Store
1. `flutter build ios --release` ile iOS build oluştur
2. Xcode'da Archive yap
3. App Store Connect'e yükle
4. App Store listing bilgilerini doldur

## Lisans
MIT License
