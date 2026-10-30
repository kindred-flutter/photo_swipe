import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/trash_provider.dart';
import '../../providers/stats_provider.dart';
import '../../widgets/common/empty_state.dart';
import 'widgets/trash_tile.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  @override
  void initState() {
    super.initState();
    context.read<TrashProvider>().loadTrashItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.trashTitle),
        actions: [
          Consumer<TrashProvider>(
            builder: (context, trashProvider, _) {
              return trashProvider.items.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.delete_sweep),
                      onPressed: () => _showClearConfirmation(context),
                    )
                  : const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<TrashProvider>(
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

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.surfaceDark
                    : AppColors.primaryContainer,
                child: Text(
                  AppStrings.trashHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.gridSpacing),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: AppSpacing.gridCrossAxisCount,
                    mainAxisSpacing: AppSpacing.gridSpacing,
                    crossAxisSpacing: AppSpacing.gridSpacing,
                  ),
                  itemCount: trashProvider.items.length,
                  itemBuilder: (context, index) {
                    final item = trashProvider.items[index];
                    return TrashTile(
                      item: item,
                      onRestore: () => _restoreItem(item),
                      onDelete: () => _deleteItem(item),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showClearConfirmation(BuildContext context) {
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
            onPressed: () {
              Navigator.pop(context);
              _clearTrash(moveToSystemTrash: false);
            },
            child: const Text(AppStrings.trashDeleteDirectly),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearTrash(moveToSystemTrash: true);
            },
            child: const Text(AppStrings.trashClearConfirmBtn),
          ),
        ],
      ),
    );
  }

  Future<void> _clearTrash({required bool moveToSystemTrash}) async {
    final trashProvider = context.read<TrashProvider>();
    final statsProvider = context.read<StatsProvider>();
    try {
      await trashProvider.emptyTrash(moveToSystemTrash: moveToSystemTrash);
      await statsProvider.loadStats();
      _showSnackBar(moveToSystemTrash ? '已移入系统垃圾箱' : '已永久删除');
    } catch (e) {
      _showSnackBar('清空失败: $e');
    }
  }

  Future<void> _restoreItem(dynamic item) async {
    final trashProvider = context.read<TrashProvider>();
    final statsProvider = context.read<StatsProvider>();
    try {
      await trashProvider.restoreFromTrash(item.id);
      await statsProvider.loadStats();
      _showSnackBar(AppStrings.restoredToAlbum);
    } catch (e) {
      _showSnackBar('恢复失败: $e');
    }
  }

  Future<void> _deleteItem(dynamic item) async {
    final trashProvider = context.read<TrashProvider>();
    final statsProvider = context.read<StatsProvider>();
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
            onPressed: () async {
              Navigator.pop(context);
              try {
                await trashProvider.permanentDelete(item.id);
                await statsProvider.loadStats();
                _showSnackBar('已永久删除');
              } catch (e) {
                _showSnackBar('删除失败: $e');
              }
            },
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
