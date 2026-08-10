import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _currentFilter = 'all';
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;
  RealtimeChannel? _taskChannel;
  String? _myUsername;

  @override
  void initState() {
    super.initState();
    _initTasks();
  }

  Future<void> _initTasks() async {
    _myUsername = await ApiService.getUsername();
    if (_myUsername != null) {
      await _loadTasks();
      _subscribeToTasks();
    }
  }

  void _subscribeToTasks() {
    if (_myUsername == null) return;
    _taskChannel = ApiService.getTasksChannel(_myUsername!, () {
      if (mounted) _loadTasks();
    });
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final tasks = await ApiService.getTasks(_currentFilter);
    if (mounted) {
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    if (_taskChannel != null) {
      Supabase.instance.client.removeChannel(_taskChannel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      appBar: AppBar(
        title: const Text("My Tasks", style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        backgroundColor: const Color(0xFF0A2540),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2979FF)))
              : _tasks.isEmpty 
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadTasks,
                    color: const Color(0xFF2979FF),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) => _buildTaskCard(_tasks[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'label': 'All', 'id': 'all'},
      {'label': 'Assigned to me', 'id': 'assigned_to_me'},
      {'label': 'Created by me', 'id': 'created_by_me'},
      {'label': 'Done', 'id': 'done'},
    ];

    return Container(
      height: 65,
      color: const Color(0xFF0A2540),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _currentFilter == filter['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                setState(() => _currentFilter = filter['id']!);
                _loadTasks();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2979FF) : const Color(0xFF16233A),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.05)),
                  boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF2979FF).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))] : [],
                ),
                child: Center(
                  child: Text(
                    filter['label']!,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white38,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final String status = task['status'] ?? 'pending';
    final bool isDone = status == 'completed';
    final bool isCancelled = status == 'cancelled';
    final DateTime? dueDate = task['due_date'] != null ? DateTime.parse(task['due_date']) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF16233A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDone ? const Color(0xFF00C48C).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.03)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 6))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => _showStatusPicker(task),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatusBadge(status),
                          const SizedBox(height: 12),
                          Text(
                            task['title'],
                            style: TextStyle(
                              color: isDone || isCancelled ? Colors.white24 : Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              decoration: isDone || isCancelled ? TextDecoration.lineThrough : null,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      _getStatusIcon(status),
                      color: _getStatusColor(status).withValues(alpha: 0.6),
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("ASSIGNED TO", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF2979FF).withValues(alpha: 0.2))),
                              child: const CircleAvatar(radius: 12, backgroundColor: Color(0xFF0F1B2D), child: Icon(Icons.person, size: 14, color: Color(0xFF2979FF))),
                            ),
                            const SizedBox(width: 10),
                            Text("@${task['assigned_to']}", style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                    if (task['source_message_id'] != null)
                      _buildChatButton(task),
                    if (dueDate != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("DUE DATE", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                          const SizedBox(height: 8),
                          Text(
                            DateFormat('MMM d, yyyy').format(dueDate),
                            style: TextStyle(
                              color: dueDate.isBefore(DateTime.now()) && !isDone && !isCancelled ? const Color(0xFFFF4C61) : Colors.white60,
                              fontSize: 13,
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final Color color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildChatButton(Map<String, dynamic> task) {
    return InkWell(
      onTap: () => _viewInChat(task),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF2979FF).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2979FF).withValues(alpha: 0.1)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 16, color: Color(0xFF2979FF)),
            SizedBox(width: 8),
            Text("CHAT", style: TextStyle(color: Color(0xFF2979FF), fontSize: 11, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress': return const Color(0xFF2979FF);
      case 'completed': return const Color(0xFF00C48C);
      case 'cancelled': return const Color(0xFFFF4C61);
      case 'pending':
      default: return const Color(0xFFFFB300);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress': return Icons.rotate_right_rounded;
      case 'completed': return Icons.check_circle_rounded;
      case 'cancelled': return Icons.cancel_rounded;
      case 'pending':
      default: return Icons.schedule_rounded;
    }
  }

  void _showStatusPicker(Map<String, dynamic> task) {
    final List<Map<String, dynamic>> statuses = [
      {'id': 'pending', 'label': 'Pending', 'icon': Icons.schedule_rounded, 'color': const Color(0xFFFFB300)},
      {'id': 'in_progress', 'label': 'In Progress', 'icon': Icons.rotate_right_rounded, 'color': const Color(0xFF2979FF)},
      {'id': 'completed', 'label': 'Completed', 'icon': Icons.check_circle_rounded, 'color': const Color(0xFF00C48C)},
      {'id': 'cancelled', 'label': 'Cancelled', 'icon': Icons.cancel_rounded, 'color': const Color(0xFFFF4C61)},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A2540),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Update Status", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Select the current state of this task.", style: TextStyle(color: Colors.white38, fontSize: 14)),
              const SizedBox(height: 24),
              ...statuses.map((s) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                onTap: () async {
                  Navigator.pop(context);
                  final success = await ApiService.updateTaskStatus(task['id'], s['id']!);
                  if (success) _loadTasks();
                },
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: s['color']!.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(s['icon'] as IconData, color: s['color'] as Color, size: 20),
                ),
                title: Text(s['label']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                trailing: task['status'] == s['id'] 
                  ? const Icon(Icons.check_circle, color: Color(0xFF2979FF)) 
                  : const Icon(Icons.chevron_right, color: Colors.white10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              )),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _viewInChat(Map<String, dynamic> task) async {
    final contextData = await ApiService.getTaskContext(task);
    if (contextData != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            username: contextData['name'],
            groupId: contextData['groupId'],
            targetMessageId: task['source_message_id'],
          ),
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: const Color(0xFF16233A), shape: BoxShape.circle),
            child: Icon(Icons.assignment_turned_in_outlined, size: 80, color: Colors.white.withValues(alpha: 0.05)),
          ),
          const SizedBox(height: 24),
          const Text("No tasks found", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Check back later or try a different filter.", style: TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }
}
