import 'package:files/backend/utils.dart';
import 'package:files/backend/workspace.dart';
import 'package:files/widgets/context_menu.dart';
import 'package:flutter/material.dart';
import 'package:yaru_icons/yaru_icons.dart';
import 'package:yaru_widgets/yaru_widgets.dart';

class TabStrip extends StatelessWidget {
  final List<WorkspaceController> tabs;
  final int selectedTab;
  final bool allowClosing;
  final ValueChanged<int>? onTabChanged;
  final ValueChanged<int>? onTabClosed;
  final VoidCallback? onNewTab;
  final List<Widget> trailing;

  const TabStrip({
    required this.tabs,
    required this.selectedTab,
    this.allowClosing = true,
    this.onTabChanged,
    this.onTabClosed,
    this.onNewTab,
    this.trailing = const [],
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Row(
        children: [
          const SizedBox(width: 8),
          YaruOptionButton(
            onPressed: onNewTab,
            child: const Icon(YaruIcons.plus),
          ),
          Expanded(
            child: ListView.separated(
              itemBuilder: (context, index) => ContextMenu(
                openOnLongPress: false,
                entries: [
                  ContextMenuItem(
                    child: const Text("Create new tab"),
                    onTap: () => onNewTab?.call(),
                  ),
                  ContextMenuItem(
                    child: const Text("Close tab"),
                    onTap: () => onTabClosed?.call(index),
                    enabled: allowClosing,
                  ),
                ],
                child: _Tab(
                  tab: tabs[index],
                  selected: selectedTab == index,
                  onTap: () => onTabChanged?.call(index),
                  onClosed: () => onTabClosed?.call(index),
                  allowClosing: allowClosing,
                ),
              ),
              scrollDirection: Axis.horizontal,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemCount: tabs.length,
              padding: const EdgeInsets.all(8),
            ),
          ),
          if (trailing.isNotEmpty)
            const VerticalDivider(
              indent: 12,
              endIndent: 12,
              width: 1,
              thickness: 1,
            ),
          ...trailing,
        ],
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  final WorkspaceController tab;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onClosed;
  final bool allowClosing;

  const _Tab({
    required this.tab,
    required this.selected,
    this.onTap,
    this.onClosed,
    this.allowClosing = true,
  });

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  @override
  void initState() {
    super.initState();
    widget.tab.addListener(updateOnDirChange);
  }

  @override
  void dispose() {
    widget.tab.removeListener(updateOnDirChange);
    super.dispose();
  }

  void updateOnDirChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: double.infinity,
      child: Material(
        color: widget.selected
            ? Theme.of(context).colorScheme.surfaceVariant
            : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Icon(Utils.iconForFolder(widget.tab.currentDir), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    Utils.getEntityName(widget.tab.currentDir),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AnimatedOpacity(
                  opacity: widget.allowClosing ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: IconButton(
                    onPressed: widget.allowClosing ? widget.onClosed : null,
                    icon: const Icon(YaruIcons.window_close),
                    iconSize: 16,
                    splashRadius: 16,
                    hoverColor: Theme.of(context).colorScheme.primary,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints.tight(const Size.square(16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
