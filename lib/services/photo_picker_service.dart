import 'package:photo_manager/photo_manager.dart';
import 'package:uuid/uuid.dart';
import '../models/photo_model.dart';

class PhotoPickerService {
  static const uuid = Uuid();

  static Future<List<PhotoModel>> pickFromGallery() async {
    final albums = await PhotoManager.getAssetPathList(onlyAll: true);
    if (albums.isEmpty) return [];

    final assets = await albums.first.getAssetListRange(start: 0, end: 100);
    final photos = <PhotoModel>[];

    for (final asset in assets) {
      final file = await asset.file;
      if (file != null) {
        photos.add(PhotoModel(
          id: uuid.v4(),
          assetId: asset.id,
          localPath: file.path,
          thumbnailPath: null,
          addedAt: asset.createDateTime ?? DateTime.now(),
          takenAt: asset.createDateTime,
          width: asset.width,
          height: asset.height,
          fileSize: await file.length(),
          sourceType: 'gallery',
        ));
      }
    }

    return photos;
  }

  static Future<PhotoModel?> pickFromCamera() async {
    // 实现相机拍摄逻辑
    // 这里简化处理，实际需要集成 image_picker
    return null;
  }
}
