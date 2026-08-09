import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiService {
  static final _storage = FlutterSecureStorage();
  static final _supabase = Supabase.instance.client;

  // AUTHENTICATION
  static Future<void> _saveUsername(String username) async {
    await _storage.write(key: 'username', value: username);
  }

  static Future<String?> getUsername() async {
    return await _storage.read(key: 'username');
  }

  static Future<void> logout() async {
    final myUsername = await getUsername();
    if (myUsername != null) {
      await updateOnlineStatus(myUsername, false);
    }
    await _supabase.auth.signOut();
    await _storage.delete(key: 'username');
  }

  static Future<void> updateOnlineStatus(String username, bool isOnline) async {
    try {
      await _supabase.from('profiles').update({
        'is_online': isOnline,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('username', username);
    } catch (e) {
      print('Update status error: $e');
    }
  }

  static Future<Map<String, dynamic>> requestOtp(String email, String username, String password) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );
      
      if (response.user != null) {
        await _ensureProfileExists(response.user!.id, username, email);
      }

      return {
        'success': true,
        'needsVerification': response.session == null,
        'username': username
      };
    } on AuthException catch (e) {
      return {'success': false, 'error': e.message};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<void> _ensureProfileExists(String userId, String username, String email) async {
    try {
      await _supabase.from('profiles').upsert({
        'id': userId,
        'username': username,
        'email': email,
        'about': "Available",
        'is_online': true,
        'last_seen': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Profile Upsert Error: $e');
    }
  }

  static Future<bool> verifyOtp(String email, String otp) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.signup,
      );
      
      if (response.user != null) {
        final username = response.user!.userMetadata?['username'] ?? email.split('@')[0];
        await _saveUsername(username);
        await _ensureProfileExists(response.user!.id, username, email);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> login(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        final username = response.user!.userMetadata?['username'] ?? email.split('@')[0];
        await _saveUsername(username);
        await _ensureProfileExists(response.user!.id, username, email);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      return false;
    }
  }

  // PROFILE MANAGEMENT
  static Future<Map<String, dynamic>?> getProfile(String username) async {
    try {
      final data = await _supabase.from('profiles').select().eq('username', username).maybeSingle();
      if (data == null) return null;
      return {
        'username': data['username'],
        'about': data['about'],
        'phone': data['phone'],
        'profilePic': data['avatar_url'],
        'isOnline': data['is_online'],
        'lastSeen': data['last_seen'],
      };
    } catch (e) {
      return null;
    }
  }

  static Future<bool> updateProfile(String username, String about, String phone) async {
    try {
      await _supabase.from('profiles').update({
        'about': about,
        'phone': phone
      }).eq('username', username);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> uploadProfilePic(String username, Uint8List fileBytes, String fileName) async {
    try {
      final path = 'avatars/${username}_$fileName';
      await _supabase.storage.from('spherex').uploadBinary(path, fileBytes);
      final url = _supabase.storage.from('spherex').getPublicUrl(path);
      
      await _supabase.from('profiles').update({'avatar_url': url}).eq('username', username);
      return true;
    } catch (e) {
      return false;
    }
  }

  // CONTACTS & SEARCH
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final myUsername = await getUsername() ?? "";
      final cleanQuery = query.replaceAll('@', '').trim();
      if (cleanQuery.isEmpty) return [];

      final List<dynamic> data = await _supabase
          .from('profiles')
          .select()
          .ilike('username', '%$cleanQuery%');

      List<Map<String, dynamic>> results = [];
      for (var user in data) {
        if (user['username'] == myUsername) continue;
        String relationship = await _getRelationship(myUsername, user['username']);
        results.add({
          'username': user['username'],
          'about': user['about'],
          'profilePic': user['avatar_url'],
          'isOnline': user['is_online'],
          'relationship': relationship
        });
      }
      return results;
    } catch (e) {
      return [];
    }
  }

  static Future<String> _getRelationship(String myUser, String otherUser) async {
    try {
      if (myUser.isEmpty) return 'none';
      final contact = await _supabase.from('contacts').select().eq('user_id', myUser).eq('contact_id', otherUser).maybeSingle();
      if (contact != null) return 'contact';

      final sent = await _supabase.from('contact_requests').select().eq('sender_id', myUser).eq('receiver_id', otherUser).eq('status', 'pending').maybeSingle();
      if (sent != null) return 'sent';

      final received = await _supabase.from('contact_requests').select().eq('sender_id', otherUser).eq('receiver_id', myUser).eq('status', 'pending').maybeSingle();
      if (received != null) return 'received';

      return 'none';
    } catch (e) {
      return 'none';
    }
  }

  static Future<bool> sendContactRequest(String receiver) async {
    try {
      final sender = await getUsername();
      if (sender == null) return false;
      await _supabase.from('contact_requests').upsert({
        'sender_id': sender,
        'receiver_id': receiver,
        'status': 'pending'
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getContactRequests() async {
    try {
      final myUser = await getUsername();
      if (myUser == null) return [];
      final List<dynamic> data = await _supabase
          .from('contact_requests')
          .select()
          .eq('receiver_id', myUser)
          .eq('status', 'pending');
      
      return data.map((r) => {'sender': r['sender_id']}).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<bool> respondToRequest(String sender, String action) async {
    try {
      final myUser = await getUsername();
      if (myUser == null) return false;
      if (action == 'accept') {
        await _supabase.from('contact_requests').update({'status': 'accepted'}).eq('sender_id', sender).eq('receiver_id', myUser);
        await _supabase.from('contacts').insert([
          {'user_id': myUser, 'contact_id': sender},
          {'user_id': sender, 'contact_id': myUser}
        ]);
      } else {
        await _supabase.from('contact_requests').delete().eq('sender_id', sender).eq('receiver_id', myUser);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // MESSAGING & CONVERSATIONS
  static Future<bool> sendMessage(String sender, String receiver, String text, {Uint8List? fileBytes, String? fileName, String type = 'text', String? replyTo, String? groupId}) async {
    try {
      String? fileUrl;
      if (fileBytes != null && fileName != null) {
        final folder = type == 'audio' ? 'voice_messages' : 'chat_media';
        final path = '$folder/${DateTime.now().millisecondsSinceEpoch}_$fileName';
        await _supabase.storage.from('spherex').uploadBinary(path, fileBytes);
        fileUrl = _supabase.storage.from('spherex').getPublicUrl(path);
      }

      final convId = groupId == null ? getConversationId(sender, receiver) : null;
      
      if (groupId == null) {
        await _supabase.from('conversations').upsert({
          'id': convId,
          'last_message': type == 'image' ? "📷 Photo" : (type == 'audio' ? "🎤 Voice Message" : (text.isEmpty ? "Media" : text)),
          'updated_at': DateTime.now().toIso8601String(),
          'participants': [sender, receiver]
        });
      }

      final messageData = {
        'conversation_id': convId,
        'group_id': groupId,
        'sender_id': sender,
        'receiver_id': groupId == null ? receiver : null,
        'content': text,
        'type': type,
        'file_url': fileUrl,
        'reply_to': replyTo,
        'is_read': false,
      };

      await _supabase.from('messages').insert(messageData);
      return true;
    } catch (e) {
      print('Send message error: $e');
      return false;
    }
  }

  static Future<bool> editMessage(String messageId, String newContent) async {
    try {
      await _supabase.from('messages').update({
        'content': newContent,
        'is_edited': true,
      }).eq('id', messageId);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteMessage(String messageId) async {
    try {
      await _supabase.from('messages').delete().eq('id', messageId);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> reactToMessage(String messageId, String emoji) async {
    try {
      final myUser = await getUsername();
      await _supabase.from('message_reactions').upsert({
        'message_id': messageId,
        'user_id': myUser,
        'reaction': emoji,
      });
    } catch (e) {
      print('Reaction error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getReactions(String messageId) async {
    try {
      return await _supabase.from('message_reactions').select().eq('message_id', messageId);
    } catch (e) {
      return [];
    }
  }

  static Future<void> markMessagesAsRead(String myUsername, String otherUsername) async {
    try {
      final convId = getConversationId(myUsername, otherUsername);
      await _supabase
          .from('messages')
          .update({'is_read': true})
          .match({'conversation_id': convId, 'receiver_id': myUsername, 'is_read': false});
    } catch (e) {
      print('Mark as read error: $e');
    }
  }

  static String getConversationId(String u1, String u2) {
    final list = [u1, u2];
    list.sort();
    return list.join('_');
  }

  static Future<List<Map<String, dynamic>>> getMessages(String user1, String user2, {String? groupId}) async {
    try {
      if (groupId != null) {
        final List<dynamic> data = await _supabase
            .from('messages')
            .select()
            .eq('group_id', groupId)
            .order('created_at', ascending: true);
        
        return data.map((m) => _mapMessage(m, user1)).toList();
      } else {
        final convId = getConversationId(user1, user2);
        final List<dynamic> data = await _supabase
            .from('messages')
            .select()
            .eq('conversation_id', convId)
            .order('created_at', ascending: true);
            
        return data.map((m) => _mapMessage(m, user1)).toList();
      }
    } catch (e) {
      return [];
    }
  }

  static Map<String, dynamic> _mapMessage(Map<String, dynamic> m, String myUser) {
    return {
      'id': m['id'],
      'sender': m['sender_id'],
      'text': m['content'],
      'mediaUrl': m['file_url'],
      'type': m['type'],
      'timestamp': m['created_at'],
      'reply_to': m['reply_to'],
      'is_read': m['is_read'],
      'is_edited': m['is_edited'],
      'isMe': m['sender_id'] == myUser,
    };
  }

  static Future<List<Map<String, dynamic>>> getConversations(String username) async {
    try {
      final List<dynamic> data = await _supabase
          .from('conversations')
          .select()
          .contains('participants', [username])
          .order('updated_at', ascending: false);
      
      List<Map<String, dynamic>> results = [];
      for (var conv in data) {
        final otherUser = (conv['participants'] as List).firstWhere((p) => p != username);
        final profile = await getProfile(otherUser);
        
        final List<dynamic> unreadCountRes = await _supabase
            .from('messages')
            .select('id')
            .eq('conversation_id', conv['id'])
            .eq('receiver_id', username)
            .eq('is_read', false);
        
        final unreadCount = unreadCountRes.length;

        results.add({
          '_id': otherUser,
          'lastMessage': conv['last_message'],
          'timestamp': conv['updated_at'],
          'profilePic': profile?['profilePic'],
          'isOnline': profile?['isOnline'],
          'unreadCount': unreadCount
        });
      }
      return results;
    } catch (e) {
      return [];
    }
  }

  // GROUP MANAGEMENT
  static Future<String?> createGroup(String name, String description, List<String> members) async {
    try {
      final myUser = await getUsername();
      if (myUser == null) return null;

      final res = await _supabase.from('groups').insert({
        'name': name,
        'description': description,
        'created_by': myUser
      }).select().single();

      final groupId = res['id'];
      
      // Add all members
      final memberInserts = members.map((m) => {
        'group_id': groupId,
        'user_id': m,
        'role': m == myUser ? 'admin' : 'member'
      }).toList();

      await _supabase.from('group_members').insert(memberInserts);
      return groupId;
    } catch (e) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getMyGroups() async {
    try {
      final myUser = await getUsername();
      if (myUser == null) return [];

      final List<dynamic> memberData = await _supabase.from('group_members').select('group_id').eq('user_id', myUser);
      final groupIds = memberData.map((m) => m['group_id']).toList();

      if (groupIds.isEmpty) return [];

      return await _supabase.from('groups').select().inFilter('id', groupIds);
    } catch (e) {
      return [];
    }
  }

  // TASK MANAGEMENT
  static Future<bool> createTask({
    required String title,
    String? description,
    required String assignedTo,
    DateTime? dueDate,
    String? sourceMessageId,
    String? conversationId,
    String? groupId
  }) async {
    try {
      final myUser = await getUsername();
      if (myUser == null) return false;

      await _supabase.from('tasks').insert({
        'title': title,
        'description': description,
        'assigned_to': assignedTo,
        'created_by': myUser,
        'due_date': dueDate?.toIso8601String(),
        'source_message_id': sourceMessageId,
        'conversation_id': conversationId,
        'group_id': groupId,
        'status': 'pending'
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getTasks(String filter) async {
    try {
      final myUser = await getUsername();
      if (myUser == null) return [];

      var query = _supabase.from('tasks').select();

      if (filter == 'assigned_to_me') {
        query = query.eq('assigned_to', myUser);
      } else if (filter == 'created_by_me') {
        query = query.eq('created_by', myUser);
      } else if (filter == 'done') {
        query = query.eq('status', 'completed');
      }

      final List<dynamic> data = await query.order('created_at', ascending: false);
      return data.map((t) => Map<String, dynamic>.from(t)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<bool> updateTaskStatus(String taskId, String status) async {
    try {
      await _supabase.from('tasks').update({
        'status': status,
        'completed_at': status == 'completed' ? DateTime.now().toIso8601String() : null
      }).eq('id', taskId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // REAL-TIME HELPERS
  static RealtimeChannel getMessageChannel(String user1, String user2, Function(Map<String, dynamic>) callback) {
    final convId = getConversationId(user1, user2);
    return _supabase
        .channel('chat:$convId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: convId,
          ),
          callback: (payload) => callback(payload.newRecord),
        )
        .subscribe();
  }

  static void sendTypingStatus(String user1, String user2, bool isTyping) {
    _supabase.from('messages').insert({
      'conversation_id': 'typing_signal',
      'sender_id': user1,
      'receiver_id': user2,
      'content': isTyping ? 'typing' : 'stopped',
      'type': 'system'
    });
  }

  static RealtimeChannel getTypingChannel(String user1, String user2, Function(Map<String, dynamic>) callback) {
    return _supabase
        .channel('typing_signals')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: 'typing_signal',
          ),
          callback: (payload) => callback(payload.newRecord),
        )
        .subscribe();
  }

  static RealtimeChannel getStatusChannel(String username, Function(Map<String, dynamic>) callback) {
    return _supabase
        .channel('public:profiles:username=eq.$username')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'username',
            value: username,
          ),
          callback: (payload) => callback(payload.newRecord),
        )
        .subscribe();
  }

  static Future<bool> loginWithGoogle(String idToken) async {
    try {
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      
      if (response.user != null) {
        final username = response.user!.userMetadata?['username'] ?? response.user!.email!.split('@')[0];
        await _saveUsername(username);
        await _ensureProfileExists(response.user!.id, username, response.user!.email!);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteAccount(String username) async {
    try {
      await _supabase.from('profiles').delete().eq('username', username);
      await logout();
      return true;
    } catch (e) {
      return false;
    }
  }
}
