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

    rect.opacity = 0.5;
    expect(rect.opacity, 0.5);
    expect(() => rect.opacity = 2, throwsArgumentError);
    expect(() => rect.opacity = -1, throwsArgumentError);
    expect(() => rect.opacity = double.nan, throwsArgumentError);

    rect.position = const Offset(5, 6);
    expect(rect.position, const Offset(5, 6));

    rect.rotationDeg = 90;
    expect(rect.rotationDeg, closeTo(90, 1e-6));

    rect.scaleX = 2;
    rect.scaleY = -3;
    expect(rect.scaleX, closeTo(2, 1e-6));
    expect(rect.scaleY, closeTo(-3, 1e-6));

    rect.transform = const Transform2D(a: 0, b: 1, c: -1, d: 0, tx: 0, ty: 0);
    expect(rect.rotationDeg, closeTo(90, 1e-6));

    rect.transform = Transform2D.trs(rotationDeg: 30, scaleX: 1, scaleY: 4);
    expect(rect.rotationDeg, closeTo(30, 1e-6));
  });

  test('convenience setters reject non-TRS or non-finite transforms', () {
    final rect = RectNode(id: 'r', size: const Size(10, 10));

    rect.transform = const Transform2D(a: 1, b: 0, c: 1, d: 1, tx: 0, ty: 0);
    expect(() => rect.rotationDeg = 1, throwsStateError);
    expect(() => rect.scaleX = 1, throwsStateError);
    expect(() => rect.scaleY = 1, throwsStateError);

    final nonFiniteRect = _RawTransformRectNode(
      rawTransform: const Transform2D(
        a: double.nan,
        b: 0,
        c: 0,
        d: 1,
        tx: 0,
        ty: 0,
      ),
    );
    expect(() => nonFiniteRect.rotationDeg = 1, throwsStateError);
  });

  test('convenience getters assert on non-finite transform components', () {
    final rect = _RawTransformRectNode(
      rawTransform: const Transform2D(
        a: double.nan,
        b: 0,
        c: 0,
        d: 1,
        tx: 0,
        ty: 0,
      ),
    );

    expect(() => rect.rotationDeg, throwsA(isA<AssertionError>()));
  });

  test('runtime node owners reject invalid constrained assignments', () {
    final rect = RectNode(id: 'rect', size: const Size(10, 10));
    expect(
      () => rect.transform = const Transform2D(
        a: 1,
        b: 2,
        c: 2,
        d: 4,
        tx: 0,
        ty: 0,
      ),
      throwsArgumentError,
    );
    expect(() => rect.hitPadding = -1, throwsArgumentError);
    expect(() => rect.strokeWidth = double.nan, throwsArgumentError);

    final image = ImageNode(
      id: 'image',
      imageId: 'image://1',
      size: const Size(10, 10),
    );
    expect(
      () => image.imageId = 'x' * (kMaxImageIdLength + 1),
      throwsArgumentError,
    );
    expect(() => image.size = const Size(-1, 10), throwsArgumentError);
    expect(
      () => image.naturalSize = const Size(10, double.infinity),
      throwsArgumentError,
    );

    final text = TextNode(
      id: 'text',
      text: 'hello',
      color: const Color(0xFF000000),
    );
    final originalBounds = text.localBounds;
    text.text = 'hello world';
    text.fontSize = 32;
    text.fontFamily = 'Mono';
    text.maxWidth = 120;
    text.lineHeight = 1.5;
    expect(text.localBounds, isNot(originalBounds));
    expect(() => text.fontSize = 0, throwsArgumentError);
    expect(() => text.fontFamily = '', throwsArgumentError);
    expect(() => text.maxWidth = 0, throwsArgumentError);
    expect(() => text.lineHeight = 0, throwsArgumentError);

    final line = LineNode(
      id: 'line',
      start: const Offset(0, 0),
      end: const Offset(10, 0),
      thickness: 1,
      color: const Color(0xFF000000),
    );
    expect(
      () => line.start = const Offset(double.infinity, 0),
      throwsArgumentError,
    );
    expect(() => line.end = const Offset(0, double.nan), throwsArgumentError);
    expect(() => line.thickness = 0, throwsArgumentError);

    final stroke = StrokeNode(
      id: 'stroke',
      points: const <Offset>[Offset(0, 0), Offset(1, 1)],
      thickness: 1,
      color: const Color(0xFF000000),
    );
    expect(() => stroke.thickness = -1, throwsArgumentError);

    final path = PathNode(id: 'path', svgPathData: 'M0 0 L10 10');
    expect(() => path.strokeWidth = -1, throwsArgumentError);
    expect(() => path.svgPathData = '', throwsArgumentError);
    expect(() => path.svgPathData = 'not svg', throwsArgumentError);
  });

  test('boundsWorld falls back to Rect.zero for invalid transform bounds', () {
    final line = _RawLineNode(
      rawStart: const Offset(double.nan, 0),
      rawEnd: const Offset(1, 1),
      rawThickness: 1,
    );
    expect(line.boundsWorld, Rect.zero);

    final translated = _RawTransformRectNode(
      rawTransform: const Transform2D(
        a: 1,
        b: 0,
        c: 0,
        d: 1,
        tx: double.infinity,
        ty: 0,
      ),
    );
    expect(translated.boundsWorld, Rect.zero);
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

      final badLine = _RawLineNode(
        rawStart: const Offset(double.infinity, 0),
        rawEnd: const Offset(1, 1),
        rawThickness: 1,
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

    expect(() => pathNode.svgPathData = '', throwsArgumentError);
    pathNode.svgPathData = 'M0 0';
    expect(pathNode.buildLocalPath(), isNull);
    expect(pathNode.localBounds, Rect.zero);

    final emptyPath = _RawSvgPathNode(rawSvgPathData: '');
    expect(emptyPath.buildLocalPath(), isNull);
    expect(emptyPath.localBounds, Rect.zero);

    final zeroMetricPath = _RawSvgPathNode(rawSvgPathData: 'M0 0');
    expect(zeroMetricPath.buildLocalPath(), isNull);
  });

  test('path node diagnostics capture failures for invalid path data', () {
    final previous = PathNode.enableBuildLocalPathDiagnostics;
    PathNode.enableBuildLocalPathDiagnostics = true;
    addTearDown(() => PathNode.enableBuildLocalPathDiagnostics = previous);

    final pathNode = _RawSvgPathNode(rawSvgPathData: 'this is not svg');
    expect(pathNode.buildLocalPath(), isNull);
    expect(pathNode.debugLastBuildLocalPathFailureReason, isNotNull);
    expect(pathNode.debugLastBuildLocalPathException, isNotNull);
    expect(pathNode.debugLastBuildLocalPathStackTrace, isNotNull);

    final validPath = PathNode(id: 'valid', svgPathData: 'M0 0 L10 0 L10 10 Z');
    expect(validPath.buildLocalPath(), isNotNull);
    expect(validPath.debugLastBuildLocalPathFailureReason, isNull);
    expect(validPath.debugLastBuildLocalPathException, isNull);
    expect(validPath.debugLastBuildLocalPathStackTrace, isNull);
  });

  test(
    'line/stroke/rect local bounds sanitize invalid thickness and points',
    () {
      final line = _RawLineNode(
        rawStart: const Offset(0, 0),
        rawEnd: const Offset(2, 0),
        rawThickness: -10,
      );
      expect(line.localBounds, const Rect.fromLTRB(0, 0, 2, 0));

      final invalidLine = _RawLineNode(
        rawStart: const Offset(double.nan, 0),
        rawEnd: const Offset(2, 0),
        rawThickness: 1,
      );
      expect(invalidLine.localBounds, Rect.zero);

      final stroke = _RawStrokeNode(
        rawPoints: const <Offset>[Offset(0, 0), Offset(4, 0)],
        rawThickness: -1,
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

final class _RawTransformRectNode extends RectNode {
  _RawTransformRectNode({required Transform2D rawTransform})
    : _rawTransform = rawTransform,
      super(id: 'raw-rect', size: const Size(10, 10));

  final Transform2D _rawTransform;

  @override
  Transform2D get transform => _rawTransform;
}

final class _RawLineNode extends LineNode {
  _RawLineNode({
    required Offset rawStart,
    required Offset rawEnd,
    required double rawThickness,
  }) : _rawStart = rawStart,
       _rawEnd = rawEnd,
       _rawThickness = rawThickness,
       super(
         id: 'raw-line',
         start: const Offset(0, 0),
         end: const Offset(1, 1),
         thickness: 1,
         color: const Color(0xFF000000),
       );

  final Offset _rawStart;
  final Offset _rawEnd;
  final double _rawThickness;

  @override
  Offset get start => _rawStart;

  @override
  Offset get end => _rawEnd;

  @override
  double get thickness => _rawThickness;
}

final class _RawStrokeNode extends StrokeNode {
  _RawStrokeNode({
    required List<Offset> rawPoints,
    required double rawThickness,
  }) : _rawPoints = List<Offset>.unmodifiable(rawPoints),
       _rawThickness = rawThickness,
       super(
         id: 'raw-stroke',
         points: const <Offset>[Offset(0, 0), Offset(1, 1)],
         thickness: 1,
         color: const Color(0xFF000000),
       );

  final List<Offset> _rawPoints;
  final double _rawThickness;

  @override
  List<Offset> get points => _rawPoints;

  @override
  double get thickness => _rawThickness;
}

final class _RawSvgPathNode extends PathNode {
  _RawSvgPathNode({required String rawSvgPathData})
    : _rawSvgPathData = rawSvgPathData,
      super(id: 'raw-path', svgPathData: 'M0 0 L10 10');

  final String _rawSvgPathData;

  @override
  String get svgPathData => _rawSvgPathData;
}
