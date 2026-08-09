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
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final String username;
  final String? groupId;
  const ChatScreen({super.key, required this.username, this.groupId});

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
  bool _showEmoji = false;
  bool _isOtherTyping = false;
  Timer? _typingTimer;
  RealtimeChannel? _messageChannel;
  RealtimeChannel? _statusChannel;
  RealtimeChannel? _typingChannel;
  RealtimeChannel? _reactionChannel;
  final ImagePicker _picker = ImagePicker();
  final Dio _dio = Dio();
  final Map<String, double> _downloadProgress = {};
  
  Map<String, dynamic>? _replyingTo;

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
      await ApiService.markMessagesAsRead(_myUsername!, widget.username);
      await _fetchMessages();
      await _fetchOtherUserProfile();
      _subscribeToMessages();
      _subscribeToStatus();
      _subscribeToTyping();
      _subscribeToReactions();
      _updateMyStatus(true);
    }
    _scrollToBottom();
  }

  void _updateMyStatus(bool online) async {
    if (_myUsername != null) {
      await ApiService.updateOnlineStatus(_myUsername!, online);
    }
  }

  void _subscribeToMessages() {
    _messageChannel = ApiService.getMessageChannel(_myUsername!, widget.username, (newMessage) {
      if (!mounted) return;
      
      if (newMessage['receiver_id'] == _myUsername && newMessage['is_read'] == false) {
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
            'is_read': newMessage['is_read'] ?? false,
            'is_edited': newMessage['is_edited'] ?? false,
            'reply_to': newMessage['reply_to'],
            'time': _formatTimestamp(newMessage['created_at']),
            'reactions': [],
          });
          _scrollToBottom();
        }
      });
    });
  }

  void _subscribeToStatus() {
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
      if (mounted && signal['sender_id'] == widget.username && signal['receiver_id'] == _myUsername) {
        setState(() {
          _isOtherTyping = signal['content'] == 'typing';
        });
      }
    });
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
    ApiService.sendTypingStatus(_myUsername!, widget.username, true);
    
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      ApiService.sendTypingStatus(_myUsername!, widget.username, false);
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
    final messages = await ApiService.getMessages(_myUsername!, widget.username, groupId: widget.groupId);
    
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
        
        const config = RecordConfig(); // Default config
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
        print('Started recording at $path');
      }
    } catch (e) {
      print('Record error: $e');
    }
  }

  void _stopRecording() async {
    if (!_isRecording) return;
    
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    
    final bool isTooShort = _recordDuration < 1;
    
    setState(() {
      _isRecording = false;
    });
    
    if (path != null && !isTooShort) {
      _sendMessage(type: 'audio', audioPath: path);
    } else if (isTooShort) {
      print('Recording too short');
    }
  }

  void _pickMedia() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (file != null) {
      _sendMessage(type: 'image', mediaFile: file);
    }
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

  void _createTaskFromMessage(Map<String, dynamic> message) {
    final titleController = TextEditingController(text: message['text']);
    String assignedTo = widget.username;
    DateTime? dueDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF16233A),
          title: const Text("Create Task", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Title", labelStyle: TextStyle(color: Colors.white38)),
              ),
              const SizedBox(height: 10),
              DropdownButton<String>(
                value: assignedTo,
                dropdownColor: const Color(0xFF16233A),
                items: [widget.username, _myUsername!].map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: (val) => setDialogState(() => assignedTo = val!),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setDialogState(() => dueDate = picked);
                },
                child: Text(dueDate == null ? "Select Due Date" : DateFormat('MMM d, yyyy').format(dueDate!)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                final success = await ApiService.createTask(
                  title: titleController.text,
                  assignedTo: assignedTo,
                  dueDate: dueDate,
                  sourceMessageId: message['id'],
                  conversationId: widget.groupId == null ? ApiService.getConversationId(_myUsername!, widget.username) : null,
                  groupId: widget.groupId
                );
                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Task Created!")));
                }
              },
              child: const Text("Create"),
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
          elevation: 4,
          leadingWidth: 40,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
          title: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(radius: 18, backgroundColor: Colors.white10, backgroundImage: _otherUserProfilePic != null ? NetworkImage(_otherUserProfilePic!) : null, child: _otherUserProfilePic == null ? const Icon(Icons.person, color: Colors.white, size: 20) : null),
                  Positioned(right: 0, bottom: 0, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: _isOnline ? const Color(0xFF00C48C) : Colors.grey, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF0A2540), width: 2)))),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.username, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(
                      _isOtherTyping ? "typing..." : (_isOnline ? "Online" : (_lastSeen.isEmpty ? "Offline" : "Last seen $_lastSeen")),
                      style: TextStyle(fontSize: 11, color: _isOtherTyping || _isOnline ? const Color(0xFF00C48C) : Colors.white54, fontStyle: _isOtherTyping ? FontStyle.italic : FontStyle.normal),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(icon: const Icon(Icons.call, color: Color(0xFF2979FF), size: 20), onPressed: () {}),
            IconButton(icon: const Icon(Icons.videocam, color: Color(0xFF2979FF), size: 22), onPressed: () {}),
            IconButton(icon: const Icon(Icons.more_vert, color: Colors.white70), onPressed: () {}),
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
              if (_isRecording) _buildRecordingUI(),
              if (!_isRecording) _buildMessageInput(),
              if (_showEmoji) _buildEmojiPicker(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingUI() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: const BoxDecoration(
        color: Color(0xFF0A2540),
        border: Border(top: BorderSide(color: Colors.redAccent, width: 2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic, color: Colors.redAccent, size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              "Recording Voice Message... ${_recordDuration}s", 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
            )
          ),
          const Text("Release to Send", style: TextStyle(color: Colors.white54, fontSize: 12)),
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

    return GestureDetector(
      onLongPress: () => _showMessageActions(message),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) ...[
                  CircleAvatar(
                    radius: 14, 
                    backgroundColor: Colors.white10, 
                    backgroundImage: _otherUserProfilePic != null ? NetworkImage(_otherUserProfilePic!) : null, 
                    child: _otherUserProfilePic == null ? const Icon(Icons.person, color: Colors.white, size: 14) : null
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
                        topLeft: const Radius.circular(20), 
                        topRight: const Radius.circular(20), 
                        bottomLeft: Radius.circular(isMe ? 20 : 5), 
                        bottomRight: Radius.circular(isMe ? 5 : 20)
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15), 
                          blurRadius: 8, 
                          offset: const Offset(0, 3)
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message['reply_to'] != null) _buildReplyInBubble(message['reply_to']),
                        if (type == 'image' && mediaUrl != null)
                          _buildImageAttachment(mediaUrl),
                        if (type == 'audio' && mediaUrl != null) 
                          VoiceMessageBubble(url: mediaUrl, isMe: isMe),
                        if (text.isNotEmpty) 
                          Text(
                            text, 
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 15,
                              height: 1.3
                            )
                          ),
                        if (isEdited) 
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text("Edited", style: TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic)),
                          ),
                      ],
                    ),
                  ),
                ),
                if (isMe) const SizedBox(width: 8),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(top: 4, left: isMe ? 0 : 44, right: isMe ? 4 : 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(time, style: const TextStyle(color: Colors.white24, fontSize: 10)),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.done_all, size: 14, color: isRead ? const Color(0xFF2979FF) : Colors.white24),
                  ],
                ],
              ),
            ),
            if (reactions.isNotEmpty) _buildReactionsRow(reactions),
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

  Widget _buildReplyInBubble(dynamic replyTo) {
    if (replyTo == null) return const SizedBox.shrink();
    
    // Safety check for ID type
    final String originalId = replyTo.toString();
    final originalMsg = _messages.firstWhere(
      (m) => m['id'].toString() == originalId, 
      orElse: () => {},
    );
    
    if (originalMsg.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
      child: Text(
        originalMsg['text'] ?? "Media", 
        maxLines: 1, 
        overflow: TextOverflow.ellipsis, 
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }

  Widget _buildReactionsRow(List reactions) {
    final Map<String, int> counts = {};
    for (var r in reactions) counts[r['reaction']] = (counts[r['reaction']] ?? 0) + 1;
    return Padding(padding: const EdgeInsets.only(top: 4, left: 40, right: 40), child: Wrap(spacing: 4, children: counts.entries.map((e) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF16233A), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)), child: Text("${e.key} ${e.value > 1 ? e.value : ''}", style: const TextStyle(fontSize: 12)))).toList()));
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

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0A2540),
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                _showEmoji ? Icons.keyboard : Icons.sentiment_satisfied_alt_outlined, 
                color: const Color(0xFF2979FF)
              ), 
              onPressed: () { 
                setState(() => _showEmoji = !_showEmoji); 
                if (_showEmoji) FocusScope.of(context).unfocus(); 
              }
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.white54), 
              onPressed: _pickMedia
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16), 
                decoration: BoxDecoration(
                  color: const Color(0xFF16233A), 
                  borderRadius: BorderRadius.circular(25)
                ), 
                child: TextField(
                  controller: _messageController, 
                  onChanged: (val) {
                    setState(() {}); // Update send icon state
                    _onTyping();
                  }, 
                  onTap: () => setState(() => _showEmoji = false), 
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: "Type a message...", 
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none
                  )
                )
              )
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) => _stopRecording(),
              onTap: () => _sendMessage(),
              child: CircleAvatar(
                radius: 22, 
                backgroundColor: const Color(0xFF2979FF), 
                child: Icon(
                  _messageController.text.isEmpty ? Icons.mic : Icons.send, 
                  color: Colors.white, 
                  size: 20
                )
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
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _totalDuration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () async {
              try {
                if (_isPlaying) {
                  await _player.pause();
                } else {
                  Source source = widget.url.startsWith('http') 
                      ? UrlSource(widget.url) 
                      : DeviceFileSource(widget.url);
                  await _player.play(source);
                }
                if (mounted) setState(() => _isPlaying = !_isPlaying);
              } catch (e) {
                print('Playback error: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not play audio'))
                  );
                }
              }
            },
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow, 
                color: Colors.white, 
                size: 20
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                  value: _totalDuration.inMilliseconds > 0 
                      ? _position.inMilliseconds / _totalDuration.inMilliseconds
                      : 0.0,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}", 
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(width: 10),
          const Icon(Icons.mic, color: Colors.white24, size: 16),
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
