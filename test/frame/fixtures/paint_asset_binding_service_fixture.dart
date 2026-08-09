import 'dart:ui';
import "../../support/runtime_root_with_committed_document_seed.dart";

// The asset-binding fixture imports the frame model, resource session, resolver
// adapter, and public descriptor payloads together to prove the exact seam.
// ignore_for_file: number-of-imports

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/selection_facts_port.dart';
import 'package:iwb_canvas_engine/src/diagnostics/diagnostics_hub.dart';
import 'package:iwb_canvas_engine/src/frame/captured_frame.dart';
import 'package:iwb_canvas_engine/src/frame/frame_engine.dart';
import 'package:iwb_canvas_engine/src/frame/frame_paint_output.dart';
import 'package:iwb_canvas_engine/src/frame/paint_asset_binding_service.dart';
import 'package:iwb_canvas_engine/src/frame/render_element_record.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_kernel.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_result.dart';
import 'package:iwb_canvas_engine/src/resources/resource_resolver_adapter.dart';
import 'package:iwb_canvas_engine/src/resources/surface_resource_session.dart';

import '../../resources/fixtures/surface_resource_session_test_support.dart';
import '../../preparation/fixtures/vector_preparation_fixture.dart';
import 'ordinary_paint_test_support.dart';

void main() {
  _testFrameEngineAssetBinding();
  _testFrameBindingContinuesAfterResolverException();
  _testReentrantResolverRejectedThroughAssetBinding();
  _testNestedResolverRejectedThroughAssetBinding();
  _testVectorFrameBindingUsesPreparedAsset();
  _testVectorFrameBindingDoesNotAllocateDiagnostics();
  _testFrameEngineCapturesVectorRecord();
}

void _testVectorFrameBindingDoesNotAllocateDiagnostics() {
  test('vector frame binding does not allocate diagnostic records', () {
    DiagnosticRecord.allocations.reset();
    final resourceId = CanvasResourceId('vector-non-hub');
    final bindings = const PaintAssetBindingService().bind(
      frame: _vectorFrame(resourceId),
      records: [_vectorRecord(resourceId)],
      session: SurfaceResourceSession(
        resolver: null,
        mutationGuard: CountingResolverMutationGuard(),
      ),
    );

    expect(
      bindings.assets[resourceId],
      isA<FrameAssetPlaceholderBinding>(),
    );
    expect(DiagnosticRecord.allocations.count, 0);
  });
}

void _testFrameEngineCapturesVectorRecord() {
  test('frame engine captures a vector record before resource binding', () {
    final resourceId = CanvasResourceId('vector-a');
    final facts = frameFactsPort(
      elements: [_vectorFacts(resourceId)],
      resourceDescriptors: [
        FrameVectorResourceDescriptorFacts(
          id: resourceId,
          appKey: 'vector-a',
          contentHash: 'sha256:vector-a',
          byteLength: 42,
          resourceRevision: 12,
          metadata: const CanvasMetadata.empty(),
        ),
      ],
    );
    final output = FrameEngine(
      frameFacts: facts,
      selectionFacts: TestSelectionFactsPort.empty(),
      spatialKernel: SpatialKernel()..rebuild(facts),
    ).buildResourceFreeMainFrame(inputs: _inputs(), viewCameraBucket: 0);

    final record = output.ordinaryPlan.ordinaryRecords.single;
    expect(record.family, RenderElementFamily.vector);
    expect(record.row, isA<VectorRenderRow>());
  });
}

FrameElementFacts _vectorFacts(CanvasResourceId resourceId) {
  return FrameElementFacts(
    id: CanvasElementId('vector-a'),
    kind: CanvasElementKind.vector,
    revision: 1,
    generation: 1,
    orderToken: 1,
    locationKind: FrameElementLocationKind.content,
    transform: CanvasTransform.identity,
    opacity: 1,
    hitPadding: 0,
    isVisible: true,
    isSelectable: true,
    isLocked: false,
    isDeletable: true,
    isTransformable: true,
    metadata: const CanvasMetadata.empty(),
    resourceId: resourceId,
    size: const Size(30, 40),
  );
}

void _testVectorFrameBindingUsesPreparedAsset() {
  test(
    'asset binding resolves an immutable vector descriptor synchronously',
    () async {
      final prepared = await prepareVector(basicVectorBytes());
      final resourceId = CanvasResourceId('vector-a');
      final resolver = RecordingResourceResolver(
        (_) => null,
        resolvePreparedVector: (_) => prepared,
      );
      final session = SurfaceResourceSession(
        resolver: resolver,
        mutationGuard: CountingResolverMutationGuard(),
      );
      final bindings = const PaintAssetBindingService().bind(
        frame: _vectorFrame(resourceId),
        records: [_vectorRecord(resourceId)],
        session: session,
      );

      final asset = bindings.assets[resourceId] as FrameVectorAssetBinding;
      expect(asset.prepared, same(prepared));
      expect(resolver.vectorCallCount, 1);

      prepared.dispose();
    },
  );
}

CapturedFrameSnapshot _vectorFrame(CanvasResourceId resourceId) {
  return CapturedFrameSnapshot(
    revisions: revisionsFor(resource: 12),
    capturedHandles: const [],
    elements: const [],
    resourceDescriptors: [
      FrameVectorResourceDescriptorFacts(
        id: resourceId,
        appKey: 'vector-a',
        contentHash: 'sha256:vector-a',
        byteLength: 42,
        resourceRevision: 12,
        metadata: const CanvasMetadata.empty(),
      ),
    ],
    background: const CanvasBackground(),
    selection: SelectionFacts(
      selectedElementIds: const {},
      selectionRevision: 0,
    ),
    inputs: _inputs(),
    spatialPaintResult: const SpatialCandidatesResult(orderedCandidates: []),
    spatialPaintCandidates: const [],
  );
}

RenderElementRecord _vectorRecord(CanvasResourceId resourceId) {
  return RenderElementRecord(
    id: CanvasElementId('vector-a'),
    family: RenderElementFamily.vector,
    generation: 1,
    orderToken: 1,
    transform: CanvasTransform.identity,
    opacity: 1,
    primitiveAlpha: 255,
    paintBoundsLocal: const Rect.fromLTWH(0, 0, 30, 40),
    paintBoundsWorld: const Rect.fromLTWH(0, 0, 30, 40),
    hitBoundsWorld: const Rect.fromLTWH(0, 0, 30, 40),
    resourceId: resourceId,
    row: VectorRenderRow(
      resourceId: resourceId,
      size: const Size(30, 40),
      naturalSize: null,
    ),
  );
}

void _testFrameBindingContinuesAfterResolverException() {
  test('asset binding continues after ordinary resolver exception', () async {
    final image = await createResourceTestImage();
    final throwingId = CanvasResourceId('throwing-image');
    final healthyId = CanvasResourceId('healthy-image');
    final resolver = RecordingResourceResolver((resource) {
      if (resource.id == throwingId) {
        throw StateError('ordinary app resolver failure');
      }

      return image;
    });
    final bindings = _bindImageAssets(
      engine: _engineForExceptionContinuationRecords(),
      session: SurfaceResourceSession(
        resolver: resolver,
        mutationGuard: CountingResolverMutationGuard(),
      ),
    );

    expect(
      bindings.assets[throwingId],
      isA<FrameAssetPlaceholderBinding>(),
    );
    expect(
      (bindings.assets[healthyId] as FrameImageAssetBinding).image,
      same(image),
    );
    expect(bindings.assets.keys, containsAll([throwingId, healthyId]));
    expect(resolver.callCount, 2);

    image.dispose();
  });
}

void _testReentrantResolverRejectedThroughAssetBinding() {
  test('asset binding rejects public runtime mutations from resolver', () {
    final root = runtimeRootWithCommittedDocumentSeed(
      CanvasDocument(),
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

void _testNestedResolverRejectedThroughAssetBinding() {
  test('asset binding rejects nested resolver callbacks', () async {
    final image = await createResourceTestImage();
    final root = runtimeRootWithCommittedDocumentSeed(
      CanvasDocument(),
      config: const CanvasRuntimeConfig(),
    );
    final resolver = RecordingResourceResolver((_) {
      return root.runResolverCallback(() => image);
    });

    expect(
      () => _bindImageAssets(
        engine: _engineForImageRecords(),
        session: SurfaceResourceSession(
          resolver: resolver,
          mutationGuard: root,
        ),
      ),
      throwsStateError,
    );
    expect(root.state.value.revisions.resourceVisual, 0);
    expect(resolver.callCount, 1);

    image.dispose();
    root.dispose();
  });
}

void _testFrameEngineAssetBinding() {
  test(
    'frame engine asset binding resolves descriptor snapshots through session',
    () async {
      final scenario = await _buildAssetBindingScenario();
      addTearDown(scenario.image.dispose);

      expect(scenario.output.assetBindings.assets, isNotEmpty);
      _expectResolvedBindings(scenario.output.assetBindings);
      _expectOrdinaryPlanUnchangedByAssetBinding(scenario);
      _expectNoOrdinaryCacheWritesDuringSupplement(scenario.output);
    },
  );
}

FrameAssetBindings _bindImageAssets({
  required FrameEngine engine,
  required SurfaceResourceSession session,
}) {
  final resourceFree = engine.buildResourceFreeMainFrame(
    inputs: _inputs(),
    viewCameraBucket: 0,
  );

  return const PaintAssetBindingService().bind(
    frame: resourceFree.capturedFrame.snapshot,
    records: resourceFree.ordinaryPlan.ordinaryRecords,
    session: session,
  );
}

Future<_AssetBindingScenario> _buildAssetBindingScenario() async {
  final image = await createResourceTestImage();
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

  return _AssetBindingScenario(
    image: image,
    resolver: resolver,
    resourceFree: resourceFree,
    output: output,
  );
}

void _expectOrdinaryPlanUnchangedByAssetBinding(
  _AssetBindingScenario scenario,
) {
  expect(scenario.resolver.resources.last.id, CanvasResourceId('image-a'));
  expect(
    scenario.output.ordinaryPlan.key,
    scenario.resourceFree.ordinaryPlan.key,
  );
  expect(
    scenario.output.ordinaryPlan.ordinaryRecords.map((record) => record.id),
    scenario.resourceFree.ordinaryPlan.ordinaryRecords.map(
      (record) => record.id,
    ),
  );
}

void _expectNoOrdinaryCacheWritesDuringSupplement(MainFramePaintOutput output) {
  expect(
    output.selectedMoveSupplementPlan.probe.ordinaryCacheWritesDuringSupplement,
    0,
  );
}

RecordingResourceResolver _imageResolver(Image image) {
  return RecordingResourceResolver((_) => image);
}

final class _AssetBindingScenario {
  const _AssetBindingScenario({
    required this.image,
    required this.resolver,
    required this.resourceFree,
    required this.output,
  });

  final Image image;
  final RecordingResourceResolver resolver;
  final MainFramePaintOutput resourceFree;
  final MainFramePaintOutput output;
}

SurfaceResourceSession _warmedSession(RecordingResourceResolver resolver) {
  final session = SurfaceResourceSession(
    resolver: resolver,
    mutationGuard: CountingResolverMutationGuard(),
  );
  for (var index = 0; index < kMaxSyncResourceResolverCallsPerFrame; index++) {
    session.resolveResource(descriptorRequest(id: 'warm-$index'));
  }

  return session;
}

void _expectResolvedBindings(FrameAssetBindings bindings) {
  expect(
    bindings.assets[CanvasResourceId('image-a')],
    isA<FrameImageAssetBinding>(),
  );
  expect(
    bindings.assets[CanvasResourceId('missing')],
    isA<FrameAssetPlaceholderBinding>(),
  );
}

FrameEngine _engineForExceptionContinuationRecords() {
  final throwingId = CanvasResourceId('throwing-image');
  final healthyId = CanvasResourceId('healthy-image');
  final frameFacts = frameFactsPort(
    elements: [
      imageFacts('throwing-image', orderToken: 1, resourceId: throwingId),
      imageFacts('healthy-image', orderToken: 2, resourceId: healthyId),
    ],
    resourceDescriptors: [
      _resourceDescriptor(throwingId, appKey: 'asset://throwing-image'),
      _resourceDescriptor(healthyId, appKey: 'asset://healthy-image'),
    ],
  );

  return FrameEngine(
    frameFacts: frameFacts,
    selectionFacts: TestSelectionFactsPort.empty(),
    spatialKernel: SpatialKernel()..rebuild(frameFacts),
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
      _resourceDescriptor(imageA, appKey: 'asset://image-a'),
    ],
  );
}

FrameResourceDescriptorFacts _resourceDescriptor(
  CanvasResourceId id, {
  required String appKey,
}) {
  return FrameImageResourceDescriptorFacts(
    id: id,
    appKey: appKey,
    mimeType: 'image/png',
    contentHash: 'hash-a',
    byteLength: 4,
    resourceRevision: 12,
    metadata: const CanvasMetadata.empty(),
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
