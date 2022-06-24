import 'package:files/widgets/context_menu/context_sub_menu_entry.dart';
import 'package:flutter/material.dart';

abstract class BaseContextMenuEntry extends PopupMenuEntry<String> {
  /// Using for [represents] method.
  final String id;

  /// A widget to display before the title.
  /// Typically a [Icon] widget.
  final Widget? leading;

  /// The primary content of the menu entry.
  /// Typically a [Text] widget.
  final Widget title;

  final bool enabled;

  const BaseContextMenuEntry({
    required this.id,
    this.leading,
    required this.title,
    this.enabled = true,
    Key? key,
  }) : super(key: key);

  @override
  double get height => 40;

  @override
  bool represents(String? value) => id == value;
}

/// [ContextSubMenuEntry] is a [PopupMenuEntry] that displays a base menu entry.
class ContextMenuEntry extends BaseContextMenuEntry {
  /// A tap with a primary button has occurred.
  final VoidCallback onTap;

  /// Optional content to display keysequence after the title.
  /// Typically a [Text] widget.
  final Widget? shortcut;

  const ContextMenuEntry({
    required String id,
    Widget? leading,
    required Widget title,
    required this.onTap,
    this.shortcut,
    bool enabled = true,
    Key? key,
  }) : super(
          id: id,
          leading: leading,
          title: title,
          enabled: enabled,
          key: key,
        );

  @override
  _ContextMenuEntryState createState() => _ContextMenuEntryState();
}

class _ContextMenuEntryState extends State<ContextMenuEntry> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.enabled
          ? () {
              Navigator.pop(context);
              widget.onTap.call();
            }
          : null,
      child: Container(
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (widget.leading != null) ...[
              IconTheme.merge(
                data: IconThemeData(
                  size: 20,
                  color: widget.enabled
                      ? Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.3),
                ),
                child: widget.leading!,
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: DefaultTextStyle(
                style: TextStyle(
                  fontSize: 16,
                  color: widget.enabled
                      ? Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.3),
                ),
                overflow: TextOverflow.ellipsis,
                child: widget.title,
              ),
            ),
            if (widget.shortcut != null)
              DefaultTextStyle(
                style: TextStyle(
                  fontSize: 16,
                  color: widget.enabled
                      ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.1),
                ),
                overflow: TextOverflow.ellipsis,
                child: widget.shortcut!,
              ),
          ],
        ),
      ),
    );
  }
}

/// A horizontal divider in a Material Design popup menu.
class ContextMenuDivider extends BaseContextMenuEntry {
  const ContextMenuDivider({Key? key})
      : super(id: "", title: const SizedBox(), key: key);

  @override
  bool represents(void value) => false;

  @override
  State<ContextMenuDivider> createState() => _ContextMenuDividerState();
}

class _ContextMenuDividerState extends State<ContextMenuDivider> {
  @override
  Widget build(BuildContext context) => Divider(height: widget.height);
}
