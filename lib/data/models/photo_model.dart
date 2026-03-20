class PhotoModel {
  final String id;
  final String assetId;
  final String? localPath;
  final String? thumbnailPath;
  final DateTime addedAt;
  final DateTime? takenAt;
  final int width;
  final int height;
  final int fileSize; // 字节
  final String? sourceType; // 'gallery' | 'camera'

  const PhotoModel({
    required this.id,
    required this.assetId,
    this.localPath,
    this.thumbnailPath,
    required this.addedAt,
    this.takenAt,
    required this.width,
    required this.height,
    required this.fileSize,
    this.sourceType,
  });

  /// 文件大小格式化，如 "3.2 MB"
  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 分辨率格式化，如 "4032 × 3024"
  String get resolutionFormatted => '$width × $height';

  PhotoModel copyWith({
    String? id,
    String? assetId,
    String? localPath,
    String? thumbnailPath,
    DateTime? addedAt,
    DateTime? takenAt,
    int? width,
    int? height,
    int? fileSize,
    String? sourceType,
  }) {
    return PhotoModel(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      localPath: localPath ?? this.localPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      addedAt: addedAt ?? this.addedAt,
      takenAt: takenAt ?? this.takenAt,
      width: width ?? this.width,
      height: height ?? this.height,
      fileSize: fileSize ?? this.fileSize,
      sourceType: sourceType ?? this.sourceType,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'asset_id': assetId,
      'local_path': localPath,
      'thumbnail_path': thumbnailPath,
      'added_at': addedAt.millisecondsSinceEpoch,
      'taken_at': takenAt?.millisecondsSinceEpoch,
      'width': width,
      'height': height,
      'file_size': fileSize,
      'source_type': sourceType,
    };
  }

  factory PhotoModel.fromMap(Map<String, dynamic> map) {
    return PhotoModel(
      id: map['id'] as String,
      assetId: map['asset_id'] as String,
      localPath: map['local_path'] as String?,
      thumbnailPath: map['thumbnail_path'] as String?,
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int),
      takenAt: map['taken_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['taken_at'] as int)
          : null,
      width: map['width'] as int,
      height: map['height'] as int,
      fileSize: map['file_size'] as int? ?? 0,
      sourceType: map['source_type'] as String?,
    );
  }
}
