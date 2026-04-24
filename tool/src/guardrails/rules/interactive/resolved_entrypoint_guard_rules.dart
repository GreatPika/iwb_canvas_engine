part of 'mutation_boundary_rules.dart';

const String _sceneControllerFilePath =
    '/lib/src/interactive/scene_controller.dart';
const String _interactionRuntimeFilePath =
    '/lib/src/interactive/internal/scene_controller_interaction_runtime.dart';

class EnsureCallInfo {
  const EnsureCallInfo({required this.hasAllowAfterDispose});

  final bool hasAllowAfterDispose;
}

Future<GuardrailViolation?> _checkRootEntrypoints(
  GuardrailContext context, {
  required File file,
  required String filePath,
}) async {
  final resolved = await _resolveInteractiveUnitOrFail(
    context: context,
    file: file,
    filePath: filePath,
  );
  final interactiveClass = _findInteractiveClass(resolved.unit.declarations);
  if (interactiveClass == null) {
    return null;
  }

  for (final member in interactiveClass.members) {
    final name = _publicEntrypointName(member);
    if (name == null) {
      continue;
    }
    final violation = _checkInteractiveEntrypointGuard(
      context: context,
      member: member as MethodDeclaration,
      name: name,
      filePath: filePath,
      lineFor: (offset) => _lineForResolvedOffset(resolved, offset),
    );
    if (violation != null) {
      return violation;
    }
  }
  return null;
}

GuardrailViolation? _checkInteractiveEntrypointGuard({
  required GuardrailContext context,
  required MethodDeclaration member,
  required String name,
  required String filePath,
  required int Function(int offset) lineFor,
}) {
  final scan = scanEntrypointGuard<EnsureCallInfo>(
    body: member.body,
    lineFor: lineFor,
    missingGuardViolation: (line) =>
        _interactiveGuardViolation(filePath: filePath, line: line),
    missingBlockBodyViolation: (line) => _capabilityGuardViolation(
      filePath: filePath,
      line: line,
      detail:
          'public SceneController entrypoint "${member.name.lexeme}" must use '
          'a block body guarded by _ensurePublicSideEffectAllowed(...).',
    ),
    resolveGuardInfo: (expression) =>
        _resolveRootEnsureCallInfo(expression: expression, context: context),
  );
  if (scan.violation != null) {
    return scan.violation;
  }

  return _validateEnsureCall(
    ensureCallInfo: scan.guardInfo,
    name: name,
    filePath: filePath,
    line: scan.guardLine ?? lineFor(member.offset),
  );
}

EnsureCallInfo? _resolveRootEnsureCallInfo({
  required Expression expression,
  required GuardrailContext context,
}) {
  final ensureCallInfo = _ensureCallInfoFromExpression(expression);
  if (ensureCallInfo == null || expression is! MethodInvocation) {
    return null;
  }
  return _matchesOwnedElement(
        element: expression.methodName.element,
        context: context,
        filePath: _sceneControllerFilePath,
        ownerName: 'SceneController',
        elementName: '_ensurePublicSideEffectAllowed',
      )
      ? ensureCallInfo
      : null;
}

Future<GuardrailViolation?> _checkCapabilityEntrypoints(
  GuardrailContext context,
) async {
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
    final resolved = await _resolveInteractiveUnitOrFail(
      context: context,
      file: file,
      filePath: filePath,
    );
    final capabilityClass = _findClassByName(
      resolved.unit.declarations,
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
        context: context,
        member: member as MethodDeclaration,
        filePath: filePath,
        lineFor: (offset) => _lineForResolvedOffset(resolved, offset),
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

GuardrailViolation? _checkCapabilityEntrypointGuard({
  required GuardrailContext context,
  required MethodDeclaration member,
  required String filePath,
  required int Function(int offset) lineFor,
  required String className,
  required String name,
  required String primaryGuardCall,
  required String? secondaryGuardCall,
}) {
  final scan = scanEntrypointGuard<EnsureCallInfo>(
    body: member.body,
    lineFor: lineFor,
    missingGuardViolation: (line) => _capabilityGuardViolation(
      filePath: filePath,
      line: line,
      detail:
          'public $className entrypoints must guard resolver purity with '
          '$primaryGuardCall(...).',
    ),
    missingBlockBodyViolation: (line) => _capabilityGuardViolation(
      filePath: filePath,
      line: line,
      detail:
          'public $className entrypoints must use a block body guarded by '
          '$primaryGuardCall(...).',
    ),
    resolveGuardInfo: (expression) => _resolveCapabilityEnsureCallInfo(
      expression: expression,
      context: context,
      filePath: filePath,
      className: className,
    ),
  );
  if (scan.violation != null) {
    return scan.violation;
  }

  if (secondaryGuardCall == null) {
    return null;
  }

  final body = member.body;
  if (body is! BlockFunctionBody) {
    return null;
  }
  final statements = body.block.statements;
  if (statements.length < 2) {
    return _capabilityGuardViolation(
      filePath: filePath,
      line: lineFor(member.offset),
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

EnsureCallInfo? _resolveCapabilityEnsureCallInfo({
  required Expression expression,
  required GuardrailContext context,
  required String filePath,
  required String className,
}) {
  if (expression is MethodInvocation) {
    switch (className) {
      case 'SceneControllerInteractionOwner':
        return _matchesOwnedMethod(
                  element: expression.methodName.element,
                  context: context,
                  filePath: _interactionRuntimeFilePath,
                  ownerName: 'SceneControllerInteractionRuntime',
                  elementName: 'ensurePublicSideEffectAllowed',
                ) &&
                _matchesOwnedAccessRuntimeTarget(
                  target: expression.target,
                  context: context,
                  filePath: filePath,
                  ownerName: className,
                )
            ? const EnsureCallInfo(hasAllowAfterDispose: false)
            : null;
      case 'SceneControllerSelectionOwner':
      case 'SceneControllerSceneOwner':
        return _matchesOwnedMethod(
                  element: expression.methodName.element,
                  context: context,
                  filePath: _interactionRuntimeFilePath,
                  ownerName: 'SceneControllerInteractionRuntime',
                  elementName: 'ensurePublicSideEffectAllowed',
                ) &&
                _matchesOwnedFieldReference(
                  element: _expressionElement(expression.target),
                  context: context,
                  filePath: filePath,
                  ownerName: className,
                  fieldName: '_runtime',
                )
            ? const EnsureCallInfo(hasAllowAfterDispose: false)
            : null;
      default:
        break;
    }
  }

  return null;
}
