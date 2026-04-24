import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  String get languageCode => 'tr';

  String get appName => 'BuzdolabıŞef';
  String get appTagline => 'Elindekiyle pişir!';

  String get home => 'Ana Sayfa';
  String get myIngredients => 'Malzemelerim';
  String get recipes => 'Tarifler';
  String get favorites => 'Favoriler';
  String get settings => 'Ayarlar';

  String get welcomeTitle => 'Buzdolabında ne var?';
  String get welcomeSubtitle =>
      'Malzemelerini seç, yapabileceğin tarifleri keşfet!';
  String get startCooking => 'Yemek yapmaya başla';
  String get selectIngredients => 'Malzemeleri seç';

  String get searchIngredients => 'Malzeme ara...';
  String get selectedIngredients => 'Seçilen';
  String get clearAll => 'Tümünü temizle';
  String get findRecipes => 'Tarif bul';
  String ingredientsSelected(int count) => '$count malzeme seçildi';

  String get recipesFound => 'Bulunan tarifler';
  String get noRecipesFound => 'Malzemelerinle uyuşan tarif bulunamadı';
  String get canMake => 'Yapabilirsin!';
  String get almostCanMake => 'Neredeyse!';
  String get matchPercentage => 'uyum';
  String missingIngredients(int count) => '$count eksik malzeme';
  String get showAll => 'Tümünü göster';
  String get showOnlyFullMatch => 'Sadece tam uyanlar';

  String get ingredients => 'Malzemeler';
  String get preparation => 'Hazırlanış';
  String get prepTime => 'Hazırlık';
  String get cookTime => 'Pişirme';
  String get totalTime => 'Toplam';
  String get servings => 'Porsiyon';
  String get difficulty => 'Zorluk';
  String get minutes => 'dk';
  String get step => 'Adım';
  String get youHaveThis => 'Bu sende var';
  String get youNeedThis => 'Eksik';
  String get optional => 'İsteğe bağlı';

  String get language => 'Dil';
  String get turkish => 'Türkçe';
  String get english => 'İngilizce';
  String get darkMode => 'Karanlık mod';
  String get about => 'Hakkında';
  String get version => 'Sürüm';

  String get all => 'Tümü';
  String get breakfast => 'Kahvaltı';
  String get soup => 'Çorbalar';
  String get mainDish => 'Ana yemek';
  String get sideDish => 'Yan lezzetler';
  String get dessert => 'Tatlı';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'tr';

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(const Locale('tr'));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
