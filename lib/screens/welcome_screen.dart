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
          Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SpherexLogo(), const SizedBox(height: 40),
              RichText(text: const TextSpan(style: TextStyle(fontSize: 36 ,fontWeight: FontWeight.bold),
              children: [
                TextSpan(
                  text: "SphereX", style: TextStyle(color: Colors.white)
                ),TextSpan(
                  text: "Chat",style: TextStyle(color: Color(0xFF7C4DFF))
                )
              ]
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
