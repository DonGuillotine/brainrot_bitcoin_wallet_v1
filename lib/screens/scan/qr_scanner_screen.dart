import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated/meme_text.dart';
import '../../services/service_locator.dart';

/// QR code scanner screen
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController? _controller;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _handleDetection(String? code) {
    if (code == null) return;

    services.soundService.success();
    services.hapticService.success();

    // Navigate to send screen with scanned data
    context.go('/home/send', extra: code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Scanner
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _handleDetection(barcode.rawValue);
                  break;
                }
              }
            },
          ),

          // UI overlay
          SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.close),
                        color: Colors.white,
                        iconSize: 32,
                      ),

                      const Expanded(
                        child: Center(
                          child: MemeText(
                            'Scan QR Code',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      IconButton(
                        onPressed: () {
                          setState(() => _torchOn = !_torchOn);
                          _controller?.toggleTorch();
                        },
                        icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
                        color: _torchOn ? AppTheme.limeGreen : Colors.white,
                        iconSize: 32,
                      ),
                    ],
                  ),
                ),

                // Scan area
                Expanded(
                  child: Center(
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppTheme.limeGreen,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),

                // Instructions
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const MemeText(
                        'Align QR code within frame',
                        fontSize: 16,
                        color: Colors.white70,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code,
                            color: AppTheme.limeGreen,
                          ),
                          const SizedBox(width: 8),
                          const MemeText(
                            'Bitcoin or Lightning',
                            fontSize: 14,
                            color: AppTheme.limeGreen,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
