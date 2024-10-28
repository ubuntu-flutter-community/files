import 'package:flutter/material.dart';

class SeparatedFlex extends StatelessWidget {
  const SeparatedFlex({
    super.key,
    required this.children,
    required this.separator,
    required this.axis,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
  });

  const SeparatedFlex.horizontal({
    super.key,
    required this.children,
    required this.separator,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
  }) : axis = Axis.horizontal;

  const SeparatedFlex.vertical({
    super.key,
    required this.children,
    required this.separator,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
  }) : axis = Axis.vertical;
  final List<Widget> children;
  final Widget separator;
  final Axis axis;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;

  @override
  Widget build(BuildContext context) {
    final separatedChildren = children.isNotEmpty
        ? List.generate(children.length * 2 - 1, (index) {
            if (index.isEven) {
              return children[index ~/ 2];
            } else {
              return separator;
            }
          })
        : <Widget>[];

    return Flex(
      direction: axis,
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: separatedChildren,
    );
  }
}
