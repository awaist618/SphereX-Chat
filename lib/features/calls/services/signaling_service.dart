import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/realtime_client.dart';

class SignalingService {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;
  
  StreamController<Map<String, dynamic>>? _eventController;
  Stream<Map<String, dynamic>>? get eventStream => _eventController?.stream;

  Future<void> init(String callId) async {
    _eventController = StreamController<Map<String, dynamic>>.broadcast();
    
    _channel = _supabase.channel('call:$callId');

    _channel!.onBroadcast(
      event: 'signal',
      callback: (payload) {
        debugPrint('Signaling received: $payload');
        if (_eventController != null && !_eventController!.isClosed) {
          _eventController!.add(Map<String, dynamic>.from(payload));
        }
      },
    ).subscribe();
  }

  Future<void> sendGlobalInvite(String receiverId, Map<String, dynamic> data) async {
    final inviteChannel = _supabase.channel('signaling:$receiverId');
    debugPrint('Sending global invite to $receiverId...');
    
    await inviteChannel.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        try {
          await inviteChannel.sendBroadcastMessage(
            event: 'signal',
            payload: data,
          );
          debugPrint('Global invite broadcasted successfully');
        } catch (e) {
          debugPrint('Global broadcast error: $e');
        }
        // Increased delay to ensure the broadcast is flushed before channel is removed
        await Future.delayed(const Duration(seconds: 2));
        await _supabase.removeChannel(inviteChannel);
      } else if (status == RealtimeSubscribeStatus.channelError) {
        debugPrint('Signaling subscription error: $error');
      }
    });
  }

  Future<void> sendSignal(String type, Map<String, dynamic> data) async {
    if (_channel == null) return;
    
    try {
      await _channel!.sendBroadcastMessage(
        event: 'signal',
        payload: {
          'type': type,
          ...data,
        },
      );
      debugPrint('Signal sent: $type');
    } catch (e) {
      debugPrint('Signal broadcast error: $e');
    }
  }

  Future<void> close() async {
    if (_channel != null) {
      await _supabase.removeChannel(_channel!);
      _channel = null;
    }
    _eventController?.close();
    _eventController = null;
  }
}
