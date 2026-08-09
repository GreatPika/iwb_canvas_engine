import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/resources/surface_resource_session.dart';
import "../../support/runtime_root_with_committed_document_seed.dart";

import 'surface_resource_session_test_support.dart';

void main() {
  _testMarkAllDirtyActiveSessionInvalidation();
}

// Mark-all dirty must prove all cached entries clear while unrelated runtime
// revisions and action delivery remain unchanged in the same scenario.
// ignore: halstead-volume
void _testMarkAllDirtyActiveSessionInvalidation() {
  test('mark-all dirty clears every active session cache entry', () async {
    final image = await createResourceTestImage();
    final resolver = RecordingResourceResolver((_) => image);
    final effects = <List<CommitDeliveryEffect>>[];
    final root = runtimeRootWithCommittedDocumentSeed(
      _document(),
      config: const CanvasRuntimeConfig(),
      commitEffectObserver: effects.add,
    );
    final session = SurfaceResourceSession(
      resolver: resolver,
      mutationGuard: root,
    );
    final actions = <CanvasActionCommitted>[];
    final subscription = root.actions.listen(actions.add);
    root.attachResourceSessionReleaseSink(session);

    session.resolveResource(descriptorRequest(id: 'resource-a'));
    session.resolveResource(descriptorRequest(id: 'resource-b'));
    expect(resolver.callCount, 2);

    root.resources.markAllResourcesDirty();
    expect(root.state.value.revisions.resourceVisual, 1);
    _expectMarkAllDirtyEffects(effects.single);
    expect(root.state.value.revisions.document, 0);
    expect(root.state.value.revisions.selection, 0);
    expect(root.state.value.revisions.preview, 0);
    expect(root.state.value.revisions.viewCamera, 0);
    expect(root.state.value.revisions.interaction, 0);
    expect(root.state.value.revisions.epoch, 0);

    session.resolveResource(descriptorRequest(id: 'resource-a'));
    session.resolveResource(descriptorRequest(id: 'resource-b'));
    expect(resolver.callCount, 4);
    await Future<void>.delayed(Duration.zero);
    expect(actions, isEmpty);

    await subscription.cancel();
    image.dispose();
    root.dispose();
  });
}

void _expectMarkAllDirtyEffects(List<CommitDeliveryEffect> effects) {
  final resourceEffect = effects.whereType<ResourceDeliveryEffect>().single;
  expect(resourceEffect.touchedSet.resourceVisualChangedIds, isEmpty);
  expect(resourceEffect.touchedSet.allResourceVisualsChanged, isTrue);
  final repaint = effects.whereType<RepaintDeliveryEffect>().single;
  expect(repaint.mainCanvas, isTrue);
  expect(repaint.overlayCanvas, isFalse);
  expect(effects.whereType<PublicStateDeliveryEffect>(), hasLength(1));
}

CanvasDocument _document() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('resource-a'),
        source: CanvasResourceSource.appKey('asset-a'),
      ),
      CanvasImageResource(
        id: CanvasResourceId('resource-b'),
        source: CanvasResourceSource.appKey('asset-b'),
      ),
    ],
  );
}
