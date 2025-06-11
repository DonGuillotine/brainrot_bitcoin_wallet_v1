import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import '../../theme/chaos_theme.dart';

/// Glitch effect widget for maximum chaos
class GlitchEffect extends StatefulWidget {
  final Widget child;
  final bool isActive;
  final double intensity;
  final Duration interval;

  const GlitchEffect({
    super.key,
    required this.child,
    this.isActive = true,
    this.intensity = 1.0,
    this.interval = const Duration(seconds: 3),
  });

  @override
  State<GlitchEffect> createState() => _GlitchEffectState();
}

class _GlitchEffectState extends State<GlitchEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _glitchTimer;
  bool _isGlitching = false;
  double _offsetX = 0;
  double _offsetY = 0;
  int _glitchLayer = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    if (widget.isActive) {
      _startGlitchTimer();
    }
  }

  @override
  void didUpdateWidget(GlitchEffect oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _startGlitchTimer();
      } else {
        _stopGlitchTimer();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _glitchTimer?.cancel();
    super.dispose();
  }

  void _startGlitchTimer() {
    _glitchTimer?.cancel();
    _glitchTimer = Timer.periodic(widget.interval, (_) {
      _triggerGlitch();
    });
  }

  void _stopGlitchTimer() {
    _glitchTimer?.cancel();
    setState(() {
      _isGlitching = false;
      _offsetX = 0;
      _offsetY = 0;
    });
  }

  void _triggerGlitch() {
    if (!mounted) return;

    final random = math.Random();

    setState(() {
      _isGlitching = true;
      _offsetX = (random.nextDouble() - 0.5) * 10 * widget.intensity;
      _offsetY = (random.nextDouble() - 0.5) * 5 * widget.intensity;
      _glitchLayer = random.nextInt(3);
    });

    _controller.forward(from: 0);

    // Stop glitch after short duration
    Future.delayed(Duration(milliseconds: 50 + random.nextInt(150)), () {
      if (mounted) {
        setState(() {
          _isGlitching = false;
          _offsetX = 0;
          _offsetY = 0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive || !_isGlitching) {
      return widget.child;
    }

    return Stack(
      children: [
        // Original widget
        widget.child,

        // Glitch layers
        ..._buildGlitchLayers(),
      ],
    );
  }

  List<Widget> _buildGlitchLayers() {
    return List.generate(3, (index) {
      if (index != _glitchLayer) return const SizedBox.shrink();

      final random = math.Random();
      final clipHeight = random.nextDouble() * 0.3 + 0.1;
      final clipY = random.nextDouble() * (1 - clipHeight);

      return Positioned.fill(
        child: Transform.translate(
          offset: Offset(_offsetX, _offsetY),
          child: ClipRect(
            clipper: GlitchClipper(
              clipY: clipY,
              clipHeight: clipHeight,
            ),
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                ChaosTheme.glitchColors[index]..withAlpha((0.8 * 255).round()),
                BlendMode.screen,
              ),
              child: widget.child,
            ),
          ),
        ),
      );
    });
  }
}

/// Custom clipper for glitch effect
class GlitchClipper extends CustomClipper<Rect> {
  final double clipY;
  final double clipHeight;

  GlitchClipper({
    required this.clipY,
    required this.clipHeight,
  });

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(
      0,
      size.height * clipY,
      size.width,
      size.height * clipHeight,
    );
  }

  @override
  bool shouldReclip(covariant GlitchClipper oldClipper) {
    return oldClipper.clipY != clipY || oldClipper.clipHeight != clipHeight;
  }
}
