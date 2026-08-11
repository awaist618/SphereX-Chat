import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
  List<Map<String, dynamic>> _suggestedUsers = [];
  bool _isSearching = false;
  bool _isLoading = true;
  bool _isSearchLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final results = await Future.wait([
      ApiService.getContactRequests(),
      ApiService.getSuggestedUsers(),
    ]);
    
    if (mounted) {
      setState(() {
        _requests = results[0] as List<Map<String, dynamic>>;
        _suggestedUsers = results[1] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRequests() async {
    final requests = await ApiService.getContactRequests();
    if (mounted) setState(() => _requests = requests);
  }

  void _handleSearch(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _isSearchLoading = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _isSearchLoading = true;
    });

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await ApiService.searchUsers(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearchLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      appBar: AppBar(
        title: const Text("Add Contact", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0A2540),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSearchHeader(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2979FF)))
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      if (_requests.isNotEmpty && !_isSearching) _buildRequestsSection(),
                      if (_isSearching) _buildSearchResults()
                      else ...[
                        if (_suggestedUsers.isNotEmpty) _buildSuggestedSection()
                        else _buildEmptyIllustration(),
                      ],
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF0A2540),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Find Connection", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF2979FF)),
                onPressed: _openScanner,
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF16233A),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _handleSearch,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Search name or @username",
                hintStyle: TextStyle(color: Colors.white38),
                prefixIcon: Icon(Icons.search, color: Color(0xFF2979FF)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text("Scan QR", style: TextStyle(color: Colors.white)),
          leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
        ),
        body: MobileScanner(
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              final String? code = barcode.rawValue;
              if (code != null && code.startsWith("spherex:")) {
                final String username = code.split(":").last;
                Navigator.pop(context);
                _handleSearch(username);
                _searchController.text = username;
                return;
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
          child: Row(
            children: [
              const Text("Contact Requests", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFFF4C61), borderRadius: BorderRadius.circular(10)),
                child: Text("${_requests.length}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _requests.length,
          itemBuilder: (context, index) {
            final req = _requests[index];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF16233A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF2979FF),
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(req['sender'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const Text("wants to connect", style: TextStyle(color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _buildRequestButton(Icons.check, const Color(0xFF00C48C), () async {
                        await ApiService.respondToRequest(req['sender'], 'accept');
                        _loadRequests();
                      }),
                      const SizedBox(width: 10),
                      _buildRequestButton(Icons.close, const Color(0xFFFF4C61), () async {
                        await ApiService.respondToRequest(req['sender'], 'decline');
                        _loadRequests();
                      }),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          child: Divider(color: Colors.white10),
        ),
      ],
    );
  }

  Widget _buildRequestButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildSuggestedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Text("Suggested Connections", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _suggestedUsers.length,
          itemBuilder: (context, index) {
            final user = _suggestedUsers[index];
            return _buildUserTile(user);
          },
        ),
      ],
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFF16233A),
            backgroundImage: user['profilePic'] != null ? NetworkImage(user['profilePic']) : null,
            child: user['profilePic'] == null ? const Icon(Icons.person, color: Colors.white70) : null,
          ),
          if (user['isOnline'] == true)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF00C48C),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0F1B2D), width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        user['name'] ?? user['username'], 
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
      ),
      subtitle: Text("@${user['username']}", style: const TextStyle(color: Colors.white38, fontSize: 13)),
      trailing: _buildActionButton(user),
      onTap: () => _showUserProfile(user),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearchLoading) {
      return const Column(
        children: [
          SizedBox(height: 100),
          Center(child: CircularProgressIndicator(color: Color(0xFF2979FF))),
          SizedBox(height: 20),
          Text("Searching...", style: TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 80),
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: const Color(0xFF16233A),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off_rounded, size: 60, color: Colors.white.withValues(alpha: 0.1)),
            ),
            const SizedBox(height: 20),
            const Text(
              "No user found",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "No account matches \"${_searchController.text}\"",
              style: const TextStyle(color: Colors.white38, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Text("Search Results", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _searchResults.length,
          itemBuilder: (context, index) {
            final user = _searchResults[index];
            return _buildUserTile(user);
          },
        ),
      ],
    );
  }

  Widget _buildActionButton(Map<String, dynamic> user) {
    switch (user['relationship']) {
      case 'contact':
        return ElevatedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(username: user['username']))),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2979FF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: const Text("Message"),
        );
      case 'sent':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
          child: const Text("Sent", style: TextStyle(color: Colors.white38, fontSize: 12)),
        );
      case 'received':
        return ElevatedButton(
          onPressed: () => _showUserProfile(user),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2979FF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: const Text("Review"),
        );
      default:
        return IconButton(
          icon: const Icon(Icons.person_add_alt_1, color: Color(0xFF2979FF)),
          onPressed: () async {
            await ApiService.sendContactRequest(user['username']);
            _handleSearch(_searchController.text);
          },
        );
    }
  }

  Widget _buildEmptyIllustration() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.person_search_rounded, size: 100, color: Colors.white.withValues(alpha: 0.05)),
          const SizedBox(height: 20),
          const Text("Search for people by @username", style: TextStyle(color: Colors.white38, fontSize: 14)),
          const Text("Connect with friends and start chatting", style: TextStyle(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }

  void _showUserProfile(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16233A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 30),
            CircleAvatar(
              radius: 60,
              backgroundColor: const Color(0xFF0F1B2D),
              backgroundImage: user['profilePic'] != null ? NetworkImage(user['profilePic']) : null,
              child: user['profilePic'] == null ? const Icon(Icons.person, size: 60, color: Colors.white70) : null,
            ),
            const SizedBox(height: 20),
            Text(user['username'], style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(radius: 4, backgroundColor: user['isOnline'] == true ? const Color(0xFF00C48C) : Colors.white24),
                const SizedBox(width: 8),
                Text(user['isOnline'] == true ? "Online" : "Offline", style: TextStyle(color: user['isOnline'] == true ? const Color(0xFF00C48C) : Colors.white38, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 25),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(15)),
              child: Text(user['about'] ?? "Hey! I'm using SphereX Chat. Let's turn our conversations into action!", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: _buildActionButton(user),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
