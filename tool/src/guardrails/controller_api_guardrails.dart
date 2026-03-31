import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../guardrail_support/guardrail_ast_utils.dart';
import '../guardrail_support/guardrail_context.dart';
import '../guardrail_support/guardrail_path_utils.dart';
import 'public_surface_guardrails.dart';

Future<List<GuardrailViolation>> runControllerApiGuardrails({
  required GuardrailContext context,
}) async {
  final violations = <GuardrailViolation>[];
  final dartFiles = _controllerDartFiles(context);
  if (dartFiles.isEmpty) {
    return violations;
  }

  var hasControllerEpoch = false;
  for (final file in dartFiles) {
    final fileResult = _checkControllerFile(context, file);
    hasControllerEpoch = hasControllerEpoch || fileResult.hasControllerEpoch;
    if (fileResult.violation case final violation?) {
      violations.add(violation);
      return violations;
    }
  }

  if (!hasControllerEpoch) {
    violations.add(
      GuardrailViolation(
        filePath: '/lib/src/controller',
        line: 1,
        message:
            'controller API violation: controllerEpoch symbol is required '
            'for epoch invalidation guardrails',
      ),
    );
  }
  return violations;
}

List<File> _controllerDartFiles(GuardrailContext context) {
  final controllerDir = Directory(
    '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
    'src${Platform.pathSeparator}controller',
  );
  if (!controllerDir.existsSync()) {
    return const <File>[];
  }
  final dartFiles =
      controllerDir
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList(growable: false)
        ..sort((a, b) => a.path.compareTo(b.path));
  return dartFiles;
}

ControllerFileResult _checkControllerFile(GuardrailContext context, File file) {
  final filePosixPath = toRepoRelPosixPath(
    absPosixPath: toPosixPath(file.absolute.path),
    rootAbsPosixPath: context.rootAbsPosixPath,
  );
  final parsed = parseUnitOrFail(
    context: context,
    absPath: file.absolute.path,
    filePathForDiag: filePosixPath,
    onFailure: _onParseFailure,
  );
  final collector = ControllerSymbolCollector();
  parsed.unit.accept(collector);
  return ControllerFileResult(
    hasControllerEpoch: collector.hasControllerEpoch,
    violation:
        _sceneWriterSelectionBypassViolation(
          parsed: parsed,
          filePosixPath: filePosixPath,
        ) ??
        _replaceSceneEpochViolation(
          collector: collector,
          parsed: parsed,
          filePosixPath: filePosixPath,
        ) ??
        _mutatingSymbolViolation(
          collector: collector,
          parsed: parsed,
          filePosixPath: filePosixPath,
        ),
  );
}

GuardrailViolation? _sceneWriterSelectionBypassViolation({
  required ParsedUnitResult parsed,
  required String filePosixPath,
}) {
  if (filePosixPath != '/lib/src/controller/scene_writer_selection.dart') {
    return null;
  }

  const guardedFunctions = <String>{
    'sceneWriterWriteSelectionReplaceResult',
    'sceneWriterWriteSelectionToggle',
    'sceneWriterWriteSelectionClear',
    'sceneWriterWriteSelectionSelectAllResult',
  };
  for (final declaration in parsed.unit.declarations) {
    if (declaration case FunctionDeclaration(
      name: final name,
      functionExpression: final expression,
    )) {
      if (!guardedFunctions.contains(name.lexeme)) {
        continue;
      }
      final bodySource = expression.body.toSource();
      if (bodySource.contains('workingSelection') ||
          bodySource.contains('changeSet')) {
        return GuardrailViolation(
          filePath: filePosixPath,
          line: lineForOffset(parsed, name.offset),
          message:
              'controller API violation: selection writer entrypoints must '
              'route through canonical selection-state mutation ops instead '
              'of touching workingSelection/changeSet directly',
        );
      }
    }
  }
  return null;
}

GuardrailViolation? _replaceSceneEpochViolation({
  required ControllerSymbolCollector collector,
  required ParsedUnitResult parsed,
  required String filePosixPath,
}) {
  final replaceSceneOccurrence = collector.occurrences.firstWhere(
    (occurrence) => occurrence.name == 'replaceScene',
    orElse: () => const ControllerSymbolOccurrence(name: '', offset: -1),
  );
  if (replaceSceneOccurrence.offset == -1 || collector.hasControllerEpoch) {
    return null;
  }
  return GuardrailViolation(
    filePath: filePosixPath,
    line: lineForOffset(parsed, replaceSceneOccurrence.offset),
    message:
        'controller API violation: replaceScene-like entrypoints '
        'must preserve epoch invalidation '
        '(missing controllerEpoch usage in file)',
  );
}

GuardrailViolation? _mutatingSymbolViolation({
  required ControllerSymbolCollector collector,
  required ParsedUnitResult parsed,
  required String filePosixPath,
}) {
  for (final occurrence in collector.occurrences) {
    if (_isAllowedControllerOccurrence(occurrence.name)) {
      continue;
    }
    if (_looksMutatingSymbol(occurrence.name)) {
      return GuardrailViolation(
        filePath: filePosixPath,
        line: lineForOffset(parsed, occurrence.offset),
        message:
            'controller API violation: mutating symbol "${occurrence.name}" '
            'must be routed through write*/txn* transaction API',
      );
    }
  }
  return null;
}

Never _onParseFailure({
  required String filePathForDiag,
  required String resultType,
}) {
  throw GuardrailToolFailure(
    GuardrailViolation(
      filePath: filePathForDiag,
      line: 1,
      message: 'tool failure: unable to parse Dart unit (result: $resultType)',
    ),
  );
}

class ControllerFileResult {
  const ControllerFileResult({
    required this.hasControllerEpoch,
    required this.violation,
  });

  final bool hasControllerEpoch;
  final GuardrailViolation? violation;
}

class ControllerSymbolOccurrence {
  const ControllerSymbolOccurrence({required this.name, required this.offset});

  final String name;
  final int offset;
}

class ControllerSymbolCollector extends RecursiveAstVisitor<void> {
  final List<ControllerSymbolOccurrence> occurrences =
      <ControllerSymbolOccurrence>[];
  bool hasControllerEpoch = false;

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (node.name.lexeme == 'controllerEpoch') {
      hasControllerEpoch = true;
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    occurrences.add(
      ControllerSymbolOccurrence(
        name: node.name.lexeme,
        offset: node.name.offset,
      ),
    );
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    occurrences.add(
      ControllerSymbolOccurrence(
        name: node.name.lexeme,
        offset: node.name.offset,
      ),
    );
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null && !node.isCascaded) {
      occurrences.add(
        ControllerSymbolOccurrence(
          name: node.methodName.name,
          offset: node.methodName.offset,
        ),
      );
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final function = node.function;
    if (function is SimpleIdentifier) {
      occurrences.add(
        ControllerSymbolOccurrence(
          name: function.name,
          offset: function.offset,
        ),
      );
    }
    super.visitFunctionExpressionInvocation(node);
  }
}

bool _looksMutatingSymbol(String symbol) {
  const prefixes = <String>[
    'add',
    'remove',
    'delete',
    'clear',
    'replace',
    'update',
    'set',
    'move',
    'insert',
    'mutate',
    'commit',
    'apply',
  ];
  return prefixes.any(symbol.startsWith);
}

bool _isAllowedControllerOccurrence(String symbol) {
  if (const <String>{
    'if',
    'for',
    'while',
    'switch',
    'assert',
    'return',
    'super',
    'this',
  }.contains(symbol)) {
    return true;
  }
  return const <String>['write', 'txn'].any(symbol.startsWith);
}
