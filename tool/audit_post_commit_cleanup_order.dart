import 'dart:convert';
import 'dart:io';

import 'src/function_audit_ast.dart';
import 'src/tool_command_result.dart';

Future<ToolCommandResult> runAuditPostCommitCleanupOrderTool(
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
  final report = _PostCommitCleanupAuditReport.evaluate(sources);
  return _renderAuditResult(report, jsonOutput: args.contains('--json'));
}

ToolCommandResult _usageResult() => const ToolCommandResult(
  exitCode: 1,
  stderr:
      'Usage: dart run tool/audit_post_commit_cleanup_order.dart '
      '<path-or-dir> [more-paths] [--json]\n',
);

ToolCommandResult _noFilesResult() => const ToolCommandResult(
  exitCode: 1,
  stderr: 'FAIL: no Dart files matched the provided targets.\n',
);

ToolCommandResult _renderAuditResult(
  _PostCommitCleanupAuditReport report, {
  required bool jsonOutput,
}) => jsonOutput ? _jsonResult(report) : _textResult(report);

ToolCommandResult _jsonResult(_PostCommitCleanupAuditReport report) {
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

ToolCommandResult _textResult(_PostCommitCleanupAuditReport report) {
  if (report.violations.isEmpty) {
    return ToolCommandResult(
      exitCode: 0,
      stdout:
          'Post-commit cleanup order audit passed: scanned ${report.fileCount} '
          'files and ${report.scannedFunctionCount} function(s) with no cleanup '
          'ordered after fallible post-commit side effects.\n',
    );
  }

  final buffer = StringBuffer()
    ..writeln(
      'Post-commit cleanup order audit found ${report.violations.length} '
      'violation(s) across ${report.fileCount} files and '
      '${report.scannedFunctionCount} function(s):',
    );
  for (final violation in report.violations) {
    buffer.writeln(
      '- ${violation.filePath}:${violation.line} ${violation.ownerDisplayName}',
    );
    buffer.writeln('  risky-calls: ${violation.riskyCalls.join(', ')}');
    buffer.writeln('  cleanup-after: ${violation.cleanupCalls.join(', ')}');
  }
  return ToolCommandResult(exitCode: 1, stdout: buffer.toString());
}

Future<void> main(List<String> args) async {
  final result = await runAuditPostCommitCleanupOrderTool(args);
  writeToolCommandResult(result);
  exitCode = result.exitCode;
}

final class _PostCommitCleanupAuditReport {
  const _PostCommitCleanupAuditReport({
    required this.fileCount,
    required this.scannedFunctionCount,
    required this.violations,
  });

  factory _PostCommitCleanupAuditReport.evaluate(
    List<FunctionAuditSource> sources,
  ) => _PostCommitCleanupAuditReport(
    fileCount: sources.length,
    scannedFunctionCount: sources.fold(
      0,
      (count, source) => count + source.analyses.length,
    ),
    violations: [
      for (final source in sources)
        ..._PostCommitCleanupOrderEvaluator(source).evaluate(),
    ],
  );

  final int fileCount;
  final int scannedFunctionCount;
  final List<_PostCommitCleanupViolation> violations;

  int get exitCode => violations.isEmpty ? 0 : 1;
}

final class _PostCommitCleanupOrderEvaluator {
  _PostCommitCleanupOrderEvaluator(this.source);

  final FunctionAuditSource source;
  final Map<FunctionAuditAnalysis, bool> _postCommitMemo = {};

  List<_PostCommitCleanupViolation> evaluate() => [
    for (final analysis in source.analyses) ?_evaluateAnalysis(analysis),
  ];

  _PostCommitCleanupViolation? _evaluateAnalysis(
    FunctionAuditAnalysis analysis,
  ) {
    final riskyCalls = _riskyCalls(analysis);
    if (riskyCalls.isEmpty) {
      return null;
    }
    final cleanupCalls = _directCleanupCalls(analysis);
    final unsafeRiskCalls = _unsafeRiskCallsAfter(
      analysis,
      riskyCalls,
      cleanupCalls,
    );
    if (unsafeRiskCalls.isEmpty) {
      return null;
    }
    return _PostCommitCleanupViolation(
      filePath: source.repoRelativePath,
      line: source.lineForOffset(analysis.offset),
      ownerDisplayName: analysis.displayName,
      riskyCalls: _sortedNames(unsafeRiskCalls),
      cleanupCalls: _cleanupNamesAfterRisk(
        analysis,
        unsafeRiskCalls,
        cleanupCalls,
      ),
    );
  }

  List<FunctionAuditCallOccurrence> _riskyCalls(
    FunctionAuditAnalysis analysis,
  ) => [
    for (final call in analysis.directCalls)
      if (_isRiskyCall(analysis, call)) call,
  ];

  bool _isRiskyCall(
    FunctionAuditAnalysis analysis,
    FunctionAuditCallOccurrence call,
  ) {
    final callees = source.callGraph.calleesFor(call);
    if (callees != null && callees.any(_hasPostCommitSideEffect)) {
      return true;
    }
    return _isDirectPostCommitSideEffectCall(call.name) &&
        _hasEarlierCommitCarrier(analysis, call);
  }

  bool _hasEarlierCommitCarrier(
    FunctionAuditAnalysis analysis,
    FunctionAuditCallOccurrence call,
  ) => analysis.directCalls.any(
    (earlierCall) =>
        earlierCall.offset < call.offset &&
        _isCommitCarrier(earlierCall) &&
        !_hasAbortBetween(analysis, earlierCall.offset, call.offset),
  );

  bool _isCommitCarrier(FunctionAuditCallOccurrence call) =>
      _isDirectCommitCall(call.name) ||
      (source.callGraph.calleesFor(call)?.any(_hasCommitEffect) ?? false);

  bool _hasCommitEffect(FunctionAuditAnalysis analysis) => source.callGraph
      .reachesDirectCall(analysis, (call) => _isDirectCommitCall(call.name));

  // Recursion, call order, and abort boundaries define one reachability rule.
  // ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index, reason: Keeping its shared traversal state together preserves recursive order semantics.
  bool _hasPostCommitSideEffect(
    FunctionAuditAnalysis analysis, [
    Set<FunctionAuditAnalysis>? stack,
  ]) {
    final cached = _postCommitMemo[analysis];
    if (cached != null) {
      return cached;
    }
    final active = stack ?? <FunctionAuditAnalysis>{};
    if (!active.add(analysis)) {
      return false;
    }
    final result =
        _hasDirectPostCommitSideEffect(analysis) ||
        analysis.directCalls.any(
          (call) =>
              source.callGraph
                  .calleesFor(call)
                  ?.any((callee) => _hasPostCommitSideEffect(callee, active)) ??
              false,
        );
    active.remove(analysis);
    _postCommitMemo[analysis] = result;
    return result;
  }

  bool _hasDirectPostCommitSideEffect(FunctionAuditAnalysis analysis) {
    final calls = analysis.directCalls.toList()..sort(_compareCallOffsets);
    final commitOffsets = [
      for (final call in calls)
        if (_isCommitCarrier(call)) call.offset,
    ];
    return calls.any(
      (call) =>
          _isDirectPostCommitSideEffectCall(call.name) &&
          commitOffsets.any(
            (commitOffset) =>
                commitOffset < call.offset &&
                !_hasAbortBetween(analysis, commitOffset, call.offset),
          ),
    );
  }
}

List<FunctionAuditCallOccurrence> _directCleanupCalls(
  FunctionAuditAnalysis analysis,
) => [
  for (final call in analysis.directCalls)
    if (_isDirectCleanupCall(call.name)) call,
];

List<FunctionAuditCallOccurrence> _unsafeRiskCallsAfter(
  FunctionAuditAnalysis analysis,
  List<FunctionAuditCallOccurrence> riskyCalls,
  List<FunctionAuditCallOccurrence> cleanupCalls,
) => [
  for (final riskyCall in riskyCalls)
    if (_hasUnsafeCleanupAfterRisk(analysis, riskyCall, cleanupCalls))
      riskyCall,
];

bool _hasUnsafeCleanupAfterRisk(
  FunctionAuditAnalysis analysis,
  FunctionAuditCallOccurrence riskyCall,
  List<FunctionAuditCallOccurrence> cleanupCalls,
) {
  final cleanupAfterRisk = cleanupCalls.where(
    (cleanupCall) =>
        cleanupCall.offset > riskyCall.offset &&
        !_hasAbortBetween(analysis, riskyCall.offset, cleanupCall.offset),
  );
  return cleanupAfterRisk.isNotEmpty &&
      !cleanupAfterRisk.any((cleanupCall) => cleanupCall.inFinally);
}

List<String> _cleanupNamesAfterRisk(
  FunctionAuditAnalysis analysis,
  List<FunctionAuditCallOccurrence> riskyCalls,
  List<FunctionAuditCallOccurrence> cleanupCalls,
) => _sortedNames([
  for (final cleanupCall in cleanupCalls)
    if (riskyCalls.any(
      (riskyCall) =>
          cleanupCall.offset > riskyCall.offset &&
          !_hasAbortBetween(analysis, riskyCall.offset, cleanupCall.offset),
    ))
      cleanupCall,
]);

bool _hasAbortBetween(
  FunctionAuditAnalysis analysis,
  int firstOffset,
  int secondOffset,
) => analysis.abortOffsets.any(
  (abortOffset) => abortOffset > firstOffset && abortOffset < secondOffset,
);

int _compareCallOffsets(
  FunctionAuditCallOccurrence left,
  FunctionAuditCallOccurrence right,
) => left.offset.compareTo(right.offset);

List<String> _sortedNames(List<FunctionAuditCallOccurrence> calls) =>
    (calls.map((call) => call.name).toSet().toList()..sort());

bool _isDirectCommitCall(String name) =>
    name.startsWith('commit') || name.startsWith('_commit');

bool _isDirectPostCommitSideEffectCall(String name) =>
    name.startsWith('emit') ||
    name.startsWith('_emit') ||
    name.startsWith('notify') ||
    name.startsWith('_notify') ||
    name.startsWith('dispatch') ||
    name.startsWith('_dispatch');

bool _isDirectCleanupCall(String name) =>
    name.startsWith('clear') ||
    name.startsWith('_clear') ||
    name.startsWith('reset') ||
    name.startsWith('_reset');

final class _PostCommitCleanupViolation {
  const _PostCommitCleanupViolation({
    required this.filePath,
    required this.line,
    required this.ownerDisplayName,
    required this.riskyCalls,
    required this.cleanupCalls,
  });

  final String filePath;
  final int line;
  final String ownerDisplayName;
  final List<String> riskyCalls;
  final List<String> cleanupCalls;

  Map<String, Object?> toJson() => <String, Object?>{
    'filePath': filePath,
    'line': line,
    'ownerDisplayName': ownerDisplayName,
    'riskyCalls': riskyCalls,
    'cleanupCalls': cleanupCalls,
  };
}
