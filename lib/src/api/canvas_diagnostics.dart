sealed class CanvasDiagnosticPolicy {
  const CanvasDiagnosticPolicy();
  const factory CanvasDiagnosticPolicy.disabled() = CanvasDiagnosticsDisabled;
  const factory CanvasDiagnosticPolicy.summary() = CanvasDiagnosticsSummary;
  factory CanvasDiagnosticPolicy.verbose({
    int maxPreviewLength,
    int maxListEntries,
  }) = CanvasDiagnosticsVerbose;
}

final class CanvasDiagnosticsDisabled extends CanvasDiagnosticPolicy {
  const CanvasDiagnosticsDisabled();
}

final class CanvasDiagnosticsSummary extends CanvasDiagnosticPolicy {
  const CanvasDiagnosticsSummary();
}

final class CanvasDiagnosticsVerbose extends CanvasDiagnosticPolicy {
  const CanvasDiagnosticsVerbose({
    this.maxPreviewLength = 256,
    this.maxListEntries = 32,
  });

  final int maxPreviewLength;
  final int maxListEntries;
}
