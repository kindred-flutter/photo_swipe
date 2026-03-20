import 'package:flutter/material.dart';
import '../../data/models/trash_item_model.dart';
import '../../data/repositories/trash_repository.dart';
import '../../services/photo_manager_service.dart';

class TrashProvider extends ChangeNotifier {
  final TrashRepository _repository = TrashRepository();

  List<TrashItemModel> _items = [];
  bool _isLoading = false;

  List<TrashItemModel> get items => _items;
  bool get isLoading => _isLoading;

  Future<void> loadTrashItems() async {
    _isLoading = true;
    notifyListeners();

    try {
      _items = await _repository.getAllTrashItems();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addToTrash(TrashItemModel item) async {
    try {
      await _repository.addToTrash(item);
      _items.insert(0, item);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> restoreFromTrash(String id) async {
    try {
      await _repository.restoreFromTrash(id);
      _items.removeWhere((item) => item.id == id);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> permanentDelete(String id) async {
    try {
      final item = _items.firstWhere((i) => i.id == id);
      if (item.photo.assetId.isNotEmpty) {
        await PhotoManagerService.deletePermanently([item.photo.assetId]);
      }
      await _repository.permanentDelete(id);
      _items.removeWhere((item) => item.id == id);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> emptyTrash({required bool moveToSystemTrash}) async {
    try {
      final assetIds = _items
          .where((item) => item.photo.assetId.isNotEmpty)
          .map((item) => item.photo.assetId)
          .toList();

      if (moveToSystemTrash && assetIds.isNotEmpty) {
        await PhotoManagerService.moveToSystemTrash(assetIds);
      } else if (!moveToSystemTrash && assetIds.isNotEmpty) {
        await PhotoManagerService.deletePermanently(assetIds);
      }

      await _repository.emptyTrash();
      _items.clear();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<int> getTrashedCount() async {
    return await _repository.getTrashedCount();
  }

  Future<int> getTrashedFileSize() async {
    return await _repository.getTrashedFileSize();
  }
}
