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
      final photoId = map['photo_id'] as String;
      final photoMaps = await database.query('photos', where: 'id = ?', whereArgs: [photoId]);
      if (photoMaps.isNotEmpty) {
        final photo = PhotoModel.fromMap(photoMaps.first);
        items.add(TrashItemModel(
          id: map['id'] as String,
          photo: photo,
          deletedAt: DateTime.fromMillisecondsSinceEpoch(map['deleted_at'] as int),
          expireAt: DateTime.fromMillisecondsSinceEpoch(map['expire_at'] as int),
        ));
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
    final maps = await database.query('trash_items', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      final photoId = maps.first['photo_id'];
      await database.delete('trash_items', where: 'id = ?', whereArgs: [id]);
      await database.delete('photos', where: 'id = ?', whereArgs: [photoId]);
    }
  }

  Future<void> emptyTrash() async {
    final database = await _db.database;
    final maps = await database.query('trash_items');
    for (final map in maps) {
      await database.delete('photos', where: 'id = ?', whereArgs: [map['photo_id']]);
    }
    await database.delete('trash_items');
  }

  Future<int> getTrashedCount() async {
    final database = await _db.database;
    final result = await database.rawQuery('SELECT COUNT(*) as count FROM trash_items');
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getTrashedFileSize() async {
    final database = await _db.database;
    final result = await database.rawQuery('''
      SELECT SUM(p.file_size) as total FROM trash_items t
      JOIN photos p ON t.photo_id = p.id
    ''');
    return (result.first['total'] as int?) ?? 0;
  }
}
