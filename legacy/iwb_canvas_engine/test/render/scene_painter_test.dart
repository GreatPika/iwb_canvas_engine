import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart' as iwb;
import 'package:iwb_canvas_engine/src/contract/scene_view_render_state.dart';
import 'package:iwb_canvas_engine/src/contract/internal/snapshot_fast_path.dart';
import 'package:iwb_canvas_engine/src/contract/internal/unsafe_snapshot_materialization.dart';
import 'package:iwb_canvas_engine/src/contract/transform2d.dart';
import 'package:iwb_canvas_engine/src/controller/scene_store_controller.dart';
import 'package:iwb_canvas_engine/src/contract/node_spec.dart';
import 'package:iwb_canvas_engine/src/contract/scene_data_exception.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/core/node_geometry.dart';
import 'package:iwb_canvas_engine/src/render/render_geometry_cache.dart';
import 'package:iwb_canvas_engine/src/render/scene_grid_renderer.dart';
import 'package:iwb_canvas_engine/src/render/scene_painter.dart';
import 'package:iwb_canvas_engine/src/render/scene_painter_contract.dart';
import 'package:iwb_canvas_engine/src/render/scene_painter_node_renderer.dart';
import 'package:iwb_canvas_engine/src/core/scene_snapshot_paint_candidates.dart';
import 'package:iwb_canvas_engine/src/core/snapshot_paint_admission_bounds.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/interactive_move_preview_read.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/scene_controller_scene_view_runtime.dart';
import 'package:iwb_canvas_engine/src/interactive/scene_controller.dart'
    as interactive;

import '../support/committed_scene_view_read_state.dart';

// INV:INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION
// INV:INV-ENG-SELECTION-BOUNDED-COMPOSITING

class _FakeRenderState extends ChangeNotifier
    implements SceneViewMainSceneRenderRead {
  _FakeRenderState({
    required this.snapshot,
    Set<NodeId>? selectedNodeIds,
    this.selectionRect,
    Offset Function(NodeId nodeId)? previewDeltaResolver,
  }) : _selectedNodeIds = selectedNodeIds ?? const <NodeId>{},
       _previewDeltaResolver = previewDeltaResolver;

  @override
  SceneSnapshot snapshot;
  Set<NodeId> _selectedNodeIds;
  final Offset Function(NodeId nodeId)? _previewDeltaResolver;
  final SnapshotPaintAdmissionBoundsCache _snapshotPaintAdmissionBoundsCache =
      SnapshotPaintAdmissionBoundsCache();

  @override
  final int controllerEpoch = 0;

  Listenable get overlayRepaintListenable => this;

  Rect? selectionRect;

  Offset get cameraOffset => snapshot.camera.offset;

  @override
  Set<NodeId> get selectedNodeIds => _selectedNodeIds;

  @override
  SceneViewFrameRead captureFrameRead() {
    final previewDeltaResolver = _previewDeltaResolver ?? _zeroPreviewDelta;
    return SceneViewFrameRead(
      snapshot: snapshot,
      selectedNodeIds: selectedNodeIds,
      selectionRevision: 0,
      preview: SceneViewFramePreview.captureSnapshot(
        snapshot: snapshot,
        deltaForNode: previewDeltaResolver,
      ),
    );
  }

  @override
  ScenePreparedPaintPlan preparePaintPlan(
    SceneViewFrameRead frameRead,
    ScenePaintCandidateQuery query,
  ) {
    return ScenePreparedPaintCandidateList(
      enumerateSnapshotPaintCandidates(
        snapshot: frameRead.snapshot,
        query: query,
        selectedNodeIds: frameRead.selectedNodeIds,
        preview: frameRead.preview,
        admissionBounds: _snapshotPaintAdmissionBoundsCache,
      ),
    );
  }

  bool get hasActiveStrokePreview => false;

  List<Offset> get activeStrokePreviewPoints => const <Offset>[];

  double get activeStrokePreviewThickness => 0;

  Color get activeStrokePreviewColor => const Color(0x00000000);

  double get activeStrokePreviewOpacity => 0;

  bool get hasActiveLinePreview => false;

  Offset? get activeLinePreviewStart => null;

  Offset? get activeLinePreviewEnd => null;

  double get activeLinePreviewThickness => 0;

  Color get activeLinePreviewColor => const Color(0x00000000);

  set selectedNodeIds(Set<NodeId> value) {
    _selectedNodeIds = value;
    notifyListeners();
  }
}

final class _FixedMovePreviewRead implements InteractiveMovePreviewRead {
  _FixedMovePreviewRead({
    required this.readSnapshot,
    required this.deltaForNode,
  });

  final SceneSnapshot Function() readSnapshot;
  final Offset Function(NodeId nodeId) deltaForNode;

  @override
  SceneViewFramePreview captureFramePreview() {
    return SceneViewFramePreview.captureSnapshot(
      snapshot: readSnapshot(),
      deltaForNode: deltaForNode,
    );
  }

  @override
  Offset previewDeltaForNode(NodeId nodeId) => deltaForNode(nodeId);
}

Offset _zeroPreviewDelta(NodeId _) => Offset.zero;

CommittedSceneViewReadState _mirrorRenderState(
  SceneStoreController controller, {
  Offset Function(NodeId nodeId)? previewDeltaResolver,
  Rect? selectionRect,
}) {
  final renderState = CommittedSceneViewReadState.mirror(
    controller,
    previewDeltaResolver: previewDeltaResolver,
    selectionRect: selectionRect,
  );
  addTearDown(renderState.dispose);
  return renderState;
}

SceneViewMainSceneRenderRead _controllerOwnedRenderState(
  SceneStoreController controller, {
  Set<NodeId>? selectedNodeIds,
  Offset Function(NodeId nodeId)? previewDeltaResolver,
}) {
  SceneSnapshot readSnapshot() => controller.snapshot;
  final renderState = SceneControllerSceneViewMainSceneRenderRead(
    storeController: controller,
    readSnapshot: readSnapshot,
    readSelectedNodeIds: () => selectedNodeIds ?? controller.selectedNodeIds,
    readControllerEpoch: () => controller.controllerEpoch,
    readMovePreview: () => _FixedMovePreviewRead(
      readSnapshot: readSnapshot,
      deltaForNode: previewDeltaResolver ?? _zeroPreviewDelta,
    ),
  );
  addTearDown(renderState.dispose);
  return renderState;
}

Future<Image> _solidImage(Color color, {int width = 8, int height = 8}) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  return recorder.endRecording().toImage(width, height);
}

Future<Image> _paintToImage(
  ScenePainter painter, {
  int width = 120,
  int height = 120,
}) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, Size(width.toDouble(), height.toDouble()));
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}

Future<int> _countNonBackgroundPixels(Image image, Color background) async {
  final data = await image.toByteData(format: ImageByteFormat.rawRgba);
  if (data == null) {
    throw StateError('Failed to encode image to raw RGBA.');
  }
  final bytes = data.buffer.asUint8List();
  final bg = background.toARGB32();
  final bgA = (bg >> 24) & 0xFF;
  final bgR = (bg >> 16) & 0xFF;
  final bgG = (bg >> 8) & 0xFF;
  final bgB = bg & 0xFF;

  var count = 0;
  for (var i = 0; i < bytes.length; i += 4) {
    if (bytes[i] != bgR ||
        bytes[i + 1] != bgG ||
        bytes[i + 2] != bgB ||
        bytes[i + 3] != bgA) {
      count++;
    }
  }
  return count;
}

Future<Color> _pixelColor(Image image, int x, int y) async {
  if (x < 0 || y < 0 || x >= image.width || y >= image.height) {
    throw ArgumentError('Pixel ($x, $y) is outside image bounds.');
  }
  final data = await image.toByteData(format: ImageByteFormat.rawRgba);
  if (data == null) {
    throw StateError('Failed to encode image to raw RGBA.');
  }
  final bytes = data.buffer.asUint8List();
  final index = (y * image.width + x) * 4;
  return Color.fromARGB(
    bytes[index + 3],
    bytes[index],
    bytes[index + 1],
    bytes[index + 2],
  );
}

Future<double> _inkCentroidX(Image image, Color background) async {
  final data = await image.toByteData(format: ImageByteFormat.rawRgba);
  if (data == null) {
    throw StateError('Failed to encode image to raw RGBA.');
  }
  final bytes = data.buffer.asUint8List();
  final argb = background.toARGB32();
  final bgR = (argb >> 16) & 0xFF;
  final bgG = (argb >> 8) & 0xFF;
  final bgB = argb & 0xFF;

  double weightedX = 0;
  double totalInk = 0;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final index = (y * image.width + x) * 4;
      final dr = (bytes[index] - bgR).abs();
      final dg = (bytes[index + 1] - bgG).abs();
      final db = (bytes[index + 2] - bgB).abs();
      final ink = (dr + dg + db).toDouble();
      if (ink <= 0) {
        continue;
      }
      weightedX += x * ink;
      totalInk += ink;
    }
  }
  if (totalInk == 0) {
    throw StateError('Expected non-background pixels.');
  }
  return weightedX / totalInk;
}

Future<int> _countDarkPixelsOnRow(Image image, int y, Color background) async {
  final data = await image.toByteData(format: ImageByteFormat.rawRgba);
  if (data == null) {
    throw StateError('Failed to encode image to raw RGBA.');
  }

  var count = 0;
  final bytes = data.buffer.asUint8List();
  final argb = background.toARGB32();
  final bgA = (argb >> 24) & 0xFF;
  final bgR = (argb >> 16) & 0xFF;
  final bgG = (argb >> 8) & 0xFF;
  final bgB = argb & 0xFF;
  for (var x = 0; x < image.width; x++) {
    final index = (y * image.width + x) * 4;
    if (bytes[index] != bgR ||
        bytes[index + 1] != bgG ||
        bytes[index + 2] != bgB ||
        bytes[index + 3] != bgA) {
      count++;
    }
  }
  return count;
}

Future<Rect> _inkBounds(Image image, Color background) async {
  final data = await image.toByteData(format: ImageByteFormat.rawRgba);
  if (data == null) {
    throw StateError('Failed to encode image to raw RGBA.');
  }
  final bytes = data.buffer.asUint8List();
  final argb = background.toARGB32();
  final bgA = (argb >> 24) & 0xFF;
  final bgR = (argb >> 16) & 0xFF;
  final bgG = (argb >> 8) & 0xFF;
  final bgB = argb & 0xFF;

  var minX = image.width;
  var minY = image.height;
  var maxX = -1;
  var maxY = -1;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final index = (y * image.width + x) * 4;
      if (bytes[index] == bgR &&
          bytes[index + 1] == bgG &&
          bytes[index + 2] == bgB &&
          bytes[index + 3] == bgA) {
        continue;
      }
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }

  if (maxX < minX || maxY < minY) {
    throw StateError('Expected non-background pixels.');
  }
  return Rect.fromLTRB(
    minX.toDouble(),
    minY.toDouble(),
    (maxX + 1).toDouble(),
    (maxY + 1).toDouble(),
  );
}

void _expectRectNear(Rect actual, Rect expected, {double tolerance = 2.0}) {
  expect((actual.left - expected.left).abs(), lessThanOrEqualTo(tolerance));
  expect((actual.top - expected.top).abs(), lessThanOrEqualTo(tolerance));
  expect((actual.right - expected.right).abs(), lessThanOrEqualTo(tolerance));
  expect((actual.bottom - expected.bottom).abs(), lessThanOrEqualTo(tolerance));
}

List<Object?> _recordedSaveLayerBounds(TestRecordingCanvas canvas) {
  return canvas.invocations
      .where((entry) => entry.invocation.memberName == #saveLayer)
      .map((entry) => entry.invocation.positionalArguments.first)
      .toList(growable: false);
}

Future<void> _expectSameImagePixels(Image actual, Image expected) async {
  expect(actual.width, expected.width);
  expect(actual.height, expected.height);

  final actualData = await actual.toByteData(format: ImageByteFormat.rawRgba);
  if (actualData == null) {
    throw StateError('Failed to encode actual image to raw RGBA.');
  }
  final expectedData = await expected.toByteData(
    format: ImageByteFormat.rawRgba,
  );
  if (expectedData == null) {
    throw StateError('Failed to encode expected image to raw RGBA.');
  }

  expect(actualData.buffer.asUint8List(), expectedData.buffer.asUint8List());
}

Future<Image> _paintLegacyRectHaloImage({
  required Rect rect,
  required Color background,
  required Color fillColor,
  required Color selectionColor,
  required double selectionStrokeWidth,
  required int width,
  required int height,
}) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = background,
  );
  canvas.drawRect(
    rect,
    Paint()
      ..style = PaintingStyle.fill
      ..color = fillColor,
  );
  canvas.saveLayer(null, Paint());
  canvas.drawRect(
    rect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = selectionStrokeWidth * 2
      ..color = selectionColor,
  );
  final clearPaint = Paint()
    ..style = PaintingStyle.fill
    ..blendMode = BlendMode.clear;
  canvas.drawRect(rect, clearPaint);
  canvas.restore();
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ScenePainter paints all node variants and selection', () async {
    const background = Color(0xFFFFFFFF);
    final image = await _solidImage(const Color(0xFFFF00FF));

    final controller = SceneStoreController(
      initialSnapshot: SceneSnapshot(
        camera: CameraSnapshot(offset: Offset(4, -3)),
        background: BackgroundSnapshot(
          color: background,
          grid: GridSnapshot(
            isEnabled: true,
            cellSize: 10,
            color: Color(0xFF000000),
          ),
        ),
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'layer-auto-0',
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(
                id: 'rect-1',
                size: const Size(30, 20),
                fillColor: const Color(0xFF2196F3),
                strokeColor: const Color(0xFF000000),
                strokeWidth: 2,
                transform: Transform2D.translation(const Offset(20, 20)),
              ),
              LineNodeSnapshot(
                id: 'line-1',
                start: Offset(0, 0),
                end: Offset(20, 0),
                thickness: 3,
                color: Color(0xFF4CAF50),
                transform: Transform2D(a: 1, b: 0, c: 0, d: 1, tx: 55, ty: 18),
              ),
              StrokeNodeSnapshot(
                id: 'stroke-1',
                points: const <Offset>[Offset(0, 0), Offset(10, 10)],
                thickness: 4,
                color: const Color(0xFFFF9800),
                transform: Transform2D.translation(const Offset(70, 25)),
              ),
              TextNodeSnapshot(
                id: 'text-1',
                text: 'TXT',
                fontSize: 14,
                color: const Color(0xFF000000),
                align: TextAlign.center,
                textDirection: TextDirection.ltr,
                transform: Transform2D.translation(const Offset(25, 60)),
              ),
              ImageNodeSnapshot(
                id: 'img-1',
                imageId: 'img',
                size: const Size(16, 16),
                transform: Transform2D.translation(const Offset(55, 55)),
              ),
              PathNodeSnapshot(
                id: 'path-1',
                svgPathData: 'M0 0 H16 V16 H0 Z M4 4 H12 V12 H4 Z',
                fillColor: const Color(0xFF81C784),
                strokeColor: const Color(0xFF1B5E20),
                strokeWidth: 2,
                fillRule: PathFillRule.evenOdd,
                transform: Transform2D.translation(const Offset(85, 60)),
              ),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    final renderState = _mirrorRenderState(controller);
    controller.write<void>((writer) {
      writer.writeSelectionReplace(const <String>{'rect-1', 'path-1'});
    });

    final painter = ScenePainter(
      controller: renderState,
      imageResolver: (id) => id == 'img' ? image : null,
      selectionColor: const Color(0xFFFF0000),
      selectionStrokeWidth: 2,
    );

    final rendered = await _paintToImage(painter, width: 120, height: 90);
    final nonBackground = await _countNonBackgroundPixels(rendered, background);
    expect(nonBackground, greaterThan(0));
  });

  test(
    'ScenePainterNodeRenderer rejects text paint without frame-resolved text layout',
    () {
      final textNode = TextNodeSnapshot(
        id: 'text-missing-layout',
        text: 'layout',
        fontSize: 14,
        color: const Color(0xFF000000),
        textDirection: TextDirection.ltr,
      );
      final renderer = ScenePainterNodeRenderer(
        imageResolver: (_) => null,
        transformBuffer: Float64List(16),
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(
        () => renderer.paintNodeLayers(
          canvas: canvas,
          frame: ScenePainterPaintFrame(
            cameraOffset: Offset.zero,
            viewRect: const Rect.fromLTWH(-20, -20, 40, 40),
            paintPlan: ScenePreparedPaintCandidateList(<ScenePaintCandidate>[
              ScenePaintCandidate(
                node: textNode,
                paintBoundsWorld: nodeSnapshotBoundsWorld(textNode),
              ),
            ]),
            selectedIds: const <NodeId>{},
            selectionStyle: const ScenePainterSelectionStyle(
              color: Color(0xFF1565C0),
              haloWidth: 1,
            ),
          ),
          resolveNodePaintData: (_) => ScenePainterResolvedNodePaintData(
            node: textNode,
            previewDelta: Offset.zero,
            geometry: const GeometryEntry(
              localBounds: Rect.fromLTRB(-10, -10, 10, 10),
              worldBounds: Rect.fromLTRB(-10, -10, 10, 10),
            ),
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Missing resolved text layout'),
          ),
        ),
      );

      recorder.endRecording();
    },
  );

  test(
    'ScenePainterNodeRenderer rejects multi-point stroke paint without frame-resolved path',
    () {
      final strokeNode = StrokeNodeSnapshot(
        id: 'stroke-missing-path',
        points: const <Offset>[Offset(0, 0), Offset(20, 0)],
        thickness: 4,
        color: const Color(0xFF000000),
      );
      final renderer = ScenePainterNodeRenderer(
        imageResolver: (_) => null,
        transformBuffer: Float64List(16),
      );

      expect(
        () => renderer.paintNodeLayers(
          canvas: TestRecordingCanvas(),
          frame: ScenePainterPaintFrame(
            cameraOffset: Offset.zero,
            viewRect: const Rect.fromLTWH(-20, -20, 80, 80),
            paintPlan: ScenePreparedPaintCandidateList(<ScenePaintCandidate>[
              ScenePaintCandidate(
                node: strokeNode,
                paintBoundsWorld: nodeSnapshotBoundsWorld(strokeNode),
              ),
            ]),
            selectedIds: const <NodeId>{},
            selectionStyle: const ScenePainterSelectionStyle(
              color: Color(0xFF1565C0),
              haloWidth: 1,
            ),
          ),
          resolveNodePaintData: (_) => ScenePainterResolvedNodePaintData(
            node: strokeNode,
            previewDelta: Offset.zero,
            geometry: GeometryEntry(
              localBounds: const Rect.fromLTRB(-2, -2, 22, 2),
              worldBounds: nodeSnapshotBoundsWorld(strokeNode),
            ),
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Missing resolved stroke path'),
          ),
        ),
      );
    },
  );

  test('ScenePainter ignores marquee selection rectangle', () async {
    const background = Color(0xFFFFFFFF);
    final controller = SceneStoreController(
      initialSnapshot: SceneSnapshot(
        background: BackgroundSnapshot(color: background),
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(id: 'layer-auto-1'),
        ],
      ),
    );
    addTearDown(controller.dispose);
    final renderState = _mirrorRenderState(controller);

    final withoutMarquee = ScenePainter(
      controller: renderState,
      imageResolver: (_) => null,
      selectionColor: const Color(0xFFFF0000),
      selectionStrokeWidth: 2,
    );
    final withMarqueeState = _FakeRenderState(
      snapshot: controller.snapshot,
      selectionRect: const Rect.fromLTRB(20, 20, 70, 60),
    );
    final withMarquee = ScenePainter(
      controller: withMarqueeState,
      imageResolver: (_) => null,
      selectionColor: const Color(0xFFFF0000),
      selectionStrokeWidth: 2,
    );

    final imageWithout = await _paintToImage(withoutMarquee);
    final imageWith = await _paintToImage(withMarquee);
    final nonBackgroundWithout = await _countNonBackgroundPixels(
      imageWithout,
      background,
    );
    final nonBackgroundWith = await _countNonBackgroundPixels(
      imageWith,
      background,
    );
    expect(nonBackgroundWith, nonBackgroundWithout);
  });

  test('SceneStoreController rejects invalid numeric snapshot fields', () {
    expect(
      () => SceneStoreController(
        initialSnapshot: unsafeMaterializeSceneSnapshot(
          SceneSnapshotBacking(
            camera: const CameraSnapshotBacking(offset: Offset(double.nan, 0)),
          ),
        ),
      ),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.path == 'camera.offset.dx' &&
              e.message == 'Field camera.offset.dx must be finite.',
        ),
      ),
    );
  });

  test('ScenePainter paints selected line and stroke', () async {
    const background = Color(0xFFFFFFFF);
    final controller = SceneStoreController(
      initialSnapshot: SceneSnapshot(
        background: BackgroundSnapshot(color: background),
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'layer-auto-2',
            nodes: <NodeSnapshot>[
              LineNodeSnapshot(
                id: 'line-valid',
                start: Offset(0, 0),
                end: Offset(20, 0),
                thickness: 3,
                color: Color(0xFF000000),
                transform: Transform2D(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20),
              ),
              StrokeNodeSnapshot(
                id: 'stroke-valid',
                points: <Offset>[Offset(0, 0), Offset(10, 10)],
                thickness: 3,
                color: Color(0xFF000000),
                transform: Transform2D(a: 1, b: 0, c: 0, d: 1, tx: 60, ty: 20),
              ),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    final renderState = _mirrorRenderState(controller);
    controller.write<void>((writer) {
      writer.writeSelectionReplace(const <String>{
        'line-valid',
        'stroke-valid',
      });
    });

    final painter = ScenePainter(
      controller: renderState,
      imageResolver: (_) => null,
      selectionColor: const Color(0xFFFF0000),
      selectionStrokeWidth: 2,
      strokePathCache: null,
    );
    final rendered = await _paintToImage(painter, width: 100, height: 60);
    final nonBackground = await _countNonBackgroundPixels(rendered, background);
    expect(nonBackground, greaterThan(0));

    final cachedPainter = ScenePainter(
      controller: renderState,
      imageResolver: (_) => null,
      selectionColor: const Color(0xFFFF0000),
      selectionStrokeWidth: 2,
      strokePathCache: SceneStrokePathCache(maxEntries: 8),
    );
    final cachedRendered = await _paintToImage(
      cachedPainter,
      width: 100,
      height: 60,
    );
    final cachedNonBackground = await _countNonBackgroundPixels(
      cachedRendered,
      background,
    );
    expect(cachedNonBackground, greaterThan(0));
  });

  test('ScenePainter keeps selected line base pixels alpha-stable', () async {
    const background = Color(0x00000000);
    final line = LineNodeSnapshot(
      id: 'line-alpha-stable',
      start: const Offset(10, 30),
      end: const Offset(70, 30),
      thickness: 6,
      color: const Color(0xFF000000),
      opacity: 0.25,
    );
    final controller = SceneStoreController(
      initialSnapshot: SceneSnapshot(
        background: BackgroundSnapshot(color: background),
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'line-alpha-layer',
            nodes: <NodeSnapshot>[line],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    final renderState = _mirrorRenderState(controller);
    final painter = ScenePainter(
      controller: renderState,
      imageResolver: (_) => null,
      selectionColor: const Color(0xFFFF0000),
      selectionStrokeWidth: 4,
    );

    final unselected = await _paintToImage(painter, width: 90, height: 60);
    controller.write<void>((writer) {
      writer.writeSelectionReplace(const <NodeId>{'line-alpha-stable'});
    });
    final selected = await _paintToImage(painter, width: 90, height: 60);

    expect(
      await _pixelColor(selected, 40, 30),
      await _pixelColor(unselected, 40, 30),
    );
  });

  test(
    'ScenePainter keeps later content above selected line content',
    () async {
      const background = Color(0xFFFFFFFF);
      const coverColor = Color(0xFF2962FF);
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: background),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'line-order-layer',
              nodes: <NodeSnapshot>[
                LineNodeSnapshot(
                  id: 'line-under-cover',
                  start: const Offset(10, 30),
                  end: const Offset(70, 30),
                  thickness: 8,
                  color: const Color(0xFF000000),
                ),
                RectNodeSnapshot(
                  id: 'later-cover',
                  size: const Size(20, 20),
                  fillColor: coverColor,
                  strokeWidth: 0,
                  transform: Transform2D.translation(const Offset(40, 30)),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _mirrorRenderState(controller);
      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'line-under-cover'});
      });

      final image = await _paintToImage(
        ScenePainter(
          controller: renderState,
          imageResolver: (_) => null,
          selectionColor: const Color(0xFFFF0000),
          selectionStrokeWidth: 4,
        ),
        width: 90,
        height: 60,
      );

      expect(await _pixelColor(image, 40, 30), coverColor);
    },
  );

  test(
    'ScenePainter keeps selected dot base pixels alpha-stable with visible halo',
    () async {
      const background = Color(0x00000000);
      final dot = StrokeNodeSnapshot(
        id: 'dot-alpha-stable',
        points: const <Offset>[Offset(30, 30)],
        thickness: 8,
        color: const Color(0xFF000000),
        opacity: 0.25,
      );
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: background),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'dot-alpha-layer',
              nodes: <NodeSnapshot>[dot],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _mirrorRenderState(controller);
      final painter = ScenePainter(
        controller: renderState,
        imageResolver: (_) => null,
        selectionColor: const Color(0xFFFF0000),
        selectionStrokeWidth: 4,
      );

      final unselected = await _paintToImage(painter, width: 70, height: 70);
      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'dot-alpha-stable'});
      });
      final selected = await _paintToImage(painter, width: 70, height: 70);

      expect(
        await _pixelColor(selected, 30, 30),
        await _pixelColor(unselected, 30, 30),
      );
      final haloPixel = await _pixelColor(selected, 37, 30);
      expect(haloPixel.a, greaterThan(0.8));
      expect(haloPixel.r, greaterThan(0.8));
      expect(haloPixel.g, 0);
      expect(haloPixel.b, 0);
    },
  );

  test(
    'ScenePainter reuses selected stroke path without selection cache lookup',
    () async {
      final strokeCache = SceneStrokePathCache(maxEntries: 8);
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: const Color(0xFFFFFFFF)),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'stroke-selection-cache-layer',
              nodes: <NodeSnapshot>[
                StrokeNodeSnapshot(
                  id: 'stroke-selection-cache',
                  points: const <Offset>[Offset(10, 10), Offset(60, 30)],
                  thickness: 4,
                  color: const Color(0xFF000000),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _mirrorRenderState(controller);
      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'stroke-selection-cache'});
      });

      await _paintToImage(
        ScenePainter(
          controller: renderState,
          imageResolver: (_) => null,
          strokePathCache: strokeCache,
          selectionColor: const Color(0xFFFF0000),
          selectionStrokeWidth: 3,
        ),
        width: 80,
        height: 50,
      );

      expect(strokeCache.debugBuildCount, 1);
      expect(strokeCache.debugHitCount, 0);
    },
  );

  test(
    'ScenePainter keeps selected open path base pixels alpha-stable and ordered',
    () async {
      const background = Color(0xFFFFFFFF);
      const coverColor = Color(0xFF00A152);
      final path = PathNodeSnapshot(
        id: 'open-path-alpha-order',
        svgPathData: 'M10 30 L70 30',
        strokeColor: const Color(0xFF000000),
        strokeWidth: 6,
        opacity: 0.25,
      );
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: background),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'open-path-layer',
              nodes: <NodeSnapshot>[
                path,
                RectNodeSnapshot(
                  id: 'open-path-cover',
                  size: const Size(20, 20),
                  fillColor: coverColor,
                  strokeWidth: 0,
                  transform: Transform2D.translation(const Offset(40, 30)),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _mirrorRenderState(controller);
      final painter = ScenePainter(
        controller: renderState,
        imageResolver: (_) => null,
        selectionColor: const Color(0xFFFF0000),
        selectionStrokeWidth: 4,
      );

      final unselected = await _paintToImage(painter, width: 90, height: 60);
      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'open-path-alpha-order'});
      });
      final selected = await _paintToImage(painter, width: 90, height: 60);

      expect(
        await _pixelColor(selected, 20, 30),
        await _pixelColor(unselected, 20, 30),
      );
      expect(await _pixelColor(selected, 40, 30), coverColor);
    },
  );

  test(
    'ScenePainter keeps canvas save stack balanced across preview and selection scopes',
    () {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: Color(0xFFFFFFFF)),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-save-restore',
              nodes: <NodeSnapshot>[
                PathNodeSnapshot(
                  id: 'path-selected',
                  svgPathData: 'M0 0 H24 V16 H0 Z',
                  fillColor: Color(0xFF81C784),
                  strokeColor: Color(0xFF000000),
                  strokeWidth: 2,
                  transform: Transform2D.translation(const Offset(40, 40)),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _mirrorRenderState(controller);
      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'path-selected'});
      });

      final canvas = TestRecordingCanvas();
      final painter = ScenePainter(
        controller: renderState,
        imageResolver: (_) => null,
        selectionColor: const Color(0xFFFF0000),
        selectionStrokeWidth: 2,
      );

      painter.paint(canvas, const Size(120, 100));

      expect(canvas.getSaveCount(), 0);
      final saveCount = canvas.invocations
          .where((invocation) => invocation.invocation.memberName == #save)
          .length;
      final saveLayerCount = canvas.invocations
          .where((invocation) => invocation.invocation.memberName == #saveLayer)
          .length;
      final restoreCount = canvas.invocations
          .where((invocation) => invocation.invocation.memberName == #restore)
          .length;
      expect(restoreCount, saveCount + saveLayerCount);
    },
  );

  test(
    'ScenePainter bounds selection saveLayer work on the real paint path',
    () {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: Color(0xFFFFFFFF)),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-selection-probe',
              nodes: <NodeSnapshot>[
                PathNodeSnapshot(
                  id: 'selection-probe-path',
                  svgPathData: 'M0 0 H24 V16 H0 Z',
                  fillColor: Color(0xFF81C784),
                  strokeColor: Color(0xFF000000),
                  strokeWidth: 2,
                  transform: Transform2D.translation(const Offset(40, 40)),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _mirrorRenderState(controller);
      final painter = ScenePainter(
        controller: renderState,
        imageResolver: (_) => null,
        selectionColor: const Color(0xFFFF0000),
        selectionStrokeWidth: 2,
      );

      controller.write<void>((writer) {
        writer.writeSelectionClear();
      });
      final noSelectionCanvas = TestRecordingCanvas();
      painter.paint(noSelectionCanvas, const Size(120, 100));

      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'selection-probe-path'});
      });
      final withSelectionCanvas = TestRecordingCanvas();
      painter.paint(withSelectionCanvas, const Size(120, 100));

      final noSelectionSaveLayers = _recordedSaveLayerBounds(noSelectionCanvas);
      final withSelectionSaveLayers = _recordedSaveLayerBounds(
        withSelectionCanvas,
      );

      expect(noSelectionSaveLayers, isEmpty);
      expect(withSelectionSaveLayers, hasLength(1));
      expect(withSelectionSaveLayers, everyElement(isA<Rect>()));
      final boundedLayer = withSelectionSaveLayers.single as Rect;
      expect(boundedLayer.width, greaterThan(24));
      expect(boundedLayer.height, greaterThan(16));
      expect(boundedLayer.width, lessThan(40));
      expect(boundedLayer.height, lessThan(32));
    },
  );

  test(
    'ScenePainter prepared paint preserves bounded selection saveLayer behavior',
    () {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: Color(0xFFFFFFFF)),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-selection-prepared-probe',
              nodes: <NodeSnapshot>[
                PathNodeSnapshot(
                  id: 'selection-prepared-path',
                  svgPathData: 'M0 0 H24 V16 H0 Z',
                  fillColor: Color(0xFF81C784),
                  strokeColor: Color(0xFF000000),
                  strokeWidth: 2,
                  transform: Transform2D.translation(const Offset(40, 40)),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _mirrorRenderState(controller);
      final painter = ScenePainter(
        controller: renderState,
        imageResolver: (_) => null,
        selectionColor: const Color(0xFFFF0000),
        selectionStrokeWidth: 2,
      );

      controller.write<void>((writer) {
        writer.writeSelectionClear();
      });
      final preparedNoSelection = painter.prepareForPaint(const Size(120, 100));
      final noSelectionCanvas = TestRecordingCanvas();
      painter.paintPrepared(noSelectionCanvas, preparedNoSelection);

      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'selection-prepared-path'});
      });
      final directWithSelectionCanvas = TestRecordingCanvas();
      painter.paint(directWithSelectionCanvas, const Size(120, 100));

      final preparedWithSelection = painter.prepareForPaint(
        const Size(120, 100),
      );
      final preparedWithSelectionCanvas = TestRecordingCanvas();
      painter.paintPrepared(preparedWithSelectionCanvas, preparedWithSelection);

      final noSelectionSaveLayers = _recordedSaveLayerBounds(noSelectionCanvas);
      final directWithSelectionSaveLayers = _recordedSaveLayerBounds(
        directWithSelectionCanvas,
      );
      final preparedWithSelectionSaveLayers = _recordedSaveLayerBounds(
        preparedWithSelectionCanvas,
      );

      expect(noSelectionSaveLayers, isEmpty);
      expect(directWithSelectionSaveLayers, hasLength(1));
      expect(preparedWithSelectionSaveLayers, hasLength(1));
      expect(directWithSelectionSaveLayers, everyElement(isA<Rect>()));
      expect(preparedWithSelectionSaveLayers, everyElement(isA<Rect>()));
      final directBounds = directWithSelectionSaveLayers.single as Rect;
      expect(directBounds.width, greaterThan(24));
      expect(directBounds.height, greaterThan(16));
      expect(directBounds.width, lessThan(40));
      expect(directBounds.height, lessThan(32));
      _expectRectNear(
        preparedWithSelectionSaveLayers.single as Rect,
        directBounds,
        tolerance: 0.001,
      );
    },
  );

  test(
    'ScenePainter keeps grid visible with over-density via stride',
    () async {
      const background = Color(0xFFFFFFFF);
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(
            color: background,
            grid: GridSnapshot(
              isEnabled: true,
              cellSize: 1,
              color: Color(0xFF000000),
            ),
          ),
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _mirrorRenderState(controller);

      final painter = ScenePainter(
        controller: renderState,
        imageResolver: (_) => null,
      );
      final image = await _paintToImage(painter, width: 500, height: 500);
      final nonBackground = await _countNonBackgroundPixels(image, background);
      expect(nonBackground, greaterThan(0));
    },
  );

  test(
    'ScenePainter delegates empty-scene grid draw to SceneGridRenderer',
    () async {
      final scene = SceneSnapshot(
        camera: CameraSnapshot(offset: Offset(5, 0)),
        background: BackgroundSnapshot(
          color: Color(0xFFFFFFFF),
          grid: GridSnapshot(
            isEnabled: true,
            cellSize: 20,
            color: Color(0xFF000000),
          ),
        ),
      );
      final controller = SceneStoreController(initialSnapshot: scene);
      addTearDown(controller.dispose);
      final renderState = _mirrorRenderState(controller);
      final painter = ScenePainter(
        controller: renderState,
        imageResolver: (_) => null,
      );

      final painterImage = await _paintToImage(
        painter,
        width: 3980,
        height: 80,
      );

      const renderer = SceneGridRenderer();
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 3980, 80),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      renderer.draw(
        canvas,
        SceneGridRenderRequest(
          grid: scene.background.grid,
          size: const Size(3980, 80),
          cameraOffset: scene.camera.offset,
          gridStrokeWidth: 1,
        ),
      );
      final rendererImage = await recorder.endRecording().toImage(3980, 80);

      final painterGridPixels = await _countDarkPixelsOnRow(
        painterImage,
        10,
        const Color(0xFFFFFFFF),
      );
      final rendererGridPixels = await _countDarkPixelsOnRow(
        rendererImage,
        10,
        const Color(0xFFFFFFFF),
      );

      expect(
        (painterGridPixels - rendererGridPixels).abs(),
        lessThanOrEqualTo(1),
      );
    },
  );

  test('ScenePainter skips grid for invalid drawable state', () async {
    const background = Color(0xFFFFFFFF);
    final controller = _FakeRenderState(
      snapshot: unsafeMaterializeSceneSnapshot(
        SceneSnapshotBacking(
          background: BackgroundSnapshotBacking(
            color: background,
            grid: GridSnapshotBacking(
              isEnabled: true,
              cellSize: 0.5,
              color: Color(0xFF000000),
            ),
          ),
        ),
      ),
    );

    final painter = ScenePainter(
      controller: controller,
      imageResolver: (_) => null,
    );
    final image = await _paintToImage(painter, width: 120, height: 80);
    final nonBackground = await _countNonBackgroundPixels(image, background);
    expect(nonBackground, 0);
  });

  test(
    'ScenePainter avoids near-threshold grid density flap on camera jitter',
    () async {
      const background = Color(0xFFFFFFFF);
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(
            color: background,
            grid: GridSnapshot(
              isEnabled: true,
              cellSize: 20,
              color: Color(0xFF000000),
            ),
          ),
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _mirrorRenderState(controller);

      final painter = ScenePainter(
        controller: renderState,
        imageResolver: (_) => null,
      );

      final baseImage = await _paintToImage(painter, width: 3980, height: 80);
      final baseInk = await _countDarkPixelsOnRow(baseImage, 10, background);

      controller.writeReplaceScene(
        SceneSnapshot(
          camera: CameraSnapshot(offset: Offset(5, 0)),
          background: BackgroundSnapshot(
            color: background,
            grid: GridSnapshot(
              isEnabled: true,
              cellSize: 20,
              color: Color(0xFF000000),
            ),
          ),
        ),
      );
      final jitterImage = await _paintToImage(painter, width: 3980, height: 80);
      final jitterInk = await _countDarkPixelsOnRow(
        jitterImage,
        10,
        background,
      );

      expect((jitterInk - baseInk).abs(), lessThanOrEqualTo(1));
    },
  );

  test('ScenePainter culls path nodes using stroke-inflated bounds', () async {
    const background = Color(0xFFFFFFFF);
    final controller = SceneStoreController(
      initialSnapshot: SceneSnapshot(
        background: BackgroundSnapshot(
          color: background,
          grid: GridSnapshot(
            isEnabled: false,
            cellSize: 10,
            color: Color(0xFF000000),
          ),
        ),
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'layer-auto-3',
            nodes: <NodeSnapshot>[
              PathNodeSnapshot(
                id: 'edge-path',
                svgPathData: 'M0 0 H10 V10 H0 Z',
                strokeColor: Color(0xFF000000),
                strokeWidth: 8,
                transform: Transform2D(a: 1, b: 0, c: 0, d: 1, tx: -8, ty: 15),
              ),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    final renderState = _mirrorRenderState(controller);

    final painter = ScenePainter(
      controller: renderState,
      imageResolver: (_) => null,
    );
    final image = await _paintToImage(painter, width: 30, height: 30);

    expect(await _countNonBackgroundPixels(image, background), greaterThan(0));
    final bounds = await _inkBounds(image, background);
    expect(bounds.left, lessThanOrEqualTo(1.5));
  });

  test('ScenePainter culls rect nodes using stroke-inflated bounds', () async {
    const background = Color(0xFFFFFFFF);
    final controller = SceneStoreController(
      initialSnapshot: SceneSnapshot(
        background: BackgroundSnapshot(
          color: background,
          grid: GridSnapshot(
            isEnabled: false,
            cellSize: 10,
            color: Color(0xFF000000),
          ),
        ),
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'layer-auto-4',
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(
                id: 'edge-rect',
                size: Size(10, 10),
                strokeColor: Color(0xFF000000),
                strokeWidth: 8,
                transform: Transform2D(a: 1, b: 0, c: 0, d: 1, tx: -8, ty: 15),
              ),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    final renderState = _mirrorRenderState(controller);

    final painter = ScenePainter(
      controller: renderState,
      imageResolver: (_) => null,
    );
    final image = await _paintToImage(painter, width: 30, height: 30);

    expect(await _countNonBackgroundPixels(image, background), greaterThan(0));
    final bounds = await _inkBounds(image, background);
    expect(bounds.left, lessThanOrEqualTo(1.5));
  });

  test('ScenePainter draws backgroundLayer below content layers', () async {
    const background = Color(0xFFFFFFFF);
    const backgroundNodeColor = Color(0xFF1E88E5);
    const contentNodeColor = Color(0xFFE53935);
    final controller = SceneStoreController(
      initialSnapshot: SceneSnapshot(
        background: BackgroundSnapshot(color: background),
        backgroundLayer: BackgroundLayerSnapshot(
          nodes: <NodeSnapshot>[
            RectNodeSnapshot(
              id: 'bg-node',
              size: Size(24, 24),
              fillColor: backgroundNodeColor,
              strokeWidth: 0,
              transform: Transform2D(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20),
            ),
          ],
        ),
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'layer-auto-bg-order',
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(
                id: 'content-node',
                size: Size(12, 12),
                fillColor: contentNodeColor,
                strokeWidth: 0,
                transform: Transform2D(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20),
              ),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    final renderState = _mirrorRenderState(controller);

    final image = await _paintToImage(
      ScenePainter(controller: renderState, imageResolver: (_) => null),
      width: 40,
      height: 40,
    );

    expect(await _pixelColor(image, 20, 20), contentNodeColor);
    expect(await _pixelColor(image, 10, 10), backgroundNodeColor);
  });

  test(
    'ScenePainter culls backgroundLayer nodes using stroke-inflated bounds',
    () async {
      const background = Color(0xFFFFFFFF);
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(
            color: background,
            grid: GridSnapshot(
              isEnabled: false,
              cellSize: 10,
              color: Color(0xFF000000),
            ),
          ),
          backgroundLayer: BackgroundLayerSnapshot(
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(
                id: 'edge-bg-rect',
                size: Size(10, 10),
                strokeColor: Color(0xFF000000),
                strokeWidth: 8,
                transform: Transform2D(a: 1, b: 0, c: 0, d: 1, tx: -8, ty: 15),
              ),
            ],
          ),
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _mirrorRenderState(controller);

      final image = await _paintToImage(
        ScenePainter(controller: renderState, imageResolver: (_) => null),
        width: 30,
        height: 30,
      );

      expect(
        await _countNonBackgroundPixels(image, background),
        greaterThan(0),
      );
      final bounds = await _inkBounds(image, background);
      expect(bounds.left, lessThanOrEqualTo(1.5));
    },
  );

  test(
    'ScenePainter draws selection frame for backgroundLayer and keeps preview parity',
    () async {
      const background = Color(0xFFFFFFFF);
      final node = RectNodeSnapshot(
        id: 'bg-world-selection',
        size: Size(20, 12),
        transform: Transform2D(
          a: 0.7071067811865476,
          b: 0.7071067811865476,
          c: -0.7071067811865476,
          d: 0.7071067811865476,
          tx: 40,
          ty: 30,
        ),
      );
      const selectionStrokeWidth = 3.0;
      final expectedFrame = RenderGeometryCache()
          .get(node)
          .worldBounds
          .inflate(selectionStrokeWidth);
      final renderState = _FakeRenderState(
        snapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: background),
          backgroundLayer: BackgroundLayerSnapshot(nodes: <NodeSnapshot>[node]),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(id: 'layer-auto-bg-selection'),
          ],
        ),
        selectedNodeIds: const <NodeId>{'bg-world-selection'},
      );

      final baselineImage = await _paintToImage(
        ScenePainter(
          controller: renderState,
          imageResolver: (_) => null,
          selectionStrokeWidth: selectionStrokeWidth,
          selectionColor: const Color(0xFFFF0000),
        ),
        width: 80,
        height: 80,
      );
      final baselineBounds = await _inkBounds(baselineImage, background);
      expect(
        () => _expectRectNear(baselineBounds, expectedFrame),
        returnsNormally,
      );

      const previewDelta = Offset(7, -5);
      final previewState = _FakeRenderState(
        snapshot: renderState.snapshot,
        selectedNodeIds: renderState.selectedNodeIds,
        previewDeltaResolver: (_) => previewDelta,
      );
      final previewImage = await _paintToImage(
        ScenePainter(
          controller: previewState,
          imageResolver: (_) => null,
          selectionStrokeWidth: selectionStrokeWidth,
          selectionColor: const Color(0xFFFF0000),
        ),
        width: 80,
        height: 80,
      );
      final previewBounds = await _inkBounds(previewImage, background);
      expect(
        () => _expectRectNear(previewBounds, expectedFrame.shift(previewDelta)),
        returnsNormally,
      );
    },
  );

  test(
    'ScenePainter draws rect selection frame from worldBounds and keeps preview parity',
    () async {
      const background = Color(0xFFFFFFFF);
      final node = RectNodeSnapshot(
        id: 'rect-world-selection',
        size: Size(20, 12),
        transform: Transform2D(
          a: 0.7071067811865476,
          b: 0.7071067811865476,
          c: -0.7071067811865476,
          d: 0.7071067811865476,
          tx: 40,
          ty: 30,
        ),
      );
      const selectionStrokeWidth = 3.0;
      final expectedFrame = RenderGeometryCache()
          .get(node)
          .worldBounds
          .inflate(selectionStrokeWidth);

      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: background),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-5',
              nodes: <NodeSnapshot>[node],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _mirrorRenderState(controller);
      controller.write((writer) {
        writer.writeSelectionReplace(const <NodeId>{'rect-world-selection'});
      });

      final baselineImage = await _paintToImage(
        ScenePainter(
          controller: renderState,
          imageResolver: (_) => null,
          selectionStrokeWidth: selectionStrokeWidth,
          selectionColor: const Color(0xFFFF0000),
        ),
        width: 80,
        height: 80,
      );
      final baselineBounds = await _inkBounds(baselineImage, background);
      expect(
        () => _expectRectNear(baselineBounds, expectedFrame),
        returnsNormally,
      );

      const previewDelta = Offset(7, -5);
      final previewState = _FakeRenderState(
        snapshot: controller.snapshot,
        selectedNodeIds: controller.selectedNodeIds,
        previewDeltaResolver: (_) => previewDelta,
      );
      final previewImage = await _paintToImage(
        ScenePainter(
          controller: previewState,
          imageResolver: (_) => null,
          selectionStrokeWidth: selectionStrokeWidth,
          selectionColor: const Color(0xFFFF0000),
        ),
        width: 80,
        height: 80,
      );
      final previewBounds = await _inkBounds(previewImage, background);
      expect(
        () => _expectRectNear(previewBounds, expectedFrame.shift(previewDelta)),
        returnsNormally,
      );
    },
  );

  test(
    'ScenePainter keeps rect world-bounds halo pixel-parity with legacy unbounded compositing',
    () async {
      const background = Color(0xFFFFFFFF);
      const nodeFill = Color(0xFF000000);
      const selectionColor = Color(0xFFFF0000);
      const selectionStrokeWidth = 6.0;
      final node = RectNodeSnapshot(
        id: 'rect-world-selection-legacy-parity',
        size: const Size(20, 12),
        fillColor: nodeFill,
        strokeWidth: 0,
        transform: Transform2D.translation(const Offset(24, 28)),
      );
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: background),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-rect-legacy-parity',
              nodes: <NodeSnapshot>[node],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _mirrorRenderState(controller);
      controller.write((writer) {
        writer.writeSelectionReplace(const <NodeId>{
          'rect-world-selection-legacy-parity',
        });
      });

      final actual = await _paintToImage(
        ScenePainter(
          controller: renderState,
          imageResolver: (_) => null,
          selectionStrokeWidth: selectionStrokeWidth,
          selectionColor: selectionColor,
        ),
        width: 96,
        height: 96,
      );
      final expected = await _paintLegacyRectHaloImage(
        rect: RenderGeometryCache().get(node).worldBounds,
        background: background,
        fillColor: nodeFill,
        selectionColor: selectionColor,
        selectionStrokeWidth: selectionStrokeWidth,
        width: 96,
        height: 96,
      );
      await _expectSameImagePixels(actual, expected);
      expect(
        await _countNonBackgroundPixels(actual, background),
        greaterThan(0),
      );
    },
  );

  test(
    'ScenePainter uses node textDirection for TextAlign.start and end',
    () async {
      const background = Color(0xFFFFFFFF);

      SceneSnapshot snapshotFor(TextAlign align, TextDirection textDirection) {
        return SceneSnapshot(
          background: BackgroundSnapshot(color: background),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-6',
              nodes: <NodeSnapshot>[
                TextNodeSnapshot(
                  id: 'text-$align',
                  text: 'StartEnd',
                  fontSize: 20,
                  color: const Color(0xFF000000),
                  align: align,
                  textDirection: textDirection,
                  maxWidth: 60,
                  transform: Transform2D.translation(const Offset(80, 40)),
                ),
              ],
            ),
          ],
        );
      }

      final ltrState = _FakeRenderState(
        snapshot: snapshotFor(TextAlign.start, TextDirection.ltr),
      );
      final rtlState = _FakeRenderState(
        snapshot: snapshotFor(TextAlign.start, TextDirection.rtl),
      );

      final ltrImage = await _paintToImage(
        ScenePainter(controller: ltrState, imageResolver: (_) => null),
        width: 160,
        height: 80,
      );
      final rtlImage = await _paintToImage(
        ScenePainter(controller: rtlState, imageResolver: (_) => null),
        width: 160,
        height: 80,
      );
      final ltrCenterX = await _inkCentroidX(ltrImage, background);
      final rtlCenterX = await _inkCentroidX(rtlImage, background);
      expect(rtlCenterX, greaterThan(ltrCenterX));

      final ltrEndState = _FakeRenderState(
        snapshot: snapshotFor(TextAlign.end, TextDirection.ltr),
      );
      final rtlEndState = _FakeRenderState(
        snapshot: snapshotFor(TextAlign.end, TextDirection.rtl),
      );

      final ltrEndImage = await _paintToImage(
        ScenePainter(controller: ltrEndState, imageResolver: (_) => null),
        width: 160,
        height: 80,
      );
      final rtlEndImage = await _paintToImage(
        ScenePainter(controller: rtlEndState, imageResolver: (_) => null),
        width: 160,
        height: 80,
      );
      final ltrEndCenterX = await _inkCentroidX(ltrEndImage, background);
      final rtlEndCenterX = await _inkCentroidX(rtlEndImage, background);
      expect(rtlEndCenterX, lessThan(ltrEndCenterX));
    },
  );

  test(
    'ScenePainter treats lineHeight as absolute logical units (legacy parity)',
    () async {
      const background = Color(0xFFFFFFFF);

      SceneSnapshot snapshotFor(double? lineHeight) {
        return SceneSnapshot(
          background: BackgroundSnapshot(color: background),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-7',
              nodes: <NodeSnapshot>[
                TextNodeSnapshot(
                  id: 'text-line-height',
                  text: 'One\nTwo',
                  fontSize: 12,
                  color: const Color(0xFF000000),
                  textDirection: TextDirection.ltr,
                  lineHeight: lineHeight,
                  transform: Transform2D.translation(const Offset(90, 90)),
                ),
              ],
            ),
          ],
        );
      }

      final defaultController = SceneStoreController(
        initialSnapshot: snapshotFor(null),
      );
      final customController = SceneStoreController(
        initialSnapshot: snapshotFor(24),
      );
      addTearDown(defaultController.dispose);
      addTearDown(customController.dispose);
      final defaultRenderState = _mirrorRenderState(defaultController);
      final customRenderState = _mirrorRenderState(customController);

      final defaultImage = await _paintToImage(
        ScenePainter(
          controller: defaultRenderState,
          imageResolver: (_) => null,
        ),
        width: 180,
        height: 180,
      );
      final customImage = await _paintToImage(
        ScenePainter(controller: customRenderState, imageResolver: (_) => null),
        width: 180,
        height: 180,
      );
      final defaultBounds = await _inkBounds(defaultImage, background);
      final customBounds = await _inkBounds(customImage, background);

      expect(customBounds.height, greaterThan(defaultBounds.height + 8));
      expect(customBounds.height, lessThan(80));
    },
  );

  test('ScenePainter uses caches when provided', () async {
    // INV:INV-ENG-PERFORMANCE-PROOF-CONTOUR
    const background = Color(0xFFFFFFFF);
    final strokeCache = SceneStrokePathCache(maxEntries: 8);
    final textCache = SceneTextLayoutCache(maxEntries: 8);
    final pathCache = ScenePathMetricsCache(maxEntries: 8);
    final controller = SceneStoreController(
      initialSnapshot: SceneSnapshot(
        background: BackgroundSnapshot(color: background),
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'layer-auto-8',
            nodes: <NodeSnapshot>[
              StrokeNodeSnapshot(
                id: 'stroke',
                points: const <Offset>[Offset(10, 10), Offset(60, 10)],
                thickness: 6,
                color: const Color(0xFF000000),
              ),
              TextNodeSnapshot(
                id: 'text',
                text: 'cache',
                fontSize: 14,
                color: const Color(0xFF000000),
                textDirection: TextDirection.ltr,
                transform: Transform2D.translation(const Offset(50, 40)),
              ),
              PathNodeSnapshot(
                id: 'path',
                svgPathData: 'M0 0 H30 V20 H0 Z',
                strokeColor: const Color(0xFF000000),
                strokeWidth: 2,
                transform: Transform2D.translation(const Offset(50, 70)),
              ),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    final renderState = _mirrorRenderState(controller);

    final painter = ScenePainter(
      controller: renderState,
      imageResolver: (_) => null,
      strokePathCache: strokeCache,
      textLayoutCache: textCache,
      pathMetricsCache: pathCache,
    );

    await _paintToImage(painter, width: 120, height: 100);
    await _paintToImage(painter, width: 120, height: 100);

    expect(strokeCache.debugBuildCount, 1);
    expect(strokeCache.debugHitCount, greaterThanOrEqualTo(1));
    expect(textCache.debugBuildCount, 1);
    expect(textCache.debugHitCount, greaterThanOrEqualTo(1));
    expect(pathCache.debugBuildCount, 0);
    expect(pathCache.debugHitCount, 0);

    controller.write<void>((writer) {
      writer.writeSelectionReplace(const <NodeId>{'path'});
    });
    await _paintToImage(painter, width: 120, height: 100);
    await _paintToImage(painter, width: 120, height: 100);

    expect(pathCache.debugBuildCount, 1);
    expect(pathCache.debugHitCount, greaterThanOrEqualTo(1));
  });

  test(
    'ScenePainter stroke cache rebuilds when node id is reused across commits',
    () async {
      final strokeCache = SceneStrokePathCache(maxEntries: 8);
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: Color(0xFFFFFFFF)),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-9',
              nodes: <NodeSnapshot>[
                StrokeNodeSnapshot(
                  id: 'A',
                  points: const <Offset>[Offset(0, 0), Offset(20, 0)],
                  thickness: 4,
                  color: const Color(0xFF000000),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _mirrorRenderState(controller);

      final painter = ScenePainter(
        controller: renderState,
        imageResolver: (_) => null,
        strokePathCache: strokeCache,
      );

      await _paintToImage(painter, width: 80, height: 80);
      expect(strokeCache.debugBuildCount, 1);

      controller.write<void>((writer) {
        writer.writeNodeErase('A');
      });
      controller.write<void>((writer) {
        writer.writeNodeInsert(
          StrokeNodeSpec(
            id: 'A',
            points: const <Offset>[Offset(0, 0), Offset(0, 20)],
            thickness: 4,
            color: const Color(0xFF000000),
          ),
        );
      });

      await _paintToImage(painter, width: 80, height: 80);
      expect(strokeCache.debugBuildCount, 2);
    },
  );

  test(
    'ScenePainter stroke cache rebuilds when erase+insert same id happens in one write',
    () async {
      final strokeCache = SceneStrokePathCache(maxEntries: 8);
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: Color(0xFFFFFFFF)),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-10',
              nodes: <NodeSnapshot>[
                StrokeNodeSnapshot(
                  id: 'A',
                  points: const <Offset>[Offset(0, 0), Offset(20, 0)],
                  thickness: 4,
                  color: const Color(0xFF000000),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _mirrorRenderState(controller);

      final painter = ScenePainter(
        controller: renderState,
        imageResolver: (_) => null,
        strokePathCache: strokeCache,
      );

      await _paintToImage(painter, width: 80, height: 80);
      expect(strokeCache.debugBuildCount, 1);

      controller.write<void>((writer) {
        expect(writer.writeNodeErase('A'), isTrue);
        writer.writeNodeInsert(
          StrokeNodeSpec(
            id: 'A',
            points: const <Offset>[Offset(0, 0), Offset(0, 20)],
            thickness: 4,
            color: const Color(0xFF000000),
          ),
        );
      });

      await _paintToImage(painter, width: 80, height: 80);
      expect(strokeCache.debugBuildCount, 2);
    },
  );

  test(
    'ScenePainter reuses path geometry across cull, draw and selection in one frame',
    () async {
      final geometryCache = RenderGeometryCache();
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: Color(0xFFFFFFFF)),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-11',
              nodes: <NodeSnapshot>[
                PathNodeSnapshot(
                  id: 'path-geometry-reuse',
                  svgPathData: 'M0 0 H30 V20 H0 Z',
                  fillColor: Color(0xFF81C784),
                  strokeColor: Color(0xFF000000),
                  strokeWidth: 4,
                  transform: Transform2D(
                    a: 1,
                    b: 0,
                    c: 0,
                    d: 1,
                    tx: 50,
                    ty: 50,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _mirrorRenderState(controller);
      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'path-geometry-reuse'});
      });

      final painter = ScenePainter(
        controller: renderState,
        imageResolver: (_) => null,
        geometryCache: geometryCache,
      );

      await _paintToImage(painter, width: 120, height: 100);

      expect(geometryCache.debugBuildCount, 1);
      expect(geometryCache.debugHitCount, 0);
      expect(geometryCache.debugSize, 1);
    },
  );

  test(
    'ScenePainter skips path metrics cache when local path is unavailable',
    () async {
      final pathCache = ScenePathMetricsCache(maxEntries: 8);
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: Color(0xFFFFFFFF)),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-12',
              nodes: <NodeSnapshot>[
                PathNodeSnapshot(
                  id: 'path-degenerate',
                  svgPathData: 'M0 0',
                  strokeColor: const Color(0xFF000000),
                  strokeWidth: 2,
                  transform: Transform2D.translation(const Offset(50, 50)),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _mirrorRenderState(controller);

      final painter = ScenePainter(
        controller: renderState,
        imageResolver: (_) => null,
        pathMetricsCache: pathCache,
      );

      await _paintToImage(painter, width: 120, height: 100);
      await _paintToImage(painter, width: 120, height: 100);

      expect(pathCache.debugBuildCount, 0);
      expect(pathCache.debugHitCount, 0);
      expect(pathCache.debugSize, 0);
    },
  );

  test(
    'ScenePainter can use static layer cache across camera updates',
    () async {
      final staticCache = SceneStaticLayerCache();
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(
            color: Color(0xFFFFFFFF),
            grid: GridSnapshot(
              isEnabled: true,
              cellSize: 20,
              color: Color(0xFF000000),
            ),
          ),
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _mirrorRenderState(controller);

      final painter = ScenePainter(
        controller: renderState,
        imageResolver: (_) => null,
        staticLayerCache: staticCache,
      );

      await _paintToImage(painter, width: 120, height: 80);
      expect(staticCache.debugBuildCount, 1);

      controller.writeReplaceScene(
        SceneSnapshot(
          camera: CameraSnapshot(offset: Offset(7, 5)),
          background: BackgroundSnapshot(
            color: Color(0xFFFFFFFF),
            grid: GridSnapshot(
              isEnabled: true,
              cellSize: 20,
              color: Color(0xFF000000),
            ),
          ),
        ),
      );
      await _paintToImage(painter, width: 120, height: 80);
      expect(staticCache.debugBuildCount, 1);
    },
  );

  test(
    'ScenePainter covers single-point stroke, image placeholder and text align branches',
    () async {
      const background = Color(0xFFFFFFFF);
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: background),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-13',
              nodes: <NodeSnapshot>[
                StrokeNodeSnapshot(
                  id: 'dot',
                  points: const <Offset>[Offset(20, 20)],
                  thickness: 8,
                  color: const Color(0xFF000000),
                ),
                ImageNodeSnapshot(
                  id: 'image-missing',
                  imageId: 'missing',
                  size: Size(20, 16),
                  transform: Transform2D(
                    a: 1,
                    b: 0,
                    c: 0,
                    d: 1,
                    tx: 55,
                    ty: 25,
                  ),
                ),
                TextNodeSnapshot(
                  id: 'text-right',
                  text: 'R',
                  fontSize: 14,
                  lineHeight: 1.4,
                  align: TextAlign.right,
                  color: const Color(0xFF000000),
                  textDirection: TextDirection.ltr,
                  transform: Transform2D.translation(const Offset(20, 55)),
                ),
                TextNodeSnapshot(
                  id: 'text-justify',
                  text: 'J',
                  fontSize: 14,
                  align: TextAlign.justify,
                  color: const Color(0xFF000000),
                  textDirection: TextDirection.ltr,
                  transform: Transform2D.translation(const Offset(55, 55)),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _mirrorRenderState(controller);

      final image = await _paintToImage(
        ScenePainter(controller: renderState, imageResolver: (_) => null),
        width: 100,
        height: 80,
      );
      final nonBackground = await _countNonBackgroundPixels(image, background);
      expect(nonBackground, greaterThan(0));
    },
  );

  test(
    'ScenePainter covers selection halo branches for image/text/stroke/path',
    () async {
      const background = Color(0xFFFFFFFF);
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: background),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-14',
              nodes: <NodeSnapshot>[
                ImageNodeSnapshot(
                  id: 'img-sel',
                  imageId: 'missing',
                  size: Size(20, 16),
                  transform: Transform2D(
                    a: 1,
                    b: 0,
                    c: 0,
                    d: 1,
                    tx: 20,
                    ty: 20,
                  ),
                ),
                TextNodeSnapshot(
                  id: 'txt-sel',
                  text: 'T',
                  color: const Color(0xFF000000),
                  textDirection: TextDirection.ltr,
                  transform: Transform2D.translation(const Offset(60, 20)),
                ),
                StrokeNodeSnapshot(
                  id: 'dot-sel',
                  points: <Offset>[Offset(40, 45)],
                  thickness: 6,
                  color: Color(0xFF000000),
                ),
                StrokeNodeSnapshot(
                  id: 'stroke-sel',
                  points: <Offset>[Offset(65, 40), Offset(78, 48)],
                  thickness: 4,
                  color: Color(0xFF000000),
                ),
                PathNodeSnapshot(
                  id: 'path-open-sel',
                  svgPathData: 'M0 0 L30 0',
                  strokeColor: Color(0xFF000000),
                  strokeWidth: 3,
                  transform: Transform2D(
                    a: 1,
                    b: 0,
                    c: 0,
                    d: 1,
                    tx: 20,
                    ty: 80,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _mirrorRenderState(controller);

      controller.write((writer) {
        writer.writeSelectionReplace(const <NodeId>{
          'img-sel',
          'txt-sel',
          'dot-sel',
          'stroke-sel',
          'path-open-sel',
        });
      });

      final withoutCache = await _paintToImage(
        ScenePainter(controller: renderState, imageResolver: (_) => null),
        width: 120,
        height: 120,
      );
      expect(
        await _countNonBackgroundPixels(withoutCache, background),
        greaterThan(0),
      );

      final withPathCache = await _paintToImage(
        ScenePainter(
          controller: renderState,
          imageResolver: (_) => null,
          pathMetricsCache: ScenePathMetricsCache(),
        ),
        width: 120,
        height: 120,
      );
      expect(
        await _countNonBackgroundPixels(withPathCache, background),
        greaterThan(0),
      );
    },
  );

  test(
    'ScenePainter keeps closed-path halo parity with and without path metrics cache',
    () async {
      const background = Color(0xFFFFFFFF);
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: background),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-closed-path-parity',
              nodes: <NodeSnapshot>[
                PathNodeSnapshot(
                  id: 'closed-path-parity',
                  svgPathData: 'M0 0 C18 -6 26 24 4 28 Z',
                  fillColor: Color(0xFF4DB6AC),
                  strokeColor: Color(0xFF004D40),
                  strokeWidth: 3,
                  transform: Transform2D.translation(const Offset(38, 34)),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _mirrorRenderState(controller);
      controller.write((writer) {
        writer.writeSelectionReplace(const <NodeId>{'closed-path-parity'});
      });

      final withoutPathCache = await _paintToImage(
        ScenePainter(
          controller: renderState,
          imageResolver: (_) => null,
          selectionColor: const Color(0xFFFF0000),
          selectionStrokeWidth: 3,
          pathMetricsCache: null,
        ),
        width: 120,
        height: 120,
      );
      final withPathCache = await _paintToImage(
        ScenePainter(
          controller: renderState,
          imageResolver: (_) => null,
          selectionColor: const Color(0xFFFF0000),
          selectionStrokeWidth: 3,
          pathMetricsCache: ScenePathMetricsCache(),
        ),
        width: 120,
        height: 120,
      );

      await _expectSameImagePixels(withoutPathCache, withPathCache);
      expect(
        await _countNonBackgroundPixels(withPathCache, background),
        greaterThan(0),
      );
    },
  );

  test(
    'ScenePainter keeps only selection-halo edge nodes paint-visible',
    () async {
      const background = Color(0xFFFFFFFF);
      const selectionColor = Color(0xFFFF0000);
      const selectionStrokeWidth = 3.0;

      Future<int> paintVisibleInk({
        required String id,
        required Offset center,
        required bool selected,
      }) async {
        final renderState = _FakeRenderState(
          snapshot: SceneSnapshot(
            background: BackgroundSnapshot(color: background),
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(
                id: 'layer-visibility-budget',
                nodes: <NodeSnapshot>[
                  RectNodeSnapshot(
                    id: id,
                    size: const Size(10, 10),
                    fillColor: const Color(0xFF000000),
                    hitPadding: 0,
                    strokeWidth: 0,
                    transform: Transform2D.translation(center),
                  ),
                ],
              ),
            ],
          ),
          selectedNodeIds: selected ? <NodeId>{id} : const <NodeId>{},
        );

        final image = await _paintToImage(
          ScenePainter(
            controller: renderState,
            imageResolver: (_) => null,
            selectionColor: selectionColor,
            selectionStrokeWidth: selectionStrokeWidth,
          ),
          width: 30,
          height: 30,
        );
        return _countNonBackgroundPixels(image, background);
      }

      final selectedHaloVisible = await paintVisibleInk(
        id: 'edge-selected-visible',
        center: const Offset(-7, 15),
        selected: true,
      );
      final unselectedStillCulled = await paintVisibleInk(
        id: 'edge-unselected-culled',
        center: const Offset(-7, 15),
        selected: false,
      );
      final selectedButTooFar = await paintVisibleInk(
        id: 'edge-selected-too-far',
        center: const Offset(-10, 15),
        selected: true,
      );

      expect(selectedHaloVisible, greaterThan(0));
      expect(unselectedStillCulled, 0);
      expect(selectedButTooFar, 0);
    },
  );

  test(
    'ScenePainter keeps unselected edge nodes culled when another node is selected',
    () {
      const background = Color(0xFFFFFFFF);
      const selectionColor = Color(0xFFFF0000);
      const unselectedFill = Color(0xFF2962FF);
      const selectionStrokeWidth = 3.0;

      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: background),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-mixed-visibility-budget',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(
                  id: 'selected-budget-anchor',
                  size: const Size(10, 10),
                  fillColor: const Color(0xFF2E7D32),
                  hitPadding: 0,
                  strokeWidth: 0,
                  transform: Transform2D.translation(const Offset(15, 15)),
                ),
                RectNodeSnapshot(
                  id: 'unselected-edge-node',
                  size: const Size(10, 10),
                  fillColor: unselectedFill,
                  hitPadding: 0,
                  strokeWidth: 0,
                  transform: Transform2D.translation(const Offset(-6, 15)),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _mirrorRenderState(controller);
      controller.write((writer) {
        writer.writeSelectionReplace(const <NodeId>{'selected-budget-anchor'});
      });

      final canvas = TestRecordingCanvas();
      final painter = ScenePainter(
        controller: renderState,
        imageResolver: (_) => null,
        selectionColor: selectionColor,
        selectionStrokeWidth: selectionStrokeWidth,
      );

      painter.paint(canvas, const Size(30, 30));

      final drawRectPaints = canvas.invocations
          .where((entry) => entry.invocation.memberName == #drawRect)
          .map((entry) => entry.invocation.positionalArguments[1] as Paint)
          .toList(growable: false);

      expect(
        drawRectPaints.where((paint) => paint.color == unselectedFill),
        isEmpty,
      );
    },
  );

  test('ScenePainter shouldRepaint reflects individual fields', () {
    final c1 = SceneStoreController();
    final c2 = SceneStoreController();
    addTearDown(c1.dispose);
    addTearDown(c2.dispose);
    final r1 = _mirrorRenderState(c1);
    final r2 = _mirrorRenderState(c2);

    Image? resolverA(String _) => null;
    Image? resolverB(String _) => null;

    final base = ScenePainter(controller: r1, imageResolver: resolverA);
    final same = ScenePainter(controller: r1, imageResolver: resolverA);
    expect(base.shouldRepaint(same), isFalse);

    expect(
      ScenePainter(
        controller: r2,
        imageResolver: resolverA,
      ).shouldRepaint(base),
      isTrue,
    );
    expect(
      ScenePainter(
        controller: r1,
        imageResolver: resolverB,
      ).shouldRepaint(base),
      isTrue,
    );

    final staticCache = SceneStaticLayerCache();
    expect(
      ScenePainter(
        controller: r1,
        imageResolver: resolverA,
        staticLayerCache: staticCache,
      ).shouldRepaint(base),
      isTrue,
    );

    final textCache = SceneTextLayoutCache();
    expect(
      ScenePainter(
        controller: r1,
        imageResolver: resolverA,
        textLayoutCache: textCache,
      ).shouldRepaint(base),
      isTrue,
    );

    final strokeCache = SceneStrokePathCache();
    expect(
      ScenePainter(
        controller: r1,
        imageResolver: resolverA,
        strokePathCache: strokeCache,
      ).shouldRepaint(base),
      isTrue,
    );

    final pathCache = ScenePathMetricsCache();
    expect(
      ScenePainter(
        controller: r1,
        imageResolver: resolverA,
        pathMetricsCache: pathCache,
      ).shouldRepaint(base),
      isTrue,
    );

    expect(
      ScenePainter(
        controller: r1,
        imageResolver: resolverA,
        selectionColor: const Color(0xFFFF0000),
      ).shouldRepaint(base),
      isTrue,
    );
    expect(
      ScenePainter(
        controller: r1,
        imageResolver: resolverA,
        selectionStrokeWidth: 3,
      ).shouldRepaint(base),
      isTrue,
    );
    expect(
      ScenePainter(
        controller: r1,
        imageResolver: resolverA,
        gridStrokeWidth: 2,
      ).shouldRepaint(base),
      isTrue,
    );
  });

  test(
    'ScenePainter applies preview delta resolver for nodes and selection',
    () async {
      const background = Color(0xFFFFFFFF);
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: background),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-15',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(
                  id: 'previewed',
                  size: const Size(20, 20),
                  fillColor: const Color(0xFF000000),
                  transform: Transform2D.translation(const Offset(140, 20)),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final renderState = _controllerOwnedRenderState(
        controller,
        selectedNodeIds: const <NodeId>{'previewed'},
        previewDeltaResolver: (nodeId) {
          if (nodeId == 'previewed') return const Offset(-120, 10);
          return Offset.zero;
        },
      );

      final image = await _paintToImage(
        ScenePainter(controller: renderState, imageResolver: (_) => null),
        width: 80,
        height: 80,
      );

      expect(
        await _countNonBackgroundPixels(image, background),
        greaterThan(0),
      );
      expect(await _pixelColor(image, 20, 30), const Color(0xFF000000));
    },
  );

  test(
    'ScenePainter keeps one selected preview snapshot when imageResolver clears live preview mid-frame',
    () async {
      const background = Color(0xFFFFFFFF);
      final controller = interactive.SceneController(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(color: background),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-reentrant-preview',
              nodes: <NodeSnapshot>[
                ImageNodeSnapshot(
                  id: 'preview-image',
                  imageId: 'img',
                  size: const Size(12, 12),
                  transform: Transform2D.translation(const Offset(20, 20)),
                ),
                RectNodeSnapshot(
                  id: 'preview-rect',
                  size: const Size(12, 12),
                  fillColor: const Color(0xFFE53935),
                  strokeWidth: 0,
                  transform: Transform2D.translation(const Offset(60, 20)),
                ),
              ],
            ),
          ],
        ),
        dragStartSlop: 0.001,
      );
      addTearDown(controller.dispose);

      controller.selection.setSelection(const <String>{
        'preview-image',
        'preview-rect',
      });
      await pumpEventQueue();

      controller.interaction.handlePointer(
        const iwb.CanvasPointerInput(
          pointerId: 1,
          position: Offset(20, 20),
          timestampMs: 1,
          phase: iwb.CanvasPointerPhase.down,
          kind: PointerDeviceKind.touch,
        ),
      );
      controller.interaction.handlePointer(
        const iwb.CanvasPointerInput(
          pointerId: 1,
          position: Offset(50, 20),
          timestampMs: 2,
          phase: iwb.CanvasPointerPhase.move,
          kind: PointerDeviceKind.touch,
        ),
      );
      await pumpEventQueue();

      expect(
        controller.previewDeltaResolver('preview-rect'),
        const Offset(30, 0),
      );

      final renderState = interactive
          .sceneControllerViewRuntimeOf(controller)
          .mainSceneRenderRead;
      final image = await _solidImage(const Color(0xFF000000));
      var invalidatedPreview = false;

      final painted = await _paintToImage(
        ScenePainter(
          controller: renderState,
          imageResolver: (id) {
            if (id != 'img') {
              return null;
            }
            if (!invalidatedPreview) {
              invalidatedPreview = true;
              controller.interaction.setMode(iwb.CanvasMode.draw);
            }
            return image;
          },
        ),
        width: 120,
        height: 60,
      );

      expect(invalidatedPreview, isTrue);
      expect(await _pixelColor(painted, 90, 20), const Color(0xFFE53935));
      expect(await _pixelColor(painted, 60, 20), background);
      expect(controller.previewDeltaResolver('preview-rect'), Offset.zero);
    },
  );
}
