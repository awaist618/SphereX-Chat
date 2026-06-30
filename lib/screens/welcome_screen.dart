import 'package:flutter/material.dart';
import 'package:spherex_chat/widgets/stars_background.dart';
import '../widgets/stars_background.dart';

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
        
        Container(
          color: const Color(0xFF0b1020),
        ),
        const StarsBackground(),
      ],
    )
    );
  }
}
