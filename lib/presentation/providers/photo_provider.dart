import 'package:flutter/material.dart';
import '../../data/models/photo_model.dart';
import '../../data/repositories/photo_repository.dart';

class PhotoProvider extends ChangeNotifier {
  final PhotoRepository _repository = PhotoRepository();

  List<PhotoModel> _photos = [];
  final Set<String> _loadedIds = <String>{};
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  int _totalCount = 0;
  static const int _pageSize = 50;

  List<PhotoModel> get photos => _photos;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  int get totalCount => _totalCount;

  Future<void> loadPhotos() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _photos = await _repository.getPhotos(limit: _pageSize, offset: 0);
      _loadedIds
        ..clear()
        ..addAll(_photos.map((p) => p.id));
      _totalCount = await _repository.getTotalCount();
      _hasMore = _photos.length >= _pageSize;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      final morePhotos = await _repository.getPhotos(
        limit: _pageSize,
        offset: _photos.length,
      );
      if (morePhotos.isEmpty) {
        _hasMore = false;
      } else {
        final uniquePhotos = morePhotos.where((p) => _loadedIds.add(p.id)).toList();
        _photos.addAll(uniquePhotos);
        _hasMore = morePhotos.length >= _pageSize;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addPhoto(PhotoModel photo) async {
    try {
      await _repository.addPhoto(photo);
      final inserted = _loadedIds.add(photo.id);
      if (inserted) {
        _photos.insert(0, photo);
      }
      if (inserted) {
        _totalCount++;
      } else {
        _totalCount = await _repository.getTotalCount();
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deletePhoto(String id) async {
    try {
      await _repository.deletePhoto(id);
      final index = _photos.indexWhere((p) => p.id == id);
      if (index != -1) {
        _photos.removeAt(index);
      }
      _loadedIds.remove(id);
      if (_totalCount > 0) {
        _totalCount--;
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<int> getTotalCount() async {
    return await _repository.getTotalCount();
  }

  Future<int> getTotalFileSize() async {
    return await _repository.getTotalFileSize();
  }

  /// 从数据库获取所有 assetId，用于去重判断
  Future<Set<String>> getAllAssetIds() async {
    return await _repository.getAllAssetIds();
  }

  /// 批量添加照片
  Future<void> addPhotosBatch(List<Map<String, dynamic>> photoMaps) async {
    try {
      await _repository.addPhotosBatch(photoMaps);
      _photos = await _repository.getPhotos(limit: _pageSize, offset: 0);
      _loadedIds
        ..clear()
        ..addAll(_photos.map((p) => p.id));
      _totalCount = await _repository.getTotalCount();
      _hasMore = _photos.length >= _pageSize;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
