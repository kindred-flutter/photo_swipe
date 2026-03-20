import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:io';

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

  static Future<bool> moveToSystemTrash(List<String> assetIds) async {
    if (assetIds.isEmpty) return true;
    
    try {
      if (Platform.isIOS) {
        final entities = <AssetEntity>[];
        for (final assetId in assetIds) {
          final entity = await AssetEntity.fromId(assetId);
          if (entity != null) {
            entities.add(entity);
          }
        }
        if (entities.isEmpty) return true;
        final result = await PhotoManager.editor.deleteWithIds(
          entities.map((e) => e.id).toList(),
        );
        return result.isNotEmpty;
      } else if (Platform.isAndroid) {
        final entities = <AssetEntity>[];
        for (final assetId in assetIds) {
          final entity = await AssetEntity.fromId(assetId);
          if (entity != null) {
            entities.add(entity);
          }
        }
        if (entities.isEmpty) return true;
        final result = await PhotoManager.editor.android.moveToTrash(entities);
        return result.isNotEmpty;
      }
      return false;
    } catch (e) {
      debugPrint('Error moving to system trash: $e');
      return false;
    }
  }

  static Future<bool> deletePermanently(List<String> assetIds) async {
    if (assetIds.isEmpty) return true;
    
    try {
      final result = await PhotoManager.editor.deleteWithIds(assetIds);
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Error deleting permanently: $e');
      return false;
    }
  }
}
