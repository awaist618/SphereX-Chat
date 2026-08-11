import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDbService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  static Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), 'spherex_local.db');
    return await openDatabase(
      path,
      version: 7, // Bumped to 7
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 5) {
          try {
            await db.execute('ALTER TABLE messages ADD COLUMN deleted_for TEXT');
          } catch (e) {}
        }
        if (oldVersion < 6) {
          try {
            await db.execute('ALTER TABLE conversations ADD COLUMN is_group INTEGER DEFAULT 0');
            await db.execute('ALTER TABLE conversations ADD COLUMN group_id TEXT');
          } catch (e) {}
        }
        if (oldVersion < 7) {
          try {
            await db.execute('ALTER TABLE messages ADD COLUMN is_deleted INTEGER DEFAULT 0');
          } catch (e) {}
        }
        await _createTables(db);
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS messages(
        id TEXT PRIMARY KEY,
        conversation_id TEXT,
        group_id TEXT,
        sender_id TEXT,
        receiver_id TEXT,
        content TEXT,
        type TEXT,
        file_url TEXT,
        file_name TEXT,
        file_size INTEGER,
        reply_to TEXT,
        is_read INTEGER,
        is_edited INTEGER,
        is_deleted INTEGER DEFAULT 0,
        deleted_for TEXT,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS conversations(
        id TEXT PRIMARY KEY,
        last_message TEXT,
        updated_at TEXT,
        other_user TEXT,
        profile_pic TEXT,
        is_online INTEGER,
        unread_count INTEGER,
        is_group INTEGER DEFAULT 0,
        group_id TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks(
        id TEXT PRIMARY KEY,
        title TEXT,
        description TEXT,
        assigned_to TEXT,
        created_by TEXT,
        due_date TEXT,
        source_message_id TEXT,
        conversation_id TEXT,
        group_id TEXT,
        status TEXT,
        created_at TEXT,
        completed_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS message_reactions(
        id TEXT PRIMARY KEY,
        message_id TEXT,
        user_id TEXT,
        reaction TEXT,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profiles(
        username TEXT PRIMARY KEY,
        about TEXT,
        phone TEXT,
        profile_pic TEXT,
        is_online INTEGER,
        last_seen TEXT
      )
    ''');
  }

  // Generic Save
  static Future<void> saveItems(String table, List<Map<String, dynamic>> items) async {
    try {
      final db = await database;
      Batch batch = db.batch();
      for (var item in items) {
        batch.insert(table, item, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } catch (e) {
      print('Error saving to $table: $e');
    }
  }

  // Get Messages
  static Future<List<Map<String, dynamic>>> getMessages(String? convId, String? groupId) async {
    try {
      final db = await database;
      String where = groupId != null ? 'group_id = ?' : 'conversation_id = ?';
      String arg = groupId ?? convId!;
      final messages = await db.query('messages', where: where, whereArgs: [arg], orderBy: 'created_at ASC');
      
      if (messages.isEmpty) return [];
      
      final messageIds = messages.map((m) => "'${m['id']}'").join(',');
      
      List<Map<String, dynamic>> reactions = [];
      try {
        reactions = await db.rawQuery('SELECT * FROM message_reactions WHERE message_id IN ($messageIds)');
      } catch (e) {
        // Table might not exist yet if no reactions synced
      }
      
      // Attach reactions to messages
      return messages.map((m) {
        final mReactions = reactions.where((r) => r['message_id'] == m['id']).toList();
        return {...m, 'reactions': mReactions};
      }).toList();
    } catch (e) {
      print('Error getting messages: $e');
      return [];
    }
  }

  // Get Conversations
  static Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final db = await database;
      return await db.query('conversations', orderBy: 'updated_at DESC');
    } catch (e) {
      return [];
    }
  }

  // Get Tasks
  static Future<List<Map<String, dynamic>>> getTasks(String filter, String myUser) async {
    try {
      final db = await database;
      String? where;
      List<String>? args;

      if (filter == 'assigned_to_me') {
        where = 'assigned_to = ?';
        args = [myUser];
      } else if (filter == 'created_by_me') {
        where = 'created_by = ?';
        args = [myUser];
      } else if (filter == 'done') {
        where = 'status = ?';
        args = ['completed'];
      }

      return await db.query('tasks', where: where, whereArgs: args, orderBy: 'created_at DESC');
    } catch (e) {
      return [];
    }
  }

  // User Profiles
  static Future<void> saveProfile(Map<String, dynamic> profile) async {
    try {
      final db = await database;
      await db.insert('user_profiles', {
        'username': profile['username'],
        'about': profile['about'],
        'phone': profile['phone'],
        'profile_pic': profile['profilePic'],
        'is_online': profile['isOnline'] == true ? 1 : 0,
        'last_seen': profile['lastSeen'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      print('Error saving profile: $e');
    }
  }

  static Future<Map<String, dynamic>?> getProfile(String username) async {
    try {
      final db = await database;
      final res = await db.query('user_profiles', where: 'username = ?', whereArgs: [username]);
      if (res.isEmpty) return null;
      final p = res.first;
      return {
        'username': p['username'],
        'about': p['about'],
        'phone': p['phone'],
        'profilePic': p['profile_pic'],
        'isOnline': p['is_online'] == 1,
        'lastSeen': p['last_seen'],
      };
    } catch (e) {
      return null;
    }
  }

  static Future<void> deleteItem(String table, String id) async {
    try {
      final db = await database;
      await db.delete(table, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('Error deleting from $table: $e');
    }
  }

  static Future<void> markAsDeletedForMe(String messageId, String myUsername) async {
    try {
      final db = await database;
      final res = await db.query('messages', where: 'id = ?', whereArgs: [messageId]);
      if (res.isNotEmpty) {
        String deletedFor = res.first['deleted_for']?.toString() ?? "";
        if (!deletedFor.contains(myUsername)) {
          deletedFor = deletedFor.isEmpty ? myUsername : "$deletedFor, $myUsername";
          await db.update('messages', {'deleted_for': deletedFor}, where: 'id = ?', whereArgs: [messageId]);
        }
      }
    } catch (e) {
      print('Error marking as deleted locally: $e');
    }
  }

  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('messages');
    await db.delete('conversations');
    await db.delete('tasks');
    await db.delete('message_reactions');
    await db.delete('user_profiles');
  }
}
