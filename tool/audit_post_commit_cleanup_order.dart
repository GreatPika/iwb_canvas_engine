import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'src/function_audit_ast.dart';
import 'src/tool_command_result.dart';

/// This command owns the full audit from parsing through the final report.
/// Splitting its mutually recursive proof checks would hide their shared state.
// ignore: cyclomatic-complexity, halstead-volume, maximum-nesting-level, source-lines-of-code, maintainability-index, reason: One recursive audit boundary owns the shared call graph.
Future<ToolCommandResult> runAuditPostCommitCleanupOrderTool(
  List<String> args, {
  Directory? root,
}) async {
  final workingRoot = root ?? Directory.current;
  final jsonOutput = args.contains('--json');
  final targetArgs = args.where((arg) => !arg.startsWith('--')).toList();
  if (targetArgs.isEmpty) {
    return const ToolCommandResult(
      exitCode: 1,
      stderr:
          'Usage: dart run tool/audit_post_commit_cleanup_order.dart '
          '<path-or-dir> [more-paths] [--json]\n',
    );
  }
  final targets = targetArgs;

  final files = collectFunctionAuditDartFiles(workingRoot, targets);
  if (files.isEmpty) {
    return const ToolCommandResult(
      exitCode: 1,
      stderr: 'FAIL: no Dart files matched the provided targets.\n',
    );
  }

  final violations = <_PostCommitCleanupViolation>[];
  var scannedFunctions = 0;

  for (final file in files) {
    final parsed = parseString(
      path: file.absolute.path,
      content: file.readAsStringSync(),
      throwIfDiagnostics: false,
    );
    final analyses = collectFunctionAuditAnalyses(parsed.unit, file.path);
    scannedFunctions += analyses.length;

    final bySimpleName = <String, Set<FunctionAuditAnalysis>>{};
    for (final analysis in analyses) {
      bySimpleName
          .putIfAbsent(analysis.simpleName, () => <FunctionAuditAnalysis>{})
          .add(analysis);
    }

    final commitMemo = <FunctionAuditAnalysis, bool>{};
    final postCommitMemo = <FunctionAuditAnalysis, bool>{};

    bool hasCommitEffect(
      FunctionAuditAnalysis analysis, [
      Set<FunctionAuditAnalysis>? stack,
    ]) {
      final cached = commitMemo[analysis];
      if (cached != null) {
        return cached;
      }
      final active = stack ?? <FunctionAuditAnalysis>{};
      if (!active.add(analysis)) {
        return false;
      }
      final result =
          analysis.directCalls.any((call) => _isDirectCommitCall(call.name)) ||
          analysis.directCalls.any((call) {
            final callees = bySimpleName[call.name];
            if (callees == null) {
              return false;
            }
            return callees.any((callee) => hasCommitEffect(callee, active));
          });
      active.remove(analysis);
      commitMemo[analysis] = result;
      return result;
    }

    // Recursion, abort boundaries, and call order form one reachability rule.
    // ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, reason: The recursive reachability rule needs order and abort state together.
    bool hasPostCommitSideEffect(
      FunctionAuditAnalysis analysis, [
      Set<FunctionAuditAnalysis>? stack,
    ]) {
      final cached = postCommitMemo[analysis];
      if (cached != null) {
        return cached;
      }
      final active = stack ?? <FunctionAuditAnalysis>{};
      if (!active.add(analysis)) {
        return false;
      }

      final calls = analysis.directCalls.toList(growable: false)
        ..sort((left, right) => left.offset.compareTo(right.offset));

      final commitCarrierOffsets = calls
          .where((call) {
            if (_isDirectCommitCall(call.name)) {
              return true;
            }
            final callees = bySimpleName[call.name];
            if (callees == null) {
              return false;
            }
            return callees.any((callee) => hasCommitEffect(callee, active));
          })
          .map((call) => call.offset)
          .toList(growable: false);

      var result = calls.any((call) {
        final callees = bySimpleName[call.name];
        if (callees != null &&
            callees.any((callee) => hasPostCommitSideEffect(callee, active))) {
          return true;
        }
        if (!_isDirectPostCommitSideEffectCall(call.name)) {
          return false;
        }
        return commitCarrierOffsets.any(
          (commitOffset) =>
              commitOffset < call.offset &&
              !analysis.abortOffsets.any(
                (abortOffset) =>
                    abortOffset > commitOffset && abortOffset < call.offset,
              ),
        );
      });

      if (!result) {
        result = calls.any((call) {
          final callees = bySimpleName[call.name];
          if (callees == null) {
            return false;
          }
          return callees.any(
            (callee) => hasPostCommitSideEffect(callee, active),
          );
        });
      }

      active.remove(analysis);
      postCommitMemo[analysis] = result;
      return result;
    }

    for (final analysis in analyses) {
      final riskyCalls = analysis.directCalls
          .where((call) {
            final callees = bySimpleName[call.name];
            if (callees != null &&
                callees.any((callee) => hasPostCommitSideEffect(callee))) {
              return true;
            }
            if (!_isDirectPostCommitSideEffectCall(call.name)) {
              return false;
            }

            return analysis.directCalls.any((earlierCall) {
              if (earlierCall.offset >= call.offset) {
                return false;
              }
              final earlierCallees = bySimpleName[earlierCall.name];
              final isCommitCarrier =
                  _isDirectCommitCall(earlierCall.name) ||
                  (earlierCallees != null &&
                      earlierCallees.any((callee) => hasCommitEffect(callee)));
              if (!isCommitCarrier) {
                return false;
              }
              return !analysis.abortOffsets.any(
                (abortOffset) =>
                    abortOffset > earlierCall.offset &&
                    abortOffset < call.offset,
              );
            });
          })
          .toList(growable: false);
      if (riskyCalls.isEmpty) {
        continue;
      }

      final cleanupCalls = analysis.directCalls
          .where((call) => _isDirectCleanupCall(call.name))
          .toList(growable: false);
      if (cleanupCalls.isEmpty) {
        continue;
      }

      final unsafeRiskCalls = riskyCalls
          .where((riskyCall) {
            final cleanupAfterRisk = cleanupCalls
                .where((cleanupCall) {
                  if (cleanupCall.offset <= riskyCall.offset) {
                    return false;
                  }
                  return !analysis.abortOffsets.any(
                    (abortOffset) =>
                        abortOffset > riskyCall.offset &&
                        abortOffset < cleanupCall.offset,
                  );
                })
                .toList(growable: false);
            if (cleanupAfterRisk.isEmpty) {
              return false;
            }
            if (cleanupAfterRisk.any((cleanupCall) => cleanupCall.inFinally)) {
              return false;
            }
            return true;
          })
          .toList(growable: false);
      if (unsafeRiskCalls.isEmpty) {
        continue;
      }

      final cleanupAfterRisk =
          cleanupCalls
              .where((cleanupCall) {
                return unsafeRiskCalls.any(
                  (riskyCall) =>
                      cleanupCall.offset > riskyCall.offset &&
                      !analysis.abortOffsets.any(
                        (abortOffset) =>
                            abortOffset > riskyCall.offset &&
                            abortOffset < cleanupCall.offset,
                      ),
                );
              })
              .map((call) => call.name)
              .toSet()
              .toList()
            ..sort();

      final sortedRiskCalls =
          unsafeRiskCalls.map((call) => call.name).toSet().toList()..sort();

      violations.add(
        _PostCommitCleanupViolation(
          filePath: functionAuditRepoRelativePath(workingRoot, file),
          line: parsed.lineInfo.getLocation(analysis.offset).lineNumber,
          ownerDisplayName: analysis.displayName,
          riskyCalls: sortedRiskCalls,
          cleanupCalls: cleanupAfterRisk,
        ),
      );
    }
  }

  if (jsonOutput) {
    final payload = <String, Object?>{
      'summary': <String, Object?>{
        'files': files.length,
        'functions': scannedFunctions,
        'violations': violations.length,
      },
      'violations': violations
          .map((violation) => violation.toJson())
          .toList(growable: false),
    };
    return ToolCommandResult(
      exitCode: violations.isEmpty ? 0 : 1,
      stdout: '${const JsonEncoder.withIndent('  ').convert(payload)}\n',
    );
  }

  if (violations.isEmpty) {
    return ToolCommandResult(
      exitCode: 0,
      stdout:
          'Post-commit cleanup order audit passed: scanned ${files.length} '
          'files and $scannedFunctions function(s) with no cleanup ordered '
          'after fallible post-commit side effects.\n',
    );
  }

  final buffer = StringBuffer()
    ..writeln(
      'Post-commit cleanup order audit found ${violations.length} '
      'violation(s) across ${files.length} files and $scannedFunctions '
      'function(s):',
    );
  for (final violation in violations) {
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

bool _isDirectCommitCall(String name) {
  return name.startsWith('commit') || name.startsWith('_commit');
}

bool _isDirectPostCommitSideEffectCall(String name) {
  return name.startsWith('emit') ||
      name.startsWith('_emit') ||
      name.startsWith('notify') ||
      name.startsWith('_notify') ||
      name.startsWith('dispatch') ||
      name.startsWith('_dispatch');
}

bool _isDirectCleanupCall(String name) {
  return name.startsWith('clear') ||
      name.startsWith('_clear') ||
      name.startsWith('reset') ||
      name.startsWith('_reset');
}

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

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'filePath': filePath,
      'line': line,
      'ownerDisplayName': ownerDisplayName,
      'riskyCalls': riskyCalls,
      'cleanupCalls': cleanupCalls,
    };
  }
}
