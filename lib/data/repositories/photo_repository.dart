import 'package:sqflite/sqflite.dart';
import '../models/photo_model.dart';
import 'local_database.dart';

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
    await database.insert('photos', photo.toMap());
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
