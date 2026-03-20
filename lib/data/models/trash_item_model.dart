import 'photo_model.dart';

class TrashItemModel {
  final String id;
  final PhotoModel photo;
  final DateTime deletedAt;
  final DateTime expireAt;

  const TrashItemModel({
    required this.id,
    required this.photo,
    required this.deletedAt,
    required this.expireAt,
  });

  bool get isExpired => DateTime.now().isAfter(expireAt);

  int get daysUntilExpiry {
    final diff = expireAt.difference(DateTime.now());
    return diff.inDays.clamp(0, 999);
  }

  factory TrashItemModel.create({
    required String id,
    required PhotoModel photo,
    int retainDays = 30,
  }) {
    final now = DateTime.now();
    return TrashItemModel(
      id: id,
      photo: photo,
      deletedAt: now,
      expireAt: now.add(Duration(days: retainDays)),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'photo_id': photo.id,
      'asset_id': photo.assetId,
      'local_path': photo.localPath,
      'thumbnail_path': photo.thumbnailPath,
      'photo_added_at': photo.addedAt.millisecondsSinceEpoch,
      'taken_at': photo.takenAt?.millisecondsSinceEpoch,
      'width': photo.width,
      'height': photo.height,
      'file_size': photo.fileSize,
      'deleted_at': deletedAt.millisecondsSinceEpoch,
      'expire_at': expireAt.millisecondsSinceEpoch,
    };
  }
}
