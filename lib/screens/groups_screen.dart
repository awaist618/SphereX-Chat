import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';
import 'create_group_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    final groups = await ApiService.getMyGroups();
    if (mounted) {
      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      appBar: AppBar(
        title: const Text("Groups", style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        backgroundColor: const Color(0xFF0A2540),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _loadGroups,
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2979FF)))
          : _groups.isEmpty 
            ? _buildEmptyState()
            : RefreshIndicator(
                onRefresh: _loadGroups,
                color: const Color(0xFF2979FF),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: _groups.length,
                  itemBuilder: (context, index) => _buildGroupCard(_groups[index]),
                ),
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => const CreateGroupScreen())
          );
          if (created == true) _loadGroups();
        },
        backgroundColor: const Color(0xFF2979FF),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("Create Group", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF16233A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (context) => ChatScreen(username: group['name'], groupId: group['id'])
        )),
        leading: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF2979FF).withValues(alpha: 0.1), width: 2),
          ),
          child: CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF0F1B2D),
            backgroundImage: group['avatar_url'] != null ? NetworkImage(group['avatar_url']) : null,
            child: group['avatar_url'] == null 
              ? const Icon(Icons.groups_rounded, color: Color(0xFF2979FF), size: 30) 
              : null,
          ),
        ),
        title: Text(
          group['name'], 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            group['description'] ?? "No description available", 
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white38, fontSize: 13)
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white12),
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
              color: const Color(0xFF16233A),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.groups_3_outlined, size: 80, color: Colors.white.withValues(alpha: 0.05)),
          ),
          const SizedBox(height: 24),
          const Text(
            "Collaborate Together", 
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 8),
          const Text(
            "Create a group to chat with friends,\nshare files, and manage tasks.", 
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 14, height: 1.5)
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () async {
              final created = await Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const CreateGroupScreen())
              );
              if (created == true) _loadGroups();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2979FF).withValues(alpha: 0.1),
              foregroundColor: const Color(0xFF2979FF),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF2979FF), width: 0.5)),
            ),
            child: const Text("Start a Group"),
          ),
        ],
      ),
    );
  }
}
