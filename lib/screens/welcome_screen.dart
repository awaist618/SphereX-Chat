import 'package:flutter/material.dart';
import '../widgets/stars_background.dart';
import '../widgets/spherex_logo.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen ({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Background
          Container(
            color: const Color(0xFF0b1020),
          ),
          
          // 2. Stars
          const StarsBackground(),

          // 3. Logo
          const Center(
            child: SpherexLogo(),
          ),
        ],
      ),
    );
  }
}
