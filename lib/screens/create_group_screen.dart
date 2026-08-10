import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final List<String> _selectedMembers = [];
  List<Map<String, dynamic>> _contacts = [];
  Uint8List? _groupImageBytes;
  String? _imageName;
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final contacts = await ApiService.getMyContacts();
    if (mounted) {
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _groupImageBytes = bytes;
        _imageName = image.name;
      });
    }
  }

  void _toggleMember(String username) {
    setState(() {
      if (_selectedMembers.contains(username)) {
        _selectedMembers.remove(username);
      } else {
        _selectedMembers.add(username);
      }
    });
  }

  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a group name")));
      return;
    }

    setState(() => _isCreating = true);
    
    try {
      final myUser = await ApiService.getUsername();
      if (myUser == null) return;

      final List<String> members = [myUser, ..._selectedMembers];
      final groupId = await ApiService.createGroup(_nameController.text.trim(), _descController.text.trim(), members);

      if (groupId != null) {
        if (_groupImageBytes != null && _imageName != null) {
          await ApiService.uploadGroupAvatar(groupId, _groupImageBytes!, _imageName!);
        }
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        throw Exception("Group creation failed");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      appBar: AppBar(
        title: const Text("New Group", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0A2540),
        elevation: 0,
        centerTitle: true,
        actions: [
          if (!_isCreating)
            TextButton(
              onPressed: _createGroup,
              child: const Text("Create", style: TextStyle(color: Color(0xFF2979FF), fontWeight: FontWeight.bold)),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2979FF))),
            ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF2979FF)))
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGroupInfoSection(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 30, 20, 10),
                  child: Text("SELECT MEMBERS", style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
                _buildMembersList(),
              ],
            ),
          ),
    );
  }

  Widget _buildGroupInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF0A2540),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFF16233A),
                  backgroundImage: _groupImageBytes != null ? MemoryImage(_groupImageBytes!) : null,
                  child: _groupImageBytes == null ? const Icon(Icons.camera_alt_rounded, color: Colors.white38, size: 30) : null,
                ),
                if (_groupImageBytes != null)
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Color(0xFF2979FF), shape: BoxShape.circle),
                      child: const Icon(Icons.edit, size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: "Group Name",
                    hintStyle: TextStyle(color: Colors.white24),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2979FF))),
                  ),
                ),
                TextField(
                  controller: _descController,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: "Description (Optional)",
                    hintStyle: TextStyle(color: Colors.white24),
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList() {
    if (_contacts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text("No contacts to add. Add contacts first!", style: TextStyle(color: Colors.white24)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _contacts.length,
      itemBuilder: (context, index) {
        final user = _contacts[index];
        final bool isSelected = _selectedMembers.contains(user['username']);
        
        return ListTile(
          onTap: () => _toggleMember(user['username']),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF16233A),
            backgroundImage: user['profilePic'] != null ? NetworkImage(user['profilePic']) : null,
            child: user['profilePic'] == null ? const Icon(Icons.person, color: Colors.white24) : null,
          ),
          title: Text(user['username'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          trailing: Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF2979FF) : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? const Color(0xFF2979FF) : Colors.white10, width: 2),
            ),
            child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
          ),
        );
      },
    );
  }
}
