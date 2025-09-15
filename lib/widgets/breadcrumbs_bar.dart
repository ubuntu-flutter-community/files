import 'package:collection/collection.dart';
import 'package:files/backend/folder_provider.dart';
import 'package:files/backend/fs.dart' as fs;
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
    super.key,
  });

  final PathParts path;
  final ValueChanged<String>? onBreadcrumbPress;
  final ValueChanged<String>? onPathSubmitted;
  final List<Widget>? leading;
  final List<Widget>? actions;

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
        controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
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
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: !focusNode.hasFocus
                          ? BorderSide(color: Theme.of(context).colorScheme.outline)
                          : BorderSide.none,
                    ),
                    clipBehavior: Clip.antiAlias,
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
      final homeIndex = sortedFolders.indexWhere((e) => e.type == FolderType.home);
      sortedFolders.add(sortedFolders.removeAt(homeIndex));

      final builtinFolder = sortedFolders.firstWhereOrNull(
        (e) => widget.path.toPath().startsWith(e.directory.path),
      );

      if (builtinFolder != null) {
        final builtinParts = PathParts.parse(builtinFolder.directory.path);
        actualParts = [
          builtinParts,
          ...List.generate(
            widget.path.integralParts.length - builtinParts.integralParts.length,
            (index) => widget.path.trim(index + builtinParts.integralParts.length),
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
          final isInsideBuiltin =
              builtinFolder != null && actualParts[index].toPath() == builtinFolder.directory.path;

          return _BreadcrumbChip(
            path: actualParts[index],
            onTap: widget.onBreadcrumbPress,
            childOverride: isInsideBuiltin
                ? Row(
                    children: [
                      Icon(folderProvider.getIconForType(builtinFolder.type), size: 16),
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
  const _BreadcrumbChip({required this.path, this.onTap, this.childOverride});

  final PathParts path;
  final ValueChanged<String>? onTap;
  final Widget? childOverride;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: double.infinity,
      child: DragTarget<fs.File>(
        onAcceptWithDetails: (details) => Utils.moveFileToDest(details.data, path.toPath()),
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
