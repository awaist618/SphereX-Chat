import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'contact_profile_screen.dart';
import 'shared_media_screen.dart';

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
  Map<String, dynamic>? _groupData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _myUsername = await ApiService.getUsername();
    final members = await ApiService.getGroupMembers(widget.groupId);
    final details = await ApiService.getGroupDetails(widget.groupId);
    
    if (mounted) {
      setState(() {
        _members = members;
        _groupData = details;
        _isLoading = false;
        _isAdmin = members.any((m) => m['user_id'] == _myUsername && m['role'] == 'admin');
      });
    }
  }

  Future<void> _pickAndUploadGroupImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final success = await ApiService.uploadGroupAvatar(widget.groupId, bytes, image.name);
      if (success) _loadData();
    }
  }

  Future<void> _confirmLeave() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16233A),
        title: const Text("Leave Group?", style: TextStyle(color: Colors.white)),
        content: const Text("You will no longer be able to send or receive messages in this group.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Leave", style: TextStyle(color: Color(0xFFFF4C61)))
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiService.leaveGroup(widget.groupId);
      if (success && mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
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
          if (_isAdmin || (_groupData?['allow_members_to_add'] ?? true))
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
                  if (_isAdmin) _buildAdminSettings(),
                  const SizedBox(height: 20),
                  _buildMediaShortcut(),
                  const SizedBox(height: 20),
                  _buildMembersList(),
                  const SizedBox(height: 30),
                  _buildLeaveButton(),
                  if (_isAdmin) ...[
                    const SizedBox(height: 15),
                    _buildDeleteButton(),
                  ],
                  const SizedBox(height: 40),
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
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(35)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _isAdmin ? _pickAndUploadGroupImage : null,
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF2979FF).withValues(alpha: 0.3), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 65,
                    backgroundColor: const Color(0xFF16233A),
                    backgroundImage: _groupData?['avatar_url'] != null 
                      ? NetworkImage(_groupData!['avatar_url']) 
                      : null,
                    child: _groupData?['avatar_url'] == null 
                      ? const Icon(Icons.groups_rounded, size: 70, color: Colors.white10) 
                      : null,
                  ),
                ),
                if (_isAdmin)
                  Positioned(
                    bottom: 5, right: 5,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2979FF), 
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0A2540), width: 3),
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)]
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 20, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          Text(
            widget.groupName, 
            style: const TextStyle(
              color: Colors.white, 
              fontSize: 28, 
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5
            )
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "${_members.length} members", 
              style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminSettings() {
    bool onlyAdmins = _groupData?['only_admins_message'] ?? false;
    bool allowAdd = _groupData?['allow_members_to_add'] ?? true;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16233A), 
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 5),
              child: Text(
                "ADMIN SETTINGS",
                style: TextStyle(
                  color: const Color(0xFF2979FF).withValues(alpha: 0.8), 
                  fontSize: 10, 
                  fontWeight: FontWeight.w900, 
                  letterSpacing: 1.5
                ),
              ),
            ),
            SwitchListTile(
              title: const Text("Only Admins can Send", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              subtitle: const Text("Mute regular members", style: TextStyle(color: Colors.white38, fontSize: 12)),
              value: onlyAdmins,
              activeColor: const Color(0xFF2979FF),
              onChanged: (val) async {
                final success = await ApiService.updateGroupSettings(widget.groupId, {'only_admins_message': val});
                if (success) _loadData();
              },
            ),
            Divider(color: Colors.white.withValues(alpha: 0.05), height: 1, indent: 20, endIndent: 20),
            SwitchListTile(
              title: const Text("Members can Add People", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              subtitle: const Text("Allow members to invite friends", style: TextStyle(color: Colors.white38, fontSize: 12)),
              value: allowAdd,
              activeColor: const Color(0xFF2979FF),
              onChanged: (val) async {
                final success = await ApiService.updateGroupSettings(widget.groupId, {'allow_members_to_add': val});
                if (success) _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton.icon(
        onPressed: _confirmDeleteGroup,
        icon: const Icon(Icons.delete_forever_rounded),
        label: const Text("Delete Group", style: TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF4C61).withValues(alpha: 0.1),
          foregroundColor: const Color(0xFFFF4C61),
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          side: const BorderSide(color: Color(0xFFFF4C61), width: 0.5),
          elevation: 0,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16233A),
        title: const Text("Delete Group?", style: TextStyle(color: Colors.white)),
        content: const Text("This will permanently delete the group and all its messages for everyone. This action cannot be undone.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Delete Everything", style: TextStyle(color: Color(0xFFFF4C61)))
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final success = await ApiService.deleteGroup(widget.groupId);
      if (success && mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        setState(() => _isLoading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete group")));
      }
    }
  }

  Widget _buildMediaShortcut() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFF16233A), borderRadius: BorderRadius.circular(20)),
        child: ListTile(
          onTap: () async {
            final msgs = await ApiService.getMessages("", "", groupId: widget.groupId);
            if (!mounted) return;
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => SharedMediaScreen(messages: msgs, title: widget.groupName)
            ));
          },
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF2979FF).withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.perm_media_rounded, color: Color(0xFF2979FF), size: 20),
          ),
          title: const Text("Shared Media", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: const Text("Photos, videos and documents", style: TextStyle(color: Colors.white38, fontSize: 12)),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white12),
        ),
      ),
    );
  }

  Widget _buildMembersList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
          child: Text(
            "MEMBERS",
            style: TextStyle(
              color: const Color(0xFF2979FF).withValues(alpha: 0.8), 
              fontSize: 10, 
              fontWeight: FontWeight.w900, 
              letterSpacing: 1.5
            ),
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

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF16233A).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ContactProfileScreen(username: member['username']))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF0F1B2D),
                      backgroundImage: member['profilePic'] != null ? NetworkImage(member['profilePic']) : null,
                      child: member['profilePic'] == null 
                        ? Text(member['username'][0].toUpperCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)) 
                        : null,
                    ),
                    if (member['isOnline'] == true)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C48C), 
                            shape: BoxShape.circle, 
                            border: Border.all(color: const Color(0xFF0F1B2D), width: 2)
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  member['username'] + (isMe ? " (You)" : ""),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: Row(
                  children: [
                    if (isMemberAdmin)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB300).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.2)),
                        ),
                        child: const Text(
                          "Admin", 
                          style: TextStyle(color: Color(0xFFFFB300), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      )
                    else
                      const Text(
                        "Member", 
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                  ],
                ),
                trailing: _isAdmin && !isMe ? _buildMemberOptions(member) : null,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMemberOptions(Map<String, dynamic> member) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white38),
      color: const Color(0xFF16233A),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      onSelected: (value) async {
        bool success = false;
        String message = "";

        if (value == 'remove') {
          success = await ApiService.removeGroupMember(widget.groupId, member['user_id']);
          message = success ? "Member removed" : "Failed to remove member";
        } else if (value == 'make_admin') {
          success = await ApiService.updateMemberRole(widget.groupId, member['user_id'], 'admin');
          message = success ? "${member['username']} is now an Admin" : "Failed to update role";
        } else if (value == 'make_member') {
          success = await ApiService.updateMemberRole(widget.groupId, member['user_id'], 'member');
          message = success ? "Admin rights removed from ${member['username']}" : "Failed to update role";
        }

        if (success) {
          _loadData();
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: success ? const Color(0xFF00C48C) : const Color(0xFFFF4C61),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            )
          );
        }
      },
      itemBuilder: (context) => [
        if (member['role'] == 'member')
          const PopupMenuItem(
            value: 'make_admin', 
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFFFFB300), size: 20),
                SizedBox(width: 12),
                Text("Make Admin", style: TextStyle(color: Colors.white)),
              ],
            )
          ),
        if (member['role'] == 'admin')
          const PopupMenuItem(
            value: 'make_member', 
            child: Row(
              children: [
                Icon(Icons.remove_moderator_outlined, color: Colors.white70, size: 20),
                SizedBox(width: 12),
                Text("Dismiss as Admin", style: TextStyle(color: Colors.white)),
              ],
            )
          ),
        const PopupMenuItem(
          value: 'remove', 
          child: Row(
            children: [
              Icon(Icons.person_remove_outlined, color: Color(0xFFFF4C61), size: 20),
              SizedBox(width: 12),
              Text("Remove from Group", style: TextStyle(color: Color(0xFFFF4C61))),
            ],
          )
        ),
      ],
    );
  }

  Widget _buildLeaveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton.icon(
        onPressed: _confirmLeave,
        icon: const Icon(Icons.logout_rounded),
        label: const Text("Leave Group", style: TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF4C61).withValues(alpha: 0.1),
          foregroundColor: const Color(0xFFFF4C61),
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
        ),
      ),
    );
  }

  void _showAddMemberDialog() async {
    final contacts = await ApiService.getMyContacts();
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16233A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (sheetContext) => Container(
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
                                if (success && sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
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
