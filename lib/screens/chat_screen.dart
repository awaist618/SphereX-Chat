import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:uuid/uuid.dart';
import 'package:open_filex/open_filex.dart';
import 'package:file_picker/file_picker.dart';
import '../features/calls/models/call_model.dart' as model;
import '../services/api_service.dart';
import 'call_screen.dart';
import 'contact_profile_screen.dart';
import 'group_details_screen.dart';

class ChatScreen extends StatefulWidget {
  final String username;
  final String? groupId;
  final String? targetMessageId;
  const ChatScreen({super.key, required this.username, this.groupId, this.targetMessageId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  String? _myUsername;
  String? _otherUserProfilePic;
  bool _isOnline = false;
  String _lastSeen = "";
  int _memberCount = 0;
  bool _showEmoji = false;
  bool _isOtherTyping = false;
  String? _typingUserName;
  Timer? _typingTimer;
  RealtimeChannel? _messageChannel;
  RealtimeChannel? _statusChannel;
  RealtimeChannel? _typingChannel;
  RealtimeChannel? _reactionChannel;
  final ImagePicker _picker = ImagePicker();
  final Dio _dio = Dio();
  final Map<String, double> _downloadProgress = {};
  
  Map<String, dynamic>? _replyingTo;
  String? _highlightedMessageId;

  // Audio Recording
  late AudioRecorder _recorder;
  bool _isRecording = false;
  Timer? _recordTimer;
  int _recordDuration = 0;

  @override
  void initState() {
    super.initState();
    _recorder = AudioRecorder();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _myUsername = await ApiService.getUsername();
    if (_myUsername != null) {
      if (widget.groupId != null) {
        _memberCount = await ApiService.getGroupMemberCount(widget.groupId!);
      }
      await ApiService.markMessagesAsRead(_myUsername!, widget.username);
      await _fetchMessages();
      await _fetchOtherUserProfile();
      _subscribeToMessages();
      _subscribeToStatus();
      _subscribeToTyping();
      _subscribeToReactions();
      _updateMyStatus(true);
      
      if (widget.targetMessageId != null) {
        _jumpToMessage(widget.targetMessageId!);
      } else {
        _scrollToBottom();
      }
    }
  }

  void _jumpToMessage(String messageId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final index = _messages.indexWhere((m) => m['id'].toString() == messageId);
      if (index != -1) {
        // Use a more precise scroll logic if possible, but for now scroll to index * approximate height
        // or just scroll to the middle of the list if precise measurement is hard.
        // Better: Find the context of the message bubble if using GlobalKeys, 
        // but for now let's just scroll to bottom + animation.
        setState(() => _highlightedMessageId = messageId);
        
        // Approximate position
        double position = index * 100.0; // Assume average height
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            position,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }

        // Clear highlight after 2 seconds
        Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _highlightedMessageId = null);
        });
      }
    });
  }

  void _updateMyStatus(bool online) async {
    if (_myUsername != null) {
      await ApiService.updateOnlineStatus(_myUsername!, online);
    }
  }

  void _subscribeToMessages() {
    _messageChannel = ApiService.getMessageChannel(_myUsername!, widget.username, (newMessage) {
      if (!mounted) return;
      
      if (widget.groupId == null && newMessage['receiver_id'] == _myUsername && newMessage['is_read'] == false) {
        ApiService.markMessagesAsRead(_myUsername!, widget.username);
      }

      final newId = newMessage['id'];
      final String content = newMessage['content'] ?? "";
      
      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == newId);
        
        if (index != -1) {
          _messages[index]['text'] = content;
          _messages[index]['is_read'] = newMessage['is_read'];
          _messages[index]['is_edited'] = newMessage['is_edited'] ?? false;
        } else {
          _messages.removeWhere((m) => 
            (m['id'].toString().startsWith('temp_') && m['text'] == content) ||
            (m['id'].toString().startsWith('temp_') && newMessage['sender_id'] == _myUsername)
          );

          _messages.add({
            'id': newId,
            'text': content,
            'mediaUrl': newMessage['file_url'],
            'type': newMessage['type'] ?? 'text',
            'isMe': newMessage['sender_id'] == _myUsername,
            'senderName': newMessage['sender_id'],
            'is_read': newMessage['is_read'] ?? false,
            'is_edited': newMessage['is_edited'] ?? false,
            'reply_to': newMessage['reply_to'],
            'time': _formatTimestamp(newMessage['created_at']),
            'reactions': [],
          });
          _scrollToBottom();
        }
      });
    }, groupId: widget.groupId);
  }

  void _subscribeToStatus() {
    if (widget.groupId != null) return;
    _statusChannel = ApiService.getStatusChannel(widget.username, (profile) {
      if (mounted) {
        setState(() {
          _isOnline = profile['is_online'] ?? false;
          _lastSeen = _formatLastSeen(profile['last_seen']);
        });
      }
    });
  }

  void _subscribeToTyping() {
    _typingChannel = ApiService.getTypingChannel(_myUsername!, widget.username, (signal) {
      if (!mounted) return;
      bool isRelevant = false;
      if (widget.groupId != null) {
        isRelevant = signal['group_id'] == widget.groupId && signal['sender_id'] != _myUsername;
      } else {
        isRelevant = signal['sender_id'] == widget.username && signal['receiver_id'] == _myUsername;
      }

      if (isRelevant) {
        setState(() {
          _isOtherTyping = signal['content'] == 'typing';
          _typingUserName = _isOtherTyping ? signal['sender_id'] : null;
          
          if (widget.groupId != null && !_isOtherTyping) {
            _typingUserName = null;
          }
        });
      }
    }, groupId: widget.groupId);
  }

  void _subscribeToReactions() {
    _reactionChannel = Supabase.instance.client
        .channel('reactions')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'message_reactions',
          callback: (payload) {
            _fetchMessages();
          },
        )
        .subscribe();
  }

  void _onTyping() {
    if (_myUsername == null) return;
    ApiService.sendTypingStatus(_myUsername!, widget.username, true, groupId: widget.groupId);
    
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      ApiService.sendTypingStatus(_myUsername!, widget.username, false, groupId: widget.groupId);
    });
  }

  Future<void> _fetchOtherUserProfile() async {
    final profile = await ApiService.getProfile(widget.username);
    if (profile != null && mounted) {
      setState(() {
        _otherUserProfilePic = profile['profilePic'];
        _isOnline = profile['isOnline'] ?? false;
        _lastSeen = _formatLastSeen(profile['lastSeen']);
      });
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return "now";
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      return DateFormat('h:mm a').format(dt);
    } catch (e) {
      return "now";
    }
  }

  String _formatLastSeen(String? timestamp) {
    if (timestamp == null) return "";
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return "Just now";
      if (diff.inHours < 1) return "${diff.inMinutes}m ago";
      if (diff.inDays < 1) return "Today at ${DateFormat('h:mm a').format(dt)}";
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (e) {
      return "";
    }
  }

  @override
  void dispose() {
    _updateMyStatus(false);
    _typingTimer?.cancel();
    _recordTimer?.cancel();
    _recorder.dispose();
    if (_messageChannel != null) Supabase.instance.client.removeChannel(_messageChannel!);
    if (_statusChannel != null) Supabase.instance.client.removeChannel(_statusChannel!);
    if (_typingChannel != null) Supabase.instance.client.removeChannel(_typingChannel!);
    if (_reactionChannel != null) Supabase.instance.client.removeChannel(_reactionChannel!);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    if (_myUsername == null) return;
    
    // 1. Initial Load (Fast)
    final messages = await ApiService.getMessages(_myUsername!, widget.username, groupId: widget.groupId);
    await _displayMessages(messages);

    // 2. The sync happened in background inside ApiService.getMessages.
    // We can fetch again after a short delay or rely on Realtime.
    // For a professional feel, we'll do one more fetch to ensure consistency.
    Future.delayed(const Duration(seconds: 1), () async {
      if (mounted) {
        final syncedMessages = await ApiService.getMessages(_myUsername!, widget.username, groupId: widget.groupId);
        await _displayMessages(syncedMessages);
      }
    });
  }

  Future<void> _displayMessages(List<Map<String, dynamic>> messages) async {
    List<Map<String, dynamic>> enrichedMessages = [];
    for (var m in messages) {
      final reactions = await ApiService.getReactions(m['id']);
      enrichedMessages.add({
        ...m,
        'time': _formatTimestamp(m['timestamp']),
        'reactions': reactions,
        'isMe': m['sender'] == _myUsername,
      });
    }

    if (mounted) {
      setState(() {
        _messages = enrichedMessages;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage({String type = 'text', XFile? mediaFile, String? audioPath}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && mediaFile == null && audioPath == null) return;
    if (_myUsername == null) return;
    
    final replyId = _replyingTo?['id'];
    
    _messageController.clear();
    setState(() {
      _showEmoji = false;
      _replyingTo = null;
    });
    ApiService.sendTypingStatus(_myUsername!, widget.username, false);
    
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _messages.add({
        'id': tempId,
        'text': text,
        'type': type,
        'mediaUrl': mediaFile?.path ?? audioPath,
        'isMe': true,
        'is_read': false,
        'reply_to': replyId,
        'time': DateFormat('h:mm a').format(DateTime.now()),
        'reactions': [],
      });
    });
    _scrollToBottom();

    bool success;
    if (audioPath != null) {
      final bytes = await File(audioPath).readAsBytes();
      success = await ApiService.sendMessage(
        _myUsername!, 
        widget.username, 
        "", 
        fileBytes: bytes, 
        fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a', 
        type: 'audio',
        replyTo: replyId,
        groupId: widget.groupId
      );
    } else if (mediaFile != null) {
      final bytes = await mediaFile.readAsBytes();
      success = await ApiService.sendMessage(
        _myUsername!, 
        widget.username, 
        text, 
        fileBytes: bytes, 
        fileName: mediaFile.name, 
        type: type,
        replyTo: replyId,
        groupId: widget.groupId
      );
    } else {
      success = await ApiService.sendMessage(
        _myUsername!, 
        widget.username, 
        text,
        replyTo: replyId,
        groupId: widget.groupId
      );
    }

    if (!success) {
      setState(() => _messages.removeWhere((m) => m['id'] == tempId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send message')));
      }
    }
  }

  void _editMessage(String id, String oldText) {
    final controller = TextEditingController(text: oldText);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16233A),
        title: const Text("Edit Message", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(border: UnderlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              final newText = controller.text.trim();
              if (newText.isNotEmpty && newText != oldText) {
                await ApiService.editMessage(id, newText);
                _fetchMessages();
              }
              Navigator.pop(context);
            },
            child: const Text("Save", style: TextStyle(color: Color(0xFF2979FF))),
          ),
        ],
      ),
    );
  }

  void _deleteMessage(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16233A),
        title: const Text("Delete Message?", style: TextStyle(color: Colors.white)),
        content: const Text("This message will be removed for everyone.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.deleteMessage(id);
      _fetchMessages();
    }
  }

  void _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/${const Uuid().v4()}.m4a';
        
        // Improved configuration for louder and clearer recording
        const config = RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          autoGain: true, // Enable automatic gain control for louder voice
          androidConfig: AndroidRecordConfig(
            audioSource: AndroidAudioSource.voiceCommunication, // Optimized for speech volume
          ),
        );
        
        await _recorder.start(config, path: path);
        
        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });
        
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordDuration++;
          });
        });
        debugPrint('Voice recording started at $path');
      }
    } catch (e) {
      debugPrint('Start recording error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start recording: $e'))
        );
      }
    }
  }

  void _stopRecording() async {
    if (!_isRecording) return;
    
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    
    // Check if recording was at least 1 second long
    final bool isValid = _recordDuration >= 1;
    
    setState(() {
      _isRecording = false;
    });
    
    if (path != null && isValid) {
      debugPrint('Recording finished: $path');
      _sendMessage(type: 'audio', audioPath: path);
    } else if (!isValid) {
      debugPrint('Recording discarded: too short');
    }
  }

  void _pickMedia() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16233A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAttachItem(
                icon: Icons.image_rounded, 
                color: Colors.purpleAccent, 
                label: "Gallery", 
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                  if (file != null) _sendMessage(type: 'image', mediaFile: file);
                }
              ),
              _buildAttachItem(
                icon: Icons.camera_alt_rounded, 
                color: Colors.orangeAccent, 
                label: "Camera", 
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                  if (file != null) _sendMessage(type: 'image', mediaFile: file);
                }
              ),
              _buildAttachItem(
                icon: Icons.insert_drive_file_rounded, 
                color: const Color(0xFF2979FF), 
                label: "Document", 
                onTap: () async {
                  Navigator.pop(context);
                  FilePickerResult? result = await FilePicker.pickFiles();
                  if (result != null && result.files.single.path != null) {
                    _sendFile(result.files.single);
                  }
                }
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendFile(PlatformFile file) async {
    if (_myUsername == null) return;
    
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _messages.add({
        'id': tempId,
        'text': "",
        'type': 'file',
        'mediaUrl': file.path,
        'fileName': file.name,
        'fileSize': file.size,
        'isMe': true,
        'is_read': false,
        'time': DateFormat('h:mm a').format(DateTime.now()),
        'reactions': [],
      });
    });
    _scrollToBottom();

    final bytes = await File(file.path!).readAsBytes();
    final success = await ApiService.sendMessage(
      _myUsername!, 
      widget.username, 
      "", 
      fileBytes: bytes, 
      fileName: file.name, 
      type: 'file',
      groupId: widget.groupId
    );

    if (!success) {
      setState(() => _messages.removeWhere((m) => m['id'] == tempId));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send file')));
    }
  }

  Widget _buildAttachItem({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _downloadFile(String url, String fileName) async {
    try {
      final status = await _getDownloadDirectory();
      if (status == null) return;
      final savePath = '${status.path}/$fileName';
      setState(() => _downloadProgress[url] = 0);
      await _dio.download(url, savePath, onReceiveProgress: (received, total) {
        if (total != -1) setState(() => _downloadProgress[url] = received / total);
      });
      setState(() => _downloadProgress.remove(url));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloaded to: $savePath'), backgroundColor: const Color(0xFF00C48C)));
    } catch (e) {
      setState(() => _downloadProgress.remove(url));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download failed'), backgroundColor: Color(0xFFFF4C61)));
    }
  }

  Future<Directory?> _getDownloadDirectory() async {
    if (Platform.isAndroid) return Directory('/storage/emulated/0/Download');
    return await getApplicationDocumentsDirectory();
  }

  void _createTaskFromMessage(Map<String, dynamic> message) async {
    final titleController = TextEditingController(text: message['text']);
    String assignedTo = _myUsername ?? "";
    DateTime? dueDate;
    List<String> assignableUsers = [_myUsername ?? ""];
    
    if (widget.groupId != null) {
      final members = await ApiService.getGroupMembers(widget.groupId!);
      assignableUsers = members.map((m) => m['username'] as String).toList();
    } else {
      assignableUsers.add(widget.username);
    }
    
    if (!assignableUsers.contains(assignedTo) && assignableUsers.isNotEmpty) {
      assignedTo = assignableUsers.first;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF16233A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Create Task", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Task Title", style: TextStyle(color: Colors.white70, fontSize: 12)),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Enter task title...",
                    hintStyle: TextStyle(color: Colors.white24),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Assign To", style: TextStyle(color: Colors.white70, fontSize: 12)),
                DropdownButton<String>(
                  value: assignedTo,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF16233A),
                  underline: Container(height: 1, color: Colors.white10),
                  items: assignableUsers.map((u) => DropdownMenuItem(
                    value: u, 
                    child: Text(u == _myUsername ? "Me (@$u)" : "@$u", style: const TextStyle(color: Colors.white))
                  )).toList(),
                  onChanged: (val) => setDialogState(() => assignedTo = val!),
                ),
                const SizedBox(height: 20),
                const Text("Due Date", style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Color(0xFF2979FF),
                              onPrimary: Colors.white,
                              surface: Color(0xFF16233A),
                              onSurface: Colors.white,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) setDialogState(() => dueDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Color(0xFF2979FF), size: 18),
                        const SizedBox(width: 10),
                        Text(
                          dueDate == null ? "Select Due Date" : DateFormat('MMM d, yyyy').format(dueDate!),
                          style: TextStyle(color: dueDate == null ? Colors.white24 : Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text("Cancel", style: TextStyle(color: Colors.white38))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2979FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                
                final success = await ApiService.createTask(
                  title: titleController.text.trim(),
                  assignedTo: assignedTo,
                  dueDate: dueDate,
                  sourceMessageId: message['id'],
                  conversationId: widget.groupId == null ? ApiService.getConversationId(_myUsername!, widget.username) : null,
                  groupId: widget.groupId
                );
                if (success) {
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Task created successfully!"),
                      backgroundColor: Color(0xFF00C48C),
                    )
                  );
                }
              },
              child: const Text("Create Task"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_showEmoji,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _showEmoji) setState(() => _showEmoji = false);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1B2D),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A2540),
          elevation: 8,
          shadowColor: Colors.black45,
          leadingWidth: 40,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20), 
            onPressed: () => Navigator.pop(context)
          ),
          title: InkWell(
            onTap: () {
              if (widget.groupId != null) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => GroupDetailsScreen(groupId: widget.groupId!, groupName: widget.username)));
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ContactProfileScreen(username: widget.username)));
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _isOnline ? const Color(0xFF00C48C) : Colors.white10, width: 1),
                        ),
                        child: CircleAvatar(
                          radius: 18, 
                          backgroundColor: Colors.white10, 
                          backgroundImage: _otherUserProfilePic != null ? NetworkImage(_otherUserProfilePic!) : null, 
                          child: _otherUserProfilePic == null ? const Icon(Icons.person, color: Colors.white, size: 20) : null
                        ),
                      ),
                      if (_isOnline)
                        Positioned(
                          right: 1, 
                          bottom: 1, 
                          child: Container(
                            width: 10, height: 10, 
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C48C), 
                              shape: BoxShape.circle, 
                              border: Border.all(color: const Color(0xFF0A2540), width: 2)
                            )
                          )
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.username, 
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isOtherTyping)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: TypingIndicatorAnimation(),
                              ),
                            Flexible(
                              child: Text(
                                _isOtherTyping 
                                  ? (widget.groupId != null ? "$_typingUserName is typing..." : "typing...")
                                  : (widget.groupId != null ? "$_memberCount members" : (_isOnline ? "Online" : (_lastSeen.isEmpty ? "Offline" : "Last seen $_lastSeen"))),
                                style: TextStyle(
                                  fontSize: 11, 
                                  color: _isOtherTyping || _isOnline ? const Color(0xFF00C48C) : Colors.white54, 
                                  fontWeight: _isOtherTyping || _isOnline ? FontWeight.w600 : FontWeight.normal
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF2979FF), size: 20), 
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (context) => CallScreen(
                  otherUsername: widget.username,
                  otherProfilePic: _otherUserProfilePic,
                  type: model.CallType.voice,
                )
              )),
            ),
            IconButton(
              icon: const Icon(Icons.videocam_rounded, color: Color(0xFF2979FF), size: 24), 
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (context) => CallScreen(
                  otherUsername: widget.username,
                  otherProfilePic: _otherUserProfilePic,
                  type: model.CallType.video,
                )
              )),
            ),
            IconButton(icon: const Icon(Icons.more_vert_rounded, color: Colors.white70), onPressed: () {}),
          ],
        ),
        body: Container(
          color: const Color(0xFF0F1B2D),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
                ),
              ),
              if (_replyingTo != null) _buildReplyPreview(),
              _buildBottomComposer(),
              if (_showEmoji) _buildEmojiPicker(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomComposer() {
    final bool hasText = _messageController.text.trim().isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 15),
      decoration: const BoxDecoration(
        color: Color(0xFF0A2540),
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Left Action Buttons (Hidden when recording)
            if (!_isRecording) ...[
              IconButton(
                icon: Icon(
                  _showEmoji ? Icons.keyboard : Icons.sentiment_satisfied_alt_outlined, 
                  color: const Color(0xFF2979FF),
                  size: 26,
                ), 
                onPressed: () { 
                  setState(() => _showEmoji = !_showEmoji); 
                  if (_showEmoji) FocusScope.of(context).unfocus(); 
                }
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_rounded, color: Colors.white38, size: 26), 
                onPressed: _pickMedia
              ),
            ],

            // Input / Recording UI
            Expanded(
              child: _isRecording 
                ? _buildRecordingOverlay()
                : _buildTextField(hasText),
            ),

            const SizedBox(width: 8),

            // Mic / Send Button (Stable in tree to catch release)
            GestureDetector(
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) => _stopRecording(),
              onTap: () => hasText ? _sendMessage() : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: hasText || _isRecording ? const Color(0xFF2979FF) : const Color(0xFF16233A),
                  shape: BoxShape.circle,
                  boxShadow: hasText || _isRecording ? [
                    BoxShadow(
                      color: const Color(0xFF2979FF).withValues(alpha: 0.4), 
                      blurRadius: 12, 
                      spreadRadius: 1
                    )
                  ] : []
                ),
                child: Icon(
                  !hasText ? Icons.mic : Icons.send_rounded, 
                  color: hasText || _isRecording ? Colors.white : const Color(0xFF2979FF), 
                  size: 22
                )
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(bool hasText) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 120),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), 
      decoration: BoxDecoration(
        color: const Color(0xFF16233A), 
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFF2979FF).withValues(alpha: 0.1))
      ), 
      child: TextField(
        controller: _messageController, 
        maxLines: null,
        onChanged: (val) {
          setState(() {}); // Update icons
          _onTyping();
        }, 
        onTap: () => setState(() => _showEmoji = false), 
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: const InputDecoration(
          hintText: "Type a message...", 
          hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 10)
        )
      )
    );
  }

  Widget _buildRecordingOverlay() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Opacity(
                opacity: 0.5 + (0.5 * (1.0 - value)),
                child: Transform.scale(
                  scale: 1.0 + (0.2 * value),
                  child: const Icon(Icons.mic, color: Colors.redAccent, size: 24),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Text(
            "${_recordDuration ~/ 60}:${(_recordDuration % 60).toString().padLeft(2, '0')}", 
            style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace')
          ),
          const Spacer(),
          const Text("Release to send", style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_right, color: Colors.white24, size: 16),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['isMe'];
    final text = message['text'] ?? "";
    final time = message['time'] ?? "now";
    final type = message['type'];
    final mediaUrl = message['mediaUrl'];
    final isRead = message['is_read'] ?? false;
    final isEdited = message['is_edited'] ?? false;
    final reactions = message['reactions'] as List? ?? [];
    final bool isHighlighted = _highlightedMessageId == message['id'].toString();

    return GestureDetector(
      onLongPress: () => _showMessageActions(message),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        padding: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isHighlighted ? const Color(0xFF2979FF).withValues(alpha: 0.1) : Colors.transparent,
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) ...[
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF2979FF).withValues(alpha: 0.1), width: 1),
                    ),
                    child: CircleAvatar(
                      radius: 14, 
                      backgroundColor: Colors.white10, 
                      backgroundImage: _otherUserProfilePic != null ? NetworkImage(_otherUserProfilePic!) : null, 
                      child: _otherUserProfilePic == null ? const Icon(Icons.person, color: Colors.white, size: 14) : null
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isMe 
                        ? const LinearGradient(
                            colors: [Color(0xFF2979FF), Color(0xFF5B9CFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                      color: isMe ? null : const Color(0xFF16233A),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(22), 
                        topRight: const Radius.circular(22), 
                        bottomLeft: Radius.circular(isMe ? 22 : 5), 
                        bottomRight: Radius.circular(isMe ? 5 : 22)
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1), 
                          blurRadius: 10, 
                          offset: const Offset(0, 4)
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.groupId != null && !isMe)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              message['senderName'] ?? widget.username,
                              style: const TextStyle(color: Color(0xFF5B9CFF), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        if (message['reply_to'] != null) _buildReplyInBubble(message['reply_to']),
                        if (type == 'image' && mediaUrl != null)
                          _buildImageAttachment(mediaUrl),
                        if (type == 'audio' && mediaUrl != null) 
                          VoiceMessageBubble(url: mediaUrl, isMe: isMe),
                        if (type == 'file' && mediaUrl != null)
                          _buildFileAttachment(message),
                        if (text.isNotEmpty) 
                          Text(
                            text, 
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 15,
                              height: 1.4,
                              letterSpacing: 0.1
                            )
                          ),
                        if (isEdited) 
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              "Edited", 
                              style: TextStyle(
                                color: isMe ? Colors.white70 : Colors.white38, 
                                fontSize: 10, 
                                fontStyle: FontStyle.italic
                              )
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (isMe) const SizedBox(width: 8),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(top: 6, left: isMe ? 0 : 44, right: isMe ? 6 : 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(time, style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w500)),
                  if (isMe) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.done_all_rounded, 
                      size: 15, 
                      color: isRead ? const Color(0xFF00C48C) : Colors.white24
                    ),
                  ],
                ],
              ),
            ),
            if (reactions.isNotEmpty) _buildReactionsRow(reactions, isMe),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionsRow(List reactions, bool isMe) {
    final Map<String, int> counts = {};
    for (var r in reactions) counts[r['reaction']] = (counts[r['reaction']] ?? 0) + 1;
    return Padding(
      padding: EdgeInsets.only(top: 4, left: isMe ? 0 : 44, right: isMe ? 4 : 0), 
      child: Wrap(
        spacing: 6, 
        children: counts.entries.map((e) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
          decoration: BoxDecoration(
            color: const Color(0xFF16233A), 
            borderRadius: BorderRadius.circular(12), 
            border: Border.all(color: const Color(0xFF2979FF).withValues(alpha: 0.15)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]
          ), 
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e.key, style: const TextStyle(fontSize: 14)),
              if (e.value > 1) ...[
                const SizedBox(width: 4),
                Text(
                  "${e.value}", 
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)
                ),
              ]
            ],
          )
        )).toList()
      )
    );
  }

  void _showMessageActions(Map<String, dynamic> message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16233A),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(padding: const EdgeInsets.all(15), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: ["❤️", "👍", "😂", "😮", "😢", "🙏"].map((e) => GestureDetector(onTap: () { ApiService.reactToMessage(message['id'], e); Navigator.pop(context); }, child: Text(e, style: const TextStyle(fontSize: 24)))).toList())),
            ListTile(leading: const Icon(Icons.reply, color: Colors.white70), title: const Text("Reply", style: TextStyle(color: Colors.white)), onTap: () { setState(() => _replyingTo = message); Navigator.pop(context); }),
            if (message['type'] == 'text') ListTile(leading: const Icon(Icons.assignment_outlined, color: Color(0xFF2979FF)), title: const Text("Create Task", style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); _createTaskFromMessage(message); }),
            if (message['isMe']) ...[
              if (message['type'] == 'text') ListTile(leading: const Icon(Icons.edit, color: Colors.white70), title: const Text("Edit", style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); _editMessage(message['id'], message['text']); }),
              ListTile(leading: const Icon(Icons.delete_outline, color: Color(0xFFFF4C61)), title: const Text("Delete", style: TextStyle(color: Color(0xFFFF4C61))), onTap: () { Navigator.pop(context); _deleteMessage(message['id']); }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageAttachment(String mediaUrl) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => FullScreenImageViewer(url: mediaUrl, tag: mediaUrl))),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12), 
              child: Hero(
                tag: mediaUrl, 
                child: mediaUrl.startsWith('http') 
                  ? CachedNetworkImage(
                      imageUrl: mediaUrl, 
                      placeholder: (c, u) => const SizedBox(height: 200, width: 200, child: Center(child: CircularProgressIndicator(color: Colors.white24)))
                    ) 
                  : Image.file(File(mediaUrl), height: 200, width: 200, fit: BoxFit.cover)
              )
            ),
          ),
        ),
        if (mediaUrl.startsWith('http'))
          Positioned(
            right: 8, 
            top: 8, 
            child: _downloadProgress.containsKey(mediaUrl) 
              ? SizedBox(width: 30, height: 30, child: CircularProgressIndicator(value: _downloadProgress[mediaUrl], color: Colors.white, strokeWidth: 2)) 
              : Container(
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
                  child: IconButton(
                    icon: const Icon(Icons.download_for_offline, color: Colors.white70), 
                    onPressed: () => _downloadFile(mediaUrl, 'SphereX_${DateTime.now().millisecondsSinceEpoch}.jpg')
                  ),
                )
          ),
      ],
    );
  }

  Widget _buildFileAttachment(Map<String, dynamic> message) {
    final String fileName = message['fileName'] ?? "Document";
    final int? fileSize = message['fileSize'];
    final String url = message['mediaUrl'];
    final bool isDownloading = _downloadProgress.containsKey(url);

    return InkWell(
      onTap: () async {
        if (url.startsWith('http')) {
          final dir = await _getDownloadDirectory();
          final savePath = '${dir?.path}/$fileName';
          if (await File(savePath).exists()) {
            OpenFilex.open(savePath);
          } else {
            _downloadFile(url, fileName);
          }
        } else {
          OpenFilex.open(url);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFF2979FF),
                  child: Icon(Icons.insert_drive_file_rounded, color: Colors.white, size: 20),
                ),
                if (isDownloading)
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      value: _downloadProgress[url],
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fileSize != null ? "${(fileSize / 1024).toStringAsFixed(1)} KB" : "Document",
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyInBubble(dynamic replyTo) {
    if (replyTo == null) return const SizedBox.shrink();
    
    final String originalId = replyTo.toString();
    final originalMsg = _messages.firstWhere(
      (m) => m['id'].toString() == originalId, 
      orElse: () => {},
    );
    
    if (originalMsg.isEmpty) return const SizedBox.shrink();

    final type = originalMsg['type'];
    final mediaUrl = originalMsg['mediaUrl'];
    final text = originalMsg['text'] ?? "";
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15), 
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 3))
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type == 'image' && mediaUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: mediaUrl.startsWith('http') 
                  ? CachedNetworkImage(imageUrl: mediaUrl, width: 35, height: 35, fit: BoxFit.cover)
                  : Image.file(File(mediaUrl), width: 35, height: 35, fit: BoxFit.cover)
              ),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    originalMsg['isMe'] ? "You" : widget.username,
                    style: const TextStyle(color: Color(0xFF5B9CFF), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    type == 'image' ? "📷 Photo" : (type == 'audio' ? "🎤 Voice Message" : (text.isEmpty ? "Media" : text)), 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis, 
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiPicker() {
    return SizedBox(height: 250, child: EmojiPicker(onEmojiSelected: (category, emoji) { _messageController.text = _messageController.text + emoji.emoji; _onTyping(); }, config: const Config(height: 250, checkPlatformCompatibility: true, emojiViewConfig: EmojiViewConfig(columns: 7, emojiSizeMax: 32, backgroundColor: Color(0xFF0A2540)), categoryViewConfig: CategoryViewConfig(backgroundColor: Color(0xFF0A2540), indicatorColor: Color(0xFF2979FF), iconColorSelected: Color(0xFF2979FF)), bottomActionBarConfig: BottomActionBarConfig(enabled: false))));
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0A2540),
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF16233A),
          borderRadius: BorderRadius.circular(10),
          border: const Border(left: BorderSide(color: Color(0xFF2979FF), width: 4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _replyingTo!['isMe'] ? "Replying to yourself" : "Replying to ${widget.username}", 
                    style: const TextStyle(color: Color(0xFF2979FF), fontWeight: FontWeight.bold, fontSize: 12)
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _replyingTo!['text'] ?? "Media", 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis, 
                    style: const TextStyle(color: Colors.white60, fontSize: 13)
                  )
                ]
              )
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white38, size: 18), 
              onPressed: () => setState(() => _replyingTo = null)
            )
          ],
        ),
      ),
    );
  }
}

class TypingIndicatorAnimation extends StatefulWidget {
  const TypingIndicatorAnimation({super.key});

  @override
  State<TypingIndicatorAnimation> createState() => _TypingIndicatorAnimationState();
}

class _TypingIndicatorAnimationState extends State<TypingIndicatorAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double delay = index * 0.2;
            final double value = ((_controller.value - delay) % 1.0);
            return Container(
              width: 3,
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF00C48C).withValues(alpha: 0.3 + (0.7 * (1.0 - value))),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}

class VoiceMessageBubble extends StatefulWidget {
  final String url;
  final bool isMe;
  const VoiceMessageBubble({super.key, required this.url, required this.isMe});
  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    
    // Configure player for maximum volume and speaker output
    _player.setVolume(1.0);
    _player.setAudioContext(AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {AVAudioSessionOptions.mixWithOthers},
      ),
      android: AudioContextAndroid(
        isSpeakerphoneOn: true,
        usageType: AndroidUsageType.media,
        contentType: AndroidContentType.music,
      ),
    ));

    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _totalDuration = d);
    });
    
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        Source source;
        if (widget.url.startsWith('http')) {
          source = UrlSource(widget.url);
        } else {
          source = DeviceFileSource(widget.url);
        }
        await _player.play(source);
      }
      if (mounted) setState(() => _isPlaying = !_isPlaying);
    } catch (e) {
      debugPrint('Voice playback error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error playing voice message'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasDuration = _totalDuration.inMilliseconds > 0;
    
    return Container(
      width: 240,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlayback,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _isPlaying ? const Color(0xFF2979FF) : Colors.white12,
                shape: BoxShape.circle,
                boxShadow: _isPlaying ? [BoxShadow(color: const Color(0xFF2979FF).withValues(alpha: 0.3), blurRadius: 8)] : [],
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, 
                color: Colors.white, 
                size: 26
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(20, (index) => Container(
                        width: 2,
                        height: index % 3 == 0 ? 10 : (index % 2 == 0 ? 18 : 12),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: hasDuration ? _position.inMilliseconds / _totalDuration.inMilliseconds : 0.0,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _isPlaying ? const Color(0xFF2979FF).withValues(alpha: 0.7) : Colors.white24
                        ),
                        minHeight: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isPlaying 
                        ? "${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}"
                        : "${_totalDuration.inMinutes}:${(_totalDuration.inSeconds % 60).toString().padLeft(2, '0')}", 
                      style: const TextStyle(color: Colors.white60, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                    ),
                    const Icon(Icons.graphic_eq_rounded, color: Colors.white12, size: 14),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String url;
  final String tag;
  const FullScreenImageViewer({super.key, required this.url, required this.tag});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white), elevation: 0),
      body: GestureDetector(onTap: () => Navigator.pop(context), child: Center(child: InteractiveViewer(panEnabled: true, minScale: 0.5, maxScale: 4, child: Hero(tag: tag, child: url.startsWith('http') ? CachedNetworkImage(imageUrl: url, fit: BoxFit.contain, placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Color(0xFF2979FF))), errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white)) : Image.file(File(url), fit: BoxFit.contain))))),
    );
  }
}
