import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/path_fill_rule.dart';
import 'package:iwb_canvas_engine/src/contract/scene_contract_limits.dart';
import 'package:iwb_canvas_engine/src/contract/transform2d.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';

void main() {
  // INV:INV-ENG-CORE-ARCHITECTURE-BOUNDARY
  test('core node owners remain split into file-local modules', () {
    final nodesSource = File('lib/src/core/nodes.dart').readAsStringSync();
    final sceneNodeSource = File(
      'lib/src/core/scene_node.dart',
    ).readAsStringSync();
    final boxNodesSource = File(
      'lib/src/core/box_nodes.dart',
    ).readAsStringSync();
    final textNodeLayoutStateSource = File(
      'lib/src/core/text_node_layout_state.dart',
    ).readAsStringSync();
    final vectorNodesSource = File(
      'lib/src/core/vector_nodes.dart',
    ).readAsStringSync();
    final pathNodeSource = File(
      'lib/src/core/path_node.dart',
    ).readAsStringSync();

    expect(nodesSource, contains("export 'scene_node.dart';"));
    expect(nodesSource, contains("export 'box_nodes.dart';"));
    expect(nodesSource, contains("export 'vector_nodes.dart';"));
    expect(nodesSource, contains("export 'path_node.dart';"));
    expect(nodesSource, isNot(contains('abstract class SceneNode')));
    expect(
      sceneNodeSource,
      contains('abstract final class _SceneNodeTransformConvenience'),
    );
    expect(
      boxNodesSource,
      contains('abstract final class _BoxNodePlacementOwner'),
    );
    expect(boxNodesSource, isNot(contains('TextLayoutRequest(')));
    expect(
      textNodeLayoutStateSource,
      contains('final class TextNodeLayoutState'),
    );
    expect(textNodeLayoutStateSource, contains('TextLayoutRequest('));
    expect(
      vectorNodesSource,
      contains('abstract final class _VectorNodeGeometryOwner'),
    );
    expect(
      pathNodeSource,
      contains('final class _PathNodeLocalPathCacheOwner'),
    );
    expect(sceneNodeSource, isNot(contains('TextLayoutRequest')));
    expect(vectorNodesSource, isNot(contains('_ActionPayloadReader')));
    expect(pathNodeSource, isNot(contains('_GeneratedIdAllocator')));
  });

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

  test('convenience getters assert on non-finite transform components', () {
    final rect = RectNode(id: 'r', size: const Size(10, 10))
      ..transform = const Transform2D(
        a: double.nan,
        b: 0,
        c: 0,
        d: 1,
        tx: 0,
        ty: 0,
      );

    expect(() => rect.rotationDeg, throwsA(isA<AssertionError>()));
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

      expect(
        () => StrokeNode(
          id: 's3',
          points: const <Offset>[Offset(double.nan, 0)],
          thickness: 1,
          color: const Color(0xFF000000),
        ),
        throwsArgumentError,
      );

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

  // INV:INV-ENG-STROKE-RUNTIME-GEOMETRY-OWNER
  test('stroke points expose read-only runtime geometry view', () {
    final stroke = StrokeNode(
      id: 's',
      points: const <Offset>[Offset(0, 0)],
      thickness: 1,
      color: const Color(0xFF000000),
    );
    expect(() => stroke.points.add(const Offset(1, 1)), throwsUnsupportedError);
    expect(() => stroke.points[0] = const Offset(2, 2), throwsUnsupportedError);
    expect(() => stroke.points.clear(), throwsUnsupportedError);
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

  test(
    'stroke replacePoints keeps no-op revision stable and updates on change',
    () {
      final stroke = StrokeNode(
        id: 'stable-revision',
        points: const <Offset>[Offset(0, 0)],
        thickness: 1,
        color: const Color(0xFF000000),
      );
      final revision = stroke.pointsRevision;
      final pointsView = stroke.points;

      expect(stroke.replacePoints(const <Offset>[Offset(0, 0)]), isFalse);
      expect(stroke.pointsRevision, revision);
      expect(identical(stroke.points, pointsView), isTrue);

      expect(
        stroke.replacePoints(const <Offset>[Offset(2, 2), Offset(3, 3)]),
        isTrue,
      );
      expect(stroke.points, const <Offset>[Offset(2, 2), Offset(3, 3)]);
      expect(stroke.pointsRevision, revision + 1);
      expect(identical(stroke.points, pointsView), isTrue);
    },
  );

  test('stroke replacePoints rejects invalid runtime geometry', () {
    final stroke = StrokeNode(
      id: 'runtime-validate',
      points: const <Offset>[Offset(0, 0)],
      thickness: 1,
      color: const Color(0xFF000000),
    );

    expect(
      () => stroke.replacePoints(const <Offset>[Offset(double.nan, 0)]),
      throwsArgumentError,
    );
    expect(
      () => stroke.replacePoints(
        List<Offset>.filled(kMaxStrokePointsPerNode + 1, Offset.zero),
      ),
      throwsArgumentError,
    );
  });

  test('scene node constructor rejects non-positive instanceRevision', () {
    expect(
      () => RectNode(
        id: 'bad-instance-revision',
        instanceRevision: 0,
        size: const Size(1, 1),
      ),
      throwsArgumentError,
    );
  });

  test('path node builds, caches and invalidates local path data', () {
    // INV:INV-ENG-PATH-NODE-CACHE-INVALIDATION
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
    expect(pathNode.localBounds, isNot(Rect.zero));

    pathNode.fillRule = PathFillRule.evenOdd;
    final evenOddPath = pathNode.buildLocalPath();
    expect(evenOddPath, isNotNull);
    if (evenOddPath == null) {
      fail('Expected svg path to build after fillRule change.');
    }
    expect(evenOddPath.fillType, PathFillType.evenOdd);

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
