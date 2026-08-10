import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'contact_profile_screen.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  const GroupDetailsScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  String? _myUsername;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _myUsername = await ApiService.getUsername();
    final members = await ApiService.getGroupMembers(widget.groupId);
    
    if (mounted) {
      setState(() {
        _members = members;
        _isLoading = false;
        _isAdmin = members.any((m) => m['user_id'] == _myUsername && m['role'] == 'admin');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      appBar: AppBar(
        title: const Text("Group Info", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0A2540),
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.person_add_rounded, color: Color(0xFF2979FF)),
              onPressed: _showAddMemberDialog,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2979FF)))
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildGroupHeader(),
                  const SizedBox(height: 20),
                  _buildMembersList(),
                ],
              ),
            ),
    );
  }

  Widget _buildGroupHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF0A2540),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: const Color(0xFF16233A),
            child: const Icon(Icons.groups, size: 60, color: Colors.white24),
          ),
          const SizedBox(height: 20),
          Text(widget.groupName, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text("${_members.length} members", style: const TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildMembersList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            "MEMBERS",
            style: TextStyle(color: const Color(0xFF2979FF).withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _members.length,
          itemBuilder: (context, index) {
            final member = _members[index];
            final bool isMe = member['user_id'] == _myUsername;
            final bool isMemberAdmin = member['role'] == 'admin';

            return ListTile(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ContactProfileScreen(username: member['username']))),
              leading: Stack(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF16233A),
                    backgroundImage: member['profilePic'] != null ? NetworkImage(member['profilePic']) : null,
                    child: member['profilePic'] == null ? Text(member['username'][0].toUpperCase(), style: const TextStyle(color: Colors.white70)) : null,
                  ),
                  if (member['isOnline'] == true)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: const Color(0xFF00C48C), shape: BoxShape.circle, border: Border.all(color: const Color(0xFF0F1B2D), width: 2)),
                      ),
                    ),
                ],
              ),
              title: Text(
                member['username'] + (isMe ? " (You)" : ""),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                isMemberAdmin ? "Admin" : "Member",
                style: TextStyle(color: isMemberAdmin ? const Color(0xFFFFB300) : Colors.white38, fontSize: 12),
              ),
              trailing: _isAdmin && !isMe ? _buildMemberOptions(member) : null,
            );
          },
        ),
      ],
    );
  }

  Widget _buildMemberOptions(Map<String, dynamic> member) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white24),
      color: const Color(0xFF16233A),
      onSelected: (value) async {
        if (value == 'remove') {
          final success = await ApiService.removeGroupMember(widget.groupId, member['user_id']);
          if (success) _loadData();
        } else if (value == 'make_admin') {
          await ApiService.updateMemberRole(widget.groupId, member['user_id'], 'admin');
          _loadData();
        } else if (value == 'make_member') {
          await ApiService.updateMemberRole(widget.groupId, member['user_id'], 'member');
          _loadData();
        }
      },
      itemBuilder: (context) => [
        if (member['role'] == 'member')
          const PopupMenuItem(value: 'make_admin', child: Text("Make Admin", style: TextStyle(color: Colors.white))),
        if (member['role'] == 'admin')
          const PopupMenuItem(value: 'make_member', child: Text("Remove Admin", style: TextStyle(color: Colors.white))),
        const PopupMenuItem(value: 'remove', child: Text("Remove from Group", style: TextStyle(color: Color(0xFFFF4C61)))),
      ],
    );
  }

  void _showAddMemberDialog() async {
    final contacts = await ApiService.getMyContacts();
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16233A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Add Members", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Expanded(
              child: contacts.isEmpty 
                ? const Center(child: Text("No contacts to add", style: TextStyle(color: Colors.white38)))
                : ListView.builder(
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      final bool isAlreadyMember = _members.any((m) => m['user_id'] == contact['username']);
                      
                      return ListTile(
                        leading: CircleAvatar(backgroundImage: contact['profilePic'] != null ? NetworkImage(contact['profilePic']) : null),
                        title: Text(contact['username'], style: const TextStyle(color: Colors.white)),
                        trailing: isAlreadyMember 
                          ? const Icon(Icons.check_circle, color: Color(0xFF00C48C))
                          : IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2979FF)),
                              onPressed: () async {
                                final success = await ApiService.addGroupMember(widget.groupId, contact['username']);
                                if (success) {
                                  Navigator.pop(context);
                                  _loadData();
                                }
                              },
                            ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
