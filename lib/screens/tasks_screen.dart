import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _currentFilter = 'all';
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final tasks = await ApiService.getTasks(_currentFilter);
    setState(() {
      _tasks = tasks;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      appBar: AppBar(
        title: const Text("My Tasks", style: TextStyle(fontWeight: FontWeight.bold)),
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
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) => _buildTaskCard(_tasks[index]),
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
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _currentFilter == filter['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilterChip(
              label: Text(filter['label']!),
              selected: isSelected,
              onSelected: (val) {
                setState(() => _currentFilter = filter['id']!);
                _loadTasks();
              },
              backgroundColor: const Color(0xFF16233A),
              selectedColor: const Color(0xFF2979FF),
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontSize: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final bool isDone = task['status'] == 'completed';
    final DateTime? dueDate = task['due_date'] != null ? DateTime.parse(task['due_date']) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16233A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _toggleTask(task['id'], isDone),
                child: Icon(
                  isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isDone ? const Color(0xFF00C48C) : Colors.white24,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  task['title'],
                  style: TextStyle(
                    color: isDone ? Colors.white24 : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Assigned to", style: TextStyle(color: Colors.white38, fontSize: 10)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const CircleAvatar(radius: 10, backgroundColor: Color(0xFF2979FF), child: Icon(Icons.person, size: 12, color: Colors.white)),
                      const SizedBox(width: 8),
                      Text(task['assigned_to'], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              if (dueDate != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Due Date", style: TextStyle(color: Colors.white38, fontSize: 10)),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM d').format(dueDate),
                      style: TextStyle(
                        color: dueDate.isBefore(DateTime.now()) && !isDone ? const Color(0xFFFF4C61) : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _toggleTask(String id, bool currentlyDone) async {
    final success = await ApiService.updateTaskStatus(id, currentlyDone ? 'pending' : 'completed');
    if (success) _loadTasks();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 80, color: Colors.white.withValues(alpha: 0.05)),
          const SizedBox(height: 20),
          const Text("No tasks found", style: TextStyle(color: Colors.white38, fontSize: 16)),
        ],
      ),
    );
  }
}
