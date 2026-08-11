import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'chat_screen.dart';

class SharedMediaScreen extends StatefulWidget {
  final List<Map<String, dynamic>> messages;
  final String title;
  const SharedMediaScreen({super.key, required this.messages, required this.title});

  @override
  State<SharedMediaScreen> createState() => _SharedMediaScreenState();
}

class _SharedMediaScreenState extends State<SharedMediaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _images => widget.messages.where((m) => m['type'] == 'image').toList();
  List<Map<String, dynamic>> get _videos => widget.messages.where((m) => m['type'] == 'video_note').toList();
  List<Map<String, dynamic>> get _files => widget.messages.where((m) => m['type'] == 'file').toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0A2540),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF2979FF),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: "Photos"),
            Tab(text: "Videos"),
            Tab(text: "Files"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPhotosGrid(),
          _buildVideosGrid(),
          _buildFilesList(),
        ],
      ),
    );
  }

  Widget _buildPhotosGrid() {
    if (_images.isEmpty) return _buildEmptyState(Icons.image_outlined, "No shared photos");
    
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2,
      ),
      itemCount: _images.length,
      itemBuilder: (context, index) {
        final url = _images[index]['mediaUrl'];
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => FullScreenImageViewer(url: url, tag: url))),
          child: Hero(
            tag: url,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (c, u) => Container(color: Colors.white.withOpacity(0.05)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideosGrid() {
    if (_videos.isEmpty) return _buildEmptyState(Icons.videocam_outlined, "No shared videos");
    
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2,
      ),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final url = _videos[index]['mediaUrl'];
        return GestureDetector(
          onTap: () {}, // Could open video player
          child: Container(
            color: Colors.white.withOpacity(0.05),
            child: const Center(child: Icon(Icons.play_circle_outline, color: Colors.white38, size: 40)),
          ),
        );
      },
    );
  }

  Widget _buildFilesList() {
    if (_files.isEmpty) return _buildEmptyState(Icons.insert_drive_file_outlined, "No shared files");
    
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index];
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFF16233A),
            child: Icon(Icons.insert_drive_file, color: Color(0xFF2979FF)),
          ),
          title: Text(file['fileName'] ?? "Document", style: const TextStyle(color: Colors.white)),
          subtitle: Text(file['time'] ?? "", style: const TextStyle(color: Colors.white38, fontSize: 12)),
          trailing: const Icon(Icons.download_rounded, color: Colors.white24),
          onTap: () {},
        );
      },
    );
  }

  Widget _buildEmptyState(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 15),
          Text(text, style: const TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }
}
