import 'dart:io';

import 'package:collection/collection.dart';
import 'package:files/backend/folder_provider.dart';
import 'package:files/backend/path_parts.dart';
import 'package:files/backend/providers.dart';
import 'package:files/backend/utils.dart';
import 'package:flutter/material.dart';

class BreadcrumbsBar extends StatefulWidget {
  const BreadcrumbsBar({
    required this.path,
    this.onBreadcrumbPress,
    this.onPathSubmitted,
    this.leading,
    this.actions,
    this.loadingProgress,
    super.key,
  });

  final PathParts path;
  final ValueChanged<String>? onBreadcrumbPress;
  final ValueChanged<String>? onPathSubmitted;
  final List<Widget>? leading;
  final List<Widget>? actions;
  final double? loadingProgress;

  @override
  State<BreadcrumbsBar> createState() => _BreadcrumbsBarState();
}

class _BreadcrumbsBarState extends State<BreadcrumbsBar> {
  final TextEditingController controller = TextEditingController();
  final FocusNode focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _updateText();
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant BreadcrumbsBar old) {
    super.didUpdateWidget(old);

    if (widget.path != old.path) {
      _updateText();
      setState(() {});
    }
  }

  void _updateText() {
    controller.text = widget.path.toPath();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: SizedBox.expand(
          child: Row(
            children: [
              if (widget.leading != null) const SizedBox(width: 8),
              if (widget.leading != null) ...widget.leading!,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Material(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: !focusNode.hasFocus
                          ? BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                            )
                          : BorderSide.none,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _LoadingIndicator(
                      progress: widget.loadingProgress,
                      child: GestureDetector(
                        onTap: () {
                          FocusScope.of(context).requestFocus(focusNode);
                        },
                        child: Container(
                          height: double.infinity,
                          alignment: AlignmentDirectional.centerStart,
                          child: _guts,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.actions != null) ...widget.actions!,
              if (widget.actions != null) const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget get _guts {
    if (focusNode.hasFocus) {
      return TextField(
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          isDense: true,
        ),
        focusNode: focusNode,
        controller: controller,
        style: const TextStyle(fontSize: 14),
        onSubmitted: widget.onPathSubmitted,
      );
    } else {
      final List<PathParts> actualParts;

      // We need home folder on last position here to emulate a low priority entry
      final sortedFolders = folderProvider.folders;
      final homeIndex =
          sortedFolders.indexWhere((e) => e.type == FolderType.home);
      sortedFolders.add(sortedFolders.removeAt(homeIndex));

      final builtinFolder = sortedFolders.firstWhereOrNull(
        (e) => widget.path.toPath().startsWith(e.directory.path),
      );

      if (builtinFolder != null) {
        final builtinParts = PathParts.parse(builtinFolder.directory.path);
        actualParts = [
          builtinParts,
          ...List.generate(
            widget.path.integralParts.length -
                builtinParts.integralParts.length,
            (index) =>
                widget.path.trim(index + builtinParts.integralParts.length),
          ),
        ];
      } else {
        actualParts = List.generate(
          widget.path.integralParts.length,
          (index) => widget.path.trim(index),
        );
      }

      return ListView.builder(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final isInsideBuiltin = builtinFolder != null &&
              actualParts[index].toPath() == builtinFolder.directory.path;

          return _BreadcrumbChip(
            path: actualParts[index],
            onTap: widget.onBreadcrumbPress,
            childOverride: isInsideBuiltin
                ? Row(
                    children: [
                      Icon(
                        folderProvider.getIconForType(builtinFolder.type),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(Utils.getEntityName(builtinFolder.directory.path)),
                    ],
                  )
                : null,
          );
        },
        itemCount: actualParts.length,
      );
    }
  }
}

class _BreadcrumbChip extends StatelessWidget {
  const _BreadcrumbChip({
    required this.path,
    this.onTap,
    this.childOverride,
  });

  final PathParts path;
  final ValueChanged<String>? onTap;
  final Widget? childOverride;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: double.infinity,
      child: DragTarget<FileSystemEntity>(
        onAcceptWithDetails: (details) =>
            Utils.moveFileToDest(details.data, path.toPath()),
        builder: (context, candidateData, rejectedData) {
          return InkWell(
            child: Row(
              children: [
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: childOverride ?? Text(path.integralParts.last),
                ),
                const VerticalDivider(width: 2, thickness: 2),
              ],
            ),
            onTap: () => onTap?.call(path.toPath()),
          );
        },
      ),
    );
  }
}

class _LoadingIndicator extends StatefulWidget {
  const _LoadingIndicator({
    required this.progress,
    required this.child,
  });
  final double? progress;
  final Widget child;

  @override
  _LoadingIndicatorState createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<_LoadingIndicator>
    with TickerProviderStateMixin {
  late AnimationController fadeController;
  late AnimationController progressController;

  @override
  void initState() {
    super.initState();
    fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: widget.progress != null ? 1 : 0,
    );
    progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      value: widget.progress,
    );
  }

  @override
  void dispose() {
    fadeController.dispose();
    progressController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _LoadingIndicator old) {
    super.didUpdateWidget(old);

    _updateController(old);
  }

  Future<void> _updateController(_LoadingIndicator old) async {
    if (widget.progress != old.progress) {
      if (widget.progress != null && old.progress == null) {
        fadeController.value = 1;
        await progressController.animateTo(widget.progress!);
      } else if (widget.progress == null && old.progress != null) {
        await fadeController.reverse();
        progressController.value = 0;
      } else if (widget.progress != null && old.progress != null) {
        if (widget.progress! > old.progress!) {
          await progressController.animateTo(widget.progress!);
        } else if (widget.progress! < old.progress!) {
          await progressController.animateBack(widget.progress!);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([progressController, fadeController]),
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            Positioned.directional(
              textDirection: Directionality.of(context),
              top: 12,
              bottom: 12,
              end: 12,
              width: 16,
              child: FadeTransition(
                opacity: fadeController,
                child: CircularProgressIndicator(
                  value: progressController.value,
                  strokeWidth: 2,
                ),
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}
