import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../features/calls/models/call_model.dart' as model;
import '../features/calls/services/call_service.dart';
import '../features/calls/services/permission_service.dart';

class CallScreen extends StatefulWidget {
  final String otherUsername;
  final String? otherProfilePic;
  final model.CallType type;
  final bool isIncoming;
  final String? callId;
  final String? sdp;
  final String? sdpType;

  const CallScreen({
    super.key,
    required this.otherUsername,
    this.otherProfilePic,
    required this.type,
    this.isIncoming = false,
    this.callId,
    this.sdp,
    this.sdpType,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final CallService _callService = CallService();
  model.CallStatus _status = model.CallStatus.idle;
  
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  bool _isMuted = false;
  bool _isCameraOff = false;
  int _duration = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _setupCallService();
    _startFlow();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _setupCallService() {
    _callService.onStatusChange = (status) {
      if (!mounted) return;
      setState(() => _status = status);
      
      if (status == model.CallStatus.connected) {
        _startTimer();
      } else if (status == model.CallStatus.ended) {
        _stopTimer();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    };

    _callService.onLocalStream = (stream) {
      if (!mounted) return;
      setState(() {
        _localRenderer.srcObject = stream;
      });
    };

    _callService.onRemoteStream = (stream) {
      if (!mounted) return;
      setState(() {
        _remoteRenderer.srcObject = stream;
      });
    };
  }

  Future<void> _startFlow() async {
    final hasPermission = await PermissionService.checkPermissions(widget.type == model.CallType.video);
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions required for calling')),
        );
        Navigator.pop(context);
      }
      return;
    }

    if (widget.isIncoming) {
      setState(() => _status = model.CallStatus.ringing);
    } else {
      await _callService.startCall(widget.otherUsername, widget.type);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _duration++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  void _acceptCall() async {
    if (widget.callId != null && widget.sdp != null && widget.sdpType != null) {
      await _callService.acceptCall(
        widget.callId!,
        widget.otherUsername,
        widget.type,
        widget.sdp!,
        widget.sdpType!,
      );
    }
  }

  void _endCall() {
    _callService.endCall();
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _callService.toggleMute(_isMuted);
  }

  void _toggleCamera() {
    setState(() => _isCameraOff = !_isCameraOff);
    _callService.toggleCamera(!_isCameraOff);
  }

  void _switchCamera() {
    _callService.switchCamera();
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _stopTimer();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A2540),
      body: Stack(
        children: [
          // Remote Video
          if (widget.type == model.CallType.video)
            Positioned.fill(
              child: RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),

          // Dark Overlay for non-connected states or voice
          if (widget.type == model.CallType.voice || _status != model.CallStatus.connected)
            Positioned.fill(
              child: Container(color: const Color(0xFF0A2540).withOpacity(0.8)),
            ),

          // UI Content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                _buildHeader(),
                const Spacer(),
                if (widget.type == model.CallType.voice || _status != model.CallStatus.connected)
                  _buildAvatar(),
                const Spacer(),
                _buildControls(),
                const SizedBox(height: 40),
              ],
            ),
          ),

          // Local Video Preview
          if (widget.type == model.CallType.video && _status == model.CallStatus.connected)
            Positioned(
              top: 40,
              right: 20,
              child: Container(
                width: 100,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    String statusText = "";
    switch (_status) {
      case model.CallStatus.idle:
        statusText = "Initializing...";
        break;
      case model.CallStatus.outgoing:
        statusText = "Calling...";
        break;
      case model.CallStatus.ringing:
        statusText = "Incoming Call";
        break;
      case model.CallStatus.connecting:
        statusText = "Connecting...";
        break;
      case model.CallStatus.connected:
        statusText = _formatDuration(_duration);
        break;
      case model.CallStatus.ended:
        statusText = "Call Ended";
        break;
      default:
        statusText = "";
    }

    return Column(
      children: [
        Text(
          widget.otherUsername,
          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          statusText,
          style: TextStyle(
            color: _status == model.CallStatus.connected ? const Color(0xFF00C48C) : Colors.white54,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF2979FF).withOpacity(0.1), width: 4),
      ),
      child: CircleAvatar(
        radius: 80,
        backgroundColor: const Color(0xFF16233A),
        backgroundImage: widget.otherProfilePic != null ? NetworkImage(widget.otherProfilePic!) : null,
        child: widget.otherProfilePic == null ? const Icon(Icons.person, size: 80, color: Colors.white10) : null,
      ),
    );
  }

  Widget _buildControls() {
    if (widget.isIncoming && _status == model.CallStatus.ringing) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCircleButton(Icons.call_end, Colors.redAccent, _endCall, "Decline"),
          _buildCircleButton(Icons.call, const Color(0xFF00C48C), _acceptCall, "Accept"),
        ],
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildIconButton(_isMuted ? Icons.mic_off : Icons.mic, _toggleMute, _isMuted),
            if (widget.type == model.CallType.video)
              _buildIconButton(_isCameraOff ? Icons.videocam_off : Icons.videocam, _toggleCamera, _isCameraOff),
            if (widget.type == model.CallType.video)
              _buildIconButton(Icons.cameraswitch, _switchCamera, false),
            _buildIconButton(Icons.volume_up, () {}, false),
          ],
        ),
        const SizedBox(height: 40),
        _buildCircleButton(Icons.call_end, const Color(0xFFFF4C61), _endCall, "End"),
      ],
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap, bool active) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: active ? const Color(0xFF0A2540) : Colors.white),
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, Color color, VoidCallback onTap, String label) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
