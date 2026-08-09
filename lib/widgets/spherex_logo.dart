import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class SpherexLogo extends StatefulWidget {
  const SpherexLogo({super.key});

  @override
  State<SpherexLogo> createState() => _SpherexLogoState();
}

class _SpherexLogoState extends State<SpherexLogo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Orbital Ring (Back part)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: _controller.value * 2 * math.pi,
                child: CustomPaint(
                  size: const Size(150, 150),
                  painter: _RingPainter(isFront: false),
                ),
              );
            },
          ),
          
          // 2. Glassmorphism Chat Sphere
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.2),
                      Colors.white.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) => _buildAnimatedDot(index)),
                  ),
                ),
              ),
            ),
          ),
          
          // 3. Inner Glow
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF7C4DFF).withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // 4. Orbital Ring (Front part)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: _controller.value * 2 * math.pi,
                child: CustomPaint(
                  size: const Size(150, 150),
                  painter: _RingPainter(isFront: true),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedDot(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Create a wave effect for the dots
        final double delay = index * 0.2;
        final double value = (math.sin((_controller.value * 2 * math.pi * 2) - delay) + 1) / 2;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.4 + (value * 0.6)),
            shape: BoxShape.circle,
            boxShadow: [
              if (value > 0.8)
                BoxShadow(
                  color: Colors.white.withValues(alpha: value * 0.5),
                  blurRadius: 4,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final bool isFront;
  _RingPainter({required this.isFront});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: size.width,
      height: size.height * 0.35,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Create a cosmic gradient for the ring
    final gradient = SweepGradient(
      colors: [
        const Color(0xFF7C4DFF).withValues(alpha: 0.0),
        const Color(0xFF7C4DFF),
        Colors.white,
        const Color(0xFF7C4DFF),
        const Color(0xFF7C4DFF).withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
    );

    paint.shader = gradient.createShader(rect);

    if (isFront) {
      // Front half with a bit of glow
      canvas.drawArc(rect, 0, math.pi, false, paint);
      
      // Add a small "satellite" dot on the ring
      final satellitePaint = Paint()..color = Colors.white;
      final x = center.dx + (size.width / 2) * math.cos(0);
      final y = center.dy + (size.height * 0.35 / 2) * math.sin(0);
      canvas.drawCircle(Offset(x, y), 3, satellitePaint);
      canvas.drawCircle(Offset(x, y), 6, satellitePaint..color = Colors.white.withValues(alpha: 0.3));
    } else {
      // Back half is slightly dimmer
      paint.color = paint.color.withValues(alpha: 0.5);
      canvas.drawArc(rect, math.pi, math.pi, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
