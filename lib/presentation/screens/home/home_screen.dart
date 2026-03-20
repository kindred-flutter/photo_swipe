import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/photo_model.dart';
import '../../../data/models/trash_item_model.dart';
import '../../providers/photo_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/trash_provider.dart';
import '../../widgets/gestures/swipe_to_delete_detector.dart';
import '../../widgets/common/glassmorphic_container.dart';
import '../photo_viewer/photo_viewer_screen.dart';
import 'widgets/stats_banner.dart';
import 'widgets/photo_tile.dart';
import '../trash/widgets/trash_tile.dart';
import '../../widgets/common/empty_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  static const _uuid = Uuid();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      context.read<PhotoProvider>().loadMore();
    }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 16),
                Text('正在同步相册...'),
              ],
            ),
            duration: Duration(seconds: 60),
          ),
        );
      }

      // 直接在主线程执行（photo_manager 不支持后台 Isolate）
      final existingAssetIds = await photoProvider.getAllAssetIds();
      final newPhotoMaps = await _fetchNewPhotosMainThread(existingAssetIds);

      if (newPhotoMaps.isNotEmpty) {
        await photoProvider.addPhotosBatch(newPhotoMaps);
      }

      await photoProvider.loadPhotos();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (newPhotoMaps.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已同步 \${newPhotoMaps.length} 张新照片')),
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
      debugPrint('Sync error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败: $e')),
        );
      }
    }
  }

  /// 在主线程中从相册获取新照片
  Future<List<Map<String, dynamic>>> _fetchNewPhotosMainThread(Set<String> existingAssetIds) async {
    final newPhotos = <Map<String, dynamic>>[];
    try {
      final albums = await PhotoManager.getAssetPathList(onlyAll: true);
      if (albums.isEmpty) return [];

      const batchSize = 100;
      int start = 0;

      while (true) {
        final assets = await albums.first.getAssetListRange(
          start: start,
          end: start + batchSize,
        );
        if (assets.isEmpty) break;

        for (final asset in assets) {
          if (existingAssetIds.contains(asset.id)) continue;
          newPhotos.add({
            'id': _uuid.v4(),
            'assetId': asset.id,
            'addedAt': (asset.createDateTime ?? DateTime.now()).millisecondsSinceEpoch,
            'takenAt': asset.createDateTime?.millisecondsSinceEpoch,
            'width': asset.width,
            'height': asset.height,
          });
        }

        if (assets.length < batchSize) break;
        start += batchSize;
      }
    } catch (e) {
      debugPrint('Fetch photos error: $e');
    }
    return newPhotos;
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

    // 先创建垃圾箱项目（此时照片还在 photos 表中）
    final trashItem = TrashItemModel.create(id: _uuid.v4(), photo: photo);
    await trashProvider.addToTrash(trashItem);

    // 再从主相册删除照片
    await photoProvider.deletePhoto(photo.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(AppStrings.movedToTrash),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: AppStrings.undoAction,
          onPressed: () async {
            // 撤销：先恢复照片到主相册，再从垃圾箱删除
            await photoProvider.addPhoto(photo);
            await trashProvider.restoreFromTrash(trashItem.id);
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
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _importFromGallery,
                tooltip: '刷新相册',
                splashRadius: 24,
              ),
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
      bottomNavigationBar: _buildGlassBottomNav(context),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _showAddPhotoOptions,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('添加'),
              elevation: 8,
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
            controller: _scrollController,
            padding: const EdgeInsets.all(AppSpacing.gridSpacing),
            // 只预加载当前屏幕上下各一屏的内容，减少内存占用
            cacheExtent: MediaQuery.of(context).size.height,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _getCrossAxisCount(context),
              mainAxisSpacing: AppSpacing.gridSpacing,
              crossAxisSpacing: AppSpacing.gridSpacing,
            ),
            itemCount: photoProvider.photos.length + (photoProvider.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= photoProvider.photos.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final photo = photoProvider.photos[index];
              return SwipeToDeleteDetector(
                onDeleted: () => _moveToTrash(photo),
                child: PhotoTile(
                  assetId: photo.assetId,
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
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: AppColors.accent.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      AppStrings.trashHint,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showClearTrashDialog(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      AppStrings.trashClear,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
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
                  return TrashTile(
                    item: item,
                    onRestore: () async {
                      await context.read<TrashProvider>().restoreFromTrash(item.id);
                      await context.read<PhotoProvider>().addPhoto(item.photo);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text(AppStrings.restoredToAlbum)),
                        );
                      }
                    },
                    onDelete: () {
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
                              },
                              child: const Text(AppStrings.delete),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGlassBottomNav(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIOS = Platform.isIOS;

    final navBar = BottomNavigationBar(
      currentIndex: _selectedIndex,
      backgroundColor: Colors.transparent,
      elevation: 0,
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
              label: Text('\${trash.items.length}'),
              child: const Icon(Icons.delete_outline),
            ),
          ),
          label: AppStrings.tabTrash,
        ),
      ],
    );

    if (!isIOS) {
      // 非 iOS 平台使用普通底部导航栏
      return BottomNavigationBar(
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
                label: Text('\${trash.items.length}'),
                child: const Icon(Icons.delete_outline),
              ),
            ),
            label: AppStrings.tabTrash,
          ),
        ],
      );
    }

    // iOS 毛玻璃底部导航栏
    return isDark
        ? GlassmorphicStyle.darkNavBar(child: navBar)
        : GlassmorphicStyle.lightNavBar(child: navBar);
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
              await context.read<TrashProvider>().emptyTrash(moveToSystemTrash: false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已永久删除')),
                );
              }
            },
            child: const Text(AppStrings.trashDeleteDirectly),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<TrashProvider>().emptyTrash(moveToSystemTrash: true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已移入系统垃圾箱')),
                );
              }
            },
            child: const Text(AppStrings.trashClearConfirmBtn),
          ),
        ],
      ),
    );
  }
}

