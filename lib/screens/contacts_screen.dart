import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _requests = [];
  bool _isSearching = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final requests = await ApiService.getContactRequests();
    setState(() {
      _requests = requests;
      _isLoading = false;
    });
  }

  void _handleSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await ApiService.searchUsers(query);
    setState(() => _searchResults = results);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      appBar: AppBar(
        title: const Text("Add Contact"),
        backgroundColor: const Color(0xFF0A2540),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF16233A),
                borderRadius: BorderRadius.circular(15),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _handleSearch,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Search name or @username",
                  hintStyle: TextStyle(color: Colors.white38),
                  prefixIcon: Icon(Icons.search, color: Colors.white38),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
          if (_requests.isNotEmpty && !_isSearching) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("Contact Requests", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final req = _requests[index];
                return ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFF2979FF), child: Icon(Icons.person, color: Colors.white)),
                  title: Text(req['sender'], style: const TextStyle(color: Colors.white)),
                  subtitle: const Text("wants to connect with you", style: TextStyle(color: Colors.white38)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Color(0xFF00C48C)),
                        onPressed: () async {
                          await ApiService.respondToRequest(req['sender'], 'accept');
                          _loadRequests();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Color(0xFFFF4C61)),
                        onPressed: () async {
                          await ApiService.respondToRequest(req['sender'], 'decline');
                          _loadRequests();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(color: Colors.white10, height: 40),
          ],
          Expanded(
            child: _isSearching 
              ? _buildSearchResults()
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_search, size: 80, color: Colors.white.withValues(alpha: 0.1)),
                      const SizedBox(height: 20),
                      const Text("Search for people by their\nusername", textAlign: TextAlign.center, style: TextStyle(color: Colors.white38)),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final relationship = user['relationship'];

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF16233A),
            backgroundImage: user['profilePic'] != null ? NetworkImage(user['profilePic']) : null,
            child: user['profilePic'] == null ? const Icon(Icons.person, color: Colors.white70) : null,
          ),
          title: Text(user['username'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text(user['about'] ?? "Available", style: const TextStyle(color: Colors.white38)),
          trailing: _buildActionButton(user),
          onTap: () => _showUserProfile(user),
        );
      },
    );
  }

  Widget _buildActionButton(Map<String, dynamic> user) {
    switch (user['relationship']) {
      case 'contact':
        return ElevatedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(username: user['username']))),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2979FF)),
          child: const Text("Message"),
        );
      case 'sent':
        return const Text("Request Sent", style: TextStyle(color: Colors.white38));
      case 'received':
        return const Text("Wants to Connect", style: TextStyle(color: Color(0xFF2979FF)));
      default:
        return ElevatedButton(
          onPressed: () async {
            await ApiService.sendContactRequest(user['username']);
            _handleSearch(_searchController.text);
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2979FF)),
          child: const Text("Add"),
        );
    }
  }

  void _showUserProfile(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16233A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFF0F1B2D),
              backgroundImage: user['profilePic'] != null ? NetworkImage(user['profilePic']) : null,
              child: user['profilePic'] == null ? const Icon(Icons.person, size: 50, color: Colors.white70) : null,
            ),
            const SizedBox(height: 20),
            Text(user['username'], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            if (user['isOnline'] == true)
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(radius: 5, backgroundColor: Color(0xFF00C48C)),
                  SizedBox(width: 8),
                  Text("Online", style: TextStyle(color: Color(0xFF00C48C))),
                ],
              ),
            const SizedBox(height: 15),
            Text(user['about'] ?? "Hey! I'm using SphereX Chat", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: _buildActionButton(user),
            ),
          ],
        ),
      ),
    );
  }
}
