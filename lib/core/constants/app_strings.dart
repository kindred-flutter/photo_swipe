class AppStrings {
  AppStrings._();

  static const String appName = 'PhotoSwipe';

  // 主界面
  static const String tabPhotos = '相册';
  static const String tabTrash = '垃圾箱';
  static const String addFromGallery = '从相册选择';
  static const String addFromCamera = '拍照';
  static const String emptyPhotos = '还没有照片';
  static const String emptyPhotosHint = '点击右下角按钮导入照片';

  // 统计条
  static const String statsTotal = '共';
  static const String statsTrash = '垃圾箱';
  static const String statsSaved = '已节省';
  static const String statsUnit = '张';
  static const String statsMB = 'MB';

  // 垃圾箱
  static const String trashTitle = '垃圾箱';
  static const String trashEmpty = '垃圾箱是空的';
  static const String trashHint = '照片将在 30 天后自动清理';
  static const String trashClear = '清空垃圾箱';
  static const String trashClearConfirm = '照片将移入系统相册垃圾箱，30天后自动删除';
  static const String trashClearConfirmBtn = '移入系统垃圾箱';
  static const String trashDeleteDirectly = '直接删除';
  static const String trashDeleteDirectlyConfirm = '照片将永久删除，不可恢复';

  // 操作
  static const String restore = '恢复';
  static const String delete = '删除';
  static const String cancel = '取消';
  static const String confirm = '确定';
  static const String selectAll = '全选';
  static const String deselectAll = '取消全选';
  static const String permanentDelete = '永久删除';
  static const String permanentDeleteConfirm = '此操作不可撤销，照片将永久删除';

  // SnackBar
  static const String movedToTrash = '已移入垃圾箱';
  static const String undoAction = '撤销';
  static const String restoredToAlbum = '已恢复到相册';

  // 权限
  static const String permissionTitle = '需要相册权限';
  static const String permissionMessage = '请允许访问相册，以便管理您的照片';
  static const String goToSettings = '去设置';

  // 照片信息
  static const String photoInfo = '照片信息';
  static const String photoSize = '文件大小';
  static const String photoResolution = '分辨率';
  static const String photoDate = '拍摄时间';
}
