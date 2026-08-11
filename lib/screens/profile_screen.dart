import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
        if (mounted) {
          setState(() {
            _username = name;
            _about = profile['about'] ?? "Available";
            _phone = profile['phone'] ?? "Not linked";
            _profilePicUrl = profile['profilePic'];
            _isLoading = false;
          });
        }
        return;
      }
    }
    if (mounted) {
      setState(() {
        _username = name;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null && _username != null) {
      setState(() => _isLoading = true);
      final bytes = await image.readAsBytes();
      final success = await ApiService.uploadProfilePic(_username!, bytes, image.name);
      if (success) {
        await _loadProfile();
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to upload image")));
        }
      }
    }
  }

  Future<void> _editField(String title, String currentValue, Function(String) onSave) async {
    final controller = TextEditingController(text: currentValue);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16233A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Edit $title", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Enter $title...",
            hintStyle: const TextStyle(color: Colors.white24),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2979FF))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            onPressed: () async {
              final newValue = controller.text.trim();
              if (newValue.isNotEmpty) {
                Navigator.pop(context);
                await onSave(newValue);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2979FF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text("Save"),
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
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update profile")));
      }
    }
  }

  Future<void> _changeUsername() async {
    if (_username == null) return;
    
    final controller = TextEditingController(text: _username);
    String? errorText;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF16233A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          title: const Text("Change Username", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Your username is your unique ID on SphereX. Changing it will update your profile across the platform.",
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  prefixText: "@",
                  prefixStyle: const TextStyle(color: Color(0xFF2979FF), fontWeight: FontWeight.bold),
                  labelText: "New Username",
                  labelStyle: const TextStyle(color: Colors.white38),
                  errorText: errorText,
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2979FF))),
                ),
                onChanged: (_) {
                  if (errorText != null) setDialogState(() => errorText = null);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white38))),
            ElevatedButton(
              onPressed: () async {
                final newName = controller.text.trim().toLowerCase();
                if (newName == _username) {
                  Navigator.pop(context);
                  return;
                }
                
                if (newName.length < 3) {
                  setDialogState(() => errorText = "Minimum 3 characters required");
                  return;
                }

                final available = await ApiService.isUsernameAvailable(newName);
                if (!available) {
                  setDialogState(() => errorText = "Username already taken");
                  return;
                }

                Navigator.pop(context);
                setState(() => _isLoading = true);
                
                final success = await ApiService.updateUsername(_username!, newName);
                if (success) {
                  await _loadProfile();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Username updated successfully!"), backgroundColor: Color(0xFF00C48C))
                    );
                  }
                } else {
                  setState(() => _isLoading = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Failed to update username"), backgroundColor: Color(0xFFFF4C61))
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2979FF), 
                foregroundColor: Colors.white, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ),
              child: const Text("Update"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16233A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text("Delete Account?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("This will permanently remove your account and all messages. This action cannot be undone.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.white38))),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Delete Account", style: TextStyle(color: Color(0xFFFF4C61), fontWeight: FontWeight.bold))
          ),
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
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete account")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2979FF)))
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle("Personal Information"),
                        const SizedBox(height: 15),
                        _buildSettingsCard([
                          _buildProfileTile(
                            Icons.alternate_email_rounded, 
                            "Username", 
                            "@${_username ?? 'user'}", 
                            _changeUsername
                          ),
                          _buildProfileTile(
                            Icons.info_outline, 
                            "About", 
                            _about, 
                            () => _editField("About", _about, (val) => _updateProfile(val, _phone))
                          ),
                          _buildProfileTile(
                            Icons.phone_outlined, 
                            "Phone", 
                            _phone, 
                            () => _editField("Phone", _phone, (val) => _updateProfile(_about, val))
                          ),
                        ]),
                        const SizedBox(height: 30),
                        _buildSectionTitle("Discovery"),
                        const SizedBox(height: 15),
                        _buildSettingsCard([
                          _buildProfileTile(Icons.qr_code_2_rounded, "My QR Code", "Share profile instantly", _showMyQRCode),
                        ]),
                        const SizedBox(height: 30),
                        _buildSectionTitle("Privacy & Security"),
                        const SizedBox(height: 15),
                        _buildSettingsCard([
                          _buildProfileTile(Icons.lock_outline, "Account Security", "E2E Encryption active", () {}),
                          _buildProfileTile(Icons.privacy_tip_outlined, "Privacy", "Manage visibility", () {}),
                        ]),
                        const SizedBox(height: 40),
                        _buildDangerZone(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: const Color(0xFF0A2540),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient Background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0A2540), Color(0xFF16233A), Color(0xFF0F1B2D)],
                ),
              ),
            ),
            // Header Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF2979FF).withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 5)
                          ],
                          gradient: const LinearGradient(colors: [Color(0xFF2979FF), Color(0xFF5B9CFF)]),
                        ),
                        child: CircleAvatar(
                          radius: 65,
                          backgroundColor: const Color(0xFF0F1B2D),
                          backgroundImage: _profilePicUrl != null ? NetworkImage(_profilePicUrl!) : null,
                          child: _profilePicUrl == null ? const Icon(Icons.person, size: 70, color: Colors.white24) : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickAndUploadImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2979FF), 
                              shape: BoxShape.circle, 
                              border: Border.all(color: const Color(0xFF0F1B2D), width: 3),
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _username ?? "User", 
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 0.5)
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF2979FF).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      "@${_username?.toLowerCase() ?? 'user'}", 
                      style: const TextStyle(color: Color(0xFF2979FF), fontSize: 13, fontWeight: FontWeight.w700)
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Color(0xFFFF4C61)),
          onPressed: () async {
            await ApiService.logout();
            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
          },
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 5),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(color: const Color(0xFF2979FF).withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16233A), 
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        children: tiles.asMap().entries.map((entry) {
          int idx = entry.key;
          Widget tile = entry.value;
          bool isLast = idx == tiles.length - 1;
          
          return Column(
            children: [
              tile,
              if (!isLast) Divider(color: Colors.white.withValues(alpha: 0.03), height: 1, indent: 60),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProfileTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10), 
        decoration: BoxDecoration(color: const Color(0xFF0F1B2D), borderRadius: BorderRadius.circular(12)), 
        child: Icon(icon, color: const Color(0xFF2979FF), size: 20)
      ),
      title: Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white12, size: 24),
    );
  }

  void _showMyQRCode() {
    if (_username == null) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A2540),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 25),
            const Text("Your SphereX ID", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("@$_username", style: const TextStyle(color: Color(0xFF2979FF), fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 35),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: const Color(0xFF2979FF).withValues(alpha: 0.2), blurRadius: 30)]
              ),
              child: QrImageView(
                data: "spherex:$_username",
                version: QrVersions.auto,
                size: 200.0,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0A2540)),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF0A2540)),
              ),
            ),
            const SizedBox(height: 35),
            const Text(
              "Friends can scan this QR code to find you instantly on SphereX Chat.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text("Share Profile"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2979FF),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZone() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4C61).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF4C61).withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4C61), size: 20),
              SizedBox(width: 10),
              Text("Danger Zone", style: TextStyle(color: Color(0xFFFF4C61), fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 15),
          const Text(
            "Deleting your account is permanent and will remove all your data across SphereX.",
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _confirmDelete,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4C61).withValues(alpha: 0.8), 
              foregroundColor: Colors.white, 
              minimumSize: const Size(double.infinity, 50), 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
              elevation: 0
            ),
            child: const Text("Delete My Account", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
