import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../theme/chaos_theme.dart';

/// Particle system for chaos effects
class ParticleSystem extends StatefulWidget {
  final ParticleType particleType;
  final int particleCount;
  final Color? color;
  final double? size;
  final bool isActive;

  const ParticleSystem({
    super.key,
    this.particleType = ParticleType.stars,
    this.particleCount = 50,
    this.color,
    this.size,
    this.isActive = true,
  });

  @override
  State<ParticleSystem> createState() => _ParticleSystemState();
}

class _ParticleSystemState extends State<ParticleSystem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();

    _initializeParticles();

    _controller.addListener(() {
      if (widget.isActive) {
        _updateParticles();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initializeParticles() {
    _particles.clear();

    for (int i = 0; i < widget.particleCount; i++) {
      _particles.add(Particle.random(
        type: widget.particleType,
        color: widget.color,
        size: widget.size,
      ));
    }
  }

  void _updateParticles() {
    if (!mounted) return;

    setState(() {
      for (final particle in _particles) {
        particle.update();

        // Reset particle if it goes off screen
        if (particle.position.dy > 1.2 ||
            particle.position.dx < -0.2 ||
            particle.position.dx > 1.2) {
          particle.reset();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: ParticlePainter(
              particles: _particles,
              particleType: widget.particleType,
            ),
            size: MediaQuery.of(context).size,
          );
        },
      ),
    );
  }
}

/// Particle types
enum ParticleType {
  stars,
  hearts,
  money,
  bitcoin,
  lightning,
  rockets,
  moons,
  chaos,
}

/// Individual particle
class Particle {
  Offset position;
  Offset velocity;
  double size;
  double rotation;
  double rotationSpeed;
  Color color;
  double opacity;
  String? emoji;

  Particle({
    required this.position,
    required this.velocity,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.opacity,
    this.emoji,
  });

  factory Particle.random({
    required ParticleType type,
    Color? color,
    double? size,
  }) {
    final random = math.Random();

    // Random starting position
    final position = Offset(
      random.nextDouble(),
      random.nextDouble() * 1.2 - 0.2,
    );

    // Random velocity
    final velocity = Offset(
      (random.nextDouble() - 0.5) * 0.002,
      random.nextDouble() * 0.003 + 0.001,
    );

    // Random properties
    final particleSize = size ?? (random.nextDouble() * 20 + 10);
    final rotation = random.nextDouble() * 2 * math.pi;
    final rotationSpeed = (random.nextDouble() - 0.5) * 0.05;
    final opacity = random.nextDouble() * 0.5 + 0.5;

    // Get emoji for type
    final emoji = _getEmojiForType(type);

    // Get color
    final particleColor = color ?? _getColorForType(type);

    return Particle(
      position: position,
      velocity: velocity,
      size: particleSize,
      rotation: rotation,
      rotationSpeed: rotationSpeed,
      color: particleColor,
      opacity: opacity,
      emoji: emoji,
    );
  }

  void update() {
    // Update position
    position = Offset(
      position.dx + velocity.dx,
      position.dy + velocity.dy,
    );

    // Update rotation
    rotation += rotationSpeed;

    // Update opacity (fade as it falls)
    opacity = (opacity - 0.005).clamp(0.0, 1.0);
  }

  void reset() {
    final random = math.Random();

    // Reset to top
    position = Offset(
      random.nextDouble(),
      -0.1,
    );

    // Reset opacity
    opacity = random.nextDouble() * 0.5 + 0.5;
  }

  static String? _getEmojiForType(ParticleType type) {
    switch (type) {
      case ParticleType.stars:
        return ['⭐', '✨', '💫'][math.Random().nextInt(3)];
      case ParticleType.hearts:
        return ['❤️', '💜', '💚'][math.Random().nextInt(3)];
      case ParticleType.money:
        return ['💵', '💸', '💰'][math.Random().nextInt(3)];
      case ParticleType.bitcoin:
        return ['₿', '🪙', '⚡'][math.Random().nextInt(3)];
      case ParticleType.lightning:
        return ['⚡', '🌩️', '⛈️'][math.Random().nextInt(3)];
      case ParticleType.rockets:
        return ['🚀', '🛸', '✈️'][math.Random().nextInt(3)];
      case ParticleType.moons:
        return ['🌙', '🌕', '🌛'][math.Random().nextInt(3)];
      case ParticleType.chaos:
        return ['🤯', '🎉', '💀', '🔥', '👾', '🎯'][math.Random().nextInt(6)];
    }
  }

  static Color _getColorForType(ParticleType type) {
    switch (type) {
      case ParticleType.stars:
        return Colors.yellow;
      case ParticleType.hearts:
        return Colors.pink;
      case ParticleType.money:
        return Colors.green;
      case ParticleType.bitcoin:
        return Colors.orange;
      case ParticleType.lightning:
        return Colors.yellow;
      case ParticleType.rockets:
        return Colors.blue;
      case ParticleType.moons:
        return Colors.purple;
      case ParticleType.chaos:
        return ChaosTheme.getRandomChaosColor();
    }
  }
}

/// Particle painter
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final ParticleType particleType;

  ParticlePainter({
    required this.particles,
    required this.particleType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final position = Offset(
        particle.position.dx * size.width,
        particle.position.dy * size.height,
      );

      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(particle.rotation);

      if (particle.emoji != null) {
        // Draw emoji
        final textPainter = TextPainter(
          text: TextSpan(
            text: particle.emoji,
            style: TextStyle(
              fontSize: particle.size,
              color: particle.color.withAlpha((particle.opacity * 255).round()),
            ),
          ),
          textDirection: TextDirection.ltr,
        );

        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            -textPainter.width / 2,
            -textPainter.height / 2,
          ),
        );
      } else {
        // Draw shape
        final paint = Paint()
          ..color = particle.color.withAlpha((particle.opacity * 255).round())
          ..style = PaintingStyle.fill;

        canvas.drawCircle(
          Offset.zero,
          particle.size / 2,
          paint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
