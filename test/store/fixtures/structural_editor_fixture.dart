import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_contract_limits.dart';
import 'package:iwb_canvas_engine/src/store/committed_document.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/element_registry.dart';
import 'package:iwb_canvas_engine/src/store/indexed_order_sequence.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

// This fixture observes the real structural-order owner across one direct
// sparse transaction. Its literal expectations deliberately do not derive
// order or work from the editor under test.
// The scenarios share a small independent oracle and lifecycle helpers; one
// fixture keeps their ordering evidence auditable instead of splitting it for
// metrics alone.
// ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index
void main() {
  test(
    'one affected content order opens and freezes once for a sparse transaction',
    () {
      final events = <IndexedOrderSequenceWorkEvent>[];
      final structuralEvents = <ElementRegistryStructuralEditorWorkEvent>[];
      ElementRegistry.observeSparseStructuralEditorWork(
        structuralEvents.add,
        () {
          IndexedOrderSequence.observeWork(events.add, () {
            _store().prepareSparseCommit(
              StoreSparseCommit(
                revisionDelta: const StoreRevisionDelta.structural(),
                mutations: [
                  _add('front', index: 0),
                  _add('middle', index: 2),
                  _add('end'),
                ],
              ),
            );
          });
        },
      );

      expect(events.where(_isBuildOpen), hasLength(1));
      expect(events.where(_isFinalPublication), isEmpty);
      expect(
        events.where(
          (event) =>
              event == IndexedOrderSequenceWorkEvent.orderedIterationVisit,
        ),
        hasLength(4),
      );
      expect(
        events.where((event) => event == IndexedOrderSequenceWorkEvent.discard),
        hasLength(1),
      );
      expect(
        events.where(
          (event) => event == IndexedOrderSequenceWorkEvent.buildInputVisit,
        ),
        hasLength(1),
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
              event.kind == ElementRegistryStructuralEditorWorkKind.orderOpen &&
              event.order == ElementRegistryStructuralOrderKind.content,
        ),
        hasLength(1),
      );
      expect(
        structuralEvents.where(
          (event) =>
              event.kind == ElementRegistryStructuralEditorWorkKind.orderOpen &&
              event.order != ElementRegistryStructuralOrderKind.content,
        ),
        isEmpty,
      );
      expect(
        structuralEvents.where(
          (event) =>
              event.kind ==
                  ElementRegistryStructuralEditorWorkKind.finalTraversalVisit &&
              event.order == ElementRegistryStructuralOrderKind.background,
        ),
        isEmpty,
      );
      expect(
        structuralEvents.where(
          (event) =>
              event.kind ==
                  ElementRegistryStructuralEditorWorkKind.finalTraversalVisit &&
              event.order == ElementRegistryStructuralOrderKind.layer,
        ),
        hasLength(2),
      );
      expect(
        structuralEvents.where(
          (event) =>
              event.kind ==
                  ElementRegistryStructuralEditorWorkKind.finalTraversalVisit &&
              event.order == ElementRegistryStructuralOrderKind.content,
        ),
        hasLength(5),
      );
      for (final kind in [
        ElementRegistryStructuralEditorWorkKind.layerRowsPublication,
        ElementRegistryStructuralEditorWorkKind.layerLocationsPublication,
        ElementRegistryStructuralEditorWorkKind.backgroundOrderPublication,
        ElementRegistryStructuralEditorWorkKind.contentOrderPublication,
        ElementRegistryStructuralEditorWorkKind.frameOrderPublication,
        ElementRegistryStructuralEditorWorkKind.frameTokenPublication,
        ElementRegistryStructuralEditorWorkKind.elementLocationPublication,
      ]) {
        expect(
          structuralEvents.where((event) => event.kind == kind),
          hasLength(1),
        );
      }
    },
  );
  test('current structural placement follows mixed sequential mutations', () {
    final base = _baseRegistry();
    ElementRegistry.editSparseStructure(base, (editor) {
      final oracle = _StructuralOracle.fromBase();
      void apply(_StructuralAction action) {
        action.applyToEditor(editor);
        action.applyToOracle(oracle);
        _expectCurrentEditorMatches(editor, oracle);
      }

      apply(const _EnsureLayer('inserted', index: 0));
      apply(const _AddBackground('background-first', index: -1));
      apply(const _AddContent('front', layerId: 'layer-a', index: -9));
      apply(const _AddContent('middle', layerId: 'layer-a', index: 2));
      apply(const _Remove('base-a'));
      apply(const _Remove('middle'));
      apply(const _AddBackground('middle', index: 1));
      apply(const _Remove('middle'));
      apply(const _AddContent('middle', layerId: 'layer-b', index: 99));
      apply(const _Clear());
      apply(const _AddContent('after-clear', layerId: 'layer-a', index: -1));

      final frozen = editor.freeze(familyTables: base.familyTables);
      expect(frozen.backgroundElementIds.map((id) => id.value), [
        'background-first',
        'background-base',
      ]);
      expect(frozen.contentElementOrder.map((id) => id.value), ['after-clear']);
      expect(frozen.frameElementOrder.map((id) => id.value), [
        'background-first',
        'background-base',
        'after-clear',
      ]);
      expect(
        frozen.elementLocationFacts[CanvasElementId('after-clear')]?.layerId,
        CanvasLayerId('layer-a'),
      );
    });
  });
  test('frozen and discarded structural editors seal mutable order state', () {
    final base = _baseRegistry();
    late ElementRegistryStructuralEditor frozenEditor;
    late ElementRegistry frozen;
    ElementRegistry.editSparseStructure(base, (editor) {
      frozenEditor = editor;
      editor.addContentElement(
        CanvasElementId('added'),
        layerId: CanvasLayerId('layer-a'),
      );
      frozen = editor.freeze(familyTables: base.familyTables);
    });

    expect(
      () => frozenEditor.addContentElement(CanvasElementId('late')),
      throwsStateError,
    );
    expect(base.contentElementOrder.map((id) => id.value), [
      'base-a',
      'base-b',
    ]);
    expect(frozen.contentElementOrder.map((id) => id.value), [
      'base-a',
      'added',
      'base-b',
    ]);
    expect(
      () => frozen.frameOrderTokensById[CanvasElementId('late')] = 9,
      throwsUnsupportedError,
    );

    late ElementRegistryStructuralEditor discardedEditor;
    expect(
      () => ElementRegistry.editSparseStructure(base, (editor) {
        discardedEditor = editor;
        editor.addBackgroundElement(CanvasElementId('discarded'));
        throw StateError('later validation failure');
      }),
      throwsStateError,
    );
    expect(
      () => discardedEditor.addBackgroundElement(CanvasElementId('late')),
      throwsStateError,
    );
    expect(base.frameElementOrder.map((id) => id.value), [
      'background-base',
      'base-a',
      'base-b',
    ]);

    final finalEqual = ElementRegistry.editSparseStructure(base, (editor) {
      editor.addContentElement(
        CanvasElementId('temporary'),
        layerId: CanvasLayerId('layer-a'),
      );
      editor.removeElement(CanvasElementId('temporary'));
      return editor.freeze(familyTables: base.familyTables);
    });
    expect(identical(finalEqual, base), isTrue);
  });
  test('every opened order visits once and closes during finalization', () {
    final sequenceEvents = <IndexedOrderSequenceWorkEvent>[];
    final structuralEvents = <ElementRegistryStructuralEditorWorkEvent>[];
    final base = _baseRegistry();
    ElementRegistry.observeSparseStructuralEditorWork(structuralEvents.add, () {
      IndexedOrderSequence.observeWork(sequenceEvents.add, () {
        ElementRegistry.editSparseStructure(base, (editor) {
          editor.ensureLayer(CanvasLayerId('inserted'), index: 0);
          editor.addBackgroundElement(CanvasElementId('background-added'));
          editor.addContentElement(
            CanvasElementId('content-added'),
            layerId: CanvasLayerId('inserted'),
          );
          editor.freeze(familyTables: base.familyTables);
        });
      });
    });

    expect(sequenceEvents.where(_isBuildOpen), hasLength(3));
    expect(sequenceEvents.where(_isFinalPublication), isEmpty);
    expect(
      sequenceEvents.where(
        (event) => event == IndexedOrderSequenceWorkEvent.discard,
      ),
      hasLength(3),
    );
    for (final order in ElementRegistryStructuralOrderKind.values) {
      expect(
        structuralEvents.where(
          (event) =>
              event.kind == ElementRegistryStructuralEditorWorkKind.orderOpen &&
              event.order == order,
        ),
        hasLength(1),
      );
    }
    expect(
      structuralEvents.where(
        (event) =>
            event.kind ==
                ElementRegistryStructuralEditorWorkKind.finalTraversalVisit &&
            event.order == ElementRegistryStructuralOrderKind.background,
      ),
      hasLength(2),
    );
    expect(
      structuralEvents.where(
        (event) =>
            event.kind ==
                ElementRegistryStructuralEditorWorkKind.finalTraversalVisit &&
            event.order == ElementRegistryStructuralOrderKind.layer,
      ),
      hasLength(3),
    );
    expect(
      structuralEvents.where(
        (event) =>
            event.kind ==
                ElementRegistryStructuralEditorWorkKind.finalTraversalVisit &&
            event.order == ElementRegistryStructuralOrderKind.content,
      ),
      hasLength(3),
    );
  });
  test('family-only and structural candidates compose frozen families', () {
    final base = CommittedDocument(
      CanvasDocument(
        layers: [
          CanvasLayer(id: CanvasLayerId('layer-a'), elements: [_rect('base')]),
        ],
      ),
    );
    final store = DocumentStoreKernel.withCommittedDocumentForTesting(base);
    final familyOnly = store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.elementBounds(),
        mutations: [
          StoreSparseUpdateElement(
            before: _rect('base'),
            element: _rect('base', revision: 1, size: const Size(2, 2)),
            elementRevisionDelta: const StoreRevisionDelta.elementBounds(),
          ),
        ],
      ),
    );

    expect(
      identical(
        familyOnly.document.elements.layerTable,
        base.elements.layerTable,
      ),
      isTrue,
    );
    expect(
      identical(
        familyOnly.document.elements.contentElementOrder,
        base.elements.contentElementOrder,
      ),
      isTrue,
    );
    expect(
      identical(
        familyOnly.document.elements.frameElementOrder,
        base.elements.frameElementOrder,
      ),
      isTrue,
    );
    expect(
      familyOnly.document.elements
          .elementById(CanvasElementId('base'))
          ?.revision,
      1,
    );

    final structuralAndFamily = store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.structural(),
        mutations: [_add('added')],
      ),
    );
    expect(
      structuralAndFamily.document.elements.elementById(
        CanvasElementId('added'),
      ),
      isNotNull,
    );
  });
  test(
    'repeated clear is a constant-time barrier until new content arrives',
    () {
      final events = <ElementRegistryStructuralEditorWorkEvent>[];
      final base = _baseRegistry();
      ElementRegistry.observeSparseStructuralEditorWork(events.add, () {
        ElementRegistry.editSparseStructure(base, (editor) {
          expect(editor.clearContent().map((id) => id.value), [
            'base-a',
            'base-b',
          ]);
          final afterFirstClear = events.length;
          expect(editor.clearContent(), isEmpty);
          expect(events.skip(afterFirstClear), isEmpty);

          editor.addContentElement(
            CanvasElementId('after-clear'),
            layerId: CanvasLayerId('layer-b'),
          );
          final afterAdd = events.length;
          expect(editor.clearContent().map((id) => id.value), ['after-clear']);
          final finalClearEvents = events.skip(afterAdd);
          expect(
            finalClearEvents.where(
              (event) =>
                  event.kind ==
                      ElementRegistryStructuralEditorWorkKind
                          .clearContentTraversalVisit &&
                  event.order == ElementRegistryStructuralOrderKind.content,
            ),
            hasLength(1),
          );
          expect(
            finalClearEvents.where(
              (event) =>
                  event.kind ==
                      ElementRegistryStructuralEditorWorkKind
                          .clearContentTraversalVisit &&
                  event.order == ElementRegistryStructuralOrderKind.layer,
            ),
            isEmpty,
          );
          editor.freeze(familyTables: base.familyTables);
        });
      });
    },
  );
  test('final-equal and no-op sparse paths publish no structural facts', () {
    final base = _baseRegistry();
    final finalEqualEvents = <ElementRegistryStructuralEditorWorkEvent>[];
    final finalEqual = ElementRegistry.observeSparseStructuralEditorWork(
      finalEqualEvents.add,
      () => ElementRegistry.editSparseStructure(base, (editor) {
        editor.addContentElement(
          CanvasElementId('temporary'),
          layerId: CanvasLayerId('layer-a'),
        );
        editor.removeElement(CanvasElementId('temporary'));
        return editor.freeze(familyTables: base.familyTables);
      }),
    );
    expect(identical(finalEqual, base), isTrue);
    expect(finalEqualEvents.where(_isStructuralPublication), isEmpty);
    expect(
      finalEqualEvents.where(
        (event) =>
            event.kind ==
            ElementRegistryStructuralEditorWorkKind.finalIdentityRetain,
      ),
      hasLength(1),
    );

    final noOpStore = _store();
    final noOpEvents = <ElementRegistryStructuralEditorWorkEvent>[];
    final noOp = ElementRegistry.observeSparseStructuralEditorWork(
      noOpEvents.add,
      () => noOpStore.prepareSparseCommit(
        StoreSparseCommit(
          revisionDelta: const StoreRevisionDelta(),
          mutations: [StoreSparseRemoveElement(CanvasElementId('missing'))],
        ),
      ),
    );
    expect(noOp.hasChanges, isFalse);
    expect(noOpEvents.where(_isStructuralPublication), isEmpty);
    expect(
      noOpEvents.where(
        (event) =>
            event.kind == ElementRegistryStructuralEditorWorkKind.discard,
      ),
      hasLength(1),
    );
  });
  test('direct sparse preparation preserves mixed structural policy', () {
    final store = DocumentStoreKernel.withCommittedDocumentForTesting(
      CommittedDocument(
        CanvasDocument(
          backgroundElements: [_rect('background-base')],
          layers: [
            CanvasLayer(
              id: CanvasLayerId('layer-a'),
              elements: [_rect('base-a')],
            ),
            CanvasLayer(
              id: CanvasLayerId('layer-b'),
              elements: [_rect('base-b')],
            ),
          ],
        ),
      ),
    );

    final prepared = store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.structural(),
        mutations: [
          StoreSparseEnsureLayer(CanvasLayerId('inserted'), index: 0),
          StoreSparseAddElement(
            element: _rect('background-first'),
            background: true,
            index: -1,
          ),
          _add('front', index: -9),
          _add('middle', index: 2),
          StoreSparseRemoveElement(CanvasElementId('base-a')),
          StoreSparseRemoveElement(CanvasElementId('middle')),
          StoreSparseAddElement(
            element: _rect('middle'),
            background: true,
            index: 1,
          ),
          StoreSparseRemoveElement(CanvasElementId('middle')),
          StoreSparseAddElement(
            element: _rect('middle'),
            layerId: CanvasLayerId('layer-b'),
            index: 99,
          ),
          const StoreSparseClearContent(removeUnusedResources: false),
          _add('after-clear', index: -1),
        ],
      ),
    );

    expect(prepared.hasChanges, isTrue);
    expect(prepared.revisionDelta.structural, isTrue);
    expect(
      prepared.document.elements.backgroundElementIds.map((id) => id.value),
      ['background-first', 'background-base'],
    );
    expect(
      prepared.document.elements.contentElementOrder.map((id) => id.value),
      ['after-clear'],
    );
    expect(
      prepared.document.elements.layerTable.rows.map((row) => row.id.value),
      ['inserted', 'layer-a', 'layer-b'],
    );
    expect(
      prepared.document.elements.layerTable
          .locationFor(CanvasLayerId('layer-a'))
          ?.row
          .elementIds
          .map((id) => id.value),
      ['after-clear'],
    );
    expect(prepared.admittedLayerIds, ['inserted', 'layer-a', 'layer-b']);
    expect(prepared.admittedElementIds, [
      'background-first',
      'front',
      'middle',
      'after-clear',
    ]);
    expect(prepared.touchedFacts.addedElementIds.map((id) => id.value), {
      'background-first',
      'after-clear',
    });
    expect(prepared.touchedFacts.removedElementIds.map((id) => id.value), {
      'base-a',
      'base-b',
    });
    expect(
      prepared.document.elements.elementById(CanvasElementId('after-clear')),
      isNotNull,
    );
  });
  test('late sparse coverage failure discards structural finalization', () {
    final store = _store();
    final events = <ElementRegistryStructuralEditorWorkEvent>[];
    expect(
      () => ElementRegistry.observeSparseStructuralEditorWork(events.add, () {
        store.prepareSparseCommit(
          StoreSparseCommit(
            revisionDelta: const StoreRevisionDelta(),
            mutations: [_add('coverage-failure')],
          ),
        );
      }),
      throwsArgumentError,
    );
    expect(events.where(_isStructuralPublication), isEmpty);
    expect(
      events
          .where(
            (event) =>
                event.kind == ElementRegistryStructuralEditorWorkKind.discard,
          )
          .length,
      1,
    );
  });
  test('relationship failure discards structural owner before publication', () {
    final store = _store();
    final events = <ElementRegistryStructuralEditorWorkEvent>[];
    expect(
      () => ElementRegistry.observeSparseStructuralEditorWork(events.add, () {
        store.prepareSparseCommit(
          StoreSparseCommit(
            revisionDelta: const StoreRevisionDelta.structural(),
            mutations: [
              StoreSparseAddElement(
                element: CanvasImageElement(
                  id: CanvasElementId('missing-resource'),
                  resourceId: CanvasResourceId('missing-resource'),
                  size: const Size(1, 1),
                ),
                layerId: CanvasLayerId('layer-a'),
              ),
            ],
          ),
        );
      }),
      throwsA(isA<CanvasDataException>()),
    );
    expect(events.where(_isStructuralPublication), isEmpty);
    expect(
      events.where(
        (event) =>
            event.kind == ElementRegistryStructuralEditorWorkKind.discard,
      ),
      hasLength(1),
    );
  });
  test(
    'supported-size Store transaction opens and traverses one affected order once',
    () {
      final oracle = _SupportedOrderOracle(canvasMaxTotalElements);
      final events = <IndexedOrderSequenceWorkEvent>[];
      final structuralEvents = <ElementRegistryStructuralEditorWorkEvent>[];
      final store = _supportedOrderStore();
      final mutations = oracle.applyMixedRankMutations();
      late PreparedSparseStoreCommit prepared;

      ElementRegistry.observeSparseStructuralEditorWork(
        structuralEvents.add,
        () {
          IndexedOrderSequence.observeWork(events.add, () {
            prepared = store.prepareSparseCommit(
              StoreSparseCommit(
                revisionDelta: const StoreRevisionDelta.structural(),
                mutations: mutations,
              ),
            );
          });
        },
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
              event.kind == ElementRegistryStructuralEditorWorkKind.orderOpen &&
              event.order == ElementRegistryStructuralOrderKind.content,
        ),
        hasLength(1),
      );
      expect(
        structuralEvents.where(
          (event) =>
              event.kind == ElementRegistryStructuralEditorWorkKind.orderOpen &&
              event.order != ElementRegistryStructuralOrderKind.content,
        ),
        isEmpty,
      );
      expect(events.where(_isBuildOpen), hasLength(1));
      expect(
        events.where(
          (event) => event == IndexedOrderSequenceWorkEvent.buildInputVisit,
        ),
        hasLength(oracle.initialLength),
      );
      expect(
        events.where(
          (event) =>
              event == IndexedOrderSequenceWorkEvent.orderedIterationVisit,
        ),
        hasLength(oracle.finalLength),
      );
      expect(
        events.where((event) => event == IndexedOrderSequenceWorkEvent.discard),
        hasLength(1),
      );
      expect(events.where(_isFinalPublication), isEmpty);
      _expectFinalTraversalVisits(
        structuralEvents,
        background: oracle.backgroundLength,
        layers: oracle.layerLength,
        content: oracle.finalLength,
      );
      _expectOneStructuralPublicationPerKind(structuralEvents);
      expect(
        prepared.document.elements.contentElementOrder.map((id) => id.value),
        oracle.ids,
      );
    },
  );
  test('Store prefixes retain exact mixed current structural state', () {
    final actions = <_StructuralAction>[
      const _EnsureLayer('inserted', index: -5),
      const _AddBackground('background-first', index: -4),
      const _AddContent('front', layerId: 'layer-a', index: -9),
      const _AddContent('middle', layerId: 'layer-a', index: 2),
      const _AddContent('end', layerId: 'layer-a', index: 999),
      const _Remove('base-a'),
      const _AddContent('base-a', layerId: 'layer-b', index: 0),
      const _Remove('middle'),
      const _AddBackground('middle', index: 1),
      const _Remove('middle'),
      const _AddContent('middle', layerId: 'layer-b', index: 999),
      const _Clear(),
      const _AddContent('after-clear', layerId: 'layer-a', index: -1),
    ];
    final oracle = _StructuralOracle.fromBase();
    for (
      var prefixLength = 1;
      prefixLength <= actions.length;
      prefixLength += 1
    ) {
      actions[prefixLength - 1].applyToOracle(oracle);
      final store = _currentStateStore();
      final prepared = store.prepareSparseCommit(
        StoreSparseCommit(
          revisionDelta: const StoreRevisionDelta.structural(),
          mutations: [
            for (final action in actions.take(prefixLength))
              action.toMutation(),
          ],
        ),
      );
      _expectStoreStructuralState(prepared.document.elements, oracle);
    }

    final conflictingStore = _currentStateStore();
    expect(
      () => conflictingStore.prepareSparseCommit(
        StoreSparseCommit(
          revisionDelta: const StoreRevisionDelta.structural(),
          mutations: [
            for (final action in actions.take(7)) action.toMutation(),
            StoreSparseAddElement(
              element: _rect('base-a'),
              layerId: CanvasLayerId('layer-a'),
            ),
          ],
        ),
      ),
      throwsA(
        isA<CanvasDataException>()
            .having(
              (error) => error.code,
              'code',
              CanvasDataErrorCode.duplicateElementId,
            )
            .having(
              (error) => error.message,
              'message',
              'duplicate element id.',
            )
            .having((error) => error.path, 'path', 'elements.id'),
      ),
    );
  });
  test(
    'content-only Store mutation preserves untouched structural identities',
    () {
      final base = CommittedDocument(_currentStateBaseDocument());
      final baseElements = base.elements;
      final baseBackground = baseElements.backgroundElementIds;
      final baseLayerB = baseElements.layerTable.locationFor(
        CanvasLayerId('layer-b'),
      );
      expect(baseLayerB, isNotNull);
      if (baseLayerB == null) {
        return;
      }
      final store = DocumentStoreKernel.withCommittedDocumentForTesting(base);
      final events = <ElementRegistryStructuralEditorWorkEvent>[];
      final prepared = ElementRegistry.observeSparseStructuralEditorWork(
        events.add,
        () => store.prepareSparseCommit(
          StoreSparseCommit(
            revisionDelta: const StoreRevisionDelta.structural(),
            mutations: [
              StoreSparseAddElement(
                element: _rect('layer-a-only'),
                layerId: CanvasLayerId('layer-a'),
                index: 0,
              ),
            ],
          ),
        ),
      );
      final nextElements = prepared.document.elements;
      final nextLayerB = nextElements.layerTable.locationFor(
        CanvasLayerId('layer-b'),
      );
      expect(nextLayerB, isNotNull);
      if (nextLayerB == null) {
        return;
      }

      expect(
        identical(nextElements.backgroundElementIds, baseBackground),
        isTrue,
      );
      expect(identical(nextLayerB.row, baseLayerB.row), isTrue);
      expect(
        identical(nextLayerB.row.elementIds, baseLayerB.row.elementIds),
        isTrue,
      );
      expect(identical(nextLayerB, baseLayerB), isTrue);
      expect(
        identical(
          nextElements.layerTable.locationFor(CanvasLayerId('layer-a'))?.row,
          baseElements.layerTable.locationFor(CanvasLayerId('layer-a'))?.row,
        ),
        isFalse,
      );
      expect(
        events.where(
          (event) =>
              event.kind == ElementRegistryStructuralEditorWorkKind.orderOpen &&
              event.order == ElementRegistryStructuralOrderKind.content,
        ),
        hasLength(1),
      );
      expect(
        events.where(
          (event) =>
              event.kind == ElementRegistryStructuralEditorWorkKind.orderOpen &&
              event.order != ElementRegistryStructuralOrderKind.content,
        ),
        isEmpty,
      );
    },
  );
}

bool _isBuildOpen(IndexedOrderSequenceWorkEvent event) =>
    event == IndexedOrderSequenceWorkEvent.buildOpen;

bool _isFinalPublication(IndexedOrderSequenceWorkEvent event) =>
    event == IndexedOrderSequenceWorkEvent.finalFlattenPublication;

bool _isStructuralPublication(ElementRegistryStructuralEditorWorkEvent event) =>
    switch (event.kind) {
      ElementRegistryStructuralEditorWorkKind.layerRowsPublication ||
      ElementRegistryStructuralEditorWorkKind.layerLocationsPublication ||
      ElementRegistryStructuralEditorWorkKind.backgroundOrderPublication ||
      ElementRegistryStructuralEditorWorkKind.contentOrderPublication ||
      ElementRegistryStructuralEditorWorkKind.frameOrderPublication ||
      ElementRegistryStructuralEditorWorkKind.frameTokenPublication ||
      ElementRegistryStructuralEditorWorkKind.elementLocationPublication =>
        true,
      _ => false,
    };

void _expectFinalTraversalVisits(
  Iterable<ElementRegistryStructuralEditorWorkEvent> events, {
  required int background,
  required int layers,
  required int content,
}) {
  for (final expected in [
    (order: ElementRegistryStructuralOrderKind.background, count: background),
    (order: ElementRegistryStructuralOrderKind.layer, count: layers),
    (order: ElementRegistryStructuralOrderKind.content, count: content),
  ]) {
    expect(
      events.where(
        (event) =>
            event.kind ==
                ElementRegistryStructuralEditorWorkKind.finalTraversalVisit &&
            event.order == expected.order,
      ),
      hasLength(expected.count),
    );
  }
}

void _expectOneStructuralPublicationPerKind(
  Iterable<ElementRegistryStructuralEditorWorkEvent> events,
) {
  for (final kind in [
    ElementRegistryStructuralEditorWorkKind.layerRowsPublication,
    ElementRegistryStructuralEditorWorkKind.layerLocationsPublication,
    ElementRegistryStructuralEditorWorkKind.backgroundOrderPublication,
    ElementRegistryStructuralEditorWorkKind.contentOrderPublication,
    ElementRegistryStructuralEditorWorkKind.frameOrderPublication,
    ElementRegistryStructuralEditorWorkKind.frameTokenPublication,
    ElementRegistryStructuralEditorWorkKind.elementLocationPublication,
  ]) {
    expect(events.where((event) => event.kind == kind), hasLength(1));
  }
}

// Keep the independent oracle's coupled order, location, and token assertions
// together: splitting them would obscure which committed structure diverged.
// ignore: halstead-volume
void _expectStoreStructuralState(
  ElementRegistry actual,
  _StructuralOracle expected,
) {
  expect(actual.layerTable.rows.map((row) => row.id.value), expected.layers);
  for (final layerId in expected.layers) {
    expect(
      actual.layerTable
          .locationFor(CanvasLayerId(layerId))
          ?.row
          .elementIds
          .map((id) => id.value),
      expected.contentByLayer[layerId],
    );
  }
  expect(
    actual.backgroundElementIds.map((id) => id.value),
    expected.background,
  );
  expect(actual.contentElementOrder.map((id) => id.value), expected.content);
  expect(actual.frameElementOrder.map((id) => id.value), expected.frame);
  expect(
    actual.elementLocationFacts.keys.map((id) => id.value).toSet(),
    expected.frame.toSet(),
  );
  for (final (index, id) in expected.frame.indexed) {
    final location = actual.elementLocationFacts[CanvasElementId(id)];
    final expectedLocation = expected.locations[id];
    expect(location, isNotNull);
    expect(expectedLocation, isNotNull);
    if (location == null || expectedLocation == null) {
      continue;
    }
    expect(location.kind, expectedLocation.kind);
    expect(location.layerId?.value, expectedLocation.layerId);
    expect(actual.frameOrderTokensById[CanvasElementId(id)], index);
  }
}

DocumentStoreKernel _currentStateStore() =>
    DocumentStoreKernel.withCommittedDocumentForTesting(
      CommittedDocument(_currentStateBaseDocument()),
    );

CanvasDocument _currentStateBaseDocument() => CanvasDocument(
  backgroundElements: [_rect('background-base')],
  layers: [
    CanvasLayer(id: CanvasLayerId('layer-a'), elements: [_rect('base-a')]),
    CanvasLayer(id: CanvasLayerId('layer-b'), elements: [_rect('base-b')]),
  ],
);

DocumentStoreKernel _supportedOrderStore() =>
    DocumentStoreKernel.withCommittedDocumentForTesting(
      CommittedDocument(
        CanvasDocument(
          layers: [
            CanvasLayer(
              id: CanvasLayerId('layer-a'),
              elements: [
                for (var index = 0; index < canvasMaxTotalElements; index += 1)
                  _rect(_supportedOrderId(index)),
              ],
            ),
          ],
        ),
      ),
    );

String _supportedOrderId(int index) => 'supported-$index';

final class _SupportedOrderOracle {
  _SupportedOrderOracle(this.initialLength)
    : _ids = [
        for (var index = 0; index < initialLength; index += 1)
          _supportedOrderId(index),
      ];

  final int initialLength;
  final List<String> _ids;

  List<String> get ids => List.unmodifiable(_ids);
  int get finalLength => _ids.length;
  int get backgroundLength => 0;
  int get layerLength => 1;

  List<StoreSparseMutation> applyMixedRankMutations() {
    final mutations = <StoreSparseMutation>[];
    _removeAt(0, mutations);
    _insert('front', 0, mutations);
    _removeAt(_ids.length ~/ 2, mutations);
    _insert('middle', _ids.length ~/ 2, mutations);
    _removeAt(_ids.length - 1, mutations);
    _insert('end', null, mutations);
    final frontIndex = _ids.indexOf('front');
    _removeAt(frontIndex, mutations);
    _insert('front', _ids.length ~/ 2, mutations);
    return mutations;
  }

  void _removeAt(int index, List<StoreSparseMutation> mutations) {
    final id = _ids.removeAt(index);
    mutations.add(StoreSparseRemoveElement(CanvasElementId(id)));
  }

  void _insert(String id, int? index, List<StoreSparseMutation> mutations) {
    _ids.insert(_clamp(index, _ids.length), id);
    mutations.add(
      StoreSparseAddElement(
        element: _rect(id),
        layerId: CanvasLayerId('layer-a'),
        index: index,
      ),
    );
  }
}

DocumentStoreKernel _store() =>
    DocumentStoreKernel.withCommittedDocumentForTesting(
      CommittedDocument(
        CanvasDocument(
          layers: [
            CanvasLayer(
              id: CanvasLayerId('layer-a'),
              elements: [_rect('base')],
            ),
            CanvasLayer(
              id: CanvasLayerId('untouched'),
              elements: [_rect('other')],
            ),
          ],
        ),
      ),
    );

StoreSparseAddElement _add(String id, {int? index}) => StoreSparseAddElement(
  element: _rect(id),
  layerId: CanvasLayerId('layer-a'),
  index: index,
);

CanvasRectElement _rect(
  String id, {
  int revision = 0,
  Size size = const Size(1, 1),
}) =>
    CanvasRectElement(id: CanvasElementId(id), revision: revision, size: size);

ElementRegistry _baseRegistry() => ElementRegistry(
  backgroundElements: [_rect('background-base')],
  layers: [
    CanvasLayer(id: CanvasLayerId('layer-a'), elements: [_rect('base-a')]),
    CanvasLayer(id: CanvasLayerId('layer-b'), elements: [_rect('base-b')]),
  ],
);

void _expectCurrentEditorMatches(
  ElementRegistryStructuralEditor editor,
  _StructuralOracle oracle,
) {
  expect(
    editor.currentBackgroundElementIds.map((id) => id.value),
    oracle.background,
  );
  expect(editor.currentContentElementIds.map((id) => id.value), oracle.content);
  expect(editor.currentFrameElementIds.map((id) => id.value), oracle.frame);
  for (final entry in oracle.locations.entries) {
    final actual = editor.locationFor(CanvasElementId(entry.key));
    expect(actual?.kind, entry.value.kind);
    expect(actual?.layerId?.value, entry.value.layerId);
  }
}

sealed class _StructuralAction {
  const _StructuralAction();

  void applyToEditor(ElementRegistryStructuralEditor editor);
  void applyToOracle(_StructuralOracle oracle);
  StoreSparseMutation toMutation();
}

final class _EnsureLayer extends _StructuralAction {
  const _EnsureLayer(this.id, {this.index});

  final String id;
  final int? index;

  @override
  void applyToEditor(ElementRegistryStructuralEditor editor) {
    editor.ensureLayer(CanvasLayerId(id), index: index);
  }

  @override
  void applyToOracle(_StructuralOracle oracle) => oracle.ensureLayer(id, index);

  @override
  StoreSparseMutation toMutation() =>
      StoreSparseEnsureLayer(CanvasLayerId(id), index: index);
}

final class _AddBackground extends _StructuralAction {
  const _AddBackground(this.id, {this.index});

  final String id;
  final int? index;

  @override
  void applyToEditor(ElementRegistryStructuralEditor editor) {
    editor.addBackgroundElement(CanvasElementId(id), index: index);
  }

  @override
  void applyToOracle(_StructuralOracle oracle) =>
      oracle.addBackground(id, index);

  @override
  StoreSparseMutation toMutation() =>
      StoreSparseAddElement(element: _rect(id), background: true, index: index);
}

final class _AddContent extends _StructuralAction {
  const _AddContent(this.id, {required this.layerId, this.index});

  final String id;
  final String layerId;
  final int? index;

  @override
  void applyToEditor(ElementRegistryStructuralEditor editor) {
    editor.addContentElement(
      CanvasElementId(id),
      layerId: CanvasLayerId(layerId),
      index: index,
    );
  }

  @override
  void applyToOracle(_StructuralOracle oracle) =>
      oracle.addContent(id, layerId, index);

  @override
  StoreSparseMutation toMutation() => StoreSparseAddElement(
    element: _rect(id),
    layerId: CanvasLayerId(layerId),
    index: index,
  );
}

final class _Remove extends _StructuralAction {
  const _Remove(this.id);

  final String id;

  @override
  void applyToEditor(ElementRegistryStructuralEditor editor) {
    editor.removeElement(CanvasElementId(id));
  }

  @override
  void applyToOracle(_StructuralOracle oracle) => oracle.remove(id);

  @override
  StoreSparseMutation toMutation() =>
      StoreSparseRemoveElement(CanvasElementId(id));
}

final class _Clear extends _StructuralAction {
  const _Clear();

  @override
  void applyToEditor(ElementRegistryStructuralEditor editor) {
    editor.clearContent();
  }

  @override
  void applyToOracle(_StructuralOracle oracle) => oracle.clearContent();

  @override
  StoreSparseMutation toMutation() => const StoreSparseClearContent();
}

final class _StructuralOracle {
  _StructuralOracle.fromBase()
    : layers = ['layer-a', 'layer-b'],
      background = ['background-base'],
      contentByLayer = {
        'layer-a': ['base-a'],
        'layer-b': ['base-b'],
      };

  final List<String> layers;
  final List<String> background;
  final Map<String, List<String>> contentByLayer;

  List<String> get content => [
    for (final layer in layers) ...contentByLayer[layer]!,
  ];
  List<String> get frame => [...background, ...content];
  Map<String, _ExpectedLocation> get locations => {
    for (final id in background) id: const _ExpectedLocation.background(),
    for (final layer in layers)
      for (final id in contentByLayer[layer]!)
        id: _ExpectedLocation.content(layer),
  };

  void ensureLayer(String id, int? index) {
    if (contentByLayer.containsKey(id)) {
      return;
    }
    layers.insert(_clamp(index, layers.length), id);
    contentByLayer[id] = [];
  }

  void addBackground(String id, int? index) {
    background.insert(_clamp(index, background.length), id);
  }

  void addContent(String id, String layerId, int? index) {
    ensureLayer(layerId, null);
    contentByLayer[layerId]!.insert(
      _clamp(index, contentByLayer[layerId]!.length),
      id,
    );
  }

  void remove(String id) {
    background.remove(id);
    for (final ids in contentByLayer.values) {
      ids.remove(id);
    }
  }

  void clearContent() {
    for (final ids in contentByLayer.values) {
      ids.clear();
    }
  }
}

final class _ExpectedLocation {
  const _ExpectedLocation.background()
    : kind = ElementLocationKind.background,
      layerId = null;

  const _ExpectedLocation.content(this.layerId)
    : kind = ElementLocationKind.content;

  final ElementLocationKind kind;
  final String? layerId;
}

int _clamp(int? index, int length) {
  final value = index ?? length;
  if (value < 0) {
    return 0;
  }
  return value > length ? length : value;
}
