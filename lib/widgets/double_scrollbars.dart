import 'package:flutter/material.dart';

class DoubleScrollbars extends StatelessWidget {
  const DoubleScrollbars({
    required this.horizontalController,
    required this.verticalController,
    required this.child,
    super.key,
  });

  final ScrollController horizontalController;
  final ScrollController verticalController;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ScrollNotificationIsolater(
        child: MediaQuery(
          data: MediaQueryData(
            padding: const EdgeInsetsDirectional.only(bottom: 12)
                .resolve(Directionality.of(context)),
          ),
          child: Scrollbar(
            controller: verticalController,
            child: _ScrollReceiver(
              direction: Axis.vertical,
              child: ScrollNotificationIsolater(
                child: MediaQuery(
                  data: MediaQueryData(
                    padding: const EdgeInsetsDirectional.only(end: 12)
                        .resolve(Directionality.of(context)),
                  ),
                  child: Scrollbar(
                    controller: horizontalController,
                    child: _ScrollReceiver(
                      direction: Axis.horizontal,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrollReceiver extends StatefulWidget {
  const _ScrollReceiver({
    required this.direction,
    required this.child,
  });
  final Axis direction;
  final Widget child;

  @override
  _ScrollReceiverState createState() => _ScrollReceiverState();
}

class _ScrollReceiverState extends State<_ScrollReceiver> {
  void notify(ScrollNotification notification) {
    notification.dispatch(context);
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.direction) {
      case Axis.vertical:
        return VerticalScrollReceiver._(state: this, child: widget.child);
      case Axis.horizontal:
        return HorizontalScrollReceiver._(state: this, child: widget.child);
    }
  }
}

class _ScrollReceiverInheritedWidget extends InheritedWidget {
  const _ScrollReceiverInheritedWidget({
    required this.state,
    required super.child,
  });
  final _ScrollReceiverState state;

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return false;
  }
}

class HorizontalScrollReceiver extends _ScrollReceiverInheritedWidget {
  const HorizontalScrollReceiver._({
    required super.state,
    required super.child,
  });

  // TODO(@Feichtmeier): fix ignore
  // ignore: library_private_types_in_public_api
  static _ScrollReceiverState of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<HorizontalScrollReceiver>()!
        .state;
  }
}

class VerticalScrollReceiver extends _ScrollReceiverInheritedWidget {
  const VerticalScrollReceiver._({
    required super.state,
    required super.child,
  });

  // TODO(@Feichtmeier): fix ignore
  // ignore: library_private_types_in_public_api
  static _ScrollReceiverState of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<VerticalScrollReceiver>()!
        .state;
  }
}

class ScrollProxy extends StatelessWidget {
  const ScrollProxy({
    required this.direction,
    required this.child,
    super.key,
  });
  final Axis direction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        late final _ScrollReceiverState provider;

        switch (direction) {
          case Axis.vertical:
            provider = VerticalScrollReceiver.of(context);
          case Axis.horizontal:
            provider = HorizontalScrollReceiver.of(context);
        }

        provider.notify(notification);
        return true;
      },
      child: child,
    );
  }
}

class ScrollNotificationIsolater extends StatelessWidget {
  const ScrollNotificationIsolater({
    required this.child,
    super.key,
  });
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) => true,
      child: child,
    );
  }
}
