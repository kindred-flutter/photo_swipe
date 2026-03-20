import 'package:flutter/material.dart';
import '../../data/repositories/photo_repository.dart';
import '../../data/repositories/trash_repository.dart';
import 'photo_provider.dart';
import 'trash_provider.dart';

class StatsProvider extends ChangeNotifier {
  final PhotoRepository _photoRepo = PhotoRepository();
  final TrashRepository _trashRepo = TrashRepository();

  int _totalPhotos = 0;
  int _trashedPhotos = 0;
  int _savedMB = 0;
  bool _isLoading = false;

  int get totalPhotos => _totalPhotos;
  int get trashedPhotos => _trashedPhotos;
  int get savedMB => _savedMB;
  bool get isLoading => _isLoading;

  PhotoProvider? _photoProvider;
  TrashProvider? _trashProvider;

  /// 绑定 PhotoProvider 和 TrashProvider，监听变化自动刷新
  void bindProviders(PhotoProvider photoProvider, TrashProvider trashProvider) {
    // 解绑旧的监听
    _photoProvider?.removeListener(_onDataChanged);
    _trashProvider?.removeListener(_onDataChanged);

    _photoProvider = photoProvider;
    _trashProvider = trashProvider;

    // 绑定新的监听
    _photoProvider!.addListener(_onDataChanged);
    _trashProvider!.addListener(_onDataChanged);
  }

  void _onDataChanged() {
    // PhotoProvider 或 TrashProvider 数据变化时自动更新统计
    _updateFromProviders();
  }

  /// 直接从 Provider 内存数据更新统计（无需查询数据库，速度快）
  void _updateFromProviders() {
    if (_photoProvider == null || _trashProvider == null) return;

    final newTotal = _photoProvider!.totalCount;
    final newTrashed = _trashProvider!.items.length;
    final newSavedBytes = _trashProvider!.items
        .fold<int>(0, (sum, item) => sum + item.photo.fileSize);
    final newSavedMB = (newSavedBytes / (1024 * 1024)).toInt();

    if (_totalPhotos != newTotal ||
        _trashedPhotos != newTrashed ||
        _savedMB != newSavedMB) {
      _totalPhotos = newTotal;
      _trashedPhotos = newTrashed;
      _savedMB = newSavedMB;
      notifyListeners();
    }
  }

  /// 从数据库加载统计（用于初始化或需要精确数据时）
  Future<void> loadStats() async {
    _isLoading = true;
    notifyListeners();
    try {
      _totalPhotos = await _photoRepo.getTotalCount();
      _trashedPhotos = await _trashRepo.getTrashedCount();
      final bytes = await _trashRepo.getTrashedFileSize();
      _savedMB = (bytes / (1024 * 1024)).toInt();
    } catch (e) {
      debugPrint('StatsProvider error: \$e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _photoProvider?.removeListener(_onDataChanged);
    _trashProvider?.removeListener(_onDataChanged);
    super.dispose();
  }
}
