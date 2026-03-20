import 'package:photo_manager/photo_manager.dart';

class PhotoManagerService {
  static Future<bool> requestPermission() async {
    final status = await PhotoManager.requestPermissionExtend();
    return status.isAuth;
  }

  static Future<List<AssetEntity>> getPhotos() async {
    final albums = await PhotoManager.getAssetPathList(onlyAll: true);
    if (albums.isEmpty) return [];
    return await albums.first.getAssetListRange(start: 0, end: 1000);
  }

  static Future<void> moveToTrash(String assetId) async {
    // 移入系统垃圾箱的实现
    // 需要根据平台特定实现
  }

  static Future<void> deletePermanently(String assetId) async {
    // 永久删除的实现
    // 需要根据平台特定实现
  }
}
