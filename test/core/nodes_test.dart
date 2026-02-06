import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';

void main() {
  // INV:INV-CORE-NORMALIZE-PRECONDITIONS
  test('ImageNode.fromTopLeftWorld positions bounds by world top-left', () {
    final node = ImageNode.fromTopLeftWorld(
      id: 'img-1',
      imageId: 'asset:sample',
      size: const Size(100, 50),
      topLeftWorld: const Offset(10, 20),
    );

    expect(node.topLeftWorld, const Offset(10, 20));
    expect(node.boundsWorld.size, const Size(100, 50));
  });

  test('ImageNode.topLeftWorld setter is a no-op for same value', () {
    final node = ImageNode.fromTopLeftWorld(
      id: 'img-1',
      imageId: 'asset:sample',
      size: const Size(100, 50),
      topLeftWorld: const Offset(10, 20),
    );

    final beforePosition = node.position;
    node.topLeftWorld = node.topLeftWorld;
    expect(node.position, beforePosition);
  });

  test('ImageNode.topLeftWorld setter moves bounds top-left', () {
    final node = ImageNode.fromTopLeftWorld(
      id: 'img-1',
      imageId: 'asset:sample',
      size: const Size(100, 50),
      topLeftWorld: const Offset(10, 20),
    );

    node.topLeftWorld = const Offset(30, 40);

    expect(node.boundsWorld.topLeft.dx, closeTo(30, 1e-9));
    expect(node.boundsWorld.topLeft.dy, closeTo(40, 1e-9));
  });

  test('TextNode.fromTopLeftWorld positions bounds by world top-left', () {
    final node = TextNode.fromTopLeftWorld(
      id: 'txt-1',
      text: 'Hello',
      size: const Size(100, 50),
      topLeftWorld: const Offset(10, 20),
      color: const Color(0xFF000000),
    );

    expect(node.topLeftWorld, const Offset(10, 20));
    expect(node.boundsWorld.size, const Size(100, 50));
  });

  test('TextNode.topLeftWorld setter moves bounds top-left', () {
    final node = TextNode.fromTopLeftWorld(
      id: 'txt-1',
      text: 'Hello',
      size: const Size(100, 50),
      topLeftWorld: const Offset(10, 20),
      color: const Color(0xFF000000),
    );

    node.topLeftWorld = const Offset(30, 40);

    expect(node.boundsWorld.topLeft.dx, closeTo(30, 1e-9));
    expect(node.boundsWorld.topLeft.dy, closeTo(40, 1e-9));
  });

  test('ImageNode boundsWorld centers on position', () {
    final node = ImageNode(
      id: 'img-1',
      imageId: 'asset:sample',
      size: const Size(10, 20),
    )..position = const Offset(5, 5);

    final rect = node.boundsWorld;
    expect(rect.center, const Offset(5, 5));
    expect(rect.width, 10);
    expect(rect.height, 20);
  });

  test('RectNode.fromTopLeftWorld positions bounds by world top-left', () {
    final node = RectNode.fromTopLeftWorld(
      id: 'rect-1',
      size: const Size(100, 50),
      topLeftWorld: const Offset(10, 20),
      fillColor: const Color(0xFF000000),
    );

    expect(node.topLeftWorld, const Offset(10, 20));
    expect(node.boundsWorld.size, const Size(100, 50));
  });

  test('RectNode.topLeftWorld setter moves bounds top-left', () {
    final node =
        RectNode(
            id: 'rect-1',
            size: const Size(100, 50),
            fillColor: const Color(0xFF000000),
          )
          ..position = const Offset(0, 0)
          ..rotationDeg = 45;

    node.topLeftWorld = const Offset(30, 40);

    expect(node.boundsWorld.topLeft.dx, closeTo(30, 1e-9));
    expect(node.boundsWorld.topLeft.dy, closeTo(40, 1e-9));
  });

  test('TextNode.topLeftWorld setter is a no-op for same value', () {
    final node = TextNode.fromTopLeftWorld(
      id: 'txt-1',
      text: 'Hello',
      size: const Size(100, 50),
      topLeftWorld: const Offset(10, 20),
      color: const Color(0xFF000000),
    );

    final beforePosition = node.position;
    node.topLeftWorld = node.topLeftWorld;
    expect(node.position, beforePosition);
  });

  test('RectNode localBounds includes strokeWidth/2 when stroked', () {
    // INV:INV-CORE-RECTNODE-BOUNDS-INCLUDE-STROKE
    final node = RectNode(
      id: 'rect-stroke-bounds',
      size: const Size(10, 20),
      strokeColor: const Color(0xFF000000),
      strokeWidth: 10,
    );

    final bounds = node.localBounds;
    expect(bounds.left, -10);
    expect(bounds.right, 10);
    expect(bounds.top, -15);
    expect(bounds.bottom, 15);
  });

  test('RectNode negative strokeWidth behaves like zero for localBounds', () {
    // INV:INV-CORE-NONNEGATIVE-WIDTHS-CLAMP
    final neg = RectNode(
      id: 'rect-stroke-neg',
      size: const Size(10, 20),
      strokeColor: const Color(0xFF000000),
      strokeWidth: -10,
    );
    final zero = RectNode(
      id: 'rect-stroke-zero',
      size: const Size(10, 20),
      strokeColor: const Color(0xFF000000),
      strokeWidth: 0,
    );

    expect(neg.localBounds, zero.localBounds);
  });

  test('LineNode boundsWorld inflates by thickness', () {
    final node = LineNode(
      id: 'line-1',
      start: const Offset(0, 0),
      end: const Offset(10, 0),
      thickness: 4,
      color: const Color(0xFF000000),
    );

    final rect = node.boundsWorld;
    expect(rect.left, -2);
    expect(rect.right, 12);
    expect(rect.top, -2);
    expect(rect.bottom, 2);
  });

  test('LineNode negative thickness behaves like zero for boundsWorld', () {
    // INV:INV-CORE-NONNEGATIVE-WIDTHS-CLAMP
    final node = LineNode(
      id: 'line-neg',
      start: const Offset(0, 0),
      end: const Offset(10, 0),
      thickness: -4,
      color: const Color(0xFF000000),
    );

    final rect = node.boundsWorld;
    expect(rect.left, 0);
    expect(rect.right, 10);
    expect(rect.top, 0);
    expect(rect.bottom, 0);
  });

  test('StrokeNode boundsWorld inflates by thickness', () {
    final node = StrokeNode(
      id: 'stroke-1',
      points: const [Offset(0, 0), Offset(10, 10)],
      thickness: 6,
      color: const Color(0xFF000000),
    );

    final rect = node.boundsWorld;
    expect(rect.left, -3);
    expect(rect.top, -3);
    expect(rect.right, 13);
    expect(rect.bottom, 13);
  });

  test('StrokeNode negative thickness behaves like zero for boundsWorld', () {
    final node = StrokeNode(
      id: 'stroke-neg',
      points: const [Offset(0, 0), Offset(10, 10)],
      thickness: -2,
      color: const Color(0xFF000000),
    );

    final rect = node.boundsWorld;
    expect(rect.left, 0);
    expect(rect.top, 0);
    expect(rect.right, 10);
    expect(rect.bottom, 10);
  });

  test('PathNode negative strokeWidth behaves like zero for boundsWorld', () {
    // INV:INV-CORE-NONNEGATIVE-WIDTHS-CLAMP
    final neg = PathNode(
      id: 'path-stroke-neg-bounds',
      svgPathData: 'M0 0 H40 V30 H0 Z',
      strokeColor: const Color(0xFF000000),
      strokeWidth: -10,
    );
    final zero = PathNode(
      id: 'path-stroke-zero-bounds',
      svgPathData: 'M0 0 H40 V30 H0 Z',
      strokeColor: const Color(0xFF000000),
      strokeWidth: 0,
    );

    expect(neg.boundsWorld, zero.boundsWorld);
  });

  test('StrokeNode.position translates points', () {
    final node = StrokeNode.fromWorldPoints(
      id: 'stroke-1',
      points: const [Offset(0, 0), Offset(10, 0)],
      thickness: 2,
      color: const Color(0xFF000000),
    );

    expect(node.position, const Offset(5, 0));
    node.position = const Offset(7, 3);

    expect(node.points, const [Offset(-5, 0), Offset(5, 0)]);
    expect(node.transform.applyToPoint(node.points[0]), const Offset(2, 3));
    expect(node.transform.applyToPoint(node.points[1]), const Offset(12, 3));
    expect(node.position, const Offset(7, 3));
  });

  test('LineNode.position translates endpoints', () {
    final node = LineNode.fromWorldSegment(
      id: 'line-1',
      start: const Offset(0, 0),
      end: const Offset(10, 0),
      thickness: 2,
      color: const Color(0xFF000000),
    );

    expect(node.position, const Offset(5, 0));
    node.position = const Offset(5, 5);

    expect(node.start, const Offset(-5, 0));
    expect(node.end, const Offset(5, 0));
    expect(node.transform.applyToPoint(node.start), const Offset(0, 5));
    expect(node.transform.applyToPoint(node.end), const Offset(10, 5));
  });

  test('PathNode.buildLocalPath returns null for empty and invalid data', () {
    // INV:INV-CORE-PATHNODE-BUILDLOCALPATH-DIAGNOSTICS
    final empty = PathNode(id: 'p1', svgPathData: '   ');
    expect(empty.buildLocalPath(), isNull);
    expect(empty.debugLastBuildLocalPathFailureReason, 'empty-svg-path-data');
    expect(empty.debugLastBuildLocalPathException, isNull);

    final invalid = PathNode(id: 'p2', svgPathData: 'not-a-path');
    expect(invalid.buildLocalPath(), isNull);
    expect(
      invalid.debugLastBuildLocalPathFailureReason,
      'exception-while-building-local-path',
    );
    expect(invalid.debugLastBuildLocalPathException, isNotNull);
    expect(invalid.debugLastBuildLocalPathStackTrace, isNotNull);

    final zeroLength = PathNode(id: 'p3', svgPathData: 'M0 0');
    expect(zeroLength.buildLocalPath(), isNull);
    expect(
      zeroLength.debugLastBuildLocalPathFailureReason,
      'svg-path-has-no-nonzero-length',
    );
    expect(zeroLength.debugLastBuildLocalPathException, isNull);
    expect(zeroLength.debugLastBuildLocalPathStackTrace, isNull);
  });

  test('PathNode.buildLocalPath accepts linear (degenerate bounds) paths', () {
    // INV:INV-CORE-PATHNODE-LINEAR-PATHS
    final node = PathNode(
      id: 'p-linear',
      svgPathData: 'M0 0 L0 10',
      strokeColor: const Color(0xFF000000),
      strokeWidth: 1,
    );

    final path = node.buildLocalPath();
    expect(path, isNotNull);
    expect(node.localBounds, isNot(Rect.zero));
    expect(node.localBounds.isEmpty, isFalse);
  });

  test(
    'PathNode.buildLocalPath applies fill rule and boundsWorld uses transforms',
    () {
      final node =
          PathNode(
              id: 'path-1',
              svgPathData: 'M0 0 H40 V30 H0 Z M12 8 H28 V22 H12 Z',
              fillRule: PathFillRule.evenOdd,
            )
            ..position = const Offset(100, 100)
            ..rotationDeg = 90
            ..scaleX = 2
            ..scaleY = 0.5;

      final path = node.buildLocalPath();
      expect(path, isNotNull);
      expect(path!.fillType, PathFillType.evenOdd);
      expect(node.boundsWorld, isNot(Rect.zero));
    },
  );

  test('PathNode invalidates cached path on data changes', () {
    final node = PathNode(id: 'path-cache', svgPathData: 'M0 0 H10 V10 H0 Z');

    final first = node.buildLocalPath();
    expect(first, isNotNull);
    final firstBounds = first!.getBounds();

    node.svgPathData = 'M0 0 H20 V6 H0 Z';
    final second = node.buildLocalPath();
    expect(second, isNotNull);
    final secondBounds = second!.getBounds();

    expect(secondBounds.width, isNot(firstBounds.width));

    node.fillRule = PathFillRule.evenOdd;
    final third = node.buildLocalPath();
    expect(third, isNotNull);
    expect(third!.fillType, PathFillType.evenOdd);
  });

  test('PathNode.buildLocalPath returns a defensive copy by default', () {
    // INV:INV-CORE-PATHNODE-LOCALPATH-DEFENSIVE-COPY
    final node = PathNode(id: 'path-copy', svgPathData: 'M0 0 H10 V10 H0 Z');

    final boundsBefore = node.localBounds;

    final localPathCopy = node.buildLocalPath();
    expect(localPathCopy, isNotNull);
    localPathCopy!.addRect(const Rect.fromLTWH(-100, -100, 10, 10));

    expect(node.localBounds, boundsBefore);

    // Internal/hot callers can opt into the cached instance.
    final localPathCached = node.buildLocalPath(copy: false);
    expect(localPathCached, isNotNull);
  });

  test(
    'PathNode.buildLocalPath diagnostics can be enabled in release builds',
    () {
      final previous = PathNode.enableBuildLocalPathDiagnostics;
      PathNode.enableBuildLocalPathDiagnostics = true;
      addTearDown(() => PathNode.enableBuildLocalPathDiagnostics = previous);

      final node = PathNode(id: 'path-diag-1', svgPathData: 'not-a-path');
      expect(node.buildLocalPath(), isNull);
      expect(node.debugLastBuildLocalPathFailureReason, isNotNull);
      expect(node.debugLastBuildLocalPathException, isNotNull);
      expect(node.debugLastBuildLocalPathStackTrace, isNotNull);

      node.svgPathData = 'M0 0 H10 V10 H0 Z';
      expect(node.buildLocalPath(), isNotNull);
      expect(node.debugLastBuildLocalPathFailureReason, isNull);
      expect(node.debugLastBuildLocalPathException, isNull);
      expect(node.debugLastBuildLocalPathStackTrace, isNull);
    },
  );

  test('normalizeToLocalCenter asserts on non-identity transforms', () {
    final stroke = StrokeNode.fromWorldPoints(
      id: 's1',
      points: const [Offset(0, 0), Offset(10, 0)],
      thickness: 2,
      color: const Color(0xFF000000),
    );
    expect(() => stroke.normalizeToLocalCenter(), throwsA(isA<StateError>()));

    final line = LineNode.fromWorldSegment(
      id: 'l1',
      start: const Offset(0, 0),
      end: const Offset(10, 0),
      thickness: 2,
      color: const Color(0xFF000000),
    );
    expect(() => line.normalizeToLocalCenter(), throwsA(isA<StateError>()));
  });

  test('normalizeToLocalCenter asserts on non-finite geometry', () {
    final stroke = StrokeNode(
      id: 's2',
      points: [const Offset(0, 0), Offset(double.nan, 0)],
      thickness: 2,
      color: const Color(0xFF000000),
    );
    expect(() => stroke.normalizeToLocalCenter(), throwsA(isA<StateError>()));

    final line = LineNode(
      id: 'l2',
      start: const Offset(0, 0),
      end: Offset(double.infinity, 0),
      thickness: 2,
      color: const Color(0xFF000000),
    );
    expect(() => line.normalizeToLocalCenter(), throwsA(isA<StateError>()));
  });

  test('normalizeToLocalCenter does not mutate on precondition failure', () {
    // INV:INV-CORE-NORMALIZE-PRECONDITIONS
    final stroke = StrokeNode(
      id: 's2-no-mutate',
      points: const [Offset(0, 0), Offset(10, 0)],
      thickness: 2,
      color: const Color(0xFF000000),
      transform: Transform2D.translation(const Offset(1, 2)),
    );
    final strokeBeforeTransform = stroke.transform;
    final strokeBeforePoints = List<Offset>.from(stroke.points);
    expect(() => stroke.normalizeToLocalCenter(), throwsA(isA<StateError>()));
    expect(stroke.transform, strokeBeforeTransform);
    expect(stroke.points, strokeBeforePoints);

    final line = LineNode(
      id: 'l2-no-mutate',
      start: const Offset(0, 0),
      end: const Offset(10, 0),
      thickness: 2,
      color: const Color(0xFF000000),
      transform: Transform2D.translation(const Offset(1, 2)),
    );
    final lineBeforeTransform = line.transform;
    final lineBeforeStart = line.start;
    final lineBeforeEnd = line.end;
    expect(() => line.normalizeToLocalCenter(), throwsA(isA<StateError>()));
    expect(line.transform, lineBeforeTransform);
    expect(line.start, lineBeforeStart);
    expect(line.end, lineBeforeEnd);
  });

  test('normalizeToLocalCenter converts world geometry to local space', () {
    final stroke = StrokeNode(
      id: 's3',
      points: const [Offset(0, 0), Offset(10, 0)],
      thickness: 2,
      color: const Color(0xFF000000),
    );

    stroke.normalizeToLocalCenter();
    expect(stroke.position, const Offset(5, 0));
    expect(stroke.points, const [Offset(-5, 0), Offset(5, 0)]);

    final line = LineNode(
      id: 'l3',
      start: const Offset(0, 0),
      end: const Offset(10, 0),
      thickness: 2,
      color: const Color(0xFF000000),
    );

    line.normalizeToLocalCenter();
    expect(line.position, const Offset(5, 0));
    expect(line.start, const Offset(-5, 0));
    expect(line.end, const Offset(5, 0));
  });

  test('SceneNode.rotationDeg uses second column when first is near zero', () {
    final node = RectNode(id: 'rect-rot', size: const Size(10, 10))
      ..transform = const Transform2D(a: 0, b: 0, c: -1, d: 0, tx: 0, ty: 0);
    expect(node.rotationDeg, closeTo(90.0, 1e-9));
  });

  test('SceneNode.scaleY uses column magnitude and determinant sign', () {
    final node = RectNode(id: 'rect-scaleY', size: const Size(10, 10))
      ..transform = const Transform2D(a: 1, b: 0, c: 0, d: -2, tx: 0, ty: 0);
    expect(node.scaleY, closeTo(-2.0, 1e-9));
  });

  test('SceneNode TRS decomposition is canonical for flips', () {
    // INV:INV-CORE-TRS-DECOMPOSITION-CANONICAL-FLIP
    final flipX = RectNode(id: 'rect-flipX', size: const Size(10, 10))
      ..transform = const Transform2D(a: -1, b: 0, c: 0, d: 1, tx: 10, ty: 20);
    expect(flipX.scaleX, closeTo(1.0, 1e-9));
    expect(flipX.scaleY, closeTo(-1.0, 1e-9));
    expect(flipX.rotationDeg, closeTo(180.0, 1e-9));
    final flipXRoundTrip = Transform2D.trs(
      translation: flipX.position,
      rotationDeg: flipX.rotationDeg,
      scaleX: flipX.scaleX,
      scaleY: flipX.scaleY,
    );
    expect(flipXRoundTrip.a, closeTo(-1.0, 1e-9));
    expect(flipXRoundTrip.b, closeTo(0.0, 1e-9));
    expect(flipXRoundTrip.c, closeTo(0.0, 1e-9));
    expect(flipXRoundTrip.d, closeTo(1.0, 1e-9));
    expect(flipXRoundTrip.tx, closeTo(10.0, 1e-9));
    expect(flipXRoundTrip.ty, closeTo(20.0, 1e-9));

    final flipY = RectNode(id: 'rect-flipY', size: const Size(10, 10))
      ..transform = const Transform2D(a: 1, b: 0, c: 0, d: -1, tx: -3, ty: 7);
    expect(flipY.scaleX, closeTo(1.0, 1e-9));
    expect(flipY.scaleY, closeTo(-1.0, 1e-9));
    expect(flipY.rotationDeg, closeTo(0.0, 1e-9));
    final flipYRoundTrip = Transform2D.trs(
      translation: flipY.position,
      rotationDeg: flipY.rotationDeg,
      scaleX: flipY.scaleX,
      scaleY: flipY.scaleY,
    );
    expect(flipYRoundTrip.a, closeTo(1.0, 1e-9));
    expect(flipYRoundTrip.b, closeTo(0.0, 1e-9));
    expect(flipYRoundTrip.c, closeTo(0.0, 1e-9));
    expect(flipYRoundTrip.d, closeTo(-1.0, 1e-9));
    expect(flipYRoundTrip.tx, closeTo(-3.0, 1e-9));
    expect(flipYRoundTrip.ty, closeTo(7.0, 1e-9));
  });

  test(
    'SceneNode rotationDeg/scaleX/scaleY setters reject sheared transforms',
    () {
      // INV:INV-CORE-CONVENIENCE-SETTERS-REJECT-SHEAR
      final node = RectNode(id: 'rect-shear', size: const Size(10, 10))
        ..transform = const Transform2D(a: 1, b: 0, c: 1, d: 1, tx: 0, ty: 0);

      expect(() => node.rotationDeg = 10, throwsA(isA<StateError>()));
      expect(() => node.scaleX = 2, throwsA(isA<StateError>()));
      expect(() => node.scaleY = 2, throwsA(isA<StateError>()));
    },
  );

  test('SceneNode rotationDeg setter rejects non-finite transforms', () {
    final node = RectNode(id: 'rect-nan', size: const Size(10, 10))
      ..transform = Transform2D(a: double.nan, b: 0, c: 0, d: 1, tx: 0, ty: 0);

    expect(() => node.rotationDeg = 10, throwsA(isA<StateError>()));
  });

  test(
    'SceneNode.rotationDeg/scaleY stay finite for tiny finite transforms',
    () {
      final node = RectNode(id: 'rect-tiny', size: const Size(10, 10));
      final transforms = <Transform2D>[
        const Transform2D(a: 1e-300, b: 0, c: 0, d: 1e-300, tx: 0, ty: 0),
        const Transform2D(a: 0, b: 0, c: 1e-300, d: 0, tx: 0, ty: 0),
        const Transform2D(a: 1e-12, b: 1e-12, c: 0, d: 1e-12, tx: 0, ty: 0),
      ];
      for (final t in transforms) {
        node.transform = t;
        expect(node.rotationDeg.isFinite, isTrue);
        expect(node.scaleY.isFinite, isTrue);
      }
    },
  );

  test(
    'RectNode.topLeftWorld setter does not drift under repeated near-identical values',
    () {
      final node = RectNode(
        id: 'rect-topLeft-drift',
        size: const Size(100, 50),
        fillColor: const Color(0xFF000000),
      )..rotationDeg = 45;

      final target = node.topLeftWorld;
      final beforePosition = node.position;
      const jitter = Offset(1e-10, -1e-10);
      for (var i = 0; i < 1000; i++) {
        node.topLeftWorld = target + jitter;
      }
      expect(node.position, beforePosition);
    },
  );

  test('SceneNode bounds stay finite for non-finite numeric inputs', () {
    // INV:INV-CORE-RUNTIME-NUMERIC-SANITIZATION
    bool isFiniteRect(Rect rect) {
      return rect.left.isFinite &&
          rect.top.isFinite &&
          rect.right.isFinite &&
          rect.bottom.isFinite;
    }

    final nodes = <SceneNode>[
      ImageNode(
        id: 'img-nonfinite',
        imageId: 'asset:sample',
        size: const Size(double.infinity, double.nan),
        hitPadding: double.nan,
        opacity: double.nan,
      ),
      TextNode(
        id: 'txt-nonfinite',
        text: 'Hello',
        size: const Size(double.nan, double.infinity),
        fontSize: double.nan,
        maxWidth: double.nan,
        lineHeight: double.infinity,
        color: const Color(0xFF000000),
        hitPadding: double.infinity,
        opacity: double.infinity,
      ),
      StrokeNode(
        id: 'stroke-nonfinite',
        points: const [Offset(double.nan, 0), Offset(10, 10)],
        thickness: double.nan,
        color: const Color(0xFF000000),
      ),
      LineNode(
        id: 'line-nonfinite',
        start: const Offset(double.nan, 0),
        end: const Offset(10, 0),
        thickness: double.infinity,
        color: const Color(0xFF000000),
      ),
      RectNode(
        id: 'rect-nonfinite',
        size: const Size(double.infinity, double.nan),
        fillColor: const Color(0xFF000000),
        strokeColor: const Color(0xFF000000),
        strokeWidth: double.nan,
        hitPadding: double.nan,
        opacity: double.nan,
      ),
      PathNode(
        id: 'path-nonfinite',
        svgPathData: 'M0 0 H40',
        strokeColor: const Color(0xFF000000),
        strokeWidth: double.infinity,
        hitPadding: double.nan,
        opacity: double.nan,
      ),
    ];

    for (final node in nodes) {
      expect(isFiniteRect(node.localBounds), isTrue, reason: node.id);
      expect(isFiniteRect(node.boundsWorld), isTrue, reason: node.id);
    }
  });

  test('SceneNode.opacity normalizes constructor and setter writes', () {
    // INV:INV-CORE-OPACITY-RUNTIME-CLAMP01
    final fromNan = RectNode(
      id: 'rect-opacity-nan',
      size: const Size(10, 10),
      opacity: double.nan,
    );
    expect(fromNan.opacity, 1);

    final fromInfinity = RectNode(
      id: 'rect-opacity-inf',
      size: const Size(10, 10),
      opacity: double.infinity,
    );
    expect(fromInfinity.opacity, 1);

    final fromNegative = RectNode(
      id: 'rect-opacity-neg',
      size: const Size(10, 10),
      opacity: -0.2,
    );
    expect(fromNegative.opacity, 0);

    final fromAboveOne = RectNode(
      id: 'rect-opacity-hi',
      size: const Size(10, 10),
      opacity: 1.7,
    );
    expect(fromAboveOne.opacity, 1);

    final setter = RectNode(
      id: 'rect-opacity-setter',
      size: const Size(10, 10),
    );
    setter.opacity = double.nan;
    expect(setter.opacity, 1);
    setter.opacity = -0.2;
    expect(setter.opacity, 0);
    setter.opacity = 1.7;
    expect(setter.opacity, 1);
  });

  test('boundsWorld is Rect.zero for non-finite transforms', () {
    final node = RectNode(
      id: 'rect-nonfinite-transform',
      size: const Size(10, 10),
    )..transform = Transform2D(a: 1, b: 0, c: 0, d: 1, tx: double.nan, ty: 0);
    expect(node.boundsWorld, Rect.zero);
  });
}
