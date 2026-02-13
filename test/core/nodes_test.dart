import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/transform2d.dart';

void main() {
  test('node convenience accessors update TRS transform', () {
    final rect = RectNode(id: 'r', size: const Size(10, 20));

    rect.opacity = 2;
    expect(rect.opacity, 1);
    rect.opacity = -1;
    expect(rect.opacity, 0);
    rect.opacity = double.nan;
    expect(rect.opacity, 1);

    rect.position = const Offset(5, 6);
    expect(rect.position, const Offset(5, 6));

    rect.rotationDeg = 90;
    expect(rect.rotationDeg, closeTo(90, 1e-6));

    rect.scaleX = 2;
    rect.scaleY = -3;
    expect(rect.scaleX, closeTo(2, 1e-6));
    expect(rect.scaleY, closeTo(-3, 1e-6));

    rect.transform = const Transform2D(a: 0.1, b: 0, c: -1, d: 0, tx: 0, ty: 0);
    expect(rect.rotationDeg, closeTo(90, 1e-6));
  });

  test('convenience setters reject non-TRS or non-finite transforms', () {
    final rect = RectNode(id: 'r', size: const Size(10, 10));

    rect.transform = const Transform2D(a: 1, b: 0, c: 1, d: 1, tx: 0, ty: 0);
    expect(() => rect.rotationDeg = 1, throwsStateError);
    expect(() => rect.scaleX = 1, throwsStateError);
    expect(() => rect.scaleY = 1, throwsStateError);

    rect.transform = const Transform2D(
      a: double.nan,
      b: 0,
      c: 0,
      d: 1,
      tx: 0,
      ty: 0,
    );
    expect(() => rect.rotationDeg = 1, throwsStateError);
  });

  test('boundsWorld falls back to Rect.zero for invalid transform bounds', () {
    final line = LineNode(
      id: 'l',
      start: const Offset(double.nan, 0),
      end: const Offset(1, 1),
      thickness: 1,
      color: const Color(0xFF000000),
    );
    expect(line.boundsWorld, Rect.zero);

    line.start = const Offset(0, 0);
    line.end = const Offset(10, 0);
    line.transform = const Transform2D(
      a: 1,
      b: 0,
      c: 0,
      d: 1,
      tx: double.infinity,
      ty: 0,
    );
    expect(line.boundsWorld, Rect.zero);
  });

  test('topLeftWorld helpers are AABB-based and honor ui epsilon', () {
    final image = ImageNode.fromTopLeftWorld(
      id: 'img',
      imageId: 'asset',
      size: const Size(20, 10),
      topLeftWorld: const Offset(10, 20),
    );
    expect(image.topLeftWorld, const Offset(10, 20));

    image.topLeftWorld = const Offset(10, 20);
    expect(image.position, const Offset(20, 25));

    image.topLeftWorld = const Offset(15, 25);
    expect(image.topLeftWorld, const Offset(15, 25));

    final text = TextNode.fromTopLeftWorld(
      id: 'txt',
      text: 'hello',
      size: const Size(40, 12),
      topLeftWorld: const Offset(3, 4),
      color: const Color(0xFF000000),
    );
    expect(text.topLeftWorld, const Offset(3, 4));
    text.topLeftWorld = const Offset(3, 4);
    text.topLeftWorld = const Offset(4, 6);
    expect(text.topLeftWorld, const Offset(4, 6));

    final rect = RectNode.fromTopLeftWorld(
      id: 'rect',
      size: const Size(10, 8),
      topLeftWorld: const Offset(1, 2),
    );
    expect(rect.topLeftWorld, const Offset(1, 2));
    rect.topLeftWorld = const Offset(1, 2);
    rect.topLeftWorld = const Offset(2, 3);
    expect(rect.topLeftWorld, const Offset(2, 3));
  });

  test('stroke and line factories center world geometry', () {
    final stroke = StrokeNode.fromWorldPoints(
      id: 's',
      points: const <Offset>[Offset(10, 10), Offset(14, 18)],
      thickness: 2,
      color: const Color(0xFF000000),
    );
    expect(stroke.position, const Offset(12, 14));

    final line = LineNode.fromWorldSegment(
      id: 'l',
      start: const Offset(0, 0),
      end: const Offset(10, 6),
      thickness: 3,
      color: const Color(0xFF000000),
    );
    expect(line.position, const Offset(5, 3));
  });

  test(
    'normalizeToLocalCenter validates preconditions and normalizes geometry',
    () {
      final stroke = StrokeNode(
        id: 's',
        points: const <Offset>[Offset(10, 10), Offset(14, 18)],
        thickness: 2,
        color: const Color(0xFF000000),
      );
      stroke.normalizeToLocalCenter();
      expect(stroke.transform.translation, const Offset(12, 14));

      final strokeWrongTransform = StrokeNode(
        id: 's2',
        points: const <Offset>[Offset(0, 0)],
        thickness: 1,
        color: const Color(0xFF000000),
        transform: Transform2D.translation(const Offset(1, 0)),
      );
      expect(strokeWrongTransform.normalizeToLocalCenter, throwsStateError);

      final strokeBadPoint = StrokeNode(
        id: 's3',
        points: const <Offset>[Offset(double.nan, 0)],
        thickness: 1,
        color: const Color(0xFF000000),
      );
      expect(strokeBadPoint.normalizeToLocalCenter, throwsStateError);

      final line = LineNode(
        id: 'l',
        start: const Offset(0, 0),
        end: const Offset(10, 4),
        thickness: 2,
        color: const Color(0xFF000000),
      );
      line.normalizeToLocalCenter();
      expect(line.transform.translation, const Offset(5, 2));

      final wrongTransformLine = LineNode(
        id: 'l0',
        start: const Offset(0, 0),
        end: const Offset(1, 1),
        thickness: 1,
        color: const Color(0xFF000000),
        transform: Transform2D.translation(const Offset(1, 0)),
      );
      expect(wrongTransformLine.normalizeToLocalCenter, throwsStateError);

      final badLine = LineNode(
        id: 'l2',
        start: const Offset(double.infinity, 0),
        end: const Offset(1, 1),
        thickness: 1,
        color: const Color(0xFF000000),
      );
      expect(badLine.normalizeToLocalCenter, throwsStateError);
    },
  );

  test('stroke points revision tracks mutating list operations', () {
    final stroke = StrokeNode(
      id: 's',
      points: const <Offset>[Offset(0, 0)],
      thickness: 1,
      color: const Color(0xFF000000),
    );
    final points = stroke.points;
    var revision = stroke.pointsRevision;

    points.length = points.length;
    points.addAll(const <Offset>[]);
    points.removeRange(0, 0);
    points.setRange(0, 0, const <Offset>[]);
    points.fillRange(0, 0);
    points.removeWhere((_) => false);
    points.retainWhere((_) => true);
    points.sort();
    points.shuffle(math.Random(1));
    expect(stroke.pointsRevision, revision);

    points.add(const Offset(1, 1));
    expect(stroke.pointsRevision, greaterThan(revision));
    revision = stroke.pointsRevision;

    points[0] = const Offset(0, 0);
    expect(stroke.pointsRevision, revision);

    points[0] = const Offset(2, 2);
    expect(stroke.pointsRevision, greaterThan(revision));
    revision = stroke.pointsRevision;

    points.addAll(const <Offset>[Offset(3, 3)]);
    points.length = points.length - 1;
    points.insert(1, const Offset(9, 9));
    points.insertAll(0, const <Offset>[Offset(-1, -1)]);
    points.remove(const Offset(9, 9));
    points.removeAt(0);
    points.removeLast();
    if (points.isNotEmpty) {
      points.removeRange(0, 1);
    }
    if (points.isEmpty) {
      points.add(const Offset(0, 0));
    }
    points.replaceRange(0, 1, const <Offset>[Offset(7, 7)]);
    points.setAll(0, const <Offset>[Offset(8, 8)]);
    points.setRange(0, 1, const <Offset>[Offset(6, 6)]);
    points.fillRange(0, 1, const Offset(5, 5));
    points.removeWhere((p) => p == const Offset(5, 5));
    points.addAll(const <Offset>[Offset(2, 0), Offset(1, 0)]);
    points.retainWhere((p) => p.dy == 0);
    points.sort((a, b) => a.dx.compareTo(b.dx));
    points.shuffle(math.Random(2));
    points.clear();
    expect(stroke.pointsRevision, greaterThan(revision));

    final one = StrokeNode(
      id: 'single',
      points: const <Offset>[Offset(0, 0)],
      thickness: 1,
      color: const Color(0xFF000000),
    );
    final oneRev = one.pointsRevision;
    one.points.length = 1;
    expect(one.pointsRevision, oneRev);
    one.points.remove(const Offset(100, 100));
    expect(one.pointsRevision, oneRev);
  });

  test('stroke constructor rejects negative initial pointsRevision', () {
    expect(
      () => StrokeNode(
        id: 'bad-rev',
        points: const <Offset>[Offset(0, 0)],
        pointsRevision: -1,
        thickness: 1,
        color: const Color(0xFF000000),
      ),
      throwsArgumentError,
    );
  });

  test('path node builds, caches and invalidates local path data', () {
    final pathNode = PathNode(
      id: 'p',
      svgPathData: 'M0 0 L10 0 L10 10 Z',
      fillColor: const Color(0xFF00FF00),
      strokeColor: const Color(0xFF000000),
      strokeWidth: 2,
    );

    final copyA = pathNode.buildLocalPath();
    final copyB = pathNode.buildLocalPath();
    expect(copyA, isNotNull);
    expect(copyB, isNotNull);
    expect(identical(copyA, copyB), isFalse);

    final sameA = pathNode.buildLocalPath(copy: false);
    final sameB = pathNode.buildLocalPath(copy: false);
    expect(identical(sameA, sameB), isTrue);
    expect(pathNode.localBounds, isNot(Rect.zero));

    pathNode.fillRule = PathFillRule.evenOdd;
    final evenOddPath = pathNode.buildLocalPath(copy: false);
    expect(evenOddPath, isNotNull);
    expect(evenOddPath!.fillType, PathFillType.evenOdd);

    pathNode.svgPathData = pathNode.svgPathData;
    expect(pathNode.buildLocalPath(), isNotNull);

    pathNode.svgPathData = '';
    expect(pathNode.buildLocalPath(), isNull);
    expect(pathNode.localBounds, Rect.zero);

    pathNode.svgPathData = 'M0 0';
    expect(pathNode.buildLocalPath(), isNull);
  });

  test('path node diagnostics capture failures for invalid path data', () {
    final previous = PathNode.enableBuildLocalPathDiagnostics;
    PathNode.enableBuildLocalPathDiagnostics = true;
    addTearDown(() => PathNode.enableBuildLocalPathDiagnostics = previous);

    final pathNode = PathNode(id: 'p', svgPathData: 'this is not svg');
    expect(pathNode.buildLocalPath(), isNull);
    expect(pathNode.debugLastBuildLocalPathFailureReason, isNotNull);
    expect(pathNode.debugLastBuildLocalPathException, isNotNull);
    expect(pathNode.debugLastBuildLocalPathStackTrace, isNotNull);

    pathNode.svgPathData = 'M0 0 L10 0 L10 10 Z';
    expect(pathNode.buildLocalPath(), isNotNull);
    expect(pathNode.debugLastBuildLocalPathFailureReason, isNull);
    expect(pathNode.debugLastBuildLocalPathException, isNull);
    expect(pathNode.debugLastBuildLocalPathStackTrace, isNull);
  });

  test(
    'line/stroke/rect local bounds sanitize invalid thickness and points',
    () {
      final line = LineNode(
        id: 'l',
        start: const Offset(0, 0),
        end: const Offset(2, 0),
        thickness: -10,
        color: const Color(0xFF000000),
      );
      expect(line.localBounds, const Rect.fromLTRB(0, 0, 2, 0));

      line.start = const Offset(double.nan, 0);
      expect(line.localBounds, Rect.zero);

      final stroke = StrokeNode(
        id: 's',
        points: const <Offset>[Offset(0, 0), Offset(4, 0)],
        thickness: -1,
        color: const Color(0xFF000000),
      );
      expect(stroke.localBounds, const Rect.fromLTRB(0, 0, 4, 0));

      final rect = RectNode(
        id: 'r',
        size: const Size(10, 6),
        strokeColor: const Color(0xFF000000),
        strokeWidth: 4,
      );
      expect(rect.localBounds.width, closeTo(14, 1e-9));
    },
  );
}
