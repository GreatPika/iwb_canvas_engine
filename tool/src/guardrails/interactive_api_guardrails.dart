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

  final boundaryViolation = _checkInteractiveBoundaryShape(context);
  if (boundaryViolation != null) {
    violations.add(boundaryViolation);
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

GuardrailViolation? _checkInteractiveBoundaryShape(GuardrailContext context) {
  final runtimeFile = _interactiveSupportFile(
    context,
    'internal/interactive_runtime.dart',
  );
  final eventFile = _interactiveSupportFile(
    context,
    'internal/interactive_event_dispatcher.dart',
  );
  final drawCoordinatorFile = _interactiveSupportFile(
    context,
    'internal/interactive_draw_coordinator.dart',
  );
  final drawEraserFile = _interactiveSupportFile(
    context,
    'internal/interactive_draw_eraser_engine.dart',
  );

  final missingOwnerViolation =
      _missingInteractiveOwnerViolation(context, <File, String>{
        runtimeFile: 'InteractiveRuntime',
        eventFile: 'InteractiveEventDispatcher',
        drawCoordinatorFile: 'InteractiveDrawCoordinator',
        drawEraserFile: 'InteractiveDrawEraserEngine',
      });
  if (missingOwnerViolation != null) {
    return missingOwnerViolation;
  }

  final facadeSource = _interactiveFile(context).readAsStringSync();
  final runtimeSource = runtimeFile.readAsStringSync();
  final eventSource = eventFile.readAsStringSync();
  final drawCoordinatorSource = drawCoordinatorFile.readAsStringSync();
  final drawEraserSource = drawEraserFile.readAsStringSync();

  return _requireSourceTokens(
        source: facadeSource,
        filePath: _interactiveFilePosixPath(context, _interactiveFile(context)),
        requiredTokens: const <String>[
          "import 'internal/interactive_runtime.dart';",
          "import 'internal/interactive_event_dispatcher.dart';",
          "import 'internal/interactive_selection_actions.dart';",
          '_runtime.handlePointer(',
          '_runtime.handleDoubleTap(',
        ],
        bannedTokens: const <String>[
          "import 'internal/interactive_move_session.dart';",
          "import 'internal/interactive_gesture_machine.dart';",
          "import 'internal/interactive_draw_coordinator.dart';",
          "import 'internal/interactive_draw_eraser_engine.dart';",
          'StreamController<',
          '_timestampCursorMs',
        ],
        message:
            'interactive API violation: SceneControllerInteractive must remain '
            'a thin facade over runtime/event/selection owners.',
      ) ??
      _requireSourceTokens(
        source: runtimeSource,
        filePath: _interactiveFilePosixPath(context, runtimeFile),
        requiredTokens: const <String>[
          "import 'interactive_draw_coordinator.dart';",
          "import 'interactive_event_dispatcher.dart';",
          "import 'interactive_move_session.dart';",
          "import 'interactive_pointer_normalizer.dart';",
          "import 'interactive_gesture_router.dart';",
          "import 'interactive_double_tap_router.dart';",
        ],
        bannedTokens: const <String>[
          'StreamController<',
          '_timestampCursorMs',
          '_actionCounter',
          '_actions =',
          '_editTextRequests =',
          '_eraserHitsLine(',
        ],
        message:
            'interactive API violation: InteractiveRuntime must keep event '
            'timeline and draw-local geometry outside the boundary runtime.',
      ) ??
      _requireSourceTokens(
        source: eventSource,
        filePath: _interactiveFilePosixPath(context, eventFile),
        requiredTokens: const <String>[
          "import 'dart:async';",
          'class InteractiveEventDispatcher',
          'resolveTimestampMs(',
          'emitAction(',
          'emitEditTextRequested(',
        ],
        bannedTokens: const <String>['_eraserHitsLine('],
        message:
            'interactive API violation: InteractiveEventDispatcher must remain '
            'the event/timeline owner.',
      ) ??
      _requireSourceTokens(
        source: drawCoordinatorSource,
        filePath: _interactiveFilePosixPath(context, drawCoordinatorFile),
        requiredTokens: const <String>[
          "import 'interactive_draw_eraser_engine.dart';",
          "import 'interactive_draw_line_engine.dart';",
          "import 'interactive_draw_stroke_engine.dart';",
          "import 'interactive_draw_terminal_router.dart';",
        ],
        bannedTokens: const <String>[
          '_eraserHitsLine(',
          '_eraserHitsStroke(',
          '_localEraserSegmentsHitLine(',
          '_eraserSegmentHitsStrokeBatch(',
        ],
        message:
            'interactive API violation: InteractiveDrawCoordinator must remain '
            'a draw-family orchestrator and not re-own eraser geometry.',
      ) ??
      _requireSourceTokens(
        source: drawEraserSource,
        filePath: _interactiveFilePosixPath(context, drawEraserFile),
        requiredTokens: const <String>[
          '_eraserHitsLine(',
          '_eraserHitsStroke(',
          '_localEraserSegmentsHitLine(',
          '_eraserSegmentHitsStrokeBatch(',
        ],
        bannedTokens: const <String>[],
        message:
            'interactive API violation: eraser geometry helpers must remain '
            'behind InteractiveDrawEraserEngine.',
      );
}

GuardrailViolation? _missingInteractiveOwnerViolation(
  GuardrailContext context,
  Map<File, String> requiredOwners,
) {
  for (final entry in requiredOwners.entries) {
    final file = entry.key;
    if (file.existsSync()) {
      continue;
    }
    return GuardrailViolation(
      filePath: _interactiveFilePosixPath(context, _interactiveFile(context)),
      line: 1,
      message:
          'interactive API violation: missing required split owner '
          '${entry.value} at '
          '${_interactiveFilePosixPath(context, file)}.',
    );
  }
  return null;
}

File _interactiveSupportFile(GuardrailContext context, String relativePath) {
  return File(
    '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
    'src${Platform.pathSeparator}interactive${Platform.pathSeparator}'
    '${relativePath.replaceAll('/', Platform.pathSeparator)}',
  );
}

GuardrailViolation? _requireSourceTokens({
  required String source,
  required String filePath,
  required List<String> requiredTokens,
  required List<String> bannedTokens,
  required String message,
}) {
  for (final token in requiredTokens) {
    if (!source.contains(token)) {
      return GuardrailViolation(filePath: filePath, line: 1, message: message);
    }
  }
  for (final token in bannedTokens) {
    final offset = source.indexOf(token);
    if (offset < 0) {
      continue;
    }
    final line = '\n'.allMatches(source.substring(0, offset)).length + 1;
    return GuardrailViolation(filePath: filePath, line: line, message: message);
  }
  return null;
}
