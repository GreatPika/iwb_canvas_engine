import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/prepared_selection_effect.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/touched_set.dart';
import 'package:iwb_canvas_engine/src/edit/commit_applier.dart';
import 'package:iwb_canvas_engine/src/edit/commit_plan.dart';
import 'package:iwb_canvas_engine/src/edit/draft_document.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

void main() {
  test('commit plan emits typed descriptions for future owners', () {
    expect(_expectTypedEffects, returnsNormally);
  });

  test('commit applier returns immutable post-install apply result', () {
    expect(_expectPostInstallApplyResult, returnsNormally);
  });

  test('commit applier skips installers for empty plans', () {
    expect(_expectEmptyApplyResult, returnsNormally);
  });

  test('unused resource descriptor edits do not request repaint', () {
    expect(_expectUnusedResourceEditDoesNotRepaint, returnsNormally);
  });

  test('referenced resource descriptor edits request repaint', () {
    expect(_expectReferencedResourceEditRepaints, returnsNormally);
  });
}

void _expectTypedEffects() {
  final draft = DraftDocument(_document());

  draft.addElement(_rect('rect-2'), layerId: CanvasLayerId('layer-1'));
  final plan = draft.commitPlan;

  expect(plan.hasChanges, isTrue);
  expect(plan.documentReplaced, isFalse);
  expect(plan.effects.whereType<ProjectionEffect>(), hasLength(1));
  expect(plan.effects.whereType<SpatialEffect>(), hasLength(1));
  expect(plan.effects.whereType<RepaintEffect>(), hasLength(1));
  expect(plan.effects.whereType<PublicStateEffect>(), hasLength(1));
}

void _expectPostInstallApplyResult() {
  final events = <String>[];
  final effects = [const ProjectionEffect(), const PublicStateEffect()];
  final plan = CommitPlan(
    revisionDelta: const StoreRevisionDelta.structural(),
    touchedSet: TouchedSet(selection: true),
    selectionEffect: const PruneSelectionEffect(),
    effects: effects,
  );

  final result = _applyPostInstallPlan(plan, events);

  _expectPostInstallEvents(events, result);
  _expectDeliveryEffects(result.effects);
}

CommitDeliveryResult _applyPostInstallPlan(
  CommitPlan plan,
  List<String> events,
) {
  return const CommitApplier().apply(
    document: AcceptedMaterializedDocument(
      document: CanvasDocument(),
      revisionDelta: plan.revisionDelta,
    ),
    plan: plan,
    documentInstallers: CommitDocumentInstallers(
      prepareDocumentInstall: (document, {required documentReplaced}) => () {
        events.add(switch (document) {
          PreparedMaterializedDocument() =>
            documentReplaced ? 'replacement' : 'document',
          PreparedSparseStoreDocument() => 'sparse-document',
          PreparedMaterializedStoreDocument() =>
            'prepared-materialized-document',
          PreparedUnchangedStoreDocument() => 'unchanged-document',
        });
      },
    ),
    selectionInstallers: CommitSelectionInstallers(
      prepareSelectionEffect: (_, _) {
        events.add('prepare-selection');

        return PreparedSelectionEffect(const []);
      },
      installSelectionEffect: (_) {
        events.add('selection');

        return true;
      },
    ),
  );
}

void _expectPostInstallEvents(
  List<String> events,
  CommitDeliveryResult result,
) {
  expect(events, ['prepare-selection', 'document', 'selection']);
  expect(result.shouldPublishState, isTrue);
}

void _expectDeliveryEffects(List<CommitDeliveryEffect> effects) {
  expect(effects.whereType<ProjectionDeliveryEffect>(), hasLength(1));
  expect(effects.whereType<PublicStateDeliveryEffect>(), hasLength(1));
  expect(
    () => effects.add(const RepaintDeliveryEffect(mainCanvas: true)),
    throwsUnsupportedError,
  );
}

void _expectEmptyApplyResult() {
  final events = <String>[];

  final result = const CommitApplier().apply(
    document: AcceptedMaterializedDocument(
      document: CanvasDocument(),
      revisionDelta: const StoreRevisionDelta(),
    ),
    plan: CommitPlan.empty(),
    documentInstallers: CommitDocumentInstallers(
      prepareDocumentInstall: (document, {required documentReplaced}) => () {
        events.add(switch (document) {
          PreparedMaterializedDocument() =>
            documentReplaced ? 'replacement' : 'document',
          PreparedSparseStoreDocument() => 'sparse-document',
          PreparedMaterializedStoreDocument() =>
            'prepared-materialized-document',
          PreparedUnchangedStoreDocument() => 'unchanged-document',
        });
      },
    ),
    selectionInstallers: CommitSelectionInstallers(
      prepareSelectionEffect: (_, _) {
        events.add('prepare-selection');

        return PreparedSelectionEffect(const []);
      },
      installSelectionEffect: (_) {
        events.add('selection');

        return true;
      },
    ),
  );

  expect(events, isEmpty);
  expect(result.shouldPublishState, isFalse);
  expect(result.effects, isEmpty);
}

void _expectUnusedResourceEditDoesNotRepaint() {
  final draft = DraftDocument(_documentWithUnusedResource());

  draft.removeUnusedResource(CanvasResourceId('resource-1'));
  final plan = draft.commitPlan;

  expect(plan.effects.whereType<ResourceEffect>(), hasLength(1));
  expect(plan.effects.whereType<RepaintEffect>(), isEmpty);
}

void _expectReferencedResourceEditRepaints() {
  final draft = DraftDocument(_documentWithReferencedResource());

  draft.upsertResource(
    CanvasImageResource(
      id: CanvasResourceId('resource-1'),
      source: CanvasResourceSource.appKey('resource-1-updated'),
    ),
  );
  final plan = draft.commitPlan;

  expect(plan.effects.whereType<ResourceEffect>(), hasLength(1));
  expect(plan.effects.whereType<RepaintEffect>(), hasLength(1));
}

CanvasDocument _document() {
  return CanvasDocument(
    layers: [
      CanvasLayer(id: CanvasLayerId('layer-1'), elements: [_rect('rect-1')]),
    ],
  );
}

CanvasDocument _documentWithUnusedResource() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('resource-1'),
        source: CanvasResourceSource.appKey('resource-1'),
      ),
    ],
    layers: [
      CanvasLayer(id: CanvasLayerId('layer-1'), elements: [_rect('rect-1')]),
    ],
  );
}

CanvasDocument _documentWithReferencedResource() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('resource-1'),
        source: CanvasResourceSource.appKey('resource-1'),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('image-1'),
            resourceId: CanvasResourceId('resource-1'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}

CanvasRectElement _rect(String id) {
  return CanvasRectElement(id: CanvasElementId(id), size: const Size(1, 1));
}
