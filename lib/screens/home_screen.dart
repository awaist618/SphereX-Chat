import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildFilterChips(),
            Expanded(
              child: ListView.builder(
                itemCount: 10,
                padding: const EdgeInsets.only(top: 10),
                itemBuilder: (context, index) => _buildChatTile(index),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF7C4DFF),
        child: const Icon(Icons.add_comment_rounded, color: Colors.white),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "SphereX",
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.camera_alt_outlined, color: Colors.white70),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white70),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white10),
        ),
        child: const TextField(
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Ask AI or Search Securely",
            hintStyle: TextStyle(color: Colors.white38),
            prefixIcon: Icon(Icons.search, color: Color(0xFF7C4DFF)),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ["All", "Unread", "Favourites", "Groups"];
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemBuilder: (context, index) {
          final isSelected = index == 0;
          return Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF7C4DFF).withOpacity(0.2) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? const Color(0xFF7C4DFF) : Colors.white10,
              ),
            ),
            child: Center(
              child: Text(
                filters[index],
                style: TextStyle(
                  color: isSelected ? const Color(0xFF7C4DFF) : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatTile(int index) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: Stack(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.3), width: 2),
              gradient: const LinearGradient(
                colors: [Color(0xFF161B33), Color(0xFF0B1020)],
              ),
            ),
            child: const Icon(Icons.person, color: Colors.white24, size: 30),
          ),
          if (index % 3 == 0)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0B1020), width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "User ${index + 1}",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const Text(
            "12:45 PM",
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Row(
          children: [
            const Icon(Icons.done_all, color: Color(0xFF7C4DFF), size: 16),
            const SizedBox(width: 5),
            const Expanded(
              child: Text(
                "This is a highly secure end-to-end encrypted message.",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white60),
              ),
            ),
            if (index == 0)
              const Icon(Icons.push_pin, color: Colors.white30, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) => setState(() => _selectedIndex = index),
      backgroundColor: const Color(0xFF0B1020),
      selectedItemColor: const Color(0xFF7C4DFF),
      unselectedItemColor: Colors.white38,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: "Chats"),
        BottomNavigationBarItem(icon: Icon(Icons.update), label: "Updates"),
        BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), label: "Groups"),
        BottomNavigationBarItem(icon: Icon(Icons.call_outlined), label: "Calls"),
      ],
    );
  }
}
