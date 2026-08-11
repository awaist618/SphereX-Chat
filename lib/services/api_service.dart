import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_db_service.dart';

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
    await LocalDbService.clearAll();
  }

  static Future<void> updateOnlineStatus(String username, bool isOnline) async {
    try {
      await _supabase.from('profiles').update({
        'is_online': isOnline,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('username', username);
    } catch (e) {
      debugPrint('Update status error: $e');
    }
  }

  static Future<Map<String, dynamic>> requestOtp(String email, String username, String password, {String? phone, String? name}) async {
    try {
      final usernameLower = username.trim().toLowerCase();

      // Check if username already exists in profiles
      final existingUser = await _supabase
          .from('profiles')
          .select('username')
          .eq('username', usernameLower)
          .maybeSingle();
      
      if (existingUser != null) {
        return {'success': false, 'error': 'Username already taken'};
      }

      // Check if phone number already exists
      if (phone != null && phone.isNotEmpty) {
        final existingPhone = await _supabase
            .from('profiles')
            .select('username')
            .eq('phone', phone)
            .maybeSingle();
        
        if (existingPhone != null) {
          return {'success': false, 'error': 'This phone number is already registered'};
        }
      }

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': usernameLower, 'phone': phone, 'full_name': name},
      );
      
      if (response.user != null) {
        await LocalDbService.clearAll();
        await _saveUsername(usernameLower);
        // We try to create the profile. If RLS fails, handle it gracefully.
        try {
          await _ensureProfileExists(response.user!.id, usernameLower, email, phone: phone, name: name);
        } catch (e) {
          debugPrint('Background profile creation failed (normal if RLS is strict before verification): $e');
        }
      }

      return {
        'success': true,
        'needsVerification': response.session == null,
        'username': usernameLower
      };
    } on AuthException catch (e) {
      return {'success': false, 'error': e.message};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<void> _ensureProfileExists(String userId, String username, String email, {String? phone, String? name}) async {
    try {
      await _supabase.from('profiles').upsert({
        'id': userId,
        'username': username,
        'email': email,
        'phone': phone,
        'name': name,
        'about': "Available",
        'is_online': true,
        'last_seen': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Profile Upsert Error: $e');
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
        await LocalDbService.clearAll();
        final meta = response.user!.userMetadata ?? {};
        final username = meta['username'] ?? email.split('@')[0];
        final phone = meta['phone'];
        final name = meta['full_name'];

        await _saveUsername(username);
        await _ensureProfileExists(response.user!.id, username, email, phone: phone, name: name);
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
        await LocalDbService.clearAll();
        final meta = response.user!.userMetadata ?? {};
        final username = meta['username'] ?? email.split('@')[0];
        final phone = meta['phone'];
        final name = meta['full_name'];

        await _saveUsername(username);
        await _ensureProfileExists(response.user!.id, username, email, phone: phone, name: name);
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
    // 1. Get from Local for speed
    final localProfile = await LocalDbService.getProfile(username);
    
    // 2. background sync
    _syncProfile(username);

    if (localProfile != null) return localProfile;

    try {
      final data = await _supabase.from('profiles').select().eq('username', username).maybeSingle();
      if (data == null) return null;
      final profile = {
        'username': data['username'],
        'name': data['name'],
        'about': data['about'],
        'phone': data['phone'],
        'profilePic': data['avatar_url'],
        'isOnline': data['is_online'],
        'lastSeen': data['last_seen'],
      };
      await LocalDbService.saveProfile(profile);
      return profile;
    } catch (e) {
      return null;
    }
  }

  static Future<void> _syncProfile(String username) async {
    try {
      final data = await _supabase.from('profiles').select().eq('username', username).maybeSingle();
      if (data != null) {
        await LocalDbService.saveProfile({
          'username': data['username'],
          'name': data['name'],
          'about': data['about'],
          'phone': data['phone'],
          'profilePic': data['avatar_url'],
          'isOnline': data['is_online'],
          'lastSeen': data['last_seen'],
        });
      }
    } catch (e) {
      debugPrint('Sync profile error: $e');
    }
  }

  static Future<bool> updateProfile(String username, String? about, String? phone, {String? name}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final Map<String, dynamic> updates = {};
      if (about != null && about != "Available") updates['about'] = about;
      
      if (phone != null && phone != "Not linked" && phone.isNotEmpty) {
        if (phone.length == 11 && RegExp(r'^[0-9]+$').hasMatch(phone)) {
          updates['phone'] = phone;
        } else {
          debugPrint('Skipping phone update: Invalid format ($phone)');
        }
      }
      
      if (name != null && name != "User" && name.isNotEmpty) updates['name'] = name;

      if (updates.isEmpty) return true;

      // Update by ID (the most secure and reliable way in Supabase)
      await _supabase.from('profiles').update(updates).eq('id', user.id);
      
      // Sync local cache
      final syncedProfile = await getProfile(username);
      if (syncedProfile != null) {
        await LocalDbService.saveProfile(syncedProfile);
      }
      
      return true;
    } catch (e) {
      debugPrint('Update profile error: $e');
      return false;
    }
  }

  static Future<bool> isUsernameAvailable(String username) async {
    try {
      final res = await _supabase.from('profiles').select('username').eq('username', username.toLowerCase()).maybeSingle();
      return res == null;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateUsername(String oldUsername, String newUsername) async {
    try {
      final newUsernameLower = newUsername.trim().toLowerCase();
      
      // 1. Update Profile in Supabase
      // This will trigger CASCADE updates in all other tables if SQL from Step 1 was run
      await _supabase.from('profiles').update({
        'username': newUsernameLower
      }).eq('username', oldUsername);

      // 2. Update Supabase Auth Metadata (Ensures future logins have the right name)
      await _supabase.auth.updateUser(
        UserAttributes(data: {'username': newUsernameLower})
      );

      // 3. Update Local Storage for the current session
      await _saveUsername(newUsernameLower);

      // 4. Clear Local DB and Sign Out to force a fresh session
      // This is the "Professional" way: force a re-login with the new identity
      await LocalDbService.clearAll();

      return true;
    } catch (e) {
      debugPrint('Update username error: $e');
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

  static Future<bool> uploadGroupAvatar(String groupId, Uint8List fileBytes, String fileName) async {
    try {
      final path = 'group_avatars/${groupId}_$fileName';
      await _supabase.storage.from('spherex').uploadBinary(path, fileBytes);
      final url = _supabase.storage.from('spherex').getPublicUrl(path);
      
      await _supabase.from('groups').update({'avatar_url': url}).eq('id', groupId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // CONTACTS & SEARCH
  static Future<Map<String, List<Map<String, dynamic>>>> globalSearch(String query) async {
    try {
      final myUsername = await getUsername() ?? "";
      debugPrint('Global Search initiated by: @$myUsername for query: $query');
      final cleanQuery = query.replaceAll('@', '').trim();
      if (cleanQuery.isEmpty) return {'users': [], 'groups': [], 'messages': []};

      // 1. Search Users (Search by username or display name)
      final List<dynamic> userData = await _supabase
          .from('profiles')
          .select()
          .or('username.ilike.*$cleanQuery*,name.ilike.*$cleanQuery*')
          .limit(10);

      debugPrint('Search Results for "$cleanQuery": Found ${userData.length} users');

      List<Map<String, dynamic>> users = [];
      if (userData.isNotEmpty) {
        final List<String> userNames = userData.map((u) => u['username'] as String).toList();
        
        // Batch fetch relationships to avoid N+1 queries
        final contacts = await _supabase.from('contacts').select('contact_id').eq('user_id', myUsername).inFilter('contact_id', userNames);
        final sentReqs = await _supabase.from('contact_requests').select('receiver_id').eq('sender_id', myUsername).eq('status', 'pending').inFilter('receiver_id', userNames);
        final receivedReqs = await _supabase.from('contact_requests').select('sender_id').eq('receiver_id', myUsername).eq('status', 'pending').inFilter('sender_id', userNames);
        final blocks = await _supabase.from('blocks').select('blocked_id').eq('blocker_id', myUsername).inFilter('blocked_id', userNames);

        final contactSet = contacts.map((c) => c['contact_id']).toSet();
        final sentSet = sentReqs.map((r) => r['receiver_id']).toSet();
        final receivedSet = receivedReqs.map((r) => r['sender_id']).toSet();
        final blockSet = blocks.map((b) => b['blocked_id']).toSet();

        for (var user in userData) {
          final uname = user['username'];
          if (uname == myUsername) continue;
          
          String relationship = 'none';
          if (blockSet.contains(uname)) relationship = 'blocked';
          else if (contactSet.contains(uname)) relationship = 'contact';
          else if (sentSet.contains(uname)) relationship = 'sent';
          else if (receivedSet.contains(uname)) relationship = 'received';
          
          users.add({
            'username': uname,
            'name': user['name'],
            'about': user['about'],
            'profilePic': user['avatar_url'],
            'isOnline': user['is_online'],
            'relationship': relationship,
          });
        }
      }

      // 2. Search Groups (Only groups I'm a member of)
      List<Map<String, dynamic>> groups = [];
      try {
        final memberData = await _supabase.from('group_members').select('group_id').eq('user_id', myUsername);
        final myGroupIds = memberData.map((m) => m['group_id']).toList();

        if (myGroupIds.isNotEmpty) {
          final List<dynamic> groupData = await _supabase
              .from('groups')
              .select()
              .inFilter('id', myGroupIds)
              .ilike('name', '%$cleanQuery%')
              .limit(5);
          groups = groupData.map((g) => Map<String, dynamic>.from(g)).toList();
        }
      } catch (e) {
        debugPrint('Group Search Error (Skipping): $e');
      }

      // 3. Search Messages
      List<Map<String, dynamic>> messages = [];
      try {
        final List<dynamic> msgData = await _supabase
            .from('messages')
            .select()
            .or('sender_id.eq.$myUsername,receiver_id.eq.$myUsername')
            .ilike('content', '%$cleanQuery%')
            .order('created_at', ascending: false)
            .limit(10);
        
        messages = List<Map<String, dynamic>>.from(msgData.map((m) => Map<String, dynamic>.from(m)));
      } catch (e) {
        debugPrint('Message Search Error (Skipping): $e');
      }

      return {
        'users': users,
        'groups': groups,
        'messages': messages,
      };
    } catch (e) {
      debugPrint('Global Search Error: $e');
      return {'users': [], 'groups': [], 'messages': []};
    }
  }

  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty) {
      return await getSuggestedUsers();
    }
    final results = await globalSearch(query);
    return results['users']!;
  }

  static Future<List<Map<String, dynamic>>> getSuggestedUsers() async {
    try {
      final myUsername = await getUsername() ?? "";
      debugPrint('Fetching suggested users for: @$myUsername');
      
      // Fetch some profiles (e.g., latest 20)
      final List<dynamic> userData = await _supabase
          .from('profiles')
          .select()
          .neq('username', myUsername)
          .order('created_at', ascending: false)
          .limit(20);

      debugPrint('Found ${userData.length} potential suggestions in database');

      List<Map<String, dynamic>> users = [];
      if (userData.isNotEmpty) {
        final List<String> userNames = userData.map((u) => u['username'] as String).toList();
        
        // Batch fetch relationships
        final contacts = await _supabase.from('contacts').select('contact_id').eq('user_id', myUsername).inFilter('contact_id', userNames);
        final sentReqs = await _supabase.from('contact_requests').select('receiver_id').eq('sender_id', myUsername).eq('status', 'pending').inFilter('receiver_id', userNames);
        final receivedReqs = await _supabase.from('contact_requests').select('sender_id').eq('receiver_id', myUsername).eq('status', 'pending').inFilter('sender_id', userNames);
        
        final contactSet = contacts.map((c) => c['contact_id']).toSet();
        final sentSet = sentReqs.map((r) => r['receiver_id']).toSet();
        final receivedSet = receivedReqs.map((r) => r['sender_id']).toSet();

        for (var user in userData) {
          final uname = user['username'];
          
          String relationship = 'none';
          if (contactSet.contains(uname)) relationship = 'contact';
          else if (sentSet.contains(uname)) relationship = 'sent';
          else if (receivedSet.contains(uname)) relationship = 'received';
          
          users.add({
            'username': uname,
            'name': user['name'],
            'about': user['about'],
            'profilePic': user['avatar_url'],
            'isOnline': user['is_online'],
            'relationship': relationship,
          });
        }
      }
      return users;
    } catch (e) {
      debugPrint('Get Suggested Users Error: $e');
      return [];
    }
  }

  static Future<String> _getRelationship(String myUser, String otherUser) async {
    try {
      if (myUser.isEmpty) return 'none';
      
      // Check if blocked
      final blocked = await _supabase.from('blocks').select().eq('blocker_id', myUser).eq('blocked_id', otherUser).maybeSingle();
      if (blocked != null) return 'blocked';

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
      
      return List<Map<String, dynamic>>.from(data.map((r) => {'sender': r['sender_id']}));
    } catch (e) {
      debugPrint('Get Suggested Users Error: $e');
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

  // BLOCKING & REPORTING
  static Future<bool> blockUser(String otherUsername) async {
    try {
      final myUser = await getUsername();
      if (myUser == null) return false;
      
      // We use a dedicated blocks table for better scalability and RLS
      await _supabase.from('blocks').upsert({
        'blocker_id': myUser,
        'blocked_id': otherUsername
      });
      
      // Also remove from contacts if they were contacts
      await _supabase.from('contacts').delete().or('user_id.eq.$myUser,contact_id.eq.$myUser').or('user_id.eq.$otherUsername,contact_id.eq.$otherUsername');
      
      return true;
    } catch (e) {
      debugPrint('Block user error: $e');
      return false;
    }
  }

  static Future<bool> reportUser(String otherUsername, String reason) async {
    try {
      final myUser = await getUsername();
      if (myUser == null) return false;
      await _supabase.from('notifications').insert({
        'user_id': 'admin', // System/Admin user
        'sender_id': myUser,
        'type': 'report',
        'title': 'User Reported: @$otherUsername',
        'body': 'Reason: $reason',
        'reference_id': otherUsername,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // MESSAGING & CONVERSATIONS
  static Future<bool> sendMessage(String sender, String receiver, String text, {Uint8List? fileBytes, String? fileName, String type = 'text', String? replyTo, String? groupId}) async {
    try {
      // 1. Group Admin Message Only Check
      if (groupId != null) {
        final group = await _supabase.from('groups').select('only_admins_message').eq('id', groupId).single();
        if (group['only_admins_message'] == true) {
          final member = await _supabase.from('group_members').select('role').match({'group_id': groupId, 'user_id': sender}).single();
          if (member['role'] != 'admin') return false;
        }
      } else {
        // 2. Block Check (Direct Chat Only)
        final blocked = await _supabase.from('blocks').select().eq('blocker_id', receiver).eq('blocked_id', sender).maybeSingle();
        if (blocked != null) return false;
      }

      String? fileUrl;
      if (fileBytes != null && fileName != null) {
        String folder = 'chat_media';
        if (type == 'audio') folder = 'voice_messages';
        if (type == 'file') folder = 'documents';
        if (type == 'video_note') folder = 'video_notes';

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
        'file_name': fileName,
        'file_size': fileBytes?.length,
        'reply_to': replyTo,
        'is_read': false,
      };

      final response = await _supabase.from('messages').insert(messageData).select().single();
      
      // Save locally immediately
      await LocalDbService.saveItems('messages', [
        {
          ...response,
          'is_read': response['is_read'] ? 1 : 0,
          'is_edited': response['is_edited'] ? 1 : 0,
        }
      ]);

      // Trigger notification
      if (groupId == null) {
        await createNotification(
          userId: receiver,
          type: 'message',
          title: 'New Message from @$sender',
          body: text.isNotEmpty ? text : (type == 'image' ? 'Sent a photo' : 'Sent a file'),
          referenceId: response['id'].toString(),
        );
      }

      return true;
    } catch (e) {
      debugPrint('Send message error: $e');
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
      await _supabase.from('messages').update({
        'content': null,
        'file_url': null,
        'file_name': null,
        'type': 'system',
        'is_deleted': true,
      }).eq('id', messageId);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteMessageForMe(String messageId) async {
    try {
      final myUser = await getUsername();
      if (myUser == null) return false;
      
      await _supabase.rpc('append_to_array_unique', params: {
        'table_name': 'messages',
        'column_name': 'deleted_for',
        'new_element': myUser,
        'row_id': messageId
      });
      await LocalDbService.markAsDeletedForMe(messageId.toString(), myUser);
      return true;
    } catch (e) {
      debugPrint('Delete for me error: $e');
      return false;
    }
  }

  static Future<bool> leaveGroup(String groupId) async {
    try {
      final myUser = await getUsername();
      if (myUser == null) return false;
      await _supabase.from('group_members').delete().match({
        'group_id': groupId,
        'user_id': myUser
      });
      return true;
    } catch (e) {
      debugPrint('Leave group error: $e');
      return false;
    }
  }

  static Future<bool> deleteGroup(String groupId) async {
    try {
      await _supabase.from('groups').delete().eq('id', groupId);
      return true;
    } catch (e) {
      debugPrint('Delete group error: $e');
      return false;
    }
  }

  static Future<bool> updateTask(String taskId, Map<String, dynamic> updates) async {
    try {
      await _supabase.from('tasks').update(updates).eq('id', taskId);
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
      debugPrint('Reaction error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getReactions(String messageId) async {
    try {
      return await _supabase.from('message_reactions').select().eq('message_id', messageId);
    } catch (e) {
      debugPrint('Get Suggested Users Error: $e');
      return [];
    }
  }

  static Future<void> markMessagesAsRead(String myUsername, String otherUsername, {String? groupId}) async {
    try {
      if (groupId != null) {
        // Mark group messages as read for me? 
        // Usually groups don't have a single 'is_read' flag per message for everyone
        // but we can mark them locally.
        return;
      }
      final convId = getConversationId(myUsername, otherUsername);
      await _supabase
          .from('messages')
          .update({'is_read': true})
          .match({'conversation_id': convId, 'receiver_id': myUsername, 'is_read': false});
    } catch (e) {
      debugPrint('Mark as read error: $e');
    }
  }

  static String getConversationId(String u1, String u2) {
    final list = [u1, u2];
    list.sort();
    return list.join('_');
  }

  static Future<List<Map<String, dynamic>>> getMessages(String user1, String user2, {String? groupId}) async {
    final myUser = await getUsername();
    final convId = groupId == null ? getConversationId(user1, user2) : null;
    
    // 1. Get from Local DB for fast load
    final localMessages = await LocalDbService.getMessages(convId, groupId);
    
    // 2. Fetch from Network in background
    _syncMessages(user1, user2, groupId: groupId);

    if (localMessages.isNotEmpty) {
      return List<Map<String, dynamic>>.from(
        localMessages
          .map((m) => _mapLocalMessage(m, user1))
          .where((m) => !(m['deleted_for'] as List).contains(myUser))
      );
    }

    // If local is empty, wait for network (first time load)
    try {
      List<dynamic> data;
      if (groupId != null) {
        data = await _supabase
            .from('messages')
            .select()
            .eq('group_id', groupId)
            .order('created_at', ascending: true);
      } else {
        data = await _supabase
            .from('messages')
            .select()
            .eq('conversation_id', convId!)
            .order('created_at', ascending: true);
      }
      
      await _saveMessagesLocally(data);
      
      // Fetch reactions for these messages
      final ids = data.map((m) => m['id']).toList();
      final reactionsRes = await _supabase.from('message_reactions').select().inFilter('message_id', ids);
      final reactions = List<Map<String, dynamic>>.from(reactionsRes);

      return List<Map<String, dynamic>>.from(
        data
          .where((m) => m['deleted_for'] == null || !(m['deleted_for'] as List).contains(myUser))
          .map((m) {
            final mReactions = reactions.where((r) => r['message_id'] == m['id']).toList();
            return {
              ..._mapMessage(m, user1),
              'reactions': mReactions,
            };
          })
      );
    } catch (e) {
      debugPrint('Get Suggested Users Error: $e');
      return [];
    }
  }

  static Future<void> _syncMessages(String user1, String user2, {String? groupId}) async {
    try {
      final convId = groupId == null ? getConversationId(user1, user2) : null;
      List<dynamic> data;
      if (groupId != null) {
        data = await _supabase.from('messages').select().eq('group_id', groupId).order('created_at', ascending: true);
      } else {
        data = await _supabase.from('messages').select().eq('conversation_id', convId!).order('created_at', ascending: true);
      }
      await _saveMessagesLocally(data);
    } catch (e) {
      debugPrint('Sync messages error: $e');
    }
  }

  static Future<void> _saveMessagesLocally(List<dynamic> messages) async {
    final localData = messages.map((m) => {
      'id': m['id'],
      'conversation_id': m['conversation_id'],
      'group_id': m['group_id'],
      'sender_id': m['sender_id'],
      'receiver_id': m['receiver_id'],
      'content': m['content'],
      'type': m['type'],
      'file_url': m['file_url'],
      'file_name': m['file_name'],
      'file_size': m['file_size'],
      'reply_to': m['reply_to'],
      'is_read': m['is_read'] == true ? 1 : 0,
      'is_edited': m['is_edited'] == true ? 1 : 0,
      'is_deleted': m['is_deleted'] == true ? 1 : 0,
      'deleted_for': m['deleted_for']?.toString(),
      'created_at': m['created_at'],
    }).toList();
    await LocalDbService.saveItems('messages', localData);

    // Also fetch and save reactions in batch
    if (messages.isNotEmpty) {
      final ids = messages.map((m) => m['id']).toList();
      final reactionsRes = await _supabase.from('message_reactions').select().inFilter('message_id', ids);
      if (reactionsRes.isNotEmpty) {
        await LocalDbService.saveItems('message_reactions', List<Map<String, dynamic>>.from(reactionsRes));
      }
    }
  }

  static Map<String, dynamic> _mapLocalMessage(Map<String, dynamic> m, String myUser) {
    List<String> deletedFor = [];
    if (m['deleted_for'] != null && m['deleted_for'].toString().isNotEmpty) {
      deletedFor = m['deleted_for'].toString().replaceAll('[', '').replaceAll(']', '').split(',').map((e) => e.trim()).toList();
    }
    
    return {
      'id': m['id'],
      'sender': m['sender_id'],
      'text': m['content'],
      'mediaUrl': m['file_url'],
      'fileName': m['file_name'],
      'fileSize': m['file_size'],
      'type': m['type'],
      'timestamp': m['created_at'],
      'reply_to': m['reply_to'],
      'is_read': m['is_read'] == 1,
      'is_edited': m['is_edited'] == 1,
      'is_deleted': m['is_deleted'] == 1,
      'isMe': m['sender_id'] == myUser,
      'deleted_for': deletedFor,
      'reactions': m['reactions'] ?? [],
    };
  }

  static Map<String, dynamic> _mapMessage(Map<String, dynamic> m, String myUser) {
    return {
      'id': m['id'],
      'sender': m['sender_id'],
      'text': m['content'],
      'mediaUrl': m['file_url'],
      'fileName': m['file_name'],
      'fileSize': m['file_size'],
      'type': m['type'],
      'timestamp': m['created_at'],
      'reply_to': m['reply_to'],
      'is_read': m['is_read'],
      'is_edited': m['is_edited'],
      'is_deleted': m['is_deleted'] == true,
      'isMe': m['sender_id'] == myUser,
      'deleted_for': m['deleted_for'],
    };
  }

  static Future<List<Map<String, dynamic>>> getConversations(String username) async {
    // 1. Get from Local
    final localConvs = await LocalDbService.getConversations();
    
    // 2. background sync
    _syncConversations(username);

    if (localConvs.isNotEmpty) {
      return localConvs.map((c) => {
        '_id': c['other_user'],
        'groupId': c['group_id'],
        'lastMessage': c['last_message'],
        'timestamp': c['updated_at'],
        'profilePic': c['profile_pic'],
        'isOnline': c['is_online'] == 1,
        'unreadCount': c['unread_count'],
        'isGroup': c['is_group'] == 1,
      }).toList();
    }

    try {
      // Fetch Direct Conversations
      final List<dynamic> data = await _supabase
          .from('conversations')
          .select()
          .contains('participants', [username])
          .order('updated_at', ascending: false);
      
      List<Map<String, dynamic>> results = [];
      for (var conv in data) {
        final participants = conv['participants'] as List;
        final otherUser = participants.firstWhere((p) => p != username, orElse: () => null);
        if (otherUser == null) continue;

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
          'unreadCount': unreadCount,
          'isGroup': false,
        });
      }

      // Fetch Groups
      final myGroups = await getMyGroups();
      for (var group in myGroups) {
        final List<dynamic> lastMsgRes = await _supabase
            .from('messages')
            .select()
            .eq('group_id', group['id'])
            .order('created_at', ascending: false)
            .limit(1);
        
        String lastMsg = "No messages yet";
        String timestamp = group['created_at'];
        
        if (lastMsgRes.isNotEmpty) {
          final m = lastMsgRes.first;
          lastMsg = m['type'] == 'image' ? "📷 Photo" : (m['type'] == 'audio' ? "🎤 Voice Message" : (m['content'] ?? "Media"));
          timestamp = m['created_at'];
        }

        results.add({
          '_id': group['name'],
          'groupId': group['id'],
          'lastMessage': lastMsg,
          'timestamp': timestamp,
          'profilePic': group['avatar_url'],
          'isOnline': false,
          'unreadCount': 0, // Simplified for now
          'isGroup': true,
        });
      }

      // Sort by timestamp
      results.sort((a, b) => DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp'])));

      await _saveConversationsLocally(results);
      return results;
    } catch (e) {
      debugPrint('Get conversations error: $e');
      return [];
    }
  }

  static Future<void> _syncConversations(String username) async {
    try {
      // Direct Chats
      final List<dynamic> data = await _supabase
          .from('conversations')
          .select()
          .contains('participants', [username])
          .order('updated_at', ascending: false);
      
      List<Map<String, dynamic>> results = [];
      for (var conv in data) {
        final participants = conv['participants'] as List;
        final otherUser = participants.firstWhere((p) => p != username, orElse: () => null);
        if (otherUser == null) continue;

        final profile = await getProfile(otherUser);
        final List<dynamic> unreadCountRes = await _supabase
            .from('messages')
            .select('id')
            .eq('conversation_id', conv['id'])
            .eq('receiver_id', username)
            .eq('is_read', false);
        results.add({
          '_id': otherUser,
          'lastMessage': conv['last_message'],
          'timestamp': conv['updated_at'],
          'profilePic': profile?['profilePic'],
          'isOnline': profile?['isOnline'],
          'unreadCount': unreadCountRes.length,
          'isGroup': false,
          'groupId': null
        });
      }

      // Groups
      final myGroups = await getMyGroups();
      for (var group in myGroups) {
        final List<dynamic> lastMsgRes = await _supabase
            .from('messages')
            .select()
            .eq('group_id', group['id'])
            .order('created_at', ascending: false)
            .limit(1);
        
        String lastMsg = "No messages yet";
        String timestamp = group['created_at'];
        
        if (lastMsgRes.isNotEmpty) {
          final m = lastMsgRes.first;
          lastMsg = m['type'] == 'image' ? "📷 Photo" : (m['type'] == 'audio' ? "🎤 Voice Message" : (m['content'] ?? "Media"));
          timestamp = m['created_at'];
        }

        results.add({
          '_id': group['name'],
          'groupId': group['id'],
          'lastMessage': lastMsg,
          'timestamp': timestamp,
          'profilePic': group['avatar_url'],
          'isOnline': false,
          'unreadCount': 0,
          'isGroup': true,
        });
      }

      results.sort((a, b) => DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp'])));
      await _saveConversationsLocally(results);
    } catch (e) {
      debugPrint('Sync conversations error: $e');
    }
  }

  static Future<void> _saveConversationsLocally(List<Map<String, dynamic>> convs) async {
    final localData = convs.map((c) => {
      'id': c['isGroup'] == true ? c['groupId'] : c['_id'],
      'last_message': c['lastMessage'],
      'updated_at': c['timestamp'],
      'other_user': c['_id'],
      'profile_pic': c['profilePic'],
      'is_online': c['isOnline'] == true ? 1 : 0,
      'unread_count': c['unreadCount'],
      'is_group': c['isGroup'] == true ? 1 : 0,
      'group_id': c['groupId']
    }).toList();
    await LocalDbService.saveItems('conversations', localData);
  }

  // GROUP MANAGEMENT
  static Future<String?> createGroup(String name, String description, List<String> members) async {
    try {
      final myUser = await getUsername();
      if (myUser == null) return null;

      final res = await _supabase.from('groups').insert({
        'name': name,
        'description': description,
        'created_by': myUser,
        'only_admins_message': false,
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
    } catch (e, stack) {
      print('Create group error: $e');
      print(stack);
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
      debugPrint('Get Suggested Users Error: $e');
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

      final res = await _supabase.from('tasks').insert({
        'title': title,
        'description': description,
        'assigned_to': assignedTo,
        'created_by': myUser,
        'due_date': dueDate?.toIso8601String(),
        'source_message_id': sourceMessageId,
        'conversation_id': conversationId,
        'group_id': groupId,
        'status': 'pending'
      }).select().single();

      // Trigger notification if assigned to someone else
      if (assignedTo != myUser) {
        await createNotification(
          userId: assignedTo,
          type: 'task',
          title: 'New Task Assigned',
          body: 'You were assigned: $title',
          referenceId: res['id'].toString(),
        );
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getTasks(String filter) async {
    try {
      final myUser = await getUsername();
      if (myUser == null) return [];

      // 1. Get from Local
      final localTasks = await LocalDbService.getTasks(filter, myUser);
      
      // 2. background sync
      _syncTasks(filter, myUser);

      if (localTasks.isNotEmpty) {
        return localTasks;
      }

      var query = _supabase.from('tasks').select();
      if (filter == 'assigned_to_me') {
        query = query.eq('assigned_to', myUser);
      } else if (filter == 'created_by_me') {
        query = query.eq('created_by', myUser);
      } else if (filter == 'done') {
        query = query.eq('status', 'completed');
      }

      final List<dynamic> data = await query.order('created_at', ascending: false);
      await _saveTasksLocally(data);
      return List<Map<String, dynamic>>.from(data.map((t) => Map<String, dynamic>.from(t)));
    } catch (e) {
      debugPrint('Get Suggested Users Error: $e');
      return [];
    }
  }

  static Future<void> _syncTasks(String filter, String myUser) async {
    try {
      var query = _supabase.from('tasks').select();
      if (filter == 'assigned_to_me') {
        query = query.eq('assigned_to', myUser);
      } else if (filter == 'created_by_me') {
        query = query.eq('created_by', myUser);
      } else if (filter == 'done') {
        query = query.eq('status', 'completed');
      }
      final List<dynamic> data = await query.order('created_at', ascending: false);
      await _saveTasksLocally(data);
    } catch (e) {
      print('Sync tasks error: $e');
    }
  }

  static Future<void> _saveTasksLocally(List<dynamic> tasks) async {
    final localData = tasks.map((t) => Map<String, dynamic>.from(t)).toList();
    await LocalDbService.saveItems('tasks', localData);
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

  static RealtimeChannel getGlobalSignalingChannel(String username, Function(Map<String, dynamic>) callback) {
    return _supabase
        .channel('signaling:$username')
        .onBroadcast(
          event: 'signal',
          callback: (payload) {
            if (payload['type'] == 'call_invite' && payload['receiver_id'] == username) {
              callback(payload);
            }
          },
        )
        .subscribe();
  }

  static Future<Map<String, dynamic>?> getTaskContext(Map<String, dynamic> task) async {
    try {
      if (task['group_id'] != null) {
        final group = await _supabase.from('groups').select().eq('id', task['group_id']).single();
        return {
          'name': group['name'],
          'groupId': group['id'],
        };
      } else if (task['conversation_id'] != null) {
        final myUser = await getUsername();
        final participants = (task['conversation_id'] as String).split('_');
        final otherUser = participants.firstWhere((p) => p != myUser);
        return {
          'name': otherUser,
          'groupId': null,
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // CALL MANAGEMENT
  static Future<String?> createCallRecord({
    required String callerId,
    required String receiverId,
    required String type,
  }) async {
    try {
      final res = await _supabase.from('calls').insert({
        'caller_id': callerId,
        'receiver_id': receiverId,
        'type': type,
        'status': 'calling',
      }).select().single();
      return res['id'].toString();
    } catch (e) {
      print('Create call record error: $e');
      return null;
    }
  }

  static Future<void> updateCallStatus(String callId, String status) async {
    try {
      final Map<String, dynamic> data = {'status': status};
      if (status == 'connected') {
        data['answered_at'] = DateTime.now().toIso8601String();
      } else if (status == 'ended' || status == 'rejected' || status == 'cancelled') {
        data['ended_at'] = DateTime.now().toIso8601String();
      }
      
      final res = await _supabase.from('calls').update(data).eq('id', callId).select().single();
      
      // Trigger Missed Call Notification
      if (status == 'cancelled' || status == 'rejected') {
        final bool answered = res['answered_at'] != null;
        if (!answered) {
          await createNotification(
            userId: res['receiver_id'],
            type: 'missed_call',
            title: 'Missed ${res['type']} call',
            body: 'From @${res['caller_id']}',
            referenceId: callId,
          );
        }
      }
    } catch (e) {
      print('Update call status error: $e');
    }
  }

  static Future<Map<String, dynamic>?> getCallDetails(String callId) async {
    // Fetch detailed call info including profile data
    try {
      final data = await _supabase
          .from('calls')
          .select('*, caller:profiles!calls_caller_id_fkey(*), receiver:profiles!calls_receiver_id_fkey(*)')
          .eq('id', callId)
          .single();
      
      final myUser = await getUsername();
      final bool isOutgoing = data['caller_id'] == myUser;
      final profile = isOutgoing ? data['receiver'] : data['caller'];

      return {
        ...data,
        'isOutgoing': isOutgoing,
        'otherUser': profile['username'],
        'profilePic': profile['avatar_url'],
      };
    } catch (e) {
      print('Error fetching call details: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getCallHistory() async {
    try {
      final myUser = await getUsername();
      if (myUser == null) return [];
      
      final List<dynamic> data = await _supabase
          .from('calls')
          .select('*, caller:profiles!calls_caller_id_fkey(*), receiver:profiles!calls_receiver_id_fkey(*)')
          .or('caller_id.eq.$myUser,receiver_id.eq.$myUser')
          .order('created_at', ascending: false);
      
      final List<Map<String, dynamic>> results = data.map((call) {
        final item = Map<String, dynamic>.from(call);
        final bool isOutgoing = item['caller_id'] == myUser;
        final profile = isOutgoing ? item['receiver'] : item['caller'];
        return {
          ...item,
          'isOutgoing': isOutgoing,
          'otherUser': profile['username'],
          'profilePic': profile['avatar_url'],
        };
      }).toList().cast<Map<String, dynamic>>();
      return results;
    } catch (e) {
      print('Get call history error: $e');
      return [];
    }
  }

  // REAL-TIME HELPERS
  static RealtimeChannel getMessageChannel(String user1, String user2, Function(Map<String, dynamic>) callback, {String? groupId}) {
    if (groupId != null) {
      return _supabase
          .channel('group_chat:$groupId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'group_id',
              value: groupId,
            ),
            callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.delete) {
              final oldId = payload.oldRecord['id'];
              LocalDbService.deleteItem('messages', oldId.toString());
              callback({'id': oldId, 'action': 'delete'});
            } else {
              final record = payload.newRecord;
              _saveMessagesLocally([record]);
              callback(record);
            }
          },
          )
          .subscribe();
    }
    
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
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.delete) {
              final oldId = payload.oldRecord['id'];
              LocalDbService.deleteItem('messages', oldId.toString());
              callback({'id': oldId, 'action': 'delete'});
            } else {
              final record = payload.newRecord;
              _saveMessagesLocally([record]);
              callback(record);
            }
          },
        )
        .subscribe();
  }

  static void sendTypingStatus(String sender, String target, bool isTyping, {String? groupId}) {
    _supabase.from('messages').insert({
      'conversation_id': 'typing_signal',
      'sender_id': sender,
      'receiver_id': groupId == null ? target : null,
      'group_id': groupId,
      'content': isTyping ? 'typing' : 'stopped',
      'type': 'system'
    });
  }

  static RealtimeChannel getTypingChannel(String user1, String user2, Function(Map<String, dynamic>) callback, {String? groupId}) {
    final filter = groupId != null 
      ? PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'group_id', value: groupId)
      : PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conversation_id', value: 'typing_signal');

    return _supabase
        .channel('typing_signals')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: filter,
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.delete) {
              final oldId = payload.oldRecord['id'];
              LocalDbService.deleteItem('messages', oldId.toString());
              callback({'id': oldId, 'action': 'delete'});
            } else {
              final record = payload.newRecord;
              _saveMessagesLocally([record]);
              callback(record);
            }
          },
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
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.delete) {
              final oldId = payload.oldRecord['id'];
              LocalDbService.deleteItem('messages', oldId.toString());
              callback({'id': oldId, 'action': 'delete'});
            } else {
              final record = payload.newRecord;
              _saveMessagesLocally([record]);
              callback(record);
            }
          },
        )
        .subscribe();
  }

  static RealtimeChannel getTasksChannel(String username, Function() callback) {
    return _supabase
        .channel('public:tasks')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tasks',
          callback: (payload) => callback(),
        )
        .subscribe();
  }

  static RealtimeChannel getNotificationsChannel(String username, Function() callback) {
    return _supabase
        .channel('public:notifications:user_id=eq.$username')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: username,
          ),
          callback: (payload) => callback(),
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

  // NOTIFICATIONS
  static Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    String? body,
    String? referenceId,
  }) async {
    try {
      final senderId = await getUsername();
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'sender_id': senderId,
        'type': type,
        'title': title,
        'body': body,
        'reference_id': referenceId,
        'is_read': false,
      });
    } catch (e) {
      print('Create notification error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final myUser = await getUsername();
      if (myUser == null) return [];
      
      final List<dynamic> data = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', myUser)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(data.map((n) => Map<String, dynamic>.from(n)));
    } catch (e) {
      debugPrint('Get Suggested Users Error: $e');
      return [];
    }
  }

  static Future<void> markNotificationAsRead(String id) async {
    try {
      await _supabase.from('notifications').update({'is_read': true}).eq('id', id);
    } catch (e) {
      print('Mark notification read error: $e');
    }
  }

  static Future<void> markAllNotificationsAsRead() async {
    try {
      final myUser = await getUsername();
      if (myUser != null) {
        await _supabase
            .from('notifications')
            .update({'is_read': true})
            .eq('user_id', myUser)
            .eq('is_read', false);
      }
    } catch (e) {
      print('Mark all notifications read error: $e');
    }
  }

  static Future<bool> deleteNotification(String id) async {
    try {
      await _supabase.from('notifications').delete().eq('id', id);
      return true;
    } catch (e) {
      print('Delete notification error: $e');
      return false;
    }
  }

  // GROUP MANAGEMENT ADVANCED
  static Future<int> getGroupMemberCount(String groupId) async {
    try {
      final List<dynamic> res = await _supabase.from('group_members').select('user_id').eq('group_id', groupId);
      return res.length;
    } catch (e) {
      return 0;
    }
  }

  static Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    try {
      final List<dynamic> data = await _supabase
          .from('group_members')
          .select('*, profiles(*)')
          .eq('group_id', groupId);
      
      return List<Map<String, dynamic>>.from(data.map((m) {
        final profile = m['profiles'] as Map<String, dynamic>;
        return {
          'user_id': m['user_id'],
          'role': m['role'],
          'joined_at': m['joined_at'],
          'username': profile['username'],
          'profilePic': profile['avatar_url'],
          'isOnline': profile['is_online'],
        };
      }));
    } catch (e) {
      print('Get members error: $e');
      return [];
    }
  }

  static Future<bool> addGroupMember(String groupId, String username) async {
    try {
      await _supabase.from('group_members').insert({
        'group_id': groupId,
        'user_id': username,
        'role': 'member'
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> removeGroupMember(String groupId, String username) async {
    try {
      await _supabase.from('group_members').delete().match({
        'group_id': groupId,
        'user_id': username
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateMemberRole(String groupId, String username, String role) async {
    try {
      await _supabase.from('group_members').update({'role': role}).match({
        'group_id': groupId,
        'user_id': username
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateGroupSettings(String groupId, Map<String, dynamic> settings) async {
    try {
      await _supabase.from('groups').update(settings).eq('id', groupId);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> pinMessage(String messageId, bool isPinned) async {
    try {
      await _supabase.from('messages').update({'is_pinned': isPinned}).eq('id', messageId);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getGroupDetails(String groupId) async {
    try {
      return await _supabase.from('groups').select().eq('id', groupId).single();
    } catch (e) {
      return null;
    }
  }

  // CONTACTS FETCH
  static Future<List<Map<String, dynamic>>> getMyContacts() async {
    try {
      final myUser = await getUsername();
      if (myUser == null) return [];
      
      final List<dynamic> data = await _supabase
          .from('contacts')
          .select('contact_id, profiles(*)')
          .eq('user_id', myUser);
      
      return data.map((c) {
        final item = Map<String, dynamic>.from(c);
        final profile = item['profiles'] as Map<String, dynamic>;
        return {
          'username': profile['username'],
          'profilePic': profile['avatar_url'],
          'isOnline': profile['is_online'],
          'about': profile['about'],
        };
      }).toList();
    } catch (e) {
      print('Get contacts error: $e');
      return [];
    }
  }

  static Future<bool> deleteAccount(String username) async {
    try {
      final usernameLower = username.toLowerCase();
      
      // 1. First, try to call the secure DB function to delete the auth account
      // This will trigger the CASCADE delete for the profile and all linked tables.
      try {
        await _supabase.rpc('delete_own_user');
      } catch (e) {
        print('RPC delete_own_user failed, falling back to manual: $e');
        
        // 2. Manual Fallback (Only if RPC fails/doesn't exist)
        // We delete from child tables first to avoid FK constraints
        await _supabase.from('group_members').delete().eq('user_id', usernameLower);
        await _supabase.from('tasks').delete().or('created_by.eq.${usernameLower},assigned_to.eq.${usernameLower}');
        await _supabase.from('contact_requests').delete().or('sender_id.eq.${usernameLower},receiver_id.eq.${usernameLower}');
        await _supabase.from('contacts').delete().or('user_id.eq.${usernameLower},contact_id.eq.${usernameLower}');
        await _supabase.from('message_reactions').delete().eq('user_id', usernameLower);
        await _supabase.from('messages').delete().eq('sender_id', usernameLower);
        await _supabase.from('profiles').delete().eq('username', usernameLower);
      }

      // 3. Clear Local Data and Logout
      await LocalDbService.clearAll();
      await logout();

      return true;
    } catch (e) {
      print('Delete account error: $e');
      return false;
    }
  }
}
