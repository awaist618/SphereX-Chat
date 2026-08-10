import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';
import 'call_screen.dart';
import '../features/calls/models/call_model.dart' as model;
import 'contacts_screen.dart';
import 'profile_screen.dart';
import 'tasks_screen.dart';
import 'groups_screen.dart';
import 'notifications_screen.dart';
import 'calls_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  String? _myUsername;
  RealtimeChannel? _globalSignalingChannel;

  final List<Widget> _tabs = [
    const HomeScreenContent(),
    const ContactsScreen(),
    const NotificationsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMyUsername();
  }

  void _loadMyUsername() async {
    _myUsername = await ApiService.getUsername();
    if (_myUsername != null) {
      ApiService.updateOnlineStatus(_myUsername!, true);
      _listenForCalls();
    }
  }

  void _listenForCalls() {
    if (_myUsername == null) return;
    _globalSignalingChannel = ApiService.getGlobalSignalingChannel(_myUsername!, (signal) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CallScreen(
              otherUsername: signal['caller_id'],
              type: signal['call_type'] == 'video' ? model.CallType.video : model.CallType.voice,
              isIncoming: true,
              callId: signal['call_id'],
              sdp: signal['sdp'],
              sdpType: signal['sdp_type'],
            ),
          ),
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_myUsername == null) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      ApiService.updateOnlineStatus(_myUsername!, false);
    } else if (state == AppLifecycleState.resumed) {
      ApiService.updateOnlineStatus(_myUsername!, true);
    }
  }

  @override
  void dispose() {
    if (_globalSignalingChannel != null) {
      Supabase.instance.client.removeChannel(_globalSignalingChannel!);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      body: _tabs[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: const Color(0xFF0A2540),
        selectedItemColor: const Color(0xFF2979FF),
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Contacts"),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_none), label: "Notifications"),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle_outlined), label: "Profile"),
        ],
      ),
    );
  }
}

class HomeScreenContent extends StatefulWidget {
  const HomeScreenContent({super.key});

  @override
  State<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent> {
  Map<String, List<Map<String, dynamic>>> _searchResults = {'users': [], 'groups': [], 'messages': []};
  List<Map<String, dynamic>> _conversations = [];
  bool _isSearching = false;
  bool _isLoading = true;
  final _searchController = TextEditingController();
  String? _myUsername;
  RealtimeChannel? _convChannel;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    _myUsername = await ApiService.getUsername();
    if (_myUsername != null) {
      await _loadConversations();
      _listenForUpdates();
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _listenForUpdates() {
    _convChannel = Supabase.instance.client
        .channel('public:conversations')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (payload) {
            _loadConversations();
          },
        )
        .subscribe();
  }

  Future<void> _loadConversations() async {
    if (_myUsername != null) {
      // 1. Initial Local Load
      final convs = await ApiService.getConversations(_myUsername!);
      if (mounted) {
        setState(() {
          _conversations = convs;
          _isLoading = false;
        });
      }

      // 2. Refresh after background sync
      Future.delayed(const Duration(seconds: 2), () async {
        if (mounted) {
          final syncedConvs = await ApiService.getConversations(_myUsername!);
          setState(() => _conversations = syncedConvs);
        }
      });
    }
  }

  @override
  void dispose() {
    if (_convChannel != null) {
      Supabase.instance.client.removeChannel(_convChannel!);
    }
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = {'users': [], 'groups': [], 'messages': []};
      });
      return;
    }
    setState(() => _isSearching = true);
    final results = await ApiService.globalSearch(query);
    setState(() => _searchResults = results);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          if (!_isSearching) _buildCategorySelector(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2979FF)))
              : _isSearching 
                ? _buildSearchResults()
                : _conversations.isEmpty 
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadConversations,
                      color: const Color(0xFF2979FF),
                      child: _buildConversationList(),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.menu, color: Colors.white70), onPressed: () {}),
          Column(
            children: [
              const Text("SphereX", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              Text("Smart Communication", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
            ],
          ),
          IconButton(icon: const Icon(Icons.search, color: Colors.white70), onPressed: () {}),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16233A), 
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _isSearching ? const Color(0xFF2979FF).withValues(alpha: 0.3) : Colors.transparent),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _handleSearch,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: "Search chats, users, groups...", 
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 15), 
            prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20), 
            suffixIcon: _searchController.text.isNotEmpty 
              ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.white38, size: 18), 
                  onPressed: () {
                    _searchController.clear();
                    _handleSearch("");
                  },
                )
              : null,
            border: InputBorder.none, 
            contentPadding: const EdgeInsets.symmetric(vertical: 12)
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    final categories = [
      {'name': 'Chats', 'icon': Icons.chat_bubble, 'screen': null},
      {'name': 'Groups', 'icon': Icons.groups, 'screen': const GroupsScreen()},
      {'name': 'Tasks', 'icon': Icons.assignment, 'screen': const TasksScreen()},
      {'name': 'Calls', 'icon': Icons.call, 'screen': const CallsHistoryScreen()},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: categories.map((cat) {
          bool isSelected = cat['name'] == 'Chats';
          return GestureDetector(
            onTap: () {
              if (cat['screen'] != null) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => cat['screen'] as Widget));
              }
            },
            child: Column(
              children: [
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(color: isSelected ? const Color(0xFF2979FF) : const Color(0xFF16233A), shape: BoxShape.circle),
                  child: Icon(cat['icon'] as IconData, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 8),
                Text(cat['name'] as String, style: TextStyle(color: isSelected ? Colors.white : Colors.white38, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildConversationList() {
    return ListView.builder(
      itemCount: _conversations.length,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      itemBuilder: (context, index) {
        final conv = _conversations[index];
        final otherUser = conv['_id'];
        final lastMsg = conv['lastMessage'] ?? "";
        final profilePic = conv['profilePic'];
        final isOnline = conv['isOnline'] ?? false;
        
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (context) => ChatScreen(username: otherUser)));
            _loadConversations();
          },
          leading: Stack(
            children: [
              CircleAvatar(radius: 28, backgroundColor: const Color(0xFF16233A), backgroundImage: profilePic != null ? NetworkImage(profilePic) : null, child: profilePic == null ? Text(otherUser[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20)) : null),
              if (isOnline) Positioned(right: 2, bottom: 2, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: const Color(0xFF00C48C), shape: BoxShape.circle, border: Border.all(color: const Color(0xFF0F1B2D), width: 2)))),
            ],
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(otherUser, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text(DateFormat('h:mm a').format(DateTime.parse(conv['timestamp'])), style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: (conv['unreadCount'] ?? 0) > 0 ? Colors.white : Colors.white38, fontSize: 14, fontWeight: (conv['unreadCount'] ?? 0) > 0 ? FontWeight.bold : FontWeight.normal))),
                if ((conv['unreadCount'] ?? 0) > 0) Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Color(0xFF2979FF), shape: BoxShape.circle), child: Text("${conv['unreadCount']}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    final users = _searchResults['users'] ?? [];
    final groups = _searchResults['groups'] ?? [];
    final messages = _searchResults['messages'] ?? [];

    if (users.isEmpty && groups.isEmpty && messages.isEmpty) {
      return const Center(child: Text("No results found", style: TextStyle(color: Colors.white38)));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      children: [
        if (users.isNotEmpty) ...[
          _buildSearchSectionHeader("People"),
          ...users.map((u) => _buildUserSearchResult(u)),
        ],
        if (groups.isNotEmpty) ...[
          _buildSearchSectionHeader("Groups"),
          ...groups.map((g) => _buildGroupSearchResult(g)),
        ],
        if (messages.isNotEmpty) ...[
          _buildSearchSectionHeader("Messages"),
          ...messages.map((m) => _buildMessageSearchResult(m)),
        ],
      ],
    );
  }

  Widget _buildSearchSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 25, 15, 12),
      child: Row(
        children: [
          Text(title.toUpperCase(), style: const TextStyle(color: Color(0xFF2979FF), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: const Color(0xFF2979FF).withValues(alpha: 0.1), thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildUserSearchResult(Map<String, dynamic> user) {
    final username = user['username'] as String;
    return ListTile(
      leading: CircleAvatar(backgroundColor: const Color(0xFF16233A), backgroundImage: user['profilePic'] != null ? NetworkImage(user['profilePic']) : null, child: user['profilePic'] == null ? const Icon(Icons.person, color: Colors.white) : null),
      title: Text(username, style: const TextStyle(color: Colors.white)),
      subtitle: Text(user['about'] ?? "Available", style: const TextStyle(color: Colors.white38, fontSize: 12)),
      onTap: () {
        setState(() => _isSearching = false);
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => ChatScreen(username: username)));
      },
    );
  }

  Widget _buildGroupSearchResult(Map<String, dynamic> group) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: const Color(0xFF16233A), backgroundImage: group['avatar_url'] != null ? NetworkImage(group['avatar_url']) : null, child: group['avatar_url'] == null ? const Icon(Icons.groups, color: Colors.white) : null),
      title: Text(group['name'], style: const TextStyle(color: Colors.white)),
      onTap: () {
        setState(() => _isSearching = false);
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => ChatScreen(username: group['name'], groupId: group['id'])));
      },
    );
  }

  Widget _buildMessageSearchResult(Map<String, dynamic> msg) {
    final bool isMe = msg['sender_id'] == _myUsername;
    final otherUser = isMe ? msg['receiver_id'] : msg['sender_id'];
    
    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: const Color(0xFF2979FF).withValues(alpha: 0.1),
        child: const Icon(Icons.message, color: Color(0xFF2979FF), size: 18),
      ),
      title: Text(otherUser ?? "Chat", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(msg['content'] ?? "", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      trailing: Text(DateFormat('MMM d').format(DateTime.parse(msg['created_at'])), style: const TextStyle(color: Colors.white24, fontSize: 10)),
      onTap: () {
        setState(() => _isSearching = false);
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => ChatScreen(username: otherUser ?? "")));
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.chat_bubble_outline, size: 80, color: Colors.white.withValues(alpha: 0.1)), const SizedBox(height: 20), const Text("No Secure Chats Yet", style: TextStyle(color: Colors.white38, fontSize: 18))]));
  }
}
