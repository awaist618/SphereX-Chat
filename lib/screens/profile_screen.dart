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
  String _displayName = "User";
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
    final username = await ApiService.getUsername();
    if (username != null) {
      final profile = await ApiService.getProfile(username);
      if (profile != null) {
        if (mounted) {
          setState(() {
            _username = username;
            _displayName = profile['name'] ?? "User";
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
        _username = username;
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

  Future<void> _updateProfile({String? name, String? about, String? phone}) async {
    if (_username == null) return;
    setState(() => _isLoading = true);
    final success = await ApiService.updateProfile(
      _username!, 
      about ?? _about, 
      phone ?? _phone,
      name: name ?? _displayName
    );
    if (success) {
      await _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!"), backgroundColor: Color(0xFF00C48C))
        );
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Update failed. This phone number might be taken, or your name is too long."), 
            backgroundColor: Color(0xFFFF4C61)
          )
        );
      }
    }
  }

  Future<void> _changeUsername() async {
    if (_username == null) return;
    
    // Capture the root contexts before opening the dialog
    final outerContext = context;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    
    final controller = TextEditingController(text: _username);
    String? errorText;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
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
                onChanged: (value) {
                  if (errorText != null) setDialogState(() => errorText = null);
                  // Auto-lowercase in dialog
                  if (value != value.toLowerCase()) {
                    controller.value = controller.value.copyWith(
                      text: value.toLowerCase(),
                      selection: TextSelection.fromPosition(
                        TextPosition(offset: controller.selection.baseOffset),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel", style: TextStyle(color: Colors.white38))),
            ElevatedButton(
              onPressed: () async {
                final newName = controller.text.trim().toLowerCase();
                if (newName == _username) {
                  Navigator.pop(dialogContext);
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

                Navigator.pop(dialogContext);
                setState(() => _isLoading = true);
                
                final success = await ApiService.updateUsername(_username!, newName);
                if (success) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text("Username updated! Please login again."), backgroundColor: Color(0xFF00C48C))
                  );
                  await ApiService.logout();
                  navigator.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()), 
                    (route) => false
                  );
                } else {
                  if (mounted) setState(() => _isLoading = false);
                  messenger.showSnackBar(
                    const SnackBar(content: Text("Database Error: Run the provided SQL CASCADE script in Supabase."), backgroundColor: Color(0xFFFF4C61))
                  );
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
                            Icons.person_outline_rounded, 
                            "Display Name", 
                            _displayName, 
                            () => _editField("Display Name", _displayName, (val) => _updateProfile(name: val))
                          ),
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
                            () => _editField("About", _about, (val) => _updateProfile(about: val))
                          ),
                          _buildProfileTile(
                            Icons.phone_outlined, 
                            "Phone", 
                            _phone, 
                            () => _editField("Phone", _phone, (val) {
                              if (val.length != 11 || !RegExp(r'^[0-9]+$').hasMatch(val)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Phone number must be exactly 11 digits"), backgroundColor: Color(0xFFFF4C61))
                                );
                                return;
                              }
                              _updateProfile(phone: val);
                            })
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
      expandedHeight: 300,
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
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0A2540), Color(0xFF0F1B2D)],
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
                            BoxShadow(color: const Color(0xFF2979FF).withValues(alpha: 0.3), blurRadius: 25, spreadRadius: 5)
                          ],
                          border: Border.all(color: const Color(0xFF2979FF).withValues(alpha: 0.5), width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 70,
                          backgroundColor: const Color(0xFF16233A),
                          backgroundImage: _profilePicUrl != null ? NetworkImage(_profilePicUrl!) : null,
                          child: _profilePicUrl == null ? const Icon(Icons.person, size: 80, color: Colors.white10) : null,
                        ),
                      ),
                      Positioned(
                        bottom: 5,
                        right: 5,
                        child: GestureDetector(
                          onTap: _pickAndUploadImage,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2979FF), 
                              shape: BoxShape.circle, 
                              border: Border.all(color: const Color(0xFF0A2540), width: 3),
                              boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10)]
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _displayName, 
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 0.5)
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF2979FF).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      "@${_username ?? 'user'}", 
                      style: const TextStyle(color: Color(0xFF2979FF), fontSize: 14, fontWeight: FontWeight.w700)
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
      padding: const EdgeInsets.only(left: 10, bottom: 10),
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: tiles.asMap().entries.map((entry) {
            int idx = entry.key;
            Widget tile = entry.value;
            bool isLast = idx == tiles.length - 1;
            
            return Column(
              children: [
                tile,
                if (!isLast) Divider(color: Colors.white.withValues(alpha: 0.03), height: 1, indent: 65),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildProfileTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(12), 
        decoration: BoxDecoration(color: const Color(0xFF0F1B2D), borderRadius: BorderRadius.circular(15)), 
        child: Icon(icon, color: const Color(0xFF2979FF), size: 22)
      ),
      title: Text(title, style: const TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w500)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white12, size: 28),
    );
  }

  void _showMyQRCode() {
    if (_username == null) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A2540),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(35))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(35),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 30),
            const Text("Your SphereX ID", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("@$_username", style: const TextStyle(color: Color(0xFF2979FF), fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: const Color(0xFF2979FF).withValues(alpha: 0.2), blurRadius: 40)]
              ),
              child: QrImageView(
                data: "spherex:$_username",
                version: QrVersions.auto,
                size: 200.0,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0A2540)),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF0A2540)),
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              "Friends can scan this QR code to find you instantly on SphereX Chat.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.share_rounded, size: 20),
              label: const Text("Share Profile", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2979FF),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4C61).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFF4C61).withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4C61), size: 24),
              SizedBox(width: 12),
              Text("Danger Zone", style: TextStyle(color: Color(0xFFFF4C61), fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 15),
          const Text(
            "Deleting your account is permanent and will remove all your data across SphereX.",
            style: TextStyle(color: Colors.white38, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 25),
          ElevatedButton(
            onPressed: _confirmDelete,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4C61).withValues(alpha: 0.8), 
              foregroundColor: Colors.white, 
              minimumSize: const Size(double.infinity, 55), 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), 
              elevation: 0
            ),
            child: const Text("Delete My Account", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
