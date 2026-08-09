import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _username;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final name = await ApiService.getUsername();
    setState(() {
      _username = name;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: const Color(0xFF161B33),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const Center(
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Color(0xFF7C4DFF),
                      child: Icon(Icons.person, size: 80, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _username ?? "Unknown User",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    "Secure & Encrypted ID",
                    style: TextStyle(color: Colors.white38),
                  ),
                  const SizedBox(height: 40),
                  _buildProfileTile(Icons.info_outline, "About", "Available"),
                  _buildProfileTile(Icons.phone_outlined, "Phone", "Not linked"),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () async {
                      await ApiService.logout();
                      if (!mounted) return;
                      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.1),
                      foregroundColor: Colors.redAccent,
                      minimumSize: const Size(double.infinity, 50),
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                    child: const Text("Delete Account"),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF7C4DFF)),
      title: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 16)),
      trailing: const Icon(Icons.edit, color: Colors.white24, size: 20),
    );
  }
}
