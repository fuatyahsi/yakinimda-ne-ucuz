/// Supabase baglanti bilgileri.
///
/// Anahtar degerler build-time'da --dart-define ile verilir:
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://lbqaggmhkoptkdziotcp.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=sb_publishable_XXXX...
/// ```
///
/// Prod build'de (App Store / Play Store) ayni parametreleri CI secret
/// olarak gec. ASLA anon key'i repo'ya commit etme.
///
/// `SUPABASE_ANON_KEY` = `sb_publishable_*` formatindaki anahtar. Sadece
/// public tablolari + RLS'in izin verdigi kullanici-bazli satirlari
/// okur/yazar. Service role key KESINLIKLE client'a konmamali.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Build-time'da dart-define gecilmediyse kullanicinin anlayacagi
  /// hata mesaji. initialize() cagrilmadan once cagrilir.
  static void assertConfigured() {
    if (url.isEmpty || anonKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL ve SUPABASE_ANON_KEY --dart-define ile verilmedi. '
        'Ornek: flutter run --dart-define=SUPABASE_URL=https://... '
        '--dart-define=SUPABASE_ANON_KEY=sb_publishable_...',
      );
    }
  }

  /// Config eksikse true doner — UI "offline mode" gosterir.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
