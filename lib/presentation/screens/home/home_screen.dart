import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/photo_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/trash_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final photoProvider = context.read<PhotoProvider>();
    final statsProvider = context.read<StatsProvider>();
    
    await photoProvider.loadPhotos();
    await statsProvider.loadStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 统计条
          Consumer<StatsProvider>(
            builder: (context, statsProvider, _) {
              return StatsBanner(
                totalPhotos: statsProvider.totalPhotos,
                trashedPhotos: statsProvider.trashedPhotos,
                savedMB: statsProvider.savedMB,
              );
            },
          ),
          // 主内容
          Expanded(
            child: _selectedIndex == 0 ? _buildPhotoGrid() : _buildTrashGrid(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          if (index == 1) {
            context.read<TrashProvider>().loadTrashItems();
          }
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.photo_library),
            label: AppStrings.tabPhotos,
          ),
          BottomNavigationBarItem(
            icon: Badge(
              label: Consumer<TrashProvider>(
                builder: (context, trashProvider, _) {
                  return Text('${trashProvider.items.length}');
                },
              ),
              child: const Icon(Icons.delete_outline),
            ),
            label: AppStrings.tabTrash,
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: _showAddPhotoOptions,
              child: const Icon(Icons.add),
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
            onActionPressed: _showAddPhotoOptions,
            actionLabel: AppStrings.addFromGallery,
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.gridSpacing),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: AppSpacing.gridCrossAxisCount,
            mainAxisSpacing: AppSpacing.gridSpacing,
            crossAxisSpacing: AppSpacing.gridSpacing,
          ),
          itemCount: photoProvider.photos.length,
          itemBuilder: (context, index) {
            final photo = photoProvider.photos[index];
            return PhotoTile(
              thumbnailPath: photo.thumbnailPath,
              onTap: () => _viewPhoto(photo),
              onLongPress: () => _deletePhoto(photo),
            );
          },
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
          return EmptyState(
            title: AppStrings.trashEmpty,
            subtitle: AppStrings.trashHint,
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.gridSpacing),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: AppSpacing.gridCrossAxisCount,
            mainAxisSpacing: AppSpacing.gridSpacing,
            crossAxisSpacing: AppSpacing.gridSpacing,
          ),
          itemCount: trashProvider.items.length,
          itemBuilder: (context, index) {
            final item = trashProvider.items[index];
            return PhotoTile(
              thumbnailPath: item.photo.thumbnailPath,
              onTap: () => _showTrashOptions(item),
            );
          },
        );
      },
    );
  }

  void _showAddPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text(AppStrings.addFromGallery),
              onTap: () {
                Navigator.pop(context);
                // TODO: 实现从相册选择
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text(AppStrings.addFromCamera),
              onTap: () {
                Navigator.pop(context);
                // TODO: 实现相机拍摄
              },
            ),
          ],
        ),
      ),
    );
  }

  void _viewPhoto(dynamic photo) {
    // TODO: 实现照片预览
  }

  void _deletePhoto(dynamic photo) {
    // TODO: 实现删除逻辑
  }

  void _showTrashOptions(dynamic item) {
    // TODO: 实现垃圾箱选项
  }
}
