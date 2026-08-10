import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'call_screen.dart';
import '../features/calls/models/call_model.dart' as model;

class CallsHistoryScreen extends StatefulWidget {
  const CallsHistoryScreen({super.key});

  @override
  State<CallsHistoryScreen> createState() => _CallsHistoryScreenState();
}

class _CallsHistoryScreenState extends State<CallsHistoryScreen> {
  List<Map<String, dynamic>> _calls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCallHistory();
  }

  Future<void> _loadCallHistory() async {
    setState(() => _isLoading = true);
    final history = await ApiService.getCallHistory();
    if (mounted) {
      setState(() {
        _calls = history;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      appBar: AppBar(
        title: const Text("Call History", style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        backgroundColor: const Color(0xFF0A2540),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _loadCallHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2979FF)))
          : _calls.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadCallHistory,
                  color: const Color(0xFF2979FF),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: _calls.length,
                    itemBuilder: (context, index) => _buildCallCard(_calls[index]),
                  ),
                ),
    );
  }

  Widget _buildCallCard(Map<String, dynamic> call) {
    final bool isOutgoing = call['isOutgoing'];
    final String status = (call['status'] ?? 'ended').toString().toLowerCase();
    final String type = call['type'] ?? 'voice';
    final DateTime createdAt = DateTime.parse(call['created_at']).toLocal();
    
    Color statusColor;
    IconData statusIcon;

    if (status == 'missed' || status == 'rejected' || status == 'cancelled') {
      statusColor = const Color(0xFFFF4C61);
      statusIcon = isOutgoing ? Icons.call_made : Icons.call_missed;
    } else {
      statusColor = const Color(0xFF00C48C);
      statusIcon = isOutgoing ? Icons.call_made : Icons.call_received;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16233A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFF0A2540),
              backgroundImage: call['profilePic'] != null ? NetworkImage(call['profilePic']) : null,
              child: call['profilePic'] == null 
                  ? const Icon(Icons.person, color: Colors.white24) 
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Color(0xFF16233A), shape: BoxShape.circle),
                child: Icon(
                  type == 'video' ? Icons.videocam : Icons.phone,
                  size: 12,
                  color: const Color(0xFF2979FF),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          call['otherUser'],
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Row(
          children: [
            Icon(statusIcon, size: 14, color: statusColor),
            const SizedBox(width: 6),
            Text(
              "${isOutgoing ? 'Outgoing' : 'Incoming'} • ${DateFormat('MMM d, h:mm a').format(createdAt)}",
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            type == 'video' ? Icons.videocam_rounded : Icons.phone_in_talk_rounded,
            color: const Color(0xFF2979FF),
            size: 22,
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CallScreen(
                otherUsername: call['otherUser'],
                otherProfilePic: call['profilePic'],
                type: type == 'video' ? model.CallType.video : model.CallType.voice,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: const Color(0xFF16233A), shape: BoxShape.circle),
            child: Icon(Icons.phone_missed_rounded, size: 80, color: Colors.white.withValues(alpha: 0.05)),
          ),
          const SizedBox(height: 24),
          const Text("No call history", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Your voice and video calls will appear here.", style: TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }
}
