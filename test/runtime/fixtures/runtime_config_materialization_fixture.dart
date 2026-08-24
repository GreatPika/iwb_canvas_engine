import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_read_port.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_config.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import "../../support/runtime_root_with_committed_document_seed.dart";

void main() {
  test('RuntimeRoot owns materialized diagnostic verbose limits', () {
    final root = _runtimeRootWithDiagnostics(
      CanvasDiagnosticPolicy.verbose(maxPreviewLength: 17, maxListEntries: 9),
    );

    final diagnostics = root.config.diagnostics;

    expect(diagnostics, isA<RuntimeDiagnosticsVerboseConfig>());
    expect(
      diagnostics,
      isA<RuntimeDiagnosticsVerboseConfig>()
          .having((config) => config.maxPreviewLength, 'maxPreviewLength', 17)
          .having((config) => config.maxListEntries, 'maxListEntries', 9),
    );

    root.dispose();
  });

  test('RuntimeRoot owns materialized non-verbose diagnostic variants', () {
    final disabledRoot = _runtimeRootWithDiagnostics(
      const CanvasDiagnosticPolicy.disabled(),
    );
    final summaryRoot = _runtimeRootWithDiagnostics(
      const CanvasDiagnosticPolicy.summary(),
    );

    expect(
      disabledRoot.config.diagnostics,
      isA<RuntimeDiagnosticsDisabledConfig>(),
    );
    expect(
      summaryRoot.config.diagnostics,
      isA<RuntimeDiagnosticsSummaryConfig>(),
    );

    disabledRoot.dispose();
    summaryRoot.dispose();
  });

  // Assertions live in the named policy-materialization scenario.
  // ignore: missing-test-assertion
  test(
    'RuntimeRoot materializes the selection delete policy',
    _runtimeRootMaterializesSelectionDeletePolicy,
  );
  // Assertions live in the named runtime-policy scenario below.
  // ignore: missing-test-assertion
  test(
    'RuntimeRoot owns one immutable eraser kind policy copy',
    _runtimeRootOwnsEraserKindPolicyCopy,
  );
}

void _runtimeRootMaterializesSelectionDeletePolicy() {
  final defaultRoot = runtimeRootWithCommittedDocumentSeed(CanvasDocument());
  final allOrNoneRoot = runtimeRootWithCommittedDocumentSeed(
    CanvasDocument(),
    config: const CanvasRuntimeConfig(
      selectionDeletePolicy: CanvasSelectionDeletePolicy.allOrNone,
    ),
  );
  addTearDown(defaultRoot.dispose);
  addTearDown(allOrNoneRoot.dispose);

  expect(
    defaultRoot.config.selectionDeletePolicy,
    CanvasSelectionDeletePolicy.partial,
  );
  expect(
    allOrNoneRoot.config.selectionDeletePolicy,
    CanvasSelectionDeletePolicy.allOrNone,
  );
}

// This scenario keeps source mutation, stored-policy mutation, and real read
// behavior together because all three are required to prove policy ownership.
// ignore: halstead-volume, source-lines-of-code
void _runtimeRootOwnsEraserKindPolicyCopy() {
  final suppliedKinds = <CanvasElementKind>{CanvasElementKind.rect};
  final unrestrictedRoot = runtimeRootWithCommittedDocumentSeed(
    _eraserPolicyDocument(),
  );
  final disabledRoot = runtimeRootWithCommittedDocumentSeed(
    _eraserPolicyDocument(),
    config: const CanvasRuntimeConfig(eraserElementKinds: {}),
  );
  final restrictedRoot = runtimeRootWithCommittedDocumentSeed(
    _eraserPolicyDocument(),
    config: CanvasRuntimeConfig(eraserElementKinds: suppliedKinds),
  );
  addTearDown(unrestrictedRoot.dispose);
  addTearDown(disabledRoot.dispose);
  addTearDown(restrictedRoot.dispose);

  suppliedKinds
    ..clear()
    ..add(CanvasElementKind.text);

  expect(unrestrictedRoot.config.eraserElementKinds, isNull);
  expect(disabledRoot.config.eraserElementKinds, isEmpty);
  final materializedKinds = switch (restrictedRoot.config.eraserElementKinds) {
    final kinds? => kinds,
    null => fail('restricted runtime must retain a materialized kind policy'),
  };
  expect(materializedKinds, {CanvasElementKind.rect});
  expect(
    () => materializedKinds.add(CanvasElementKind.text),
    throwsUnsupportedError,
  );

  final request = EraserReadRequest(
    corridorPoints: const [Offset(0, 0)],
    eraserThickness: 2,
  );
  expect(
    unrestrictedRoot.interactionReadPort
        .eraserTerminalFacts(request)
        .erasedElementIds,
    [CanvasElementId('text'), CanvasElementId('rect')],
  );
  expect(
    disabledRoot.interactionReadPort
        .eraserTerminalFacts(request)
        .erasedElementIds,
    isEmpty,
  );
  expect(
    restrictedRoot.interactionReadPort
        .eraserPreviewFacts(request)
        .erasedElementIds,
    [CanvasElementId('rect')],
  );
  expect(
    restrictedRoot.interactionReadPort
        .eraserTerminalFacts(request)
        .erasedElementIds,
    [CanvasElementId('rect')],
  );
}

CanvasDocument _eraserPolicyDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('eraser-policy-layer'),
        elements: [
          CanvasTextElement(
            id: CanvasElementId('text'),
            text: 'text',
            color: const Color(0xFF000000),
            textDirection: TextDirection.ltr,
            transform: CanvasTransform.translation(const Offset(-5, -5)),
          ),
          CanvasRectElement(
            id: CanvasElementId('rect'),
            size: const Size(10, 10),
            transform: CanvasTransform.translation(const Offset(-5, -5)),
          ),
        ],
      ),
    ],
  );
}

RuntimeRoot _runtimeRootWithDiagnostics(CanvasDiagnosticPolicy policy) {
  return runtimeRootWithCommittedDocumentSeed(
    CanvasDocument(),
    config: CanvasRuntimeConfig(diagnosticPolicy: policy),
  );
}
