import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/date_utils.dart';
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
                      onRestore: () => _restoreItem(context, item),
                      onDelete: () => _deleteItem(context, item),
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
              _clearTrash(context, moveToSystemTrash: false);
            },
            child: const Text(AppStrings.trashDeleteDirectly),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearTrash(context, moveToSystemTrash: true);
            },
            child: const Text(AppStrings.trashClearConfirmBtn),
          ),
        ],
      ),
    );
  }

  Future<void> _clearTrash(BuildContext context, {required bool moveToSystemTrash}) async {
    try {
      await context.read<TrashProvider>().emptyTrash(moveToSystemTrash: moveToSystemTrash);
      await context.read<StatsProvider>().loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(moveToSystemTrash ? '已移入系统垃圾箱' : '已永久删除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清空失败: $e')),
        );
      }
    }
  }

  Future<void> _restoreItem(BuildContext context, dynamic item) async {
    try {
      await context.read<TrashProvider>().restoreFromTrash(item.id);
      await context.read<StatsProvider>().loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.restoredToAlbum)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('恢复失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteItem(BuildContext context, dynamic item) async {
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
                await context.read<TrashProvider>().permanentDelete(item.id);
                await context.read<StatsProvider>().loadStats();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已永久删除')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('删除失败: $e')),
                  );
                }
              }
            },
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
  }
}
