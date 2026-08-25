import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'src/function_audit_ast.dart';
import 'src/tool_command_result.dart';

// This command owns the whole terminal-path classification and report, whose
// predicates share the same parsed-call graph and cannot be separated safely.
// ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index, reason: One command owns its shared parsed-call graph and report.
Future<ToolCommandResult> runAuditTerminalCleanupSafetyTool(
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
          'Usage: dart run tool/audit_terminal_cleanup_safety.dart '
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

  final violations = <_TerminalCleanupViolation>[];
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

    final hazardMemo = <FunctionAuditAnalysis, bool>{};
    final cleanupMemo = <FunctionAuditAnalysis, bool>{};

    bool isHazardous(
      FunctionAuditAnalysis analysis, [
      Set<FunctionAuditAnalysis>? stack,
    ]) {
      final cached = hazardMemo[analysis];
      if (cached != null) {
        return cached;
      }
      final active = stack ?? <FunctionAuditAnalysis>{};
      if (!active.add(analysis)) {
        return false;
      }
      final hazardous =
          analysis.directCalls.any(
            (call) => _isDirectHazardousCall(call.name),
          ) ||
          analysis.directCalls.any((call) {
            final callees = bySimpleName[call.name];
            if (callees == null) {
              return false;
            }
            return callees.any((callee) => isHazardous(callee, active));
          });
      active.remove(analysis);
      hazardMemo[analysis] = hazardous;
      return hazardous;
    }

    bool isCleanup(
      FunctionAuditAnalysis analysis, [
      Set<FunctionAuditAnalysis>? stack,
    ]) {
      final cached = cleanupMemo[analysis];
      if (cached != null) {
        return cached;
      }
      final active = stack ?? <FunctionAuditAnalysis>{};
      if (!active.add(analysis)) {
        return false;
      }
      final cleanup =
          analysis.directCalls.any((call) => _isDirectCleanupCall(call.name)) ||
          analysis.directCalls.any((call) {
            final callees = bySimpleName[call.name];
            if (callees == null) {
              return false;
            }
            return callees.any((callee) => isCleanup(callee, active));
          });
      active.remove(analysis);
      cleanupMemo[analysis] = cleanup;
      return cleanup;
    }

    for (final analysis in analyses) {
      final hazardousCalls = analysis.directCalls
          .where((call) {
            if (_isDirectHazardousCall(call.name)) {
              return true;
            }
            final callees = bySimpleName[call.name];
            if (callees == null) {
              return false;
            }
            return callees.any(isHazardous);
          })
          .toList(growable: false);
      if (hazardousCalls.isEmpty) {
        continue;
      }

      final cleanupCalls = analysis.directCalls
          .where((call) {
            if (_isDirectCleanupCall(call.name)) {
              return true;
            }
            final callees = bySimpleName[call.name];
            if (callees == null) {
              return false;
            }
            return callees.any(isCleanup);
          })
          .toList(growable: false);
      if (cleanupCalls.isEmpty) {
        continue;
      }

      final hasCleanupFinally = cleanupCalls.any((call) => call.inFinally);
      if (hasCleanupFinally) {
        continue;
      }

      final hazardOffset = hazardousCalls.map((call) => call.offset).fold<int?>(
        null,
        (current, offset) {
          if (current == null || offset < current) {
            return offset;
          }
          return current;
        },
      );
      if (hazardOffset == null) {
        continue;
      }

      final cleanupAfterHazard = cleanupCalls.where((call) {
        if (call.offset <= hazardOffset) {
          return false;
        }
        return !analysis.abortOffsets.any(
          (abortOffset) =>
              abortOffset > hazardOffset && abortOffset < call.offset,
        );
      });
      if (cleanupAfterHazard.isEmpty) {
        continue;
      }

      if (!_looksLikeTerminalCleanupCandidate(analysis.simpleName)) {
        continue;
      }

      final sortedHazards =
          hazardousCalls.map((call) => call.name).toSet().toList()..sort();
      final sortedCleanup =
          cleanupAfterHazard.map((call) => call.name).toSet().toList()..sort();

      violations.add(
        _TerminalCleanupViolation(
          filePath: functionAuditRepoRelativePath(workingRoot, file),
          line: parsed.lineInfo.getLocation(analysis.offset).lineNumber,
          ownerDisplayName: analysis.displayName,
          hazardousCalls: sortedHazards,
          cleanupCalls: sortedCleanup,
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
          'Terminal cleanup safety audit passed: scanned ${files.length} files '
          'and $scannedFunctions function(s) with no exception-unsafe cleanup '
          'patterns.\n',
    );
  }

  final buffer = StringBuffer()
    ..writeln(
      'Terminal cleanup safety audit found ${violations.length} violation(s) '
      'across ${files.length} files and $scannedFunctions function(s):',
    );
  for (final violation in violations) {
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

bool _isDirectHazardousCall(String name) {
  return name.startsWith('commit') ||
      name.startsWith('_commit') ||
      name.startsWith('emit') ||
      name.startsWith('_emit');
}

bool _isDirectCleanupCall(String name) {
  return name.startsWith('clear') ||
      name.startsWith('_clear') ||
      name.startsWith('reset') ||
      name.startsWith('_reset');
}

bool _looksLikeTerminalCleanupCandidate(String name) {
  return name == 'handleUp' ||
      name == '_handleUp' ||
      name == 'commitOnUp' ||
      name.startsWith('_commit');
}

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

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'filePath': filePath,
      'line': line,
      'ownerDisplayName': ownerDisplayName,
      'hazardousCalls': hazardousCalls,
      'cleanupCalls': cleanupCalls,
    };
  }
}
