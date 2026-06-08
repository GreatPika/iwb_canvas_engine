import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
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
}

RuntimeRoot _runtimeRootWithDiagnostics(CanvasDiagnosticPolicy policy) {
  return runtimeRootWithCommittedDocumentSeed(
    CanvasDocument(),
    config: CanvasRuntimeConfig(diagnosticPolicy: policy),
  );
}
