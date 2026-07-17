import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/reply_history.dart';

/// SQLite-backed history of replies the user actually sent.
class HistoryService {
  Database? _db;

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final path = await getDatabasesPath();
    _db = await openDatabase(
      p.join(path, 'replygenius.db'),
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE reply_history (
            id TEXT PRIMARY KEY,
            channel TEXT,
            sender TEXT,
            incoming_message TEXT,
            sent_reply TEXT,
            anger_score INTEGER,
            timestamp TEXT
          )
        ''');
      },
    );
    return _db!;
  }

  Future<void> insert(ReplyHistoryEntry entry) async {
    final db = await _database();
    await db.insert('reply_history', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ReplyHistoryEntry>> all() async {
    final db = await _database();
    final rows = await db.query('reply_history',
        orderBy: 'timestamp DESC', limit: 500);
    return rows.map(ReplyHistoryEntry.fromMap).toList();
  }

  Future<void> clear() async {
    final db = await _database();
    await db.delete('reply_history');
  }
}
