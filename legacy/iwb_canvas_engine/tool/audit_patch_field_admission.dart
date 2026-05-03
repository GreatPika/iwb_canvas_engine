import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import 'src/tool_command_result.dart';

Future<ToolCommandResult> runAuditPatchFieldAdmissionTool(
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

  final violations = <_PatchFieldAdmissionViolation>[];
  var scannedFunctions = 0;

  for (final file in files) {
    final parsed = parseString(
      path: file.absolute.path,
      content: file.readAsStringSync(),
      throwIfDiagnostics: false,
    );
    final typedefFields = _collectTypedefFields(parsed.unit);
    for (final declaration in parsed.unit.declarations) {
      if (declaration is! FunctionDeclaration) {
        continue;
      }
      final functionName = declaration.name.lexeme;
      if (!_isValidatePatchSchemaFunction(functionName)) {
        continue;
      }
      scannedFunctions++;

      final aliasName = _extractSingleNamedTypeParameter(declaration);
      if (aliasName == null) {
        continue;
      }
      final fieldTypes = typedefFields[aliasName];
      if (fieldTypes == null || fieldTypes.isEmpty) {
        continue;
      }

      final fieldsParameterName = _extractSingleParameterName(declaration);
      final recordLiteral = _extractReturnedRecordLiteral(declaration);
      if (fieldsParameterName == null || recordLiteral == null) {
        continue;
      }

      for (final expression
          in recordLiteral.fields.whereType<NamedExpression>()) {
        final outputFieldName = expression.name.label.name;
        final inputFieldType = fieldTypes[outputFieldName];
        if (inputFieldType == null ||
            !_isNonNullablePatchField(inputFieldType)) {
          continue;
        }
        if (_isDirectFieldPassThrough(
          expression.expression,
          targetName: fieldsParameterName,
          fieldName: outputFieldName,
        )) {
          violations.add(
            _PatchFieldAdmissionViolation(
              filePath: _repoRelativePath(workingRoot, file),
              line: parsed.lineInfo
                  .getLocation(expression.expression.offset)
                  .lineNumber,
              functionName: functionName,
              fieldName: outputFieldName,
              fieldType: inputFieldType,
            ),
          );
        }
      }
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
          'PatchField admission audit passed: scanned ${files.length} files '
          'and $scannedFunctions validate*PatchSchemaFields functions with no '
          'non-nullable passthrough violations.\n',
    );
  }

  final buffer = StringBuffer()
    ..writeln(
      'PatchField admission audit found ${violations.length} non-nullable '
      'passthrough violation(s) across ${files.length} files and '
      '$scannedFunctions validate*PatchSchemaFields functions:',
    );
  for (final violation in violations) {
    buffer.writeln(
      '- ${violation.filePath}:${violation.line} '
      '${violation.functionName}.${violation.fieldName} '
      '(${violation.fieldType})',
    );
  }
  return ToolCommandResult(exitCode: 1, stdout: buffer.toString());
}

Future<void> main(List<String> args) async {
  final result = await runAuditPatchFieldAdmissionTool(args);
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

Map<String, Map<String, String>> _collectTypedefFields(CompilationUnit unit) {
  final typedefFields = <String, Map<String, String>>{};
  for (final declaration in unit.declarations.whereType<GenericTypeAlias>()) {
    final type = declaration.type;
    if (type is! RecordTypeAnnotation) {
      continue;
    }
    final namedFields = type.namedFields;
    if (namedFields == null) {
      continue;
    }
    typedefFields[declaration.name.lexeme] = <String, String>{
      for (final field in namedFields.fields)
        field.name.lexeme: field.type.toSource(),
    };
  }
  return typedefFields;
}

bool _isValidatePatchSchemaFunction(String functionName) {
  return functionName.startsWith('validate') &&
      functionName.endsWith('SchemaFields') &&
      functionName.contains('Patch');
}

String? _extractSingleNamedTypeParameter(FunctionDeclaration declaration) {
  final parameters = declaration.functionExpression.parameters?.parameters;
  if (parameters == null || parameters.length != 1) {
    return null;
  }
  final parameter = parameters.single;
  final type = switch (parameter) {
    SimpleFormalParameter(:final type) => type,
    DefaultFormalParameter(:final parameter) => switch (parameter) {
      SimpleFormalParameter(:final type) => type,
      _ => null,
    },
    _ => null,
  };
  if (type is! NamedType) {
    return null;
  }
  return type.name.lexeme;
}

String? _extractSingleParameterName(FunctionDeclaration declaration) {
  final parameters = declaration.functionExpression.parameters?.parameters;
  if (parameters == null || parameters.length != 1) {
    return null;
  }
  final parameter = parameters.single;
  return switch (parameter) {
    SimpleFormalParameter(:final name?) => name.lexeme,
    DefaultFormalParameter(:final parameter) => switch (parameter) {
      SimpleFormalParameter(:final name?) => name.lexeme,
      _ => null,
    },
    _ => null,
  };
}

RecordLiteral? _extractReturnedRecordLiteral(FunctionDeclaration declaration) {
  final body = declaration.functionExpression.body;
  return switch (body) {
    ExpressionFunctionBody(:final expression)
        when expression is RecordLiteral =>
      expression,
    BlockFunctionBody() => switch (body.block.statements) {
      [ReturnStatement(:final expression?)] when expression is RecordLiteral =>
        expression,
      _ => null,
    },
    _ => null,
  };
}

bool _isNonNullablePatchField(String typeSource) {
  final normalized = typeSource.replaceAll(RegExp(r'\s+'), '');
  final match = RegExp(r'^PatchField<(.+)>$').firstMatch(normalized);
  if (match == null) {
    return false;
  }
  final innerType = match.group(1);
  if (innerType == null) {
    return false;
  }
  return !innerType.endsWith('?');
}

bool _isDirectFieldPassThrough(
  Expression expression, {
  required String targetName,
  required String fieldName,
}) {
  if (expression is PrefixedIdentifier) {
    return expression.prefix.name == targetName &&
        expression.identifier.name == fieldName;
  }
  if (expression is PropertyAccess && expression.target is SimpleIdentifier) {
    final target = expression.target as SimpleIdentifier;
    return target.name == targetName &&
        expression.propertyName.name == fieldName;
  }
  return false;
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

final class _PatchFieldAdmissionViolation {
  const _PatchFieldAdmissionViolation({
    required this.filePath,
    required this.line,
    required this.functionName,
    required this.fieldName,
    required this.fieldType,
  });

  final String filePath;
  final int line;
  final String functionName;
  final String fieldName;
  final String fieldType;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'filePath': filePath,
      'line': line,
      'functionName': functionName,
      'fieldName': fieldName,
      'fieldType': fieldType,
    };
  }
}
