import 'package:flutter/material.dart';
import '../widgets/stars_background.dart';
import '../widgets/spherex_logo.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _fadeController.forward();

    // Navigate to Login Screen after 3.5 seconds
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0b1020),
      body: Stack(
        children: [
          // 1. Background
          Container(
            color: const Color(0xFF0b1020),
          ),
          
          // 2. Stars
          const StarsBackground(),

          // 3. Pulsing Planet
          Positioned(
            bottom: -150,
            right: -100,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C4DFF).withOpacity(0.1 + (_pulseController.value * 0.1)),
                        blurRadius: 50,
                        spreadRadius: 10,
                      ),
                    ],
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF7C4DFF).withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF0b1020),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 4. Content with Entry Animation
          FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),
                    const SpherexLogo(),
                    const SizedBox(height: 40),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                        children: [
                          TextSpan(text: "SphereX ", style: TextStyle(color: Colors.white)),
                          TextSpan(text: "Chat", style: TextStyle(color: Color(0xFF7C4DFF))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Connect. Share. Communicate.\nWithout Limits.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const Spacer(flex: 4),
                    // Loading Indicator
                    const LoadingIndicator(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoadingIndicator extends StatefulWidget {
  const LoadingIndicator({super.key});

  @override
  State<LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCapsule(0),
        const SizedBox(width: 8),
        _buildCapsule(0.5),
      ],
    );
  }

  Widget _buildCapsule(double offset) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = (1.0 - (_controller.value + offset) % 1.0).clamp(0.2, 1.0);
        return Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFF7C4DFF).withOpacity(opacity),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              if (opacity > 0.8)
                BoxShadow(
                  color: const Color(0xFF7C4DFF).withOpacity(0.5),
                  blurRadius: 8,
                ),
            ],
          ),
        );
      },
    );
  }
}
