import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../app/theme/app_colors.dart';
import '../../shared/layouts/app_scaffold.dart';

typedef BarcodeScannedCallback = Future<void> Function(String barcode);

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({
    super.key,
    this.continuous = false,
    this.title,
    this.onBarcodeScanned,
  });

  /// Mode berkelanjutan: tidak tutup setelah satu scan (untuk opname, dll.).
  final bool continuous;
  final String? title;
  final BarcodeScannedCallback? onBarcodeScanned;

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  late final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: widget.continuous
        ? DetectionSpeed.normal
        : DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _closed = false;
  bool _processing = false;
  final Map<String, DateTime> _lastAcceptedAt = {};
  final List<String> _recentScans = [];
  int _sessionScanCount = 0;

  static const _sameCodeCooldown = Duration(milliseconds: 450);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _acceptBarcode(String value) {
    final now = DateTime.now();
    final last = _lastAcceptedAt[value];
    if (last != null && now.difference(last) < _sameCodeCooldown) {
      return false;
    }
    _lastAcceptedAt[value] = now;
    return true;
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_closed || _processing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final accepted = <String>[];
    for (final raw in barcodes) {
      final value = raw.rawValue?.trim();
      if (value == null || value.isEmpty) continue;
      if (!_acceptBarcode(value)) continue;
      accepted.add(value);
    }
    if (accepted.isEmpty) return;

    if (!widget.continuous) {
      _closed = true;
      if (mounted) Navigator.of(context).pop(accepted.first);
      return;
    }

    setState(() => _processing = true);
    try {
      for (final value in accepted) {
        await widget.onBarcodeScanned?.call(value);
        if (!mounted) return;
        setState(() {
          _sessionScanCount++;
          _recentScans.insert(0, value);
          if (_recentScans.length > 8) _recentScans.removeLast();
        });
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _finish() {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ??
        (widget.continuous ? 'Scan Berkelanjutan' : 'Scan Barcode');

    return AppScaffold(
      title: title,
      actions: [
        if (widget.continuous)
          TextButton(
            onPressed: _finish,
            child: const Text(
              'Selesai',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        IconButton(
          tooltip: 'Flash',
          onPressed: () => _controller.toggleTorch(),
          icon: const Icon(Icons.flash_on),
        ),
        IconButton(
          tooltip: 'Flip camera',
          onPressed: () => _controller.switchCamera(),
          icon: const Icon(Icons.cameraswitch),
        ),
      ],
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
          ),
          if (_processing)
            const Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.continuous
                        ? 'Scan satu per satu. Barcode sama bisa discan ulang untuk menambah qty.'
                        : 'Arahkan kamera ke barcode obat',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  if (widget.continuous) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Sesi: $_sessionScanCount scan',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_recentScans.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Terakhir: ${_recentScans.first}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          Center(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: widget.continuous
          ? FloatingActionButton.extended(
              onPressed: _finish,
              icon: const Icon(Icons.check),
              label: const Text('Selesai'),
            )
          : null,
    );
  }
}
