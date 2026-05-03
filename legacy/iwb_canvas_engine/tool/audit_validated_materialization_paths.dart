import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'src/tool_command_result.dart';

Future<ToolCommandResult> runAuditValidatedMaterializationPathsTool(
  List<String> args, {
  Directory? root,
}) async {
  final workingRoot = root ?? Directory.current;
  final jsonOutput = args.contains('--json');
  final targetArgs = args.where((arg) => !arg.startsWith('--')).toList();
  final targets = targetArgs.isEmpty
      ? <String>['lib/src/contract/internal']
      : targetArgs;

  final files = _collectDartFiles(workingRoot, targets);
  if (files.isEmpty) {
    return const ToolCommandResult(
      exitCode: 1,
      stderr: 'FAIL: no Dart files matched the provided targets.\n',
    );
  }

  final violations = <_ValidatedPathViolation>[];
  var scannedFunctions = 0;

  for (final file in files) {
    final parsed = parseString(
      path: file.absolute.path,
      content: file.readAsStringSync(),
      throwIfDiagnostics: false,
    );
    for (final declaration
        in parsed.unit.declarations.whereType<FunctionDeclaration>()) {
      final functionName = declaration.name.lexeme;
      if (!_isPublicValidatedFunction(functionName)) {
        continue;
      }
      scannedFunctions++;
      final bodyVisitor = _InvocationCollector();
      declaration.functionExpression.body.visitChildren(bodyVisitor);

      final directMaterializers = bodyVisitor.calls
          .where(_isDirectMaterializerCall)
          .toList(growable: false);
      if (directMaterializers.isEmpty) {
        continue;
      }

      final hasValidatedBuilderHop = bodyVisitor.calls.any(
        (call) =>
            call.endsWith('SchemaFieldsFromValidated') ||
            call.endsWith('BackingFromValidated') ||
            call.endsWith('CommonFieldsFromValidated'),
      );
      final hasValidatorHop = bodyVisitor.calls.any(
        (call) =>
            call.startsWith('validate') || call.startsWith('sceneValidate'),
      );

      if (hasValidatedBuilderHop || hasValidatorHop) {
        continue;
      }

      violations.add(
        _ValidatedPathViolation(
          filePath: _repoRelativePath(workingRoot, file),
          line: parsed.lineInfo.getLocation(declaration.name.offset).lineNumber,
          functionName: functionName,
          materializers: directMaterializers,
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
          'Validated materialization path audit passed: scanned ${files.length} '
          'files and $scannedFunctions public validated functions with no '
          'direct raw materialization bypasses.\n',
    );
  }

  final buffer = StringBuffer()
    ..writeln(
      'Validated materialization path audit found ${violations.length} '
      'violation(s) across ${files.length} files and $scannedFunctions '
      'public validated functions:',
    );
  for (final violation in violations) {
    buffer.writeln(
      '- ${violation.filePath}:${violation.line} ${violation.functionName} '
      'directly materializes via ${violation.materializers.join(', ')} '
      'without a validated helper or validator hop',
    );
  }
  return ToolCommandResult(exitCode: 1, stdout: buffer.toString());
}

Future<void> main(List<String> args) async {
  final result = await runAuditValidatedMaterializationPathsTool(args);
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

bool _isPublicValidatedFunction(String functionName) {
  return !functionName.startsWith('_') &&
      functionName.contains('FromValidated');
}

bool _isDirectMaterializerCall(String callee) {
  return callee.startsWith('materialize') ||
      (callee.startsWith('_materialize') && callee.contains('FromValidated'));
}

String _repoRelativePath(Directory root, File file) {
  final rootPath = root.path.endsWith(Platform.pathSeparator)
      ? root.path
      : '${root.path}${Platform.pathSeparator}';
  if (!file.path.startsWith(rootPath)) {
    return file.path;
  }
  return file.path.substring(rootPath.length).replaceAll(r'\', '/');
}

final class _ValidatedPathViolation {
  const _ValidatedPathViolation({
    required this.filePath,
    required this.line,
    required this.functionName,
    required this.materializers,
  });

  final String filePath;
  final int line;
  final String functionName;
  final List<String> materializers;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'filePath': filePath,
      'line': line,
      'functionName': functionName,
      'materializers': materializers,
    };
  }
}

final class _InvocationCollector extends RecursiveAstVisitor<void> {
  final Set<String> calls = <String>{};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    calls.add(node.methodName.name);
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final function = node.function;
    if (function is SimpleIdentifier) {
      calls.add(function.name);
    }
    super.visitFunctionExpressionInvocation(node);
  }
}
