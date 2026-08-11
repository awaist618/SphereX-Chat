import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'call_screen.dart';
import 'chat_screen.dart';
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

  void _showCallDetails(Map<String, dynamic> call) async {
    final details = await ApiService.getCallDetails(call['id'].toString());
    if (details == null || !mounted) return;

    final createdAt = DateTime.parse(details['created_at']).toLocal();
    final answeredAt = details['answered_at'] != null ? DateTime.parse(details['answered_at']).toLocal() : null;
    final endedAt = details['ended_at'] != null ? DateTime.parse(details['ended_at']).toLocal() : null;
    
    Duration? duration;
    if (answeredAt != null && endedAt != null) {
      duration = endedAt.difference(answeredAt);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A2540),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 30),
            CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFF16233A),
              backgroundImage: details['profilePic'] != null ? NetworkImage(details['profilePic']) : null,
              child: details['profilePic'] == null ? const Icon(Icons.person, size: 50, color: Colors.white10) : null,
            ),
            const SizedBox(height: 20),
            Text(details['otherUser'], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            Text(details['isOutgoing'] ? "Outgoing Call" : "Incoming Call", style: const TextStyle(color: Colors.white38, fontSize: 14)),
            const SizedBox(height: 30),
            _buildDetailRow(Icons.calendar_today_rounded, "Date", DateFormat('EEEE, MMM d').format(createdAt)),
            _buildDetailRow(Icons.access_time_rounded, "Time", DateFormat('h:mm a').format(createdAt)),
            if (duration != null)
              _buildDetailRow(Icons.timer_outlined, "Duration", "${duration.inMinutes}m ${duration.inSeconds % 60}s"),
            _buildDetailRow(Icons.info_outline, "Status", details['status'].toString().toUpperCase(), color: _getStatusColor(details['status'])),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(username: details['otherUser'])));
                    },
                    icon: const Icon(Icons.message_rounded, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text("Message"),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16233A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => CallScreen(
                          otherUsername: details['otherUser'],
                          otherProfilePic: details['profilePic'],
                          type: details['type'] == 'video' ? model.CallType.video : model.CallType.voice,
                        ),
                      ));
                    },
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text("Call Back"),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2979FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.white24, size: 20),
          const SizedBox(width: 15),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 14)),
          const Spacer(),
          Flexible(
            child: Text(
              value, 
              style: TextStyle(color: color ?? Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'missed':
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFFF4C61);
      case 'connected':
      case 'ended':
        return const Color(0xFF00C48C);
      default:
        return Colors.white54;
    }
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
        onTap: () => _showCallDetails(call),
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
            Expanded(
              child: Text(
                "${isOutgoing ? 'Outgoing' : 'Incoming'} • ${DateFormat('MMM d, h:mm a').format(createdAt)}",
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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
