import 'package:flutter/material.dart';

import '../models/supabase_market.dart';
import '../services/supabase_service.dart';

/// Backend'deki marketlerin gercek canli listesi.
/// `SupabaseService.fetchMarkets()` ile `markets` tablosunu okur, tier'a
/// gore grupler ("Ulusal Zincirler", "Orta Olcekli" ...).
///
/// Bu ekran app'in "Hangi marketlerde indirimleri takip ediyoruz?" sorusunun
/// gercek cevabi. Kullanici profil/settings'ten tercih ettigi marketleri
/// buradan secer (ileride).
class SupabaseMarketsScreen extends StatefulWidget {
  const SupabaseMarketsScreen({super.key});

  @override
  State<SupabaseMarketsScreen> createState() => _SupabaseMarketsScreenState();
}

class _SupabaseMarketsScreenState extends State<SupabaseMarketsScreen> {
  late Future<List<SupabaseMarket>> _future;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.instance.fetchMarkets();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = SupabaseService.instance.fetchMarkets();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Desteklenen Marketler'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<SupabaseMarket>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorState(
                error: snapshot.error.toString(),
                onRetry: _refresh,
              );
            }
            final markets = snapshot.data ?? const [];
            if (markets.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Henuz market bulunamadi. Backend baglantini kontrol et.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return _MarketTierList(markets: markets);
          },
        ),
      ),
    );
  }
}

class _MarketTierList extends StatelessWidget {
  const _MarketTierList({required this.markets});

  final List<SupabaseMarket> markets;

  static const _tierLabels = <int, String>{
    1: 'Ulusal Zincirler',
    2: 'Orta Olcekli Zincirler',
    3: 'Bolgesel Zincirler',
    4: 'Online / Hizli Market',
  };

  @override
  Widget build(BuildContext context) {
    // tier -> list
    final grouped = <int, List<SupabaseMarket>>{};
    for (final m in markets) {
      final tier = m.tier ?? 3;
      grouped.putIfAbsent(tier, () => []).add(m);
    }
    final sortedTiers = grouped.keys.toList()..sort();

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: sortedTiers.length,
      itemBuilder: (context, index) {
        final tier = sortedTiers[index];
        final tierMarkets = grouped[tier]!;
        return _TierSection(
          title: _tierLabels[tier] ?? 'Tier $tier',
          markets: tierMarkets,
        );
      },
    );
  }
}

class _TierSection extends StatelessWidget {
  const _TierSection({required this.title, required this.markets});

  final String title;
  final List<SupabaseMarket> markets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${markets.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...markets.map((m) => _MarketTile(market: m)),
      ],
    );
  }
}

class _MarketTile extends StatelessWidget {
  const _MarketTile({required this.market});

  final SupabaseMarket market;

  @override
  Widget build(BuildContext context) {
    final initials = market.displayName
        .split(RegExp(r'\s+'))
        .take(2)
        .map((w) => w.isEmpty ? '' : w[0])
        .join()
        .toUpperCase();
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: market.logoUrl != null
            ? NetworkImage(market.logoUrl!)
            : null,
        child: market.logoUrl == null
            ? Text(
                initials,
                style: const TextStyle(fontWeight: FontWeight.w700),
              )
            : null,
      ),
      title: Text(market.displayName),
      subtitle: market.website != null
          ? Text(
              market.website!.replaceAll(RegExp(r'^https?://'), ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : Text('market_id: ${market.id}'),
      trailing: market.active
          ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
          : const Icon(Icons.pause_circle, color: Colors.grey, size: 20),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.orange),
              const SizedBox(height: 12),
              const Text(
                'Backend erisiminde hata',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
