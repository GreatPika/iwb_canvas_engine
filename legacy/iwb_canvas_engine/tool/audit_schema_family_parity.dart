import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'src/tool_command_result.dart';

Future<ToolCommandResult> runAuditSchemaFamilyParityTool(
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

  final units = <File, _ParsedUnit>{};
  final typedefFields = <String, List<String>>{};
  final functionParameterAliases = <String, String>{};

  for (final file in files) {
    final parsed = parseString(
      path: file.absolute.path,
      content: file.readAsStringSync(),
      throwIfDiagnostics: false,
    );
    units[file] = _ParsedUnit(parsed.unit, parsed.lineInfo);
    typedefFields.addAll(_collectTypedefFields(parsed.unit));
    functionParameterAliases.addAll(
      _collectFunctionParameterAliases(parsed.unit),
    );
  }

  final violations = <_SchemaParityViolation>[];
  var scannedSchemaFunctions = 0;
  var scannedBackingFunctions = 0;

  for (final entry in units.entries) {
    final file = entry.key;
    final parsed = entry.value;
    for (final declaration in parsed.unit.declarations) {
      if (declaration is! FunctionDeclaration) {
        continue;
      }

      final functionName = declaration.name.lexeme;
      if (_isSchemaFamilyFunction(functionName)) {
        scannedSchemaFunctions++;
        final aliasName = _extractSingleNamedTypeParameter(declaration);
        final expectedFields = aliasName == null
            ? null
            : typedefFields[aliasName];
        final recordLiteral = _extractReturnedRecordLiteral(declaration);
        if (expectedFields == null || recordLiteral == null) {
          continue;
        }
        final returnedFields = recordLiteral.fields
            .whereType<NamedExpression>()
            .map((field) => field.name.label.name)
            .toList(growable: false);
        violations.addAll(
          _compareFieldSets(
            filePath: _repoRelativePath(workingRoot, file),
            lineInfo: parsed.lineInfo,
            functionName: functionName,
            category: 'schema-return',
            expectedFields: expectedFields,
            observedFields: returnedFields,
            anchorOffset: recordLiteral.offset,
          ),
        );
      }

      if (_isBackingFromValidatedFunction(functionName)) {
        scannedBackingFunctions++;
        final variableAliases = _collectResolvedVariableAliases(
          declaration,
          functionParameterAliases,
        );
        if (variableAliases.isEmpty) {
          continue;
        }
        final returnedCall = _extractReturnedCall(declaration);
        if (returnedCall == null) {
          continue;
        }
        final accessVisitor = _PropertyAccessVisitor(
          variableAliases.keys.toSet(),
        );
        for (final argument in returnedCall.arguments) {
          argument.accept(accessVisitor);
        }
        for (final variableAlias in variableAliases.entries) {
          final expectedFields = typedefFields[variableAlias.value];
          if (expectedFields == null || expectedFields.isEmpty) {
            continue;
          }
          final observedFields =
              accessVisitor.accessedFields[variableAlias.key]?.toList(
                growable: false,
              ) ??
              const <String>[];
          violations.addAll(
            _compareFieldSets(
              filePath: _repoRelativePath(workingRoot, file),
              lineInfo: parsed.lineInfo,
              functionName: functionName,
              category: 'backing-propagation',
              expectedFields: expectedFields,
              observedFields: observedFields,
              anchorOffset: returnedCall.offset,
              variableName: variableAlias.key,
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
        'schemaFunctions': scannedSchemaFunctions,
        'backingFunctions': scannedBackingFunctions,
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
          'Schema family parity audit passed: scanned ${files.length} files, '
          '$scannedSchemaFunctions schema-family functions, and '
          '$scannedBackingFunctions backing builders with no parity drift.\n',
    );
  }

  final buffer = StringBuffer()
    ..writeln(
      'Schema family parity audit found ${violations.length} violation(s) '
      'across ${files.length} files, $scannedSchemaFunctions schema-family '
      'functions, and $scannedBackingFunctions backing builders:',
    );
  for (final violation in violations) {
    final variableSuffix = violation.variableName == null
        ? ''
        : ' via ${violation.variableName}';
    buffer.writeln(
      '- ${violation.filePath}:${violation.line} '
      '${violation.functionName} [${violation.category}$variableSuffix] '
      '${violation.message}',
    );
  }
  return ToolCommandResult(exitCode: 1, stdout: buffer.toString());
}

Future<void> main(List<String> args) async {
  final result = await runAuditSchemaFamilyParityTool(args);
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

Map<String, List<String>> _collectTypedefFields(CompilationUnit unit) {
  final typedefFields = <String, List<String>>{};
  for (final declaration in unit.declarations.whereType<GenericTypeAlias>()) {
    final type = declaration.type;
    if (type is! RecordTypeAnnotation) {
      continue;
    }
    final namedFields = type.namedFields;
    if (namedFields == null) {
      continue;
    }
    typedefFields[declaration.name.lexeme] = namedFields.fields
        .map((field) => field.name.lexeme)
        .toList(growable: false);
  }
  return typedefFields;
}

Map<String, String> _collectFunctionParameterAliases(CompilationUnit unit) {
  final aliases = <String, String>{};
  for (final declaration
      in unit.declarations.whereType<FunctionDeclaration>()) {
    final functionName = declaration.name.lexeme;
    final aliasName = _extractSingleNamedTypeParameter(declaration);
    if (aliasName != null) {
      aliases[functionName] = aliasName;
    }
  }
  return aliases;
}

bool _isSchemaFamilyFunction(String functionName) {
  return (functionName.startsWith('validate') &&
          functionName.endsWith('SchemaFields')) ||
      functionName.endsWith('SchemaFieldsFromValidated');
}

bool _isBackingFromValidatedFunction(String functionName) {
  return functionName.endsWith('BackingFromValidated');
}

String? _extractSingleNamedTypeParameter(FunctionDeclaration declaration) {
  final parameters = declaration.functionExpression.parameters?.parameters;
  if (parameters == null || parameters.length != 1) {
    return null;
  }
  return _extractNamedTypeName(parameters.single);
}

String? _extractNamedTypeName(FormalParameter parameter) {
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

_ReturnedCall? _extractReturnedCall(FunctionDeclaration declaration) {
  final body = declaration.functionExpression.body;
  return switch (body) {
    ExpressionFunctionBody(:final expression)
        when expression is InstanceCreationExpression ||
            expression is MethodInvocation =>
      _toReturnedCall(expression),
    BlockFunctionBody() => switch (body.block.statements) {
      [ReturnStatement(:final expression?)]
          when expression is InstanceCreationExpression ||
              expression is MethodInvocation =>
        _toReturnedCall(expression),
      _ => _extractReturnedCallFromBlock(body.block),
    },
    _ => null,
  };
}

_ReturnedCall? _extractReturnedCallFromBlock(Block block) {
  for (final statement in block.statements) {
    if (statement case ReturnStatement(:final expression?)) {
      if (expression is InstanceCreationExpression ||
          expression is MethodInvocation) {
        return _toReturnedCall(expression);
      }
    }
  }
  return null;
}

_ReturnedCall? _toReturnedCall(Expression expression) {
  return switch (expression) {
    InstanceCreationExpression() => _ReturnedCall(
      offset: expression.offset,
      arguments: expression.argumentList.arguments.toList(growable: false),
    ),
    MethodInvocation()
        when expression.target == null &&
            _looksLikeConstructorName(expression.methodName.name) =>
      _ReturnedCall(
        offset: expression.offset,
        arguments: expression.argumentList.arguments.toList(growable: false),
      ),
    _ => null,
  };
}

bool _looksLikeConstructorName(String name) {
  if (name.isEmpty) {
    return false;
  }
  final first = name.codeUnitAt(0);
  return first >= 65 && first <= 90;
}

Map<String, String> _collectResolvedVariableAliases(
  FunctionDeclaration declaration,
  Map<String, String> functionParameterAliases,
) {
  final body = declaration.functionExpression.body;
  if (body is! BlockFunctionBody) {
    return const <String, String>{};
  }
  final aliases = <String, String>{};
  for (final statement
      in body.block.statements.whereType<VariableDeclarationStatement>()) {
    for (final variable in statement.variables.variables) {
      final initializer = variable.initializer;
      final callee = switch (initializer) {
        MethodInvocation() => initializer.methodName.name,
        FunctionExpressionInvocation(:final function)
            when function is SimpleIdentifier =>
          function.name,
        _ => null,
      };
      if (callee == null) {
        continue;
      }
      final aliasName = functionParameterAliases[callee];
      if (aliasName == null) {
        continue;
      }
      aliases[variable.name.lexeme] = aliasName;
    }
  }
  return aliases;
}

List<_SchemaParityViolation> _compareFieldSets({
  required String filePath,
  required LineInfo lineInfo,
  required String functionName,
  required String category,
  required List<String> expectedFields,
  required List<String> observedFields,
  required int anchorOffset,
  String? variableName,
}) {
  final violations = <_SchemaParityViolation>[];
  final expectedSet = expectedFields.toSet();
  final observedSet = observedFields.toSet();
  final missing = expectedFields.where((field) => !observedSet.contains(field));
  final extra = observedFields.where((field) => !expectedSet.contains(field));
  if (missing.isNotEmpty) {
    violations.add(
      _SchemaParityViolation(
        filePath: filePath,
        line: lineInfo.getLocation(anchorOffset).lineNumber,
        functionName: functionName,
        category: category,
        variableName: variableName,
        message: 'missing fields: ${missing.join(', ')}',
      ),
    );
  }
  if (extra.isNotEmpty) {
    violations.add(
      _SchemaParityViolation(
        filePath: filePath,
        line: lineInfo.getLocation(anchorOffset).lineNumber,
        functionName: functionName,
        category: category,
        variableName: variableName,
        message: 'unexpected fields: ${extra.join(', ')}',
      ),
    );
  }
  return violations;
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

final class _ParsedUnit {
  const _ParsedUnit(this.unit, this.lineInfo);

  final CompilationUnit unit;
  final LineInfo lineInfo;
}

final class _SchemaParityViolation {
  const _SchemaParityViolation({
    required this.filePath,
    required this.line,
    required this.functionName,
    required this.category,
    required this.message,
    this.variableName,
  });

  final String filePath;
  final int line;
  final String functionName;
  final String category;
  final String message;
  final String? variableName;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'filePath': filePath,
      'line': line,
      'functionName': functionName,
      'category': category,
      'variableName': variableName,
      'message': message,
    };
  }
}

final class _ReturnedCall {
  const _ReturnedCall({required this.offset, required this.arguments});

  final int offset;
  final List<Expression> arguments;
}

final class _PropertyAccessVisitor extends RecursiveAstVisitor<void> {
  _PropertyAccessVisitor(this.variableNames);

  final Set<String> variableNames;
  final Map<String, Set<String>> accessedFields = <String, Set<String>>{};

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final prefix = node.prefix.name;
    if (variableNames.contains(prefix)) {
      accessedFields
          .putIfAbsent(prefix, () => <String>{})
          .add(node.identifier.name);
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final target = node.target;
    if (target is SimpleIdentifier && variableNames.contains(target.name)) {
      accessedFields
          .putIfAbsent(target.name, () => <String>{})
          .add(node.propertyName.name);
    }
    super.visitPropertyAccess(node);
  }
}
