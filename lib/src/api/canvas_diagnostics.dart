import 'package:flutter/foundation.dart';

import 'canvas_contract_limits.dart';
import 'canvas_value_validators.dart';

@immutable
sealed class CanvasDiagnosticPolicy {
  const CanvasDiagnosticPolicy();
  const factory CanvasDiagnosticPolicy.disabled() = CanvasDiagnosticsDisabled;
  const factory CanvasDiagnosticPolicy.summary() = CanvasDiagnosticsSummary;
  factory CanvasDiagnosticPolicy.verbose({
    int maxPreviewLength,
    int maxListEntries,
  }) = CanvasDiagnosticsVerbose;
}

@immutable
final class CanvasDiagnosticsDisabled extends CanvasDiagnosticPolicy {
  const CanvasDiagnosticsDisabled();

  @override
  bool operator ==(Object other) {
    return other is CanvasDiagnosticsDisabled;
  }

  @override
  int get hashCode => runtimeType.hashCode;
}

@immutable
final class CanvasDiagnosticsSummary extends CanvasDiagnosticPolicy {
  const CanvasDiagnosticsSummary();

  @override
  bool operator ==(Object other) {
    return other is CanvasDiagnosticsSummary;
  }

  @override
  int get hashCode => runtimeType.hashCode;
}

@immutable
final class CanvasDiagnosticsVerbose extends CanvasDiagnosticPolicy {
  factory CanvasDiagnosticsVerbose({
    int maxPreviewLength = canvasDiagnosticVerbosePreviewLengthDefault,
    int maxListEntries = canvasDiagnosticVerboseListEntriesDefault,
  }) {
    validateIntegerRange(
      maxPreviewLength,
      path: 'diagnostics.maxPreviewLength',
      min: canvasDiagnosticVerbosePreviewLengthMin,
      max: canvasDiagnosticVerbosePreviewLengthMax,
    );
    validateIntegerRange(
      maxListEntries,
      path: 'diagnostics.maxListEntries',
      min: canvasDiagnosticVerboseListEntriesMin,
      max: canvasDiagnosticVerboseListEntriesMax,
    );

    return CanvasDiagnosticsVerbose._(
      maxPreviewLength: maxPreviewLength,
      maxListEntries: maxListEntries,
    );
  }

  const CanvasDiagnosticsVerbose._({
    this.maxPreviewLength = canvasDiagnosticVerbosePreviewLengthDefault,
    this.maxListEntries = canvasDiagnosticVerboseListEntriesDefault,
  });

  final int maxPreviewLength;
  final int maxListEntries;

  @override
  bool operator ==(Object other) {
    return other is CanvasDiagnosticsVerbose &&
        other.maxPreviewLength == maxPreviewLength &&
        other.maxListEntries == maxListEntries;
  }

  @override
  int get hashCode => Object.hash(maxPreviewLength, maxListEntries);
}
