import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/photo_model.dart';
import '../../../data/models/trash_item_model.dart';
import '../../providers/photo_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/trash_provider.dart';
import '../../widgets/gestures/swipe_to_delete_detector.dart';
import '../photo_viewer/photo_viewer_screen.dart';
import 'widgets/stats_banner.dart';
import 'widgets/photo_tile.dart';
import '../../widgets/common/empty_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  static const _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _requestPermissionAndLoad();
    if (mounted) await context.read<StatsProvider>().loadStats();
  }

  Future<void> _requestPermissionAndLoad() async {
    final status = await PhotoManager.requestPermissionExtend();
    if (!mounted) return;
    if (status.isAuth || status.hasAccess) {
      await _loadPhotosFromGallery();
    } else {
      _showPermissionDialog();
    }
  }

  Future<void> _loadPhotosFromGallery() async {
    final photoProvider = context.read<PhotoProvider>();
    await photoProvider.loadPhotos();
    // 无论数据库是否为空，都执行同步（只导入新增的）
    await _syncFromGallery();
  }

  /// 同步相册：只导入数据库中没有的照片（通过 assetId 去重）
  Future<void> _syncFromGallery() async {
    final photoProvider = context.read<PhotoProvider>();
    try {
      final albums = await PhotoManager.getAssetPathList(
        onlyAll: true,
        filterOption: FilterOptionGroup(
          orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
        ),
      );
      if (albums.isEmpty) return;

      // 从数据库获取已存在的 assetId（比内存更准确）
      final existingAssetIds = await photoProvider.getAllAssetIds();

      // 分批加载，每批 100 张，直到全部加载完
      int start = 0;
      const batchSize = 100;
      int newCount = 0;

      while (true) {
        final assets = await albums.first
            .getAssetListRange(start: start, end: start + batchSize);
        if (assets.isEmpty) break;

        for (final asset in assets) {
          // 跳过已存在的
          if (existingAssetIds.contains(asset.id)) continue;

          final file = await asset.originFile;
          if (file == null) continue;

          final photo = PhotoModel(
            id: _uuid.v4(),
            assetId: asset.id,
            localPath: file.path,
            thumbnailPath: file.path,
            addedAt: asset.createDateTime ?? DateTime.now(),
            takenAt: asset.createDateTime,
            width: asset.width,
            height: asset.height,
            fileSize: await file.length(),
            sourceType: 'gallery',
          );
          await photoProvider.addPhoto(photo);
          existingAssetIds.add(asset.id);
          newCount++;
        }

        if (assets.length < batchSize) break;
        start += batchSize;
      }

      if (mounted) {
        await context.read<StatsProvider>().loadStats();
        if (newCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已同步 $newCount 张新照片')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('相册已是最新'),
                duration: Duration(seconds: 2)),
          );
        }
      }
    } catch (e) {
      debugPrint('Sync error: \$e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败: \$e')),
        );
      }
    }
  }

  /// 刷新按钮：重新同步相册
  Future<void> _importFromGallery() async {
    await _syncFromGallery();
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.permissionTitle),
        content: const Text(AppStrings.permissionMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              PhotoManager.openSetting();
            },
            child: const Text(AppStrings.goToSettings),
          ),
        ],
      ),
    );
  }

  Future<void> _moveToTrash(PhotoModel photo) async {
    final trashProvider = context.read<TrashProvider>();
    final photoProvider = context.read<PhotoProvider>();
    final statsProvider = context.read<StatsProvider>();
    final trashItem = TrashItemModel.create(id: _uuid.v4(), photo: photo);
    await trashProvider.addToTrash(trashItem);
    await photoProvider.deletePhoto(photo.id);
    await statsProvider.loadStats();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(AppStrings.movedToTrash),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: AppStrings.undoAction,
          onPressed: () async {
            await trashProvider.restoreFromTrash(trashItem.id);
            await photoProvider.addPhoto(photo);
            await statsProvider.loadStats();
          },
        ),
      ),
    );
  }

  void _viewPhoto(PhotoModel photo) {
    final photos = context.read<PhotoProvider>().photos;
    final index = photos.indexWhere((p) => p.id == photo.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewerScreen(
          photos: List.from(photos), // 传副本，避免删除时数组变动
          initialIndex: index >= 0 ? index : 0,
          onDelete: _moveToTrash,
        ),
      ),
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 900) return 4;
    if (width > 600) return 3;
    return AppSpacing.gridCrossAxisCount;
  }

  void _showAddPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text(AppStrings.addFromGallery),
              onTap: () { Navigator.pop(context); _importFromGallery(); },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text(AppStrings.addFromCamera),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('相机功能开发中')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTrashItemOptions(BuildContext context, TrashItemModel item) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restore, color: AppColors.primary),
              title: const Text(AppStrings.restore),
              onTap: () async {
                Navigator.pop(context);
                await context.read<TrashProvider>().restoreFromTrash(item.id);
                await context.read<PhotoProvider>().addPhoto(item.photo);
                await context.read<StatsProvider>().loadStats();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text(AppStrings.restoredToAlbum)),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: AppColors.error),
              title: const Text(AppStrings.permanentDelete),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text(AppStrings.permanentDelete),
                    content: const Text(AppStrings.permanentDeleteConfirm),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(AppStrings.cancel),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: AppColors.error),
                        onPressed: () async {
                          Navigator.pop(context);
                          await context.read<TrashProvider>().permanentDelete(item.id);
                          await context.read<StatsProvider>().loadStats();
                        },
                        child: const Text(AppStrings.delete),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        elevation: 0,
        actions: [
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _importFromGallery,
              tooltip: '刷新相册',
            ),
        ],
      ),
      body: Column(
        children: [
          Consumer<StatsProvider>(
            builder: (context, stats, _) => StatsBanner(
              totalPhotos: stats.totalPhotos,
              trashedPhotos: stats.trashedPhotos,
              savedMB: stats.savedMB,
            ),
          ),
          Expanded(
            child: _selectedIndex == 0 ? _buildPhotoGrid() : _buildTrashGrid(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          if (index == 1) context.read<TrashProvider>().loadTrashItems();
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.photo_library_outlined),
            activeIcon: Icon(Icons.photo_library),
            label: AppStrings.tabPhotos,
          ),
          BottomNavigationBarItem(
            icon: Consumer<TrashProvider>(
              builder: (context, trash, _) => Badge(
                isLabelVisible: trash.items.isNotEmpty,
                label: Text('${trash.items.length}'),
                child: const Icon(Icons.delete_outline),
              ),
            ),
            label: AppStrings.tabTrash,
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: _showAddPhotoOptions,
              child: const Icon(Icons.add_photo_alternate),
            )
          : null,
    );
  }

  Widget _buildPhotoGrid() {
    return Consumer<PhotoProvider>(
      builder: (context, photoProvider, _) {
        if (photoProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (photoProvider.photos.isEmpty) {
          return EmptyState(
            title: AppStrings.emptyPhotos,
            subtitle: AppStrings.emptyPhotosHint,
            onActionPressed: _requestPermissionAndLoad,
            actionLabel: AppStrings.addFromGallery,
          );
        }
        return RefreshIndicator(
          onRefresh: _importFromGallery,
          child: GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.gridSpacing),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _getCrossAxisCount(context),
              mainAxisSpacing: AppSpacing.gridSpacing,
              crossAxisSpacing: AppSpacing.gridSpacing,
            ),
            itemCount: photoProvider.photos.length,
            itemBuilder: (context, index) {
              final photo = photoProvider.photos[index];
              return SwipeToDeleteDetector(
                onDeleted: () => _moveToTrash(photo),
                child: PhotoTile(
                  thumbnailPath: photo.thumbnailPath,
                  onTap: () => _viewPhoto(photo),
                  onLongPress: () => _moveToTrash(photo),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTrashGrid() {
    return Consumer<TrashProvider>(
      builder: (context, trashProvider, _) {
        if (trashProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (trashProvider.items.isEmpty) {
          return const EmptyState(
            title: AppStrings.trashEmpty,
            subtitle: AppStrings.trashHint,
          );
        }
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              color: AppColors.primaryContainer,
              child: Row(
                children: [
                  const Expanded(
                    child: Text(AppStrings.trashHint,
                        style: TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () => _showClearTrashDialog(context),
                    child: const Text(AppStrings.trashClear,
                        style: TextStyle(
                            color: AppColors.error, fontSize: 12)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.gridSpacing),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _getCrossAxisCount(context),
                  mainAxisSpacing: AppSpacing.gridSpacing,
                  crossAxisSpacing: AppSpacing.gridSpacing,
                ),
                itemCount: trashProvider.items.length,
                itemBuilder: (context, index) {
                  final item = trashProvider.items[index];
                  return PhotoTile(
                    thumbnailPath: item.photo.thumbnailPath,
                    onTap: () => _showTrashItemOptions(context, item),
                    onLongPress: () => _showTrashItemOptions(context, item),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showClearTrashDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.trashClear),
        content: const Text(AppStrings.trashClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(context);
              await context.read<TrashProvider>().emptyTrash();
              await context.read<StatsProvider>().loadStats();
            },
            child: const Text(AppStrings.trashClearConfirmBtn),
          ),
        ],
      ),
    );
  }
}
