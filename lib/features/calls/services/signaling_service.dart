import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignalingService {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;
  
  StreamController<Map<String, dynamic>>? _eventController;
  Stream<Map<String, dynamic>>? get eventStream => _eventController?.stream;

  Future<void> init(String callId) async {
    _eventController = StreamController<Map<String, dynamic>>.broadcast();
    
    _channel = _supabase.channel('call:$callId');

    // Bypass static type checking for extension methods
    (_channel as dynamic).onBroadcast(
      event: 'signal',
      callback: (payload) {
        if (_eventController != null && !_eventController!.isClosed) {
          _eventController!.add(Map<String, dynamic>.from(payload));
        }
      },
    ).subscribe();
  }

  Future<void> sendGlobalInvite(String receiverId, Map<String, dynamic> data) async {
    final inviteChannel = _supabase.channel('signaling:$receiverId');
    
    await inviteChannel.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        try {
          // Bypass static type checking for extension methods
          await (inviteChannel as dynamic).sendBroadcast(
            event: 'signal',
            payload: data,
          );
        } catch (e) {
          print('Broadcast send error: $e');
        }
        await Future.delayed(const Duration(milliseconds: 500));
        await _supabase.removeChannel(inviteChannel);
      }
    });
  }

  Future<void> sendSignal(String type, Map<String, dynamic> data) async {
    if (_channel == null) return;
    
    try {
      // Bypass static type checking for extension methods
      await (_channel as dynamic).sendBroadcast(
        event: 'signal',
        payload: {
          'type': type,
          ...data,
        },
      );
    } catch (e) {
      print('Signal send error: $e');
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
