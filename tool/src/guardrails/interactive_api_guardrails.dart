import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../guardrail_support/guardrail_ast_utils.dart';
import '../guardrail_support/guardrail_context.dart';
import '../guardrail_support/guardrail_path_utils.dart';
import 'public_surface_guardrails.dart';

Future<List<GuardrailViolation>> runInteractiveApiGuardrails({
  required GuardrailContext context,
}) async {
  final violations = <GuardrailViolation>[];
  final file = _interactiveFile(context);
  if (!file.existsSync()) {
    return violations;
  }

  final filePosixPath = _interactiveFilePosixPath(context, file);
  final parsed = _parseInteractiveFile(context, file, filePosixPath);
  final interactiveClass = _findInteractiveClass(parsed.unit.declarations);
  if (interactiveClass == null) {
    return violations;
  }

  for (final member in interactiveClass.members) {
    final name = _interactiveEntrypointName(member);
    if (name == null) {
      continue;
    }
    final violation = _checkInteractiveEntrypointGuard(
      member: member as MethodDeclaration,
      name: name,
      filePath: filePosixPath,
      lineFor: (offset) => lineForOffset(parsed, offset),
    );
    if (violation != null) {
      violations.add(violation);
      return violations;
    }
  }
  return violations;
}

File _interactiveFile(GuardrailContext context) {
  return File(
    '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
    'src${Platform.pathSeparator}interactive${Platform.pathSeparator}'
    'scene_controller_interactive.dart',
  );
}

String _interactiveFilePosixPath(GuardrailContext context, File file) {
  return toRepoRelPosixPath(
    absPosixPath: toPosixPath(file.absolute.path),
    rootAbsPosixPath: context.rootAbsPosixPath,
  );
}

ParsedUnitResult _parseInteractiveFile(
  GuardrailContext context,
  File file,
  String filePosixPath,
) {
  return parseUnitOrFail(
    context: context,
    absPath: file.absolute.path,
    filePathForDiag: filePosixPath,
    onFailure: _onInteractiveParseFailure,
  );
}

ClassDeclaration? _findInteractiveClass(
  NodeList<CompilationUnitMember> declarations,
) {
  for (final declaration in declarations) {
    if (declaration is ClassDeclaration &&
        declaration.name.lexeme == 'SceneControllerInteractive') {
      return declaration;
    }
  }
  return null;
}

class EnsureCallInfo {
  const EnsureCallInfo({required this.hasAllowAfterDispose});

  final bool hasAllowAfterDispose;
}

class InteractiveGuardContext {
  const InteractiveGuardContext({
    required this.firstStatement,
    required this.expressionStatement,
  });

  final Statement firstStatement;
  final ExpressionStatement expressionStatement;
}

String? _interactiveEntrypointName(ClassMember member) {
  if (member is! MethodDeclaration) {
    return null;
  }
  if (member.isStatic || member.isGetter) {
    return null;
  }
  final name = member.name.lexeme;
  if (!isPublicName(name) || name == 'SceneControllerInteractive') {
    return null;
  }
  return name;
}

GuardrailViolation? _checkInteractiveEntrypointGuard({
  required MethodDeclaration member,
  required String name,
  required String filePath,
  required int Function(int offset) lineFor,
}) {
  final guardContext = _interactiveGuardContext(
    member: member,
    filePath: filePath,
    lineFor: lineFor,
  );
  final violation = _guardContextViolation(guardContext);
  if (violation != null) {
    return violation;
  }
  if (guardContext is! InteractiveGuardContext) {
    return null;
  }

  final ensureCallInfo = _ensureCallInfoFromExpression(
    guardContext.expressionStatement.expression,
  );
  return _validateEnsureCall(
    ensureCallInfo: ensureCallInfo,
    name: name,
    filePath: filePath,
    line: lineFor(guardContext.firstStatement.offset),
  );
}

Object? _interactiveGuardContext({
  required MethodDeclaration member,
  required String filePath,
  required int Function(int offset) lineFor,
}) {
  final body = member.body;
  if (body is! BlockFunctionBody) {
    return _GuardViolation(
      GuardrailViolation(
        filePath: filePath,
        line: lineFor(member.offset),
        message:
            'interactive API violation: public SceneControllerInteractive '
            'entrypoint "${member.name.lexeme}" must use a block body guarded '
            'by _ensurePublicSideEffectAllowed(...).',
      ),
    );
  }
  final statements = body.block.statements;
  if (statements.isEmpty) {
    return _GuardViolation(
      _interactiveGuardViolation(
        filePath: filePath,
        line: lineFor(member.offset),
      ),
    );
  }
  final firstStatement = statements.first;
  if (firstStatement is! ExpressionStatement) {
    return _GuardViolation(
      _interactiveGuardViolation(
        filePath: filePath,
        line: lineFor(firstStatement.offset),
      ),
    );
  }
  return InteractiveGuardContext(
    firstStatement: firstStatement,
    expressionStatement: firstStatement,
  );
}

EnsureCallInfo? _ensureCallInfoFromExpression(Expression expression) {
  if (expression is! MethodInvocation) {
    return null;
  }
  if (expression.target != null) {
    return null;
  }
  if (expression.methodName.name != '_ensurePublicSideEffectAllowed') {
    return null;
  }

  var hasAllowAfterDispose = false;
  for (final argument in expression.argumentList.arguments) {
    if (argument is! NamedExpression) {
      continue;
    }
    if (argument.name.label.name != 'allowAfterDispose') {
      continue;
    }
    final value = argument.expression;
    if (value is BooleanLiteral && value.value) {
      hasAllowAfterDispose = true;
    }
  }
  return EnsureCallInfo(hasAllowAfterDispose: hasAllowAfterDispose);
}

GuardrailViolation _interactiveGuardViolation({
  required String filePath,
  required int line,
}) {
  return GuardrailViolation(
    filePath: filePath,
    line: line,
    message:
        'interactive API violation: public SceneControllerInteractive '
        'entrypoints must guard resolver purity with '
        '_ensurePublicSideEffectAllowed(...).',
  );
}

class _GuardViolation {
  const _GuardViolation(this.violation);

  final GuardrailViolation violation;
}

GuardrailViolation? _guardContextViolation(Object? guardContext) {
  if (guardContext case _GuardViolation(:final violation)) {
    return violation;
  }
  return null;
}

GuardrailViolation? _validateEnsureCall({
  required EnsureCallInfo? ensureCallInfo,
  required String name,
  required String filePath,
  required int line,
}) {
  if (ensureCallInfo == null) {
    return _interactiveGuardViolation(filePath: filePath, line: line);
  }
  if (name == 'dispose') {
    return ensureCallInfo.hasAllowAfterDispose
        ? null
        : GuardrailViolation(
            filePath: filePath,
            line: line,
            message:
                'interactive API violation: dispose() must guard resolver '
                'purity with allowAfterDispose: true.',
          );
  }
  return ensureCallInfo.hasAllowAfterDispose
      ? GuardrailViolation(
          filePath: filePath,
          line: line,
          message:
              'interactive API violation: only dispose() may call '
              '_ensurePublicSideEffectAllowed(..., allowAfterDispose: true).',
        )
      : null;
}

Never _onInteractiveParseFailure({
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
