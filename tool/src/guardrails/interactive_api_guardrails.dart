import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../guardrail_support/guardrail_ast_utils.dart';
import '../guardrail_support/guardrail_context.dart';
import '../guardrail_support/guardrail_path_utils.dart';
import 'interactive_mutation_guard_contract.dart';
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

  final rootViolation = _checkRootEntrypoints(
    interactiveClass,
    filePath: filePosixPath,
    lineFor: (offset) => lineForOffset(parsed, offset),
  );
  if (rootViolation != null) {
    violations.add(rootViolation);
    return violations;
  }

  final capabilityViolation = _checkCapabilityEntrypoints(context);
  if (capabilityViolation != null) {
    violations.add(capabilityViolation);
    return violations;
  }

  final mutationOwnerViolation = _checkMutationOwnerPolicies(context);
  if (mutationOwnerViolation != null) {
    violations.add(mutationOwnerViolation);
    return violations;
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
    'scene_controller.dart',
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
        declaration.name.lexeme == 'SceneController') {
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

String? _publicEntrypointName(ClassMember member) {
  if (member is! MethodDeclaration) {
    return null;
  }
  if (member.isStatic || member.isGetter) {
    return null;
  }
  final name = member.name.lexeme;
  if (!isPublicName(name) || name == 'SceneController') {
    return null;
  }
  if (name == 'addListener' || name == 'removeListener') {
    return null;
  }
  return name;
}

GuardrailViolation? _checkRootEntrypoints(
  ClassDeclaration interactiveClass, {
  required String filePath,
  required int Function(int offset) lineFor,
}) {
  for (final member in interactiveClass.members) {
    final name = _publicEntrypointName(member);
    if (name == null) {
      continue;
    }
    final violation = _checkInteractiveEntrypointGuard(
      member: member as MethodDeclaration,
      name: name,
      filePath: filePath,
      lineFor: lineFor,
    );
    if (violation != null) {
      return violation;
    }
  }
  return null;
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
            'interactive API violation: public SceneController '
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
        'interactive API violation: public SceneController '
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

final class CapabilityGuardSpec {
  const CapabilityGuardSpec({
    required this.relativePath,
    required this.className,
    required this.primaryGuardCall,
    this.secondaryGuardCallsByMethod = const <String, String>{},
  });

  final String relativePath;
  final String className;
  final String primaryGuardCall;
  final Map<String, String> secondaryGuardCallsByMethod;
}

const List<CapabilityGuardSpec> _capabilityGuardSpecs = <CapabilityGuardSpec>[
  CapabilityGuardSpec(
    relativePath: 'scene_controller_interaction.dart',
    className: 'SceneControllerInteraction',
    primaryGuardCall: '_access.runtime.ensurePublicSideEffectAllowed',
  ),
  CapabilityGuardSpec(
    relativePath: 'scene_controller_scene.dart',
    className: 'SceneControllerScene',
    primaryGuardCall: 'ensurePublicSideEffectAllowed',
  ),
  CapabilityGuardSpec(
    relativePath: 'scene_controller_selection.dart',
    className: 'SceneControllerSelection',
    primaryGuardCall: '_runtime.ensurePublicSideEffectAllowed',
  ),
];

GuardrailViolation? _checkCapabilityEntrypoints(GuardrailContext context) {
  for (final spec in _capabilityGuardSpecs) {
    final file = _interactiveSupportFile(context, spec.relativePath);
    if (!file.existsSync()) {
      return GuardrailViolation(
        filePath: _interactiveFilePosixPath(context, _interactiveFile(context)),
        line: 1,
        message:
            'interactive API violation: missing required capability owner '
            '${spec.className} at ${_interactiveFilePosixPath(context, file)}.',
      );
    }

    final filePath = _interactiveFilePosixPath(context, file);
    final parsed = _parseInteractiveFile(context, file, filePath);
    final capabilityClass = _findClassByName(
      parsed.unit.declarations,
      spec.className,
    );
    if (capabilityClass == null) {
      return GuardrailViolation(
        filePath: filePath,
        line: 1,
        message:
            'interactive API violation: ${spec.className} must remain the '
            'canonical capability owner in $filePath.',
      );
    }

    for (final member in capabilityClass.members) {
      final name = _publicEntrypointName(member);
      if (name == null) {
        continue;
      }
      final violation = _checkCapabilityEntrypointGuard(
        member: member as MethodDeclaration,
        filePath: filePath,
        lineFor: (offset) => lineForOffset(parsed, offset),
        className: spec.className,
        name: name,
        primaryGuardCall: spec.primaryGuardCall,
        secondaryGuardCall: spec.secondaryGuardCallsByMethod[name],
      );
      if (violation != null) {
        return violation;
      }
    }
  }
  return null;
}

GuardrailViolation? _checkMutationOwnerPolicies(GuardrailContext context) {
  for (final spec in mutationOwnerGuardSpecs) {
    final file = _interactiveSupportFile(context, spec.relativePath);
    if (!file.existsSync()) {
      return GuardrailViolation(
        filePath: _interactiveFilePosixPath(context, _interactiveFile(context)),
        line: 1,
        message:
            'interactive API violation: missing required mutation owner '
            '${spec.className} at ${_interactiveFilePosixPath(context, file)}.',
      );
    }

    final filePath = _interactiveFilePosixPath(context, file);
    final parsed = _parseInteractiveFile(context, file, filePath);
    final ownerClass = _findClassByName(
      parsed.unit.declarations,
      spec.className,
    );
    if (ownerClass == null) {
      return GuardrailViolation(
        filePath: filePath,
        line: 1,
        message:
            'interactive API violation: ${spec.className} must remain the '
            'canonical mutation owner in $filePath.',
      );
    }

    for (final policy in spec.policies) {
      final member = _findMethodByName(ownerClass.members, policy.methodName);
      if (member == null) {
        return GuardrailViolation(
          filePath: filePath,
          line: 1,
          message:
              'interactive API violation: '
              '${spec.className}.${policy.methodName} '
              'must remain part of the canonical mutation-owner surface.',
        );
      }
      final violation = _checkMutationOwnerPolicy(
        member: member,
        filePath: filePath,
        lineFor: (offset) => lineForOffset(parsed, offset),
        className: spec.className,
        methodName: policy.methodName,
        policyCall: policy.policyCall,
        policyIndex: policy.policyIndex,
      );
      if (violation != null) {
        return violation;
      }
    }
  }
  return null;
}

ClassDeclaration? _findClassByName(
  NodeList<CompilationUnitMember> declarations,
  String className,
) {
  for (final declaration in declarations) {
    if (declaration is ClassDeclaration &&
        declaration.name.lexeme == className) {
      return declaration;
    }
  }
  return null;
}

MethodDeclaration? _findMethodByName(
  NodeList<ClassMember> members,
  String name,
) {
  for (final member in members) {
    if (member is MethodDeclaration && member.name.lexeme == name) {
      return member;
    }
  }
  return null;
}

GuardrailViolation? _checkCapabilityEntrypointGuard({
  required MethodDeclaration member,
  required String filePath,
  required int Function(int offset) lineFor,
  required String className,
  required String name,
  required String primaryGuardCall,
  required String? secondaryGuardCall,
}) {
  final body = member.body;
  if (body is! BlockFunctionBody) {
    return _capabilityGuardViolation(
      filePath: filePath,
      line: lineFor(member.offset),
      detail:
          'public $className entrypoints must use a block body guarded by '
          '$primaryGuardCall(...).',
    );
  }

  final statements = body.block.statements;
  if (statements.isEmpty) {
    return _capabilityGuardViolation(
      filePath: filePath,
      line: lineFor(member.offset),
      detail:
          'public $className entrypoints must guard resolver purity with '
          '$primaryGuardCall(...).',
    );
  }

  final firstCall = _qualifiedInvocationNameFromStatement(statements.first);
  if (firstCall != primaryGuardCall) {
    return _capabilityGuardViolation(
      filePath: filePath,
      line: lineFor(statements.first.offset),
      detail:
          'public $className entrypoints must guard resolver purity with '
          '$primaryGuardCall(...).',
    );
  }

  if (secondaryGuardCall == null) {
    return null;
  }
  if (statements.length < 2) {
    return _capabilityGuardViolation(
      filePath: filePath,
      line: lineFor(statements.first.offset),
      detail:
          '$className.$name must guard active-gesture exclusivity with '
          '$secondaryGuardCall(...).',
    );
  }

  final secondCall = _qualifiedInvocationNameFromStatement(statements[1]);
  if (secondCall != secondaryGuardCall) {
    return _capabilityGuardViolation(
      filePath: filePath,
      line: lineFor(statements[1].offset),
      detail:
          '$className.$name must guard active-gesture exclusivity with '
          '$secondaryGuardCall(...).',
    );
  }
  return null;
}

GuardrailViolation? _checkMutationOwnerPolicy({
  required MethodDeclaration member,
  required String filePath,
  required int Function(int offset) lineFor,
  required String className,
  required String methodName,
  required String policyCall,
  required int policyIndex,
}) {
  final body = member.body;
  if (body is! BlockFunctionBody) {
    return _capabilityGuardViolation(
      filePath: filePath,
      line: lineFor(member.offset),
      detail:
          '$className.$methodName must guard active-gesture exclusivity with '
          '$policyCall(...).',
    );
  }

  final statements = body.block.statements;
  if (statements.length <= policyIndex) {
    return _capabilityGuardViolation(
      filePath: filePath,
      line: lineFor(member.offset),
      detail:
          '$className.$methodName must guard active-gesture exclusivity with '
          '$policyCall(...).',
    );
  }

  final actualCall = _qualifiedInvocationNameFromStatement(
    statements[policyIndex],
  );
  if (actualCall != policyCall) {
    return _capabilityGuardViolation(
      filePath: filePath,
      line: lineFor(statements[policyIndex].offset),
      detail:
          '$className.$methodName must guard active-gesture exclusivity with '
          '$policyCall(...).',
    );
  }
  return null;
}

String? _qualifiedInvocationNameFromStatement(Statement statement) {
  if (statement is! ExpressionStatement) {
    return null;
  }
  return _qualifiedInvocationName(statement.expression);
}

String? _qualifiedInvocationName(Expression expression) {
  if (expression is! MethodInvocation) {
    return null;
  }

  final target = expression.target;
  final methodName = expression.methodName.name;
  if (target == null) {
    return methodName;
  }
  final qualifiedTarget = _qualifiedTargetName(target);
  if (qualifiedTarget == null) {
    return null;
  }
  return '$qualifiedTarget.$methodName';
}

String? _qualifiedTargetName(Expression expression) {
  return switch (expression) {
    SimpleIdentifier(:final name) => name,
    PrefixedIdentifier(:final prefix, :final identifier) =>
      '${prefix.name}.${identifier.name}',
    PropertyAccess(:final target?, :final propertyName) =>
      '${_qualifiedTargetName(target)}.${propertyName.name}',
    ThisExpression() => 'this',
    _ => null,
  };
}

GuardrailViolation _capabilityGuardViolation({
  required String filePath,
  required int line,
  required String detail,
}) {
  return GuardrailViolation(
    filePath: filePath,
    line: line,
    message: 'interactive API violation: $detail',
  );
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
  final facadeFile = _interactiveFile(context);
  final facadeFilePosixPath = _interactiveFilePosixPath(context, facadeFile);
  final parsed = _parseInteractiveFile(
    context,
    facadeFile,
    facadeFilePosixPath,
  );
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
  final drawEraserExactHitFile = _interactiveSupportFile(
    context,
    'internal/interactive_draw_eraser_exact_hit.dart',
  );
  final drawEraserLineHitFile = _interactiveSupportFile(
    context,
    'internal/interactive_draw_eraser_line_hit.dart',
  );
  final drawEraserProjectionFile = _interactiveSupportFile(
    context,
    'internal/interactive_draw_eraser_projection.dart',
  );
  final drawEraserStrokeHitFile = _interactiveSupportFile(
    context,
    'internal/interactive_draw_eraser_stroke_hit.dart',
  );
  final drawStyleFile = _interactiveSupportFile(
    context,
    'internal/interactive_draw_style.dart',
  );
  final interactionConfigFile = _interactiveSupportFile(
    context,
    'internal/scene_controller_interaction_config.dart',
  );
  final interactionFile = _interactiveSupportFile(
    context,
    'scene_controller_interaction.dart',
  );
  final interactionRuntimeFile = _interactiveSupportFile(
    context,
    'internal/scene_controller_interaction_runtime.dart',
  );
  final interactionAccessFile = _interactiveSupportFile(
    context,
    'internal/scene_controller_interaction_access.dart',
  );
  final sceneMutationsFile = _interactiveSupportFile(
    context,
    'internal/scene_controller_scene_mutations.dart',
  );
  final selectionMutationsFile = _interactiveSupportFile(
    context,
    'internal/scene_controller_selection_mutations.dart',
  );
  final mutationBoundaryFile = _interactiveSupportFile(
    context,
    'internal/scene_controller_mutation_boundary.dart',
  );
  final pointerSessionFile = _interactiveSupportFile(
    context,
    'internal/scene_controller_pointer_session.dart',
  );
  final selectionActionsFile = _interactiveSupportFile(
    context,
    'internal/interactive_selection_actions.dart',
  );
  final ownerGraphFile = _interactiveSupportFile(
    context,
    'internal/scene_controller_graph.dart',
  );
  final viewRuntimeFile = _interactiveSupportFile(
    context,
    'internal/scene_controller_scene_view_runtime.dart',
  );
  final internalAccessFile = _interactiveSupportFile(
    context,
    'internal/scene_controller_internal_access.dart',
  );
  final runtimeContractFile = File(
    '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
    'src${Platform.pathSeparator}contract${Platform.pathSeparator}'
    'scene_view_runtime.dart',
  );
  final sceneViewInteractiveFile = File(
    '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
    'src${Platform.pathSeparator}view${Platform.pathSeparator}'
    'scene_view_interactive.dart',
  );
  final sceneViewRuntimeFile = File(
    '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
    'src${Platform.pathSeparator}view${Platform.pathSeparator}'
    'scene_view_runtime_host.dart',
  );
  final renderSurfaceFile = File(
    '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
    'src${Platform.pathSeparator}view${Platform.pathSeparator}'
    'scene_view_render_surface.dart',
  );
  final pointerHostFile = File(
    '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
    'src${Platform.pathSeparator}view${Platform.pathSeparator}'
    'scene_view_interactive_pointer_host.dart',
  );
  final pointerSessionTokenFile = _interactiveSupportFile(
    context,
    'internal/pointer_session_token.dart',
  );

  final missingOwnerViolation =
      _missingInteractiveOwnerViolation(context, <File, String>{
        runtimeFile: 'InteractiveRuntime',
        eventFile: 'InteractiveEventDispatcher',
        drawCoordinatorFile: 'InteractiveDrawCoordinator',
        drawEraserFile: 'InteractiveDrawEraserEngine',
        drawEraserExactHitFile: 'InteractiveDrawEraserExactHit',
        drawEraserLineHitFile: 'InteractiveDrawEraserLineHit',
        drawEraserProjectionFile: 'InteractiveDrawProjectedEraser',
        drawEraserStrokeHitFile: 'InteractiveDrawEraserStrokeHit',
        drawStyleFile: 'InteractiveDrawStyle',
        interactionConfigFile: 'SceneControllerInteractionConfig',
        interactionFile: 'SceneControllerInteraction',
        interactionRuntimeFile: 'SceneControllerInteractionRuntime',
        interactionAccessFile: 'SceneControllerInteractionContext',
        sceneMutationsFile: 'SceneControllerSceneMutations',
        selectionMutationsFile: 'SceneControllerSelectionMutations',
        mutationBoundaryFile: 'SceneControllerMutationBoundary',
        pointerSessionFile: 'SceneControllerPointerSession',
        pointerSessionTokenFile: 'PointerSessionToken',
        selectionActionsFile: 'InteractiveSelectionActions',
        ownerGraphFile: 'createSceneControllerGraph',
        viewRuntimeFile: 'SceneControllerSceneViewRuntime',
        internalAccessFile: 'SceneControllerInternalAccess',
        runtimeContractFile: 'SceneViewRuntime',
        sceneViewInteractiveFile: 'SceneViewInteractive',
        sceneViewRuntimeFile: 'SceneViewRuntimeHost',
        renderSurfaceFile: 'SceneViewRenderSurface',
        pointerHostFile: 'SceneViewInteractivePointerHost',
      });
  if (missingOwnerViolation != null) {
    return missingOwnerViolation;
  }
  for (final deletedPath in <String>[
    'internal/scene_controller_scene_access.dart',
    'internal/scene_controller_selection_access.dart',
    'internal/scene_controller_facade_assembly.dart',
    'internal/scene_controller_pointer_semantics.dart',
    'scene_view_pointer_semantics.dart',
  ]) {
    if (_interactiveSupportFile(context, deletedPath).existsSync()) {
      final detail = switch (deletedPath) {
        'internal/scene_controller_scene_access.dart' =>
          'SceneControllerSceneAccessAdapter is a deleted residual seam and '
              'must not exist.',
        'internal/scene_controller_selection_access.dart' =>
          'SceneControllerSelectionAccessAdapter is a deleted residual seam '
              'and must not exist.',
        'internal/scene_controller_facade_assembly.dart' =>
          'assembleSceneControllerFacade is a deleted residual seam and must '
              'not exist.',
        'internal/scene_controller_pointer_semantics.dart' =>
          'SceneControllerPointerSemantics is a deleted residual seam and '
              'must not exist.',
        'scene_view_pointer_semantics.dart' =>
          'SceneView pointer-semantics seam is deleted and must not exist.',
        _ => 'deleted residual seam must not exist ($deletedPath).',
      };
      return GuardrailViolation(
        filePath: 'lib/src/interactive/$deletedPath',
        line: 1,
        message: 'interactive API violation: $detail',
      );
    }
  }

  final facadeSource = facadeFile.readAsStringSync();
  final interactionSource = interactionFile.readAsStringSync();
  final runtimeSource = runtimeFile.readAsStringSync();
  final pointerSessionTokenSource = pointerSessionTokenFile.readAsStringSync();
  final eventSource = eventFile.readAsStringSync();
  final drawCoordinatorSource = drawCoordinatorFile.readAsStringSync();
  final drawEraserSource = drawEraserFile.readAsStringSync();
  final drawEraserExactHitSource = drawEraserExactHitFile.readAsStringSync();
  final drawEraserLineHitSource = drawEraserLineHitFile.readAsStringSync();
  final drawEraserProjectionSource = drawEraserProjectionFile
      .readAsStringSync();
  final drawEraserStrokeHitSource = drawEraserStrokeHitFile.readAsStringSync();
  final drawStyleSource = drawStyleFile.readAsStringSync();
  final internalAccessSource = internalAccessFile.readAsStringSync();
  final interactionRuntimeSource = interactionRuntimeFile.readAsStringSync();
  final sceneMutationsSource = sceneMutationsFile.readAsStringSync();
  final selectionMutationsSource = selectionMutationsFile.readAsStringSync();
  final mutationBoundarySource = mutationBoundaryFile.readAsStringSync();
  final pointerSessionSource = pointerSessionFile.readAsStringSync();
  final selectionActionsSource = selectionActionsFile.readAsStringSync();
  final graphSource = ownerGraphFile.readAsStringSync();
  final viewRuntimeSource = viewRuntimeFile.readAsStringSync();
  final runtimeContractSource = runtimeContractFile.readAsStringSync();
  final pointerHostSource = pointerHostFile.readAsStringSync();
  final sceneViewInteractiveSource = sceneViewInteractiveFile
      .readAsStringSync();
  final sceneViewRuntimeSource = sceneViewRuntimeFile.readAsStringSync();
  final renderSurfaceSource = renderSurfaceFile.readAsStringSync();
  final eligibilityPolicyFile = _interactiveSupportFile(
    context,
    'interaction_eligibility_policy.dart',
  );
  final eligibilityPolicySource = eligibilityPolicyFile.readAsStringSync();

  return _topLevelFacadeHelperViolation(context, parsed: parsed) ??
      _requireSourceTokens(
        source: interactionSource,
        filePath: _interactiveFilePosixPath(context, interactionFile),
        requiredTokens: const <String>[],
        bannedTokens: const <String>[
          'SceneSnapshot get snapshot',
          'get snapshot => _access.snapshot',
        ],
        message:
            'interactive API violation: SceneControllerInteraction must not '
            'expose committed render-state through snapshot.',
      ) ??
      _requireSourceTokens(
        source: facadeSource,
        filePath: facadeFilePosixPath,
        requiredTokens: const <String>[
          "import 'internal/scene_controller_graph.dart';",
          "import '../contract/scene_view_runtime.dart';",
          'createSceneControllerGraph(',
          'SceneControllerGraphRequest(',
          'SceneViewRuntime sceneControllerViewRuntimeOf(',
        ],
        bannedTokens: const <String>[
          'implements SceneViewRenderState',
          'createPointerSemanticsBridge(',
          "import 'internal/scene_controller_internal_access.dart';",
          "import 'internal/scene_controller_pointer_session.dart';",
          "import 'internal/interactive_draw_coordinator.dart';",
          "import 'internal/interactive_runtime.dart';",
          "import 'internal/interactive_event_dispatcher.dart';",
          '_runtime.handlePointer(',
          '_runtime.handleDoubleTap(',
          'StreamController<',
          '_timestampCursorMs',
        ],
        message:
            'interactive API violation: SceneController must remain '
            'a thin facade over the assembled controller graph.',
      ) ??
      _requireSourceTokens(
        source: runtimeContractSource,
        filePath: toRepoRelPosixPath(
          absPosixPath: toPosixPath(runtimeContractFile.absolute.path),
          rootAbsPosixPath: context.rootAbsPosixPath,
        ),
        requiredTokens: const <String>[
          'abstract interface class SceneViewRuntime',
          'SceneViewPointerSession createPointerSession({',
          'abstract interface class SceneViewPointerSession',
          'void detach();',
        ],
        bannedTokens: const <String>[
          'handleControllerChanged(',
          'updateController(',
        ],
        message:
            'interactive API violation: SceneViewRuntime must remain the '
            'single internal runtime/session contract for view core.',
      ) ??
      _requireSourceTokens(
        source: graphSource,
        filePath: _interactiveFilePosixPath(context, ownerGraphFile),
        requiredTokens: const <String>[
          'SceneControllerInteraction(',
          'SceneControllerSelection(',
          'SceneControllerScene(',
          'SceneControllerSceneViewRuntime(',
          'SceneControllerInternalAccessRegistration(',
          'registerSceneControllerInternalAccess(',
        ],
        bannedTokens: const <String>[
          'createPointerSemanticsBridge(',
          'SceneControllerPointerSemantics',
        ],
        message:
            'interactive API violation: SceneController graph must '
            'assemble view runtime and internal access outside the facade.',
      ) ??
      _requireSourceTokens(
        source: viewRuntimeSource,
        filePath: _interactiveFilePosixPath(context, viewRuntimeFile),
        requiredTokens: const <String>[
          'final class SceneControllerSceneViewRuntime',
          'final class SceneControllerSceneViewRenderState',
          'SceneControllerPointerSession(',
          'SceneControllerInteraction get _interaction',
          'createPointerSessionToken()',
          'detachPointerSession:',
          '_interactionRuntime.detachPointerSession',
          'releasePointerSessionToken:',
          '_interactionRuntime.releasePointerSessionToken',
          'handlePointerFromSession: _interactionRuntime.handlePointerFromSession',
        ],
        bannedTokens: const <String>[
          'SceneControllerPointerSemantics',
          'createPointerSemanticsBridge(',
          '_DisposedSceneViewPointerSession',
        ],
        message:
            'interactive API violation: SceneControllerSceneViewRuntime must '
            'own the render-state adapter and pointer-session factory.',
      ) ??
      _requireSourceTokens(
        source: pointerSessionTokenSource,
        filePath: _interactiveFilePosixPath(context, pointerSessionTokenFile),
        requiredTokens: const <String>['final class PointerSessionToken'],
        bannedTokens: const <String>[
          'operator ==',
          'hashCode',
          ' id;',
          'toJson(',
        ],
        message:
            'interactive API violation: PointerSessionToken must remain an '
            'opaque internal nominal token.',
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
          'void handlePublicPointer(CanvasPointerInput input)',
          'void handlePublicDoubleTap({required Offset position, int? timestampMs})',
          'handlePointerFromSession(',
          'handleDoubleTapFromSession({',
        ],
        bannedTokens: const <String>[
          'StreamController<',
          '_timestampCursorMs',
          '_actionCounter',
          '_actions =',
          '_editTextRequests =',
          '_eraserHitsLine(',
          'void handlePointer(CanvasPointerInput input)',
          'void handleDoubleTap({required Offset position, int? timestampMs})',
        ],
        message:
            'interactive API violation: InteractiveRuntime must keep event '
            'timeline and draw-local geometry outside the boundary runtime.',
      ) ??
      _requireSourceTokens(
        source: interactionRuntimeSource,
        filePath: _interactiveFilePosixPath(context, interactionRuntimeFile),
        requiredTokens: const <String>[
          "import 'pointer_session_token.dart';",
          "import '../../controller/scene_controller_committed_mutation_access.dart';",
          "import 'scene_controller_mutation_boundary.dart';",
          'required this.mutationAccess,',
          'final SceneControllerCommittedMutationAccess mutationAccess;',
          'PointerSessionToken createPointerSessionToken()',
          'void detachPointerSession(PointerSessionToken token)',
          'void releasePointerSessionToken(PointerSessionToken token)',
          'void handlePublicPointer(CanvasPointerInput input)',
          'void handlePublicDoubleTap({required Offset position, int? timestampMs})',
          'handlePointerFromSession(',
          'handleDoubleTapFromSession({',
          '_ensureKnownPointerSessionToken(token);',
          'mutationAccess: request.mutationAccess,',
          'writeSelectionReplace: mutationBoundary.setSelection,',
          'writeSelectionClear: mutationBoundary.clearSelection,',
          'commitMoveSelection: mutationBoundary.commitMoveSelection,',
          'commitDrawStroke: mutationBoundary.commitDrawStroke,',
          'mutationBoundary.commitDrawLineFromWorldSegment',
          'commitEraseNodes: mutationBoundary.commitEraseNodes,',
        ],
        bannedTokens: const <String>[
          'request.storeController.commands.writeSelectionReplace',
          'request.storeController.commands.writeSelectionClear',
          'request.storeController.draw.writeDrawStroke',
          'request.storeController.draw.writeDrawLineFromWorldSegment',
          'request.storeController.draw.writeEraseNodes',
          'void handlePointer(CanvasPointerInput input)',
          'void handleDoubleTap({required Offset position, int? timestampMs})',
        ],
        message:
            'interactive API violation: SceneControllerInteractionRuntime '
            'must route committed selection/draw callbacks through '
            'SceneControllerMutationBoundary.',
      ) ??
      _requireSourceTokens(
        source: eligibilityPolicySource,
        filePath: _interactiveFilePosixPath(context, eligibilityPolicyFile),
        requiredTokens: const <String>['_snapshotBoundsWorld('],
        bannedTokens: const <String>[
          "../model/document.dart",
          'txnNodeFromSnapshot(',
        ],
        message:
            'interactive API violation: interaction_eligibility_policy must '
            'stay model-free and avoid document.dart materialization helpers.',
      ) ??
      _requireSourceTokens(
        source: sceneMutationsSource,
        filePath: _interactiveFilePosixPath(context, sceneMutationsFile),
        requiredTokens: const <String>['mutations.'],
        bannedTokens: const <String>[
          'storeController.commands.',
          'storeController.writeReplaceScene(',
        ],
        bannedPatterns: <RegExp>[
          RegExp(r'storeController\.write\s*(<[^>]+>)?\s*\('),
        ],
        message:
            'interactive API violation: SceneControllerSceneMutations must '
            'delegate committed scene writes through '
            'SceneControllerMutationBoundary.',
      ) ??
      _requireSourceTokens(
        source: selectionMutationsSource,
        filePath: _interactiveFilePosixPath(context, selectionMutationsFile),
        requiredTokens: const <String>['mutations.'],
        bannedTokens: const <String>['storeController.commands.'],
        bannedPatterns: <RegExp>[
          RegExp(r'storeController\.write\s*(<[^>]+>)?\s*\('),
        ],
        message:
            'interactive API violation: SceneControllerSelectionMutations '
            'must delegate committed selection writes through '
            'SceneControllerMutationBoundary.',
      ) ??
      _requireSourceTokens(
        source: selectionActionsSource,
        filePath: _interactiveFilePosixPath(context, selectionActionsFile),
        requiredTokens: const <String>['mutations.'],
        bannedTokens: const <String>['core.commands.'],
        bannedPatterns: <RegExp>[RegExp(r'core\.write\s*(<[^>]+>)?\s*\(')],
        message:
            'interactive API violation: InteractiveSelectionActions must '
            'remain a thin routing shell over SceneControllerMutationBoundary.',
      ) ??
      _requireSourceTokens(
        source: mutationBoundarySource,
        filePath: _interactiveFilePosixPath(context, mutationBoundaryFile),
        requiredTokens: const <String>[
          'class SceneControllerMutationBoundary',
          "import '../../controller/scene_controller_committed_mutation_access.dart';",
          'final SceneControllerCommittedMutationAccess mutationAccess;',
          'mutationAccess.clearSceneExactResult();',
          'mutationAccess.replaceSelection(nodeIds);',
          'mutationAccess.clearSelection();',
          'mutationAccess.deleteSelection();',
          'mutationAccess.transformSelection(delta);',
          'mutationAccess.prepareSceneReplacement(snapshot);',
          'mutationAccess.commitDrawStroke(',
          'mutationAccess.commitDrawLineFromWorldSegment(',
          'mutationAccess.commitEraseNodes(ids);',
          'mutationAccess.writePreparedSceneReplacement(replacement);',
        ],
        bannedTokens: const <String>[
          "import '../../controller/scene_store_controller.dart';",
          'SceneStoreController storeController;',
          'storeController.commands.',
          'storeController.draw.',
          'storeController.prepareSceneReplacement(',
          'storeController.writePreparedSceneReplacement(',
          'storeController.requestRepaint();',
          'storeController.writeReplaceScene(snapshot);',
          'txnSceneFromSnapshot(',
        ],
        message:
            'interactive API violation: SceneControllerMutationBoundary must '
            'remain the canonical scene/selection write owner.',
      ) ??
      _requireSourceTokens(
        source: pointerSessionSource,
        filePath: _interactiveFilePosixPath(context, pointerSessionFile),
        requiredTokens: const <String>[
          'class SceneControllerPointerSession',
          'PointerInputTracker(',
          '_PendingTapFlushScheduler',
          '_ownerListenable.addListener(',
          'PointerSessionToken token,',
          'detachPointerSession',
          'releasePointerSessionToken',
          'PointerSessionToken token',
          'void detach()',
          '_detachPointerSession(_token);',
          '_releaseOwnedResources();',
          '_handlePointerFromSession(',
          '_handleDoubleTapFromSession(',
          'void _releaseOwnedResources()',
          '_ownerListenable.removeListener(_ownerListener);',
          '_releasePointerSessionToken(',
        ],
        bannedTokens: const <String>[
          'handleControllerChanged(',
          'SceneControllerInteraction',
          '_readInteraction',
          'Object? owner',
          'Object? session',
          'Object? context',
          'runtimeType',
        ],
        message:
            'interactive API violation: pointer session must stay owned by '
            'SceneControllerPointerSession.',
      ) ??
      _requireSourceTokens(
        source: pointerHostSource,
        filePath: toRepoRelPosixPath(
          absPosixPath: toPosixPath(pointerHostFile.absolute.path),
          rootAbsPosixPath: context.rootAbsPosixPath,
        ),
        requiredTokens: const <String>[
          'SceneViewPointerSession',
          'replacePointerSession(',
          'current.detach();',
          'current.dispose();',
          '_pointerRouter.reset();',
          '_pointerSession = next;',
          '_pointerSession.detach();',
          '_pointerSession.dispose();',
        ],
        bannedTokens: const <String>[
          'SceneController',
          'createPointerSemanticsBridge(',
          'PointerInputTracker(',
          '_PendingTapFlushScheduler',
          '_pendingPointerSettings',
          '_SceneViewPointerSessionFactory',
        ],
        message:
            'interactive API violation: SceneViewInteractivePointerHost must '
            'remain a raw routing/lifecycle shell over pointer sessions.',
      ) ??
      _requireTokenOrder(
        source: pointerHostSource,
        filePath: toRepoRelPosixPath(
          absPosixPath: toPosixPath(pointerHostFile.absolute.path),
          rootAbsPosixPath: context.rootAbsPosixPath,
        ),
        scopeRootStart: 'class _SceneViewInteractivePointerRuntime',
        methodStart: 'void replacePointerSession(SceneViewPointerSession next)',
        orderedTokens: const <String>[
          'current.detach();',
          'current.dispose();',
          '_pointerRouter.reset();',
          '_pointerSession = next;',
        ],
        message:
            'interactive API violation: SceneViewInteractivePointerHost must '
            'detach old sessions before dispose and router reset.',
      ) ??
      _requireTokenOrder(
        source: pointerHostSource,
        filePath: toRepoRelPosixPath(
          absPosixPath: toPosixPath(pointerHostFile.absolute.path),
          rootAbsPosixPath: context.rootAbsPosixPath,
        ),
        scopeRootStart: 'class _SceneViewInteractivePointerRuntime',
        methodStart: 'void dispose()',
        orderedTokens: const <String>[
          '_pointerSession.detach();',
          '_pointerSession.dispose();',
        ],
        message:
            'interactive API violation: SceneViewInteractivePointerHost must '
            'detach current sessions before dispose.',
      ) ??
      _requireSourceTokens(
        source: sceneViewInteractiveSource,
        filePath: toRepoRelPosixPath(
          absPosixPath: toPosixPath(sceneViewInteractiveFile.absolute.path),
          rootAbsPosixPath: context.rootAbsPosixPath,
        ),
        requiredTokens: const <String>[
          "import '../interactive/scene_controller.dart';",
          "import 'scene_view_runtime_host.dart';",
          'sceneControllerViewRuntimeOf(controller)',
        ],
        bannedTokens: const <String>['Listener(', 'SceneViewRenderSurface('],
        message:
            'interactive API violation: SceneViewInteractive must remain a '
            'thin public shell over SceneViewRuntimeHost.',
      ) ??
      _requireSourceTokens(
        source: sceneViewRuntimeSource,
        filePath: toRepoRelPosixPath(
          absPosixPath: toPosixPath(sceneViewRuntimeFile.absolute.path),
          rootAbsPosixPath: context.rootAbsPosixPath,
        ),
        requiredTokens: const <String>[
          'class SceneViewRuntimeHost extends StatefulWidget',
          'late SceneViewRuntime _activeRuntime;',
          '_activeRuntime.createPointerSession(',
          'return runtime.createPointerSession(',
          'if (_activeRuntime == widget.runtime) {',
          'return;',
          '_createReplacementPointerSession(',
          '_pointerHost.replacePointerSession(',
          'final renderState = _activeRuntime.renderState;',
          '_activeRuntime = widget.runtime;',
          'SceneViewRenderSurface(',
        ],
        bannedTokens: const <String>[
          "import '../interactive/scene_controller.dart';",
          'createPointerSemanticsBridge(',
          'final renderState = widget.runtime.renderState;',
          'late SceneViewRuntime _requestedRuntime;',
          'FlutterError.reportError(',
          'if (nextPointerSession == null) {',
        ],
        message:
            'interactive API violation: SceneViewRuntimeHost must own '
            'runtime state beneath the public shell.',
      ) ??
      _requireTokenOrder(
        source: sceneViewRuntimeSource,
        filePath: toRepoRelPosixPath(
          absPosixPath: toPosixPath(sceneViewRuntimeFile.absolute.path),
          rootAbsPosixPath: context.rootAbsPosixPath,
        ),
        scopeRootStart: 'class _SceneViewRuntimeHostState',
        methodStart: 'void didUpdateWidget(SceneViewRuntimeHost oldWidget)',
        orderedTokens: const <String>[
          'final nextPointerSession = _createReplacementPointerSession(',
          '_pointerHost.replacePointerSession(nextPointerSession);',
          '_activeRuntime = widget.runtime;',
        ],
        message:
            'interactive API violation: SceneViewRuntimeHost must create '
            'replacement sessions before install, propagate failed swaps to '
            'the owner, compare updates against the installed runtime, and '
            'switch the active runtime only after install succeeds.',
      ) ??
      _requireSourceTokens(
        source: renderSurfaceSource,
        filePath: toRepoRelPosixPath(
          absPosixPath: toPosixPath(renderSurfaceFile.absolute.path),
          rootAbsPosixPath: context.rootAbsPosixPath,
        ),
        requiredTokens: const <String>[
          'required SceneViewRenderState renderState,',
        ],
        bannedTokens: const <String>[
          'SceneViewRenderSurface.store(',
          'SceneViewRenderSurface.interactive(',
          "import '../interactive/scene_controller.dart';",
          "import '../controller/scene_store_controller.dart';",
        ],
        message:
            'interactive API violation: SceneViewRenderSurface must remain a '
            'single render-state entrypoint.',
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
          "import 'interactive_draw_eraser_exact_hit.dart';",
          'InteractiveDrawEraserExactHit(',
          '_exactHit.hitsNode(',
        ],
        bannedTokens: const <String>[
          '_eraserHitsNode(',
          '_eraserHitsLine(',
          '_eraserHitsStroke(',
          '_projectEraserToLocal(',
          '_fallbackWorldBoundsHit(',
          '_localEraserSegmentsHitLine(',
          '_eraserSegmentHitsStrokeBatch(',
        ],
        message:
            'interactive API violation: InteractiveDrawEraserEngine must '
            'delegate exact-hit geometry to eraser-local owners.',
      ) ??
      _requireSourceTokens(
        source: drawEraserExactHitSource,
        filePath: _interactiveFilePosixPath(context, drawEraserExactHitFile),
        requiredTokens: const <String>[
          "import 'interactive_draw_eraser_line_hit.dart';",
          "import 'interactive_draw_eraser_projection.dart';",
          "import 'interactive_draw_eraser_stroke_hit.dart';",
          'class InteractiveDrawEraserExactHit',
          '_lineHit.hitsProjectedLine(',
          '_strokeHit.hitsProjectedStroke(',
          '_projectEraserToLocal(',
          '_fallbackWorldBoundsHit(',
        ],
        bannedTokens: const <String>[
          '_localEraserSegmentsHitLine(',
          '_eraserSegmentHitsStrokeBatch(',
        ],
        message:
            'interactive API violation: InteractiveDrawEraserExactHit must '
            'own shared dispatch/projection/fallback and delegate focused '
            'geometry bodies.',
      ) ??
      _requireSourceTokens(
        source: drawEraserLineHitSource,
        filePath: _interactiveFilePosixPath(context, drawEraserLineHitFile),
        requiredTokens: const <String>[
          'class InteractiveDrawEraserLineHit',
          'hitsProjectedLine(',
          '_localEraserSegmentsHitLine(',
          'onPreciseSegmentCheck()',
        ],
        bannedTokens: const <String>['_eraserSegmentHitsStrokeBatch('],
        message:
            'interactive API violation: InteractiveDrawEraserLineHit must '
            'remain the focused line exact-hit owner.',
      ) ??
      _requireSourceTokens(
        source: drawEraserStrokeHitSource,
        filePath: _interactiveFilePosixPath(context, drawEraserStrokeHitFile),
        requiredTokens: const <String>[
          'class InteractiveDrawEraserStrokeHit',
          'hitsProjectedStroke(',
          '_eraserSegmentHitsStrokeBatch(',
          'onPreciseSegmentCheck()',
        ],
        bannedTokens: const <String>['_localEraserSegmentsHitLine('],
        message:
            'interactive API violation: InteractiveDrawEraserStrokeHit must '
            'remain the focused stroke exact-hit owner.',
      ) ??
      _requireSourceTokens(
        source: drawEraserProjectionSource,
        filePath: _interactiveFilePosixPath(context, drawEraserProjectionFile),
        requiredTokens: const <String>[
          'typedef InteractiveDrawProjectedEraser = ({',
          'List<Offset> points,',
          'double threshold,',
          'double thresholdSquared,',
        ],
        bannedTokens: const <String>[],
        message:
            'interactive API violation: InteractiveDrawProjectedEraser must '
            'remain the shared eraser exact-hit projection contract.',
      ) ??
      _requireSourceTokens(
        source: drawStyleSource,
        filePath: _interactiveFilePosixPath(context, drawStyleFile),
        requiredTokens: const <String>[
          'typedef InteractiveDrawStyle = ({',
          'DrawTool drawTool,',
          'Color drawColor,',
          'double lineThickness,',
        ],
        bannedTokens: const <String>[],
        message:
            'interactive API violation: InteractiveDrawStyle must remain a '
            'shared interactive-local contract owner.',
      ) ??
      _requireSourceTokens(
        source: internalAccessSource,
        filePath: _interactiveFilePosixPath(context, internalAccessFile),
        requiredTokens: const <String>[
          'registerSceneControllerInternalAccess(',
          'sceneControllerInternalEpoch(',
          'sceneControllerInternalPreviewDeltaForNode(',
          'sceneControllerInternalSetBeforePointerDispatchHook(',
        ],
        bannedTokens: const <String>[
          'SceneViewRuntime',
          'SceneViewPointerSession',
        ],
        message:
            'interactive API violation: internal interactive test/debug access '
            'must remain outside SceneController.',
      );
}

GuardrailViolation? _topLevelFacadeHelperViolation(
  GuardrailContext context, {
  required ParsedUnitResult parsed,
}) {
  for (final declaration in parsed.unit.declarations) {
    if (declaration is FunctionDeclaration) {
      final name = declaration.name.lexeme;
      if (name == 'sceneControllerViewRuntimeOf') {
        continue;
      }
      return GuardrailViolation(
        filePath: _interactiveFilePosixPath(context, _interactiveFile(context)),
        line: lineForOffset(parsed, declaration.offset),
        message:
            'interactive API violation: SceneController facade '
            'file must not own top-level helper functions.',
      );
    }
  }
  return null;
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
  List<RegExp> bannedPatterns = const <RegExp>[],
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
  for (final pattern in bannedPatterns) {
    final match = pattern.firstMatch(source);
    if (match == null) {
      continue;
    }
    final offset = match.start;
    final line = '\n'.allMatches(source.substring(0, offset)).length + 1;
    return GuardrailViolation(filePath: filePath, line: line, message: message);
  }
  return null;
}

GuardrailViolation? _requireTokenOrder({
  required String source,
  required String filePath,
  required List<String> orderedTokens,
  required String message,
  String? scopeRootStart,
  String? methodStart,
  String? blockStart,
}) {
  final maskedSource = _maskNonCodeText(source);
  final scopeRootOffset = scopeRootStart == null
      ? 0
      : _findMaskedTokenOffset(
          maskedSource: maskedSource,
          token: scopeRootStart,
        );
  if (scopeRootOffset < 0) {
    return GuardrailViolation(filePath: filePath, line: 1, message: message);
  }

  final methodScope = methodStart == null
      ? (
          body: source.substring(scopeRootOffset),
          maskedBody: maskedSource.substring(scopeRootOffset),
          bodyStartOffset: scopeRootOffset,
        )
      : _extractMethodBodyScope(
          source: source,
          maskedSource: maskedSource,
          methodStart: methodStart,
          searchStartOffset: scopeRootOffset,
        );
  if (methodScope == null) {
    return GuardrailViolation(
      filePath: filePath,
      line: _lineNumberAtOffset(source: source, offset: scopeRootOffset),
      message: message,
    );
  }

  final scopedSource = blockStart == null
      ? methodScope
      : _extractBlockBodyScope(
          source: methodScope.body,
          maskedSource: methodScope.maskedBody,
          blockStart: blockStart,
          bodyStartOffset: methodScope.bodyStartOffset,
        );
  if (scopedSource == null) {
    return GuardrailViolation(
      filePath: filePath,
      line: _lineNumberAtOffset(
        source: source,
        offset: methodScope.bodyStartOffset,
      ),
      message: message,
    );
  }

  final statements = _extractTopLevelStatements(
    source: scopedSource.maskedBody,
    bodyStartOffset: scopedSource.bodyStartOffset,
  );
  final normalizedTokens = orderedTokens
      .map((token) => _normalizeGuardrailToken(token))
      .toList(growable: false);

  var statementIndex = 0;
  for (final token in normalizedTokens) {
    var matchedIndex = -1;
    for (var i = statementIndex; i < statements.length; i++) {
      if (statements[i].normalized.startsWith(token)) {
        matchedIndex = i;
        break;
      }
    }
    if (matchedIndex < 0) {
      final failureOffset = statementIndex < statements.length
          ? statements[statementIndex].startOffset
          : scopedSource.bodyStartOffset;
      return GuardrailViolation(
        filePath: filePath,
        line: _lineNumberAtOffset(source: source, offset: failureOffset),
        message: message,
      );
    }
    statementIndex = matchedIndex + 1;
  }
  return null;
}

String _normalizeGuardrailToken(String source) =>
    source.replaceAll(RegExp(r'\s+'), ' ').trim();

int _findMaskedTokenOffset({
  required String maskedSource,
  required String token,
  int startOffset = 0,
}) => maskedSource.indexOf(token, startOffset);

int _lineNumberAtOffset({required String source, required int offset}) {
  final safeOffset = offset.clamp(0, source.length);
  return '\n'.allMatches(source.substring(0, safeOffset)).length + 1;
}

String _maskNonCodeText(String source) {
  final masked = source.split('');
  var index = 0;

  while (index < source.length) {
    final stringLiteral = _matchStringLiteralStart(
      source: source,
      index: index,
    );
    if (stringLiteral != null) {
      final start = index;
      index += stringLiteral.openingLength;
      while (index < source.length) {
        if (stringLiteral.triple) {
          if (index + 2 < source.length &&
              source[index] == stringLiteral.quote &&
              source[index + 1] == stringLiteral.quote &&
              source[index + 2] == stringLiteral.quote) {
            index += 3;
            break;
          }
          index += 1;
          continue;
        }
        if (!stringLiteral.raw &&
            source[index] == r'\' &&
            index + 1 < source.length) {
          index += 2;
          continue;
        }
        if (source[index] == stringLiteral.quote) {
          index += 1;
          break;
        }
        index += 1;
      }
      _maskCharacters(masked, start: start, end: index);
      continue;
    }

    if (index + 1 < source.length &&
        source[index] == '/' &&
        source[index + 1] == '/') {
      final start = index;
      index += 2;
      while (index < source.length && source[index] != '\n') {
        index += 1;
      }
      _maskCharacters(masked, start: start, end: index);
      continue;
    }

    if (index + 1 < source.length &&
        source[index] == '/' &&
        source[index + 1] == '*') {
      final start = index;
      index += 2;
      var depth = 1;
      while (index < source.length && depth > 0) {
        if (index + 1 < source.length &&
            source[index] == '/' &&
            source[index + 1] == '*') {
          depth += 1;
          index += 2;
          continue;
        }
        if (index + 1 < source.length &&
            source[index] == '*' &&
            source[index + 1] == '/') {
          depth -= 1;
          index += 2;
          continue;
        }
        index += 1;
      }
      _maskCharacters(masked, start: start, end: index);
      continue;
    }

    index += 1;
  }

  return masked.join();
}

void _maskCharacters(
  List<String> source, {
  required int start,
  required int end,
}) {
  final safeEnd = end > source.length ? source.length : end;
  for (var i = start; i < safeEnd; i++) {
    if (source[i] == '\n' || source[i] == '\r') {
      continue;
    }
    source[i] = ' ';
  }
}

({int openingLength, String quote, bool raw, bool triple})?
_matchStringLiteralStart({required String source, required int index}) {
  final char = source[index];
  if (char == 'r' || char == 'R') {
    if (index + 1 >= source.length) {
      return null;
    }
    final quote = source[index + 1];
    if (quote != "'" && quote != '"') {
      return null;
    }
    final triple =
        index + 3 < source.length &&
        source[index + 2] == quote &&
        source[index + 3] == quote;
    return (
      openingLength: triple ? 4 : 2,
      quote: quote,
      raw: true,
      triple: triple,
    );
  }

  if (char != "'" && char != '"') {
    return null;
  }

  final triple =
      index + 2 < source.length &&
      source[index + 1] == char &&
      source[index + 2] == char;
  return (
    openingLength: triple ? 3 : 1,
    quote: char,
    raw: false,
    triple: triple,
  );
}

({String body, String maskedBody, int bodyStartOffset})?
_extractMethodBodyScope({
  required String source,
  required String maskedSource,
  required String methodStart,
  int searchStartOffset = 0,
}) {
  final startIndex = _findMaskedTokenOffset(
    maskedSource: maskedSource,
    token: methodStart,
    startOffset: searchStartOffset,
  );
  if (startIndex < 0) {
    return null;
  }

  var bodyStart = -1;
  var parenDepth = 0;
  for (var i = startIndex; i < maskedSource.length; i++) {
    final char = maskedSource[i];
    if (char == '(') {
      parenDepth += 1;
    } else if (char == ')') {
      if (parenDepth > 0) {
        parenDepth -= 1;
      }
    } else if (char == '{' && parenDepth == 0) {
      bodyStart = i;
      break;
    }
  }
  if (bodyStart < 0) {
    return null;
  }

  var depth = 1;
  for (var i = bodyStart + 1; i < maskedSource.length; i++) {
    final char = maskedSource[i];
    if (char == '{') {
      depth += 1;
    } else if (char == '}') {
      depth -= 1;
      if (depth == 0) {
        return (
          body: source.substring(bodyStart + 1, i),
          maskedBody: maskedSource.substring(bodyStart + 1, i),
          bodyStartOffset: bodyStart + 1,
        );
      }
    }
  }
  return null;
}

({String body, String maskedBody, int bodyStartOffset})?
_extractBlockBodyScope({
  required String source,
  required String maskedSource,
  required String blockStart,
  required int bodyStartOffset,
}) {
  final startIndex = _findMaskedTokenOffset(
    maskedSource: maskedSource,
    token: blockStart,
  );
  if (startIndex < 0) {
    return null;
  }

  var blockBodyStart = -1;
  var parenDepth = 0;
  for (var i = startIndex; i < maskedSource.length; i++) {
    final char = maskedSource[i];
    if (char == '(') {
      parenDepth += 1;
    } else if (char == ')') {
      if (parenDepth > 0) {
        parenDepth -= 1;
      }
    } else if (char == '{' && parenDepth == 0) {
      blockBodyStart = i;
      break;
    }
  }
  if (blockBodyStart < 0) {
    return null;
  }

  var depth = 1;
  for (var i = blockBodyStart + 1; i < maskedSource.length; i++) {
    final char = maskedSource[i];
    if (char == '{') {
      depth += 1;
    } else if (char == '}') {
      depth -= 1;
      if (depth == 0) {
        return (
          body: source.substring(blockBodyStart + 1, i),
          maskedBody: maskedSource.substring(blockBodyStart + 1, i),
          bodyStartOffset: bodyStartOffset + blockBodyStart + 1,
        );
      }
    }
  }
  return null;
}

List<({String normalized, int startOffset})> _extractTopLevelStatements({
  required String source,
  required int bodyStartOffset,
}) {
  final statements = <({String normalized, int startOffset})>[];
  var statementStart = -1;
  var parenDepth = 0;
  var bracketDepth = 0;
  var braceDepth = 0;

  for (var i = 0; i < source.length; i++) {
    final char = source[i];
    if (braceDepth == 0 && statementStart < 0 && char.trim().isNotEmpty) {
      statementStart = i;
    }

    if (char == '(') {
      parenDepth += 1;
      continue;
    }
    if (char == ')') {
      if (parenDepth > 0) {
        parenDepth -= 1;
      }
      continue;
    }
    if (char == '[') {
      bracketDepth += 1;
      continue;
    }
    if (char == ']') {
      if (bracketDepth > 0) {
        bracketDepth -= 1;
      }
      continue;
    }
    if (char == '{') {
      if (parenDepth == 0 && bracketDepth == 0) {
        braceDepth += 1;
        if (braceDepth == 1) {
          statementStart = -1;
        }
      }
      continue;
    }
    if (char == '}') {
      if (parenDepth == 0 && bracketDepth == 0 && braceDepth > 0) {
        braceDepth -= 1;
      }
      continue;
    }
    if (char == ';' &&
        parenDepth == 0 &&
        bracketDepth == 0 &&
        braceDepth == 0 &&
        statementStart >= 0) {
      final statement = _normalizeGuardrailToken(
        source.substring(statementStart, i + 1),
      );
      if (statement.isNotEmpty) {
        statements.add((
          normalized: statement,
          startOffset: bodyStartOffset + statementStart,
        ));
      }
      statementStart = -1;
    }
  }

  return statements;
}
