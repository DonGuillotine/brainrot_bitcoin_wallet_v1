import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/effects/glitch_effect.dart';
import 'dart:math' as math;

/// QR code display with chaos effects
class QRCodeDisplay extends StatefulWidget {
  final String data;
  final double size;
  final bool isLightning;
  final int chaosLevel;

  const QRCodeDisplay({
    super.key,
    required this.data,
    required this.size,
    required this.isLightning,
    required this.chaosLevel,
  });

  @override
  State<QRCodeDisplay> createState() => _QRCodeDisplayState();
}

class _QRCodeDisplayState extends State<QRCodeDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    if (widget.chaosLevel >= 5) {
      _animationController.repeat();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget qrCode = Container(
      width: widget.size,
      height: widget.size,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (widget.isLightning ? AppTheme.limeGreen : AppTheme.deepPurple)
                ..withAlpha((0.3 * 255).round()),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: QrImageView(
        data: widget.data,
        version: QrVersions.auto,
        size: widget.size - 32,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: EdgeInsets.zero,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        embeddedImage: widget.chaosLevel >= 8
            ? const AssetImage('assets/images/bitcoin_logo.png')
            : null,
        embeddedImageStyle: const QrEmbeddedImageStyle(
          size: Size(40, 40),
        ),
      ),
    );

    // Apply chaos effects
    if (widget.chaosLevel >= 9) {
      qrCode = GlitchEffect(
        isActive: true,
        intensity: 0.5,
        child: qrCode,
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Background animation
        if (widget.chaosLevel >= 6)
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _animationController.value * 2 * math.pi,
                child: Container(
                  width: widget.size + 40,
                  height: widget.size + 40,
                  decoration: BoxDecoration(
                    gradient: SweepGradient(
                      colors: [
                        widget.isLightning ? AppTheme.limeGreen : AppTheme.deepPurple,
                        Colors.transparent,
                        widget.isLightning ? AppTheme.limeGreen : AppTheme.deepPurple,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              );
            },
          ),

        // QR Code
        qrCode
            .animate()
            .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: const Duration(milliseconds: 300),
        ),

        // Corner decorations for high chaos
        if (widget.chaosLevel >= 7) ...[
          Positioned(
            top: -10,
            left: -10,
            child: _buildCornerDecoration(),
          ),
          Positioned(
            top: -10,
            right: -10,
            child: Transform.rotate(
              angle: math.pi / 2,
              child: _buildCornerDecoration(),
            ),
          ),
          Positioned(
            bottom: -10,
            left: -10,
            child: Transform.rotate(
              angle: -math.pi / 2,
              child: _buildCornerDecoration(),
            ),
          ),
          Positioned(
            bottom: -10,
            right: -10,
            child: Transform.rotate(
              angle: math.pi,
              child: _buildCornerDecoration(),
            ),
          ),
        ],

        // Lightning bolt overlay
        if (widget.isLightning)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.limeGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bolt,
                color: Colors.white,
                size: 20,
              ),
            )
                .animate(
              onPlay: (controller) => controller.repeat(),
            )
                .scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1.2, 1.2),
              duration: const Duration(seconds: 2),
            ),
          ),
      ],
    );
  }

  Widget _buildCornerDecoration() {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: widget.isLightning ? AppTheme.limeGreen : AppTheme.deepPurple,
            width: 3,
          ),
          left: BorderSide(
            color: widget.isLightning ? AppTheme.limeGreen : AppTheme.deepPurple,
            width: 3,
          ),
        ),
      ),
    );
  }
}
