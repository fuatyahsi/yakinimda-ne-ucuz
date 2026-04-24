import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_theme.dart';
import '../widgets/supabase_smoke_card.dart';
import 'smart_actueller_screen.dart';

const _brandLogoAsset = 'assets/images/market_logo.png';
const _brandTitle = 'Yakınımda Ne Ucuz';

class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  static const _onboardingSeenKey = 'market_onboarding_seen_v1';

  bool _isBooting = true;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_onboardingSeenKey) ?? false;
    if (!mounted) return;
    setState(() {
      _isBooting = false;
      _showOnboarding = !seen;
    });
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, true);
    if (!mounted) return;
    setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isBooting) {
      return const _MarketSplashScreen();
    }

    if (_showOnboarding) {
      return _MarketOnboardingFlow(onDone: _finishOnboarding);
    }

    return Scaffold(
      body: const SmartActuellerScreen(autoSyncOnOpen: true),
      // Sadece debug build'de gorulen backend smoke test FAB'i.
      // Prod build'de (flutter build apk --release) gorunmez.
      floatingActionButton: kDebugMode
          ? FloatingActionButton.small(
              heroTag: 'supabase-smoke',
              onPressed: () => _showSmokeSheet(context),
              tooltip: 'Supabase saglik',
              child: const Icon(Icons.cloud),
            )
          : null,
    );
  }

  void _showSmokeSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: SupabaseSmokeCard(),
      ),
    );
  }
}

class _MarketSplashScreen extends StatelessWidget {
  const _MarketSplashScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0B6A71),
              Color(0xFF146C79),
              Color(0xFF144D72),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(36),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 28,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        _brandLogoAsset,
                        width: 220,
                        height: 220,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    _brandTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Yakındaki marketlerde aynı ürünü hızlıca karşılaştır.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.8,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketOnboardingFlow extends StatefulWidget {
  final Future<void> Function() onDone;

  const _MarketOnboardingFlow({required this.onDone});

  @override
  State<_MarketOnboardingFlow> createState() => _MarketOnboardingFlowState();
}

class _MarketOnboardingFlowState extends State<_MarketOnboardingFlow> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;

  final List<_OnboardingPageData> _pages = const [
    _OnboardingPageData(
      badge: 'Yakın market modu',
      title: 'Aynı ürünü market market karşılaştır',
      body:
          'Konumunu seç, gezeceğin marketleri aç ve fiyatları tek listede topla.',
      icon: Icons.shopping_bag_rounded,
      gradient: [
        Color(0xFF0B6A71),
        Color(0xFF146C79),
        Color(0xFF144D72),
      ],
      useLogoHero: true,
    ),
    _OnboardingPageData(
      badge: 'Akıllı liste',
      title: 'Seçtiğin ürünü kendi kararınla listeye ekle',
      body:
          'En ucuzu seçmek zorunda değilsin. Hangi market ürününü istersen onu al.',
      icon: Icons.checklist_rounded,
      gradient: [
        Color(0xFF13294B),
        Color(0xFF1D3D6F),
        Color(0xFF2B4E8B),
      ],
    ),
    _OnboardingPageData(
      badge: 'Kısa rota',
      title: 'Az marketle alışveriş planını sadeleştir',
      body:
          'Seçtiklerini tek listede, markete göre ya da kısa rota görünümünde kullan.',
      icon: Icons.route_rounded,
      gradient: [
        Color(0xFFFF6584),
        Color(0xFFFF8E63),
        Color(0xFFFFD36E),
      ],
    ),
  ];

  Future<void> _handlePrimaryAction() async {
    if (_pageIndex == _pages.length - 1) {
      await widget.onDone();
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _pageIndex == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppTheme.shellBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            children: [
              Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: widget.onDone,
                    child: const Text('Geç'),
                  ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) {
                    setState(() => _pageIndex = index);
                  },
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return _OnboardingPageCard(page: page);
                  },
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  final active = index == _pageIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? AppTheme.primary : AppTheme.inkSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _handlePrimaryAction,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                  child: Text(isLastPage ? 'Başla' : 'Devam Et'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageCard extends StatelessWidget {
  final _OnboardingPageData page;

  const _OnboardingPageCard({required this.page});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: page.gradient,
        ),
        borderRadius: BorderRadius.circular(34),
        boxShadow: AppTheme.softShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                page.badge,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.center,
              child: page.useLogoHero
                  ? Container(
                      width: 188,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.asset(
                          _brandLogoAsset,
                          height: 188,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  : Container(
                      width: 168,
                      height: 168,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Icon(
                        page.icon,
                        size: 88,
                        color: Colors.white,
                      ),
                    ),
            ),
            const Spacer(),
            Text(
              page.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              page.body,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.94),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final String badge;
  final String title;
  final String body;
  final IconData icon;
  final List<Color> gradient;
  final bool useLogoHero;

  const _OnboardingPageData({
    required this.badge,
    required this.title,
    required this.body,
    required this.icon,
    required this.gradient,
    this.useLogoHero = false,
  });
}
