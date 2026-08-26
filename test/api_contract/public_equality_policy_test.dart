import 'package:test/test.dart';

import '../support/flutter_consumer_test_harness.dart';

void main() {
  test('public equality policy matches the v1 contract', () async {
    await expectLater(
      runFlutterConsumerTest(
        packageName: 'iwb_canvas_engine_equality_policy_consumer',
        testFileName: 'equality_policy_test.dart',
        testSource: _equalityPolicySource,
      ),
      completes,
    );
  });
}

const _equalityPolicySource = '''
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('contract-listed value types compare by public values', () {
    _expectValueEquality(CanvasElementId('element-1'), CanvasElementId('element-1'));
    _expectValueEquality(CanvasLayerId('layer-1'), CanvasLayerId('layer-1'));
    _expectValueEquality(CanvasResourceId('resource-1'), CanvasResourceId('resource-1'));
    _expectValueEquality(CanvasActionId('action-1'), CanvasActionId('action-1'));
    _expectValueEquality(
      CanvasInteractionRequestId('request-1'),
      CanvasInteractionRequestId('request-1'),
    );

    _expectValueEquality(_runtimeRevisions(), _runtimeRevisions());
    _expectValueEquality(_runtimeSummary(), _runtimeSummary());
    _expectValueEquality(
      CanvasRuntimeState(
        revisions: _runtimeRevisions(),
        summary: _runtimeSummary(),
      ),
      CanvasRuntimeState(
        revisions: _runtimeRevisions(),
        summary: _runtimeSummary(),
      ),
    );
    _expectValueEquality(
      CanvasSelectionDeleteAvailability(
        hasSelection: true,
        allSelectedElementsDeletable: true,
        hasAnySelectedElementDeletable: true,
      ),
      CanvasSelectionDeleteAvailability(
        hasSelection: true,
        allSelectedElementsDeletable: true,
        hasAnySelectedElementDeletable: true,
      ),
    );
    expect(
      const CanvasSelectionDeleteAvailability(
        hasSelection: true,
        allSelectedElementsDeletable: false,
        hasAnySelectedElementDeletable: true,
      ),
      isNot(
        const CanvasSelectionDeleteAvailability(
          hasSelection: true,
          allSelectedElementsDeletable: false,
          hasAnySelectedElementDeletable: false,
        ),
      ),
    );
    final availabilitySet = {
      CanvasSelectionDeleteAvailability(
        hasSelection: true,
        allSelectedElementsDeletable: true,
        hasAnySelectedElementDeletable: true,
      ),
    };
    expect(
      availabilitySet,
      contains(
        CanvasSelectionDeleteAvailability(
          hasSelection: true,
          allSelectedElementsDeletable: true,
          hasAnySelectedElementDeletable: true,
        ),
      ),
    );

    final deletionElement = CanvasRectElement(
      id: CanvasElementId('deletion-element'),
      size: const Size(1, 1),
    );
    final deletionEntry = CanvasDeletionEntry(
      element: deletionElement,
      layerId: CanvasLayerId('layer-1'),
      elementIndex: 0,
    );
    final deletionRequest = CanvasDeletionCommitRequest(
      operation: CanvasDeletionOperation.deleteSelection,
      entries: [deletionEntry],
    );
    expect(
      CanvasDeletionEntry(
        element: deletionElement,
        layerId: CanvasLayerId('layer-1'),
        elementIndex: 0,
      ),
      isNot(equals(deletionEntry)),
    );
    expect(
      CanvasDeletionCommitRequest(
        operation: CanvasDeletionOperation.deleteSelection,
        entries: [deletionEntry],
      ),
      isNot(equals(deletionRequest)),
    );

    _expectValueEquality(
      CanvasTransform(a: 1, b: 2, c: 3, d: 4, tx: 5, ty: 6),
      CanvasTransform(a: 1, b: 2, c: 3, d: 4, tx: 5, ty: 6),
    );
    _expectValueEquality(
      CanvasFieldUpdate<int>.absent(),
      CanvasFieldUpdate<int>.absent(),
    );
    _expectValueEquality(
      CanvasFieldSet<int>(1),
      CanvasFieldSet<int>(1),
    );
    _expectValueEquality(
      CanvasFieldClear<String>(),
      CanvasFieldClear<String>(),
    );
    _expectValueEquality(
      CanvasMetadata.fromMap({
        'a': [
          {'b': true},
        ],
      }),
      CanvasMetadata.fromMap({
        'a': [
          {'b': true},
        ],
      }),
    );
    _expectValueEquality(
      CanvasDocumentSummary(
        elementCount: 1,
        layerCount: 2,
        resourceCount: 3,
      ),
      CanvasDocumentSummary(
        elementCount: 1,
        layerCount: 2,
        resourceCount: 3,
      ),
    );
    _expectValueEquality(
      CanvasCamera(offset: const Offset(1, 2)),
      CanvasCamera(offset: const Offset(1, 2)),
    );
    _expectValueEquality(
      CanvasBackground(grid: CanvasGrid(enabled: true, cellSize: 10)),
      CanvasBackground(grid: CanvasGrid(enabled: true, cellSize: 10)),
    );
    _expectValueEquality(
      CanvasGrid(enabled: true, cellSize: 10),
      CanvasGrid(enabled: true, cellSize: 10),
    );
    _expectValueEquality(
      CanvasSelectionStyle(strokeWidth: 2),
      CanvasSelectionStyle(strokeWidth: 2),
    );
    _expectValueEquality(
      CanvasGridStyle(strokeWidth: 2),
      CanvasGridStyle(strokeWidth: 2),
    );
    _expectValueEquality(
      CanvasPointerPolicy(tapSlop: 2),
      CanvasPointerPolicy(tapSlop: 2),
    );
    _expectValueEquality(
      CanvasPointerSample(
        pointerId: 1,
        position: const Offset(1, 2),
        phase: CanvasPointerLifecyclePhase.down,
        kind: PointerDeviceKind.touch,
      ),
      CanvasPointerSample(
        pointerId: 1,
        position: const Offset(1, 2),
        phase: CanvasPointerLifecyclePhase.down,
        kind: PointerDeviceKind.touch,
      ),
    );
    _expectValueEquality(
      CanvasPointerTerminalCleanup(
        pointerId: 1,
        phase: CanvasPointerLifecyclePhase.up,
        kind: PointerDeviceKind.touch,
        timestampMs: 3,
      ),
      CanvasPointerTerminalCleanup(
        pointerId: 1,
        phase: CanvasPointerLifecyclePhase.up,
        kind: PointerDeviceKind.touch,
        timestampMs: 3,
      ),
    );
    _expectValueEquality(
      CanvasDrawStyle(tool: CanvasDrawTool.marker),
      CanvasDrawStyle(tool: CanvasDrawTool.marker),
    );
    _expectValueEquality(
      CanvasResourceSource.appKey('asset-main'),
      CanvasResourceSource.appKey('asset-main'),
    );
    _expectValueEquality(
      CanvasElementRead(
        id: CanvasElementId('element-1'),
        kind: CanvasElementKind.rect,
        revision: 1,
        boundsWorld: const Rect.fromLTWH(0, 0, 1, 1),
        transform: CanvasTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0),
        isLocked: false,
        isTransformable: true,
      ),
      CanvasElementRead(
        id: CanvasElementId('element-1'),
        kind: CanvasElementKind.rect,
        revision: 1,
        boundsWorld: const Rect.fromLTWH(0, 0, 1, 1),
        transform: CanvasTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0),
        isLocked: false,
        isTransformable: true,
      ),
    );
    _expectValueEquality(
      CanvasMoveCommit(delta: const Offset(1, 2)),
      CanvasMoveCommit(delta: const Offset(1, 2)),
    );
    _expectValueEquality(
      CanvasMoveCancel(reason: 'blocked'),
      CanvasMoveCancel(reason: 'blocked'),
    );
    _expectValueEquality(
      CanvasDiagnosticPolicy.disabled(),
      CanvasDiagnosticPolicy.disabled(),
    );
    _expectValueEquality(
      CanvasDiagnosticPolicy.summary(),
      CanvasDiagnosticPolicy.summary(),
    );
    _expectValueEquality(
      CanvasDiagnosticPolicy.verbose(maxPreviewLength: 20, maxListEntries: 3),
      CanvasDiagnosticPolicy.verbose(maxPreviewLength: 20, maxListEntries: 3),
    );
  });

  test('contract-listed identity types keep identity equality', () {
    final firstPaletteUpdate = CanvasPaletteUpdate(
      penColors: const [Color(0xFF102030)],
    );
    final secondPaletteUpdate = CanvasPaletteUpdate(
      penColors: const [Color(0xFF102030)],
    );
    expect(identical(firstPaletteUpdate, secondPaletteUpdate), isFalse);
    expect(firstPaletteUpdate, isNot(secondPaletteUpdate));
    expect(firstPaletteUpdate, firstPaletteUpdate);
    expect({firstPaletteUpdate}, contains(firstPaletteUpdate));
    expect({firstPaletteUpdate}, isNot(contains(secondPaletteUpdate)));

    final firstGridUpdate = CanvasGridUpdate(cellSize: 12);
    final secondGridUpdate = CanvasGridUpdate(cellSize: 12);
    expect(identical(firstGridUpdate, secondGridUpdate), isFalse);
    expect(firstGridUpdate, isNot(secondGridUpdate));
    expect(firstGridUpdate, firstGridUpdate);
    expect({firstGridUpdate}, contains(firstGridUpdate));
    expect({firstGridUpdate}, isNot(contains(secondGridUpdate)));

    final firstAppearance = CanvasAppearance(
      backgroundColor: const Color(0xFF102030),
      grid: CanvasGrid.disabled,
      palette: CanvasPalette.defaults(),
    );
    final secondAppearance = CanvasAppearance(
      backgroundColor: const Color(0xFF102030),
      grid: CanvasGrid.disabled,
      palette: CanvasPalette.defaults(),
    );
    expect(identical(firstAppearance, secondAppearance), isFalse);
    expect(firstAppearance, isNot(secondAppearance));
    expect(firstAppearance, firstAppearance);
    expect({firstAppearance}, contains(firstAppearance));
    expect({firstAppearance}, isNot(contains(secondAppearance)));
    expect(CanvasDocument(), isNot(CanvasDocument()));
    expect(
      CanvasImageResource(
        id: CanvasResourceId('resource-1'),
        source: CanvasResourceSource.appKey('resource-1'),
      ),
      isNot(
        CanvasImageResource(
          id: CanvasResourceId('resource-1'),
          source: CanvasResourceSource.appKey('resource-1'),
        ),
      ),
    );
    expect(
      CanvasDataException(
        code: CanvasDataErrorCode.invalidJson,
        message: 'invalid',
        path: r'\$',
      ),
      isNot(
        CanvasDataException(
          code: CanvasDataErrorCode.invalidJson,
          message: 'invalid',
          path: r'\$',
        ),
      ),
    );
  });

  test('prepared vectors retain default identity through disposal', () async {
    final first = await prepareVector(_basicPreparedVectorBytes());
    final second = await prepareVector(_basicPreparedVectorBytes());
    final firstHashCode = first.hashCode;
    final secondHashCode = second.hashCode;

    expect(first.intrinsicSize, second.intrinsicSize);
    expect(identical(first, second), isFalse);
    expect(first == second, isFalse);

    first.dispose();
    second.dispose();

    expect(first == second, isFalse);
    expect(first.hashCode, firstHashCode);
    expect(second.hashCode, secondHashCode);
  });
}

ByteData _basicPreparedVectorBytes() => ByteData.sublistView(
  Uint8List.fromList(
    base64Decode(
      'Yi2IAAEpAAAgQQAAoEEcmWYz/wMAAP//GwAAAAUAAAAAAQEBAwgAAAAAAAAAAAAAAAAAAAAAIEEAAAAAAAAgQQAAoEEAAAAAAACgQTAeAAAAAP//',
    ),
  ),
);

void _expectValueEquality(Object left, Object right) {
  expect(identical(left, right), isFalse);
  expect(left, right);
  expect(left.hashCode, right.hashCode);
}

CanvasRuntimeRevisions _runtimeRevisions() {
  return CanvasRuntimeRevisions(
    document: 1,
    selection: 2,
    preview: 3,
    viewCamera: 4,
    resourceVisual: 5,
    interaction: 6,
    epoch: 7,
  );
}

CanvasRuntimeSummary _runtimeSummary() {
  return CanvasRuntimeSummary(
    elementCount: 1,
    layerCount: 2,
    resourceCount: 3,
    selectedCount: 4,
  );
}
''';
