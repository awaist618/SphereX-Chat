
import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';

class SphereXChatApp extends StatelessWidget {
  const SphereXChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SphereX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF2979FF),
        scaffoldBackgroundColor: const Color(0xFF0F1B2D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2979FF),
          secondary: Color(0xFF5B9CFF),
          surface: Color(0xFF0A2540),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFF2979FF),
          selectionColor: Color(0xFF2979FF),
          selectionHandleColor: Color(0xFF2979FF),
        ),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}
