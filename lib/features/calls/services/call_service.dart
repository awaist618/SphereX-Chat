import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'webrtc_service.dart';
import 'signaling_service.dart';
import '../models/call_model.dart';
import '../../../services/api_service.dart';

class CallService {
  final WebRTCService _webRTCService = WebRTCService();
  final SignalingService _signalingService = SignalingService();
  
  CallSession? _currentSession;
  StreamSubscription? _signalSubscription;
  
  Function(CallStatus)? onStatusChange;
  Function(MediaStream)? onRemoteStream;
  Function(MediaStream)? onLocalStream;

  Future<void> startCall(String receiverId, CallType type) async {
    final myUsername = await ApiService.getUsername();
    if (myUsername == null) return;

    final callId = const Uuid().v4();
    
    // Create Call Record in Database
    final dbCallId = await ApiService.createCallRecord(
      callerId: myUsername,
      receiverId: receiverId,
      type: type.name,
    );

    _currentSession = CallSession(
      id: dbCallId ?? callId,
      callerId: myUsername,
      receiverId: receiverId,
      type: type,
      status: CallStatus.outgoing,
      createdAt: DateTime.now(),
    );

    await _initServices(_currentSession!.id, type == CallType.video);
    
    // Create SDP Offer
    final offer = await _webRTCService.createOffer();
    
    // Send Call Invite through Global Channel
    await _signalingService.sendGlobalInvite(receiverId, {
      'type': 'call_invite',
      'call_id': _currentSession!.id,
      'caller_id': myUsername,
      'receiver_id': receiverId,
      'call_type': type.name,
      'sdp': offer.sdp,
      'sdp_type': offer.type,
    });

    onStatusChange?.call(CallStatus.outgoing);
    onLocalStream?.call(_webRTCService.localStream!);
  }

  Future<void> acceptCall(String callId, String callerId, CallType type, String sdp, String sdpType) async {
    final myUsername = await ApiService.getUsername();
    if (myUsername == null) return;

    _currentSession = CallSession(
      id: callId,
      callerId: callerId,
      receiverId: myUsername,
      type: type,
      status: CallStatus.connecting,
      createdAt: DateTime.now(),
    );

    await _initServices(callId, type == CallType.video);
    
    // Set Remote Description (Offer)
    await _webRTCService.setRemoteDescription(RTCSessionDescription(sdp, sdpType));
    
    // Update Call Status in DB
    await ApiService.updateCallStatus(callId, 'connected');
    
    // Create SDP Answer
    final answer = await _webRTCService.createAnswer();
    
    // Send Answer
    await _signalingService.sendSignal('call_answer', {
      'sdp': answer.sdp,
      'sdp_type': answer.type,
    });

    onStatusChange?.call(CallStatus.connected);
    onLocalStream?.call(_webRTCService.localStream!);
  }

  Future<void> _initServices(String callId, bool isVideo) async {
    await _signalingService.init(callId);
    await _webRTCService.init(isVideo);

    _webRTCService.onIceCandidate = (candidate) {
      _signalingService.sendSignal('ice_candidate', {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _webRTCService.onRemoteStream = (stream) {
      onRemoteStream?.call(stream);
    };

    _webRTCService.onConnectionStateChange = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        onStatusChange?.call(CallStatus.connected);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
                 state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
                 state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        endCall();
      }
    };

    _signalSubscription = _signalingService.eventStream?.listen((event) {
      _handleSignalingEvent(event);
    });
  }

  void _handleSignalingEvent(Map<String, dynamic> event) async {
    final type = event['type'];
    
    switch (type) {
      case 'call_answer':
        if (_currentSession?.status == CallStatus.outgoing) {
          await _webRTCService.setRemoteDescription(
            RTCSessionDescription(event['sdp'], event['sdp_type']),
          );
        }
        break;
      case 'ice_candidate':
        await _webRTCService.addIceCandidate(
          RTCIceCandidate(
            event['candidate'],
            event['sdpMid'],
            event['sdpMLineIndex'],
          ),
        );
        break;
      case 'call_reject':
      case 'call_end':
        endCall(notify: false);
        break;
    }
  }

  Future<void> endCall({bool notify = true}) async {
    if (_currentSession != null) {
      String finalStatus = 'ended';
      if (_currentSession!.status == CallStatus.outgoing) finalStatus = 'cancelled';
      if (_currentSession!.status == CallStatus.ringing) finalStatus = 'rejected';
      
      await ApiService.updateCallStatus(_currentSession!.id, finalStatus);
    }

    if (notify) {
      await _signalingService.sendSignal('call_end', {});
    }
    
    await _webRTCService.dispose();
    await _signalingService.close();
    _signalSubscription?.cancel();
    
    _currentSession = null;
    onStatusChange?.call(CallStatus.ended);
  }

  void toggleMute(bool muted) => _webRTCService.toggleMute(muted);
  void toggleCamera(bool enabled) => _webRTCService.toggleCamera(enabled);
  Future<void> switchCamera() => _webRTCService.switchCamera();
  
  Future<void> setSpeakerphoneOn(bool on) async {
    await Helper.setSpeakerphoneOn(on);
  }
}
