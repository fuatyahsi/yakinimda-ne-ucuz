import 'package:flutter/material.dart';

import '../screens/supabase_markets_screen.dart';
import '../services/supabase_service.dart';

/// Gelistirme sirasinda backend baglantisini dogrulayan dar kart.
///
/// Supabase'e bagli degilse "offline" gosterir. Bagli ise 3 sayac:
///   markets, products, active campaigns.
///
/// Production'da bu widget ya kaldirilir ya da "Destekledigimiz marketler"
/// butonuna donusturulur.
class SupabaseSmokeCard extends StatefulWidget {
  const SupabaseSmokeCard({super.key});

  @override
  State<SupabaseSmokeCard> createState() => _SupabaseSmokeCardState();
}

class _SupabaseSmokeCardState extends State<SupabaseSmokeCard> {
  int? _markets;
  int? _products;
  int? _campaigns;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!SupabaseService.instance.isReady) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = SupabaseService.instance;
      final results = await Future.wait([
        svc.fetchMarkets(),
        svc.countProducts(),
        svc.countActiveCampaigns(),
      ]);
      if (!mounted) return;
      setState(() {
        _markets = (results[0] as List).length;
        _products = results[1] as int;
        _campaigns = results[2] as int;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = SupabaseService.instance.isReady;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ready ? Icons.cloud_done : Icons.cloud_off,
                  color: ready ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Backend baglantisi',
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                if (ready)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loading ? null : _fetch,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!ready)
              const Text('Supabase yapilandirilmadi. --dart-define ile URL '
                  've ANON_KEY ver.')
            else if (_loading)
              const LinearProgressIndicator()
            else if (_error != null)
              Text('Hata: $_error',
                  style: TextStyle(color: theme.colorScheme.error))
            else
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _Stat(
                    label: 'Market',
                    value: _markets,
                    onTap: () => _openMarkets(context),
                  ),
                  _Stat(label: 'Urun', value: _products),
                  _Stat(label: 'Aktif kampanya', value: _campaigns),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _openMarkets(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SupabaseMarketsScreen(),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.onTap});

  final String label;
  final int? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tappable = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: tappable
              ? Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.4),
                  width: 1,
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(label, style: theme.textTheme.labelSmall),
                if (tappable) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    size: 12,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ],
            ),
            Text(
              value?.toString() ?? '-',
              style: theme.textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}
