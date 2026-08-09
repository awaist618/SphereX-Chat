import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

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
    final groups = await ApiService.getMyGroups();
    setState(() {
      _groups = groups;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      appBar: AppBar(
        title: const Text("Groups", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0A2540),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2979FF)))
          : _groups.isEmpty 
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: _groups.length,
                itemBuilder: (context, index) => _buildGroupTile(_groups[index]),
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateGroupDialog,
        backgroundColor: const Color(0xFF2979FF),
        child: const Icon(Icons.group_add, color: Colors.white),
      ),
    );
  }

  Widget _buildGroupTile(Map<String, dynamic> group) {
    return ListTile(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(username: group['name'], groupId: group['id']))),
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: const Color(0xFF16233A),
        backgroundImage: group['avatar_url'] != null ? NetworkImage(group['avatar_url']) : null,
        child: group['avatar_url'] == null ? const Icon(Icons.groups, color: Colors.white70) : null,
      ),
      title: Text(group['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text(group['description'] ?? "No description", style: const TextStyle(color: Colors.white38, fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white10),
    );
  }

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16233A),
        title: const Text("Create New Group", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Group Name")),
            TextField(controller: descController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Description")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final myUser = await ApiService.getUsername();
                final groupId = await ApiService.createGroup(nameController.text, descController.text, [myUser!]);
                if (groupId != null) {
                  Navigator.pop(context);
                  _loadGroups();
                }
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups_outlined, size: 80, color: Colors.white.withValues(alpha: 0.05)),
          const SizedBox(height: 20),
          const Text("You haven't joined any groups", style: TextStyle(color: Colors.white38, fontSize: 16)),
        ],
      ),
    );
  }
}
