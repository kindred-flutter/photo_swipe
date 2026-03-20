import 'package:sqflite/sqflite.dart';
import '../models/photo_model.dart';
import '../datasources/local_database.dart';

class PhotoRepository {
  final LocalDatabase _db = LocalDatabase.instance;

  Future<List<PhotoModel>> getAllPhotos() async {
    final database = await _db.database;
    final maps = await database.query('photos', orderBy: 'added_at DESC');
    return maps.map((map) => PhotoModel.fromMap(map)).toList();
  }

  Future<PhotoModel?> getPhotoById(String id) async {
    final database = await _db.database;
    final maps = await database.query('photos', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return PhotoModel.fromMap(maps.first);
  }

  Future<void> addPhoto(PhotoModel photo) async {
    final database = await _db.database;
    // 用 IGNORE 冲突策略，asset_id 重复时跳过
    await database.insert(
      'photos',
      photo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 获取所有已存储的 assetId 集合，用于去重
  Future<Set<String>> getAllAssetIds() async {
    final database = await _db.database;
    final result = await database.query('photos', columns: ['asset_id']);
    return result.map((row) => row['asset_id'] as String).toSet();
  }

  Future<void> deletePhoto(String id) async {
    final database = await _db.database;
    await database.delete('photos', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getTotalCount() async {
    final database = await _db.database;
    final result = await database.rawQuery('SELECT COUNT(*) as count FROM photos');
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getTotalFileSize() async {
    final database = await _db.database;
    final result = await database.rawQuery('SELECT SUM(file_size) as total FROM photos');
    return (result.first['total'] as int?) ?? 0;
  }
}
