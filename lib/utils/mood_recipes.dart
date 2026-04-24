/// Ruh hâline göre yemek öneri sistemi.
/// Tarif kategorileri ve zorluk/süre bilgilerine göre eşleştirme yapar.
class MoodRecipeEngine {
  static const List<MoodOption> moods = [
    MoodOption(
      id: 'tired',
      emoji: '😴',
      nameTr: 'Yorgunum',
      nameEn: "I'm Tired",
      descTr: 'Minimum efor, maksimum lezzet',
      descEn: 'Minimum effort, maximum flavor',
      color: 0xFF7986CB,
      filter: MoodFilter(maxTime: 25, difficulties: ['easy'], categories: []),
    ),
    MoodOption(
      id: 'adventurous',
      emoji: '🧭',
      nameTr: 'Maceracıyım',
      nameEn: "I'm Adventurous",
      descTr: 'Yeni tatlar keşfet',
      descEn: 'Discover new flavors',
      color: 0xFFFF7043,
      filter: MoodFilter(
        maxTime: 0,
        difficulties: ['medium', 'hard'],
        categories: ['appetizer', 'main'],
      ),
    ),
    MoodOption(
      id: 'comfort',
      emoji: '🛋️',
      nameTr: 'Rahatlamak İstiyorum',
      nameEn: 'Need Comfort',
      descTr: 'Sıcacık, sarıp sarmalayan tarifler',
      descEn: 'Warm, cozy recipes',
      color: 0xFFFFB74D,
      filter: MoodFilter(
        maxTime: 0,
        difficulties: [],
        categories: ['soup', 'main', 'dessert'],
      ),
    ),
    MoodOption(
      id: 'healthy',
      emoji: '🥦',
      nameTr: 'Sağlıklı Olayım',
      nameEn: 'Feeling Healthy',
      descTr: 'Hafif ve besleyici seçenekler',
      descEn: 'Light and nutritious options',
      color: 0xFF66BB6A,
      filter: MoodFilter(
        maxTime: 0,
        difficulties: ['easy', 'medium'],
        categories: ['salad', 'soup', 'side'],
      ),
    ),
    MoodOption(
      id: 'romantic',
      emoji: '💕',
      nameTr: 'Romantik Akşam',
      nameEn: 'Romantic Evening',
      descTr: 'Özel biri için özel bir menü',
      descEn: 'A special menu for someone special',
      color: 0xFFEC407A,
      filter: MoodFilter(
        maxTime: 0,
        difficulties: ['medium', 'hard'],
        categories: ['main', 'dessert', 'appetizer'],
        requiredTags: ['romantik', 'romantic', 'ozel-aksam'],
      ),
    ),
    MoodOption(
      id: 'quick',
      emoji: '⚡',
      nameTr: 'Acelem Var',
      nameEn: "I'm in a Rush",
      descTr: '15 dakikada hazır tarifler',
      descEn: 'Ready in 15 minutes',
      color: 0xFFFFA726,
      filter: MoodFilter(maxTime: 15, difficulties: ['easy'], categories: []),
    ),
    MoodOption(
      id: 'nostalgic',
      emoji: '👵',
      nameTr: 'Anneannemin Mutfağı',
      nameEn: "Grandma's Kitchen",
      descTr: 'Geleneksel ev yemekleri',
      descEn: 'Traditional home cooking',
      color: 0xFF8D6E63,
      filter: MoodFilter(
        maxTime: 0,
        difficulties: [],
        categories: ['soup', 'main', 'side', 'breakfast'],
      ),
    ),
    MoodOption(
      id: 'party',
      emoji: '🎉',
      nameTr: 'Misafir Geliyor',
      nameEn: 'Hosting Guests',
      descTr: 'Etkileyici ve bol porsiyonlu',
      descEn: 'Impressive and generous portions',
      color: 0xFFAB47BC,
      filter: MoodFilter(
        maxTime: 0,
        difficulties: ['medium', 'hard'],
        categories: ['main', 'appetizer', 'dessert'],
      ),
    ),
  ];

  static MoodOption? getMoodById(String id) {
    try {
      return moods.firstWhere((mood) => mood.id == id);
    } catch (_) {
      return null;
    }
  }
}

class MoodOption {
  final String id;
  final String emoji;
  final String nameTr;
  final String nameEn;
  final String descTr;
  final String descEn;
  final int color;
  final MoodFilter filter;

  const MoodOption({
    required this.id,
    required this.emoji,
    required this.nameTr,
    required this.nameEn,
    required this.descTr,
    required this.descEn,
    required this.color,
    required this.filter,
  });

  String getName(String locale) => locale == 'tr' ? nameTr : nameEn;
  String getDesc(String locale) => locale == 'tr' ? descTr : descEn;
}

class MoodFilter {
  final int maxTime;
  final List<String> difficulties;
  final List<String> categories;
  final List<String> requiredTags;
  final List<String> blockedTags;

  const MoodFilter({
    required this.maxTime,
    required this.difficulties,
    required this.categories,
    this.requiredTags = const [],
    this.blockedTags = const [],
  });
}
