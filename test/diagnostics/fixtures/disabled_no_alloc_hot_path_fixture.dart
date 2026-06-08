import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/codec/schema_v1_decoder.dart';
import 'package:iwb_canvas_engine/src/diagnostics/diagnostic_code.dart';
import 'package:iwb_canvas_engine/src/diagnostics/diagnostics_hub.dart';

void main() {
  test('disabled diagnostics do not allocate records or build details', () {
    expect(expectDisabledDiagnosticsDoNotAllocate, returnsNormally);
  });

  test('enabled diagnostics apply verbose policy limits to records', () {
    expect(expectVerboseDiagnosticsApplyLimits, returnsNormally);
  });

  test('successful schema codec operations do not allocate records', () {
    expect(expectSuccessfulSchemaCodecDoesNotAllocateRecords, returnsNormally);
  });
}

void expectDisabledDiagnosticsDoNotAllocate() {
  DiagnosticRecord.allocations.reset();
  var detailsBuilt = false;
  final hub = DiagnosticsHub(policy: const CanvasDiagnosticPolicy.disabled());

  hub.record(
    DiagnosticEvent(
      code: const DiagnosticCode.data(CanvasDataErrorCode.invalidJson),
      severity: DiagnosticSeverity.info,
      source: DiagnosticSource.codec,
      path: r'$.schemaVersion',
      details: () {
        detailsBuilt = true;

        return {'schemaVersion': 1};
      },
    ),
  );

  expect(detailsBuilt, isFalse);
  expect(hub.recordCount, 0);
  expect(DiagnosticRecord.allocations.count, 0);
}

void expectVerboseDiagnosticsApplyLimits() {
  final hub = DiagnosticsHub(
    policy: CanvasDiagnosticPolicy.verbose(
      maxPreviewLength: 4,
      maxListEntries: 2,
    ),
  );

  hub.record(
    DiagnosticEvent(
      code: const DiagnosticCode.data(CanvasDataErrorCode.invalidJson),
      severity: DiagnosticSeverity.warning,
      source: DiagnosticSource.codec,
      details: () {
        return {
          'text': 'abcdef',
          'items': [1, 2, 3],
          'nested': {'first': 1, 'second': 2, 'third': 3},
        };
      },
    ),
  );

  expect(hub.recordCount, 1);
  expect(hub.records.single.details, {
    'text': 'abcd<truncated>',
    'item<truncated>': [1, 2],
  });
}

void expectSuccessfulSchemaCodecDoesNotAllocateRecords() {
  DiagnosticRecord.allocations.reset();
  final document = CanvasDocument(
    backgroundElements: [
      CanvasRectElement(id: CanvasElementId('rect-a'), size: const Size(2, 2)),
    ],
  );
  final before = DiagnosticRecord.allocations.count;

  final encoded = encodeCanvasDocument(document);
  final encodedJson = encodeCanvasDocumentToJson(document);
  expect(decodeSchemaV1Document(encoded), isA<CanvasDocument>());
  expect(decodeSchemaV1DocumentFromJson(encodedJson), isA<CanvasDocument>());

  expect(DiagnosticRecord.allocations.count, before);
}
