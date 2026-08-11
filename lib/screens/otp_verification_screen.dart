import 'dart:async'; // Add timer support
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/stars_background.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String username;
  final String password;
  const OtpVerificationScreen({
    super.key, 
    required this.email, 
    required this.username,
    required this.password,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  int _resendTimer = 30; // Start with 30 seconds cooldown
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendTimer = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer == 0) {
        setState(() {
          _timer?.cancel();
        });
      } else {
        setState(() {
          _resendTimer--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0b1020),
      body: Stack(
        children: [
          const StarsBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Verify Email",
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "We sent a 6-digit code to\n${widget.email}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 50),
                  
                  // OTP Input Boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) => _buildOtpBox(index)),
                  ),
                  
                  const SizedBox(height: 50),
                  
                  ElevatedButton(
                    onPressed: _isLoading ? null : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2979FF),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Verify & Continue", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: (_resendTimer == 0 && !_isLoading) ? _resendOtp : null,
                    child: Text(
                      _resendTimer == 0 ? "Resend Code" : "Resend in ${_resendTimer}s",
                      style: TextStyle(
                        color: _resendTimer == 0 ? const Color(0xFF2979FF) : Colors.white38,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resendOtp() async {
    setState(() => _isLoading = true);
    final result = await ApiService.requestOtp(
      widget.email, 
      widget.username,
      widget.password,
    );
    setState(() => _isLoading = false);

    if (result['success']) {
      _startResendTimer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification code resent successfully!')),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? 'Failed to resend code')),
      );
    }
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 45,
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        onChanged: (value) => _onChanged(value, index),
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          LengthLimitingTextInputFormatter(1),
          FilteringTextInputFormatter.digitsOnly,
        ],
        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 2),
          ),
        ),
      ),
    );
  }

  void _verifyCode() async {
    String code = _controllers.map((c) => c.text).join();
    if (code.length == 6) {
      setState(() => _isLoading = true);
      
      final success = await ApiService.verifyOtp(widget.email, code);
      
      setState(() => _isLoading = false);

      if (success) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid or Expired Code.')),
        );
      }
    }
  }
}
