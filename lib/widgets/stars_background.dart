import 'package:flutter/material.dart';
import 'dart:math' as math;

class StarsBackground extends StatelessWidget {
  const StarsBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: StarsPainter(),
    );
  }
}

class StarsPainter extends CustomPainter{
  @override
  void paint(Canvas canvas,Size size){
    final random = math.Random(42);
    final paint = Paint()..color = Colors.white;
    for(int i = 0; i<100 ;i++){
      double x = random.nextDouble() * size.width;
      double y = random.nextDouble()* size.height;

      canvas.drawCircle(Offset(x, y), random.nextDouble(), paint..color = Colors.white.withOpacity(random.nextDouble()),);
    }

  }

  bool shouldRepaint(CustomPainter oldDelegate) => false;

}