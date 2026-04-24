# Google Sign-In Setup

## Debug Build

Debug Google girisi icin Firebase Android uygulamasinda su SHA-1 bulunmali:

`50:F1:89:03:64:1E:20:79:F7:93:A7:EE:91:29:64:15:4F:D4:D8:2E`

Bu SHA yerel debug keystore ile eslesiyor. `android/app/google-services.json`
dosyasinda Android OAuth client kaydi da oldugu icin debug build tarafi hazir.

## Release Build

Release AAB veya APK icin ayri upload keystore kullanacaksan:

1. Keystore uret:
   `keytool -genkeypair -v -keystore android/upload-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000`
2. SHA degerlerini al:
   `keytool -list -v -alias upload -keystore android/upload-keystore.jks`
3. Firebase Console > Project settings > Android app `com.fridgechef.fridge_chef`
   altina release `SHA-1` ve `SHA-256` degerlerini ekle.
4. Yeni `google-services.json` dosyasini indirip `android/app/google-services.json`
   uzerine yaz.
5. `android/key.properties.example` dosyasini `android/key.properties` olarak
   kopyalayip gercek degerleri doldur.
6. Release build al:
   `flutter build appbundle --release`

## GitHub Actions Secrets

Release artifactlerini Actions'ta almak icin su secret'lari ekle:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_STORE_PASSWORD`
