import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';
import 'tasks_screen.dart';
import 'calls_history_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String _activeFilter = 'All';
  RealtimeChannel? _notificationChannel;
  String? _myUsername;

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    _myUsername = await ApiService.getUsername();
    if (_myUsername != null) {
      await _fetchNotifications();
      _subscribeToNotifications();
    }
  }

  void _subscribeToNotifications() {
    if (_myUsername == null) return;
    _notificationChannel = ApiService.getNotificationsChannel(_myUsername!, () {
      if (mounted) _fetchNotifications();
    });
  }

  @override
  void dispose() {
    if (_notificationChannel != null) {
      Supabase.instance.client.removeChannel(_notificationChannel!);
    }
    super.dispose();
  }

  Future<void> _fetchNotifications() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final data = await ApiService.getNotifications();
    if (mounted) {
      setState(() {
        _notifications = data;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredNotifications {
    if (_activeFilter == 'All') return _notifications;
    return _notifications.where((n) {
      final type = n['type']?.toString().toLowerCase();
      if (_activeFilter == 'Messages') return type == 'message';
      if (_activeFilter == 'Tasks') return type == 'task';
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        backgroundColor: const Color(0xFF0A2540),
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_notifications.any((n) => n['is_read'] == false))
            TextButton(
              onPressed: () async {
                setState(() {
                  for (var n in _notifications) {
                    n['is_read'] = true;
                  }
                });
                await ApiService.markAllNotificationsAsRead();
                // Optionally re-fetch to ensure sync, but local update is enough for UX
              },
              child: const Text("Mark all read", style: TextStyle(color: Color(0xFF2979FF), fontSize: 12)),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _filteredNotifications.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _fetchNotifications,
                        color: const Color(0xFF2979FF),
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 10, bottom: 20),
                          itemCount: _filteredNotifications.length,
                          itemBuilder: (context, index) {
                            final notification = _filteredNotifications[index];
                            return Dismissible(
                              key: Key(notification['id'].toString()),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 30),
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF4C61),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
                              ),
                              onDismissed: (direction) {
                                final id = notification['id'].toString();
                                setState(() {
                                  _notifications.removeWhere((n) => n['id'].toString() == id);
                                });
                                ApiService.deleteNotification(id);
                              },
                              child: _buildNotificationCard(notification),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = ['All', 'Messages', 'Tasks'];
    return Container(
      height: 50,
      color: const Color(0xFF0A2540),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: filters.map((filter) {
          final isSelected = _activeFilter == filter;
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = filter),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? const Color(0xFF2979FF) : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white38,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final bool isRead = notification['is_read'] ?? false;
    final String type = (notification['type'] ?? 'info').toString().toLowerCase();
    final String? refId = notification['reference_id']?.toString();
    
    IconData icon;
    Color color;
    
    switch (type) {
      case 'task':
        icon = Icons.assignment_rounded;
        color = const Color(0xFFFFB300);
        break;
      case 'message':
        icon = Icons.chat_bubble_rounded;
        color = const Color(0xFF2979FF);
        break;
      case 'contact':
        icon = Icons.person_add_rounded;
        color = const Color(0xFF00C48C);
        break;
      case 'missed_call':
        icon = Icons.phone_missed_rounded;
        color = const Color(0xFFFF4C61);
        break;
      default:
        icon = Icons.notifications_rounded;
        color = Colors.white54;
    }

    return GestureDetector(
      onTap: () async {
        if (!isRead) {
          await ApiService.markNotificationAsRead(notification['id'].toString());
          _fetchNotifications();
        }
        
        if (!mounted) return;

        // Navigation logic based on type
        if (type == 'message' && notification['sender_id'] != null) {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => ChatScreen(username: notification['sender_id'])
          ));
        } else if (type == 'task') {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => const TasksScreen()
          ));
        } else if (type == 'missed_call') {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => CallsHistoryScreen()
          ));
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? const Color(0xFF16233A).withValues(alpha: 0.4) : const Color(0xFF16233A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead ? Colors.white.withValues(alpha: 0.05) : const Color(0xFF2979FF).withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification['title'] ?? "SphereX Notification",
                          style: TextStyle(
                            color: isRead ? Colors.white60 : Colors.white,
                            fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTime(notification['created_at']),
                        style: const TextStyle(color: Colors.white24, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification['body'] ?? "",
                    style: TextStyle(
                      color: isRead ? Colors.white38 : Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (!isRead)
              Container(
                margin: const EdgeInsets.only(left: 12, top: 4),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF2979FF),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return "";
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return "Just now";
      if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
      if (diff.inHours < 24) return "${diff.inHours}h ago";
      if (diff.inDays < 7) return "${diff.inDays}d ago";
      return DateFormat('MMM d').format(dt);
    } catch (e) {
      return "";
    }
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        height: 80,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF16233A).withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
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
            decoration: BoxDecoration(
              color: const Color(0xFF16233A).withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_none_rounded, size: 60, color: Colors.white.withValues(alpha: 0.1)),
          ),
          const SizedBox(height: 24),
          const Text(
            "Nothing to see here",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "We'll notify you when something important happens.",
            style: TextStyle(color: Colors.white38, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextButton.icon(
            onPressed: _fetchNotifications,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text("Refresh"),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2979FF),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
