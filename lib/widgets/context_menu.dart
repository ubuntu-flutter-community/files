import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

class ContextMenu extends StatefulWidget {
  const ContextMenu({
    required this.entries,
    required this.child,
    this.openOnLongPress = true,
    this.openOnSecondaryPress = true,
    super.key,
  });

  final List<BaseContextMenuItem> entries;
  final Widget child;
  final bool openOnLongPress;
  final bool openOnSecondaryPress;

  @override
  State<ContextMenu> createState() => _ContextMenuState();
}

class _ContextMenuState extends State<ContextMenu> {
  late Offset lastPosition;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: widget.entries.map((e) => e.buildWrapper(context)).toList(),
      builder: (context, controller, child) {
        return GestureDetector(
          onSecondaryTapUp: (details) =>
              controller.open(position: details.localPosition),
          onLongPressDown: (details) => lastPosition = details.localPosition,
          onLongPress: () => controller.open(position: lastPosition),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _EnabledBuilder extends StatelessWidget {
  const _EnabledBuilder({
    required this.enabled,
    required this.child,
  });
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: child,
      ),
    );
  }
}

abstract class BaseContextMenuItem {
  const BaseContextMenuItem({
    required this.child,
    this.enabled = true,
    this.leading,
    this.trailing,
  });
  final Widget child;
  final Widget? leading;
  final Widget? trailing;
  final bool enabled;

  Widget buildWrapper(BuildContext context) =>
      _EnabledBuilder(enabled: enabled, child: build(context));

  Widget build(BuildContext context);
  Widget? buildLeading(BuildContext context) => leading;
  Widget? buildTrailing(BuildContext context) => trailing;
}

class SubmenuMenuItem extends BaseContextMenuItem {
  const SubmenuMenuItem({
    required super.child,
    required this.menuChildren,
    super.leading,
    super.enabled,
  }) : super(trailing: null);
  final List<BaseContextMenuItem> menuChildren;

  @override
  Widget? buildTrailing(BuildContext context) {
    return const Icon(YaruIcons.go_next, size: 16);
  }

  @override
  Widget build(BuildContext context) {
    return SubmenuButton(
      menuChildren: menuChildren.map((e) => e.buildWrapper(context)).toList(),
      leadingIcon: buildLeading(context),
      trailingIcon: buildTrailing(context),
      style: const ButtonStyle(
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
      child: child,
    );
  }
}

class ContextMenuItem extends BaseContextMenuItem {
  const ContextMenuItem({
    required super.child,
    this.onTap,
    super.leading,
    super.trailing,
    this.shortcut,
    super.enabled,
  });
  final VoidCallback? onTap;
  final MenuSerializableShortcut? shortcut;

  @override
  Widget build(BuildContext context) {
    final leading = buildLeading(context);

    return MenuItemButton(
      leadingIcon: leading != null
          ? IconTheme.merge(
              data: Theme.of(context).iconTheme.copyWith(size: 20),
              child: leading,
            )
          : null,
      trailingIcon: buildTrailing(context),
      onPressed: onTap,
      shortcut: shortcut,
      style: const ButtonStyle(
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
      child: child,
    );
  }
}

class RadioMenuItem<T> extends ContextMenuItem {
  const RadioMenuItem({
    required this.value,
    required this.groupValue,
    this.onChanged,
    this.toggleable = false,
    required super.child,
    super.trailing,
    super.shortcut,
    super.enabled,
  }) : super(leading: null, onTap: null);
  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final bool toggleable;

  @override
  VoidCallback? get onTap => onChanged == null
      ? null
      : () {
          if (toggleable && groupValue == value) {
            onChanged!.call(null);
            return;
          }
          onChanged!.call(value);
        };

  @override
  Widget? buildTrailing(BuildContext context) {
    return ExcludeFocus(
      child: IgnorePointer(
        child: YaruRadio<T>(
          groupValue: groupValue,
          value: value,
          onChanged: onChanged,
          toggleable: toggleable,
        ),
      ),
    );
  }
}

class CheckboxMenuItem extends ContextMenuItem {
  const CheckboxMenuItem({
    required this.value,
    this.onChanged,
    this.tristate = false,
    required super.child,
    super.trailing,
    super.shortcut,
    super.enabled,
  }) : super(leading: null, onTap: null);
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final bool tristate;

  @override
  VoidCallback? get onTap => onChanged == null
      ? null
      : () {
          switch (value) {
            case false:
              onChanged!.call(true);
            case true:
              onChanged!.call(tristate ? null : false);
            case null:
              onChanged!.call(false);
          }
        };

  @override
  Widget? buildTrailing(BuildContext context) {
    return ExcludeFocus(
      child: IgnorePointer(
        child: YaruCheckbox(
          value: value,
          onChanged: onChanged,
          tristate: tristate,
        ),
      ),
    );
  }
}

class ContextMenuDivider extends BaseContextMenuItem {
  const ContextMenuDivider() : super(child: const SizedBox());

  @override
  Widget build(BuildContext context) => const Divider();
}
