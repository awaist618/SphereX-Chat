import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _username;
  String _about = "Available";
  String _phone = "Not linked";
  String? _profilePicUrl;
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final name = await ApiService.getUsername();
    if (name != null) {
      final profile = await ApiService.getProfile(name);
      if (profile != null) {
        setState(() {
          _username = name;
          _about = profile['about'] ?? "Available";
          _phone = profile['phone'] ?? "Not linked";
          _profilePicUrl = profile['profilePic'];
          _isLoading = false;
        });
        return;
      }
    }
    setState(() {
      _username = name;
      _isLoading = false;
    });
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && _username != null) {
      setState(() => _isLoading = true);
      final bytes = await image.readAsBytes();
      final success = await ApiService.uploadProfilePic(_username!, bytes, image.name);
      if (success) {
        await _loadProfile();
      } else {
        setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to upload image")));
      }
    }
  }

  Future<void> _editField(String title, String currentValue, Function(String) onSave) async {
    final controller = TextEditingController(text: currentValue);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Edit $title", style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF7C4DFF))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white38))),
          TextButton(
            onPressed: () async {
              final newValue = controller.text.trim();
              if (newValue.isNotEmpty) {
                Navigator.pop(context);
                await onSave(newValue);
              }
            },
            child: const Text("Save", style: TextStyle(color: Color(0xFF7C4DFF))),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProfile(String about, String phone) async {
    if (_username == null) return;
    setState(() => _isLoading = true);
    final success = await ApiService.updateProfile(_username!, about, phone);
    if (success) {
      await _loadProfile();
    } else {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update profile")));
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Account?", style: TextStyle(color: Colors.white)),
        content: const Text("This will permanently remove your account and all messages. This action cannot be undone.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm == true && _username != null) {
      setState(() => _isLoading = true);
      final success = await ApiService.deleteAccount(_username!);
      if (success) {
        await ApiService.logout();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
      } else {
        setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete account")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0A2540),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2979FF)))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  _buildProfileHeader(),
                  const SizedBox(height: 40),
                  _buildSettingsSection(),
                  const SizedBox(height: 40),
                  _buildDangerZone(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Color(0xFF2979FF), shape: BoxShape.circle),
                child: CircleAvatar(
                  radius: 70,
                  backgroundColor: const Color(0xFF16233A),
                  backgroundImage: _profilePicUrl != null ? NetworkImage(_profilePicUrl!) : null,
                  child: _profilePicUrl == null ? const Icon(Icons.person, size: 80, color: Colors.white24) : null,
                ),
              ),
              Positioned(
                bottom: 5,
                right: 5,
                child: GestureDetector(
                  onTap: _pickAndUploadImage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF2979FF), shape: BoxShape.circle, border: Border.all(color: const Color(0xFF0F1B2D), width: 3)),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(_username ?? "User", style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
          const Text("SphereX Secured ID", style: TextStyle(color: Color(0xFF2979FF), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF16233A), borderRadius: BorderRadius.circular(25)),
      child: Column(
        children: [
          _buildProfileTile(Icons.info_outline, "About", _about, () => _editField("About", _about, (val) => _updateProfile(val, _phone))),
          Divider(color: Colors.white.withValues(alpha: 0.05), height: 1, indent: 60),
          _buildProfileTile(Icons.phone_outlined, "Phone", _phone, () => _editField("Phone", _phone, (val) => _updateProfile(_about, val))),
          Divider(color: Colors.white.withValues(alpha: 0.05), height: 1, indent: 60),
          _buildProfileTile(Icons.lock_outline, "Security", "Encryption active", () {}),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.only(left: 10, bottom: 10), child: Text("Account Actions", style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold))),
        ElevatedButton(
          onPressed: () async {
            await ApiService.logout();
            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16233A), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0),
          child: const Row(children: [Icon(Icons.logout, color: Color(0xFFFF4C61)), SizedBox(width: 15), Text("Logout", style: TextStyle(fontWeight: FontWeight.bold))]),
        ),
        const SizedBox(height: 15),
        ElevatedButton(
          onPressed: _confirmDelete,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4C61).withValues(alpha: 0.1), foregroundColor: const Color(0xFFFF4C61), minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), side: const BorderSide(color: Color(0xFFFF4C61), width: 0.5), elevation: 0),
          child: const Row(children: [Icon(Icons.delete_outline), SizedBox(width: 15), Text("Delete Account", style: TextStyle(fontWeight: FontWeight.bold))]),
        ),
      ],
    );
  }

  Widget _buildProfileTile(IconData icon, String title, String subtitle, VoidCallback onEdit) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF0F1B2D), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: const Color(0xFF2979FF), size: 22)),
      title: Text(title, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      trailing: IconButton(icon: const Icon(Icons.edit, color: Colors.white10, size: 18), onPressed: onEdit),
    );
  }
}
