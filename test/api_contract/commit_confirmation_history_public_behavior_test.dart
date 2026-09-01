import 'package:test/test.dart';

import '../support/flutter_consumer_test_harness.dart';

void main() {
  test('public consumer replays committed confirmation facts for Undo and Redo',
      () async {
    await expectLater(
      runFlutterConsumerTest(
        packageName: 'iwb_canvas_engine_commit_confirmation_history',
        testFileName: 'commit_confirmation_history_test.dart',
        testSource: _consumerSource,
      ),
      completes,
    );
  });
}

// This is intentionally one external consumer source: it owns the cross-route
// host-history proof without importing production internals or adding a runner.
const _consumerSource = r'''
import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('Undo and Redo use only committed public facts', () async {
    final host = _Host();
    try {
      await host.exerciseAllFamilies();
    } finally {
      await host.dispose();
    }
  });

  test('Draw provenance restores only the layer created by that Draw', () async {
    await _exerciseDrawLayerProvenance();
  });
}

final class _Host implements CanvasCommitLease {
  _Host()
      : runtime = CanvasRuntime(
          config: CanvasRuntimeConfig(commitResolver: _resolveCommit),
        ) {
    _actions = runtime.actions.listen(actions.add);
  }

  static late _Host _active;
  final CanvasRuntime runtime;
  final _History history = _History();
  final List<CanvasActionCommitted> actions = <CanvasActionCommitted>[];
  late final StreamSubscription<CanvasActionCommitted> _actions;
  CanvasCommitRequest? _pendingRequest;
  Offset? _pendingMoveDelta;
  var _recording = true;
  var cancelNextDelete = false;
  var abortNextMove = false;
  var abortedCalls = 0;
  var resolverCalls = 0;

  static CanvasCommitResolution _resolveCommit(CanvasCommitRequest request) {
    final host = _active;
    host.resolverCalls += 1;
    if (request is CanvasDeleteCommitRequest && host.cancelNextDelete) {
      host.cancelNextDelete = false;
      return const CanvasCommitCancel();
    }
    if (request is CanvasMoveCommitRequest && host.abortNextMove) {
      host.abortNextMove = false;
      host._pendingRequest = request;
      host._pendingMoveDelta = Offset.zero;
      return CanvasMoveCommitAccept(delta: Offset.zero, lease: host);
    }
    host._pendingRequest = request;
    host._pendingMoveDelta = request is CanvasMoveCommitRequest
        ? const Offset(7, -3)
        : null;
    return request is CanvasMoveCommitRequest
        ? CanvasMoveCommitAccept(delta: host._pendingMoveDelta!, lease: host)
        : CanvasCommitAccept(lease: host);
  }

  @override
  void committed() {
    final request = _pendingRequest!;
    if (_recording) {
      history.record(request, finalMoveDelta: _pendingMoveDelta);
    }
    _pendingRequest = null;
    _pendingMoveDelta = null;
  }

  @override
  void aborted() {
    abortedCalls += 1;
    _pendingRequest = null;
    _pendingMoveDelta = null;
  }

  Future<void> exerciseAllFamilies() async {
    _active = this;
    _seed();
    runtime.selection.setSelection([
      CanvasElementId('transform-me'),
      CanvasElementId('selection-drop'),
    ]);
    final baseline = runtime.readDocument();
    final baselineSelection = runtime.selection.selectedElementIds;
    final snapshots = <_ReplaySnapshot>[
      _ReplaySnapshot(baseline, baselineSelection),
    ];

    _draw();
    snapshots.add(_snapshot());
    cancelNextDelete = true;
    expect(runtime.commands.removeElement(CanvasElementId('cancel-me')), isFalse);
    // The cancellation record is intentionally absent because no lease commits.
    expect(history.records, hasLength(1));
    snapshots.addAll(_delete());
    _erase();
    snapshots.add(_snapshot());
    _abortMove();
    _move();
    snapshots.add(_snapshot());
    _rotate();
    snapshots.add(_snapshot());
    _reflect();
    snapshots.add(_snapshot());
    await _textEdit();
    snapshots.add(_snapshot());
    await Future<void>.delayed(Duration.zero);

    expect(history.records.map((record) => record.request.runtimeType), [
      CanvasDrawCommitRequest,
      CanvasDeleteCommitRequest,
      CanvasDeleteCommitRequest,
      CanvasDeleteCommitRequest,
      CanvasDeleteCommitRequest,
      CanvasEraseCommitRequest,
      CanvasMoveCommitRequest,
      CanvasRotateCommitRequest,
      CanvasReflectCommitRequest,
      CanvasTextEditCommitRequest,
    ]);
    expect(abortedCalls, 1);
    expect(resolverCalls, 12);
    expect(actions, hasLength(10));
    expect(snapshots, hasLength(history.records.length + 1));

    final accepted = snapshots.last.document;
    final acceptedSelection = snapshots.last.selection;
    final actionsBeforeReplay = actions.length;
    final resolverCallsBeforeReplay = resolverCalls;
    _mutateTextAfterRecording();
    _recording = false;
    var documentRevision = runtime.state.value.revisions.document;
    var selectionRevision = runtime.state.value.revisions.selection;
    var snapshotIndex = snapshots.length - 1;
    while (history.canUndo) {
      final selectionBeforeStep = runtime.selection.selectedElementIds;
      final textRevisionBeforeStep = _text(runtime).revision;
      final record = history.undo(runtime);
      final revisions = runtime.state.value.revisions;
      expect(revisions.document, documentRevision + 1);
      if (!_sameIds(runtime.selection.selectedElementIds, selectionBeforeStep)) {
        expect(revisions.selection, selectionRevision + 1);
      } else {
        expect(revisions.selection, selectionRevision);
      }
      if (record.request case CanvasTextEditCommitRequest(:final before, :final after)) {
        final restored = _text(runtime);
        expect(restored.revision, textRevisionBeforeStep + 1);
        expect(restored.revision, isNot(before.revision));
        expect(restored.revision, isNot(after.revision));
      }
      documentRevision = revisions.document;
      selectionRevision = revisions.selection;
      _expectSnapshot(runtime, snapshots[--snapshotIndex]);
    }

    while (history.canRedo) {
      final selectionBeforeStep = runtime.selection.selectedElementIds;
      final textRevisionBeforeStep = _text(runtime).revision;
      final record = history.redo(runtime);
      final revisions = runtime.state.value.revisions;
      expect(revisions.document, documentRevision + 1);
      if (!_sameIds(runtime.selection.selectedElementIds, selectionBeforeStep)) {
        expect(revisions.selection, selectionRevision + 1);
      } else {
        expect(revisions.selection, selectionRevision);
      }
      if (record.request case CanvasTextEditCommitRequest(:final before, :final after)) {
        final restored = _text(runtime);
        expect(restored.revision, textRevisionBeforeStep + 1);
        expect(restored.revision, isNot(before.revision));
        expect(restored.revision, isNot(after.revision));
      }
      documentRevision = revisions.document;
      selectionRevision = revisions.selection;
      _expectSnapshot(runtime, snapshots[++snapshotIndex]);
    }
    expect(snapshotIndex, snapshots.length - 1);
    _expectDocumentContent(runtime.readDocument(), accepted);
    expect(runtime.selection.selectedElementIds, acceptedSelection);
    expect(actions, hasLength(actionsBeforeReplay));
    expect(resolverCalls, resolverCallsBeforeReplay);
    _expectText(_text(runtime), _textFrom(accepted));
  }

  void _seed() {
    runtime.edits.edit((edit) {
      edit.replaceDraftDocument(
        CanvasDocument(
          background: CanvasBackground(
            color: const Color(0xFFABCDEF),
            grid: CanvasGrid(enabled: true, cellSize: 16),
          ),
          palette: CanvasPalette(
            penColors: const [Color(0xFF102030)],
            backgroundColors: const [Color(0xFFABCDEF)],
            gridSizes: const [16, 32],
          ),
          metadata: CanvasMetadata.fromMap({'document': 'host baseline'}),
          layers: [
            CanvasLayer(
              id: CanvasLayerId('seed'),
              metadata: CanvasMetadata.fromMap({'layer': 'host baseline'}),
            ),
          ],
        ),
      );
      edit.upsertResource(
        CanvasImageResource(
          id: CanvasResourceId('asset'),
          source: CanvasResourceSource.appKey('host-owned'),
          contentHash: 'sha256:host-owned',
          byteLength: 42,
          mimeType: 'image/png',
          metadata: CanvasMetadata.fromMap({'owner': 'host'}),
        ),
      );
      edit.addBackgroundElement(
        CanvasRectElement(
          id: CanvasElementId('background'),
          size: const Size(10, 10),
          transform: CanvasTransform.translation(const Offset(-10, 5)),
          opacity: 0.6,
          hitPadding: 1,
          isVisible: false,
          isSelectable: false,
          isLocked: true,
          isDeletable: false,
          isTransformable: false,
          metadata: CanvasMetadata.fromMap({'background': 'retained'}),
          fillColor: const Color(0xFF123456),
          strokeColor: const Color(0xFF654321),
          strokeWidth: 2,
        ),
      );
      edit.addBackgroundElement(
        _rect('background-delete', const Offset(40, 0)),
      );
      for (final element in [_rect('selection-drop', const Offset(-20, 0)), _rect('delete-me', const Offset(0, 0)), _line('delete-line'), _rect('erase-me', const Offset(200, 0)), _rect('cancel-me', const Offset(0, 30)), _rect('transform-me', const Offset(30, 30)), _initialText()]) {
        edit.addElement(element, layerId: CanvasLayerId('seed'));
      }
      edit.updateElement(
        CanvasTextElementUpdate(
          id: CanvasElementId('text'),
          transform: CanvasFieldSet(CanvasTransform.translation(const Offset(90, 0))),
          opacity: const CanvasFieldSet(0.7),
          hitPadding: const CanvasFieldSet(2),
          isVisible: const CanvasFieldSet(true),
          isSelectable: const CanvasFieldSet(true),
          isLocked: const CanvasFieldSet(false),
          isDeletable: const CanvasFieldSet(true),
          isTransformable: const CanvasFieldSet(true),
          metadata: CanvasFieldSet(CanvasMetadata.fromMap({'version': 'before'})),
          text: const CanvasFieldSet('before'),
          fontSize: const CanvasFieldSet(18),
          color: const CanvasFieldSet(Color(0xFF102030)),
          align: const CanvasFieldSet(TextAlign.right),
          textDirection: const CanvasFieldSet(TextDirection.ltr),
          isBold: const CanvasFieldSet(true),
          isItalic: const CanvasFieldSet(true),
          isUnderline: const CanvasFieldSet(true),
          fontFamily: const CanvasFieldClear(),
          maxWidth: const CanvasFieldClear(),
          lineHeight: const CanvasFieldClear(),
        ),
      );
    });
  }

  void _draw() {
    runtime.tools.setMode(CanvasInteractionMode.draw);
    runtime.tools.setDrawStyle(
      CanvasDrawStyle(tool: CanvasDrawTool.pencil, pencilThickness: 3),
    );
    _drag(runtime.tools, Offset.zero, const Offset(8, 4));
  }

  List<_ReplaySnapshot> _delete() {
    expect(runtime.commands.removeElement(CanvasElementId('selection-drop')), isTrue);
    final selectionDeleted = _snapshot();
    expect(runtime.commands.removeElement(CanvasElementId('delete-me')), isTrue);
    final contentDeleted = _snapshot();
    expect(runtime.commands.removeElement(CanvasElementId('background-delete')), isTrue);
    final backgroundDeleted = _snapshot();
    expect(runtime.commands.removeElement(CanvasElementId('delete-line')), isTrue);
    return [selectionDeleted, contentDeleted, backgroundDeleted, _snapshot()];
  }

  void _erase() {
    runtime.tools.setDrawStyle(
      CanvasDrawStyle(tool: CanvasDrawTool.eraser, eraserThickness: 8),
    );
    _drag(runtime.tools, const Offset(200, 0), const Offset(204, 0));
  }

  void _abortMove() {
    runtime.tools.setMode(CanvasInteractionMode.move);
    abortNextMove = true;
    runtime.selection.moveSelection(const Offset(1, 1));
  }

  void _move() {
    runtime.selection.moveSelection(const Offset(2, 2));
  }

  void _rotate() {
    runtime.selection.rotateSelectionClockwise();
  }

  void _reflect() {
    runtime.selection.flipSelectionHorizontal();
  }

  Future<void> _textEdit() async {
    final requests = <CanvasContextActionRequested>[];
    final subscription = runtime.contextActionRequests.listen(requests.add);
    runtime.tools.handleDoubleTap(position: const Offset(90, 0));
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    expect(requests, hasLength(1));
    expect(runtime.commands.commitTextEdit(requests.single.requestId, 'after with a longer compensated layout'), isTrue);
    final request = history.records.last.request as CanvasTextEditCommitRequest;
    expect(request.before.id, request.after.id);
    expect(request.before.transform, isNot(request.after.transform));
    final text = _text(runtime);
    expect(text.id, request.after.id);
    expect(text.transform, request.after.transform);
  }

  void _mutateTextAfterRecording() {
    runtime.edits.edit((edit) {
      edit.updateElement(
        CanvasTextElementUpdate(
          id: CanvasElementId('text'),
          transform: CanvasFieldSet(CanvasTransform.translation(const Offset(1, 1))),
          opacity: const CanvasFieldSet(1),
          hitPadding: const CanvasFieldSet(0),
          isVisible: const CanvasFieldSet(false),
          isSelectable: const CanvasFieldSet(false),
          isLocked: const CanvasFieldSet(true),
          isDeletable: const CanvasFieldSet(false),
          isTransformable: const CanvasFieldSet(false),
          metadata: CanvasFieldSet(CanvasMetadata.fromMap({'version': 'later'})),
          text: const CanvasFieldSet('later'),
          fontSize: const CanvasFieldSet(12),
          color: const CanvasFieldSet(Color(0xFF000000)),
          align: const CanvasFieldSet(TextAlign.left),
          textDirection: const CanvasFieldSet(TextDirection.rtl),
          isBold: const CanvasFieldSet(false),
          isItalic: const CanvasFieldSet(false),
          isUnderline: const CanvasFieldSet(false),
          fontFamily: const CanvasFieldSet('later-family'),
          maxWidth: const CanvasFieldSet(60),
          lineHeight: const CanvasFieldSet(2),
        ),
      );
    });
    final retained = history.records.last.request as CanvasTextEditCommitRequest;
    expect(retained.after.text, 'after with a longer compensated layout');
    expect(retained.after.fontFamily, isNull);
    expect(retained.after.maxWidth, isNull);
    expect(retained.after.lineHeight, isNull);
  }

  Future<void> dispose() async {
    await _actions.cancel();
    runtime.dispose();
  }
}

final class _History {
  final List<_Record> records = <_Record>[];
  var _cursor = 0;

  bool get canUndo => _cursor > 0;
  bool get canRedo => _cursor < records.length;

  void record(CanvasCommitRequest request, {Offset? finalMoveDelta}) {
    records.removeRange(_cursor, records.length);
    records.add(_Record(request, finalMoveDelta));
    _cursor = records.length;
  }

  _Record undo(CanvasRuntime runtime) {
    final record = records[--_cursor];
    runtime.edits.edit((edit) => _apply(edit, record, undo: true));
    return record;
  }

  _Record redo(CanvasRuntime runtime) {
    final record = records[_cursor++];
    runtime.edits.edit((edit) => _apply(edit, record, undo: false));
    return record;
  }
}

final class _Record {
  const _Record(this.request, this.finalMoveDelta);
  final CanvasCommitRequest request;
  final Offset? finalMoveDelta;
}

void _apply(CanvasEdit edit, _Record record, {required bool undo}) {
  switch (record.request) {
    case CanvasDrawCommitRequest(:final entry, :final layerIndex, :final createsLayer, :final selectedElementIdsBefore):
      if (undo) {
        edit.removeElement(entry.element.id);
        if (createsLayer && entry.layerId != null) {
          final layerId = entry.layerId!;
          edit.removeEmptyLayer(layerId);
        }
      } else {
        if (entry.layerId case final layerId?) {
          edit.ensureLayer(layerId, index: layerIndex);
        }
        _restoreEntry(edit, entry);
      }
      edit.setSelection(selectedElementIdsBefore);
    case CanvasDeleteCommitRequest(:final entries, :final selectedElementIdsBefore) || CanvasEraseCommitRequest(:final entries, :final selectedElementIdsBefore):
      if (undo) {
        for (final entry in entries) {
          _restoreEntry(edit, entry);
        }
      } else {
        for (final entry in entries) {
          edit.removeElement(entry.element.id);
        }
      }
      edit.setSelection(selectedElementIdsBefore);
    case CanvasMoveCommitRequest(:final movedElements, :final selectedElementIdsBefore):
      _restoreTransforms(
        edit,
        movedElements,
        transform: undo ? null : CanvasTransform.translation(record.finalMoveDelta!),
      );
      edit.setSelection(selectedElementIdsBefore);
    case CanvasRotateCommitRequest(:final affectedElements, :final worldTransform, :final selectedElementIdsBefore) || CanvasReflectCommitRequest(:final affectedElements, :final worldTransform, :final selectedElementIdsBefore):
      _restoreTransforms(
        edit,
        affectedElements,
        transform: undo ? null : worldTransform,
      );
      edit.setSelection(selectedElementIdsBefore);
    case CanvasTextEditCommitRequest(:final before, :final after, :final selectedElementIdsBefore):
      _restoreText(edit, undo ? before : after);
      edit.setSelection(selectedElementIdsBefore);
  }
}

void _restoreEntry(CanvasEdit edit, CanvasCommitElementEntry entry) {
  if (entry.layerId case final layerId?) {
    edit.addElement(entry.element, layerId: layerId, index: entry.elementIndex);
  } else {
    edit.addBackgroundElement(entry.element, index: entry.elementIndex);
  }
}

void _restoreTransforms(
  CanvasEdit edit,
  List<CanvasElementRead> elements, {
  required CanvasTransform? transform,
}) {
  for (final element in elements) {
    edit.updateElement(
      CanvasRectElementUpdate(
        id: element.id,
        transform: CanvasFieldSet(
          transform == null ? element.transform : transform.multiply(element.transform),
        ),
      ),
    );
  }
}

void _restoreText(CanvasEdit edit, CanvasTextElement value) {
  edit.updateElement(
    CanvasTextElementUpdate(
      id: value.id,
      transform: CanvasFieldSet(value.transform),
      opacity: CanvasFieldSet(value.opacity),
      hitPadding: CanvasFieldSet(value.hitPadding),
      isVisible: CanvasFieldSet(value.isVisible),
      isSelectable: CanvasFieldSet(value.isSelectable),
      isLocked: CanvasFieldSet(value.isLocked),
      isDeletable: CanvasFieldSet(value.isDeletable),
      isTransformable: CanvasFieldSet(value.isTransformable),
      metadata: CanvasFieldSet(value.metadata),
      text: CanvasFieldSet(value.text),
      fontSize: CanvasFieldSet(value.fontSize),
      color: CanvasFieldSet(value.color),
      align: CanvasFieldSet(value.align),
      textDirection: CanvasFieldSet(value.textDirection),
      isBold: CanvasFieldSet(value.isBold),
      isItalic: CanvasFieldSet(value.isItalic),
      isUnderline: CanvasFieldSet(value.isUnderline),
      fontFamily: value.fontFamily == null
          ? const CanvasFieldClear()
          : CanvasFieldSet(value.fontFamily!),
      maxWidth: value.maxWidth == null
          ? const CanvasFieldClear()
          : CanvasFieldSet(value.maxWidth!),
      lineHeight: value.lineHeight == null
          ? const CanvasFieldClear()
          : CanvasFieldSet(value.lineHeight!),
    ),
  );
}

CanvasRectElement _rect(String id, Offset offset) => CanvasRectElement(
      id: CanvasElementId(id),
      size: const Size(12, 12),
      transform: CanvasTransform.translation(offset),
    );

CanvasLineElement _line(String id) => CanvasLineElement(
      id: CanvasElementId(id),
      start: const Offset(4, 4),
      end: const Offset(12, 8),
      thickness: 2,
      color: const Color(0xFF445566),
    );

CanvasTextElement _initialText() => CanvasTextElement(
      id: CanvasElementId('text'),
      text: 'initial',
      color: const Color(0xFF112233),
      textDirection: TextDirection.ltr,
      fontFamily: 'initial-family',
      maxWidth: 40,
      lineHeight: 1.4,
    );

void _drag(CanvasToolPort tools, Offset start, Offset end) {
  tools.handlePointer(_sample(CanvasPointerLifecyclePhase.down, start));
  tools.handlePointer(_sample(CanvasPointerLifecyclePhase.move, end));
  tools.handlePointer(_sample(CanvasPointerLifecyclePhase.up, end));
}

CanvasPointerSample _sample(CanvasPointerLifecyclePhase phase, Offset position) =>
    CanvasPointerSample(
      pointerId: 1,
      position: position,
      phase: phase,
      kind: PointerDeviceKind.touch,
    );

CanvasTextElement _text(CanvasRuntime runtime) => _textFrom(runtime.readDocument());

_ReplaySnapshot _snapshot() => _ReplaySnapshot(
      _Host._active.runtime.readDocument(),
      _Host._active.runtime.selection.selectedElementIds,
    );

void _expectSnapshot(CanvasRuntime runtime, _ReplaySnapshot expected) {
  _expectDocumentContent(runtime.readDocument(), expected.document);
  expect(runtime.selection.selectedElementIds, expected.selection);
}

final class _ReplaySnapshot {
  _ReplaySnapshot(CanvasDocument document, Iterable<CanvasElementId> selection)
      : document = document,
        selection = Set<CanvasElementId>.unmodifiable(selection);

  final CanvasDocument document;
  final Set<CanvasElementId> selection;
}

bool _sameIds(Set<CanvasElementId> left, Set<CanvasElementId> right) =>
    left.length == right.length && left.containsAll(right);

CanvasTextElement _textFrom(CanvasDocument document) => document.layers
    .expand((layer) => layer.elements)
    .whereType<CanvasTextElement>()
    .singleWhere((element) => element.id == CanvasElementId('text'));

void _expectDocumentContent(CanvasDocument actual, CanvasDocument expected) {
  expect(actual.camera, expected.camera);
  expect(actual.background, expected.background);
  expect(actual.palette.penColors, expected.palette.penColors);
  expect(actual.palette.backgroundColors, expected.palette.backgroundColors);
  expect(actual.palette.gridSizes, expected.palette.gridSizes);
  expect(actual.metadata, expected.metadata);
  expect(actual.resources.map((resource) => resource.id), expected.resources.map((resource) => resource.id));
  for (var index = 0; index < expected.resources.length; index += 1) {
    _expectResource(actual.resources[index], expected.resources[index]);
  }
  expect(actual.backgroundElements.map((element) => element.id), expected.backgroundElements.map((element) => element.id));
  for (var index = 0; index < expected.backgroundElements.length; index += 1) {
    final actualElement = actual.backgroundElements[index];
    final expectedElement = expected.backgroundElements[index];
    expect(actualElement.runtimeType, expectedElement.runtimeType);
    _expectCommonElement(actualElement, expectedElement);
    _expectElementContent(actualElement, expectedElement);
  }
  expect(actual.layers.map((layer) => layer.id), expected.layers.map((layer) => layer.id));
  for (var index = 0; index < expected.layers.length; index += 1) {
    final actualLayer = actual.layers[index];
    final expectedLayer = expected.layers[index];
    expect(actualLayer.metadata, expectedLayer.metadata);
    expect(actualLayer.elements.map((element) => element.id), expectedLayer.elements.map((element) => element.id));
    for (var elementIndex = 0; elementIndex < expectedLayer.elements.length; elementIndex += 1) {
      final actualElement = actualLayer.elements[elementIndex];
      final expectedElement = expectedLayer.elements[elementIndex];
      expect(actualElement.runtimeType, expectedElement.runtimeType);
      _expectCommonElement(actualElement, expectedElement);
      _expectElementContent(actualElement, expectedElement);
      if (actualElement is CanvasTextElement && expectedElement is CanvasTextElement) {
        _expectText(actualElement, expectedElement);
      }
    }
  }
}

void _expectResource(CanvasResource actual, CanvasResource expected) {
  expect(actual.runtimeType, expected.runtimeType);
  expect(actual.id, expected.id);
  expect(actual.source, expected.source);
  expect(actual.contentHash, expected.contentHash);
  expect(actual.byteLength, expected.byteLength);
  expect(actual.metadata, expected.metadata);
  if (actual is CanvasImageResource && expected is CanvasImageResource) {
    expect(actual.mimeType, expected.mimeType);
  }
}

void _expectCommonElement(CanvasElement actual, CanvasElement expected) {
  expect(actual.id, expected.id);
  expect(actual.transform, expected.transform);
  expect(actual.opacity, expected.opacity);
  expect(actual.hitPadding, expected.hitPadding);
  expect(actual.isVisible, expected.isVisible);
  expect(actual.isSelectable, expected.isSelectable);
  expect(actual.isLocked, expected.isLocked);
  expect(actual.isDeletable, expected.isDeletable);
  expect(actual.isTransformable, expected.isTransformable);
  expect(actual.metadata, expected.metadata);
}

void _expectElementContent(CanvasElement actual, CanvasElement expected) {
  if (actual is CanvasRectElement && expected is CanvasRectElement) {
    expect(actual.size, expected.size);
    expect(actual.fillColor, expected.fillColor);
    expect(actual.strokeColor, expected.strokeColor);
    expect(actual.strokeWidth, expected.strokeWidth);
    return;
  }
  if (actual is CanvasLineElement && expected is CanvasLineElement) {
    expect(actual.start, expected.start);
    expect(actual.end, expected.end);
    expect(actual.thickness, expected.thickness);
    expect(actual.color, expected.color);
    return;
  }
  if (actual is CanvasStrokeElement && expected is CanvasStrokeElement) {
    expect(actual.points, expected.points);
    expect(actual.thickness, expected.thickness);
    expect(actual.color, expected.color);
    return;
  }
  if (actual is CanvasTextElement && expected is CanvasTextElement) {
    return;
  }
  fail('Unexpected public replay element type: ${actual.runtimeType}.');
}

void _expectText(CanvasTextElement actual, CanvasTextElement expected) {
  expect(actual.id, expected.id);
  expect(actual.transform, expected.transform);
  expect(actual.opacity, expected.opacity);
  expect(actual.hitPadding, expected.hitPadding);
  expect(actual.isVisible, expected.isVisible);
  expect(actual.isSelectable, expected.isSelectable);
  expect(actual.isLocked, expected.isLocked);
  expect(actual.isDeletable, expected.isDeletable);
  expect(actual.isTransformable, expected.isTransformable);
  expect(actual.metadata['version'], expected.metadata['version']);
  expect(actual.text, expected.text);
  expect(actual.fontSize, expected.fontSize);
  expect(actual.color, expected.color);
  expect(actual.align, expected.align);
  expect(actual.textDirection, expected.textDirection);
  expect(actual.isBold, expected.isBold);
  expect(actual.isItalic, expected.isItalic);
  expect(actual.isUnderline, expected.isUnderline);
  expect(actual.fontFamily, expected.fontFamily);
  expect(actual.maxWidth, expected.maxWidth);
  expect(actual.lineHeight, expected.lineHeight);
}

Future<void> _exerciseDrawLayerProvenance() async {
  final zero = _DrawHost();
  try {
    zero.draw();
    final request = zero.history.records.single.request as CanvasDrawCommitRequest;
    expect(request.createsLayer, isTrue);
    zero.history.undo(zero.runtime);
    expect(zero.runtime.readDocument().layers, isEmpty);
    _expectDrawHostRetainedState(zero.runtime);
    expect(zero.runtime.selection.selectedElementIds, request.selectedElementIdsBefore);
    zero.history.redo(zero.runtime);
    _expectDrawReplay(zero.runtime, request);
  } finally {
    await zero.dispose();
  }

  final existing = _DrawHost();
  try {
    existing.runtime.edits.edit(
      (edit) => edit.ensureLayer(CanvasLayerId('default-layer')),
    );
    existing.draw();
    final request = existing.history.records.single.request as CanvasDrawCommitRequest;
    expect(request.createsLayer, isFalse);
    existing.history.undo(existing.runtime);
    expect(existing.runtime.readDocument().layers.map((layer) => layer.id), [CanvasLayerId('default-layer')]);
    expect(existing.runtime.readDocument().layers.single.elements, isEmpty);
    _expectDrawHostRetainedState(existing.runtime);
    expect(existing.runtime.selection.selectedElementIds, request.selectedElementIdsBefore);
    existing.history.redo(existing.runtime);
    _expectDrawReplay(existing.runtime, request);
  } finally {
    await existing.dispose();
  }

  final laterContent = _DrawHost();
  try {
    laterContent.draw();
    final request = laterContent.history.records.single.request as CanvasDrawCommitRequest;
    expect(request.createsLayer, isTrue);
    laterContent.runtime.edits.edit((edit) {
      edit.addElement(
        _rect('later', const Offset(30, 0)),
        layerId: CanvasLayerId('default-layer'),
      );
    });
    laterContent.history.undo(laterContent.runtime);
    final layer = laterContent.runtime.readDocument().layers.single;
    expect(layer.elements.map((element) => element.id), [CanvasElementId('later')]);
    _expectDrawHostRetainedState(laterContent.runtime);
    expect(laterContent.runtime.selection.selectedElementIds, request.selectedElementIdsBefore);
    laterContent.history.redo(laterContent.runtime);
    _expectDrawReplay(laterContent.runtime, request, trailingId: CanvasElementId('later'));
  } finally {
    await laterContent.dispose();
  }
}

void _expectDrawHostRetainedState(CanvasRuntime runtime) {
  final document = runtime.readDocument();
  expect(document.resources, hasLength(1));
  final resource = document.resources.single as CanvasImageResource;
  expect(resource.source, CanvasResourceSource.appKey('provenance-asset'));
  expect(resource.metadata, CanvasMetadata.fromMap({'owner': 'provenance'}));
  expect(document.background.color, const Color(0xFF336699));
  expect(document.background.grid, CanvasGrid(enabled: true, cellSize: 20));
  expect(document.backgroundElements.map((element) => element.id), [CanvasElementId('provenance-background')]);
  final background = document.backgroundElements.single as CanvasRectElement;
  expect(background.transform, CanvasTransform.translation(const Offset(-5, 8)));
  expect(background.size, const Size(7, 9));
}

void _expectDrawReplay(
  CanvasRuntime runtime,
  CanvasDrawCommitRequest request, {
  CanvasElementId? trailingId,
}) {
  final document = runtime.readDocument();
  _expectDrawHostRetainedState(runtime);
  final layer = document.layers.singleWhere((layer) => layer.id == request.entry.layerId);
  final expectedIds = <CanvasElementId>[request.entry.element.id];
  if (trailingId != null) {
    expectedIds.add(trailingId);
  }
  expect(layer.elements.map((element) => element.id), expectedIds);
  expect(layer.elements[request.entry.elementIndex].id, request.entry.element.id);
  _expectElementContent(layer.elements[request.entry.elementIndex], request.entry.element);
  expect(runtime.selection.selectedElementIds, request.selectedElementIdsBefore);
}

final class _DrawHost implements CanvasCommitLease {
  _DrawHost()
      : runtime = CanvasRuntime(
          config: CanvasRuntimeConfig(commitResolver: _resolve),
        ) {
    _active = this;
    runtime.edits.edit((edit) {
      edit.setBackgroundColor(const Color(0xFF336699));
      edit.setGrid(CanvasGrid(enabled: true, cellSize: 20));
      edit.upsertResource(
        CanvasImageResource(
          id: CanvasResourceId('provenance-resource'),
          source: CanvasResourceSource.appKey('provenance-asset'),
          metadata: CanvasMetadata.fromMap({'owner': 'provenance'}),
        ),
      );
      edit.addBackgroundElement(
        CanvasRectElement(
          id: CanvasElementId('provenance-background'),
          size: const Size(7, 9),
          transform: CanvasTransform.translation(const Offset(-5, 8)),
        ),
      );
    });
  }

  static late _DrawHost _active;
  final CanvasRuntime runtime;
  final _History history = _History();
  CanvasCommitRequest? _request;

  static CanvasCommitResolution _resolve(CanvasCommitRequest request) {
    _active._request = request;
    return CanvasCommitAccept(lease: _active);
  }

  @override
  void committed() {
    history.record(_request!);
  }

  @override
  void aborted() {}

  void draw() {
    runtime.tools.setMode(CanvasInteractionMode.draw);
    runtime.tools.setDrawStyle(
      CanvasDrawStyle(tool: CanvasDrawTool.pencil, pencilThickness: 2),
    );
    _drag(runtime.tools, Offset.zero, const Offset(4, 4));
  }

  Future<void> dispose() async => runtime.dispose();
}
''';
