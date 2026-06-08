import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'src/tool_command_result.dart';

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

  final files = _collectDartFiles(workingRoot, targets);
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
    final analyses = _collectFunctionAnalyses(parsed.unit, file.path);
    scannedFunctions += analyses.length;

    final bySimpleName = <String, Set<_FunctionAnalysis>>{};
    for (final analysis in analyses) {
      bySimpleName
          .putIfAbsent(analysis.simpleName, () => <_FunctionAnalysis>{})
          .add(analysis);
    }

    final hazardMemo = <_FunctionAnalysis, bool>{};
    final cleanupMemo = <_FunctionAnalysis, bool>{};

    bool isHazardous(
      _FunctionAnalysis analysis, [
      Set<_FunctionAnalysis>? stack,
    ]) {
      final cached = hazardMemo[analysis];
      if (cached != null) {
        return cached;
      }
      final active = stack ?? <_FunctionAnalysis>{};
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
      _FunctionAnalysis analysis, [
      Set<_FunctionAnalysis>? stack,
    ]) {
      final cached = cleanupMemo[analysis];
      if (cached != null) {
        return cached;
      }
      final active = stack ?? <_FunctionAnalysis>{};
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
          filePath: _repoRelativePath(workingRoot, file),
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

List<File> _collectDartFiles(Directory root, List<String> targets) {
  final files = <File>[];
  for (final target in targets) {
    final absolute = target.startsWith('/')
        ? target
        : '${root.path}${Platform.pathSeparator}$target';
    final file = File(absolute);
    if (file.existsSync()) {
      files.add(file);
      continue;
    }
    final directory = Directory(absolute);
    if (!directory.existsSync()) {
      continue;
    }
    for (final entity in directory.listSync(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File && entity.path.endsWith('.dart')) {
        files.add(entity);
      }
    }
  }
  files.sort((left, right) => left.path.compareTo(right.path));
  return files;
}

List<_FunctionAnalysis> _collectFunctionAnalyses(
  CompilationUnit unit,
  String filePath,
) {
  final visitor = _FunctionCollector(filePath: filePath);
  unit.accept(visitor);
  return visitor.analyses;
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

String _repoRelativePath(Directory root, File file) {
  final rootPath = root.path.endsWith(Platform.pathSeparator)
      ? root.path
      : '${root.path}${Platform.pathSeparator}';
  if (!file.path.startsWith(rootPath)) {
    return file.path;
  }
  return file.path.replaceFirst(rootPath, '').replaceAll(r'\', '/');
}

final class _FunctionCollector extends RecursiveAstVisitor<void> {
  _FunctionCollector({required this.filePath});

  final String filePath;
  final List<_FunctionAnalysis> analyses = <_FunctionAnalysis>[];
  final List<String> _ownerStack = <String>[];

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _ownerStack.add(_className(node));
    super.visitClassDeclaration(node);
    _ownerStack.removeLast();
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    final name = node.name?.lexeme;
    if (name != null) {
      _ownerStack.add(name);
    }
    super.visitExtensionDeclaration(node);
    if (name != null) {
      _ownerStack.removeLast();
    }
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final body = node.functionExpression.body;
    final collector = _CallCollector();
    body.visitChildren(collector);
    analyses.add(
      _FunctionAnalysis(
        filePath: filePath,
        simpleName: node.name.lexeme,
        displayName: _displayName(node.name.lexeme),
        offset: node.name.offset,
        directCalls: collector.calls,
        abortOffsets: collector.abortOffsets,
      ),
    );
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final collector = _CallCollector();
    node.body.visitChildren(collector);
    analyses.add(
      _FunctionAnalysis(
        filePath: filePath,
        simpleName: node.name.lexeme,
        displayName: _displayName(node.name.lexeme),
        offset: node.name.offset,
        directCalls: collector.calls,
        abortOffsets: collector.abortOffsets,
      ),
    );
    super.visitMethodDeclaration(node);
  }

  String _displayName(String functionName) {
    if (_ownerStack.isEmpty) {
      return functionName;
    }
    return '${_ownerStack.join('.')}.$functionName';
  }
}

String _className(ClassDeclaration declaration) {
  final namePart = declaration.namePart;
  return switch (namePart) {
    NameWithTypeParameters(:final typeName) => typeName.lexeme,
    PrimaryConstructorDeclaration() => namePart.beginToken.lexeme,
  };
}

final class _CallCollector extends RecursiveAstVisitor<void> {
  final List<_CallOccurrence> calls = <_CallOccurrence>[];
  final List<int> abortOffsets = <int>[];
  var _finallyDepth = 0;

  @override
  void visitTryStatement(TryStatement node) {
    node.body.accept(this);
    for (final catchClause in node.catchClauses) {
      catchClause.accept(this);
    }
    final finallyBlock = node.finallyBlock;
    if (finallyBlock != null) {
      _finallyDepth++;
      finallyBlock.accept(this);
      _finallyDepth--;
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    calls.add(
      _CallOccurrence(
        name: node.methodName.name,
        offset: node.methodName.offset,
        inFinally: _finallyDepth > 0,
      ),
    );
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final function = node.function;
    if (function is SimpleIdentifier) {
      calls.add(
        _CallOccurrence(
          name: function.name,
          offset: function.offset,
          inFinally: _finallyDepth > 0,
        ),
      );
    }
    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    abortOffsets.add(node.returnKeyword.offset);
    super.visitReturnStatement(node);
  }

  @override
  void visitThrowExpression(ThrowExpression node) {
    abortOffsets.add(node.throwKeyword.offset);
    super.visitThrowExpression(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Skip nested closures. Deferred callbacks are not part of the immediate
    // cleanup path this audit checks.
    return;
  }
}

final class _FunctionAnalysis {
  const _FunctionAnalysis({
    required this.filePath,
    required this.simpleName,
    required this.displayName,
    required this.offset,
    required this.directCalls,
    required this.abortOffsets,
  });

  final String filePath;
  final String simpleName;
  final String displayName;
  final int offset;
  final List<_CallOccurrence> directCalls;
  final List<int> abortOffsets;
}

final class _CallOccurrence {
  const _CallOccurrence({
    required this.name,
    required this.offset,
    required this.inFinally,
  });

  final String name;
  final int offset;
  final bool inFinally;
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
