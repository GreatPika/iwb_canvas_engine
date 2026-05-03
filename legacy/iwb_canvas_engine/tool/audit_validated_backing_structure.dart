import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'src/tool_command_result.dart';

Future<ToolCommandResult> runAuditValidatedBackingStructureTool(
  List<String> args, {
  Directory? root,
}) async {
  final workingRoot = root ?? Directory.current;
  final jsonOutput = args.contains('--json');
  final targetArgs = args.where((arg) => !arg.startsWith('--')).toList();
  final targets = targetArgs.isEmpty
      ? <String>['lib/src/contract']
      : targetArgs;

  final files = _collectDartFiles(workingRoot, targets);
  if (files.isEmpty) {
    return const ToolCommandResult(
      exitCode: 1,
      stderr: 'FAIL: no Dart files matched the provided targets.\n',
    );
  }

  final validatorsByBackingType = <String, Set<_StructureValidator>>{};
  final functionsByName = <String, List<_FunctionProbe>>{};
  final builders = <_ValidatedBackingBuilder>[];

  for (final file in files) {
    final parsed = parseString(
      path: file.absolute.path,
      content: file.readAsStringSync(),
      throwIfDiagnostics: false,
    );
    for (final declaration
        in parsed.unit.declarations.whereType<FunctionDeclaration>()) {
      final functionName = declaration.name.lexeme;
      final returnType = _namedTypeText(declaration.returnType);
      final collector = _InvocationCollector();
      declaration.functionExpression.body.visitChildren(collector);
      final functionProbe = _FunctionProbe(
        filePath: _repoRelativePath(workingRoot, file),
        line: parsed.lineInfo.getLocation(declaration.name.offset).lineNumber,
        name: functionName,
        calls: collector.calls,
      );
      functionsByName
          .putIfAbsent(functionName, () => <_FunctionProbe>[])
          .add(functionProbe);

      if (_isStructureValidatorName(functionName)) {
        for (final backingType in _formalBackingTypes(declaration)) {
          validatorsByBackingType
              .putIfAbsent(backingType, () => <_StructureValidator>{})
              .add(
                _StructureValidator(
                  filePath: _repoRelativePath(workingRoot, file),
                  line: parsed.lineInfo
                      .getLocation(declaration.name.offset)
                      .lineNumber,
                  name: functionName,
                  backingType: backingType,
                ),
              );
        }
      }

      if (returnType == null ||
          !_isValidatedBackingBuilder(
            functionName: functionName,
            returnType: returnType,
          )) {
        continue;
      }

      builders.add(
        _ValidatedBackingBuilder(
          filePath: functionProbe.filePath,
          line: functionProbe.line,
          name: functionName,
          returnType: returnType,
        ),
      );
    }
  }

  final violations = <_ValidatedBackingStructureViolation>[];
  for (final builder in builders) {
    final validators = validatorsByBackingType[builder.returnType];
    if (validators == null || validators.isEmpty) {
      continue;
    }
    final matchingValidatorNames = validators
        .map((validator) => validator.name)
        .toSet();
    final validatorPath = _findValidatorPath(
      startName: builder.name,
      validatorNames: matchingValidatorNames,
      functionsByName: functionsByName,
    );
    if (validatorPath != null) {
      continue;
    }
    violations.add(
      _ValidatedBackingStructureViolation(
        builder: builder,
        validators: validators.toList(growable: false)
          ..sort((left, right) => left.name.compareTo(right.name)),
      ),
    );
  }

  if (jsonOutput) {
    final payload = <String, Object?>{
      'summary': <String, Object?>{
        'files': files.length,
        'validatedBackingBuilders': builders.length,
        'structureValidatedBackingTypes': validatorsByBackingType.length,
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
          'Validated backing structure audit passed: scanned ${files.length} '
          'files and ${builders.length} validated backing builder(s) with no '
          'missing structure-validator hops.\n',
    );
  }

  final buffer = StringBuffer()
    ..writeln(
      'Validated backing structure audit found ${violations.length} '
      'violation(s) across ${files.length} files and ${builders.length} '
      'validated backing builder(s):',
    );
  for (final violation in violations) {
    final builder = violation.builder;
    buffer.writeln(
      '- ${builder.filePath}:${builder.line} ${builder.name} returns '
      '${builder.returnType} without calling '
      '${violation.validatorNames.join(' or ')}',
    );
  }
  return ToolCommandResult(exitCode: 1, stdout: buffer.toString());
}

Future<void> main(List<String> args) async {
  final result = await runAuditValidatedBackingStructureTool(args);
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
      if (file.path.endsWith('.dart')) {
        files.add(file);
      }
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

bool _isValidatedBackingBuilder({
  required String functionName,
  required String returnType,
}) {
  return !functionName.startsWith('_') &&
      functionName.endsWith('BackingFromValidated') &&
      returnType.endsWith('Backing');
}

bool _isStructureValidatorName(String functionName) {
  return !functionName.startsWith('_') &&
      functionName.toLowerCase().contains('validate') &&
      functionName.endsWith('BackingStructure');
}

List<String>? _findValidatorPath({
  required String startName,
  required Set<String> validatorNames,
  required Map<String, List<_FunctionProbe>> functionsByName,
}) {
  return _findValidatorPathFrom(
    functionName: startName,
    validatorNames: validatorNames,
    functionsByName: functionsByName,
    visited: <String>{},
  );
}

List<String>? _findValidatorPathFrom({
  required String functionName,
  required Set<String> validatorNames,
  required Map<String, List<_FunctionProbe>> functionsByName,
  required Set<String> visited,
}) {
  if (!visited.add(functionName)) {
    return null;
  }
  final functions = functionsByName[functionName];
  if (functions == null) {
    visited.remove(functionName);
    return null;
  }
  for (final function in functions) {
    final directValidator =
        function.calls.where(validatorNames.contains).toList(growable: false)
          ..sort();
    if (directValidator.isNotEmpty) {
      visited.remove(functionName);
      return <String>[functionName, directValidator.first];
    }

    final helperCalls =
        function.calls
            .where(functionsByName.containsKey)
            .toList(growable: false)
          ..sort();
    for (final helperCall in helperCalls) {
      final helperPath = _findValidatorPathFrom(
        functionName: helperCall,
        validatorNames: validatorNames,
        functionsByName: functionsByName,
        visited: visited,
      );
      if (helperPath != null) {
        visited.remove(functionName);
        return <String>[functionName, ...helperPath];
      }
    }
  }
  visited.remove(functionName);
  return null;
}

Iterable<String> _formalBackingTypes(FunctionDeclaration declaration) sync* {
  final parameters =
      declaration.functionExpression.parameters?.parameters ??
      const <FormalParameter>[];
  for (final parameter in parameters) {
    final type = _namedTypeText(_parameterType(parameter));
    if (type != null && type.endsWith('Backing')) {
      yield type;
    }
  }
}

TypeAnnotation? _parameterType(FormalParameter parameter) {
  final normalized = parameter is DefaultFormalParameter
      ? parameter.parameter
      : parameter;
  return switch (normalized) {
    SimpleFormalParameter(:final type) => type,
    FieldFormalParameter(:final type) => type,
    FunctionTypedFormalParameter(:final returnType) => returnType,
    SuperFormalParameter(:final type) => type,
    _ => null,
  };
}

String? _namedTypeText(Object? typeNode) {
  if (typeNode == null) {
    return null;
  }
  final typeText = typeNode.toString();
  if (typeText.isEmpty || typeText == 'dynamic') {
    return null;
  }
  final genericStart = typeText.indexOf('<');
  return genericStart == -1 ? typeText : typeText.substring(0, genericStart);
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

final class _ValidatedBackingBuilder {
  const _ValidatedBackingBuilder({
    required this.filePath,
    required this.line,
    required this.name,
    required this.returnType,
  });

  final String filePath;
  final int line;
  final String name;
  final String returnType;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'filePath': filePath,
      'line': line,
      'name': name,
      'returnType': returnType,
    };
  }
}

final class _FunctionProbe {
  const _FunctionProbe({
    required this.filePath,
    required this.line,
    required this.name,
    required this.calls,
  });

  final String filePath;
  final int line;
  final String name;
  final Set<String> calls;
}

final class _StructureValidator {
  const _StructureValidator({
    required this.filePath,
    required this.line,
    required this.name,
    required this.backingType,
  });

  final String filePath;
  final int line;
  final String name;
  final String backingType;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'filePath': filePath,
      'line': line,
      'name': name,
      'backingType': backingType,
    };
  }
}

final class _ValidatedBackingStructureViolation {
  const _ValidatedBackingStructureViolation({
    required this.builder,
    required this.validators,
  });

  final _ValidatedBackingBuilder builder;
  final List<_StructureValidator> validators;

  List<String> get validatorNames =>
      validators
          .map((validator) => validator.name)
          .toSet()
          .toList(growable: false)
        ..sort();

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'builder': builder.toJson(),
      'validators': validators
          .map((validator) => validator.toJson())
          .toList(growable: false),
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
