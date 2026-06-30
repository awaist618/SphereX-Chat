
import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';

class SphereXChatApp extends StatelessWidget {
  const SphereXChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: const WelcomeScreen(),
    );
  }
}
