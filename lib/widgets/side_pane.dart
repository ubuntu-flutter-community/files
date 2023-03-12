import 'dart:io';

import 'package:files/backend/folder_provider.dart';
import 'package:files/backend/workspace.dart';
import 'package:files/widgets/context_menu.dart';
import 'package:files/widgets/drive_list.dart';
import 'package:flutter/material.dart';
import 'package:yaru_widgets/yaru_widgets.dart';

typedef NewTabCallback = void Function(String);

class SidePane extends StatefulWidget {
  final List<SideDestination> destinations;
  final WorkspaceController workspace;
  final NewTabCallback onNewTab;

  const SidePane({
    required this.destinations,
    required this.workspace,
    required this.onNewTab,
    super.key,
  });

  @override
  _SidePaneState createState() => _SidePaneState();
}

class _SidePaneState extends State<SidePane> {
  @override
  void initState() {
    super.initState();
    widget.workspace.addListener(updateOnDirChange);
  }

  @override
  void didUpdateWidget(covariant SidePane old) {
    super.didUpdateWidget(old);
    if (widget.workspace != old.workspace) {
      old.workspace.removeListener(updateOnDirChange);
      widget.workspace.addListener(updateOnDirChange);
    }
  }

  @override
  void dispose() {
    widget.workspace.removeListener(updateOnDirChange);
    super.dispose();
  }

  void updateOnDirChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 304,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: ListView.separated(
          padding: const EdgeInsets.only(top: 16),
          itemCount: widget.destinations.length + 1,
          separatorBuilder: (context, index) {
            if (index == widget.destinations.length - 1) {
              return const Divider();
            }

            return SizedBox(
              height: YaruMasterDetailTheme.of(context).tileSpacing ?? 0,
            );
          },
          itemBuilder: (context, index) {
            if (index == widget.destinations.length) {
              return DriveList(onDriveTap: widget.workspace.changeCurrentDir);
            }

            return ContextMenu(
              entries: [
                ContextMenuItem(
                  child: const Text("Open"),
                  onTap: () => widget.workspace
                      .changeCurrentDir(widget.destinations[index].path),
                ),
                ContextMenuItem(
                  child: const Text("Open in new tab"),
                  onTap: () => widget.onNewTab(widget.destinations[index].path),
                ),
                ContextMenuItem(
                  child: const Text("Open in new window"),
                  onTap: () async {
                    await Process.start(
                      Platform.resolvedExecutable,
                      [widget.destinations[index].path],
                    );
                  },
                ),
              ],
              child: YaruMasterTile(
                leading: Icon(widget.destinations[index].icon),
                selected: widget.workspace.currentDir ==
                    widget.destinations[index].path,
                title: Text(
                  widget.destinations[index].label,
                ),
                onTap: () => widget.workspace
                    .changeCurrentDir(widget.destinations[index].path),
              ),
            );
          },
        ),
      ),
    );
  }
}
