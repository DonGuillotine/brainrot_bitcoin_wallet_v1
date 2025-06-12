import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/chaos_theme.dart';
import '../../providers/theme_provider.dart';
import '../../services/service_locator.dart';
import 'dart:math' as math;

/// Chaotic animated button with meme effects
class ChaosButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final double? width;
  final double height;
  final bool isPrimary;
  final IconData? icon;
  final bool enableChaos;

  const ChaosButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.width,
    this.height = 56,
    this.isPrimary = true,
    this.icon,
    this.enableChaos = true,
  });

  @override
  State<ChaosButton> createState() => _ChaosButtonState();
}

class _ChaosButtonState extends State<ChaosButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;
  double _rotation = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();

    // Haptic feedback
    services.hapticService.light();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handleTap() {
    final themeProvider = context.read<ThemeProvider>();

    // Play sound
    services.soundService.tap();

    // Trigger haptic
    if (themeProvider.chaosLevel >= 5) {
      services.hapticService.chaos();
    } else {
      services.hapticService.medium();
    }

    // Add random rotation for high chaos
    if (widget.enableChaos && themeProvider.chaosLevel >= 7) {
      setState(() {
        _rotation = (math.Random().nextDouble() - 0.5) * 0.1;
      });

      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() => _rotation = 0);
        }
      });
    }

    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final chaosLevel = themeProvider.chaosLevel;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = 1.0 - (_controller.value * 0.05);

          return Transform(
            transform: Matrix4.identity()
              ..scale(scale)
              ..rotateZ(_rotation),
            alignment: Alignment.center,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: widget.isPrimary
                  ? ChaosTheme.getChaosDecoration(
                chaosLevel: chaosLevel,
                baseColor: AppTheme.deepPurple,
                glitch: _isPressed && chaosLevel >= 6,
              )
                  : BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.limeGreen,
                  width: 2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Glitch effect for high chaos
                  if (_isPressed && chaosLevel >= 8)
                    ..._buildGlitchLayers(),

                  // Main content
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          color: widget.isPrimary
                              ? Colors.white
                              : AppTheme.limeGreen,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.text,
                        style: ChaosTheme.getChaosTextStyle(
                          fontSize: 18,
                          chaosLevel: _isPressed ? chaosLevel + 2 : chaosLevel,
                          fontWeight: FontWeight.bold,
                          color: widget.isPrimary
                              ? Colors.white
                              : AppTheme.limeGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    )
        .animate(
      onPlay: (controller) {
        if (widget.enableChaos && chaosLevel >= 5) {
          controller.repeat(reverse: true);
        }
      },
    )
        .shimmer(
      duration: const Duration(seconds: 2),
      color: widget.isPrimary
          ? Colors.white.withAlpha((0.2 * 255).round())
          : AppTheme.limeGreen.withAlpha((0.3 * 255).round()),
    );
  }

  List<Widget> _buildGlitchLayers() {
    return List.generate(3, (index) {
      final offset = Offset(
        (math.Random().nextDouble() - 0.5) * 10,
        (math.Random().nextDouble() - 0.5) * 10,
      );

      return Transform.translate(
        offset: offset,
        child: Opacity(
          opacity: 0.3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  color: ChaosTheme.glitchColors[index],
                  size: 24,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                widget.text,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ChaosTheme.glitchColors[index],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
