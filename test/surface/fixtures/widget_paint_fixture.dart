import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

// This fixture is the widget-level proof surface for CanvasSurface repaint
// routing, so it intentionally imports the public widget API and internal probes.
// ignore_for_file: number-of-external-imports, number-of-imports

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import 'package:iwb_canvas_engine/src/api/canvas_runtime_frame_bridge.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_prepared_vector.dart';
import 'package:iwb_canvas_engine/src/frame/paint_asset_binding_service.dart';
import 'package:iwb_canvas_engine/src/resources/surface_resource_session.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import 'package:iwb_canvas_engine/src/surface/main_painter.dart';
import 'package:iwb_canvas_engine/src/surface/overlay_painter.dart';

import '../../preparation/fixtures/vector_preparation_fixture.dart';

// The registration block keeps the full CanvasSurface repaint matrix visible in
// one fixture instead of scattering the proof across unrelated test files.
// ignore: halstead-volume, maintainability-index, source-lines-of-code
void main() {
  test('CanvasSurface layer host isolates repaint boundaries', () {
    final source = File(
      'lib/src/surface/layer_paint_host.dart',
    ).readAsStringSync();

    expect(_tokenCount(source, 'RepaintBoundary('), 2);
    expect(_tokenCount(source, 'CustomPaint('), 2);
    expect(source, contains('iwb_canvas_surface.main_paint_host'));
    expect(source, contains('iwb_canvas_surface.overlay_paint_host'));
  });

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

  testWidgets(
    'CanvasSurface releases retained target bindings before dirty publication',
    (tester) async {
      await _expectTargetReleasePrecedesDirtyPublication(tester);
      expect(_paintHosts(), findsOneWidget);
    },
  );

  testWidgets(
    'CanvasSurface releases all retained bindings for lifecycle paths and stale sessions',
    (tester) async {
      await _expectAllRetainedReleasePaths(tester);
      expect(_paintHosts(), findsOneWidget);
    },
  );

  testWidgets(
    'CanvasSurface releases vector output borrows before detach and ignores stale releases',
    (tester) async {
      await _expectVectorRetainedOutputReleaseAndStaleIsolation(tester);
      expect(_paintHosts(), findsNothing);
    },
  );

  testWidgets(
    'same vector wrapper remains application-owned across two attached runtimes',
    (tester) async {
      await _expectSameWrapperAliasesAcrossAttachedRuntimes(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('CanvasSurface schedules resource budget follow-up frames', (
    tester,
  ) async {
    await _expectResourceBudgetFollowUpFrame(tester);
    expect(_paintHosts(), findsOneWidget);
  });

  testWidgets('stale resource budget follow-up does not rebuild old surface', (
    tester,
  ) async {
    await _expectStaleBudgetFollowUpIgnored(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CanvasSurface splits selected move and overlay previews', (
    tester,
  ) async {
    await _expectMainAndOverlayPreviewRouting(tester);
    expect(_paintHosts(), findsOneWidget);
  });

  testWidgets('CanvasSurface coalesces synchronous runtime repaint frames', (
    tester,
  ) async {
    await _expectSynchronousRuntimeFrameCoalescing(tester);
    expect(_paintHosts(), findsOneWidget);
  });

  testWidgets('CanvasSurface rebuilds both layers for document replacement', (
    tester,
  ) async {
    await _expectDocumentReplacementRebuildsBothLayers(tester);
    expect(_paintHosts(), findsOneWidget);
  });

  testWidgets('CanvasSurface painters do not construct outputs during paint', (
    tester,
  ) async {
    await _expectPainterPaintDoesNotBuildOutputs(tester);
    expect(_paintHosts(), findsOneWidget);
  });

  testWidgets('CanvasSurface routes local input invalidations by layer', (
    tester,
  ) async {
    await _expectLocalInputInvalidationRouting(tester);
    expect(_paintHosts(), findsOneWidget);
  });

  testWidgets('CanvasSurface routes resource invalidations by layer', (
    tester,
  ) async {
    await _expectResourceInvalidationRouting(tester);
    expect(_paintHosts(), findsOneWidget);
  });

  testWidgets('CanvasSurface rebuilds both layers for runtime swap', (
    tester,
  ) async {
    await _expectRuntimeSwapRebuildsBothLayers(tester);
    expect(_paintHosts(), findsOneWidget);
  });

  testWidgets(
    'CanvasSurface ignores inactive runtime publications after swap',
    (tester) async {
      await _expectInactiveRuntimePublicationIgnoredAfterSwap(tester);
      expect(_paintHosts(), findsOneWidget);
    },
  );

  testWidgets('CanvasSurface rejected attach installs no layer listener', (
    tester,
  ) async {
    await _expectRejectedAttachInstallsNoLayerListener(tester);
    expect(_paintHosts(), findsOneWidget);
  });

  testWidgets('CanvasSurface ignores runtime publications after detach', (
    tester,
  ) async {
    await _expectDetachedSurfaceIgnoresRuntimePublications(tester);
    expect(_paintHosts(), findsNothing);
  });

  testWidgets('CanvasSurface rebuilds for inline text paint suppression', (
    tester,
  ) async {
    await _expectInlineTextSuppressionSurfaceRepaint(tester);
    expect(_paintHosts(), findsOneWidget);
  });
}

Future<void> _expectEmptyAndResourceFreePaint(WidgetTester tester) async {
  final emptyRuntime = runtimeWithDocument(CanvasDocument());
  final emptyResolver = _RecordingResolver((_) => null);
  addTearDown(emptyRuntime.dispose);
  await tester.pumpWidget(
    _SurfaceHost(runtime: emptyRuntime, resolver: emptyResolver),
  );
  _expectPaintHost();
  expect(emptyResolver.calls, 0);

  final resourceFreeRuntime = runtimeWithDocument(_rectDocument());
  final resourceFreeResolver = _RecordingResolver((_) => null);
  addTearDown(resourceFreeRuntime.dispose);
  await tester.pumpWidget(
    _SurfaceHost(runtime: resourceFreeRuntime, resolver: resourceFreeResolver),
  );
  _expectPaintHost();
  expect(resourceFreeResolver.calls, 0);

  final descriptorOnlyRuntime = runtimeWithDocument(
    _resourceDescriptorOnlyDocument(),
  );
  final descriptorOnlyResolver = _RecordingResolver((_) => null);
  addTearDown(descriptorOnlyRuntime.dispose);
  await tester.pumpWidget(
    _SurfaceHost(
      runtime: descriptorOnlyRuntime,
      resolver: descriptorOnlyResolver,
    ),
  );
  _expectPaintHost();
  expect(descriptorOnlyResolver.calls, 0);
}

Future<void> _expectImageResourcePaintAndDirtyRepaint(
  WidgetTester tester,
) async {
  final image = await _createImage();
  final runtime = runtimeWithDocument(_imageDocument());
  final resolver = _RecordingResolver((_) => image);
  addTearDown(runtime.dispose);

  await tester.pumpWidget(_SurfaceHost(runtime: runtime, resolver: resolver));

  _expectPaintHost();
  expect(resolver.calls, 1);
  expect(
    _mainPainter(tester).output.assetBindings.assets[CanvasResourceId(
      'resource-a',
    )],
    isA<FrameImageAssetBinding>(),
  );

  runtime.resources.markResourceDirty(CanvasResourceId('resource-a'));
  await tester.pump();

  expect(resolver.calls, 2);
  expect(image.debugDisposed, isFalse);
  image.dispose();
}

// Removing the retained main-output release after session-cache retirement
// must fail this scenario: publication would still expose resource-a's image.
// Cache removal, retained output, overlay preservation, and publication order
// are one synchronous contract, so splitting this proof would hide the failure.
// ignore: halstead-volume, source-lines-of-code
Future<void> _expectTargetReleasePrecedesDirtyPublication(
  WidgetTester tester,
) async {
  final firstImage = await _createImage();
  final secondImage = await _createImage();
  final runtime = runtimeWithDocument(_twoImageDocument());
  final resolver = _RecordingResolver(
    (resource) => resource.id.value == 'resource-a' ? firstImage : secondImage,
  );
  addTearDown(runtime.dispose);

  await tester.pumpWidget(_SurfaceHost(runtime: runtime, resolver: resolver));

  final mainBeforeRelease = _mainPainter(tester).output;
  final overlayBeforeRelease = _overlayPainter(tester).output;
  expect(mainBeforeRelease.assetBindings.assets.keys, {
    CanvasResourceId('resource-a'),
    CanvasResourceId('resource-b'),
  });
  expect(resolver.calls, 2);

  var observedBeforePublication = false;
  runtime.state.addListener(() {
    final output = _mainPainter(tester).output;
    expect(
      output.assetBindings.assets.containsKey(CanvasResourceId('resource-a')),
      isFalse,
    );
    expect(
      output.assetBindings.assets.containsKey(CanvasResourceId('resource-b')),
      isTrue,
    );
    expect(_overlayPainter(tester).output, same(overlayBeforeRelease));
    expect(resolver.calls, 2);
    observedBeforePublication = true;
  });

  runtime.resources.markResourceDirty(CanvasResourceId('resource-a'));

  expect(observedBeforePublication, isTrue);
  expect(
    _mainPainter(
      tester,
    ).output.assetBindings.assets.containsKey(CanvasResourceId('resource-a')),
    isFalse,
  );
  expect(
    _mainPainter(
      tester,
    ).output.assetBindings.assets.containsKey(CanvasResourceId('resource-b')),
    isTrue,
  );
  expect(_overlayPainter(tester).output, same(overlayBeforeRelease));
  expect(firstImage.debugDisposed, isFalse);
  expect(secondImage.debugDisposed, isFalse);
  firstImage.dispose();
  secondImage.dispose();
}

// Removing any active all-release callback leaves the retained main output
// borrowed after mark-all, replacement, reset, or drop and fails this scenario.
// Lifecycle ordering and output identity share one witness; keeping it together
// makes stale-session mutation and all-release regressions directly observable.
// ignore: halstead-volume, source-lines-of-code
Future<void> _expectAllRetainedReleasePaths(WidgetTester tester) async {
  final firstImage = await _createImage();
  final secondImage = await _createImage();
  final runtime = runtimeWithDocument(_twoImageDocument());
  final resolver = _RecordingResolver(
    (resource) => resource.id.value == 'resource-a' ? firstImage : secondImage,
  );
  addTearDown(runtime.dispose);

  await tester.pumpWidget(_SurfaceHost(runtime: runtime, resolver: resolver));
  final session = _activeSurfaceSession(runtime);
  final overlay = _overlayPainter(tester).output;
  _expectRetainedImages(tester, {'resource-a', 'resource-b'});

  runtime.resources.markAllResourcesDirty();
  _expectRetainedImages(tester, <String>{});
  expect(_overlayPainter(tester).output, same(overlay));
  expect(resolver.calls, 2);
  await tester.pump();
  _expectRetainedImages(tester, {'resource-a', 'resource-b'});

  session.replaceResolver(resolver);
  _expectRetainedImages(tester, <String>{});
  expect(_overlayPainter(tester).output, same(overlay));
  expect(resolver.calls, 4);

  runtime.resources.markAllResourcesDirty();
  await tester.pump();
  _expectRetainedImages(tester, {'resource-a', 'resource-b'});

  runtime.edits.loadDocumentFromJson(
    encodeCanvasDocumentToJson(_twoImageDocument()),
  );
  _expectRetainedImages(tester, <String>{});
  expect(_overlayPainter(tester).output, same(overlay));
  await tester.pump();
  _expectRetainedImages(tester, {'resource-a', 'resource-b'});

  session.drop();
  _expectRetainedImages(tester, <String>{});
  expect(firstImage.debugDisposed, isFalse);
  expect(secondImage.debugDisposed, isFalse);

  await _expectStaleSessionDoesNotReleaseCurrentOutput(
    tester,
    oldImage: firstImage,
    newImage: secondImage,
  );
  firstImage.dispose();
  secondImage.dispose();
}

// Target/all release, drop/detach, and stale-session isolation must observe
// the actual retained output, not only the session callback counts.
// ignore: halstead-volume, source-lines-of-code
Future<void> _expectVectorRetainedOutputReleaseAndStaleIsolation(
  WidgetTester tester,
) async {
  final prepared = await prepareVector(basicVectorBytes());
  final exactPicture = liveCanvasPreparedVectorPicture(prepared);
  final disposedPictures = <ui.Picture>[];
  final previousOnDispose = ui.Picture.onDispose;
  ui.Picture.onDispose = (picture) {
    if (identical(picture, exactPicture)) {
      disposedPictures.add(picture);
    }
  };
  addTearDown(() {
    ui.Picture.onDispose = previousOnDispose;
  });
  final runtime = runtimeWithDocument(_twoVectorDocument());
  final resolver = _RecordingResolver(
    (_) => null,
    resolvePreparedVector: (_) => prepared,
  );
  addTearDown(runtime.dispose);

  await tester.pumpWidget(_SurfaceHost(runtime: runtime, resolver: resolver));
  final session = _activeSurfaceSession(runtime);
  _expectRetainedVectors(tester, {'vector-a', 'vector-b'}, prepared);

  runtime.resources.markResourceDirty(CanvasResourceId('vector-a'));
  _expectRetainedVectors(tester, {'vector-b'}, prepared);

  runtime.resources.markAllResourcesDirty();
  _expectRetainedVectors(tester, <String>{}, prepared);
  await tester.pump();
  _expectRetainedVectors(tester, {'vector-a', 'vector-b'}, prepared);

  session.replaceResolver(resolver);
  _expectRetainedVectors(tester, <String>{}, prepared);
  runtime.resources.markAllResourcesDirty();
  await tester.pump();
  _expectRetainedVectors(tester, {'vector-a', 'vector-b'}, prepared);

  runtime.edits.loadDocumentFromJson(
    encodeCanvasDocumentToJson(_twoVectorDocument()),
  );
  _expectRetainedVectors(tester, <String>{}, prepared);
  await tester.pump();
  _expectRetainedVectors(tester, {'vector-a', 'vector-b'}, prepared);

  await tester.pumpWidget(const SizedBox.shrink());
  expect(_paintHosts(), findsNothing);
  expect(disposedPictures, isEmpty);
  await tester.pumpWidget(_SurfaceHost(runtime: runtime, resolver: resolver));
  final droppedSession = _activeSurfaceSession(runtime);
  _expectRetainedVectors(tester, {'vector-a', 'vector-b'}, prepared);

  droppedSession.drop();
  _expectRetainedVectors(tester, <String>{}, prepared);
  expect(disposedPictures, isEmpty);

  await _expectStaleVectorSessionCannotClearCurrentOutput(tester, prepared);
  await tester.pumpWidget(const SizedBox.shrink());
  expect(_paintHosts(), findsNothing);
  expect(disposedPictures, isEmpty);

  prepared.dispose();
  expect(disposedPictures, [exactPicture]);
}

Future<void> _expectStaleVectorSessionCannotClearCurrentOutput(
  WidgetTester tester,
  CanvasPreparedVector prepared,
) async {
  final oldRuntime = runtimeWithDocument(_vectorDocument('stale-vector'));
  final currentRuntime = runtimeWithDocument(_vectorDocument('current-vector'));
  final oldResolver = _RecordingResolver(
    (_) => null,
    resolvePreparedVector: (_) => prepared,
  );
  final currentResolver = _RecordingResolver(
    (_) => null,
    resolvePreparedVector: (_) => prepared,
  );
  addTearDown(oldRuntime.dispose);
  addTearDown(currentRuntime.dispose);

  await tester.pumpWidget(
    _SurfaceHost(runtime: oldRuntime, resolver: oldResolver),
  );
  final staleSession = _activeSurfaceSession(oldRuntime);
  await tester.pumpWidget(
    _SurfaceHost(runtime: currentRuntime, resolver: currentResolver),
  );
  final currentOutput = _mainPainter(tester).output;

  staleSession.releaseResource(CanvasResourceId('stale-vector'));
  staleSession.releaseAllResources();
  staleSession.resetForDocumentReplacement();
  staleSession.drop();

  expect(_mainPainter(tester).output, same(currentOutput));
  _expectRetainedVectors(tester, {'current-vector'}, prepared);
}

// This two-runtime witness keeps the same wrapper borrowed by two real active
// surfaces so one detach cannot authorize application disposal or later paint.
// ignore: halstead-volume, source-lines-of-code
Future<void> _expectSameWrapperAliasesAcrossAttachedRuntimes(
  WidgetTester tester,
) async {
  final prepared = await prepareVector(basicVectorBytes());
  final exactPicture = liveCanvasPreparedVectorPicture(prepared);
  final disposedPictures = <ui.Picture>[];
  final previousOnDispose = ui.Picture.onDispose;
  ui.Picture.onDispose = (picture) {
    if (identical(picture, exactPicture)) {
      disposedPictures.add(picture);
    }
  };
  addTearDown(() {
    ui.Picture.onDispose = previousOnDispose;
  });
  final firstRuntime = runtimeWithDocument(_vectorDocument('alias-a'));
  final secondRuntime = runtimeWithDocument(_vectorDocument('alias-b'));
  final resolver = _RecordingResolver(
    (_) => null,
    resolvePreparedVector: (_) => prepared,
  );
  addTearDown(firstRuntime.dispose);
  addTearDown(secondRuntime.dispose);

  await tester.pumpWidget(
    _TwoRuntimeSurfaceHost(
      firstRuntime: firstRuntime,
      secondRuntime: secondRuntime,
      firstResolver: resolver,
      secondResolver: resolver,
      includeFirst: true,
    ),
  );
  final painters = _mainPainters(tester);
  expect(painters, hasLength(2));
  expect(
    _boundVectorFor(painters[0], CanvasResourceId('alias-a')),
    same(prepared),
  );
  expect(
    _boundVectorFor(painters[1], CanvasResourceId('alias-b')),
    same(prepared),
  );

  await tester.pumpWidget(
    _TwoRuntimeSurfaceHost(
      firstRuntime: firstRuntime,
      secondRuntime: secondRuntime,
      firstResolver: resolver,
      secondResolver: resolver,
      includeFirst: false,
    ),
  );
  expect(_mainPainters(tester), hasLength(1));
  expect(
    _boundVectorFor(_mainPainters(tester).single, CanvasResourceId('alias-b')),
    same(prepared),
  );
  expect(disposedPictures, isEmpty);

  await tester.pumpWidget(const SizedBox.shrink());
  expect(_mainPainters(tester), isEmpty);
  expect(disposedPictures, isEmpty);
  prepared.dispose();
  expect(disposedPictures, [exactPicture]);
}

Future<void> _expectStaleSessionDoesNotReleaseCurrentOutput(
  WidgetTester tester, {
  required ui.Image oldImage,
  required ui.Image newImage,
}) async {
  final oldRuntime = runtimeWithDocument(_imageDocument());
  final newRuntime = runtimeWithDocument(_twoImageDocument());
  final oldResolver = _RecordingResolver((_) => oldImage);
  final newResolver = _RecordingResolver(
    (resource) => resource.id.value == 'resource-a' ? oldImage : newImage,
  );
  addTearDown(oldRuntime.dispose);
  addTearDown(newRuntime.dispose);

  await tester.pumpWidget(
    _SurfaceHost(runtime: oldRuntime, resolver: oldResolver),
  );
  final staleSession = _activeSurfaceSession(oldRuntime);
  await tester.pumpWidget(
    _SurfaceHost(runtime: newRuntime, resolver: newResolver),
  );
  final currentOutput = _mainPainter(tester).output;

  staleSession.releaseResource(CanvasResourceId('resource-a'));
  staleSession.releaseAllResources();
  staleSession.resetForDocumentReplacement();
  staleSession.drop();

  expect(_mainPainter(tester).output, same(currentOutput));
  _expectRetainedImages(tester, {'resource-a', 'resource-b'});
  expect(oldResolver.calls, 1);
  expect(newResolver.calls, 2);
}

void _expectRetainedImages(WidgetTester tester, Set<String> expectedIds) {
  expect(
    _mainPainter(tester).output.assetBindings.assets.keys.map((id) => id.value),
    expectedIds,
  );
}

void _expectRetainedVectors(
  WidgetTester tester,
  Set<String> expectedIds,
  CanvasPreparedVector prepared,
) {
  final painter = _mainPainter(tester);
  expect(
    painter.output.assetBindings.assets.keys.map((id) => id.value),
    expectedIds,
  );
  for (final id in expectedIds) {
    expect(_boundVectorFor(painter, CanvasResourceId(id)), same(prepared));
  }
}

CanvasPreparedVector _boundVectorFor(
  MainFramePainter painter,
  CanvasResourceId id,
) {
  final binding = painter.output.assetBindings.assets[id];
  if (binding is! FrameVectorAssetBinding) {
    throw StateError('Expected a resolved vector asset for $id.');
  }

  return binding.prepared;
}

// Budget follow-up behavior depends on resolver calls, layer dispatch, and
// render-object paint flags being asserted in one ordered widget scenario.
// ignore: halstead-volume
Future<void> _expectResourceBudgetFollowUpFrame(WidgetTester tester) async {
  final image = await _createImage();
  final runtime = runtimeWithDocument(_manyImageDocument(140));
  final resolver = _RecordingResolver((_) => image);
  addTearDown(runtime.dispose);

  await tester.pumpWidget(_SurfaceHost(runtime: runtime, resolver: resolver));
  final probe = _LayerDispatchProbe(tester);
  addTearDown(probe.dispose);

  expect(resolver.calls, 128);
  expect(_budgetPlaceholders(tester), 12);
  final beforeMain = _mainPainter(tester).output;
  final beforeOverlay = _overlayPainter(tester).output;
  probe.reset();

  await tester.pump(null, EnginePhase.layout);

  expect(_mainPainter(tester).output, isNot(same(beforeMain)));
  expect(_overlayPainter(tester).output, same(beforeOverlay));
  expect(resolver.calls, 140);
  expect(_budgetPlaceholders(tester), 0);
  expect(probe.mainDispatches, 1);
  expect(probe.overlayDispatches, 0);
  expect(_mainRenderObject(tester).debugNeedsPaint, isTrue);
  expect(_overlayRenderObject(tester).debugNeedsPaint, isFalse);
  await tester.pump();

  await tester.pump();

  expect(resolver.calls, 140);
  expect(_budgetPlaceholders(tester), 0);
  expect(image.debugDisposed, isFalse);
  image.dispose();
}

// The stale follow-up guard must keep old/new runtimes and layer outputs in one
// scenario so inactive resource publications cannot be mistaken for valid work.
// ignore: halstead-volume
Future<void> _expectStaleBudgetFollowUpIgnored(WidgetTester tester) async {
  final oldImage = await _createImage();
  final newImage = await _createImage();
  final oldRuntime = runtimeWithDocument(_manyImageDocument(140));
  final newRuntime = runtimeWithDocument(_imageDocument());
  final oldResolver = _RecordingResolver((_) => oldImage);
  final newResolver = _RecordingResolver((_) => newImage);
  addTearDown(oldRuntime.dispose);
  addTearDown(newRuntime.dispose);

  await tester.pumpWidget(
    _SurfaceHost(runtime: oldRuntime, resolver: oldResolver),
  );
  expect(oldResolver.calls, 128);

  await tester.pumpWidget(
    _SurfaceHost(runtime: newRuntime, resolver: newResolver),
  );
  final probe = _LayerDispatchProbe(tester);
  addTearDown(probe.dispose);
  final beforeMain = _mainPainter(tester).output;
  final beforeOverlay = _overlayPainter(tester).output;

  expect(oldResolver.calls, 128);
  expect(newResolver.calls, 1);
  probe.reset();
  _rootFor(oldRuntime).replaceInteractionPreview(
    const CanvasMarqueePreview(rect: Rect.fromLTWH(1, 2, 3, 4)),
  );

  await tester.pump(null, EnginePhase.layout);

  expect(_mainPainter(tester).output, same(beforeMain));
  expect(_overlayPainter(tester).output, same(beforeOverlay));
  expect(oldResolver.calls, 128);
  expect(newResolver.calls, 1);
  expect(probe.mainDispatches, 0);
  expect(probe.overlayDispatches, 0);
  expect(_mainRenderObject(tester).debugNeedsPaint, isFalse);
  expect(_overlayRenderObject(tester).debugNeedsPaint, isFalse);
  await tester.pump();
  expect(oldImage.debugDisposed, isFalse);
  expect(newImage.debugDisposed, isFalse);
  oldImage.dispose();
  newImage.dispose();
}

Future<void> _expectMainAndOverlayPreviewRouting(WidgetTester tester) async {
  final image = await _createImage();
  final runtime = runtimeWithDocument(_imageDocument());
  final resolver = _RecordingResolver((_) => image);
  addTearDown(runtime.dispose);
  addTearDown(image.dispose);

  await tester.pumpWidget(_SurfaceHost(runtime: runtime, resolver: resolver));
  final probe = _LayerDispatchProbe(tester);
  addTearDown(probe.dispose);

  expect(resolver.calls, 1);
  await _expectSelectedMoveMainRepaint(tester, runtime, resolver, probe);
  _rootFor(runtime).clearInteractionPreview();
  await tester.pump();
  probe.reset();

  await _expectMarqueeOverlayOnly(tester, runtime, resolver, probe);
}

// Coalescing proof is clearer with all three synchronous runtime publications
// and layer counters asserted in the same scenario.
// ignore: halstead-volume
Future<void> _expectSynchronousRuntimeFrameCoalescing(
  WidgetTester tester,
) async {
  final runtime = runtimeWithDocument(_rectDocument());
  final resolver = _RecordingResolver((_) => null);
  addTearDown(runtime.dispose);

  await tester.pumpWidget(_SurfaceHost(runtime: runtime, resolver: resolver));

  final beforeMain = _mainPainter(tester).output;
  final beforeOverlay = _overlayPainter(tester).output;
  runtime.selection.setSelection([CanvasElementId('rect-a')]);
  _rootFor(runtime).replaceInteractionPreview(
    const CanvasMarqueePreview(rect: Rect.fromLTWH(1, 2, 3, 4)),
  );
  await tester.pump();

  expect(_mainPainter(tester).output, isNot(same(beforeMain)));
  expect(_overlayPainter(tester).output, isNot(same(beforeOverlay)));
  expect(
    _mainPainter(
      tester,
    ).output.capturedFrame.snapshot.selection.selectedElementIds,
    [CanvasElementId('rect-a')],
  );
  expect(
    _overlayPainter(tester).output.overlayPreviewPlan.primitives,
    isNotEmpty,
  );
  expect(resolver.calls, 0);
}

// Document replacement must compare both layer outputs before and after the
// same runtime mutation, so the proof stays together.
// ignore: halstead-volume
Future<void> _expectDocumentReplacementRebuildsBothLayers(
  WidgetTester tester,
) async {
  final runtime = runtimeWithDocument(_rectDocument());
  final resolver = _RecordingResolver((_) => null);
  addTearDown(runtime.dispose);

  await tester.pumpWidget(_SurfaceHost(runtime: runtime, resolver: resolver));
  final probe = _LayerDispatchProbe(tester);
  addTearDown(probe.dispose);
  final beforeMain = _mainPainter(tester).output;
  final beforeOverlay = _overlayPainter(tester).output;
  probe.reset();

  runtime.edits.edit((edit) {
    edit.replaceDraftDocument(_textAndRectDocument());
  });
  await tester.pump(null, EnginePhase.layout);

  expect(_mainPainter(tester).output, isNot(same(beforeMain)));
  expect(_overlayPainter(tester).output, isNot(same(beforeOverlay)));
  expect(_mainRecordIds(tester), contains(_surfaceTextId));
  expect(probe.mainDispatches, 1);
  expect(probe.overlayDispatches, 1);
  expect(_mainRenderObject(tester).debugNeedsPaint, isTrue);
  expect(_overlayRenderObject(tester).debugNeedsPaint, isTrue);
  await tester.pump();
}

Future<void> _expectInlineTextSuppressionSurfaceRepaint(
  WidgetTester tester,
) async {
  final scenario = _InlineTextSurfaceScenario();
  addTearDown(scenario.dispose);

  await tester.pumpWidget(
    _SurfaceHost(runtime: scenario.runtime, resolver: scenario.resolver),
  );
  expect(_mainRecordIds(tester), contains(_surfaceTextId));

  final session = await scenario.startTextSession(tester);
  await tester.pump();

  expect(_mainRecordIds(tester), isNot(contains(_surfaceTextId)));
  expect(_mainRecordIds(tester), contains(_surfaceRectId));

  session.dismiss();
  await tester.pump();

  expect(_mainRecordIds(tester), contains(_surfaceTextId));
}

Future<void> _expectPainterPaintDoesNotBuildOutputs(WidgetTester tester) async {
  final image = await _createImage();
  final runtime = runtimeWithDocument(_imageDocument());
  final resolver = _RecordingResolver((_) => image);
  addTearDown(runtime.dispose);
  addTearDown(image.dispose);

  await tester.pumpWidget(_SurfaceHost(runtime: runtime, resolver: resolver));
  final probe = _LayerDispatchProbe(tester);
  addTearDown(probe.dispose);
  final beforeMain = _mainPainter(tester).output;
  final beforeOverlay = _overlayPainter(tester).output;

  expect(resolver.calls, 1);
  _paintCurrentOutputs(tester);
  _paintCurrentOutputs(tester);

  expect(_mainPainter(tester).output, same(beforeMain));
  expect(_overlayPainter(tester).output, same(beforeOverlay));
  expect(probe.mainDispatches, 0);
  expect(probe.overlayDispatches, 0);
  expect(resolver.calls, 1);
  _expectPaintersDoNotCallSurfaceFrameBuilders();
}

Future<void> _expectLocalInputInvalidationRouting(WidgetTester tester) async {
  final runtime = runtimeWithDocument(_rectDocument());
  final resolver = _RecordingResolver((_) => null);
  addTearDown(runtime.dispose);

  await tester.pumpWidget(_SurfaceHost(runtime: runtime, resolver: resolver));
  final probe = _LayerDispatchProbe(tester);
  addTearDown(probe.dispose);

  await _expectGridStyleMainOnly(tester, runtime, resolver, probe);
  await _expectSelectionStyleBothLayers(tester, runtime, resolver, probe);
  await _expectDevicePixelRatioBothLayers(tester, runtime, resolver, probe);
  await _expectLayoutSizeBothLayers(tester, runtime, resolver, probe);
}

Future<void> _expectResourceInvalidationRouting(WidgetTester tester) async {
  final firstImage = await _createImage();
  final secondImage = await _createImage();
  final runtime = runtimeWithDocument(_imageDocument());
  final firstResolver = _RecordingResolver((_) => firstImage);
  final secondResolver = _RecordingResolver((_) => secondImage);
  addTearDown(runtime.dispose);
  addTearDown(firstImage.dispose);
  addTearDown(secondImage.dispose);

  await tester.pumpWidget(
    _SurfaceHost(runtime: runtime, resolver: firstResolver),
  );
  final probe = _LayerDispatchProbe(tester);
  addTearDown(probe.dispose);

  await _expectResourceDirtyMainOnly(tester, runtime, firstResolver, probe);
  await _expectAllResourcesDirtyMainOnly(tester, runtime, firstResolver, probe);
  await _expectResolverReplacementMainOnly(
    tester,
    runtime,
    secondResolver,
    probe,
  );
}

// Runtime swap proof needs both runtimes, outputs, and dispatch counters in one
// ordered flow to catch stale listener behavior.
// ignore: halstead-volume
Future<void> _expectRuntimeSwapRebuildsBothLayers(WidgetTester tester) async {
  final oldRuntime = runtimeWithDocument(_rectDocument());
  final newRuntime = runtimeWithDocument(_textAndRectDocument());
  final resolver = _RecordingResolver((_) => null);
  addTearDown(oldRuntime.dispose);
  addTearDown(newRuntime.dispose);

  await tester.pumpWidget(
    _SurfaceHost(runtime: oldRuntime, resolver: resolver),
  );
  final probe = _LayerDispatchProbe(tester);
  addTearDown(probe.dispose);
  final beforeMain = _mainPainter(tester).output;
  final beforeOverlay = _overlayPainter(tester).output;
  probe.reset();

  await tester.pumpWidget(
    _SurfaceHost(runtime: newRuntime, resolver: resolver),
    phase: EnginePhase.layout,
  );

  expect(_mainPainter(tester).output, isNot(same(beforeMain)));
  expect(_overlayPainter(tester).output, isNot(same(beforeOverlay)));
  expect(_mainRecordIds(tester), contains(_surfaceTextId));
  expect(probe.mainDispatches, greaterThanOrEqualTo(1));
  expect(probe.overlayDispatches, greaterThanOrEqualTo(1));
  expect(_mainRenderObject(tester).debugNeedsPaint, isTrue);
  expect(_overlayRenderObject(tester).debugNeedsPaint, isTrue);
  await tester.pump();
}

// This stale-publication scenario keeps inactive runtime mutations adjacent to
// the active output assertions so swap isolation remains auditable.
// ignore: halstead-volume
Future<void> _expectInactiveRuntimePublicationIgnoredAfterSwap(
  WidgetTester tester,
) async {
  final oldImage = await _createImage();
  final oldRuntime = runtimeWithDocument(_imageDocument());
  final newRuntime = runtimeWithDocument(_rectDocument());
  final oldResolver = _RecordingResolver((_) => oldImage);
  final newResolver = _RecordingResolver((_) => null);
  addTearDown(oldRuntime.dispose);
  addTearDown(newRuntime.dispose);
  addTearDown(oldImage.dispose);

  await tester.pumpWidget(
    _SurfaceHost(runtime: oldRuntime, resolver: oldResolver),
  );
  expect(oldResolver.calls, 1);

  await tester.pumpWidget(
    _SurfaceHost(runtime: newRuntime, resolver: newResolver),
  );
  final probe = _LayerDispatchProbe(tester);
  addTearDown(probe.dispose);
  final beforeMain = _mainPainter(tester).output;
  final beforeOverlay = _overlayPainter(tester).output;
  final beforeOldResolverCalls = oldResolver.calls;
  probe.reset();

  oldRuntime.resources.markResourceDirty(CanvasResourceId('resource-a'));
  _rootFor(oldRuntime).replaceInteractionPreview(
    const CanvasMarqueePreview(rect: Rect.fromLTWH(1, 2, 3, 4)),
  );
  await tester.pump(null, EnginePhase.layout);

  expect(_mainPainter(tester).output, same(beforeMain));
  expect(_overlayPainter(tester).output, same(beforeOverlay));
  expect(oldResolver.calls, beforeOldResolverCalls);
  expect(probe.mainDispatches, 0);
  expect(probe.overlayDispatches, 0);
  expect(_mainRenderObject(tester).debugNeedsPaint, isFalse);
  expect(_overlayRenderObject(tester).debugNeedsPaint, isFalse);
  await tester.pump();
}

// Rejected attach proof intentionally checks the bad runtime, good runtime, and
// listener counters in one place to avoid hiding attach-order mistakes.
// ignore: halstead-volume, source-lines-of-code
Future<void> _expectRejectedAttachInstallsNoLayerListener(
  WidgetTester tester,
) async {
  final runtime = runtimeWithDocument(_imageDocument());
  final image = await _createImage();
  final acceptedResolver = _RecordingResolver((_) => image);
  final rejectedResolver = _RecordingResolver((_) => image);
  addTearDown(runtime.dispose);
  addTearDown(image.dispose);

  await tester.pumpWidget(
    _TwoSurfaceHost(
      runtime: runtime,
      acceptedResolver: acceptedResolver,
      rejectedResolver: null,
    ),
  );
  expect(acceptedResolver.calls, 1);
  final probe = _LayerDispatchProbe(tester);
  addTearDown(probe.dispose);

  await tester.pumpWidget(
    _TwoSurfaceHost(
      runtime: runtime,
      acceptedResolver: acceptedResolver,
      rejectedResolver: rejectedResolver,
    ),
  );
  final error = tester.takeException();
  expect(error, isStateError);
  expect(_paintHosts(), findsOneWidget);
  expect(rejectedResolver.calls, 0);

  final beforeMain = _mainPainter(tester).output;
  final beforeOverlay = _overlayPainter(tester).output;
  final beforeAcceptedResolverCalls = acceptedResolver.calls;
  probe.reset();

  runtime.resources.markResourceDirty(CanvasResourceId('resource-a'));
  await tester.pump(null, EnginePhase.layout);

  expect(tester.takeException(), isNull);
  expect(_mainPainter(tester).output, isNot(same(beforeMain)));
  expect(_overlayPainter(tester).output, same(beforeOverlay));
  expect(acceptedResolver.calls, beforeAcceptedResolverCalls + 1);
  expect(rejectedResolver.calls, 0);
  expect(probe.mainDispatches, 2);
  expect(probe.overlayDispatches, 0);
  expect(_mainRenderObject(tester).debugNeedsPaint, isTrue);
  expect(_overlayRenderObject(tester).debugNeedsPaint, isFalse);
  await tester.pump();
}

Future<void> _expectDetachedSurfaceIgnoresRuntimePublications(
  WidgetTester tester,
) async {
  final image = await _createImage();
  final runtime = runtimeWithDocument(_imageDocument());
  final resolver = _RecordingResolver((_) => image);
  addTearDown(runtime.dispose);
  addTearDown(image.dispose);

  await tester.pumpWidget(_SurfaceHost(runtime: runtime, resolver: resolver));
  expect(resolver.calls, 1);

  await tester.pumpWidget(const SizedBox.shrink());
  expect(_paintHosts(), findsNothing);
  final beforeResolverCalls = resolver.calls;

  runtime.resources.markResourceDirty(CanvasResourceId('resource-a'));
  _rootFor(runtime).replaceInteractionPreview(
    const CanvasMarqueePreview(rect: Rect.fromLTWH(1, 2, 3, 4)),
  );
  await tester.pump();

  expect(_paintHosts(), findsNothing);
  expect(resolver.calls, beforeResolverCalls);
  expect(tester.takeException(), isNull);
}

// Selected move routing compares preview and main-frame repaint effects in one
// sequence so overlay/main divergence remains explicit.
// ignore: halstead-volume
Future<void> _expectSelectedMoveMainRepaint(
  WidgetTester tester,
  CanvasRuntime runtime,
  _RecordingResolver resolver,
  _LayerDispatchProbe probe,
) async {
  final beforeMain = _mainPainter(tester).output;
  final beforeOverlay = _overlayPainter(tester).output;
  probe.reset();
  runtime.selection.setSelection([CanvasElementId('image-a')]);
  _rootFor(runtime).replaceInteractionPreview(
    const CanvasSelectedMovePreview(delta: Offset(4, 5)),
  );
  await tester.pump(null, EnginePhase.layout);

  expect(_mainPainter(tester).output, isNot(same(beforeMain)));
  expect(_overlayPainter(tester).output, same(beforeOverlay));
  expect(resolver.calls, greaterThanOrEqualTo(1));
  expect(probe.mainDispatches, 1);
  expect(probe.overlayDispatches, 0);
  expect(_mainRenderObject(tester).debugNeedsPaint, isTrue);
  expect(_overlayRenderObject(tester).debugNeedsPaint, isFalse);
  await tester.pump();
  expect(
    _mainPainter(tester).output.repaintSignal.reason,
    'selected_move_preview',
  );
  expect(_overlayPainter(tester).output.overlayPreviewPlan.primitives, isEmpty);
}

Future<void> _expectGridStyleMainOnly(
  WidgetTester tester,
  CanvasRuntime runtime,
  _RecordingResolver resolver,
  _LayerDispatchProbe probe,
) async {
  final beforeMain = _mainPainter(tester).output;
  final beforeOverlay = _overlayPainter(tester).output;
  final beforeResolverCalls = resolver.calls;
  probe.reset();

  await tester.pumpWidget(
    _SurfaceHost(
      runtime: runtime,
      resolver: resolver,
      gridStyle: CanvasGridStyle(strokeWidth: 2),
    ),
    phase: EnginePhase.layout,
  );

  expect(_mainPainter(tester).output, isNot(same(beforeMain)));
  expect(_overlayPainter(tester).output, same(beforeOverlay));
  expect(resolver.calls, beforeResolverCalls);
  expect(probe.mainDispatches, 1);
  expect(probe.overlayDispatches, 0);
  expect(_mainRenderObject(tester).debugNeedsPaint, isTrue);
  expect(_overlayRenderObject(tester).debugNeedsPaint, isFalse);
  await tester.pump();
}

Future<void> _expectSelectionStyleBothLayers(
  WidgetTester tester,
  CanvasRuntime runtime,
  _RecordingResolver resolver,
  _LayerDispatchProbe probe,
) async {
  final beforeMain = _mainPainter(tester).output;
  final beforeOverlay = _overlayPainter(tester).output;
  probe.reset();

  await tester.pumpWidget(
    _SurfaceHost(
      runtime: runtime,
      resolver: resolver,
      gridStyle: CanvasGridStyle(strokeWidth: 2),
      selectionStyle: CanvasSelectionStyle(color: const Color(0xFFFF0000)),
    ),
    phase: EnginePhase.layout,
  );

  expect(_mainPainter(tester).output, isNot(same(beforeMain)));
  expect(_overlayPainter(tester).output, isNot(same(beforeOverlay)));
  expect(probe.mainDispatches, 1);
  expect(probe.overlayDispatches, 1);
  expect(_mainRenderObject(tester).debugNeedsPaint, isTrue);
  expect(_overlayRenderObject(tester).debugNeedsPaint, isTrue);
  await tester.pump();
}

Future<void> _expectDevicePixelRatioBothLayers(
  WidgetTester tester,
  CanvasRuntime runtime,
  _RecordingResolver resolver,
  _LayerDispatchProbe probe,
) async {
  final beforeMain = _mainPainter(tester).output;
  final beforeOverlay = _overlayPainter(tester).output;
  probe.reset();

  await tester.pumpWidget(
    _SurfaceHost(
      runtime: runtime,
      resolver: resolver,
      devicePixelRatio: 2,
      gridStyle: CanvasGridStyle(strokeWidth: 2),
      selectionStyle: CanvasSelectionStyle(color: const Color(0xFFFF0000)),
    ),
    phase: EnginePhase.layout,
  );

  expect(_mainPainter(tester).output, isNot(same(beforeMain)));
  expect(_overlayPainter(tester).output, isNot(same(beforeOverlay)));
  expect(probe.mainDispatches, 1);
  expect(probe.overlayDispatches, 1);
  expect(_mainRenderObject(tester).debugNeedsPaint, isTrue);
  expect(_overlayRenderObject(tester).debugNeedsPaint, isTrue);
  await tester.pump();
}

// Layout-size routing is a two-layer comparison; splitting the assertions would
// make the shared viewport mutation harder to follow.
// ignore: halstead-volume
Future<void> _expectLayoutSizeBothLayers(
  WidgetTester tester,
  CanvasRuntime runtime,
  _RecordingResolver resolver,
  _LayerDispatchProbe probe,
) async {
  final beforeMain = _mainPainter(tester).output;
  final beforeOverlay = _overlayPainter(tester).output;
  probe.reset();

  await tester.pumpWidget(
    _SurfaceHost(
      runtime: runtime,
      resolver: resolver,
      size: const Size(120, 80),
      devicePixelRatio: 2,
      gridStyle: CanvasGridStyle(strokeWidth: 2),
      selectionStyle: CanvasSelectionStyle(color: const Color(0xFFFF0000)),
    ),
    phase: EnginePhase.layout,
  );

  expect(_mainPainter(tester).output, isNot(same(beforeMain)));
  expect(_overlayPainter(tester).output, isNot(same(beforeOverlay)));
  expect(
    _mainPainter(
      tester,
    ).output.capturedFrame.snapshot.inputs.viewportWorldBounds,
    const Rect.fromLTWH(0, 0, 120, 80),
  );
  expect(probe.mainDispatches, 1);
  expect(probe.overlayDispatches, 1);
  expect(_mainRenderObject(tester).debugNeedsPaint, isTrue);
  expect(_overlayRenderObject(tester).debugNeedsPaint, isTrue);
  await tester.pump();
}

Future<void> _expectResourceDirtyMainOnly(
  WidgetTester tester,
  CanvasRuntime runtime,
  _RecordingResolver resolver,
  _LayerDispatchProbe probe,
) async {
  final beforeMain = _mainPainter(tester).output;
  final beforeOverlay = _overlayPainter(tester).output;
  final beforeResolverCalls = resolver.calls;
  probe.reset();

  runtime.resources.markResourceDirty(CanvasResourceId('resource-a'));
  await tester.pump(null, EnginePhase.layout);

  expect(_mainPainter(tester).output, isNot(same(beforeMain)));
  expect(_overlayPainter(tester).output, same(beforeOverlay));
  expect(resolver.calls, beforeResolverCalls + 1);
  expect(probe.mainDispatches, 2);
  expect(probe.overlayDispatches, 0);
  expect(_mainRenderObject(tester).debugNeedsPaint, isTrue);
  expect(_overlayRenderObject(tester).debugNeedsPaint, isFalse);
  await tester.pump();
}

Future<void> _expectAllResourcesDirtyMainOnly(
  WidgetTester tester,
  CanvasRuntime runtime,
  _RecordingResolver resolver,
  _LayerDispatchProbe probe,
) async {
  final beforeMain = _mainPainter(tester).output;
  final beforeOverlay = _overlayPainter(tester).output;
  final beforeResolverCalls = resolver.calls;
  probe.reset();

  runtime.resources.markAllResourcesDirty();
  await tester.pump(null, EnginePhase.layout);

  expect(_mainPainter(tester).output, isNot(same(beforeMain)));
  expect(_overlayPainter(tester).output, same(beforeOverlay));
  expect(resolver.calls, beforeResolverCalls + 1);
  expect(probe.mainDispatches, 2);
  expect(probe.overlayDispatches, 0);
  expect(_mainRenderObject(tester).debugNeedsPaint, isTrue);
  expect(_overlayRenderObject(tester).debugNeedsPaint, isFalse);
  await tester.pump();
}

Future<void> _expectResolverReplacementMainOnly(
  WidgetTester tester,
  CanvasRuntime runtime,
  _RecordingResolver resolver,
  _LayerDispatchProbe probe,
) async {
  final beforeMain = _mainPainter(tester).output;
  final beforeOverlay = _overlayPainter(tester).output;
  probe.reset();

  await tester.pumpWidget(_SurfaceHost(runtime: runtime, resolver: resolver));

  expect(_mainPainter(tester).output, isNot(same(beforeMain)));
  expect(_overlayPainter(tester).output, same(beforeOverlay));
  expect(resolver.calls, 1);
  expect(probe.mainDispatches, 2);
  expect(probe.overlayDispatches, 0);
}

// Marquee routing proves overlay-only invalidation by comparing both layers in
// the same gesture preview scenario.
// ignore: halstead-volume
Future<void> _expectMarqueeOverlayOnly(
  WidgetTester tester,
  CanvasRuntime runtime,
  _RecordingResolver resolver,
  _LayerDispatchProbe probe,
) async {
  final beforeMain = _mainPainter(tester).output;
  final beforeOverlay = _overlayPainter(tester).output;
  final beforeResolverCalls = resolver.calls;
  probe.reset();
  _rootFor(runtime).replaceInteractionPreview(
    const CanvasMarqueePreview(rect: Rect.fromLTWH(1, 2, 3, 4)),
  );
  await tester.pump(null, EnginePhase.layout);

  expect(_mainPainter(tester).output, same(beforeMain));
  expect(_overlayPainter(tester).output, isNot(same(beforeOverlay)));
  expect(resolver.calls, beforeResolverCalls);
  expect(probe.mainDispatches, 0);
  expect(probe.overlayDispatches, 1);
  expect(_mainRenderObject(tester).debugNeedsPaint, isFalse);
  expect(_overlayRenderObject(tester).debugNeedsPaint, isTrue);
  await tester.pump();
  expect(_mainPainter(tester).output.capturedFrame.selectedMovePreview, isNull);
  expect(
    _overlayPainter(tester).output.overlayPreviewPlan.primitives,
    isNotEmpty,
  );
}

// The host deliberately couples runtime, resolver, and surface wiring because
// every fixture scenario needs the same widget boundary.
// ignore: coupling-between-object-classes
final class _SurfaceHost extends StatelessWidget {
  const _SurfaceHost({
    required this.runtime,
    required this.resolver,
    this.size = const Size(100, 100),
    this.devicePixelRatio = 1,
    this.selectionStyle = CanvasSelectionStyle.defaultStyle,
    this.gridStyle = CanvasGridStyle.defaultStyle,
  });

  final CanvasRuntime runtime;
  final CanvasResourceResolver resolver;
  final Size size;
  final double devicePixelRatio;
  final CanvasSelectionStyle selectionStyle;
  final CanvasGridStyle gridStyle;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(devicePixelRatio: devicePixelRatio),
        child: Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: CanvasSurface(
              runtime: runtime,
              resourceResolver: resolver,
              selectionStyle: selectionStyle,
              gridStyle: gridStyle,
              interactive: false,
            ),
          ),
        ),
      ),
    );
  }
}

final class _TwoRuntimeSurfaceHost extends StatelessWidget {
  const _TwoRuntimeSurfaceHost({
    required this.firstRuntime,
    required this.secondRuntime,
    required this.firstResolver,
    required this.secondResolver,
    required this.includeFirst,
  });

  final CanvasRuntime firstRuntime;
  final CanvasRuntime secondRuntime;
  final CanvasResourceResolver firstResolver;
  final CanvasResourceResolver secondResolver;
  final bool includeFirst;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          Expanded(
            child: includeFirst
                ? CanvasSurface(
                    key: const ValueKey<String>('first-runtime-surface'),
                    runtime: firstRuntime,
                    resourceResolver: firstResolver,
                    interactive: false,
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: CanvasSurface(
              key: const ValueKey<String>('second-runtime-surface'),
              runtime: secondRuntime,
              resourceResolver: secondResolver,
              interactive: false,
            ),
          ),
        ],
      ),
    );
  }
}

final class _TwoSurfaceHost extends StatelessWidget {
  const _TwoSurfaceHost({
    required this.runtime,
    required this.acceptedResolver,
    required this.rejectedResolver,
  });

  final CanvasRuntime runtime;
  final CanvasResourceResolver acceptedResolver;
  final CanvasResourceResolver? rejectedResolver;

  @override
  Widget build(BuildContext context) {
    final secondResolver = rejectedResolver;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          Expanded(
            child: CanvasSurface(
              runtime: runtime,
              resourceResolver: acceptedResolver,
              interactive: false,
            ),
          ),
          Expanded(
            child: secondResolver == null
                ? const SizedBox.shrink()
                : CanvasSurface(
                    runtime: runtime,
                    resourceResolver: secondResolver,
                    interactive: false,
                  ),
          ),
        ],
      ),
    );
  }
}

void _expectPaintHost() {
  expect(_paintHosts(), findsOneWidget);
  expect(_mainPaintHosts(), findsOneWidget);
  expect(_overlayPaintHosts(), findsOneWidget);
}

int _tokenCount(String source, String token) {
  return token.allMatches(source).length;
}

Finder _paintHosts() {
  return find.byKey(const ValueKey<String>('iwb_canvas_surface.paint_host'));
}

MainFramePainter _mainPainter(WidgetTester tester) {
  final paintHost = tester.widget<CustomPaint>(_mainPaintHosts());
  final painter = paintHost.painter;
  expect(painter, isA<MainFramePainter>());

  return painter as MainFramePainter;
}

List<MainFramePainter> _mainPainters(WidgetTester tester) {
  return [
    for (final paintHost in tester.widgetList<CustomPaint>(_mainPaintHosts()))
      if (paintHost.painter case final MainFramePainter painter) painter,
  ];
}

OverlayFramePainter _overlayPainter(WidgetTester tester) {
  final paintHost = tester.widget<CustomPaint>(_overlayPaintHosts());
  final painter = paintHost.painter;
  expect(painter, isA<OverlayFramePainter>());

  return painter as OverlayFramePainter;
}

RenderCustomPaint _mainRenderObject(WidgetTester tester) {
  return tester.renderObject<RenderCustomPaint>(_mainPaintHosts());
}

RenderCustomPaint _overlayRenderObject(WidgetTester tester) {
  return tester.renderObject<RenderCustomPaint>(_overlayPaintHosts());
}

void _paintCurrentOutputs(WidgetTester tester) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  _mainPainter(tester).paint(canvas, const Size(100, 100));
  _overlayPainter(tester).paint(canvas, const Size(100, 100));
  recorder.endRecording().dispose();
}

void _expectPaintersDoNotCallSurfaceFrameBuilders() {
  final mainPainterSource = File(
    'lib/src/surface/main_painter.dart',
  ).readAsStringSync();
  final overlayPainterSource = File(
    'lib/src/surface/overlay_painter.dart',
  ).readAsStringSync();

  for (final source in [mainPainterSource, overlayPainterSource]) {
    expect(source, isNot(contains('buildSurfaceMainFrame')));
    expect(source, isNot(contains('buildSurfaceOverlayFrame')));
  }
}

Finder _mainPaintHosts() {
  return find.byKey(
    const ValueKey<String>('iwb_canvas_surface.main_paint_host'),
  );
}

Finder _overlayPaintHosts() {
  return find.byKey(
    const ValueKey<String>('iwb_canvas_surface.overlay_paint_host'),
  );
}

int _budgetPlaceholders(WidgetTester tester) {
  return _mainPainter(tester).output.assetBindings.assets.values
      .whereType<FrameAssetPlaceholderBinding>()
      .length;
}

List<CanvasElementId> _mainRecordIds(WidgetTester tester) {
  return [
    for (final record in _mainPainter(
      tester,
    ).output.ordinaryPlan.ordinaryRecords)
      record.id,
  ];
}

RuntimeRoot _rootFor(CanvasRuntime runtime) {
  final root = canvasRuntimeFrameRootForSurface(runtime);
  if (root != null) {
    return root;
  }

  throw StateError('CanvasRuntime frame root is not attached.');
}

SurfaceResourceSession _activeSurfaceSession(CanvasRuntime runtime) {
  final session = _rootFor(runtime).activeSurfaceResourceSessionForTesting;
  if (session is SurfaceResourceSession) {
    return session;
  }

  throw StateError('CanvasRuntime has no active SurfaceResourceSession.');
}

final class _LayerDispatchProbe {
  _LayerDispatchProbe(this._tester) {
    _mainListenable = _mainPainter(_tester).outputListenable;
    _overlayListenable = _overlayPainter(_tester).outputListenable;
    _mainListenable.addListener(_handleMainDispatch);
    _overlayListenable.addListener(_handleOverlayDispatch);
  }

  final WidgetTester _tester;
  late final ValueListenable<Object?> _mainListenable;
  late final ValueListenable<Object?> _overlayListenable;
  int mainDispatches = 0;
  int overlayDispatches = 0;

  void reset() {
    mainDispatches = 0;
    overlayDispatches = 0;
  }

  void dispose() {
    _mainListenable.removeListener(_handleMainDispatch);
    _overlayListenable.removeListener(_handleOverlayDispatch);
  }

  void _handleMainDispatch() {
    mainDispatches += 1;
  }

  void _handleOverlayDispatch() {
    overlayDispatches += 1;
  }
}

final class _InlineTextSurfaceScenario {
  _InlineTextSurfaceScenario() {
    subscription = runtime.contextActionRequests.listen(requests.add);
  }

  final CanvasRuntime runtime = runtimeWithDocument(_textAndRectDocument());
  final _RecordingResolver resolver = _RecordingResolver((_) => null);
  final List<CanvasContextActionRequested> requests = [];
  late final StreamSubscription<CanvasContextActionRequested> subscription;

  Future<CanvasTextEditSession> startTextSession(WidgetTester tester) async {
    _rootFor(runtime).handleDoubleTap(position: Offset.zero, timestampMs: 1);
    await tester.pump();
    final session = runtime.textEditing.startFromContextAction(requests.single);
    requests.clear();
    if (session == null) {
      throw StateError('CanvasSurface text edit request was not admitted.');
    }

    return session;
  }

  Future<void> dispose() async {
    await subscription.cancel();
    runtime.dispose();
  }
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

CanvasDocument _textAndRectDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasTextElement(
            id: _surfaceTextId,
            text: 'surface',
            fontSize: 16,
            color: const Color(0xFF111111),
            textDirection: TextDirection.ltr,
          ),
          CanvasRectElement(
            id: _surfaceRectId,
            size: const Size(20, 20),
            transform: CanvasTransform.translation(const Offset(60, 0)),
          ),
        ],
      ),
    ],
  );
}

final _surfaceTextId = CanvasElementId('surface-text-a');
final _surfaceRectId = CanvasElementId('surface-rect-a');

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

CanvasDocument _twoImageDocument() {
  return CanvasDocument(
    resources: [
      _imageResource(),
      CanvasImageResource(
        id: CanvasResourceId('resource-b'),
        source: CanvasResourceSource.appKey('image-b'),
        mimeType: 'image/png',
        byteLength: 24,
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('image-a'),
            resourceId: CanvasResourceId('resource-a'),
            size: const Size(10, 10),
          ),
          CanvasImageElement(
            id: CanvasElementId('image-b'),
            resourceId: CanvasResourceId('resource-b'),
            size: const Size(10, 10),
            transform: CanvasTransform.translation(const Offset(20, 0)),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _twoVectorDocument() {
  return CanvasDocument(
    resources: [_vectorResource('vector-a'), _vectorResource('vector-b')],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasVectorElement(
            id: CanvasElementId('vector-a'),
            resourceId: CanvasResourceId('vector-a'),
            size: const Size(10, 10),
          ),
          CanvasVectorElement(
            id: CanvasElementId('vector-b'),
            resourceId: CanvasResourceId('vector-b'),
            size: const Size(10, 10),
            transform: CanvasTransform.translation(const Offset(20, 0)),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _vectorDocument(String resourceId) {
  return CanvasDocument(
    resources: [_vectorResource(resourceId)],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasVectorElement(
            id: CanvasElementId('$resourceId-element'),
            resourceId: CanvasResourceId(resourceId),
            size: const Size(10, 10),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _manyImageDocument(int count) {
  return CanvasDocument(
    resources: [
      for (var index = 0; index < count; index += 1)
        CanvasImageResource(
          id: CanvasResourceId('resource-$index'),
          source: CanvasResourceSource.appKey('image-$index'),
          mimeType: 'image/png',
          byteLength: 24,
        ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          for (var index = 0; index < count; index += 1)
            CanvasImageElement(
              id: CanvasElementId('image-$index'),
              resourceId: CanvasResourceId('resource-$index'),
              size: const Size(1, 1),
              transform: CanvasTransform.translation(
                Offset((index % 20).toDouble(), (index ~/ 20).toDouble()),
              ),
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

CanvasVectorResource _vectorResource(String id) {
  return CanvasVectorResource(
    id: CanvasResourceId(id),
    source: CanvasResourceSource.appKey('vector-$id'),
    byteLength: 42,
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
  _RecordingResolver(this._resolve, {this.resolvePreparedVector});

  final ui.Image? Function(CanvasImageResource resource) _resolve;
  final CanvasPreparedVector? Function(CanvasVectorResource resource)?
  resolvePreparedVector;
  int calls = 0;

  @override
  ui.Image? resolveImage(CanvasImageResource resource) {
    calls += 1;

    return _resolve(resource);
  }

  @override
  CanvasPreparedVector? resolveVector(CanvasVectorResource resource) {
    return resolvePreparedVector?.call(resource);
  }
}

CanvasRuntime runtimeWithDocument(CanvasDocument document) {
  final runtime = CanvasRuntime();
  runtime.edits.loadDocumentFromJson(encodeCanvasDocumentToJson(document));

  return runtime;
}
