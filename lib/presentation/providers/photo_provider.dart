import 'package:flutter/material.dart';
import '../../data/models/photo_model.dart';
import '../../data/repositories/photo_repository.dart';

class PhotoProvider extends ChangeNotifier {
  final PhotoRepository _repository = PhotoRepository();

  List<PhotoModel> _photos = [];
  bool _isLoading = false;
  String? _error;

  List<PhotoModel> get photos => _photos;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadPhotos() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _photos = await _repository.getAllPhotos();
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
      _photos.insert(0, photo);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deletePhoto(String id) async {
    try {
      await _repository.deletePhoto(id);
      _photos.removeWhere((p) => p.id == id);
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
}
