import '../contracts/public/canvas_error_details_sanitizer.dart';
import '../contracts/public/canvas_diagnostics.dart';
import 'diagnostic_code.dart';

typedef DiagnosticDetailsBuilder = Map<String, Object?> Function();

enum DiagnosticSeverity { info, warning, error }

enum DiagnosticSource {
  codec,
  edit,
  interaction,
  frame,
  spatial,
  resource,
  diagnostics,
}

final class DiagnosticsHub {
  DiagnosticsHub({required CanvasDiagnosticPolicy policy}) : _policy = policy;

  final CanvasDiagnosticPolicy _policy;
  final List<DiagnosticRecord> _records = [];

  bool get isDisabled => _policy is CanvasDiagnosticsDisabled;
  int get recordCount => _records.length;
  List<DiagnosticRecord> get records => List.unmodifiable(_records);

  void record(DiagnosticEvent event) {
    if (isDisabled) {
      return;
    }

    _records.add(
      DiagnosticRecord._(
        code: event.code,
        severity: event.severity,
        source: event.source,
        path: event.path,
        details: _sanitizeDetails(event.details()),
        revision: event.revision,
        sessionId: event.sessionId,
        correlationId: event.correlationId,
      ),
    );
  }

  Map<String, Object?> _sanitizeDetails(Map<String, Object?> details) {
    final policy = _policy;
    if (policy is CanvasDiagnosticsVerbose) {
      return sanitizeCanvasErrorDetailsWithLimits(
        details,
        maxPreviewLength: policy.maxPreviewLength,
        maxListEntries: policy.maxListEntries,
      );
    }

    return sanitizeCanvasErrorDetails(details);
  }
}

DiagnosticsHub? diagnosticsHubForPolicy(CanvasDiagnosticPolicy policy) {
  if (policy is CanvasDiagnosticsDisabled) {
    return null;
  }

  return DiagnosticsHub(policy: policy);
}

void recordInteractionReliabilityDiagnostic(
  DiagnosticsHub? hub, {
  required InteractionDiagnosticCode code,
  DiagnosticDetailsBuilder details = _emptyDetails,
}) {
  hub?.record(
    DiagnosticEvent(
      code: DiagnosticCode.interaction(code),
      severity: DiagnosticSeverity.warning,
      source: DiagnosticSource.interaction,
      details: details,
    ),
  );
}

final class DiagnosticEvent {
  const DiagnosticEvent({
    required this.code,
    required this.severity,
    required this.source,
    this.path,
    this.details = _emptyDetails,
    this.revision,
    this.sessionId,
    this.correlationId,
  });

  final DiagnosticCode code;
  final DiagnosticSeverity severity;
  final DiagnosticSource source;
  final String? path;
  final DiagnosticDetailsBuilder details;
  final int? revision;
  final String? sessionId;
  final String? correlationId;
}

final class DiagnosticRecord {
  DiagnosticRecord._({
    required this.code,
    required this.severity,
    required this.source,
    required this.details,
    this.path,
    this.revision,
    this.sessionId,
    this.correlationId,
  }) {
    DiagnosticRecordAllocationProbe.instance.recordAllocation();
  }

  static DiagnosticRecordAllocationProbe get allocations {
    return DiagnosticRecordAllocationProbe.instance;
  }

  final DiagnosticCode code;
  final DiagnosticSeverity severity;
  final DiagnosticSource source;
  final String? path;
  final Map<String, Object?> details;
  final int? revision;
  final String? sessionId;
  final String? correlationId;
}

final class DiagnosticRecordAllocationProbe {
  DiagnosticRecordAllocationProbe._();

  static final instance = DiagnosticRecordAllocationProbe._();

  int _count = 0;

  int get count => _count;

  void reset() {
    _count = 0;
  }

  void recordAllocation() {
    _count += 1;
  }
}

Map<String, Object?> _emptyDetails() => const {};
