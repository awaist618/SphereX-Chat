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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages(
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
            created_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE conversations(
            id TEXT PRIMARY KEY,
            last_message TEXT,
            updated_at TEXT,
            other_user TEXT,
            profile_pic TEXT,
            is_online INTEGER,
            unread_count INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE tasks(
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
      },
    );
  }

  // Generic Save
  static Future<void> saveItems(String table, List<Map<String, dynamic>> items) async {
    final db = await database;
    Batch batch = db.batch();
    for (var item in items) {
      batch.insert(table, item, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // Get Messages
  static Future<List<Map<String, dynamic>>> getMessages(String? convId, String? groupId) async {
    final db = await database;
    String where = groupId != null ? 'group_id = ?' : 'conversation_id = ?';
    String arg = groupId ?? convId!;
    return await db.query('messages', where: where, whereArgs: [arg], orderBy: 'created_at ASC');
  }

  // Get Conversations
  static Future<List<Map<String, dynamic>>> getConversations() async {
    final db = await database;
    return await db.query('conversations', orderBy: 'updated_at DESC');
  }

  // Get Tasks
  static Future<List<Map<String, dynamic>>> getTasks(String filter, String myUser) async {
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
  }

  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('messages');
    await db.delete('conversations');
    await db.delete('tasks');
  }
}
