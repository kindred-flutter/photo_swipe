import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/trash_item_model.dart';
import '../models/photo_model.dart';
import '../datasources/local_database.dart';

class TrashRepository {
  final LocalDatabase _db = LocalDatabase.instance;

  Future<List<TrashItemModel>> getAllTrashItems() async {
    final database = await _db.database;
    final maps = await database.query('trash_items', orderBy: 'deleted_at DESC');

    final items = <TrashItemModel>[];
    for (final map in maps) {
      try {
        // 直接从 trash_items 表重建 PhotoModel，不依赖 photos 表
        final photo = PhotoModel(
          id: map['photo_id'] as String,
          assetId: map['asset_id'] as String? ?? '',
          localPath: map['local_path'] as String?,
          thumbnailPath: map['thumbnail_path'] as String?,
          addedAt: DateTime.fromMillisecondsSinceEpoch(
              map['photo_added_at'] as int? ?? 0),
          takenAt: map['taken_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['taken_at'] as int)
              : null,
          width: map['width'] as int? ?? 0,
          height: map['height'] as int? ?? 0,
          fileSize: map['file_size'] as int? ?? 0,
          sourceType: 'gallery',
        );
        items.add(TrashItemModel(
          id: map['id'] as String,
          photo: photo,
          deletedAt: DateTime.fromMillisecondsSinceEpoch(
              map['deleted_at'] as int),
          expireAt: DateTime.fromMillisecondsSinceEpoch(
              map['expire_at'] as int),
        ));
      } catch (e) {
        debugPrint('Error loading trash item: \$e');
      }
    }
    return items;
  }

  Future<void> addToTrash(TrashItemModel item) async {
    final database = await _db.database;
    await database.insert('trash_items', item.toMap());
  }

  Future<void> restoreFromTrash(String id) async {
    final database = await _db.database;
    await database.delete('trash_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> permanentDelete(String id) async {
    final database = await _db.database;
    await database.delete('trash_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> emptyTrash() async {
    final database = await _db.database;
    await database.delete('trash_items');
  }

  Future<int> getTrashedCount() async {
    final database = await _db.database;
    final result = await database
        .rawQuery('SELECT COUNT(*) as count FROM trash_items');
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getTrashedFileSize() async {
    final database = await _db.database;
    final result = await database
        .rawQuery('SELECT SUM(file_size) as total FROM trash_items');
    return (result.first['total'] as int?) ?? 0;
  }
}
