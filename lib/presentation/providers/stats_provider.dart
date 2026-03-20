import 'package:flutter/material.dart';
import '../../data/repositories/photo_repository.dart';
import '../../data/repositories/trash_repository.dart';

class StatsProvider extends ChangeNotifier {
  final PhotoRepository _photoRepo = PhotoRepository();
  final TrashRepository _trashRepo = TrashRepository();

  int _totalPhotos = 0;
  int _trashedPhotos = 0;
  int _savedMB = 0;

  int get totalPhotos => _totalPhotos;
  int get trashedPhotos => _trashedPhotos;
  int get savedMB => _savedMB;

  Future<void> loadStats() async {
    try {
      _totalPhotos = await _photoRepo.getTotalCount();
      _trashedPhotos = await _trashRepo.getTrashedCount();
      final bytes = await _trashRepo.getTrashedFileSize();
      _savedMB = (bytes / (1024 * 1024)).toInt();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  void updateStats(int totalPhotos, int trashedPhotos, int savedMB) {
    _totalPhotos = totalPhotos;
    _trashedPhotos = trashedPhotos;
    _savedMB = savedMB;
    notifyListeners();
  }
}
