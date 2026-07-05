import 'package:flutter/material.dart';

class  SpherexLogo extends StatelessWidget {
  const SpherexLogo ({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
    width: 100, height: 110,
    decoration: const BoxDecoration( shape: BoxShape.circle,
    gradient: LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFFA855F7)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,),),
      child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center,children: List.generate(3,(index)=> _buildDot()),),),

    );
  }
  // Add this logic below your build() method
  Widget _buildDot() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2.5),
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}
