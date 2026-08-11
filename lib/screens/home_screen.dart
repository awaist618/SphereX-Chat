import 'package:flutter/material.dart';
import 'dart:ui';
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
import 'login_screen.dart';
import 'contact_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  String? _myUsername;
  RealtimeChannel? _globalSignalingChannel;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FocusNode _searchFocusNode = FocusNode();

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      HomeScreenContent(scaffoldKey: _scaffoldKey, searchFocusNode: _searchFocusNode),
      const ContactsScreen(),
      const NotificationsScreen(),
      const ProfileScreen(),
    ];
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
    _searchFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0A2540),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 50),
            // Improved Avatar Section
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF2979FF), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2979FF).withValues(alpha: 0.2),
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                ),
                const Icon(Icons.person, size: 60, color: Colors.white),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              _myUsername != null ? "@$_myUsername" : "User",
              style: const TextStyle(
                color: Colors.white, 
                fontSize: 22, 
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 60),
            // Menu Items
            _buildDrawerItem(Icons.settings_outlined, "Settings", () {}),
            const SizedBox(height: 10),
            _buildDrawerItem(Icons.privacy_tip_outlined, "Privacy", () {}),
            const SizedBox(height: 10),
            _buildDrawerItem(Icons.help_outline_rounded, "Help & Support", () {}),
            
            const Spacer(),
            
            // Logout Button at Bottom
            Padding(
              padding: const EdgeInsets.only(bottom: 30, left: 20),
              child: InkWell(
                onTap: () async {
                  await ApiService.logout();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginScreen()), 
                      (route) => false
                    );
                  }
                },
                child: const Row(
                  children: [
                    Icon(Icons.logout_rounded, color: Color(0xFFFF4C61), size: 24),
                    SizedBox(width: 15),
                    Text(
                      "Logout",
                      style: TextStyle(
                        color: Color(0xFFFF4C61), 
                        fontSize: 16, 
                        fontWeight: FontWeight.w700
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 30),
      leading: Icon(icon, color: Colors.white70, size: 24),
      title: Text(
        title, 
        style: const TextStyle(
          color: Colors.white, 
          fontSize: 16, 
          fontWeight: FontWeight.w500
        )
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      backgroundColor: const Color(0xFF0F1B2D),
      drawer: _buildDrawer(),
      body: _tabs[_selectedIndex],
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 25),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF0A2540).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(35),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(Icons.home_rounded, Icons.home_outlined, 0),
                  _buildNavItem(Icons.person_rounded, Icons.person_outline, 1),
                  _buildNavItem(Icons.notifications_rounded, Icons.notifications_none_rounded, 2),
                  _buildNavItem(Icons.account_circle_rounded, Icons.account_circle_outlined, 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData activeIcon, IconData inactiveIcon, int index) {
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2979FF).withValues(alpha: 0.1) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSelected ? activeIcon : inactiveIcon, 
                size: 26, 
                color: isSelected ? const Color(0xFF2979FF) : Colors.white38
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 4,
              width: isSelected ? 4 : 0,
              decoration: BoxDecoration(
                color: const Color(0xFF2979FF),
                shape: BoxShape.circle,
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: const Color(0xFF2979FF).withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )
                ] : [],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreenContent extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final FocusNode searchFocusNode;
  const HomeScreenContent({super.key, required this.scaffoldKey, required this.searchFocusNode});

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
        if (!mounted) return;
        final syncedConvs = await ApiService.getConversations(_myUsername!);
        if (mounted) {
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
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white70), 
            onPressed: () => widget.scaffoldKey.currentState?.openDrawer()
          ),
          Column(
            children: [
              const Text("SphereX", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              Text("Smart Communication", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white70), 
            onPressed: () => widget.searchFocusNode.requestFocus()
          ),
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
          focusNode: widget.searchFocusNode,
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
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 100),
      itemBuilder: (context, index) {
        final conv = _conversations[index];
        final otherUser = conv['_id'];
        final lastMsg = conv['lastMessage'] ?? "";
        final profilePic = conv['profilePic'];
        final isOnline = conv['isOnline'] ?? false;
        
        return Material(
          color: Colors.transparent,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (context) => ChatScreen(
                username: otherUser,
                groupId: conv['groupId'],
              )));
              _loadConversations();
            },
            leading: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: conv['isGroup'] == true ? const Color(0xFF2979FF).withValues(alpha: 0.3) : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 26, 
                    backgroundColor: const Color(0xFF16233A), 
                    backgroundImage: profilePic != null ? NetworkImage(profilePic) : null, 
                    child: profilePic == null 
                      ? Icon(conv['isGroup'] == true ? Icons.groups_rounded : Icons.person_rounded, color: Colors.white24, size: 28) 
                      : null
                  ),
                ),
                if (isOnline && conv['isGroup'] != true) Positioned(right: 2, bottom: 2, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: const Color(0xFF00C48C), shape: BoxShape.circle, border: Border.all(color: const Color(0xFF0F1B2D), width: 2)))),
              ],
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          otherUser, 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conv['isGroup'] == true) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFF2979FF).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                          child: const Text("GROUP", style: TextStyle(color: Color(0xFF2979FF), fontSize: 8, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(DateFormat('h:mm a').format(DateTime.parse(conv['timestamp'])), style: const TextStyle(color: Colors.white24, fontSize: 12)),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: const Color(0xFF16233A),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_off_rounded, size: 60, color: Colors.white.withValues(alpha: 0.1)),
            ),
            const SizedBox(height: 20),
            const Text(
              "No results found",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "We couldn't find anything matching \"${_searchController.text}\"",
              style: const TextStyle(color: Colors.white38, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 100),
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
    final displayName = user['name'] ?? username;
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF16233A), 
        backgroundImage: user['profilePic'] != null ? NetworkImage(user['profilePic']) : null, 
        child: user['profilePic'] == null ? const Icon(Icons.person, color: Colors.white) : null
      ),
      title: Text(displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text("@$username", style: const TextStyle(color: Colors.white38, fontSize: 12)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: user['relationship'] == 'contact' ? const Color(0xFF00C48C).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          user['relationship'] == 'contact' ? "Message" : "Profile",
          style: TextStyle(
            color: user['relationship'] == 'contact' ? const Color(0xFF00C48C) : Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.bold
          ),
        ),
      ),
      onTap: () {
        setState(() => _isSearching = false);
        if (user['relationship'] == 'contact') {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => ChatScreen(username: username)));
        } else {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => ContactProfileScreen(username: username)));
        }
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
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => ChatScreen(
          username: otherUser ?? "",
          groupId: msg['group_id'],
          targetMessageId: msg['id'].toString(),
        )));
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.chat_bubble_outline, size: 80, color: Colors.white.withValues(alpha: 0.1)), const SizedBox(height: 20), const Text("No Secure Chats Yet", style: TextStyle(color: Colors.white38, fontSize: 18))]));
  }
}
