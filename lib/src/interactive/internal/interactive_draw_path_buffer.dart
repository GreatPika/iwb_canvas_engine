import 'dart:collection';
import 'dart:ui';

import '../../core/input_sampling.dart';
import 'interactive_geometry.dart';

class InteractiveDrawPathBuffer {
  InteractiveDrawPathBuffer({required this.softLimit, required this.trimTo});

  final int softLimit;
  final int trimTo;

  final List<Offset> _points = <Offset>[];
  late final UnmodifiableListView<Offset> _pointsView =
      UnmodifiableListView<Offset>(_points);

  List<Offset> get points => _pointsView;
  int get length => _points.length;
  bool get isEmpty => _points.isEmpty;
  bool get isNotEmpty => _points.isNotEmpty;
  Offset get last => _points.last;

  void clear() {
    _points.clear();
  }

  void start(Offset scenePoint) {
    _points
      ..clear()
      ..add(scenePoint);
  }

  bool appendMovePoint(Offset scenePoint) {
    if (_points.isEmpty) return false;
    if (!isDistanceAtLeast(last, scenePoint, kInputDecimationMinStepScene)) {
      return false;
    }
    _points.add(scenePoint);
    _enforceSoftLimit();
    return true;
  }

  bool appendTerminalPoint(Offset scenePoint, {bool enforceSoftLimit = false}) {
    if (_points.isEmpty || !isDistanceGreaterThan(last, scenePoint, 0)) {
      return false;
    }
    _points.add(scenePoint);
    if (enforceSoftLimit) {
      _enforceSoftLimit();
    }
    return true;
  }

  void _enforceSoftLimit() {
    enforceGestureBufferSoftLimit(
      _points,
      softLimit: softLimit,
      trimTo: trimTo,
    );
  }
}
