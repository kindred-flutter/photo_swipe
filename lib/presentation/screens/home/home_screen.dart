import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
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
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/glassmorphic_container.dart';
import '../photo_viewer/photo_viewer_screen.dart';
import '../photo_viewer/delete_photo_session.dart';
import 'widgets/photo_tile.dart';
import '../trash/widgets/trash_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isSyncing = false;
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
    if (!mounted) return;
    await context.read<StatsProvider>().loadStats();
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
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      // 直接在主线程执行（photo_manager 不支持后台 Isolate）
      final existingAssetIds = await photoProvider.getAllAssetIds();
      final staleAssetIds = await _findStaleAssetIds(existingAssetIds);
      final mediaTypeBackfill = await _backfillExistingMediaTypes(existingAssetIds);
      final newPhotoMaps = await _fetchNewPhotosMainThread(existingAssetIds);

      if (staleAssetIds.isNotEmpty) {
        await photoProvider.deletePhotosByAssetIds(staleAssetIds);
      }

      if (mediaTypeBackfill.isNotEmpty) {
        await photoProvider.updateMediaTypesBatch(mediaTypeBackfill);
      }

      if (newPhotoMaps.isNotEmpty) {
        await photoProvider.addPhotosBatch(newPhotoMaps);
      }

      await photoProvider.loadPhotos();

      if (mounted && newPhotoMaps.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已同步 ${newPhotoMaps.length} 张新照片'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Sync error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<List<String>> _findStaleAssetIds(Set<String> existingAssetIds) async {
    if (existingAssetIds.isEmpty) return [];

    final staleAssetIds = <String>[];
    for (final assetId in existingAssetIds) {
      final asset = await AssetEntity.fromId(assetId);
      if (asset == null) {
        staleAssetIds.add(assetId);
      }
    }
    return staleAssetIds;
  }

  Future<Map<String, String>> _backfillExistingMediaTypes(Set<String> existingAssetIds) async {
    if (existingAssetIds.isEmpty) return {};

    final mediaTypesByAssetId = <String, String>{};

    try {
      final albums = await PhotoManager.getAssetPathList(onlyAll: true);
      if (albums.isEmpty) return {};

      const batchSize = 100;
      int start = 0;

      while (true) {
        final assets = await albums.first.getAssetListRange(
          start: start,
          end: start + batchSize,
        );
        if (assets.isEmpty) break;

        for (final asset in assets) {
          if (!existingAssetIds.contains(asset.id)) continue;
          final mediaType = _resolveMediaType(asset);
          if (mediaType != 'image') {
            mediaTypesByAssetId[asset.id] = mediaType;
          }
        }

        if (assets.length < batchSize) break;
        start += batchSize;
      }
    } catch (e) {
      debugPrint('Backfill media type error: $e');
    }

    return mediaTypesByAssetId;
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
          final mediaType = _resolveMediaType(asset);
          newPhotos.add({
            'id': _uuid.v4(),
            'assetId': asset.id,
            'addedAt': (asset.createDateTime ?? DateTime.now()).millisecondsSinceEpoch,
            'takenAt': asset.createDateTime?.millisecondsSinceEpoch,
            'width': asset.width,
            'height': asset.height,
            'mediaType': mediaType,
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

  String _resolveMediaType(AssetEntity asset) {
    try {
      if (asset.type == AssetType.video) return 'video';
      final dynamic liveFlag = asset.isLivePhoto;
      if (liveFlag == true) return 'live';
    } catch (_) {}
    return asset.type.name;
  }

  /// 刷新按钮：重新同步相册
  Future<void> _importFromGallery() async {
    await _syncFromGallery();
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.permissionTitle),
        content: const Text(AppStrings.permissionMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              PhotoManager.openSetting();
            },
            child: const Text(AppStrings.goToSettings),
          ),
        ],
      ),
    );
  }

  Future<DeletePhotoSession> _moveToTrash(PhotoModel photo) async {
    final trashProvider = context.read<TrashProvider>();
    final photoProvider = context.read<PhotoProvider>();

    // 先创建垃圾箱项目（此时照片还在 photos 表中）
    final trashItem = TrashItemModel.create(id: _uuid.v4(), photo: photo);
    await trashProvider.addToTrash(trashItem);

    // 再从主相册删除照片
    await photoProvider.deletePhoto(photo.id);

    if (!mounted) {
      return DeletePhotoSession(
        undone: ValueNotifier<bool>(false),
        trashItemId: trashItem.id,
      );
    }
    final messenger = ScaffoldMessenger.of(context);
    final countdown = ValueNotifier<int>(5);
    final undoneNotifier = ValueNotifier<bool>(false);
    var undone = false;
    var snackbarClosed = false;

    messenger.hideCurrentSnackBar();
    messenger
        .showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Expanded(
                  child: Text(AppStrings.movedToTrash),
                ),
                ValueListenableBuilder<int>(
                  valueListenable: countdown,
                  builder: (_, secondsLeft, __) {
                    return TextButton(
                      onPressed: () async {
                        if (undone || snackbarClosed) return;
                        undone = true;
                        undoneNotifier.value = true;
                        await photoProvider.addPhoto(photo);
                        await trashProvider.restoreFromTrash(trashItem.id);
                        messenger.hideCurrentSnackBar();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF7AB6FF),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text('撤销 · ${secondsLeft}s'),
                    );
                  },
                ),
              ],
            ),
          ),
        )
        .closed
        .whenComplete(() {
          snackbarClosed = true;
          countdown.dispose();
        });

    for (var i = 4; i >= 0; i--) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || undone || snackbarClosed) break;
      countdown.value = i;
    }

    return DeletePhotoSession(
      undone: undoneNotifier,
      trashItemId: trashItem.id,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<StatsProvider>(
          builder: (context, stats, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(AppStrings.appName),
              Text(
                '照片 ${stats.totalPhotos} · 垃圾箱 ${stats.trashedPhotos}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
        elevation: 0,
        actions: [
          if (_selectedIndex == 0)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isSyncing
                      ? SizedBox(
                          key: const ValueKey('syncing'),
                          width: 20,
                          height: 20,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.refresh_rounded,
                          key: ValueKey('idle'),
                        ),
                ),
                onPressed: _isSyncing ? null : _importFromGallery,
                tooltip: _isSyncing ? '正在同步相册' : '刷新相册',
                splashRadius: 24,
              ),
            ),
        ],
      ),
      body: _selectedIndex == 0 ? _buildPhotoGrid() : _buildTrashGrid(),
      bottomNavigationBar: _buildGlassBottomNav(context),
    );
  }

  Widget _buildPhotoGrid() {
    return Consumer<PhotoProvider>(
      builder: (context, photoProvider, _) {
        if (photoProvider.isLoading && photoProvider.photos.isEmpty) {
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
            itemCount: photoProvider.photos.length + (photoProvider.isLoadingMore ? 1 : 0),
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
              if (index + 12 < photoProvider.photos.length) {
                preloadThumbnails(
                  photoProvider.photos
                      .skip(index)
                      .take(12)
                      .map((p) => p.assetId)
                      .toList(),
                );
              }
              return PhotoTile(
                key: ValueKey(photo.id),
                assetId: photo.assetId,
                mediaType: photo.mediaType,
                onTap: () => _viewPhoto(photo),
                onDeleteHoldComplete: () async {
                  await _moveToTrash(photo);
                },
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
                  final messenger = ScaffoldMessenger.of(context);
                  final trashRepo = context.read<TrashProvider>();
                  final photoRepo = context.read<PhotoProvider>();
                  return TrashTile(
                    item: item,
                    onRestore: () async {
                      await trashRepo.restoreFromTrash(item.id);
                      await photoRepo.addPhoto(item.photo);
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(content: Text(AppStrings.restoredToAlbum)),
                      );
                    },
                    onDelete: () {
                      showDialog(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text(AppStrings.permanentDelete),
                          content: const Text(AppStrings.permanentDeleteConfirm),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text(AppStrings.cancel),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(foregroundColor: AppColors.error),
                              onPressed: () async {
                                Navigator.pop(dialogContext);
                                await trashRepo.permanentDelete(item.id);
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
              label: Text('${trash.items.length}'),
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
                label: Text('${trash.items.length}'),
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
    final messenger = ScaffoldMessenger.of(context);
    final trashProvider = context.read<TrashProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.trashClear),
        content: const Text(AppStrings.trashClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await trashProvider.emptyTrash(moveToSystemTrash: false);
              if (!mounted) return;
              messenger.showSnackBar(
                const SnackBar(content: Text('已永久删除')),
              );
            },
            child: const Text(AppStrings.trashDeleteDirectly),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await trashProvider.emptyTrash(moveToSystemTrash: true);
              if (!mounted) return;
              messenger.showSnackBar(
                const SnackBar(content: Text('已移入系统垃圾箱')),
              );
            },
            child: const Text(AppStrings.trashClearConfirmBtn),
          ),
        ],
      ),
    );
  }
}

