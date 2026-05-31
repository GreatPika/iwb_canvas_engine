import 'dart:ui' show Offset, Rect, Size;

// This resource fixture now covers both the session boundary and the P9 asset
// binding caller, so the imports intentionally span frame and resource seams.
// ignore_for_file: number-of-imports

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/frame/captured_frame.dart';
import 'package:iwb_canvas_engine/src/frame/frame_engine.dart';
import 'package:iwb_canvas_engine/src/frame/paint_asset_binding_service.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_kernel.dart';
import 'package:iwb_canvas_engine/src/resources/resource_resolver_adapter.dart';
import 'package:iwb_canvas_engine/src/resources/surface_resource_session.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

import '../../frame/fixtures/ordinary_paint_test_support.dart';
import 'surface_resource_session_test_support.dart';

void main() {
  _testNestedResolverCallbackRejected();
  _testP9AssetBindingMutationRejected();
  _testPublicRuntimeMutationsRejected();
}

void _testNestedResolverCallbackRejected() {
  test('nested resolver callbacks are rejected by the runtime guard', () async {
    final image = await createResourceTestImage();
    final root = _runtime();
    final resolver = RecordingResourceResolver((_) {
      return root.runResolverCallback(() => image);
    });
    final session = SurfaceResourceSession(
      resolver: resolver,
      mutationGuard: root,
    );

    expect(
      () => session.resolveImage(descriptorRequest(id: 'resource-a')),
      throwsStateError,
    );
    expect(resolver.callCount, 1);
    expect(root.state.value.revisions.resourceVisual, 0);

    image.dispose();
    root.dispose();
  });
}

void _testP9AssetBindingMutationRejected() {
  test('P9 asset binding rejects public runtime mutations', () {
    final root = _runtime();
    final resolver = RecordingResourceResolver((_) {
      root.generateElementId();

      return null;
    });
    final session = SurfaceResourceSession(
      resolver: resolver,
      mutationGuard: root,
    );

    expect(
      () => _frameEngineWithImageRecord().buildMainFrameWithAssetBindings(
        inputs: _frameInputs(),
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

// Each mutation runs inside a resolver callback so the test proves the runtime
// guard blocks public side effects before document, selection, camera, ids, or
// resource-visual state can change.
// ignore: halstead-volume, source-lines-of-code
void _testPublicRuntimeMutationsRejected() {
  test('resolver callbacks cannot run public runtime mutations', () async {
    final mutations = <void Function(RuntimeRoot)>[
      (root) =>
          root.resources.markResourceDirty(CanvasResourceId('resource-a')),
      (root) => root.resources.markAllResourcesDirty(),
      (root) => root.setSelection([CanvasElementId('element-a')]),
      (root) => root.setCameraOffset(const Offset(10, 20)),
      (root) => root.generateElementId(),
      (root) => root.generateLayerId(),
      (root) => root.generateResourceId(),
      (root) => root.selection.moveSelection(const Offset(1, 1)),
      (root) => root.edits.edit((edit) {
        edit.addBackgroundElement(
          CanvasRectElement(
            id: CanvasElementId('resolver-edit-added'),
            size: const Size(1, 1),
          ),
        );
      }),
      (root) => root.edits.loadDocument(CanvasDocument()),
    ];

    expect(mutations, hasLength(10));
    for (final mutate in mutations) {
      await _expectRejectedMutation(mutate);
    }
  });
}

// This helper verifies the same rollback surface after each rejected public
// mutation so every resolver callback path is held to one side-effect contract.
// ignore: halstead-volume
Future<void> _expectRejectedMutation(
  void Function(RuntimeRoot root) mutate,
) async {
  final image = await createResourceTestImage();
  final root = _runtime();
  final actions = <CanvasActionCommitted>[];
  final subscription = root.actions.listen(actions.add);
  var attempts = 0;
  final resolver = RecordingResourceResolver((_) {
    attempts += 1;
    if (attempts == 1) {
      mutate(root);
    }

    return image;
  });
  final session = SurfaceResourceSession(
    resolver: resolver,
    mutationGuard: root,
  );

  expect(
    () => session.resolveImage(descriptorRequest(id: 'resource-a')),
    throwsStateError,
  );
  expect(resolver.callCount, 1);
  expect(
    session.resolveImage(descriptorRequest(id: 'resource-a')),
    isA<ResolvedResourceImage>(),
  );
  expect(resolver.callCount, 2);
  expect(root.state.value.revisions.document, 0);
  expect(root.state.value.revisions.resourceVisual, 0);
  expect(root.state.value.revisions.selection, 0);
  expect(root.state.value.revisions.viewCamera, 0);
  expect(root.selectedElementIds, isEmpty);
  expect(root.viewCameraOffset, Offset.zero);
  expect(root.generateElementId(), CanvasElementId('e0'));
  expect(root.generateLayerId(), CanvasLayerId('l0'));
  expect(root.generateResourceId(), CanvasResourceId('r0'));
  await Future<void>.delayed(Duration.zero);
  expect(actions, isEmpty);

  await subscription.cancel();
  image.dispose();
  root.dispose();
}

RuntimeRoot _runtime() {
  return RuntimeRoot(
    initialDocument: CanvasDocument(
      resources: [
        CanvasImageResource(
          id: CanvasResourceId('resource-a'),
          source: CanvasResourceSource.appKey('asset-a'),
        ),
      ],
      layers: [
        CanvasLayer(
          id: CanvasLayerId('layer-a'),
          elements: [
            CanvasRectElement(
              id: CanvasElementId('element-a'),
              size: const Size(1, 1),
            ),
          ],
        ),
      ],
    ),
    config: const CanvasRuntimeConfig(),
  );
}

FrameEngine _frameEngineWithImageRecord() {
  final frameFacts = frameFactsPort(
    elements: [
      imageFacts(
        'image-a',
        orderToken: 1,
        resourceId: CanvasResourceId('resource-a'),
      ),
    ],
    resourceDescriptors: [
      FrameResourceDescriptorFacts(
        id: CanvasResourceId('resource-a'),
        appKey: 'asset-a',
        mimeType: 'image/png',
        contentHash: null,
        byteLength: null,
        resourceRevision: 1,
        metadata: const CanvasMetadata.empty(),
      ),
    ],
  );

  return FrameEngine(
    frameFacts: frameFacts,
    selectionFacts: TestSelectionFactsPort.empty(),
    spatialKernel: SpatialKernel()..rebuild(frameFacts),
  );
}

FrameCaptureInputs _frameInputs() {
  return const FrameCaptureInputs(
    viewportWorldBounds: Rect.fromLTWH(0, 0, 100, 100),
    devicePixelRatio: 1,
    selectionStyle: CanvasSelectionStyle.defaultStyle,
    gridStyle: CanvasGridStyle.defaultStyle,
    preview: CanvasNoPreview(),
    previewRevision: 0,
  );
}
