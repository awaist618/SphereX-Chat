import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

enum CallType { voice, video }
enum CallStatus { calling, ringing, connected, ended }

class CallScreen extends StatefulWidget {
  final String otherUsername;
  final String? otherProfilePic;
  final CallType type;
  final bool isIncoming;
  final String? callId;

  const CallScreen({
    super.key,
    required this.otherUsername,
    this.otherProfilePic,
    required this.type,
    this.isIncoming = false,
    this.callId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  CallStatus _status = CallStatus.calling;
  int _duration = 0;
  Timer? _timer;
  bool _isMuted = false;
  bool _isSpeakerOn = false;

  @override
  void initState() {
    super.initState();
    _status = widget.isIncoming ? CallStatus.ringing : CallStatus.calling;
    if (!widget.isIncoming) {
      _startCall();
    }
    
    // Simulate connection for demo purposes if not rejected
    if (!widget.isIncoming) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _status == CallStatus.calling) {
          _connectCall();
        }
      });
    }
  }

  void _startCall() {
    // In a real app, this would send a signaling message via Supabase Realtime
    debugPrint("Starting ${widget.type.name} call to ${widget.otherUsername}");
  }

  void _connectCall() {
    setState(() => _status = CallStatus.connected);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _duration++);
    });
  }

  void _endCall() {
    _timer?.cancel();
    setState(() => _status = CallStatus.ended);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pop(context);
    });
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A2540),
      body: Stack(
        children: [
          // Video Background (Placeholder for real camera feed)
          if (widget.type == CallType.video && _status == CallStatus.connected)
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black,
              child: Opacity(
                opacity: 0.4,
                child: Image.network(
                  widget.otherProfilePic ?? "https://placeholder.com/user",
                  fit: BoxFit.cover,
                ),
              ),
            ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                _buildHeader(),
                const Spacer(),
                if (widget.type == CallType.voice || _status != CallStatus.connected)
                  _buildMainAvatar(),
                const Spacer(),
                _buildControls(),
                const SizedBox(height: 40),
              ],
            ),
          ),
          
          // Self Video Preview (Small overlay)
          if (widget.type == CallType.video && _status == CallStatus.connected)
            Positioned(
              top: 40,
              right: 20,
              child: Container(
                width: 100,
                height: 150,
                decoration: BoxDecoration(
                  color: const Color(0xFF16233A),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: const Icon(Icons.person, color: Colors.white24),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          widget.otherUsername,
          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        const SizedBox(height: 10),
        Text(
          _status == CallStatus.connected 
              ? _formatDuration(_duration) 
              : (_status == CallStatus.calling ? "Calling..." : (_status == CallStatus.ringing ? "Incoming Call" : "Call Ended")),
          style: TextStyle(
            color: _status == CallStatus.connected ? const Color(0xFF00C48C) : Colors.white54,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMainAvatar() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing background for Calling/Ringing
        if (_status != CallStatus.connected && _status != CallStatus.ended)
          _PulsingCircle(),
        
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF2979FF).withOpacity(0.2), width: 2),
          ),
          child: CircleAvatar(
            radius: 80,
            backgroundColor: const Color(0xFF16233A),
            backgroundImage: widget.otherProfilePic != null ? NetworkImage(widget.otherProfilePic!) : null,
            child: widget.otherProfilePic == null ? const Icon(Icons.person, size: 80, color: Colors.white24) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    if (widget.isIncoming && _status == CallStatus.ringing) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(Icons.close, Colors.redAccent, "Decline", _endCall),
          _buildActionButton(Icons.check, const Color(0xFF00C48C), "Accept", _connectCall),
        ],
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildIconButton(_isMuted ? Icons.mic_off : Icons.mic, () => setState(() => _isMuted = !_isMuted), _isMuted),
            _buildIconButton(Icons.videocam_off, () {}, false),
            _buildIconButton(_isSpeakerOn ? Icons.volume_up : Icons.volume_down, () => setState(() => _isSpeakerOn = !_isSpeakerOn), _isSpeakerOn),
          ],
        ),
        const SizedBox(height: 40),
        GestureDetector(
          onTap: _endCall,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Color(0xFFFF4C61), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 15, offset: Offset(0, 5))]),
            child: const Icon(Icons.call_end, color: Colors.white, size: 32),
          ),
        ),
      ],
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap, bool isActive) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isActive ? const Color(0xFF0A2540) : Colors.white, size: 24),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, String label, VoidCallback onTap) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)]),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _PulsingCircle extends StatefulWidget {
  @override
  State<_PulsingCircle> createState() => _PulsingCircleState();
}

class _PulsingCircleState extends State<_PulsingCircle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 250 * _controller.value,
          height: 250 * _controller.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF2979FF).withOpacity(1 - _controller.value), width: 2),
          ),
        );
      },
    );
  }
}
