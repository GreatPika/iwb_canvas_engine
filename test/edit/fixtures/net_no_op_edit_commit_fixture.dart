import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/document_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

import '../../support/runtime_root_with_committed_document_seed.dart';

void main() {
  test(
    'sparse compensating field edits commit as delivery-silent no-ops',
    () => expectLater(_sparseCompensatingFieldsAreSilent(), completes),
  );
  test(
    'sparse compensating element edits commit as delivery-silent no-op',
    () => expectLater(_sparseCompensatingElementIsSilent(), completes),
  );
  test(
    'sparse partial compensation advances only accepted final families',
    () => expectLater(_sparsePartialCompensationUsesFinalFamilies(), completes),
  );
  test(
    'sparse partial compensation restores unchanged row revisions',
    () => expectLater(
      _sparsePartialCompensationRestoresRowRevisions(),
      completes,
    ),
  );
  test(
    'sparse implicit re-add publishes content order change',
    () => expectLater(_sparseImplicitReAddPublishesContentOrder(), completes),
  );
  test(
    'sparse add then remove commit is delivery-silent no-op',
    () => expectLater(_sparseAddRemoveIsSilent(), completes),
  );
  test(
    'sparse resource compensation commit is delivery-silent no-op',
    () => expectLater(_sparseResourceCompensationIsSilent(), completes),
  );
  test(
    'materialized fallback compensation commits as delivery-silent no-op',
    () => expectLater(_materializedCompensationIsSilent(), completes),
  );
}

Future<void> _sparseCompensatingFieldsAreSilent() async {
  await _expectSilentNetNoOpCommit(
    mutate: (edit) {
      edit.setBackgroundColor(const Color(0xFF112233));
      edit.setBackgroundColor(const Color(0xFFFFFFFF));
    },
  );
  await _expectSilentNetNoOpCommit(
    mutate: (edit) {
      edit.setPalette(_alternatePalette());
      edit.setPalette(const CanvasPalette.defaults());
    },
  );
  await _expectSilentNetNoOpCommit(
    mutate: (edit) {
      edit.setCameraOffset(const Offset(4, 5));
      edit.setCameraOffset(Offset.zero);
    },
  );
}

Future<void> _sparseAddRemoveIsSilent() {
  return _expectSilentNetNoOpCommit(
    mutate: (edit) {
      edit.addElement(_rect('temporary'), layerId: CanvasLayerId('layer-1'));
      edit.removeElement(CanvasElementId('temporary'));
    },
  );
}

Future<void> _sparseCompensatingElementIsSilent() {
  return _expectSilentNetNoOpCommit(
    mutate: (edit) {
      edit.updateElement(
        CanvasRectElementUpdate(
          id: CanvasElementId('rect-1'),
          fillColor: const CanvasFieldSet(Color(0xFF112233)),
        ),
      );
      edit.updateElement(
        CanvasRectElementUpdate(
          id: CanvasElementId('rect-1'),
          fillColor: const CanvasFieldClear<Color>(),
        ),
      );
    },
  );
}

Future<void> _sparsePartialCompensationUsesFinalFamilies() async {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final root = runtimeRootWithCommittedDocumentSeed(
    _baseDocument(),
    config: const CanvasRuntimeConfig(
      deletionCommitResolver: _acceptDeletionCommit,
    ),
    commitEffectObserver: (effects) => effectBatches.add(effects),
  );
  final beforeFrameRevisions = root.frameRevisions;

  root.edits.edit((edit) {
    edit.setGrid(CanvasGrid(cellSize: 24));
    edit.setGrid(CanvasGrid());
    edit.setBackgroundColor(const Color(0xFF112233));
  });
  await Future<void>.delayed(Duration.zero);

  expect(
    root.frameRevisions.backgroundRevision,
    beforeFrameRevisions.backgroundRevision + 1,
  );
  expect(root.frameRevisions.gridRevision, beforeFrameRevisions.gridRevision);
  expect(root.background.color, const Color(0xFF112233));
  expect(effectBatches, hasLength(1));
  expect(effectBatches.single.whereType<RepaintDeliveryEffect>(), hasLength(1));
  root.dispose();
}

Future<void> _sparsePartialCompensationRestoresRowRevisions() async {
  final root = runtimeRootWithCommittedDocumentSeed(
    _baseDocument(),
    config: const CanvasRuntimeConfig(
      deletionCommitResolver: _acceptDeletionCommit,
    ),
  );
  final before = _RowRevisionProbe.capture(root);

  _applyCompensatedRowRevisionEdit(root);
  await Future<void>.delayed(Duration.zero);

  before.expectOnlyBackgroundAccepted(root);
  root.dispose();
}

Future<void> _sparseImplicitReAddPublishesContentOrder() async {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final root = runtimeRootWithCommittedDocumentSeed(
    _twoElementDocument(),
    config: const CanvasRuntimeConfig(
      deletionCommitResolver: _acceptDeletionCommit,
    ),
    commitEffectObserver: (effects) => effectBatches.add(effects),
  );
  final beforeFrameRevisions = root.frameRevisions;

  _applyImplicitReAdd(root);
  await Future<void>.delayed(Duration.zero);

  _expectImplicitReAddAccepted(
    root: root,
    beforeFrameRevisions: beforeFrameRevisions,
    effectBatches: effectBatches,
  );
  root.dispose();
}

void _applyCompensatedRowRevisionEdit(RuntimeRoot root) {
  root.edits.edit((edit) {
    edit.updateElement(
      CanvasRectElementUpdate(
        id: CanvasElementId('rect-1'),
        fillColor: const CanvasFieldSet(Color(0xFF112233)),
      ),
    );
    edit.updateElement(
      CanvasRectElementUpdate(
        id: CanvasElementId('rect-1'),
        fillColor: const CanvasFieldClear<Color>(),
      ),
    );
    edit.upsertResource(_resource('resource-1', appKey: 'resource-1-next'));
    edit.upsertResource(_resource('resource-1'));
    edit.setBackgroundColor(const Color(0xFF445566));
  });
}

void _applyImplicitReAdd(RuntimeRoot root) {
  root.edits.edit((edit) {
    edit.removeElement(CanvasElementId('rect-1'));
    edit.addElement(_rect('rect-1'));
  });
}

void _expectImplicitReAddAccepted({
  required RuntimeRoot root,
  required FrameRevisionFacts beforeFrameRevisions,
  required List<List<CommitDeliveryEffect>> effectBatches,
}) {
  expect(
    root.frameRevisions.documentRevision,
    beforeFrameRevisions.documentRevision + 1,
  );
  expect(
    root.frameRevisions.structuralRevision,
    beforeFrameRevisions.structuralRevision + 1,
  );
  expect(
    root.readDocument().layers.single.elements.map((element) => element.id),
    [CanvasElementId('rect-2'), CanvasElementId('rect-1')],
  );
  expect(effectBatches, hasLength(1));
  expect(effectBatches.single.whereType<SpatialDeliveryEffect>(), hasLength(1));
}

Future<void> _sparseResourceCompensationIsSilent() {
  return _expectSilentNetNoOpCommit(
    mutate: (edit) {
      edit.upsertResource(_resource('resource-1', appKey: 'resource-1-next'));
      edit.upsertResource(_resource('resource-1'));
    },
  );
}

Future<void> _materializedCompensationIsSilent() {
  return _expectSilentNetNoOpCommit(
    expectedProjectionBuildDelta: 1,
    mutate: (edit) {
      edit.readDraftDocument();
      edit.setBackgroundColor(const Color(0xFF112233));
      edit.setBackgroundColor(const Color(0xFFFFFFFF));
      edit.upsertResource(_resource('resource-1', appKey: 'resource-1-next'));
      edit.upsertResource(_resource('resource-1'));
    },
  );
}

Future<void> _expectSilentNetNoOpCommit({
  required void Function(CanvasEdit edit) mutate,
  int expectedProjectionBuildDelta = 0,
}) async {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final root = runtimeRootWithCommittedDocumentSeed(
    _baseDocument(),
    config: const CanvasRuntimeConfig(
      deletionCommitResolver: _acceptDeletionCommit,
    ),
    commitEffectObserver: (effects) => effectBatches.add(effects),
  );
  final probe = _NetNoOpProbe(root: root, effectBatches: effectBatches);

  root.edits.edit(mutate);
  await Future<void>.delayed(Duration.zero);

  probe.expectSilent(
    expectedProjectionBuildDelta: expectedProjectionBuildDelta,
  );
  await probe.dispose();
}

final class _NetNoOpProbe {
  _NetNoOpProbe({required this.root, required this.effectBatches})
    : beforeState = root.state.value,
      beforeDocumentFacts = root.documentFacts,
      beforeFrameRevisions = root.frameRevisions,
      beforeProjectionBuilds = root.projectionBuildCount {
    subscription = root.actions.listen(actions.add);
    root.state.addListener(_recordState);
  }

  final RuntimeRoot root;
  final List<List<CommitDeliveryEffect>> effectBatches;
  final CanvasRuntimeState beforeState;
  final DocumentFacts beforeDocumentFacts;
  final FrameRevisionFacts beforeFrameRevisions;
  final int beforeProjectionBuilds;
  final List<CanvasRuntimeState> notifications = [];
  final List<CanvasActionCommitted> actions = [];
  late final StreamSubscription<CanvasActionCommitted> subscription;

  void expectSilent({required int expectedProjectionBuildDelta}) {
    _expectNoPublicStateChange(root, beforeState);
    _expectNoDocumentFactChange(root, beforeDocumentFacts);
    _expectNoFrameRevisionChange(root, beforeFrameRevisions);
    expect(
      root.projectionBuildCount,
      beforeProjectionBuilds + expectedProjectionBuildDelta,
    );
    expect(notifications, isEmpty);
    expect(actions, isEmpty);
    expect(effectBatches, isEmpty);
  }

  Future<void> dispose() {
    root.state.removeListener(_recordState);

    return subscription.cancel();
  }

  void _recordState() {
    notifications.add(root.state.value);
  }
}

final class _RowRevisionProbe {
  const _RowRevisionProbe({
    required this.elementRevision,
    required this.resourceRevision,
    required this.frameRevisions,
  });

  factory _RowRevisionProbe.capture(RuntimeRoot root) {
    return _RowRevisionProbe(
      elementRevision: _documentElementRevision(root, 'rect-1'),
      resourceRevision: root
          .resourceDescriptor(CanvasResourceId('resource-1'))
          ?.resourceRevision,
      frameRevisions: root.frameRevisions,
    );
  }

  final int? elementRevision;
  final int? resourceRevision;
  final FrameRevisionFacts frameRevisions;

  void expectOnlyBackgroundAccepted(RuntimeRoot root) {
    expect(root.background.color, const Color(0xFF445566));
    expect(
      root.frameRevisions.backgroundRevision,
      frameRevisions.backgroundRevision + 1,
    );
    expect(
      root.frameRevisions.elementVisualRevision,
      frameRevisions.elementVisualRevision,
    );
    expect(
      root.frameRevisions.resourceRevision,
      frameRevisions.resourceRevision,
    );
    expect(_documentElementRevision(root, 'rect-1'), elementRevision);
    expect(
      root.resourceDescriptor(CanvasResourceId('resource-1'))?.resourceRevision,
      resourceRevision,
    );
  }
}

void _expectNoPublicStateChange(
  RuntimeRoot root,
  CanvasRuntimeState beforeState,
) {
  expect(root.state.value, beforeState);
}

void _expectNoDocumentFactChange(
  RuntimeRoot root,
  DocumentFacts beforeDocumentFacts,
) {
  expect(
    root.documentFacts.documentRevision,
    beforeDocumentFacts.documentRevision,
  );
  expect(
    root.documentFacts.structuralRevision,
    beforeDocumentFacts.structuralRevision,
  );
  expect(root.documentFacts.elementCount, beforeDocumentFacts.elementCount);
  expect(root.documentFacts.layerCount, beforeDocumentFacts.layerCount);
  expect(root.documentFacts.resourceCount, beforeDocumentFacts.resourceCount);
}

void _expectNoFrameRevisionChange(
  RuntimeRoot root,
  FrameRevisionFacts beforeFrameRevisions,
) {
  expect(
    root.frameRevisions.documentRevision,
    beforeFrameRevisions.documentRevision,
  );
  expect(
    root.frameRevisions.structuralRevision,
    beforeFrameRevisions.structuralRevision,
  );
  expect(
    root.frameRevisions.boundsRevision,
    beforeFrameRevisions.boundsRevision,
  );
  expect(
    root.frameRevisions.elementVisualRevision,
    beforeFrameRevisions.elementVisualRevision,
  );
  expect(
    root.frameRevisions.backgroundRevision,
    beforeFrameRevisions.backgroundRevision,
  );
  expect(root.frameRevisions.gridRevision, beforeFrameRevisions.gridRevision);
  expect(
    root.frameRevisions.resourceRevision,
    beforeFrameRevisions.resourceRevision,
  );
}

CanvasDocument _baseDocument() {
  return CanvasDocument(
    resources: [_resource('resource-1')],
    layers: [
      CanvasLayer(id: CanvasLayerId('layer-1'), elements: [_rect('rect-1')]),
    ],
  );
}

CanvasDocument _twoElementDocument() {
  return CanvasDocument(
    resources: [_resource('resource-1')],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [_rect('rect-1'), _rect('rect-2')],
      ),
    ],
  );
}

int? _documentElementRevision(RuntimeRoot root, String id) {
  for (final layer in root.readDocument().layers) {
    for (final element in layer.elements) {
      if (element.id.value == id) {
        return element.revision;
      }
    }
  }

  return null;
}

CanvasImageResource _resource(String id, {String? appKey}) {
  return CanvasImageResource(
    id: CanvasResourceId(id),
    source: CanvasResourceSource.appKey(appKey ?? id),
  );
}

CanvasRectElement _rect(String id) {
  return CanvasRectElement(id: CanvasElementId(id), size: const Size(1, 1));
}

CanvasPalette _alternatePalette() {
  return CanvasPalette(
    penColors: const [Color(0xFF000000), Color(0xFFFFFFFF)],
    backgroundColors: const [Color(0xFF112233)],
    gridSizes: const [8, 16],
  );
}

CanvasDeletionDecision _acceptDeletionCommit(CanvasDeletionCommitRequest _) =>
    CanvasDeletionDecision.accept;
