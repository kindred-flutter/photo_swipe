import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();

  factory LocalDatabase() {
    return _instance;
  }

  LocalDatabase._internal();

  static LocalDatabase get instance => _instance;

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'photo_swipe.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE photos (
        id TEXT PRIMARY KEY,
        asset_id TEXT UNIQUE,
        local_path TEXT,
        thumbnail_path TEXT,
        added_at INTEGER,
        taken_at INTEGER,
        width INTEGER,
        height INTEGER,
        file_size INTEGER,
        source_type TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_photos_asset_id ON photos(asset_id)
    ''');

    await db.execute('''
      CREATE TABLE trash_items (
        id TEXT PRIMARY KEY,
        photo_id TEXT,
        deleted_at INTEGER,
        expire_at INTEGER,
        FOREIGN KEY (photo_id) REFERENCES photos(id)
      )
    ''');
  }

  Future<void> init() async {
    await database;
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
