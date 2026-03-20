import 'package:sqflite/sqflite.dart';
import '../models/photo_model.dart';
import '../datasources/local_database.dart';

class PhotoRepository {
  final LocalDatabase _db = LocalDatabase.instance;

  /// 获取照片（支持分页）
  Future<List<PhotoModel>> getPhotos({
    int limit = 50,
    int offset = 0,
    String? mediaType,
  }) async {
    final database = await _db.database;
    final maps = await database.query(
      'photos',
      where: mediaType != null && mediaType != 'all' ? 'media_type = ?' : null,
      whereArgs: mediaType != null && mediaType != 'all' ? [mediaType] : null,
      orderBy: 'added_at DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((map) => PhotoModel.fromMap(map)).toList();
  }

  /// 获取所有照片（用于兼容旧代码）
  Future<List<PhotoModel>> getAllPhotos({String? mediaType}) async {
    return await getPhotos(limit: 100000, offset: 0, mediaType: mediaType);
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

  Future<void> deletePhotosByAssetIds(List<String> assetIds) async {
    if (assetIds.isEmpty) return;
    final database = await _db.database;
    await database.delete(
      'photos',
      where: 'asset_id IN (${List.filled(assetIds.length, '?').join(',')})',
      whereArgs: assetIds,
    );
  }

  Future<void> deletePhoto(String id) async {
    final database = await _db.database;
    await database.delete('photos', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getTotalCount({String? mediaType}) async {
    final database = await _db.database;
    final result = await database.rawQuery(
      mediaType != null && mediaType != 'all'
          ? 'SELECT COUNT(*) as count FROM photos WHERE media_type = ?'
          : 'SELECT COUNT(*) as count FROM photos',
      mediaType != null && mediaType != 'all' ? [mediaType] : null,
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getTotalFileSize() async {
    final database = await _db.database;
    final result = await database.rawQuery('SELECT SUM(file_size) as total FROM photos');
    return (result.first['total'] as int?) ?? 0;
  }

  /// 批量回填已存在照片的媒体类型
  Future<void> updateMediaTypesBatch(Map<String, String> mediaTypesByAssetId) async {
    if (mediaTypesByAssetId.isEmpty) return;

    final database = await _db.database;
    final batch = database.batch();

    mediaTypesByAssetId.forEach((assetId, mediaType) {
      batch.update(
        'photos',
        {'media_type': mediaType},
        where: 'asset_id = ?',
        whereArgs: [assetId],
      );
    });

    await batch.commit(noResult: true);
  }

  /// 批量插入照片
  Future<void> addPhotosBatch(List<Map<String, dynamic>> photoMaps) async {
    if (photoMaps.isEmpty) return;
    
    final database = await _db.database;
    final batch = database.batch();
    
    for (final map in photoMaps) {
      batch.insert(
        'photos',
        {
          'id': map['id'] as String,
          'asset_id': map['assetId'] as String,
          'local_path': null,
          'thumbnail_path': null,
          'added_at': map['addedAt'] as int,
          'taken_at': map['takenAt'] as int?,
          'width': map['width'] as int,
          'height': map['height'] as int,
          'file_size': 0,
          'source_type': 'gallery',
          'media_type': map['mediaType'] as String? ?? 'image',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    
    await batch.commit(noResult: true);
  }
}
