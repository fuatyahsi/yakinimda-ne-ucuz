import 'package:flutter/material.dart';

class CommunityChallenge {
  final String id;
  final String emoji;
  final String tag;
  final String titleTr;
  final String titleEn;
  final String subtitleTr;
  final String subtitleEn;
  final String descriptionTr;
  final String descriptionEn;
  final int accentColorValue;

  const CommunityChallenge({
    required this.id,
    required this.emoji,
    required this.tag,
    required this.titleTr,
    required this.titleEn,
    required this.subtitleTr,
    required this.subtitleEn,
    required this.descriptionTr,
    required this.descriptionEn,
    required this.accentColorValue,
  });

  String title(bool isTr) => isTr ? titleTr : titleEn;
  String subtitle(bool isTr) => isTr ? subtitleTr : subtitleEn;
  String description(bool isTr) => isTr ? descriptionTr : descriptionEn;
  Color get accentColor => Color(accentColorValue);
}

class CommunityChallenges {
  static const List<CommunityChallenge> all = [
    CommunityChallenge(
      id: 'three_ingredients',
      emoji: '🥊',
      tag: 'challenge_three_ingredients',
      titleTr: '3 Malzemeli Düello',
      titleEn: '3-Ingredient Duel',
      subtitleTr: 'Az malzeme, net fikir',
      subtitleEn: 'Less ingredients, sharper ideas',
      descriptionTr:
          'Sadece 3 ana malzemeyle yaratıcı bir tarif paylaş. Basit ama akılda kalan tarifler öne çıksın.',
      descriptionEn:
          'Share a creative recipe using only 3 main ingredients. Simple but memorable wins.',
      accentColorValue: 0xFFFF7A59,
    ),
    CommunityChallenge(
      id: 'zero_spend_dinner',
      emoji: '💸',
      tag: 'challenge_zero_spend_dinner',
      titleTr: '0 TL Akşam Yemeği',
      titleEn: 'Zero-Spend Dinner',
      subtitleTr: 'Evdekilerle üç akşam çıkar',
      subtitleEn: 'Create three dinners with what you have',
      descriptionTr:
          'Bu hafta hiç alışveriş yapmadan, yalnızca evdeki malzemelerle üç akşam yemeği çıkar.',
      descriptionEn:
          'Create three dinners this week without shopping, using only what you already have at home.',
      accentColorValue: 0xFF2DAA72,
    ),
    CommunityChallenge(
      id: 'midnight_snack',
      emoji: '🌙',
      tag: 'challenge_midnight_snack',
      titleTr: 'Gece Atıştırması',
      titleEn: 'Midnight Snack',
      subtitleTr: '15 dakikada mutlu son',
      subtitleEn: 'Comfort food in 15 minutes',
      descriptionTr:
          '15 dakika içinde bitecek, düşük eforlu ama güçlü lezzetli tarifler paylaş.',
      descriptionEn:
          'Share low-effort, high-comfort recipes that are ready within 15 minutes.',
      accentColorValue: 0xFF5B6CFF,
    ),
    CommunityChallenge(
      id: 'fridge_rescue',
      emoji: '♻️',
      tag: 'challenge_fridge_rescue',
      titleTr: 'Buzdolabı Kurtarma',
      titleEn: 'Fridge Rescue',
      subtitleTr: 'İsrafı azalt, puanı kap',
      subtitleEn: 'Reduce waste, earn bragging rights',
      descriptionTr:
          'Kalan malzemeleri değerlendirip israfı azaltan tarifler paylaş. Bonus puan: yeniden kullanım.',
      descriptionEn:
          'Share recipes that rescue leftovers and reduce waste. Bonus points for clever reuse.',
      accentColorValue: 0xFF2DAA72,
    ),
    CommunityChallenge(
      id: 'breakfast_blitz',
      emoji: '🍳',
      tag: 'challenge_breakfast_blitz',
      titleTr: 'Kahvaltı Hızı',
      titleEn: 'Breakfast Blitz',
      subtitleTr: 'Sabahın yıldız tabağı',
      subtitleEn: 'Build the MVP breakfast plate',
      descriptionTr:
          'Günün en iyi başlangıcı için hızlı, enerjik ve paylaşmalık kahvaltı tarifleri yükle.',
      descriptionEn:
          'Upload fast, energetic breakfast recipes worth sharing for the best start of the day.',
      accentColorValue: 0xFFFFB648,
    ),
  ];

  static CommunityChallenge active([DateTime? now]) {
    final current = now ?? DateTime.now();
    final anchor = DateTime(2026, 1, 5);
    final weekIndex = current.difference(anchor).inDays ~/ 7;
    final normalizedIndex = weekIndex % all.length;
    return all[
        normalizedIndex < 0 ? normalizedIndex + all.length : normalizedIndex];
  }
}
