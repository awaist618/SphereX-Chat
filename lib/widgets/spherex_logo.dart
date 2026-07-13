import 'dart:math' as math;
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
      duration: const Duration(seconds: 8),
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
      width: 140,
      height: 140,
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
                  size: const Size(130, 130),
                  painter: _RingPainter(isFront: false),
                ),
              );
            },
          ),
          
          // 2. Main Chat Bubble
          Container(
            width: 85,
            height: 85,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF7C4DFF), Color(0xFFA855F7)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF7C4DFF),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) => _buildDot()),
              ),
            ),
          ),
          
          // 3. Orbital Ring (Front part)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: _controller.value * 2 * math.pi,
                child: CustomPaint(
                  size: const Size(130, 130),
                  painter: _RingPainter(isFront: true),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDot() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2.5),
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final bool isFront;
  _RingPainter({required this.isFront});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: size.width,
      height: size.height * 0.4,
    );

    if (isFront) {
      canvas.drawArc(rect, 0, math.pi, false, paint);
    } else {
      canvas.drawArc(rect, math.pi, math.pi, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
