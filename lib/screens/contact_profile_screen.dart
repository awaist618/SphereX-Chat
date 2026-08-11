import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class ContactProfileScreen extends StatefulWidget {
  final String username;
  const ContactProfileScreen({super.key, required this.username});

  @override
  State<ContactProfileScreen> createState() => _ContactProfileScreenState();
}

class _ContactProfileScreenState extends State<ContactProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final data = await ApiService.getProfile(widget.username);
    if (mounted) {
      setState(() {
        _profile = data;
        _isLoading = false;
      });
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
                _buildAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusIndicator(),
                        const SizedBox(height: 25),
                        _buildSectionTitle("About"),
                        const SizedBox(height: 12),
                        _buildInfoCard(_profile?['about'] ?? "Hey! I'm using SphereX Chat."),
                        const SizedBox(height: 30),
                        _buildSectionTitle("Quick Actions"),
                        const SizedBox(height: 15),
                        _buildActionButtons(),
                        const SizedBox(height: 35),
                        _buildSectionTitle("Shared Media"),
                        const SizedBox(height: 15),
                        _buildMediaPreview(),
                        const SizedBox(height: 40),
                        _buildPrivacyActions(),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 350,
      pinned: true,
      backgroundColor: const Color(0xFF0A2540),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.username,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            shadows: [Shadow(color: Colors.black54, blurRadius: 15)],
            letterSpacing: 0.5
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (_profile?['profilePic'] != null)
              Image.network(_profile!['profilePic'], fit: BoxFit.cover)
            else
              Container(
                color: const Color(0xFF16233A),
                child: Center(
                  child: Icon(Icons.person, size: 120, color: Colors.white.withValues(alpha: 0.05)),
                ),
              ),
            // Gradient Overlays
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black26, Colors.transparent, Color(0xFF0F1B2D)],
                  stops: [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildStatusIndicator() {
    final bool isOnline = _profile?['isOnline'] ?? false;
    final String lastSeen = _profile?['lastSeen'] != null 
        ? "Last seen ${DateFormat('MMM d, h:mm a').format(DateTime.parse(_profile!['lastSeen']).toLocal())}" 
        : "Offline";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isOnline ? const Color(0xFF00C48C).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isOnline ? const Color(0xFF00C48C).withValues(alpha: 0.2) : Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isOnline ? const Color(0xFF00C48C) : Colors.white24,
              shape: BoxShape.circle,
              boxShadow: isOnline ? [BoxShadow(color: const Color(0xFF00C48C).withValues(alpha: 0.4), blurRadius: 6)] : [],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isOnline ? "Online Now" : lastSeen,
            style: TextStyle(
              color: isOnline ? const Color(0xFF00C48C) : Colors.white38,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16233A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.6, letterSpacing: 0.2),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            label: "Message",
            icon: Icons.chat_bubble_rounded,
            color: const Color(0xFF2979FF),
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ChatScreen(username: widget.username))),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildActionButton(
            label: "Voice Call",
            icon: Icons.phone_rounded,
            color: const Color(0xFF16233A),
            textColor: const Color(0xFF2979FF),
            onTap: () {},
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildActionButton(
            label: "Video",
            icon: Icons.videocam_rounded,
            color: const Color(0xFF16233A),
            textColor: const Color(0xFF2979FF),
            onTap: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Privacy & Safety"),
        const SizedBox(height: 15),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF16233A),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              _buildSettingsTile(
                icon: Icons.block_flipped,
                title: "Block @${widget.username}",
                subtitle: "Prevent any further communication",
                color: const Color(0xFFFF4C61),
                onTap: _showBlockConfirmation,
              ),
              Divider(color: Colors.white.withValues(alpha: 0.03), height: 1, indent: 60),
              _buildSettingsTile(
                icon: Icons.report_gmailerrorred_rounded,
                title: "Report User",
                subtitle: "Send a report to our safety team",
                color: const Color(0xFFFF4C61),
                onTap: _showReportDialog,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({required IconData icon, required String title, String? subtitle, required Color color, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: color.withValues(alpha: 0.5), fontSize: 12)) : null,
      trailing: Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.3), size: 20),
    );
  }

  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16233A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Block User?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text("You will no longer receive messages from @${widget.username}.", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white38))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ApiService.blockUser(widget.username);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("@${widget.username} blocked"), backgroundColor: const Color(0xFFFF4C61)));
                Navigator.pop(context);
              }
            },
            child: const Text("Block", style: TextStyle(color: Color(0xFFFF4C61), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16233A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Report User", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Reason for reporting...",
            hintStyle: TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2979FF))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context);
              final success = await ApiService.reportUser(widget.username, controller.text.trim());
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Report submitted. Thank you."), backgroundColor: Color(0xFF00C48C)));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2979FF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label, 
    required IconData icon, 
    required Color color, 
    required VoidCallback onTap,
    Color textColor = Colors.white,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: color == const Color(0xFF2979FF) ? [
              BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 5))
            ] : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: textColor, size: 26),
              const SizedBox(height: 8),
              Text(
                label, 
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPreview() {
    return Container(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: 5,
        itemBuilder: (context, index) => Container(
          width: 120,
          margin: const EdgeInsets.only(right: 15),
          decoration: BoxDecoration(
            color: const Color(0xFF16233A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Center(
            child: Icon(Icons.perm_media_rounded, color: Colors.white.withValues(alpha: 0.05), size: 40),
          ),
        ),
      ),
    );
  }
}
