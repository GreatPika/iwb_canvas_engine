import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';

import '../../support/document_store_with_document.dart';

void main() {
  _registerCoherentAppearanceReadTest();
  _registerAppearanceReadSideEffectTest();
  _registerAppearanceCollectionImmutabilityTest();
  _registerAppearanceLifecycleTest();
}

// The one read boundary must retain every pre-read capture and post-read
// oracle together, so splitting it would obscure the side-effect comparison.
// ignore: halstead-volume
void _registerAppearanceReadSideEffectTest() {
  test('appearance reads have no committed or delivery side effects', () {
    final store = documentStoreWithDocument(_firstDocument());
    final effectBatches = <List<CommitDeliveryEffect>>[];
    final root = RuntimeRoot.test(
      config: const CanvasRuntimeConfig(
        deletionCommitResolver: _acceptDeletionCommit,
      ),
      store: store,
      commitEffectObserver: effectBatches.add,
    );
    addTearDown(root.dispose);
    final actions = <CanvasActionCommitted>[];
    final actionSubscription = root.actions.listen(actions.add);
    addTearDown(actionSubscription.cancel);
    var stateNotifications = 0;
    root.state.addListener(() => stateNotifications += 1);
    final projectedDocument = root.readDocument();
    final beforeBuildCount = root.projectionBuildCount;
    final beforeRevisions = _storeRevisions(store);

    final first = root.readAppearance();
    final second = root.readAppearance();

    _expectStoreAppearance(first, store);
    _expectStoreAppearance(second, store);
    expect(_storeRevisions(store), beforeRevisions);
    expect(root.projectionBuildCount, beforeBuildCount);
    expect(root.readDocument(), same(projectedDocument));
    expect(effectBatches, isEmpty);
    expect(actions, isEmpty);
    expect(stateNotifications, 0);
  });
}

void _registerCoherentAppearanceReadTest() {
  test('appearance reads one immutable committed boundary', () {
    final store = documentStoreWithDocument(_firstDocument());
    final root = RuntimeRoot.test(
      config: const CanvasRuntimeConfig(
        deletionCommitResolver: _acceptDeletionCommit,
      ),
      store: store,
    );
    addTearDown(root.dispose);

    final first = root.readAppearance();
    expect(first.backgroundColor, _firstBackgroundColor);
    _expectStoreAppearance(first, store);

    root.edits.edit((edit) {
      edit.setBackgroundColor(_secondBackgroundColor);
      edit.setGrid(_secondGrid);
      edit.setPalette(_secondPalette);

      _expectStoreAppearance(root.readAppearance(), store);
    });

    _expectStoreAppearance(root.readAppearance(), store);
  });
}

void _registerAppearanceCollectionImmutabilityTest() {
  test(
    'appearance collections reject mutation and retain committed values',
    () {
      final runtime = _runtimeWithDocument(_firstDocument());
      addTearDown(runtime.dispose);
      final appearance = runtime.readAppearance();

      expect(
        () => appearance.palette.penColors.add(const Color(0xFFABCDEF)),
        throwsUnsupportedError,
      );
      expect(
        () => appearance.palette.backgroundColors.add(const Color(0xFFABCDEF)),
        throwsUnsupportedError,
      );
      expect(
        () => appearance.palette.gridSizes.add(99),
        throwsUnsupportedError,
      );

      _expectAppearance(runtime.readAppearance(), _firstDocument());
    },
  );
}

// Keeping the complete lifecycle chronology together makes committed-state
// visibility and notification boundaries safer to read than helper fragments.
// ignore: halstead-volume
void _registerAppearanceLifecycleTest() {
  test(
    'appearance remains the last installed value through lifecycle boundaries',
    () {
      final runtime = _runtimeWithDocument(_firstDocument());
      var notifications = 0;
      runtime.state.addListener(() => notifications += 1);
      final first = _firstDocument();
      final second = _secondDocument();

      runtime.edits.edit((edit) {
        edit.setBackgroundColor(_secondBackgroundColor);
        edit.setGrid(_secondGrid);
        edit.setPalette(_secondPalette);

        _expectAppearance(runtime.readAppearance(), first);
        expect(notifications, 0);
      });
      _expectAppearance(runtime.readAppearance(), second);
      expect(notifications, 1);

      expect(
        () => runtime.edits.edit((edit) {
          edit.setBackgroundColor(_firstBackgroundColor);
          edit.setGrid(_firstGrid);
          edit.setPalette(_firstPalette);

          _expectAppearance(runtime.readAppearance(), second);
          throw StateError('rollback');
        }),
        throwsStateError,
      );
      _expectAppearance(runtime.readAppearance(), second);
      expect(notifications, 1);

      runtime.dispose();
      _expectAppearance(runtime.readAppearance(), second);
      expect(notifications, 1);
    },
  );
}

CanvasRuntime _runtimeWithDocument(CanvasDocument document) {
  final runtime = CanvasRuntime(
    config: const CanvasRuntimeConfig(
      deletionCommitResolver: _acceptDeletionCommit,
    ),
  );
  runtime.edits.loadDocumentFromJson(encodeCanvasDocumentToJson(document));

  return runtime;
}

CanvasDeletionDecision _acceptDeletionCommit(CanvasDeletionCommitRequest _) =>
    CanvasDeletionDecision.accept;

void _expectAppearance(CanvasAppearance appearance, CanvasDocument document) {
  expect(appearance.backgroundColor, document.background.color);
  expect(appearance.grid.enabled, document.background.grid.enabled);
  expect(appearance.grid.cellSize, document.background.grid.cellSize);
  expect(appearance.grid.color, document.background.grid.color);
  expect(appearance.palette.penColors, document.palette.penColors);
  expect(
    appearance.palette.backgroundColors,
    document.palette.backgroundColors,
  );
  expect(appearance.palette.gridSizes, document.palette.gridSizes);
}

void _expectStoreAppearance(
  CanvasAppearance appearance,
  DocumentStoreKernel store,
) {
  expect(appearance.backgroundColor, store.background.color);
  expect(appearance.grid.enabled, store.background.grid.enabled);
  expect(appearance.grid.cellSize, store.background.grid.cellSize);
  expect(appearance.grid.color, store.background.grid.color);
  expect(appearance.palette.penColors, store.palette.penColors);
  expect(appearance.palette.backgroundColors, store.palette.backgroundColors);
  expect(appearance.palette.gridSizes, store.palette.gridSizes);
}

({
  int document,
  int structural,
  int bounds,
  int elementVisual,
  int background,
  int grid,
  int resource,
})
_storeRevisions(DocumentStoreKernel store) => (
  document: store.documentRevision,
  structural: store.structuralRevision,
  bounds: store.boundsRevision,
  elementVisual: store.elementVisualRevision,
  background: store.backgroundRevision,
  grid: store.gridRevision,
  resource: store.resourceRevision,
);

const _firstBackgroundColor = Color(0xFF102030);
const _secondBackgroundColor = Color(0xFF405060);

final _firstGrid = CanvasGrid(
  enabled: true,
  cellSize: 12,
  color: const Color(0xAA010203),
);
final _secondGrid = CanvasGrid(
  enabled: true,
  cellSize: 24,
  color: const Color(0xBB040506),
);
final _firstPalette = CanvasPalette(
  penColors: const [Color(0xFF111111), Color(0xFF222222)],
  backgroundColors: const [Color(0xFF333333)],
  gridSizes: const [6, 12],
);
final _secondPalette = CanvasPalette(
  penColors: const [Color(0xFF444444), Color(0xFF555555)],
  backgroundColors: const [Color(0xFF666666), Color(0xFF777777)],
  gridSizes: const [24, 48],
);

CanvasDocument _firstDocument() => CanvasDocument(
  background: CanvasBackground(color: _firstBackgroundColor, grid: _firstGrid),
  palette: _firstPalette,
);

CanvasDocument _secondDocument() => CanvasDocument(
  background: CanvasBackground(
    color: _secondBackgroundColor,
    grid: _secondGrid,
  ),
  palette: _secondPalette,
);
