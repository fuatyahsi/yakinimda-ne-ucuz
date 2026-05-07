import 'package:flutter/material.dart';

import '../models/smart_actueller.dart';
import '../utils/app_theme.dart';

/// Her ürün kategorisi için emoji + arka plan rengi tanımı.
/// [ActuellerCatalogItem.category] alanına göre eşleme yapılır.
const _categoryVisuals = <String, _CatVisual>{
  'sut':      _CatVisual(icon: '🥛', bg: Color(0xFFDBEAFE)),
  'peynir':   _CatVisual(icon: '🧀', bg: Color(0xFFFFFBEB)),
  'yumurta':  _CatVisual(icon: '🥚', bg: Color(0xFFFEFCE8)),
  'et':       _CatVisual(icon: '🍗', bg: Color(0xFFFFF7ED)),
  'kirmizi_et': _CatVisual(icon: '🥩', bg: Color(0xFFFFF1F2)),
  'sebze':    _CatVisual(icon: '🥦', bg: Color(0xFFDCFCE7)),
  'domates':  _CatVisual(icon: '🍅', bg: Color(0xFFFEE2E2)),
  'meyve':    _CatVisual(icon: '🍎', bg: Color(0xFFDCFCE7)),
  'ekmek':    _CatVisual(icon: '🍞', bg: Color(0xFFFEF3C7)),
  'simit':    _CatVisual(icon: '🥯', bg: Color(0xFFFFEDD5)),
  'icecek':   _CatVisual(icon: '🥤', bg: Color(0xFFEFF6FF)),
  'su':       _CatVisual(icon: '💧', bg: Color(0xFFEFF6FF)),
  'ayran':    _CatVisual(icon: '🫗', bg: Color(0xFFF0FDF4)),
  'kola':     _CatVisual(icon: '🥫', bg: Color(0xFFFEE2E2)),
  'temizlik': _CatVisual(icon: '🧴', bg: Color(0xFFF3E8FF)),
  'camasir':  _CatVisual(icon: '🫧', bg: Color(0xFFCFFAFE)),
  'kozmetik': _CatVisual(icon: '✨', bg: Color(0xFFFDF4FF)),
};

const _fallbackVisual = _CatVisual(icon: '🛒', bg: Color(0xFFFFF5F2));

class _CatVisual {
  final String icon;
  final Color bg;
  const _CatVisual({required this.icon, required this.bg});
}

/// Ürün adından kategori visual'ını bulan yardımcı.
/// Gerçek uygulamada [ProductCategory] enum'undan türetilebilir.
_CatVisual _visualFor(ActuellerCatalogItem item) {
  final title = item.productTitle.toLowerCase();
  if (title.contains('süt') || title.contains('sut')) return _categoryVisuals['sut']!;
  if (title.contains('ayran')) return _categoryVisuals['ayran']!;
  if (title.contains('peynir')) return _categoryVisuals['peynir']!;
  if (title.contains('kaşar') || title.contains('kasar')) return _categoryVisuals['peynir']!;
  if (title.contains('yumurta')) return _categoryVisuals['yumurta']!;
  if (title.contains('piliç') || title.contains('tavuk')) return _categoryVisuals['et']!;
  if (title.contains('kıyma') || title.contains('biftek') || title.contains('dana')) return _categoryVisuals['kirmizi_et']!;
  if (title.contains('domates')) return _categoryVisuals['domates']!;
  if (title.contains('elma') || title.contains('muz') || title.contains('portakal')) return _categoryVisuals['meyve']!;
  if (title.contains('sebze') || title.contains('salatalık') || title.contains('biber')) return _categoryVisuals['sebze']!;
  if (title.contains('ekmek')) return _categoryVisuals['ekmek']!;
  if (title.contains('simit')) return _categoryVisuals['simit']!;
  if (title.contains('su') && !title.contains('ayran')) return _categoryVisuals['su']!;
  if (title.contains('cola') || title.contains('gazoz') || title.contains('fanta')) return _categoryVisuals['kola']!;
  if (title.contains('deterjan') || title.contains('sabun')) return _categoryVisuals['temizlik']!;
  if (title.contains('çamaşır') || title.contains('camasir')) return _categoryVisuals['camasir']!;
  return _fallbackVisual;
}

/// Katalog ürün kartı — grid içinde kullanılır.
/// [onTap] → karşılaştırma sheet'ini açar.
class ProductGridCard extends StatelessWidget {
  final ActuellerCatalogItem item;
  final double? minPrice;
  final String? cheapestMarket;
  final int marketCount;
  final bool isInList;
  final VoidCallback onTap;

  const ProductGridCard({
    super.key,
    required this.item,
    required this.minPrice,
    required this.cheapestMarket,
    required this.marketCount,
    required this.isInList,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = _visualFor(item);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: AppTheme.cardSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isInList
                ? AppTheme.primary.withValues(alpha: 0.6)
                : AppTheme.primary.withValues(alpha: 0.09),
            width: isInList ? 1.8 : 1.5,
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst sağ: listede mi?
              Stack(
                children: [
                  // İkon kutusu
                  Container(
                    width: double.infinity,
                    height: 80,
                    decoration: BoxDecoration(
                      color: visual.bg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(visual.icon, style: const TextStyle(fontSize: 38)),
                  ),
                  if (isInList)
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 13),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Ürün adı
              Text(
                item.productTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),

              // Gramaj
              if (item.weight != null && item.weight!.isNotEmpty)
                Text(
                  item.weight!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.inkSoft,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              const SizedBox(height: 8),

              // Fiyat
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    minPrice != null
                        ? minPrice!.toStringAsFixed(2)
                        : item.price.toStringAsFixed(2),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'TL',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.inkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              // Market bilgisi
              Text(
                '${cheapestMarket ?? item.marketName} · $marketCount market',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.inkSoft,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kategori filtre chip'i
class CategoryFilterChip extends StatelessWidget {
  final String label;
  final String icon;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryFilterChip({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.32),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected ? Colors.white : AppTheme.inkSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
