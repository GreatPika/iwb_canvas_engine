import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/resources/surface_resource_session.dart';
import "../../support/runtime_root_with_document.dart";

import 'surface_resource_session_test_support.dart';

void main() {
  _testTargetDirtyActiveSessionInvalidation();
}

// The target dirty proof keeps runtime publication and direct session resolves
// in one sequence so the cache eviction order stays observable.
// ignore: halstead-volume
void _testTargetDirtyActiveSessionInvalidation() {
  test('target dirty evicts only the matching active session entry', () async {
    final image = await createResourceTestImage();
    final resolver = RecordingResourceResolver((_) => image);
    final effects = <List<CommitDeliveryEffect>>[];
    final root = runtimeRootWithDocument(
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
    root.attachResourceSessionInvalidationSink(session);

    session.resolveImage(descriptorRequest(id: 'resource-a'));
    session.resolveImage(descriptorRequest(id: 'resource-b'));
    session.resolveImage(descriptorRequest(id: 'resource-a'));
    session.resolveImage(descriptorRequest(id: 'resource-b'));
    expect(resolver.callCount, 2);

    root.resources.markResourceDirty(CanvasResourceId('resource-a'));
    expect(root.state.value.revisions.resourceVisual, 1);
    _expectTargetDirtyEffects(effects.single);

    session.resolveImage(descriptorRequest(id: 'resource-a'));
    session.resolveImage(descriptorRequest(id: 'resource-b'));
    expect(resolver.callCount, 3);
    expect(resolver.resources.map((resource) => resource.id), [
      CanvasResourceId('resource-a'),
      CanvasResourceId('resource-b'),
      CanvasResourceId('resource-a'),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(actions, isEmpty);

    await subscription.cancel();
    image.dispose();
    root.dispose();
  });
}

void _expectTargetDirtyEffects(List<CommitDeliveryEffect> effects) {
  final resourceEffect = effects.whereType<ResourceDeliveryEffect>().single;
  expect(resourceEffect.touchedSet.resourceVisualChangedIds, {
    CanvasResourceId('resource-a'),
  });
  expect(resourceEffect.touchedSet.allResourceVisualsChanged, isFalse);
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
