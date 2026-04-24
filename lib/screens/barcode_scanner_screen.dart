import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/smart_actueller.dart';
import '../providers/app_provider.dart';
import '../services/market_fiyati_source_service.dart';
import '../utils/text_repair.dart';

/// A screen that lets the user scan a product barcode and shows price
/// comparison results across nearby markets.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  final MarketFiyatiSourceService _sourceService = MarketFiyatiSourceService();

  bool _isProcessing = false;
  String? _lastScannedBarcode;
  List<ActuellerCatalogItem>? _results;
  String? _errorMessage;

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first.rawValue;
    if (barcode == null || barcode.isEmpty) return;
    if (barcode == _lastScannedBarcode) return;

    setState(() {
      _isProcessing = true;
      _lastScannedBarcode = barcode;
      _results = null;
      _errorMessage = null;
    });

    try {
      final provider = context.read<AppProvider>();
      final session = provider.marketFiyatiSession;
      if (session == null) {
        setState(() {
          _errorMessage = '\u00D6nce konum se\u00E7melisin.';
          _isProcessing = false;
        });
        return;
      }

      // Search by barcode as product identity.
      final response = await _sourceService.searchByIdentity(
        session: session,
        identity: barcode,
        keywords: barcode,
        size: 20,
        identityType: 'barcode',
      );

      final items = _sourceService.toCatalogItems(response);

      if (items.isEmpty) {
        // Fallback: try as a regular keyword search.
        final fallbackResponse = await _sourceService.searchByCategories(
          session: session,
          keywords: barcode,
          size: 20,
        );
        final fallbackItems = _sourceService.toCatalogItems(fallbackResponse);
        setState(() {
          _results = fallbackItems;
          _errorMessage = fallbackItems.isEmpty
              ? 'Bu barkod i\u00E7in \u00FCr\u00FCn bulunamad\u0131:\n$barcode'
              : null;
          _isProcessing = false;
        });
        return;
      }

      setState(() {
        _results = items;
        _isProcessing = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage =
            'Arama s\u0131ras\u0131nda hata: ${error.toString().replaceFirst('Exception: ', '')}';
        _isProcessing = false;
      });
    }
  }

  void _resetScan() {
    setState(() {
      _lastScannedBarcode = null;
      _results = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasResults = _results != null && _results!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barkod Tara'),
        actions: [
          if (_lastScannedBarcode != null)
            IconButton(
              onPressed: _resetScan,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Tekrar Tara',
            ),
        ],
      ),
      body: Column(
        children: [
          // Camera preview (compact when results are shown)
          SizedBox(
            height: hasResults ? 160 : 300,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _cameraController,
                    onDetect: _onBarcodeDetected,
                  ),
                  Center(
                    child: Container(
                      width: 260,
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.7),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Status area
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Ürün aranıyor...'),
                ],
              ),
            ),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    repairTurkishText(_errorMessage!),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _resetScan,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Tekrar Tara'),
                  ),
                ],
              ),
            ),

          // Results list
          if (hasResults)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.compare_arrows_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_results!.length} sonu\u00E7 bulundu',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: _results!.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _results![index];
                        return _BarcodeResultTile(item: item);
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Initial instruction
          if (!_isProcessing &&
              _errorMessage == null &&
              !hasResults &&
              _lastScannedBarcode == null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 64,
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '\u00DCr\u00FCn\u00FCn barkodunu kameraya g\u00F6ster',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'En ucuz fiyat\u0131 h\u0131zl\u0131ca bul',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BarcodeResultTile extends StatelessWidget {
  final ActuellerCatalogItem item;

  const _BarcodeResultTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Market badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              item.marketName,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  repairTurkishText(item.productTitle),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.weight != null && item.weight!.isNotEmpty)
                  Text(
                    item.weight!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Price
          Text(
            '${item.price.toStringAsFixed(2)} TL',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
