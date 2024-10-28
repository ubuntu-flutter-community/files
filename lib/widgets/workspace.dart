import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:files/backend/entity_info.dart';
import 'package:files/backend/fetch.dart';
import 'package:files/backend/path_parts.dart';
import 'package:files/backend/utils.dart';
import 'package:files/backend/workspace.dart';
import 'package:files/widgets/breadcrumbs_bar.dart';
import 'package:files/widgets/context_menu.dart';
import 'package:files/widgets/folder_dialog.dart';
import 'package:files/widgets/grid.dart';
import 'package:files/widgets/table.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:yaru/yaru.dart';

class FilesWorkspace extends StatefulWidget {
  const FilesWorkspace({
    required this.controller,
    super.key,
  });
  final WorkspaceController controller;

  @override
  State<FilesWorkspace> createState() => _FilesWorkspaceState();
}

class _FilesWorkspaceState extends State<FilesWorkspace> {
  late CachingScrollController horizontalController;
  late CachingScrollController verticalController;

  WorkspaceController get controller => widget.controller;

  void _resetScrollControllers() {
    horizontalController = CachingScrollController(
      initialScrollOffset: controller.lastHorizontalScrollOffset,
    );
    verticalController = CachingScrollController(
      initialScrollOffset: controller.lastVerticalScrollOffset,
    );
  }

  @override
  void initState() {
    super.initState();
    _resetScrollControllers();
    controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    controller.lastHorizontalScrollOffset =
        horizontalController.lastPosition?.pixels ?? 0;
    controller.lastVerticalScrollOffset =
        verticalController.lastPosition?.pixels ?? 0;
    controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _setHidden(bool flag) {
    controller.showHidden = flag;
    controller.changeCurrentDir(controller.currentDir);
  }

  void _setSortType(SortType? type) {
    if (type != null) {
      controller.sortType = type;
      controller.changeCurrentDir(controller.currentDir);
    }
  }

  void _setSortOrder(bool ascending) {
    if (ascending != controller.ascending) {
      controller.ascending = ascending;
      controller.changeCurrentDir(controller.currentDir);
    }
  }

  Future<void> _createFolder() async {
    final folderNameDialog = await promptNewFolder();
    final currentDir = PathParts.parse(controller.currentDir);
    currentDir.parts.add('$folderNameDialog');
    if (folderNameDialog != null) {
      await Directory(currentDir.toPath()).create(recursive: true);
      await controller.changeCurrentDir(currentDir.toPath());
    }
  }

  void _setWorkspaceView(WorkspaceView view) {
    if (controller.view == view) return;

    setState(() {
      controller.lastHorizontalScrollOffset = 0;
      controller.lastVerticalScrollOffset = 0;
      _resetScrollControllers();
      controller.view = view;
    });
  }

  Future<String?> promptNewFolder() {
    return showDialog(
      context: context,
      builder: (context) => const FolderDialog(),
    );
  }

  String get selectedItemsLabel {
    if (controller.selectedItems.isEmpty) return '';

    late String itemLabel;

    if (controller.selectedItems.length == 1) {
      itemLabel = 'item';
    } else {
      itemLabel = 'items';
    }

    var baseString = '${controller.selectedItems.length} selected $itemLabel';

    if (controller.selectedItems.every((element) => element.isFile)) {
      final totalSize = controller.selectedItems.fold(
        0,
        (previousValue, element) => previousValue + element.stat.size,
      );
      baseString += ' ${filesize(totalSize)}';
    }

    return baseString;
  }

  void _onEntityTap(EntityInfo entity) {
    final selected = controller.selectedItems.contains(entity);
    final keysPressed =
        // TODO: remove ignore
        // ignore: deprecated_member_use
        RawKeyboard.instance.keysPressed;
    final multiSelect = keysPressed.contains(
          LogicalKeyboardKey.controlLeft,
        ) ||
        keysPressed.contains(
          LogicalKeyboardKey.controlRight,
        );

    if (!multiSelect) controller.clearSelectedItems();

    if (!selected && multiSelect) {
      controller.addSelectedItem(entity);
    } else if (selected && multiSelect) {
      controller.removeSelectedItem(entity);
    } else {
      controller.addSelectedItem(entity);
    }

    setState(() {});
  }

  void _onEntityDoubleTap(EntityInfo entity) {
    if (entity.isDirectory) {
      controller.changeCurrentDir(entity.path);
    } else {
      launchUrlString(entity.path);
    }
  }

  // To move more than one file
  void _onDropAccepted(String path) {
    for (final entity in controller.selectedItems) {
      Utils.moveFileToDest(entity.entity, path);
    }
  }

  List<BaseContextMenuItem> _getMenuEntries(BuildContext context) {
    return [
      CheckboxMenuItem(
        value: controller.showHidden,
        onChanged: (val) => _setHidden(val!),
        child: const Text('Show hidden files'),
      ),
      ContextMenuItem(
        child: const Text('Create new folder'),
        onTap: _createFolder,
      ),
      const ContextMenuDivider(),
      RadioMenuItem(
        child: const Text('Name'),
        value: SortType.name,
        groupValue: controller.sortType,
        onChanged: _setSortType,
      ),
      RadioMenuItem(
        child: const Text('Modifies'),
        value: SortType.modified,
        groupValue: controller.sortType,
        onChanged: _setSortType,
      ),
      RadioMenuItem(
        child: const Text('Size'),
        value: SortType.size,
        groupValue: controller.sortType,
        onChanged: _setSortType,
      ),
      RadioMenuItem(
        child: const Text('Type'),
        value: SortType.type,
        groupValue: controller.sortType,
        onChanged: _setSortType,
      ),
      const ContextMenuDivider(),
      RadioMenuItem<bool>(
        value: true,
        groupValue: controller.ascending,
        child: const Text('Ascending'),
        onChanged: (val) => _setSortOrder(val!),
      ),
      RadioMenuItem<bool>(
        value: false,
        groupValue: controller.ascending,
        child: const Text('Descending'),
        onChanged: (val) => _setSortOrder(val!),
      ),
      const ContextMenuDivider(),
      ContextMenuItem(
        child: const Text('Reload'),
        onTap: () async {
          await controller.getInfoForDir(Directory(controller.currentDir));
        },
      ),
    ];
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 56,
          child: _WorkspaceTopbar(
            controller: controller,
            popupBuilder: _getMenuEntries,
            onWorkspaceViewChanged: _setWorkspaceView,
          ),
        ),
        Expanded(
          child: ChangeNotifierProvider.value(
            value: controller,
            child: controller.lastError == null
                ? getBody(context)
                : _WorkspaceErrorWidget(
                    error: controller.lastError!,
                    path: controller.currentDir,
                  ),
          ),
        ),
        SizedBox(
          height: 32,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Text('${controller.currentInfo?.length ?? 0} items'),
                  const Spacer(),
                  Text(selectedItemsLabel),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget getBody(BuildContext context) {
    if (controller.currentInfo == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (controller.currentInfo!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              YaruIcons.folder,
              size: 80,
            ),
            Text(
              'This Folder is Empty',
              style: TextStyle(fontSize: 17),
            ),
          ],
        ),
      );
    }

    switch (controller.view) {
      case WorkspaceView.grid:
        return FilesGrid(
          entities: controller.currentInfo!,
          onEntityTap: _onEntityTap,
          onEntityDoubleTap: _onEntityDoubleTap,
          onDropAccept: _onDropAccepted,
          controller: verticalController,
          size: controller.gridState.size,
          onSizeChange: (value) =>
              controller.setGridState(GridViewState(size: value)),
        );
      default:
        return FilesTable(
          rows: controller.currentInfo!
              .map(
                (entity) => FilesRow(
                  entity: entity,
                  selected: controller.selectedItems.contains(entity),
                  onTap: () => _onEntityTap(entity),
                  onDoubleTap: () => _onEntityDoubleTap(entity),
                ),
              )
              .toList(),
          columns: [
            FilesColumn(
              width: controller.tableState.widths[0],
              type: FilesColumnType.name,
            ),
            FilesColumn(
              width: controller.tableState.widths[1],
              type: FilesColumnType.date,
            ),
            FilesColumn(
              width: controller.tableState.widths[2],
              type: FilesColumnType.type,
              allowSorting: false,
            ),
            FilesColumn(
              width: controller.tableState.widths[3],
              type: FilesColumnType.size,
            ),
          ],
          ascending: controller.ascending,
          columnIndex: controller.sortType.index,
          onHeaderCellTap: (newAscending, newColumnIndex) {
            if (controller.sortType.index == newColumnIndex) {
              controller.ascending = newAscending;
            } else {
              controller.ascending = true;
              controller.sortType = SortType.values[newColumnIndex];
            }
            controller.changeCurrentDir(controller.currentDir);
          },
          onHeaderResize: (newColumnIndex, details) {
            controller.setTableState(
              controller.tableState.applyDeltaToWidth(
                newColumnIndex,
                details.primaryDelta!,
              ),
            );
          },
          horizontalController: horizontalController,
          verticalController: verticalController,
        );
    }
  }
}

class _WorkspaceTopbar extends StatelessWidget {
  const _WorkspaceTopbar({
    required this.controller,
    this.onWorkspaceViewChanged,
    this.popupBuilder,
  });
  final WorkspaceController controller;
  final ValueChanged<WorkspaceView>? onWorkspaceViewChanged;
  final List<BaseContextMenuItem> Function(BuildContext context)? popupBuilder;

  @override
  Widget build(BuildContext context) {
    return BreadcrumbsBar(
      path: PathParts.parse(controller.currentDir),
      onBreadcrumbPress: controller.changeCurrentDir,
      onPathSubmitted: (path) async {
        final exists = await Directory(path).exists();

        if (exists) {
          await controller.changeCurrentDir(path);
        } else {
          await controller.changeCurrentDir(controller.currentDir);
        }
      },
      leading: [
        _HistoryModifierIconButton(
          icon: YaruIcons.go_previous,
          onPressed: controller.goToPreviousHistoryEntry,
          controller: controller,
          onHistoryOffsetChanged: controller.setHistoryOffset,
          enabled: controller.canGoToPreviousHistoryEntry,
          type: _HistoryModifierIconButtonType.left,
        ),
        _HistoryModifierIconButton(
          icon: YaruIcons.go_next,
          onPressed: controller.goToNextHistoryEntry,
          controller: controller,
          onHistoryOffsetChanged: controller.setHistoryOffset,
          enabled: controller.canGoToNextHistoryEntry,
          type: _HistoryModifierIconButtonType.right,
        ),
        const SizedBox(width: 8),
        YaruOptionButton(
          onPressed: () {
            final backDir = PathParts.parse(controller.currentDir);
            controller.changeCurrentDir(
              backDir.toPath(backDir.parts.length - 1),
            );
          },
          child: const Icon(YaruIcons.go_up, size: 20),
        ),
      ],
      actions: [
        YaruOptionButton(
          onPressed: () {
            switch (controller.view) {
              case WorkspaceView.table:
                onWorkspaceViewChanged?.call(WorkspaceView.grid);
              case WorkspaceView.grid:
                onWorkspaceViewChanged?.call(WorkspaceView.table);
            }
          },
          child: Icon(viewIcon),
        ),
        if (popupBuilder != null) const SizedBox(width: 8),
        if (popupBuilder != null)
          MenuAnchor(
            menuChildren: popupBuilder!(context)
                .map((e) => e.buildWrapper(context))
                .toList(),
            alignmentOffset: const Offset(-8, 8),
            builder: (context, controller, child) {
              return YaruOptionButton(
                onPressed: () {
                  if (controller.isOpen) return controller.close();
                  controller.open();
                },
                child: const Icon(YaruIcons.menu),
              );
            },
          ),
      ],
      loadingProgress: controller.loadingProgress,
    );
  }

  IconData get viewIcon {
    switch (controller.view) {
      case WorkspaceView.grid:
        return YaruIcons.app_grid;
      case WorkspaceView.table:
      default:
        return YaruIcons.unordered_list;
    }
  }
}

enum _HistoryModifierIconButtonType { left, right }

class _HistoryModifierIconButton extends StatelessWidget {
  const _HistoryModifierIconButton({
    required this.icon,
    required this.onPressed,
    this.enabled = true,
    this.onHistoryOffsetChanged,
    required this.controller,
    required this.type,
  });
  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;
  final ValueChanged<int>? onHistoryOffsetChanged;
  final WorkspaceController controller;
  final _HistoryModifierIconButtonType type;

  @override
  Widget build(BuildContext context) {
    return ContextMenu(
      entries: controller.history.reversed
          .mapIndexed(
            (index, e) => ContextMenuItem(
              child: Text(
                Utils.getEntityName(e),
                style: TextStyle(
                  color: index == controller.historyOffset
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
              onTap: () {
                onHistoryOffsetChanged?.call(index);
              },
            ),
          )
          .toList(),
      child: YaruOptionButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(
              left: type == _HistoryModifierIconButtonType.left
                  ? const Radius.circular(6)
                  : Radius.zero,
              right: type == _HistoryModifierIconButtonType.right
                  ? const Radius.circular(6)
                  : Radius.zero,
            ),
          ),
          backgroundColor: enabled
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Theme.of(context).colorScheme.surface,
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}

class _WorkspaceErrorWidget extends StatelessWidget {
  const _WorkspaceErrorWidget({
    required this.error,
    required this.path,
  });
  final OSError error;
  final String path;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Error while accessing '),
                TextSpan(
                  text: path,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: '\n${error.message}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class CachingScrollController extends ScrollController {
  CachingScrollController({
    super.initialScrollOffset = 0.0,
    super.keepScrollOffset = true,
    super.debugLabel,
  });

  bool _inited = false;
  ScrollPosition? lastPosition;

  @override
  void attach(ScrollPosition position) {
    lastPosition = position;
    super.attach(position);
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    late final double initialPixels;

    if (!_inited) {
      initialPixels = initialScrollOffset;
      _inited = true;
    } else {
      initialPixels = 0;
    }

    return ScrollPositionWithSingleContext(
      physics: physics,
      context: context,
      initialPixels: initialPixels,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}
