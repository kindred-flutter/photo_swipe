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
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
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
        source_type TEXT,
        media_type TEXT DEFAULT 'image'
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_photos_asset_id ON photos(asset_id)
    ''');

    // trash_items 存储完整照片信息，不依赖 photos 表
    await db.execute('''
      CREATE TABLE trash_items (
        id TEXT PRIMARY KEY,
        photo_id TEXT,
        asset_id TEXT,
        local_path TEXT,
        thumbnail_path TEXT,
        photo_added_at INTEGER,
        taken_at INTEGER,
        width INTEGER,
        height INTEGER,
        file_size INTEGER,
        deleted_at INTEGER,
        expire_at INTEGER
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 删除旧表重建
      await db.execute('DROP TABLE IF EXISTS trash_items');
      await db.execute('''
        CREATE TABLE trash_items (
          id TEXT PRIMARY KEY,
          photo_id TEXT,
          asset_id TEXT,
          local_path TEXT,
          thumbnail_path TEXT,
          photo_added_at INTEGER,
          taken_at INTEGER,
          width INTEGER,
          height INTEGER,
          file_size INTEGER,
          deleted_at INTEGER,
          expire_at INTEGER
        )
      ''');
    }

    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE photos ADD COLUMN media_type TEXT DEFAULT 'image'",
      );
    }
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
