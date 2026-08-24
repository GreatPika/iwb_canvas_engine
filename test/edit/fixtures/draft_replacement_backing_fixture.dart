import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/edit/draft_document.dart';
import 'package:iwb_canvas_engine/src/store/committed_document.dart';

import 'sparse_edit_session/sparse_edit_session_support.dart';

void registerDraftReplacementBackingTests() {
  test(
    'draft replacement prepares one isolated backing before publication',
    () => expect(_expectDraftReplacementBackingAtomicity, returnsNormally),
  );
}

void _expectDraftReplacementBackingAtomicity() {
  _expectDraftReplacementFailureRetention();
  _expectDraftReplacementPublicationAndIsolation();
  _expectDraftReplacementAtSupportedSizeBuildsOnce();
}

// All injected phases share one before/after oracle so partial publication
// cannot hide behind final equality or a clone-back repair.
// ignore: halstead-volume, source-lines-of-code
void _expectDraftReplacementFailureRetention() {
  for (final phase in DraftReplacementWorkPhase.values) {
    final draft = _replacementDraft();
    final before = _DraftReplacementSnapshot.capture(draft);
    final events = <DraftReplacementWorkEvent>[];

    expect(
      () => DraftDocument.observeDraftReplacementWork((event) {
        events.add(event);
        if (event.phase == phase) {
          throw StateError('Injected replacement failure at $phase.');
        }
      }, () => draft.replaceDocument(_completeReplacementDocument())),
      throwsStateError,
    );

    before.expectUnchanged(draft);
    expect(
      events.map((event) => event.phase),
      _replacementPhasesThrough(phase),
    );
    expect(
      events.map((event) => event.activeBacking),
      everyElement(same(before.backing)),
    );
    if (phase == DraftReplacementWorkPhase.publication) {
      expect(events.last.replacementBacking, isNot(same(before.backing)));
    } else {
      expect(events.last.replacementBacking, isNull);
    }
  }

  final invalidDraft = _replacementDraft();
  final beforeInvalid = _DraftReplacementSnapshot.capture(invalidDraft);
  final invalidEvents = <DraftReplacementWorkEvent>[];
  expect(
    () => DraftDocument.observeDraftReplacementWork(
      invalidEvents.add,
      () => invalidDraft.replaceDocument(_invalidBackingReplacementDocument()),
    ),
    throwsA(
      isA<CanvasDataException>().having(
        (error) => error.code,
        'code',
        CanvasDataErrorCode.duplicateElementId,
      ),
    ),
  );
  beforeInvalid.expectUnchanged(invalidDraft);
  expect(invalidEvents.map((event) => event.phase), [
    DraftReplacementWorkPhase.validation,
  ]);
  expect(invalidEvents.single.activeBacking, same(beforeInvalid.backing));
}

// Publication, backing identity, caller alias, and projection alias checks are
// one atomicity admission rather than separate fixture families.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _expectDraftReplacementPublicationAndIsolation() {
  final draft = _replacementDraft();
  final before = _DraftReplacementSnapshot.capture(draft);
  final events = <DraftReplacementWorkEvent>[];

  DraftDocument.observeDraftReplacementWork(events.add, () {
    draft.replaceDocument(_completeReplacementDocument());
  });

  expect(events.map((event) => event.phase), DraftReplacementWorkPhase.values);
  expect(
    events.map((event) => event.activeBacking),
    everyElement(same(before.backing)),
  );
  final publication = events.last;
  final replacementBacking = publication.replacementBacking;
  expect(replacementBacking, isNotNull);
  expect(replacementBacking, isNot(same(before.backing)));
  expect(draft.replacementBackingHandle, same(replacementBacking));

  final replacement = draft.readDocument();
  expect(replacement.camera.offset, const Offset(12, 13));
  expect(replacement.background.color, const Color(0xFF102030));
  expect(replacement.palette.penColors, [const Color(0xFF010203)]);
  expect(replacement.resources.map((resource) => resource.id.value), [
    'next-r',
  ]);
  expect(
    replacement.layers.single.elements.map((element) => element.id.value),
    ['next-element'],
  );
  expect(
    draft.summary,
    const CanvasDocumentSummary(
      elementCount: 2,
      layerCount: 1,
      resourceCount: 1,
    ),
  );
  expect(draft.documentReplaced, isTrue);
  expect(draft.touchedSet.documentReplaced, isTrue);
  expect(draft.touchedSet.selection, isTrue);
  _expectReplacementRevisionDelta(draft);

  for (final element in <CanvasRectElement>[
    CanvasRectElement(
      id: CanvasElementId('ineligible-selection'),
      size: const Size(1, 1),
      isVisible: false,
    ),
    CanvasRectElement(
      id: CanvasElementId('ineligible-selection'),
      size: const Size(1, 1),
      isSelectable: false,
    ),
  ]) {
    final selectionDraft = DraftDocument(
      _replacementSeedDocument(),
      selectedElementIds: [CanvasElementId('ineligible-selection')],
    );
    selectionDraft.replaceDocument(
      CanvasDocument(
        layers: [
          CanvasLayer(
            id: CanvasLayerId('ineligible-layer'),
            elements: [element],
          ),
        ],
      ),
    );
    expect(selectionDraft.touchedSet.selection, isTrue);
  }

  final activeBeforeRetiredMutation = _DraftReplacementSnapshot.capture(draft);
  draft.mutateReplacementBackingForTesting(before.backing);
  activeBeforeRetiredMutation.expectUnchanged(draft);

  draft.addElement(
    CanvasImageElement(
      id: CanvasElementId('active-replacement-element'),
      resourceId: CanvasResourceId('next-r'),
      size: const Size(1, 1),
    ),
    layerId: CanvasLayerId('next-layer'),
  );
  expect(
    draft.upsertResource(
      CanvasImageResource(
        id: CanvasResourceId('active-replacement-resource'),
        source: CanvasResourceSource.appKey('active-replacement-resource'),
      ),
    ),
    isTrue,
  );
  final afterMutation = draft.readDocument();
  expect(
    afterMutation.layers.single.elements.map((element) => element.id.value),
    ['next-element', 'active-replacement-element'],
  );
  expect(afterMutation.resources.map((resource) => resource.id.value), [
    'next-r',
    'active-replacement-resource',
  ]);
  expect(
    draft.summary,
    const CanvasDocumentSummary(
      elementCount: 3,
      layerCount: 1,
      resourceCount: 2,
    ),
  );
  expect(draft.touchedSet.addedElementIds, {
    CanvasElementId('active-replacement-element'),
  });
  expect(draft.touchedSet.resourceDescriptorChangedIds, {
    CanvasResourceId('active-replacement-resource'),
  });
  expect(draft.touchedSet.layerIds, isEmpty);
  expect(draft.touchedSet.backgroundLayerChanged, isFalse);
  _expectReplacementRevisionDelta(draft);

  expect(() => replacement.layers.clear(), throwsUnsupportedError);
  expect(() => replacement.resources.clear(), throwsUnsupportedError);
  expect(draft.readDocument().layers.single.elements, hasLength(2));
  expect(draft.readDocument().resources, hasLength(2));
}

// The supported-size witness observes only replacement's one Draft backing
// construction and publication; structure/resource mutation work stays owned
// by their existing focused suites.
// ignore: halstead-volume, source-lines-of-code
void _expectDraftReplacementAtSupportedSizeBuildsOnce() {
  const elementCount = 200000;
  const layerCount = 4096;
  final draft = DraftDocument(_replacementSeedDocument());
  final replacement = supportedSizeDraftDocument(
    elementCount: elementCount,
    layerCount: layerCount,
  );
  final replacementEvents = <DraftReplacementWorkEvent>[];
  final aggregateEvents = <StoreSparseCandidateEvent>[];
  var constructionLayerVisits = 0;
  var constructionElementVisits = 0;
  var constructionDescriptorVisits = 0;
  var resourceConstructionElementVisits = 0;
  var structureMapReads = 0;

  CommittedDocument.observeSparseCandidateEvents(
    aggregateEvents.add,
    () => DraftDocument.observeDraftReplacementWork(
      replacementEvents.add,
      () => observeDraftStructureWork(
        (event) {
          if (event.mapOperation == DraftStructureMapOperation.read) {
            structureMapReads += 1;
          }
          switch (event.kind) {
            case DraftStructureWorkKind.constructionLayerVisit:
              constructionLayerVisits += 1;
            case DraftStructureWorkKind.constructionElementVisit:
              constructionElementVisits += 1;
            case _:
              break;
          }
        },
        () => observeDraftResourceWork((event) {
          switch (event.kind) {
            case DraftResourceWorkKind.constructionDescriptorVisit:
              constructionDescriptorVisits += 1;
            case DraftResourceWorkKind.constructionElementVisit:
              resourceConstructionElementVisits += 1;
            case _:
              break;
          }
        }, () => draft.replaceDocument(replacement)),
      ),
    ),
  );

  expect(
    replacementEvents.map((event) => event.phase),
    DraftReplacementWorkPhase.values,
  );
  expect(
    replacementEvents.where(
      (event) => event.phase == DraftReplacementWorkPhase.publication,
    ),
    hasLength(1),
  );
  expect(constructionLayerVisits, layerCount);
  expect(constructionElementVisits, elementCount);
  expect(constructionDescriptorVisits, 0);
  expect(resourceConstructionElementVisits, elementCount);
  expect(structureMapReads, 0);
  expect(
    aggregateEvents.where(
      (event) =>
          event.kind == StoreSparseCandidateEventKind.aggregatePublication,
    ),
    isEmpty,
  );
  expect(
    draft.summary,
    const CanvasDocumentSummary(
      elementCount: elementCount,
      layerCount: layerCount,
      resourceCount: 0,
    ),
  );
}

DraftDocument _replacementDraft() {
  final selectedElementIds = <CanvasElementId>[CanvasElementId('element-1')];
  final draft = DraftDocument(
    _replacementSeedDocument(),
    selectedElementIds: selectedElementIds,
  );
  selectedElementIds.clear();
  draft.setCameraOffset(const Offset(2, 3));
  draft.setPalette(
    CanvasPalette(
      penColors: const [Color(0xFF112233)],
      backgroundColors: const [Color(0xFF445566)],
      gridSizes: const [8],
    ),
  );
  return draft;
}

CanvasDocument _replacementSeedDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('element-1'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _invalidBackingReplacementDocument() {
  return CanvasDocument(
    backgroundElements: [
      CanvasRectElement(
        id: CanvasElementId('duplicate'),
        size: const Size(1, 1),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('duplicate'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _completeReplacementDocument() {
  return CanvasDocument(
    camera: CanvasCamera(offset: const Offset(12, 13)),
    background: const CanvasBackground(color: Color(0xFF102030)),
    palette: CanvasPalette(
      penColors: const [Color(0xFF010203)],
      backgroundColors: const [Color(0xFF040506)],
      gridSizes: const [16],
    ),
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('next-r'),
        source: CanvasResourceSource.appKey('next-r'),
      ),
    ],
    backgroundElements: [
      CanvasRectElement(
        id: CanvasElementId('next-background'),
        size: const Size(1, 1),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('next-layer'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('next-element'),
            resourceId: CanvasResourceId('next-r'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}

Iterable<DraftReplacementWorkPhase> _replacementPhasesThrough(
  DraftReplacementWorkPhase phase,
) {
  return DraftReplacementWorkPhase.values.take(phase.index + 1);
}

void _expectReplacementRevisionDelta(DraftDocument draft) {
  final delta = draft.revisionDelta;
  expect(delta.document, isTrue);
  expect(delta.projection, isTrue);
  expect(delta.structural, isTrue);
  expect(delta.bounds, isTrue);
  expect(delta.elementVisual, isTrue);
  expect(delta.background, isTrue);
  expect(delta.grid, isTrue);
  expect(delta.resource, isTrue);
}

final class _DraftReplacementSnapshot {
  const _DraftReplacementSnapshot({
    required this.backing,
    required this.document,
    required this.summary,
    required this.revisionFacts,
    required this.touchedFacts,
    required this.didChange,
    required this.documentReplaced,
  });

  factory _DraftReplacementSnapshot.capture(DraftDocument draft) {
    return _DraftReplacementSnapshot(
      backing: draft.replacementBackingHandle,
      document: draft.readDocument(),
      summary: draft.summary,
      revisionFacts: _revisionFacts(draft),
      touchedFacts: _touchedFacts(draft),
      didChange: draft.didChange,
      documentReplaced: draft.documentReplaced,
    );
  }

  final Object backing;
  final CanvasDocument document;
  final CanvasDocumentSummary summary;
  final List<bool> revisionFacts;
  final List<Object> touchedFacts;
  final bool didChange;
  final bool documentReplaced;

  void expectUnchanged(DraftDocument draft) {
    expect(draft.replacementBackingHandle, same(backing));
    expect(
      encodeCanvasDocument(draft.readDocument()),
      encodeCanvasDocument(document),
    );
    expect(draft.summary, summary);
    expect(draft.didChange, didChange);
    expect(draft.documentReplaced, documentReplaced);
    expect(_revisionFacts(draft), revisionFacts);
    expect(_touchedFacts(draft), touchedFacts);
  }
}

List<bool> _revisionFacts(DraftDocument draft) {
  final delta = draft.revisionDelta;

  return [
    delta.document,
    delta.projection,
    delta.structural,
    delta.bounds,
    delta.elementVisual,
    delta.background,
    delta.grid,
    delta.resource,
  ];
}

List<Object> _touchedFacts(DraftDocument draft) {
  final touched = draft.touchedSet;

  return [
    touched.addedElementIds,
    touched.removedElementIds,
    touched.updatedElementIds,
    touched.transformedElementIds,
    touched.geometryElementIds,
    touched.visualElementIds,
    touched.resourceDescriptorChangedIds,
    touched.resourceVisualChangedIds,
    touched.layerIds,
    touched.allResourceVisualsChanged,
    touched.backgroundLayerChanged,
    touched.selection,
    touched.persistedCamera,
    touched.background,
    touched.grid,
    touched.palette,
    touched.documentReplaced,
  ];
}
