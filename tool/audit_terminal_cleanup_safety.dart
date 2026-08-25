import 'dart:convert';
import 'dart:io';

import 'src/function_audit_ast.dart';
import 'src/tool_command_result.dart';

Future<ToolCommandResult> runAuditTerminalCleanupSafetyTool(
  List<String> args, {
  Directory? root,
}) async {
  final targetArgs = args.where((arg) => !arg.startsWith('--')).toList();
  if (targetArgs.isEmpty) {
    return _usageResult();
  }

  final workingRoot = root ?? Directory.current;
  final files = collectFunctionAuditDartFiles(workingRoot, targetArgs);
  if (files.isEmpty) {
    return _noFilesResult();
  }

  final sources = loadFunctionAuditSources(workingRoot, files);
  final report = _TerminalCleanupAuditReport.evaluate(sources);
  return _renderAuditResult(report, jsonOutput: args.contains('--json'));
}

ToolCommandResult _usageResult() => const ToolCommandResult(
  exitCode: 1,
  stderr:
      'Usage: dart run tool/audit_terminal_cleanup_safety.dart '
      '<path-or-dir> [more-paths] [--json]\n',
);

ToolCommandResult _noFilesResult() => const ToolCommandResult(
  exitCode: 1,
  stderr: 'FAIL: no Dart files matched the provided targets.\n',
);

ToolCommandResult _renderAuditResult(
  _TerminalCleanupAuditReport report, {
  required bool jsonOutput,
}) => jsonOutput ? _jsonResult(report) : _textResult(report);

ToolCommandResult _jsonResult(_TerminalCleanupAuditReport report) {
  final payload = <String, Object?>{
    'summary': <String, Object?>{
      'files': report.fileCount,
      'functions': report.scannedFunctionCount,
      'violations': report.violations.length,
    },
    'violations': [
      for (final violation in report.violations) violation.toJson(),
    ],
  };
  return ToolCommandResult(
    exitCode: report.exitCode,
    stdout: '${const JsonEncoder.withIndent('  ').convert(payload)}\n',
  );
}

ToolCommandResult _textResult(_TerminalCleanupAuditReport report) {
  if (report.violations.isEmpty) {
    return ToolCommandResult(
      exitCode: 0,
      stdout:
          'Terminal cleanup safety audit passed: scanned ${report.fileCount} '
          'files and ${report.scannedFunctionCount} function(s) with no '
          'exception-unsafe cleanup patterns.\n',
    );
  }

  final buffer = StringBuffer()
    ..writeln(
      'Terminal cleanup safety audit found ${report.violations.length} '
      'violation(s) across ${report.fileCount} files and '
      '${report.scannedFunctionCount} function(s):',
    );
  for (final violation in report.violations) {
    buffer.writeln(
      '- ${violation.filePath}:${violation.line} ${violation.ownerDisplayName}',
    );
    buffer.writeln('  hazardous: ${violation.hazardousCalls.join(', ')}');
    buffer.writeln('  cleanup-after: ${violation.cleanupCalls.join(', ')}');
  }
  return ToolCommandResult(exitCode: 1, stdout: buffer.toString());
}

Future<void> main(List<String> args) async {
  final result = await runAuditTerminalCleanupSafetyTool(args);
  writeToolCommandResult(result);
  exitCode = result.exitCode;
}

final class _TerminalCleanupAuditReport {
  const _TerminalCleanupAuditReport({
    required this.fileCount,
    required this.scannedFunctionCount,
    required this.violations,
  });

  factory _TerminalCleanupAuditReport.evaluate(
    List<FunctionAuditSource> sources,
  ) => _TerminalCleanupAuditReport(
    fileCount: sources.length,
    scannedFunctionCount: sources.fold(
      0,
      (count, source) => count + source.analyses.length,
    ),
    violations: [
      for (final source in sources)
        ..._TerminalCleanupSafetyEvaluator(source).evaluate(),
    ],
  );

  final int fileCount;
  final int scannedFunctionCount;
  final List<_TerminalCleanupViolation> violations;

  int get exitCode => violations.isEmpty ? 0 : 1;
}

final class _TerminalCleanupSafetyEvaluator {
  _TerminalCleanupSafetyEvaluator(this.source);

  final FunctionAuditSource source;

  List<_TerminalCleanupViolation> evaluate() => [
    for (final analysis in source.analyses) ?_evaluateAnalysis(analysis),
  ];

  _TerminalCleanupViolation? _evaluateAnalysis(FunctionAuditAnalysis analysis) {
    final hazardousCalls = _callsMatching(analysis, _isDirectHazardousCall);
    if (hazardousCalls.isEmpty) {
      return null;
    }
    final cleanupCalls = _callsMatching(analysis, _isDirectCleanupCall);
    if (cleanupCalls.isEmpty || cleanupCalls.any((call) => call.inFinally)) {
      return null;
    }
    final hazardOffset = _firstOffset(hazardousCalls);
    final cleanupAfterHazard = _callsAfter(
      analysis,
      cleanupCalls,
      hazardOffset,
    );
    if (cleanupAfterHazard.isEmpty ||
        !_looksLikeTerminalCleanupCandidate(analysis.simpleName)) {
      return null;
    }
    return _TerminalCleanupViolation(
      filePath: source.repoRelativePath,
      line: source.lineForOffset(analysis.offset),
      ownerDisplayName: analysis.displayName,
      hazardousCalls: _sortedNames(hazardousCalls),
      cleanupCalls: _sortedNames(cleanupAfterHazard),
    );
  }

  List<FunctionAuditCallOccurrence> _callsMatching(
    FunctionAuditAnalysis analysis,
    bool Function(String name) matches,
  ) => [
    for (final call in analysis.directCalls)
      if (_matchesCallOrCallee(call, matches)) call,
  ];

  bool _matchesCallOrCallee(
    FunctionAuditCallOccurrence call,
    bool Function(String name) matches,
  ) =>
      matches(call.name) ||
      (source.callGraph
              .calleesFor(call)
              ?.any(
                (callee) => source.callGraph.reachesDirectCall(
                  callee,
                  (nestedCall) => matches(nestedCall.name),
                ),
              ) ??
          false);

  List<FunctionAuditCallOccurrence> _callsAfter(
    FunctionAuditAnalysis analysis,
    List<FunctionAuditCallOccurrence> calls,
    int offset,
  ) => [
    for (final call in calls)
      if (call.offset > offset &&
          !_hasAbortBetween(analysis, offset, call.offset))
        call,
  ];

  bool _hasAbortBetween(
    FunctionAuditAnalysis analysis,
    int firstOffset,
    int secondOffset,
  ) => analysis.abortOffsets.any(
    (abortOffset) => abortOffset > firstOffset && abortOffset < secondOffset,
  );
}

int _firstOffset(List<FunctionAuditCallOccurrence> calls) => calls
    .map((call) => call.offset)
    .reduce((left, right) => left < right ? left : right);

List<String> _sortedNames(List<FunctionAuditCallOccurrence> calls) =>
    (calls.map((call) => call.name).toSet().toList()..sort());

bool _isDirectHazardousCall(String name) =>
    name.startsWith('commit') ||
    name.startsWith('_commit') ||
    name.startsWith('emit') ||
    name.startsWith('_emit');

bool _isDirectCleanupCall(String name) =>
    name.startsWith('clear') ||
    name.startsWith('_clear') ||
    name.startsWith('reset') ||
    name.startsWith('_reset');

bool _looksLikeTerminalCleanupCandidate(String name) =>
    name == 'handleUp' ||
    name == '_handleUp' ||
    name == 'commitOnUp' ||
    name.startsWith('_commit');

final class _TerminalCleanupViolation {
  const _TerminalCleanupViolation({
    required this.filePath,
    required this.line,
    required this.ownerDisplayName,
    required this.hazardousCalls,
    required this.cleanupCalls,
  });

  final String filePath;
  final int line;
  final String ownerDisplayName;
  final List<String> hazardousCalls;
  final List<String> cleanupCalls;

  Map<String, Object?> toJson() => <String, Object?>{
    'filePath': filePath,
    'line': line,
    'ownerDisplayName': ownerDisplayName,
    'hazardousCalls': hazardousCalls,
    'cleanupCalls': cleanupCalls,
  };
}
