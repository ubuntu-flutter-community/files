import 'package:files/widgets/context_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaru/yaru.dart';

class EntityContextMenu extends StatelessWidget {
  final Widget child;
  final VoidCallback? onOpen;
  final VoidCallback? onOpenWith;
  final VoidCallback? onCopy;
  final VoidCallback? onCut;
  final VoidCallback? onPaste;

  const EntityContextMenu({
    required this.child,
    this.onOpen,
    this.onOpenWith,
    this.onCopy,
    this.onCut,
    this.onPaste,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        if (onCopy != null)
          const SingleActivator(LogicalKeyboardKey.keyC, control: true):
              onCopy!,
      },
      child: ContextMenu(
        entries: [
          ContextMenuItem(
            child: const Text("Open"),
            onTap: onOpen,
            shortcut: const SingleActivator(LogicalKeyboardKey.enter),
          ),
          ContextMenuItem(
            child: const Text("Open with other application"),
            onTap: onOpenWith,
            enabled: false,
          ),
          const ContextMenuDivider(),
          ContextMenuItem(
            leading: const Icon(YaruIcons.copy),
            child: const Text("Copy file"),
            onTap: onCopy,
            shortcut:
                const SingleActivator(LogicalKeyboardKey.keyC, control: true),
          ),
          ContextMenuItem(
            leading: const Icon(YaruIcons.cut),
            child: const Text("Cut file"),
            onTap: onCut,
            shortcut:
                const SingleActivator(LogicalKeyboardKey.keyX, control: true),
          ),
          ContextMenuItem(
            leading: const Icon(YaruIcons.paste),
            child: const Text("Paste file"),
            onTap: onPaste,
            shortcut:
                const SingleActivator(LogicalKeyboardKey.keyV, control: true),
          ),
        ],
        child: child,
      ),
    );
  }
}

class CopyFileIntent extends Intent {
  const CopyFileIntent();
}
