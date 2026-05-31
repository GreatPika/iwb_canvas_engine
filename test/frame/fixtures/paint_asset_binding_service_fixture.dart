import 'dart:ui';

// The asset-binding fixture imports the frame model, resource session, resolver
// adapter, and public descriptor payloads together to prove the exact seam.
// ignore_for_file: number-of-imports

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_document.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_ids.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_metadata.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_preview.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_runtime.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_surface_styles.dart';
import 'package:iwb_canvas_engine/src/frame/captured_frame.dart';
import 'package:iwb_canvas_engine/src/frame/frame_engine.dart';
import 'package:iwb_canvas_engine/src/frame/frame_paint_output.dart';
import 'package:iwb_canvas_engine/src/frame/paint_asset_binding_service.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_kernel.dart';
import 'package:iwb_canvas_engine/src/resources/resource_resolver_adapter.dart';
import 'package:iwb_canvas_engine/src/resources/surface_resource_session.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

import '../../resources/fixtures/surface_resource_session_test_support.dart';
import 'ordinary_paint_test_support.dart';

void main() {
  _testFrameEngineAssetBinding();
  _testReentrantResolverRejectedThroughAssetBinding();
}

void _testReentrantResolverRejectedThroughAssetBinding() {
  test('asset binding rejects public runtime mutations from resolver', () {
    final root = RuntimeRoot(
      initialDocument: CanvasDocument(),
      config: const CanvasRuntimeConfig(),
    );
    final resolver = RecordingResourceResolver((_) {
      root.generateElementId();

      return null;
    });
    final session = SurfaceResourceSession(
      resolver: resolver,
      mutationGuard: root,
    );

    expect(
      () => _engineForImageRecords().buildMainFrameWithAssetBindings(
        inputs: _inputs(),
        viewCameraBucket: 0,
        bindAssets: ({required frame, required records}) =>
            const PaintAssetBindingService().bind(
              frame: frame,
              records: records,
              session: session,
            ),
      ),
      throwsStateError,
    );
    expect(root.state.value.revisions.document, 0);
    expect(root.generateElementId(), CanvasElementId('e0'));
    root.dispose();
  });
}

void _testFrameEngineAssetBinding() {
  test(
    'frame engine asset binding resolves descriptor snapshots through session',
    () async {
      final image = await createResourceTestImage();
      addTearDown(image.dispose);
      final resolver = _imageResolver(image);
      final session = _warmedSession(resolver);
      final engine = _engineForImageRecords();
      final resourceFree = engine.buildResourceFreeMainFrame(
        inputs: _inputs(),
        viewCameraBucket: 0,
      );

      final output = engine.buildMainFrameWithAssetBindings(
        inputs: _inputs(),
        viewCameraBucket: 0,
        bindAssets: ({required frame, required records}) =>
            const PaintAssetBindingService().bind(
              frame: frame,
              records: records,
              session: session,
            ),
      );

      _expectResolvedBindings(output.assetBindings);
      expect(resolver.resources.last.id, CanvasResourceId('image-a'));
      expect(output.ordinaryPlan, same(resourceFree.ordinaryPlan));
      expect(
        output
            .selectedMoveSupplementPlan
            .probe
            .ordinaryCacheWritesDuringSupplement,
        0,
      );
    },
  );
}

RecordingResourceResolver _imageResolver(Image image) {
  return RecordingResourceResolver((_) => image);
}

SurfaceResourceSession _warmedSession(RecordingResourceResolver resolver) {
  final session = SurfaceResourceSession(
    resolver: resolver,
    mutationGuard: CountingResolverMutationGuard(),
  );
  for (var index = 0; index < kMaxSyncResourceResolverCallsPerFrame; index++) {
    session.resolveImage(descriptorRequest(id: 'warm-$index'));
  }

  return session;
}

void _expectResolvedBindings(FrameAssetBindings bindings) {
  expect(
    bindings.images[CanvasResourceId('image-a')],
    isA<ResolvedResourceImage>(),
  );
  expect(
    bindings.images[CanvasResourceId('missing')],
    isA<MissingDescriptorResourceImagePlaceholder>(),
  );
}

FrameEngine _engineForImageRecords() {
  final frameFacts = _frameFactsWithImageRecords();

  return FrameEngine(
    frameFacts: frameFacts,
    selectionFacts: TestSelectionFactsPort.empty(),
    spatialKernel: SpatialKernel()..rebuild(frameFacts),
  );
}

TestFrameFactsPort _frameFactsWithImageRecords() {
  final imageA = CanvasResourceId('image-a');

  return frameFactsPort(
    elements: [
      imageFacts('image-a', orderToken: 2, resourceId: imageA),
      imageFacts(
        'missing',
        orderToken: 1,
        resourceId: CanvasResourceId('missing'),
      ),
    ],
    resourceDescriptors: [
      FrameResourceDescriptorFacts(
        id: imageA,
        appKey: 'asset://image-a',
        mimeType: 'image/png',
        contentHash: 'hash-a',
        byteLength: 4,
        resourceRevision: 12,
        metadata: const CanvasMetadata.empty(),
      ),
    ],
  );
}

FrameCaptureInputs _inputs() {
  return const FrameCaptureInputs(
    viewportWorldBounds: Rect.fromLTWH(0, 0, 100, 100),
    devicePixelRatio: 1,
    selectionStyle: CanvasSelectionStyle.defaultStyle,
    gridStyle: CanvasGridStyle.defaultStyle,
    preview: CanvasNoPreview(),
    previewRevision: 0,
  );
}
