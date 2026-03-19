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
  final controllerTreeFiles = _controllerTreeDartFiles(context);
  final dartFiles = _controllerGuardrailFiles(
    context,
    controllerTreeFiles: controllerTreeFiles,
  );
  if (dartFiles.isEmpty) {
    return violations;
  }

  var hasControllerEpochInControllerTree = false;
  for (final file in dartFiles) {
    final fileResult = _checkControllerFile(context, file);
    if (_isControllerTreeFile(context, file)) {
      hasControllerEpochInControllerTree =
          hasControllerEpochInControllerTree || fileResult.hasControllerEpoch;
    }
    if (fileResult.violation case final violation?) {
      violations.add(violation);
      return violations;
    }
  }

  if (controllerTreeFiles.isNotEmpty && !hasControllerEpochInControllerTree) {
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

List<File> _controllerGuardrailFiles(
  GuardrailContext context, {
  List<File>? controllerTreeFiles,
}) {
  final candidates = <File>[
    ...(controllerTreeFiles ?? _controllerTreeDartFiles(context)),
    ..._interactiveControllerEntrypointFiles(context),
  ];
  if (candidates.isEmpty) {
    return const <File>[];
  }
  final uniqueByPath = <String, File>{};
  for (final file in candidates) {
    uniqueByPath[toPosixPath(file.absolute.path)] = file;
  }
  final result = uniqueByPath.values.toList(growable: false)
    ..sort((a, b) => a.path.compareTo(b.path));
  return result;
}

List<File> _controllerTreeDartFiles(GuardrailContext context) {
  final controllerDir = Directory(
    '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
    'src${Platform.pathSeparator}controller',
  );
  if (!controllerDir.existsSync()) {
    return const <File>[];
  }
  return controllerDir
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList(growable: false);
}

List<File> _interactiveControllerEntrypointFiles(GuardrailContext context) {
  final file = File(
    '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
    'src${Platform.pathSeparator}interactive${Platform.pathSeparator}'
    'scene_controller_interactive.dart',
  );
  if (!file.existsSync()) {
    return const <File>[];
  }
  return <File>[file];
}

bool _isControllerTreeFile(GuardrailContext context, File file) {
  final controllerRoot = toPosixPath(
    '${context.root.absolute.path}${Platform.pathSeparator}lib'
    '${Platform.pathSeparator}src${Platform.pathSeparator}controller'
    '${Platform.pathSeparator}',
  );
  return toPosixPath(file.absolute.path).startsWith(controllerRoot);
}

ControllerFileResult _checkControllerFile(GuardrailContext context, File file) {
  final filePosixPath = toRepoRelPosixPath(
    absPosixPath: toPosixPath(file.absolute.path),
    rootAbsPosixPath: context.rootAbsPosixPath,
  );
  final isInteractiveEntrypointFile =
      filePosixPath ==
          '/lib/src/interactive/scene_controller_interactive.dart' ||
      filePosixPath == 'lib/src/interactive/scene_controller_interactive.dart';
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
        (isInteractiveEntrypointFile
            ? null
            : _replaceSceneEpochViolation(
                collector: collector,
                parsed: parsed,
                filePosixPath: filePosixPath,
              )) ??
        _mutatingDeclarationViolation(
          collector: collector,
          parsed: parsed,
          filePosixPath: filePosixPath,
          isInteractiveEntrypointFile: isInteractiveEntrypointFile,
        ),
  );
}

GuardrailViolation? _replaceSceneEpochViolation({
  required ControllerSymbolCollector collector,
  required ParsedUnitResult parsed,
  required String filePosixPath,
}) {
  final replaceSceneDeclaration = collector.declarations.firstWhere(
    (declaration) => declaration.name == 'replaceScene',
    orElse: () => const ControllerDeclaration(name: '', offset: -1, node: null),
  );
  if (replaceSceneDeclaration.offset == -1 || collector.hasControllerEpoch) {
    return null;
  }
  return GuardrailViolation(
    filePath: filePosixPath,
    line: lineForOffset(parsed, replaceSceneDeclaration.offset),
    message:
        'controller API violation: replaceScene-like entrypoints '
        'must preserve epoch invalidation '
        '(missing controllerEpoch usage in file)',
  );
}

GuardrailViolation? _mutatingDeclarationViolation({
  required ControllerSymbolCollector collector,
  required ParsedUnitResult parsed,
  required String filePosixPath,
  required bool isInteractiveEntrypointFile,
}) {
  for (final declaration in collector.declarations) {
    if (_isAllowedControllerDeclaration(
      declaration,
      isInteractiveEntrypointFile: isInteractiveEntrypointFile,
    )) {
      continue;
    }
    if (_looksMutatingSymbol(declaration.name)) {
      return GuardrailViolation(
        filePath: filePosixPath,
        line: lineForOffset(parsed, declaration.offset),
        message:
            'controller API violation: mutating symbol "${declaration.name}" '
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

class ControllerSymbolCollector extends RecursiveAstVisitor<void> {
  final List<ControllerDeclaration> declarations = <ControllerDeclaration>[];
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
    if (!_isPrivateIdentifier(node.name.lexeme)) {
      declarations.add(
        ControllerDeclaration(
          name: node.name.lexeme,
          offset: node.name.offset,
          node: node,
        ),
      );
    }
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (!_isPrivateIdentifier(node.name.lexeme)) {
      declarations.add(
        ControllerDeclaration(
          name: node.name.lexeme,
          offset: node.name.offset,
          node: node,
        ),
      );
    }
    super.visitFunctionDeclaration(node);
  }
}

class ControllerDeclaration {
  const ControllerDeclaration({
    required this.name,
    required this.offset,
    required this.node,
  });

  final String name;
  final int offset;
  final AstNode? node;
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

bool _isAllowedControllerDeclaration(
  ControllerDeclaration declaration, {
  required bool isInteractiveEntrypointFile,
}) {
  final symbol = declaration.name;
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
  if (const <String>['write', 'txn'].any(symbol.startsWith)) {
    return true;
  }
  if (!isInteractiveEntrypointFile) {
    return false;
  }
  if (_interactiveDeclarationAllowList.contains(symbol)) {
    return true;
  }
  return _routesThroughCanonicalWriteSeam(declaration.node);
}

const Set<String> _interactiveDeclarationAllowList = <String>{
  'setMode',
  'setDrawTool',
  'setDrawColor',
  'penThickness',
  'highlighterThickness',
  'lineThickness',
  'eraserThickness',
  'highlighterOpacity',
  'setPointerSettings',
  'setDragStartSlop',
};

bool _routesThroughCanonicalWriteSeam(AstNode? declaration) {
  if (declaration == null) {
    return false;
  }
  final visitor = _DirectCanonicalWriteSeamVisitor();
  declaration.accept(visitor);
  return visitor.foundCanonicalWriteSeam;
}

bool _isPrivateIdentifier(String name) => name.startsWith('_');

class _DirectCanonicalWriteSeamVisitor extends RecursiveAstVisitor<void> {
  bool foundCanonicalWriteSeam = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isDirectCanonicalWriteInvocation(node)) {
      foundCanonicalWriteSeam = true;
      return;
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    // Local helper invocations must not count as canonical routing seams.
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    // Nested helpers may delegate later, but slice 13.4/2 requires direct
    // delegation from the public declaration itself.
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Closures are not owner-level routing seams for the enclosing declaration.
  }
}

bool _isDirectCanonicalWriteInvocation(MethodInvocation node) {
  final targetPath = _memberAccessPath(node.realTarget);
  final methodName = node.methodName.name;
  if (targetPath == null) {
    return false;
  }
  if (targetPath.length == 1 && targetPath.first == '_core') {
    return methodName == 'write' || methodName == 'writeReplaceScene';
  }
  if (targetPath.length == 2 &&
      targetPath.first == '_core' &&
      targetPath[1] == 'commands') {
    return methodName.startsWith('write');
  }
  if (targetPath.length == 2 &&
      targetPath.first == '_core' &&
      targetPath[1] == 'draw') {
    return methodName.startsWith('write');
  }
  return false;
}

List<String>? _memberAccessPath(Expression? expression) {
  if (expression == null) {
    return null;
  }
  if (expression is ParenthesizedExpression) {
    return _memberAccessPath(expression.expression);
  }
  if (expression is SimpleIdentifier) {
    return <String>[expression.name];
  }
  if (expression is PrefixedIdentifier) {
    final prefixPath = _memberAccessPath(expression.prefix);
    if (prefixPath == null) {
      return null;
    }
    return <String>[...prefixPath, expression.identifier.name];
  }
  if (expression is PropertyAccess) {
    final targetPath = _memberAccessPath(expression.realTarget);
    if (targetPath == null) {
      return null;
    }
    return <String>[...targetPath, expression.propertyName.name];
  }
  return null;
}
