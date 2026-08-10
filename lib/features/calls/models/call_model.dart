enum CallType { voice, video }

enum CallStatus {
  idle,
  outgoing,
  ringing,
  connecting,
  connected,
  ending,
  ended,
  rejected,
  cancelled,
  missed,
  failed,
  busy
}

class CallSession {
  final String id;
  final String callerId;
  final String receiverId;
  final CallType type;
  final CallStatus status;
  final DateTime createdAt;

  CallSession({
    required this.id,
    required this.callerId,
    required this.receiverId,
    required this.type,
    this.status = CallStatus.idle,
    required this.createdAt,
  });

  CallSession copyWith({
    CallStatus? status,
  }) {
    return CallSession(
      id: id,
      callerId: callerId,
      receiverId: receiverId,
      type: type,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
