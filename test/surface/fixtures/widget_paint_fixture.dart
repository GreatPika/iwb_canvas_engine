import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/api/canvas_runtime_frame_bridge.dart';
import 'package:iwb_canvas_engine/src/resources/resource_resolver_adapter.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import 'package:iwb_canvas_engine/src/surface/main_painter.dart';
import 'package:iwb_canvas_engine/src/surface/overlay_painter.dart';

void main() {
  testWidgets('CanvasSurface paints empty and resource-free documents', (
    tester,
  ) async {
    await _expectEmptyAndResourceFreePaint(tester);
    expect(_paintHosts(), findsOneWidget);
  });

  testWidgets('CanvasSurface resolves image records through active session', (
    tester,
  ) async {
    await _expectImageResourcePaintAndDirtyRepaint(tester);
    expect(_paintHosts(), findsOneWidget);
  });

  testWidgets('CanvasSurface splits selected move and overlay previews', (
    tester,
  ) async {
    await _expectMainAndOverlayPreviewRouting(tester);
    expect(_paintHosts(), findsOneWidget);
  });
}

Future<void> _expectEmptyAndResourceFreePaint(WidgetTester tester) async {
  final emptyRuntime = CanvasRuntime(initialDocument: CanvasDocument());
  final emptyResolver = _RecordingResolver((_) => null);
  addTearDown(emptyRuntime.dispose);
  await tester.pumpWidget(_surfaceHost(emptyRuntime, emptyResolver));
  _expectPaintHost();
  expect(emptyResolver.calls, 0);

  final resourceFreeRuntime = CanvasRuntime(initialDocument: _rectDocument());
  final resourceFreeResolver = _RecordingResolver((_) => null);
  addTearDown(resourceFreeRuntime.dispose);
  await tester.pumpWidget(
    _surfaceHost(resourceFreeRuntime, resourceFreeResolver),
  );
  _expectPaintHost();
  expect(resourceFreeResolver.calls, 0);

  final descriptorOnlyRuntime = CanvasRuntime(
    initialDocument: _resourceDescriptorOnlyDocument(),
  );
  final descriptorOnlyResolver = _RecordingResolver((_) => null);
  addTearDown(descriptorOnlyRuntime.dispose);
  await tester.pumpWidget(
    _surfaceHost(descriptorOnlyRuntime, descriptorOnlyResolver),
  );
  _expectPaintHost();
  expect(descriptorOnlyResolver.calls, 0);
}

Future<void> _expectImageResourcePaintAndDirtyRepaint(
  WidgetTester tester,
) async {
  final image = await _createImage();
  final runtime = CanvasRuntime(initialDocument: _imageDocument());
  final resolver = _RecordingResolver((_) => image);
  addTearDown(runtime.dispose);

  await tester.pumpWidget(_surfaceHost(runtime, resolver));

  _expectPaintHost();
  expect(resolver.calls, 1);
  expect(
    _mainPainter(tester).output.assetBindings.images[CanvasResourceId(
      'resource-a',
    )],
    isA<ResolvedResourceImage>(),
  );

  runtime.resources.markResourceDirty(CanvasResourceId('resource-a'));
  await tester.pump();

  expect(resolver.calls, 2);
  expect(image.debugDisposed, isFalse);
  image.dispose();
}

Future<void> _expectMainAndOverlayPreviewRouting(WidgetTester tester) async {
  final runtime = CanvasRuntime(initialDocument: _rectDocument());
  final resolver = _RecordingResolver((_) => null);
  addTearDown(runtime.dispose);

  await tester.pumpWidget(_surfaceHost(runtime, resolver));
  await _expectSelectedMoveMainRepaint(tester, runtime);
  await _expectMarqueeOverlayOnly(tester, runtime);
  expect(resolver.calls, 0);
}

Future<void> _expectSelectedMoveMainRepaint(
  WidgetTester tester,
  CanvasRuntime runtime,
) async {
  runtime.selection.setSelection([CanvasElementId('rect-a')]);
  _rootFor(runtime).replaceInteractionPreview(
    const CanvasSelectedMovePreview(delta: Offset(4, 5)),
  );
  await tester.pump();

  expect(
    _mainPainter(tester).output.repaintSignal.reason,
    'selected_move_preview',
  );
  expect(_overlayPainter(tester).output.overlayPreviewPlan.primitives, isEmpty);
}

Future<void> _expectMarqueeOverlayOnly(
  WidgetTester tester,
  CanvasRuntime runtime,
) async {
  _rootFor(runtime).replaceInteractionPreview(
    const CanvasMarqueePreview(rect: Rect.fromLTWH(1, 2, 3, 4)),
  );
  await tester.pump();

  expect(_mainPainter(tester).output.capturedFrame.selectedMovePreview, isNull);
  expect(
    _overlayPainter(tester).output.overlayPreviewPlan.primitives,
    isNotEmpty,
  );
}

Widget _surfaceHost(CanvasRuntime runtime, CanvasResourceResolver resolver) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: 100,
      height: 100,
      child: CanvasSurface(
        runtime: runtime,
        resourceResolver: resolver,
        interactive: false,
      ),
    ),
  );
}

void _expectPaintHost() {
  expect(_paintHosts(), findsOneWidget);
  expect(find.byType(CustomPaint), findsOneWidget);
}

Finder _paintHosts() {
  return find.byKey(const ValueKey<String>('iwb_canvas_surface.paint_host'));
}

MainFramePainter _mainPainter(WidgetTester tester) {
  final paintHost = tester.widget<CustomPaint>(_paintHosts());
  final painter = paintHost.painter;
  expect(painter, isA<MainFramePainter>());

  return painter as MainFramePainter;
}

OverlayFramePainter _overlayPainter(WidgetTester tester) {
  final paintHost = tester.widget<CustomPaint>(_paintHosts());
  final painter = paintHost.foregroundPainter;
  expect(painter, isA<OverlayFramePainter>());

  return painter as OverlayFramePainter;
}

RuntimeRoot _rootFor(CanvasRuntime runtime) {
  final root = canvasRuntimeFrameRootForSurface(runtime);
  if (root != null) {
    return root;
  }

  throw StateError('CanvasRuntime frame root is not attached.');
}

CanvasDocument _rectDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('rect-a'),
            size: const Size(10, 10),
            fillColor: const Color(0xFF336699),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _resourceDescriptorOnlyDocument() {
  return CanvasDocument(
    resources: [_imageResource()],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('rect-a'),
            size: const Size(10, 10),
            fillColor: const Color(0xFF336699),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _imageDocument() {
  return CanvasDocument(
    resources: [_imageResource()],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('image-a'),
            resourceId: CanvasResourceId('resource-a'),
            size: const Size(10, 10),
          ),
        ],
      ),
    ],
  );
}

CanvasImageResource _imageResource() {
  return CanvasImageResource(
    id: CanvasResourceId('resource-a'),
    source: CanvasResourceSource.appKey('image-a'),
    mimeType: 'image/png',
    byteLength: 24,
  );
}

Future<ui.Image> _createImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 1, 1),
    Paint()..color = const Color(0xFF00AA00),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(1, 1);
  picture.dispose();

  return image;
}

final class _RecordingResolver implements CanvasResourceResolver {
  _RecordingResolver(this._resolve);

  final ui.Image? Function(CanvasImageResource resource) _resolve;
  int calls = 0;

  @override
  ui.Image? resolveImage(CanvasImageResource resource) {
    calls += 1;

    return _resolve(resource);
  }
}
