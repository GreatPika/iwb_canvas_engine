import '../contracts/public/canvas_actions.dart';
import '../contracts/public/canvas_diagnostics.dart';
import '../contracts/public/canvas_pointer.dart';
import '../contracts/public/canvas_runtime.dart';
import '../contracts/public/canvas_tools.dart';

final class RuntimeConfig {
  RuntimeConfig.from(CanvasRuntimeConfig config)
    : pointerPolicy = config.pointerPolicy,
      initialMode = config.initialMode,
      initialDrawStyle = config.initialDrawStyle,
      clearSelectionOnDrawModeEnter = config.clearSelectionOnDrawModeEnter,
      moveCommitResolver = config.moveCommitResolver,
      diagnostics = RuntimeDiagnosticsConfig.from(config.diagnosticPolicy);

  final CanvasPointerPolicy pointerPolicy;
  final CanvasInteractionMode initialMode;
  final CanvasDrawStyle initialDrawStyle;
  final bool clearSelectionOnDrawModeEnter;
  final CanvasMoveCommitResolver? moveCommitResolver;
  final RuntimeDiagnosticsConfig diagnostics;
}

sealed class RuntimeDiagnosticsConfig {
  const RuntimeDiagnosticsConfig();

  factory RuntimeDiagnosticsConfig.from(CanvasDiagnosticPolicy policy) {
    return switch (policy) {
      CanvasDiagnosticsDisabled() => const RuntimeDiagnosticsDisabledConfig(),
      CanvasDiagnosticsSummary() => const RuntimeDiagnosticsSummaryConfig(),
      CanvasDiagnosticsVerbose(
        :final maxPreviewLength,
        :final maxListEntries,
      ) =>
        RuntimeDiagnosticsVerboseConfig(
          maxPreviewLength: maxPreviewLength,
          maxListEntries: maxListEntries,
        ),
    };
  }
}

final class RuntimeDiagnosticsDisabledConfig extends RuntimeDiagnosticsConfig {
  const RuntimeDiagnosticsDisabledConfig();
}

final class RuntimeDiagnosticsSummaryConfig extends RuntimeDiagnosticsConfig {
  const RuntimeDiagnosticsSummaryConfig();
}

final class RuntimeDiagnosticsVerboseConfig extends RuntimeDiagnosticsConfig {
  const RuntimeDiagnosticsVerboseConfig({
    required this.maxPreviewLength,
    required this.maxListEntries,
  });

  final int maxPreviewLength;
  final int maxListEntries;
}
