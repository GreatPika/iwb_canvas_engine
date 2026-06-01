import 'package:test/test.dart';

import '../support/flutter_consumer_test_harness.dart';

void main() {
  test(
    'disabled diagnostics do not allocate records on codec success',
    () async {
      await expectLater(
        runFlutterConsumerTest(
          packageName: 'iwb_canvas_engine_diagnostics_no_alloc',
          testFileName: 'disabled_no_alloc_hot_path_test.dart',
          testSource: _disabledNoAllocHotPathSource,
        ),
        completes,
      );
    },
  );
}

const _disabledNoAllocHotPathSource = r'''
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/diagnostics/diagnostic_code.dart';
import 'package:iwb_canvas_engine/src/diagnostics/diagnostics_hub.dart';

void main() {
  test('disabled diagnostics do not allocate records or build details', () {
    DiagnosticRecord.allocations.reset();
    var detailsBuilt = false;
    final hub = DiagnosticsHub(
      policy: const CanvasDiagnosticPolicy.disabled(),
    );

    hub.record(DiagnosticEvent(
      code: DiagnosticCode.data(CanvasDataErrorCode.invalidJson),
      severity: DiagnosticSeverity.info,
      source: DiagnosticSource.codec,
      path: r'$.schemaVersion',
      details: () {
        detailsBuilt = true;

        return {'schemaVersion': 1};
      },
    ));

    expect(detailsBuilt, isFalse);
    expect(hub.recordCount, 0);
    expect(DiagnosticRecord.allocations.count, 0);
  });

  test('enabled diagnostics apply verbose policy limits to records', () {
    final hub = DiagnosticsHub(
      policy: CanvasDiagnosticPolicy.verbose(
        maxPreviewLength: 4,
        maxListEntries: 2,
      ),
    );

    hub.record(DiagnosticEvent(
      code: DiagnosticCode.data(CanvasDataErrorCode.invalidJson),
      severity: DiagnosticSeverity.warning,
      source: DiagnosticSource.codec,
      details: () {
        return {
          'text': 'abcdef',
          'items': [1, 2, 3],
          'nested': {'first': 1, 'second': 2, 'third': 3},
        };
      },
    ));

    expect(hub.recordCount, 1);
    expect(hub.records.single.details, {
      'text': 'abcd<truncated>',
      'item<truncated>': [1, 2],
    });
  });

  test('successful schema codec operations do not allocate diagnostic records', () {
    DiagnosticRecord.allocations.reset();
    final document = CanvasDocument(
      backgroundElements: [
        CanvasRectElement(
          id: CanvasElementId('rect-a'),
          size: const Size(2, 2),
        ),
      ],
    );
    final before = DiagnosticRecord.allocations.count;

    final encoded = encodeCanvasDocument(document);
    final encodedJson = encodeCanvasDocumentToJson(document);
    expect(decodeCanvasDocument(encoded), isA<CanvasDocument>());
    expect(decodeCanvasDocumentFromJson(encodedJson), isA<CanvasDocument>());

    expect(DiagnosticRecord.allocations.count, before);
  });
}
''';
