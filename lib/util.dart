import 'dart:math';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class MeasureSizeRenderObject extends RenderProxyBox {
  MeasureSizeRenderObject(this.onChange);
  void Function(Size? size)? onChange;

  Size? _prevSize;
  @override
  void performLayout() {
    super.performLayout();
    Size? newSize = child?.size;
    if (_prevSize == newSize) return;
    _prevSize = newSize;
    WidgetsBinding.instance?.addPostFrameCallback((_) => onChange!(newSize));
  }
}

class MeasurableWidget extends SingleChildRenderObjectWidget {
  const MeasurableWidget(
      {Key? key, @required this.onChange, @required Widget? child})
      : super(key: key, child: child);
  final void Function(Size? size)? onChange;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      MeasureSizeRenderObject(onChange);
}

class ExtraScrollPhysics extends ClampingScrollPhysics {
  final double extra;
  ExtraScrollPhysics({this.extra = 0.0, ScrollPhysics? parent})
      : super(parent: parent);
  ScrollMetrics expandScrollMetrics(ScrollMetrics? extant) {
    return FixedScrollMetrics(
      pixels: extant?.pixels,
      axisDirection: extant?.axisDirection ?? AxisDirection.down,
      minScrollExtent: extant?.minScrollExtent,
      maxScrollExtent: (extant?.maxScrollExtent ?? 0) + extra,
      viewportDimension: extant?.viewportDimension,
    );
  }

  ExtraScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ExtraScrollPhysics(parent: buildParent(ancestor), extra: extra);
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    return super
        .applyPhysicsToUserOffset(expandScrollMetrics(position), offset);
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    return super.shouldAcceptUserOffset(expandScrollMetrics(position));
  }

  @override
  double adjustPositionForNewDimensions({
    ScrollMetrics? oldPosition,
    ScrollMetrics? newPosition,
    bool isScrolling = false,
    double velocity = 0.0,
  }) {
    return super.adjustPositionForNewDimensions(
        oldPosition: expandScrollMetrics(oldPosition),
        newPosition: expandScrollMetrics(newPosition),
        isScrolling: isScrolling,
        velocity: velocity);
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    return super.applyBoundaryConditions(
      expandScrollMetrics(position),
      value,
    );
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    return super
        .createBallisticSimulation(expandScrollMetrics(position), velocity);
  }
}
