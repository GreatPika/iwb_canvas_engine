// This direct Store witness composes the existing owner-owned test seams.
// Keeping their typed imports explicit prevents a test-only mirror/barrel.
// This metric is file-scoped; the three direct Store owner fixtures use the
// same explicit-import policy rather than hiding dependencies behind a barrel.
// ignore_for_file: number-of-imports

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_contract_limits.dart';
import 'package:iwb_canvas_engine/src/store/committed_document.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/element_registry.dart';
import 'package:iwb_canvas_engine/src/store/family_tables.dart';
import 'package:iwb_canvas_engine/src/store/indexed_order_sequence.dart';
import 'package:iwb_canvas_engine/src/store/resource_table.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';
import 'package:iwb_canvas_engine/src/store/store_commit_finalization.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

import '../../support/document_store_with_document.dart';
import 'family_tables_telemetry.dart';

void main() {
  // Each named helper contains the direct owner assertions; adding a sentinel
  // assertion here would only test a fixture return value.
  // ignore: missing-test-assertion, reason: The named helper owns the direct assertions.
  test(
    'candidate current-state oracle covers fixed seeded cross-owner prefixes',
    _candidateCurrentStateOracle,
  );
  // ignore: missing-test-assertion, reason: The named helper owns the direct assertions.
  test(
    'candidate accepted facts use normalized final facts',
    _candidateAcceptedFactsOracle,
  );
  // ignore: missing-test-assertion, reason: The named helper owns the direct assertions.
  test(
    'candidate composes bounded owner work and one publication',
    _candidatePublicationWork,
  );
  // ignore: missing-test-assertion, reason: The named helper owns the direct assertions.
  test(
    'candidate failure and alias matrix keeps preparation atomic',
    _candidateFailureAndAliasMatrix,
  );
}

const _allFactsDelta = StoreRevisionDelta(
  document: true,
  projection: true,
  structural: true,
  bounds: true,
  elementVisual: true,
  background: true,
  grid: true,
  resource: true,
);

// These published seeds each force the same cross-owner policy obligations in
// a different journal arrangement. Prefix replay produces a smallest failing
// prefix directly in the assertion reason without depending on Store helpers.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _candidateCurrentStateOracle() {
  const seeds = [1709, 2718, 31415];
  for (final seed in seeds) {
    final trace = _seededTrace(seed);
    final oracle = _CandidateStateOracle.fromDocument(_candidateBaseDocument());
    for (var length = 1; length <= trace.length; length += 1) {
      oracle.apply(trace[length - 1]);
      final store = documentStoreWithDocument(_candidateBaseDocument());
      final events = <StoreSparseCandidateEvent>[];
      final resourceEvents = <ResourceTableSelectiveMutationEvent>[];
      final structuralEvents = <ElementRegistryStructuralEditorWorkEvent>[];
      final familyWork = FamilyTablesTelemetry();
      late PreparedSparseStoreCommit prepared;
      try {
        prepared = FamilyTables.observeTelemetry(
          familyWork.record,
          () => ResourceTableEditor.observeWork(
            resourceEvents.add,
            () => ElementRegistry.observeSparseStructuralEditorWork(
              structuralEvents.add,
              () => CommittedDocument.observeSparseCandidateEvents(
                events.add,
                () => store.prepareSparseCommit(
                  StoreSparseCommit(
                    revisionDelta: _allFactsDelta,
                    mutations: trace.take(length).toList(growable: false),
                  ),
                ),
              ),
            ),
          ),
        );
      } catch (error, stackTrace) {
        fail(
          'seed=$seed shortest failing prefix=$length error=$error\n$stackTrace',
        );
      }
      _expectStoreMatchesOracle(
        prepared.document,
        oracle,
        reason: 'seed=$seed shortest failing prefix=$length',
      );
      expect(
        prepared.hasChanges,
        oracle.differsFromBase,
        reason: 'seed=$seed shortest failing prefix=$length acceptance',
      );
      _expectPrefixOwnerState(
        events: events,
        resourceEvents: resourceEvents,
        structuralEvents: structuralEvents,
        familyWork: familyWork,
        prefix: trace.take(length),
        reason: 'seed=$seed shortest failing prefix=$length',
      );
      if (seed == 1709 && length == 3) {
        // This prefix is the admitted resource-add/remove interleaving. Keep
        // the family decision ordering here with the cross-owner oracle.
        expect(familyWork.editorDecisionTrace, const [
          FamilyTablesDecision.duplicateAdd,
          FamilyTablesDecision.removeUnusedReference,
          FamilyTablesDecision.removeMembership,
          FamilyTablesDecision.relationship,
          FamilyTablesDecision.acceptedDelta,
        ]);
      }
    }
  }
}

// One literal trace forces every cross-owner mutation family for each seed.
// splitting it would hide the deliberate interleaving that the oracle proves.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
List<StoreSparseMutation> _seededTrace(int seed) {
  final suffix = '$seed';
  final image = CanvasImageElement(
    id: CanvasElementId('image-$suffix'),
    resourceId: CanvasResourceId('r-pre-$suffix'),
    size: const Size(2, 3),
  );
  final imageMoved = CanvasImageElement(
    id: image.id,
    resourceId: CanvasResourceId('r-image-1'),
    size: image.size,
    revision: 1,
  );
  final vector = CanvasVectorElement(
    id: CanvasElementId('vector-$suffix'),
    resourceId: CanvasResourceId('r-vector-$suffix'),
    size: const Size(3, 2),
  );
  final transient = CanvasRectElement(
    id: CanvasElementId('transient-$suffix'),
    size: const Size(1, 1),
  );
  final readded = CanvasRectElement(id: transient.id, size: const Size(2, 2));
  final first = <StoreSparseMutation>[
    StoreSparseUpsertResource(_imageResource('r-pre-$suffix', 'before-$seed')),
    StoreSparseAddElement(
      element: image,
      layerId: CanvasLayerId('layer-a'),
      index: -5,
    ),
    StoreSparseRemoveUnusedResource(CanvasResourceId('r-pre-$suffix')),
    StoreSparseUpdateElement(
      before: image,
      element: imageMoved,
      elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
    ),
    StoreSparseRemoveUnusedResource(CanvasResourceId('r-pre-$suffix')),
    StoreSparseUpsertResource(
      _vectorResource('r-vector-$suffix', 'vector-$seed'),
    ),
    StoreSparseAddElement(
      element: vector,
      layerId: CanvasLayerId('layer-b'),
      index: 999,
    ),
    StoreSparseEnsureLayer(CanvasLayerId('layer-$suffix'), index: -999),
    StoreSparseAddElement(
      element: transient,
      layerId: CanvasLayerId('layer-$suffix'),
    ),
    StoreSparseRemoveElement(transient.id),
    StoreSparseAddElement(element: readded, background: true, index: 999),
    StoreSparseRemoveElement(readded.id),
    StoreSparseAddElement(
      element: readded,
      layerId: CanvasLayerId('layer-$suffix'),
      index: 0,
    ),
  ];
  final scalarsAndClear = <StoreSparseMutation>[
    StoreSparseSetCamera(CanvasCamera(offset: const Offset(3, 4))),
    const StoreSparseSetCamera(CanvasCamera.origin),
    const StoreSparseSetBackground(CanvasBackground(color: Color(0xFF112233))),
    const StoreSparseSetBackground(CanvasBackground()),
    StoreSparseSetPalette(
      CanvasPalette(
        penColors: const [Color(0xFF112233)],
        backgroundColors: const [Color(0xFF445566)],
        gridSizes: const [12],
      ),
    ),
    const StoreSparseSetPalette(CanvasPalette.defaults()),
    const StoreSparseClearContent(removeUnusedResources: false),
    StoreSparseAddElement(
      element: CanvasRectElement(
        id: CanvasElementId('after-clear-$suffix'),
        size: const Size(4, 5),
      ),
    ),
    const StoreSparseClearContent(removeUnusedResources: true),
    StoreSparseSetBackground(
      CanvasBackground(color: Color(0xFF000000 | (seed & 0x00FFFFFF))),
    ),
  ];
  return switch (seed % 3) {
    0 => [...first, ...scalarsAndClear],
    1 => [
      ...first.take(8),
      ...scalarsAndClear.take(6),
      ...first.skip(8),
      ...scalarsAndClear.skip(6),
    ],
    _ => [
      ...first.take(3),
      ...scalarsAndClear.take(4),
      ...first.skip(3),
      ...scalarsAndClear.skip(4),
    ],
  };
}

// The four live owner observations remain separately typed so this direct
// oracle cannot hide a stale-owner read behind a test-only context mirror.
// ignore: number-of-parameters
void _expectPrefixOwnerState({
  required List<StoreSparseCandidateEvent> events,
  required List<ResourceTableSelectiveMutationEvent> resourceEvents,
  required List<ElementRegistryStructuralEditorWorkEvent> structuralEvents,
  required FamilyTablesTelemetry familyWork,
  required Iterable<StoreSparseMutation> prefix,
  required String reason,
}) {
  expect(
    events.map((event) => event.kind),
    contains(StoreSparseCandidateEventKind.open),
    reason: '$reason candidate open',
  );
  expect(familyWork.staleDecisionReadCount, 0, reason: reason);
  expect(
    resourceEvents.where(
      (event) => event.kind == ResourceTableEditorWorkKind.editorOpen,
    ),
    hasLength(1),
    reason: '$reason resource editor open',
  );
  expect(
    resourceEvents.where(
      (event) => event.kind == ResourceTableEditorWorkKind.currentRead,
    ),
    isNotEmpty,
    reason: '$reason resource decisions use the live editor',
  );
  expect(
    structuralEvents.where(
      (event) =>
          event.kind == ElementRegistryStructuralEditorWorkKind.editorOpen,
    ),
    hasLength(1),
    reason: '$reason structural editor open',
  );
  if (prefix.any(
    (mutation) =>
        mutation is StoreSparseSetBackground ||
        mutation is StoreSparseSetCamera ||
        mutation is StoreSparseSetPalette,
  )) {
    expect(
      events.map((event) => event.kind),
      contains(StoreSparseCandidateEventKind.currentScalarRead),
      reason: '$reason scalar decisions use candidate-local facts',
    );
  }
}

CanvasDocument _candidateBaseDocument() => CanvasDocument(
  resources: [
    _imageResource('r-image-0', 'image-0'),
    _imageResource('r-image-1', 'image-1'),
    _vectorResource('r-vector-0', 'vector-0'),
  ],
  backgroundElements: [_rect('background-base')],
  layers: [
    CanvasLayer(
      id: CanvasLayerId('layer-a'),
      elements: [
        _rect('rect-a'),
        CanvasImageElement(
          id: CanvasElementId('image-base'),
          resourceId: CanvasResourceId('r-image-0'),
          size: const Size(1, 1),
        ),
      ],
    ),
    CanvasLayer(
      id: CanvasLayerId('layer-b'),
      elements: [
        CanvasVectorElement(
          id: CanvasElementId('vector-base'),
          resourceId: CanvasResourceId('r-vector-0'),
          size: const Size(1, 1),
        ),
      ],
    ),
  ],
);

CanvasImageResource _imageResource(String id, String appKey) =>
    CanvasImageResource(
      id: CanvasResourceId(id),
      source: CanvasResourceSource.appKey(appKey),
    );

CanvasVectorResource _vectorResource(String id, String appKey) =>
    CanvasVectorResource(
      id: CanvasResourceId(id),
      source: CanvasResourceSource.appKey(appKey),
    );

CanvasRectElement _rect(String id, {int revision = 0}) => CanvasRectElement(
  id: CanvasElementId(id),
  size: const Size(1, 1),
  revision: revision,
);

// This oracle intentionally uses only DTO facts plus list/map operations. It
// never calls Store, candidate, editor, table, or sequence APIs for expected
// state, so a stale owner read cannot be masked by shared implementation.
// ignore: coupling-between-object-classes, response-for-class, weighted-methods-per-class
final class _CandidateStateOracle {
  _CandidateStateOracle.fromDocument(CanvasDocument document)
    : camera = document.camera,
      background = document.background,
      palette = document.palette {
    for (final resource in document.resources) {
      resources[resource.id.value] = resource;
    }
    for (final element in document.backgroundElements) {
      elements[element.id.value] = element;
      backgroundIds.add(element.id.value);
    }
    for (final layer in document.layers) {
      layerIds.add(layer.id.value);
      contentByLayer[layer.id.value] = [
        for (final element in layer.elements) element.id.value,
      ];
      for (final element in layer.elements) {
        elements[element.id.value] = element;
      }
    }
    _base = _CandidateStateOracleSnapshot.from(this);
  }

  late final _CandidateStateOracleSnapshot _base;
  CanvasCamera camera;
  CanvasBackground background;
  CanvasPalette palette;
  final Map<String, CanvasResource> resources = {};
  final Map<String, CanvasElement> elements = {};
  final List<String> backgroundIds = [];
  final List<String> layerIds = [];
  final Map<String, List<String>> contentByLayer = {};

  bool get differsFromBase => !_base.matches(this);

  Iterable<String> get contentIds sync* {
    for (final layerId in layerIds) {
      yield* contentByLayer[layerId] ?? const <String>[];
    }
  }

  Iterable<String> get frameIds sync* {
    yield* backgroundIds;
    yield* contentIds;
  }

  // The independent oracle owns the full mutation taxonomy in one place so
  // every seeded prefix has a simple, auditable list/map interpretation.
  // ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index
  void apply(StoreSparseMutation mutation) {
    switch (mutation) {
      case StoreSparseEnsureLayer(:final id, :final index):
        if (contentByLayer.containsKey(id.value)) {
          return;
        }
        final target = _clampedIndex(index, layerIds.length);
        layerIds.insert(target, id.value);
        contentByLayer[id.value] = [];
      case StoreSparseAddElement(
        :final element,
        :final layerId,
        :final index,
        :final background,
      ):
        if (elements.containsKey(element.id.value)) {
          return;
        }
        elements[element.id.value] = element;
        if (background) {
          backgroundIds.insert(
            _clampedIndex(index, backgroundIds.length),
            element.id.value,
          );
        } else {
          final targetLayer = layerId?.value ?? layerIds.last;
          final ids = contentByLayer[targetLayer]!;
          ids.insert(_clampedIndex(index, ids.length), element.id.value);
        }
      case StoreSparseUpdateElement(:final element):
        if (elements.containsKey(element.id.value)) {
          elements[element.id.value] = element;
        }
      case StoreSparseRemoveElement(:final id):
        if (elements.remove(id.value) == null) {
          return;
        }
        backgroundIds.remove(id.value);
        for (final ids in contentByLayer.values) {
          ids.remove(id.value);
        }
      case StoreSparseUpsertResource(:final resource):
        resources[resource.id.value] = resource;
      case StoreSparseRemoveUnusedResource(:final id):
        if (!_isResourceReferenced(id.value)) {
          resources.remove(id.value);
        }
      case StoreSparseClearContent(:final removeUnusedResources):
        for (final id in contentIds.toList(growable: false)) {
          elements.remove(id);
        }
        for (final ids in contentByLayer.values) {
          ids.clear();
        }
        if (removeUnusedResources) {
          resources.removeWhere((id, _) => !_isResourceReferenced(id));
        }
      case StoreSparseSetCamera(:final camera):
        this.camera = camera;
      case StoreSparseSetBackground(:final background):
        this.background = background;
      case StoreSparseSetPalette(:final palette):
        this.palette = palette;
    }
  }

  bool _isResourceReferenced(String resourceId) => elements.values.any(
    (element) => switch (element) {
      CanvasImageElement(resourceId: final referencedId) ||
      CanvasVectorElement(
        resourceId: final referencedId,
      ) => referencedId.value == resourceId,
      _ => false,
    },
  );
}

int _clampedIndex(int? index, int length) {
  final requested = index ?? length;
  if (requested < 0) {
    return 0;
  }
  if (requested > length) {
    return length;
  }
  return requested;
}

final class _CandidateStateOracleSnapshot {
  _CandidateStateOracleSnapshot.from(_CandidateStateOracle source)
    : camera = source.camera,
      background = source.background,
      palette = source.palette,
      resources = Map.of(source.resources),
      elements = Map.of(source.elements),
      backgroundIds = List.of(source.backgroundIds),
      layerIds = List.of(source.layerIds),
      contentByLayer = {
        for (final entry in source.contentByLayer.entries)
          entry.key: List.of(entry.value),
      };

  final CanvasCamera camera;
  final CanvasBackground background;
  final CanvasPalette palette;
  final Map<String, CanvasResource> resources;
  final Map<String, CanvasElement> elements;
  final List<String> backgroundIds;
  final List<String> layerIds;
  final Map<String, List<String>> contentByLayer;

  bool matches(_CandidateStateOracle current) =>
      camera == current.camera &&
      background == current.background &&
      _samePalette(palette, current.palette) &&
      _sameResourceMap(resources, current.resources) &&
      _sameElementMap(elements, current.elements) &&
      _sameList(backgroundIds, current.backgroundIds) &&
      _sameList(layerIds, current.layerIds) &&
      _sameContent(contentByLayer, current.contentByLayer);
}

// Complete public-state parity belongs in one assertion boundary, avoiding a
// partial oracle that could miss order, locations, tokens, or descriptors.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _expectStoreMatchesOracle(
  CommittedDocument document,
  _CandidateStateOracle oracle, {
  required String reason,
}) {
  expect(document.camera, oracle.camera, reason: '$reason camera');
  expect(document.background, oracle.background, reason: '$reason background');
  expect(
    _samePalette(document.palette, oracle.palette),
    isTrue,
    reason: '$reason palette',
  );
  expect(
    document.resourceTable.descriptors.keys.map((id) => id.value),
    oracle.resources.keys,
    reason: '$reason descriptor order',
  );
  for (final resource in oracle.resources.values) {
    final descriptor = document.resourceDescriptor(resource.id);
    expect(
      descriptor,
      isNotNull,
      reason: '$reason descriptor ${resource.id.value}',
    );
    if (descriptor == null) {
      continue;
    }
    expect(
      descriptor.runtimeType,
      _descriptorTypeFor(resource),
      reason: '$reason descriptor kind ${resource.id.value}',
    );
    expect(
      descriptor.appKey,
      _appKeyOf(resource),
      reason: '$reason descriptor source ${resource.id.value}',
    );
  }
  expect(
    document.elements.backgroundElementIds.map((id) => id.value),
    oracle.backgroundIds,
    reason: '$reason background order',
  );
  expect(
    document.elements.layerTable.rows.map((row) => row.id.value),
    oracle.layerIds,
    reason: '$reason layer order',
  );
  for (final layerId in oracle.layerIds) {
    final row = document.elements.layerTable
        .locationFor(CanvasLayerId(layerId))
        ?.row;
    expect(row, isNotNull, reason: '$reason layer $layerId');
    expect(
      row?.elementIds.map((id) => id.value),
      oracle.contentByLayer[layerId],
      reason: '$reason content $layerId',
    );
  }
  final expectedFrame = oracle.frameIds.toList(growable: false);
  expect(
    document.elements.frameElementOrder.map((id) => id.value),
    expectedFrame,
    reason: '$reason frame order',
  );
  for (final entry in oracle.elements.entries) {
    final actual = document.elements.elementById(CanvasElementId(entry.key));
    expect(
      _sameElementFacts(actual, entry.value),
      isTrue,
      reason: '$reason element ${entry.key}',
    );
  }
  for (final (index, id) in expectedFrame.indexed) {
    expect(
      document.elements.frameOrderTokensById[CanvasElementId(id)],
      index,
      reason: '$reason token $id',
    );
    final location =
        document.elements.elementLocationFacts[CanvasElementId(id)];
    expect(location, isNotNull, reason: '$reason location $id');
    final expectedBackground = oracle.backgroundIds.contains(id);
    expect(
      location?.kind.name,
      expectedBackground ? 'background' : 'content',
      reason: '$reason location kind $id',
    );
  }
}

Type _descriptorTypeFor(CanvasResource resource) => switch (resource) {
  CanvasImageResource() => StoreImageResourceDescriptorFacts,
  CanvasVectorResource() => StoreVectorResourceDescriptorFacts,
};

String _appKeyOf(CanvasResource resource) =>
    (resource.source as CanvasAppKeyResourceSource).key;

bool _sameElementFacts(CanvasElement? left, CanvasElement right) {
  if (left == null ||
      left.runtimeType != right.runtimeType ||
      left.id != right.id ||
      left.revision != right.revision) {
    return false;
  }
  return switch ((left, right)) {
    (
      CanvasImageElement(
        resourceId: final leftResourceId,
        size: final leftSize,
      ),
      CanvasImageElement(
        resourceId: final rightResourceId,
        size: final rightSize,
      ),
    ) =>
      leftResourceId == rightResourceId && leftSize == rightSize,
    (
      CanvasVectorElement(
        resourceId: final leftResourceId,
        size: final leftSize,
      ),
      CanvasVectorElement(
        resourceId: final rightResourceId,
        size: final rightSize,
      ),
    ) =>
      leftResourceId == rightResourceId && leftSize == rightSize,
    (
      CanvasRectElement(size: final leftSize),
      CanvasRectElement(size: final rightSize),
    ) =>
      leftSize == rightSize,
    _ => left == right,
  };
}

bool _samePalette(CanvasPalette left, CanvasPalette right) =>
    _sameList(left.penColors, right.penColors) &&
    _sameList(left.backgroundColors, right.backgroundColors) &&
    _sameList(left.gridSizes, right.gridSizes);

bool _sameResourceMap(
  Map<String, CanvasResource> left,
  Map<String, CanvasResource> right,
) {
  if (!_sameList(left.keys, right.keys)) {
    return false;
  }
  for (final id in left.keys) {
    final before = left[id];
    final after = right[id];
    if (before == null ||
        after == null ||
        before.runtimeType != after.runtimeType ||
        _appKeyOf(before) != _appKeyOf(after)) {
      return false;
    }
  }
  return true;
}

bool _sameElementMap(
  Map<String, CanvasElement> left,
  Map<String, CanvasElement> right,
) {
  if (!_sameList(left.keys, right.keys)) {
    return false;
  }
  for (final id in left.keys) {
    final before = left[id];
    final after = right[id];
    if (before == null || after == null || !_sameElementFacts(before, after)) {
      return false;
    }
  }
  return true;
}

bool _sameContent(
  Map<String, List<String>> left,
  Map<String, List<String>> right,
) {
  if (!_sameList(left.keys, right.keys)) {
    return false;
  }
  return left.keys.every((id) => _sameList(left[id]!, right[id]!));
}

bool _sameList<T>(Iterable<T> left, Iterable<T> right) {
  final leftIterator = left.iterator;
  final rightIterator = right.iterator;
  while (leftIterator.moveNext()) {
    if (!rightIterator.moveNext() ||
        leftIterator.current != rightIterator.current) {
      return false;
    }
  }
  return !rightIterator.moveNext();
}

// Compensation leaves temporary rows only in the admitted ledger. The oracle
// spells every accepted-delta and touched-fact field out so mutation history
// cannot become an accidental final-facts authority.
// One transaction intentionally groups compensation, overwrite/removal,
// placement, clear, and relationship facts into one final immutable witness.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _candidateAcceptedFactsOracle() {
  final base = CommittedDocument(_candidateBaseDocument());
  final store = DocumentStoreKernel.withCommittedDocumentForTesting(base);
  final events = <StoreSparseCandidateEvent>[];
  final prepared = CommittedDocument.observeSparseCandidateEvents(
    events.add,
    () => store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: _allFactsDelta,
        mutations: [
          StoreSparseUpsertResource(_imageResource('r-image-0', 'changed')),
          StoreSparseUpsertResource(_imageResource('r-image-0', 'image-0')),
          StoreSparseRemoveElement(CanvasElementId('image-base')),
          StoreSparseSetCamera(CanvasCamera(offset: const Offset(5, 6))),
        ],
      ),
    ),
  );

  expect(prepared.hasChanges, isTrue);
  _expectExactDelta(
    prepared.revisionDelta,
    const StoreRevisionDelta(
      document: true,
      projection: true,
      structural: true,
      bounds: true,
      elementVisual: true,
    ),
  );
  _expectExactTouchedFacts(
    prepared.touchedFacts,
    removed: {CanvasElementId('image-base')},
    selectionPrune: {CanvasElementId('image-base')},
    layers: {CanvasLayerId('layer-a')},
    persistedCamera: true,
  );
  _expectAggregateBeforeTouched(events);
  expect(
    () => prepared.document.resourceTable.descriptors.clear(),
    throwsUnsupportedError,
  );
  expect(
    () => prepared.document.elements.backgroundElementIds.add(
      CanvasElementId('alias'),
    ),
    throwsUnsupportedError,
  );
  final placementStore = documentStoreWithDocument(_candidateBaseDocument());
  final placementEvents = <StoreSparseCandidateEvent>[];
  final placement = CommittedDocument.observeSparseCandidateEvents(
    placementEvents.add,
    () => placementStore.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: _allFactsDelta,
        mutations: [
          StoreSparseUpdateElement(
            before: _rect('rect-a'),
            element: CanvasRectElement(
              id: CanvasElementId('rect-a'),
              size: const Size(1, 1),
              fillColor: const Color(0xFF112233),
              revision: 1,
            ),
            elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
          ),
          StoreSparseRemoveElement(CanvasElementId('rect-a')),
          StoreSparseRemoveElement(CanvasElementId('image-base')),
          StoreSparseAddElement(
            element: CanvasImageElement(
              id: CanvasElementId('image-base'),
              resourceId: CanvasResourceId('r-image-0'),
              size: const Size(1, 1),
            ),
            background: true,
          ),
          const StoreSparseClearContent(removeUnusedResources: true),
        ],
      ),
    ),
  );
  _expectExactDelta(
    placement.revisionDelta,
    const StoreRevisionDelta(
      document: true,
      projection: true,
      structural: true,
      bounds: true,
      elementVisual: true,
      resource: true,
    ),
  );
  _expectExactTouchedFacts(
    placement.touchedFacts,
    removed: {CanvasElementId('rect-a'), CanvasElementId('vector-base')},
    selectionPrune: {CanvasElementId('rect-a'), CanvasElementId('vector-base')},
    descriptors: {
      CanvasResourceId('r-image-1'),
      CanvasResourceId('r-vector-0'),
    },
    resourceVisual: {CanvasResourceId('r-vector-0')},
    layers: {CanvasLayerId('layer-a'), CanvasLayerId('layer-b')},
    backgroundLayerChanged: true,
  );
  expect(placement.admittedElementIds, ['image-base']);
  expect(placement.admittedLayerIds, isEmpty);
  expect(placement.admittedResourceIds, isEmpty);
  expect(
    placement
        .document
        .elements
        .elementLocationFacts[CanvasElementId('image-base')]
        ?.kind,
    ElementLocationKind.background,
  );
  expect(
    placement.document.elements.referencesResource(
      CanvasResourceId('r-image-0'),
    ),
    isTrue,
    reason: 'final relationship remains valid after remove/re-add and clear',
  );
  _expectAggregateBeforeTouched(placementEvents);
}

void _expectExactDelta(StoreRevisionDelta actual, StoreRevisionDelta expected) {
  expect(actual.document, expected.document);
  expect(actual.projection, expected.projection);
  expect(actual.structural, expected.structural);
  expect(actual.bounds, expected.bounds);
  expect(actual.elementVisual, expected.elementVisual);
  expect(actual.background, expected.background);
  expect(actual.grid, expected.grid);
  expect(actual.resource, expected.resource);
}

// The result type intentionally exposes every stable touched field here.
// ignore: number-of-parameters
void _expectExactTouchedFacts(
  AcceptedStoreTouchedFacts actual, {
  Set<CanvasElementId> added = const {},
  Set<CanvasElementId> removed = const {},
  Set<CanvasElementId> updated = const {},
  Set<CanvasElementId> transformed = const {},
  Set<CanvasElementId> geometry = const {},
  Set<CanvasElementId> visual = const {},
  Set<CanvasElementId> selectionPrune = const {},
  Set<CanvasResourceId> descriptors = const {},
  Set<CanvasResourceId> resourceVisual = const {},
  Set<CanvasLayerId> layers = const {},
  bool backgroundLayerChanged = false,
  bool persistedCamera = false,
  bool background = false,
  bool grid = false,
  bool palette = false,
}) {
  expect(actual.addedElementIds, added);
  expect(actual.removedElementIds, removed);
  expect(actual.updatedElementIds, updated);
  expect(actual.transformedElementIds, transformed);
  expect(actual.geometryElementIds, geometry);
  expect(actual.visualElementIds, visual);
  expect(actual.selectionPruneElementIds, selectionPrune);
  expect(actual.resourceDescriptorChangedIds, descriptors);
  expect(actual.resourceVisualChangedIds, resourceVisual);
  expect(actual.layerIds, layers);
  expect(actual.backgroundLayerChanged, backgroundLayerChanged);
  expect(actual.persistedCamera, persistedCamera);
  expect(actual.background, background);
  expect(actual.grid, grid);
  expect(actual.palette, palette);
}

void _expectAggregateBeforeTouched(List<StoreSparseCandidateEvent> events) {
  final aggregate = events.indexWhere(
    (event) => event.kind == StoreSparseCandidateEventKind.aggregatePublication,
  );
  final touched = events.indexWhere(
    (event) => event.kind == StoreSparseCandidateEventKind.touchedFacts,
  );
  expect(aggregate, greaterThanOrEqualTo(0));
  expect(touched, greaterThan(aggregate));
}

// Each case observes the same candidate seam while retaining only external
// Store facts. The events are production owner reports, not fixture controls.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _candidateFailureAndAliasMatrix() {
  final rect = _rect('rect-a');
  final invalidRect = CanvasRectElement(
    id: rect.id,
    size: rect.size,
    fillColor: const Color(0xFF112233),
    revision: 3,
  );
  final image = CanvasImageElement(
    id: CanvasElementId('image-base'),
    resourceId: CanvasResourceId('r-image-0'),
    size: const Size(1, 1),
  );
  final invalidImage = CanvasImageElement(
    id: image.id,
    resourceId: image.resourceId,
    size: image.size,
    revision: 4,
  );
  final cases = <_CandidateFailureCase>[
    _CandidateFailureCase(
      name: 'relationship before invalid provided delta',
      revisionDelta: const StoreRevisionDelta(document: true),
      mutations: [
        StoreSparseAddElement(
          element: CanvasImageElement(
            id: CanvasElementId('missing-resource'),
            resourceId: CanvasResourceId('missing'),
            size: const Size(1, 1),
          ),
          layerId: CanvasLayerId('layer-a'),
        ),
      ],
      error: isA<CanvasDataException>()
          .having(
            (error) => error.code,
            'code',
            CanvasDataErrorCode.missingResourceReference,
          )
          .having(
            (error) => error.message,
            'message',
            'resource element references a missing resource.',
          )
          .having((error) => error.path, 'path', 'image.resourceId'),
      phases: const [
        StoreSparseCandidateEventKind.relationshipValidation,
        StoreSparseCandidateEventKind.discard,
      ],
    ),
    _CandidateFailureCase(
      name: 'provided delta before deferred validation',
      revisionDelta: const StoreRevisionDelta(document: true),
      mutations: [
        StoreSparseUpdateElement(
          before: rect,
          element: invalidRect,
          elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
        ),
      ],
      error: isA<ArgumentError>()
          .having((error) => error.name, 'name', 'revisionDelta')
          .having(
            (error) => error.message,
            'message',
            'sparse committed fact changes must invalidate public projection.',
          ),
      phases: const [
        StoreSparseCandidateEventKind.relationshipValidation,
        StoreSparseCandidateEventKind.providedDeltaValidation,
        StoreSparseCandidateEventKind.discard,
      ],
    ),
    _CandidateFailureCase(
      name: 'first deferred validation wins journal order',
      revisionDelta: const StoreRevisionDelta.background(),
      mutations: [
        StoreSparseUpdateElement(
          before: rect,
          element: invalidRect,
          elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
        ),
        StoreSparseUpdateElement(
          before: image,
          element: invalidImage,
          elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
        ),
      ],
      error: isA<ArgumentError>()
          .having((error) => error.name, 'name', 'element.revision')
          .having((error) => error.invalidValue, 'invalidValue', 3)
          .having(
            (error) => error.message,
            'message',
            'sparse element updates must carry the next committed element revision.',
          ),
      phases: const [
        StoreSparseCandidateEventKind.relationshipValidation,
        StoreSparseCandidateEventKind.providedDeltaValidation,
        StoreSparseCandidateEventKind.deferredValidation,
        StoreSparseCandidateEventKind.discard,
      ],
    ),
    _CandidateFailureCase(
      name: 'coverage before normalization and publication',
      revisionDelta: const StoreRevisionDelta.projectionOnly(),
      mutations: const [
        StoreSparseSetBackground(CanvasBackground(color: Color(0xFF112233))),
      ],
      error: isA<ArgumentError>()
          .having((error) => error.name, 'name', 'revisionDelta')
          .having(
            (error) => error.message,
            'message',
            'sparse revision delta does not cover changed committed facts.',
          ),
      phases: const [
        StoreSparseCandidateEventKind.relationshipValidation,
        StoreSparseCandidateEventKind.providedDeltaValidation,
        StoreSparseCandidateEventKind.deferredValidation,
        StoreSparseCandidateEventKind.acceptedFacts,
        StoreSparseCandidateEventKind.coverageValidation,
        StoreSparseCandidateEventKind.discard,
      ],
    ),
  ];
  for (final entry in cases) {
    final base = CommittedDocument(_candidateBaseDocument());
    final store = DocumentStoreKernel.withCommittedDocumentForTesting(base);
    final events = <StoreSparseCandidateEvent>[];
    final resourceEvents = <ResourceTableSelectiveMutationEvent>[];
    final structuralEvents = <ElementRegistryStructuralEditorWorkEvent>[];
    final familyWork = FamilyTablesTelemetry();
    final beforeId = store.observeElementIdCandidateForTesting();
    final beforeDocument = base;
    final beforeElements = base.elements;
    final beforeFamilies = base.elements.familyTables;
    final beforeResources = base.resourceTable;
    final beforeRevisions = (
      document: store.documentRevision,
      structural: store.structuralRevision,
      resource: store.resourceRevision,
    );
    expect(
      () => FamilyTables.observeTelemetry(
        familyWork.record,
        () => ResourceTableEditor.observeWork(
          resourceEvents.add,
          () => ElementRegistry.observeSparseStructuralEditorWork(
            structuralEvents.add,
            () => CommittedDocument.observeSparseCandidateEvents(
              events.add,
              () => store.prepareSparseCommit(
                StoreSparseCommit(
                  revisionDelta: entry.revisionDelta,
                  mutations: entry.mutations,
                ),
              ),
            ),
          ),
        ),
      ),
      throwsA(entry.error),
      reason: entry.name,
    );
    expect(
      store.documentRevision,
      beforeRevisions.document,
      reason: entry.name,
    );
    expect(
      store.structuralRevision,
      beforeRevisions.structural,
      reason: entry.name,
    );
    expect(
      store.resourceRevision,
      beforeRevisions.resource,
      reason: entry.name,
    );
    expect(base, same(beforeDocument), reason: '${entry.name} base object');
    expect(
      base.elements,
      same(beforeElements),
      reason: '${entry.name} elements',
    );
    expect(
      base.elements.familyTables,
      same(beforeFamilies),
      reason: '${entry.name} family owner',
    );
    expect(
      base.resourceTable,
      same(beforeResources),
      reason: '${entry.name} resource owner',
    );
    expect(
      store.elementIds.map((id) => id.value),
      beforeElements.frameElementOrder.map((id) => id.value),
      reason: '${entry.name} base order',
    );
    expect(
      store.resourceIds.map((id) => id.value),
      beforeResources.descriptors.keys.map((id) => id.value),
      reason: '${entry.name} base descriptors',
    );
    expect(
      store.observeElementIdCandidateForTesting(),
      beforeId,
      reason: entry.name,
    );
    expect(
      store.generateElementId(),
      CanvasElementId('e0'),
      reason: entry.name,
    );
    expect(store.generateLayerId(), CanvasLayerId('l0'), reason: entry.name);
    expect(
      store.generateResourceId(),
      CanvasResourceId('r0'),
      reason: entry.name,
    );
    expect(store.projectionBuildCount, 0, reason: entry.name);
    _expectCandidatePhasePrefix(events, entry.phases, reason: entry.name);
    expect(
      events.where(
        (event) =>
            event.kind == StoreSparseCandidateEventKind.aggregatePublication,
      ),
      isEmpty,
      reason: entry.name,
    );
    expect(
      resourceEvents.where(
        (event) => event.kind == ResourceTableEditorWorkKind.discard,
      ),
      hasLength(1),
      reason: entry.name,
    );
    expect(
      structuralEvents.where(
        (event) =>
            event.kind == ElementRegistryStructuralEditorWorkKind.discard,
      ),
      hasLength(1),
      reason: entry.name,
    );
    expect(familyWork.transactionDiscardCount, 1, reason: entry.name);
  }

  final store = documentStoreWithDocument(_candidateBaseDocument());
  final stalePreparationEvents = <StoreSparseCandidateEvent>[];
  final prepared = CommittedDocument.observeSparseCandidateEvents(
    stalePreparationEvents.add,
    () => store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.background(),
        mutations: const [
          StoreSparseSetBackground(CanvasBackground(color: Color(0xFF112233))),
        ],
      ),
    ),
  );
  expect(prepared.hasChanges, isTrue);
  _expectAggregateBeforeTouched(stalePreparationEvents);
  expect(
    stalePreparationEvents.where(
      (event) =>
          event.kind == StoreSparseCandidateEventKind.aggregatePublication,
    ),
    hasLength(1),
    reason: 'stale installation can only reject an already complete aggregate',
  );
  final later = store.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.background(),
      mutations: const [
        StoreSparseSetBackground(CanvasBackground(color: Color(0xFF445566))),
      ],
    ),
  );
  store.installSparseCommit(later);
  final beforeStaleId = store.observeElementIdCandidateForTesting();
  expect(() => store.installSparseCommit(prepared), throwsStateError);
  expect(store.background.color, const Color(0xFF445566));
  expect(store.observeElementIdCandidateForTesting(), beforeStaleId);
}

final class _CandidateFailureCase {
  const _CandidateFailureCase({
    required this.name,
    required this.revisionDelta,
    required this.mutations,
    required this.error,
    required this.phases,
  });

  final String name;
  final StoreRevisionDelta revisionDelta;
  final List<StoreSparseMutation> mutations;
  final Matcher error;
  final List<StoreSparseCandidateEventKind> phases;
}

void _expectCandidatePhasePrefix(
  List<StoreSparseCandidateEvent> events,
  List<StoreSparseCandidateEventKind> expected, {
  required String reason,
}) {
  final actual = [
    for (final event in events)
      if (event.kind.index >=
          StoreSparseCandidateEventKind.relationshipValidation.index)
        event.kind,
  ];
  expect(actual, expected, reason: reason);
}

enum _CandidateWorkBoundary {
  relationshipPhase,
  familyRelationship,
  providedDeltaPhase,
  deferredValidationPhase,
  structuralFinalTraversal,
  acceptedFactsPhase,
  familyAcceptedDelta,
  coveragePhase,
  normalizationPhase,
  familyFreezePhase,
  familyFreeze,
  familyPublication,
  resourceNormalization,
  resourceFreezePhase,
  resourceFreeze,
  resourcePublication,
  structuralPublicationPhase,
  structuralPublication,
  aggregatePublication,
  touchedFacts,
  consume,
}

// This exhaustive mapping is one candidate protocol. Keeping it together
// makes a newly added lifecycle event compile-visible to the work witness.
// ignore: cyclomatic-complexity
void _recordCandidateWorkBoundary(
  List<_CandidateWorkBoundary> timeline,
  StoreSparseCandidateEvent event,
) {
  final boundary = switch (event.kind) {
    StoreSparseCandidateEventKind.relationshipValidation =>
      _CandidateWorkBoundary.relationshipPhase,
    StoreSparseCandidateEventKind.providedDeltaValidation =>
      _CandidateWorkBoundary.providedDeltaPhase,
    StoreSparseCandidateEventKind.deferredValidation =>
      _CandidateWorkBoundary.deferredValidationPhase,
    StoreSparseCandidateEventKind.acceptedFacts =>
      _CandidateWorkBoundary.acceptedFactsPhase,
    StoreSparseCandidateEventKind.coverageValidation =>
      _CandidateWorkBoundary.coveragePhase,
    StoreSparseCandidateEventKind.normalization =>
      _CandidateWorkBoundary.normalizationPhase,
    StoreSparseCandidateEventKind.familyFreeze =>
      _CandidateWorkBoundary.familyFreezePhase,
    StoreSparseCandidateEventKind.resourceFreeze =>
      _CandidateWorkBoundary.resourceFreezePhase,
    StoreSparseCandidateEventKind.structuralPublication =>
      _CandidateWorkBoundary.structuralPublicationPhase,
    StoreSparseCandidateEventKind.aggregatePublication =>
      _CandidateWorkBoundary.aggregatePublication,
    StoreSparseCandidateEventKind.touchedFacts =>
      _CandidateWorkBoundary.touchedFacts,
    StoreSparseCandidateEventKind.consume => _CandidateWorkBoundary.consume,
    StoreSparseCandidateEventKind.open ||
    StoreSparseCandidateEventKind.currentScalarRead ||
    StoreSparseCandidateEventKind.touchedElementRead ||
    StoreSparseCandidateEventKind.touchedResourceRead ||
    StoreSparseCandidateEventKind.discard => null,
  };
  if (boundary != null) {
    timeline.add(boundary);
  }
}

void _recordFamilyWorkBoundary(
  List<_CandidateWorkBoundary> timeline,
  Set<_CandidateWorkBoundary> seen,
  FamilyTablesTelemetryEvent event,
) {
  final boundary = switch (event.kind) {
    FamilyTablesTelemetryKind.editorDecision
        when event.decision == FamilyTablesDecision.relationship =>
      _CandidateWorkBoundary.familyRelationship,
    FamilyTablesTelemetryKind.editorDecision
        when event.decision == FamilyTablesDecision.acceptedDelta =>
      _CandidateWorkBoundary.familyAcceptedDelta,
    FamilyTablesTelemetryKind.transactionFamilyFreeze =>
      _CandidateWorkBoundary.familyFreeze,
    FamilyTablesTelemetryKind.transactionImmutablePublication =>
      _CandidateWorkBoundary.familyPublication,
    _ => null,
  };
  _appendOwnerBoundary(timeline, seen, boundary);
}

void _recordResourceWorkBoundary(
  List<_CandidateWorkBoundary> timeline,
  Set<_CandidateWorkBoundary> seen,
  ResourceTableSelectiveMutationEvent event,
) {
  final boundary = switch (event.kind) {
    ResourceTableEditorWorkKind.normalizationRead =>
      _CandidateWorkBoundary.resourceNormalization,
    ResourceTableEditorWorkKind.freeze => _CandidateWorkBoundary.resourceFreeze,
    ResourceTableEditorWorkKind.immutablePublication =>
      _CandidateWorkBoundary.resourcePublication,
    _ => null,
  };
  _appendOwnerBoundary(timeline, seen, boundary);
}

void _recordStructuralWorkBoundary(
  List<_CandidateWorkBoundary> timeline,
  Set<_CandidateWorkBoundary> seen,
  ElementRegistryStructuralEditorWorkEvent event,
) {
  final boundary = switch (event.kind) {
    ElementRegistryStructuralEditorWorkKind.finalTraversalVisit =>
      _CandidateWorkBoundary.structuralFinalTraversal,
    ElementRegistryStructuralEditorWorkKind.frameOrderPublication =>
      _CandidateWorkBoundary.structuralPublication,
    _ => null,
  };
  _appendOwnerBoundary(timeline, seen, boundary);
}

void _appendOwnerBoundary(
  List<_CandidateWorkBoundary> timeline,
  Set<_CandidateWorkBoundary> seen,
  _CandidateWorkBoundary? boundary,
) {
  if (boundary != null && seen.add(boundary)) {
    timeline.add(boundary);
  }
}

void _expectCandidateWorkTimeline(List<_CandidateWorkBoundary> timeline) {
  expect(timeline, const [
    _CandidateWorkBoundary.relationshipPhase,
    _CandidateWorkBoundary.familyRelationship,
    _CandidateWorkBoundary.providedDeltaPhase,
    _CandidateWorkBoundary.deferredValidationPhase,
    _CandidateWorkBoundary.structuralFinalTraversal,
    _CandidateWorkBoundary.acceptedFactsPhase,
    _CandidateWorkBoundary.familyAcceptedDelta,
    _CandidateWorkBoundary.coveragePhase,
    _CandidateWorkBoundary.normalizationPhase,
    _CandidateWorkBoundary.familyFreezePhase,
    _CandidateWorkBoundary.familyFreeze,
    _CandidateWorkBoundary.familyPublication,
    _CandidateWorkBoundary.resourceNormalization,
    _CandidateWorkBoundary.resourceFreezePhase,
    _CandidateWorkBoundary.resourceFreeze,
    _CandidateWorkBoundary.resourcePublication,
    _CandidateWorkBoundary.structuralPublicationPhase,
    _CandidateWorkBoundary.structuralPublication,
    _CandidateWorkBoundary.aggregatePublication,
    _CandidateWorkBoundary.touchedFacts,
    _CandidateWorkBoundary.consume,
  ]);
}

// This supported-size witness composes owner-provided event seams. The large
// order is compared once at finalization; the seeded prefix oracle above owns
// small-step semantics and avoids turning this work proof into O(M * K).
// ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index
void _candidatePublicationWork() {
  final base = CommittedDocument(_supportedCandidateDocument());
  final adversarialAggregateEvents = <StoreSparseCandidateEvent>[];
  final adversarialIntermediate =
      CommittedDocument.observeSparseCandidateEvents(
        adversarialAggregateEvents.add,
        () => base.copyWith(
          background: const CanvasBackground(color: Color(0xFF102030)),
        ),
      );
  expect(adversarialIntermediate.background.color, const Color(0xFF102030));
  expect(
    adversarialAggregateEvents
        .where(
          (event) =>
              event.kind == StoreSparseCandidateEventKind.aggregatePublication,
        )
        .toList(growable: false),
    hasLength(1),
    reason:
        'every immutable aggregate construction, including an intermediate copyWith, is observable',
  );
  final store = DocumentStoreKernel.withCommittedDocumentForTesting(base);
  final resourceEvents = <ResourceTableSelectiveMutationEvent>[];
  final structuralEvents = <ElementRegistryStructuralEditorWorkEvent>[];
  final sequenceEvents = <IndexedOrderSequenceWorkEvent>[];
  final candidateEvents = <StoreSparseCandidateEvent>[];
  final journalEvents = <SparseTransactionWorkEvent>[];
  final admissionEvents = <IdAdmissionWorkEvent>[];
  final familyWork = FamilyTablesTelemetry();
  final timeline = <_CandidateWorkBoundary>[];
  final ownerBoundaries = <_CandidateWorkBoundary>{};
  final mutations = <StoreSparseMutation>[
    StoreSparseRemoveElement(CanvasElementId('rect-0')),
    StoreSparseRemoveElement(CanvasElementId('rect-1')),
    StoreSparseUpsertResource(_imageResource('r-image', 'changed-image')),
    StoreSparseAddElement(
      element: CanvasImageElement(
        id: CanvasElementId('image-added'),
        resourceId: CanvasResourceId('r-image'),
        size: const Size(1, 1),
      ),
      layerId: CanvasLayerId('large-layer'),
      index: 0,
    ),
    StoreSparseAddElement(
      element: CanvasVectorElement(
        id: CanvasElementId('vector-added'),
        resourceId: CanvasResourceId('r-vector'),
        size: const Size(1, 1),
      ),
      layerId: CanvasLayerId('large-layer'),
      index: 999,
    ),
  ];
  late PreparedSparseStoreCommit prepared;
  FamilyTables.observeTelemetry(
    (event) {
      familyWork.record(event);
      _recordFamilyWorkBoundary(timeline, ownerBoundaries, event);
    },
    () => ResourceTableEditor.observeWork(
      (event) {
        resourceEvents.add(event);
        _recordResourceWorkBoundary(timeline, ownerBoundaries, event);
      },
      () => ElementRegistry.observeSparseStructuralEditorWork(
        (event) {
          structuralEvents.add(event);
          _recordStructuralWorkBoundary(timeline, ownerBoundaries, event);
        },
        () => IndexedOrderSequence.observeWork(
          sequenceEvents.add,
          () => DocumentStoreKernel.observeSparseTransactionWork(
            journalEvents.add,
            () => DocumentStoreKernel.observeIdAdmissionWork(
              admissionEvents.add,
              () => CommittedDocument.observeSparseCandidateEvents(
                (event) {
                  candidateEvents.add(event);
                  _recordCandidateWorkBoundary(timeline, event);
                },
                () {
                  prepared = store.prepareSparseCommit(
                    StoreSparseCommit(
                      revisionDelta: _allFactsDelta,
                      mutations: mutations,
                    ),
                  );
                  store.installSparseCommit(prepared);
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );

  final replayVisits = journalEvents.where(
    (event) =>
        event.phase == SparseTransactionWorkPhase.replay &&
        event.kind == SparseTransactionWorkKind.journalVisit,
  );
  expect(replayVisits.map((event) => event.journalIndex), [0, 1, 2, 3, 4]);
  expect(
    journalEvents.where(
      (event) =>
          event.phase == SparseTransactionWorkPhase.finalization &&
          event.kind == SparseTransactionWorkKind.journalVisit,
    ),
    isEmpty,
  );
  expect(
    resourceEvents.where(
      (event) => event.kind == ResourceTableEditorWorkKind.editorOpen,
    ),
    hasLength(1),
  );
  expect(
    resourceEvents
        .where(
          (event) =>
              event.kind == ResourceTableEditorWorkKind.normalizationRead,
        )
        .map((event) => event.id),
    [CanvasResourceId('r-image')],
    reason: 'normalization reads exactly the changed R ledger',
  );
  expect(
    resourceEvents
        .where(
          (event) =>
              event.kind == ResourceTableEditorWorkKind.normalizationWrite,
        )
        .map((event) => event.id),
    [CanvasResourceId('r-image')],
    reason: 'normalization writes exactly the changed R ledger',
  );
  expect(
    resourceEvents.where(
      (event) => event.kind == ResourceTableEditorWorkKind.freeze,
    ),
    hasLength(1),
  );
  expect(
    resourceEvents.where(
      (event) =>
          event.kind ==
          ResourceTableEditorWorkKind.materializationBaseEntryVisit,
    ),
    hasLength(canvasMaxResources),
  );
  expect(
    structuralEvents.where(
      (event) =>
          event.kind == ElementRegistryStructuralEditorWorkKind.editorOpen,
    ),
    hasLength(1),
  );
  expect(
    structuralEvents.where(
      (event) =>
          event.kind ==
              ElementRegistryStructuralEditorWorkKind.finalTraversalVisit &&
          event.order == ElementRegistryStructuralOrderKind.content,
    ),
    hasLength(canvasMaxTotalElements),
  );
  expect(
    sequenceEvents.where(
      (event) => event == IndexedOrderSequenceWorkEvent.buildOpen,
    ),
    hasLength(1),
  );
  expect(
    sequenceEvents.where(
      (event) => event == IndexedOrderSequenceWorkEvent.buildInputVisit,
    ),
    hasLength(canvasMaxTotalElements),
  );
  expect(
    sequenceEvents.where(
      (event) => event == IndexedOrderSequenceWorkEvent.orderedIterationVisit,
    ),
    hasLength(canvasMaxTotalElements),
  );
  for (final kind in CanvasElementKind.values) {
    final affected =
        kind == CanvasElementKind.image ||
        kind == CanvasElementKind.vector ||
        kind == CanvasElementKind.rect;
    expect(
      familyWork.transactionOpenCount(kind),
      affected ? 1 : 0,
      reason: '$kind family rows open only for the affected owner',
    );
    expect(
      familyWork.transactionFreezeCount(kind),
      affected ? 1 : 0,
      reason: '$kind family rows freeze at most once',
    );
  }
  expect(
    familyWork.transactionBaseEntryCopyCount(CanvasElementKind.image),
    0,
    reason: 'new image family has no base-row copy',
  );
  expect(
    familyWork.transactionBaseEntryCopyCount(CanvasElementKind.vector),
    0,
    reason: 'new vector family has no base-row copy',
  );
  expect(
    familyWork.transactionBaseEntryCopyCount(CanvasElementKind.rect),
    canvasMaxTotalElements,
    reason: 'one rect family copy is bounded to its one opened owner',
  );
  expect(familyWork.transactionImmutablePublicationCount, 1);
  expect(familyWork.transactionIntermediateImmutablePublicationCount, 0);
  expect(familyWork.staleDecisionReadCount, 0);
  expect(familyWork.postFreezeWriteCount, 0);
  expect(familyWork.postFreezeCopyCount, 0);
  expect(familyWork.postFreezeNormalizationCount, 0);
  expect(familyWork.postFreezeImmutablePublicationCount, 0);
  expect(familyWork.referenceQueryFamilyRowVisitCount, 0);
  _expectCandidateWorkTimeline(timeline);
  expect(
    candidateEvents
        .where(
          (event) =>
              event.kind == StoreSparseCandidateEventKind.touchedElementRead,
        )
        .map(
          (event) => switch (event) {
            StoreSparseCandidateEvent(
              side: final side?,
              subject: final subject?,
            ) =>
              (side: side, subject: subject),
            _ => throw StateError('touched element lookup omitted its owner.'),
          },
        ),
    [
      (side: StoreSparseCandidateReadSide.base, subject: 'rect-0'),
      (side: StoreSparseCandidateReadSide.candidate, subject: 'rect-0'),
      (side: StoreSparseCandidateReadSide.base, subject: 'rect-1'),
      (side: StoreSparseCandidateReadSide.candidate, subject: 'rect-1'),
      (side: StoreSparseCandidateReadSide.base, subject: 'image-added'),
      (side: StoreSparseCandidateReadSide.candidate, subject: 'image-added'),
      (side: StoreSparseCandidateReadSide.base, subject: 'vector-added'),
      (side: StoreSparseCandidateReadSide.candidate, subject: 'vector-added'),
    ],
    reason: 'accepted touched facts perform each changed element owner lookup',
  );
  expect(
    candidateEvents
        .where(
          (event) =>
              event.kind == StoreSparseCandidateEventKind.touchedResourceRead,
        )
        .map(
          (event) => switch (event) {
            StoreSparseCandidateEvent(
              side: final side?,
              subject: final subject?,
            ) =>
              (side: side, subject: subject),
            _ => throw StateError('touched resource lookup omitted its owner.'),
          },
        ),
    [
      (side: StoreSparseCandidateReadSide.base, subject: 'r-image'),
      (side: StoreSparseCandidateReadSide.candidate, subject: 'r-image'),
    ],
    reason: 'accepted touched facts perform each changed resource owner lookup',
  );
  expect(store.projectionBuildCount, 0);
  expect(
    admissionEvents
        .where(
          (event) =>
              event.phase == IdAdmissionWorkPhase.acceptedAdmission &&
              event.kind == IdAdmissionWorkKind.sparseLedgerVisit,
        )
        .map((event) => event.subject),
    [
      ...prepared.admittedElementIds,
      ...prepared.admittedLayerIds,
      ...prepared.admittedResourceIds,
    ],
  );
  expect(
    prepared.document.resourceDescriptor(CanvasResourceId('r-4095')),
    same(base.resourceDescriptor(CanvasResourceId('r-4095'))),
  );
  expect(
    prepared.document.elements.backgroundElementIds,
    same(base.elements.backgroundElementIds),
  );
  expect(
    prepared.document.elements.layerTable
        .locationFor(CanvasLayerId('untouched-layer'))
        ?.row,
    same(
      base.elements.layerTable
          .locationFor(CanvasLayerId('untouched-layer'))
          ?.row,
    ),
    reason: 'the untouched layer row retains its base identity',
  );
  expect(
    resourceEvents.where(
      (event) => event.kind == ResourceTableEditorWorkKind.postClosureAccess,
    ),
    isEmpty,
  );
  expect(
    structuralEvents.where(
      (event) =>
          event.kind ==
          ElementRegistryStructuralEditorWorkKind.postClosureAttempt,
    ),
    isEmpty,
  );
  final expectedOrder = <String>[
    'image-added',
    for (var index = 2; index < 1000; index += 1) 'rect-$index',
    'vector-added',
    for (var index = 1000; index < canvasMaxTotalElements; index += 1)
      'rect-$index',
  ];
  expect(
    store.elementIds.map((id) => id.value),
    expectedOrder,
    reason: 'supported-size final content order',
  );
  _expectTerminalCandidateWork();
  expect(
    candidateEvents.where(
      (event) =>
          event.kind == StoreSparseCandidateEventKind.aggregatePublication,
    ),
    hasLength(1),
  );
}

// The work witness owns the terminal no-op lifecycle. The failure matrix above
// owns all semantic preparation gates, including late coverage failure.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _expectTerminalCandidateWork() {
  final noOpStore = documentStoreWithDocument(_candidateBaseDocument());
  final noOpEvents = <StoreSparseCandidateEvent>[];
  final noOpResourceEvents = <ResourceTableSelectiveMutationEvent>[];
  final noOpStructuralEvents = <ElementRegistryStructuralEditorWorkEvent>[];
  final noOpFamilyWork = FamilyTablesTelemetry();
  final noOp = FamilyTables.observeTelemetry(
    noOpFamilyWork.record,
    () => ResourceTableEditor.observeWork(
      noOpResourceEvents.add,
      () => ElementRegistry.observeSparseStructuralEditorWork(
        noOpStructuralEvents.add,
        () => CommittedDocument.observeSparseCandidateEvents(
          noOpEvents.add,
          () => noOpStore.prepareSparseCommit(
            StoreSparseCommit(
              revisionDelta: _allFactsDelta,
              mutations: const [StoreSparseSetCamera(CanvasCamera.origin)],
            ),
          ),
        ),
      ),
    ),
  );
  expect(noOp.hasChanges, isFalse);
  _expectCandidatePhasePrefix(noOpEvents, const [
    StoreSparseCandidateEventKind.relationshipValidation,
    StoreSparseCandidateEventKind.providedDeltaValidation,
    StoreSparseCandidateEventKind.deferredValidation,
    StoreSparseCandidateEventKind.acceptedFacts,
    StoreSparseCandidateEventKind.discard,
  ], reason: 'final no-op phase order');
  expect(
    noOpEvents.where(
      (event) =>
          event.kind == StoreSparseCandidateEventKind.aggregatePublication,
    ),
    isEmpty,
  );
  expect(
    noOpResourceEvents.where(
      (event) =>
          event.kind == ResourceTableEditorWorkKind.normalizationRead ||
          event.kind == ResourceTableEditorWorkKind.freeze ||
          event.kind == ResourceTableEditorWorkKind.immutablePublication,
    ),
    isEmpty,
  );
  expect(
    noOpStructuralEvents.where(
      (event) =>
          event.kind ==
              ElementRegistryStructuralEditorWorkKind.contentOrderPublication ||
          event.kind ==
              ElementRegistryStructuralEditorWorkKind.frameOrderPublication,
    ),
    isEmpty,
  );
  expect(
    noOpResourceEvents.where(
      (event) => event.kind == ResourceTableEditorWorkKind.discard,
    ),
    hasLength(1),
  );
  expect(
    noOpStructuralEvents.where(
      (event) => event.kind == ElementRegistryStructuralEditorWorkKind.discard,
    ),
    hasLength(1),
  );
  expect(noOpFamilyWork.transactionDiscardCount, 1);
}

CanvasDocument _supportedCandidateDocument() => CanvasDocument(
  resources: [
    _imageResource('r-image', 'image'),
    _vectorResource('r-vector', 'vector'),
    for (var index = 2; index < canvasMaxResources; index += 1)
      _imageResource('r-$index', 'resource-$index'),
  ],
  layers: [
    CanvasLayer(
      id: CanvasLayerId('large-layer'),
      elements: [
        for (var index = 0; index < canvasMaxTotalElements; index += 1)
          _rect('rect-$index'),
      ],
    ),
    CanvasLayer(id: CanvasLayerId('untouched-layer')),
  ],
);
