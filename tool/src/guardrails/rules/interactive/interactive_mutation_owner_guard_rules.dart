part of 'mutation_boundary_rules.dart';

Future<GuardrailViolation?> _checkMutationOwnerPolicies(
  GuardrailContext context,
) async {
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
    final resolved = await _resolveInteractiveUnitOrFail(
      context: context,
      file: file,
      filePath: filePath,
    );
    final ownerClass = findClassDeclarationByName(
      resolved.unit.declarations,
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
      final member = findMethodDeclarationByName(
        ownerClass.members,
        policy.methodName,
      );
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
        context: context,
        member: member,
        filePath: filePath,
        lineFor: (offset) => _lineForResolvedOffset(resolved, offset),
        className: spec.className,
        policy: policy,
      );
      if (violation != null) {
        return violation;
      }
    }
  }
  return null;
}

GuardrailViolation? _checkMutationOwnerPolicy({
  required GuardrailContext context,
  required MethodDeclaration member,
  required String filePath,
  required int Function(int offset) lineFor,
  required String className,
  required MutationOwnerPolicySpec policy,
}) {
  final body = member.body;
  if (body is! BlockFunctionBody) {
    return _mutationOwnerPolicyViolation(
      filePath: filePath,
      line: lineFor(member.offset),
      className: className,
      methodName: policy.methodName,
      requiredGuard: policy.requiredGuard,
    );
  }

  switch (policy.contractKind) {
    case MutationOwnerContractKind.standardEffectfulRoute:
      return _checkStandardMutationOwnerPolicy(
        context: context,
        body: body,
        member: member,
        filePath: filePath,
        lineFor: lineFor,
        className: className,
        policy: policy,
      );
    case MutationOwnerContractKind.cameraOffsetPreflight:
      return _checkSetCameraOffsetMutationOwnerPolicy(
        context: context,
        body: body,
        member: member,
        filePath: filePath,
        lineFor: lineFor,
        className: className,
        policy: policy,
      );
    case MutationOwnerContractKind.replaceSceneForwarding:
      return _checkReplaceSceneMutationOwnerPolicy(
        context: context,
        body: body,
        member: member,
        filePath: filePath,
        lineFor: lineFor,
        className: className,
        policy: policy,
      );
  }
}

GuardrailViolation? _checkStandardMutationOwnerPolicy({
  required GuardrailContext context,
  required BlockFunctionBody body,
  required MethodDeclaration member,
  required String filePath,
  required int Function(int offset) lineFor,
  required String className,
  required MutationOwnerPolicySpec policy,
}) {
  final events = body.block.statements
      .map(
        (statement) => _classifyMutationOwnerStatement(
          statement: statement,
          context: context,
          filePath: filePath,
          className: className,
          requiredGuard: policy.requiredGuard,
        ),
      )
      .toList(growable: false);
  return evaluateRequiredGuardSequence(
    events: events,
    lineFor: lineFor,
    missingGuardOffset: member.offset,
    violationForLine: (line) => _mutationOwnerPolicyViolation(
      filePath: filePath,
      line: line,
      className: className,
      methodName: policy.methodName,
      requiredGuard: policy.requiredGuard,
    ),
    allowUnsupportedAfterGuard: true,
  );
}

GuardrailViolation? _checkSetCameraOffsetMutationOwnerPolicy({
  required GuardrailContext context,
  required BlockFunctionBody body,
  required MethodDeclaration member,
  required String filePath,
  required int Function(int offset) lineFor,
  required String className,
  required MutationOwnerPolicySpec policy,
}) {
  final events = body.block.statements
      .map(
        (statement) => _classifySetCameraOffsetStatement(
          statement: statement,
          context: context,
          filePath: filePath,
          className: className,
          requiredGuard: policy.requiredGuard,
        ),
      )
      .toList(growable: false);
  return evaluateRequiredGuardSequence(
    events: events,
    lineFor: lineFor,
    missingGuardOffset: member.offset,
    violationForLine: (line) => _mutationOwnerPolicyViolation(
      filePath: filePath,
      line: line,
      className: className,
      methodName: policy.methodName,
      requiredGuard: policy.requiredGuard,
    ),
    allowPurePreludeAfterGuard: false,
    allowBoundaryRouteAfterGuard: false,
    requireEffectfulRouteAfterGuard: true,
  );
}

GuardrailViolation? _checkReplaceSceneMutationOwnerPolicy({
  required GuardrailContext context,
  required BlockFunctionBody body,
  required MethodDeclaration member,
  required String filePath,
  required int Function(int offset) lineFor,
  required String className,
  required MutationOwnerPolicySpec policy,
}) {
  var sawForwarding = false;
  for (final statement in body.block.statements) {
    if (!sawForwarding && isAllowedPurePreludeStatement(statement)) {
      continue;
    }
    if (!sawForwarding &&
        _isAllowedReplaceSceneForwardingStatement(
          statement: statement,
          context: context,
          filePath: filePath,
          className: className,
          requiredGuard: policy.requiredGuard,
        )) {
      sawForwarding = true;
      continue;
    }
    return _mutationOwnerPolicyViolation(
      filePath: filePath,
      line: lineFor(statement.offset),
      className: className,
      methodName: policy.methodName,
      requiredGuard: policy.requiredGuard,
    );
  }
  return sawForwarding
      ? null
      : _mutationOwnerPolicyViolation(
          filePath: filePath,
          line: lineFor(member.offset),
          className: className,
          methodName: policy.methodName,
          requiredGuard: policy.requiredGuard,
        );
}

GuardrailViolation _mutationOwnerPolicyViolation({
  required String filePath,
  required int line,
  required String className,
  required String methodName,
  required String requiredGuard,
}) {
  return _capabilityGuardViolation(
    filePath: filePath,
    line: line,
    detail:
        '$className.$methodName must guard active-gesture exclusivity with '
        '$requiredGuard(...).',
  );
}

SemanticSequenceEvent _classifySetCameraOffsetStatement({
  required Statement statement,
  required GuardrailContext context,
  required String filePath,
  required String className,
  required String requiredGuard,
}) {
  final preflightRoute = _cameraOffsetPreludeRouteForStatement(
    statement: statement,
    context: context,
    filePath: filePath,
    className: className,
  );
  if (preflightRoute != null) {
    return SemanticSequenceEvent(
      kind: SemanticSequenceEventKind.boundaryRoute,
      statement: statement,
    );
  }
  return _classifyMutationOwnerStatement(
    statement: statement,
    context: context,
    filePath: filePath,
    className: className,
    requiredGuard: requiredGuard,
  );
}

SemanticSequenceEvent _classifyMutationOwnerStatement({
  required Statement statement,
  required GuardrailContext context,
  required String filePath,
  required String className,
  required String requiredGuard,
}) {
  if (isAllowedPurePreludeStatement(statement)) {
    return SemanticSequenceEvent(
      kind: SemanticSequenceEventKind.purePrelude,
      statement: statement,
    );
  }
  final boundaryRoute = _mutationBoundaryRouteForStatement(
    statement: statement,
    context: context,
    filePath: filePath,
    className: className,
  );
  if (boundaryRoute != null) {
    return SemanticSequenceEvent(
      kind: boundaryRoute.isEffectful
          ? SemanticSequenceEventKind.effectfulBoundaryRoute
          : SemanticSequenceEventKind.boundaryRoute,
      statement: statement,
    );
  }

  final requiresArguments = requiredGuard != interruptForExternalMutationCall;
  final expression = extractStatementExpression(statement);
  final isRequiredGuard = switch (expression) {
    FunctionExpressionInvocation(:final function, :final argumentList) =>
      _matchesOwnedMutationOwnerCallback(
            element: _expressionElement(function),
            context: context,
            filePath: filePath,
            className: className,
            callbackName: requiredGuard,
          ) &&
          (!requiresArguments || argumentList.arguments.isNotEmpty),
    MethodInvocation(:final target, :final methodName, :final argumentList)
        when target == null =>
      _matchesOwnedMutationOwnerCallback(
            element: methodName.element,
            context: context,
            filePath: filePath,
            className: className,
            callbackName: requiredGuard,
          ) &&
          (!requiresArguments || argumentList.arguments.isNotEmpty),
    _ => false,
  };
  return SemanticSequenceEvent(
    kind: isRequiredGuard
        ? SemanticSequenceEventKind.requiredGuard
        : SemanticSequenceEventKind.unsupported,
    statement: statement,
  );
}

_MutationBoundaryRoute? _mutationBoundaryRouteForStatement({
  required Statement statement,
  required GuardrailContext context,
  required String filePath,
  required String className,
}) {
  final expression = extractStatementExpression(statement);
  if (expression is! MethodInvocation) {
    return null;
  }
  final routeKind = _mutationBoundaryRouteKindForMethodName(
    expression.methodName.name,
  );
  if (routeKind == null) {
    return null;
  }
  return _matchesOwnedFieldReference(
        element: _expressionElement(expression.target),
        context: context,
        filePath: filePath,
        ownerName: className,
        fieldName: 'mutations',
      )
      ? _MutationBoundaryRoute(
          methodName: expression.methodName.name,
          isEffectful:
              routeKind == _MutationBoundaryRouteKind.effectfulBoundaryRoute,
        )
      : null;
}

_MutationBoundaryRoute? _cameraOffsetPreludeRouteForStatement({
  required Statement statement,
  required GuardrailContext context,
  required String filePath,
  required String className,
}) {
  final route = _mutationBoundaryRouteForStatement(
    statement: statement,
    context: context,
    filePath: filePath,
    className: className,
  );
  if (route != null && route.methodName == 'validateCameraOffset') {
    return route;
  }
  return switch (statement) {
    IfStatement(:final expression, :final thenStatement, :final elseStatement)
        when elseStatement == null &&
            _isCameraOffsetShouldApplyGuardExpression(
              expression: expression,
              context: context,
              filePath: filePath,
              className: className,
            ) &&
            _isEarlyReturnShortCircuitStatement(thenStatement) =>
      const _MutationBoundaryRoute(
        methodName: 'shouldApplyCameraOffset',
        isEffectful: false,
      ),
    _ => null,
  };
}

bool _isAllowedReplaceSceneForwardingStatement({
  required Statement statement,
  required GuardrailContext context,
  required String filePath,
  required String className,
  required String requiredGuard,
}) {
  final expression = extractStatementExpression(statement);
  if (expression is! MethodInvocation ||
      expression.methodName.name != 'replaceScene' ||
      !_matchesOwnedFieldReference(
        element: _expressionElement(expression.target),
        context: context,
        filePath: filePath,
        ownerName: className,
        fieldName: 'mutations',
      )) {
    return false;
  }
  return hasNamedArgumentMatching(
    invocation: expression,
    argumentName: 'interruptBeforeApply',
    matchesExpression: (argumentExpression) =>
        _matchesDirectOwnedMutationOwnerCallbackReference(
          expression: argumentExpression,
          context: context,
          filePath: filePath,
          className: className,
          callbackName: requiredGuard,
        ),
  );
}

bool _isEarlyReturnShortCircuitStatement(Statement statement) {
  if (statement case ReturnStatement(:final expression)) {
    return expression == null;
  }
  if (statement case Block(:final statements)) {
    if (statements.length != 1) {
      return false;
    }
    final onlyStatement = statements.single;
    return onlyStatement is ReturnStatement && onlyStatement.expression == null;
  }
  return false;
}

bool _isCameraOffsetShouldApplyGuardExpression({
  required Expression expression,
  required GuardrailContext context,
  required String filePath,
  required String className,
}) {
  final unparenthesized = expression.unParenthesized;
  if (unparenthesized is! PrefixExpression ||
      unparenthesized.operator.lexeme != '!') {
    return false;
  }
  final operand = unparenthesized.operand.unParenthesized;
  return operand is MethodInvocation &&
      operand.methodName.name == 'shouldApplyCameraOffset' &&
      _matchesOwnedFieldReference(
        element: _expressionElement(operand.target),
        context: context,
        filePath: filePath,
        ownerName: className,
        fieldName: 'mutations',
      );
}

bool _matchesOwnedMutationOwnerCallback({
  required Element? element,
  required GuardrailContext context,
  required String filePath,
  required String className,
  required String callbackName,
}) {
  return _matchesOwnedFieldReference(
        element: element,
        context: context,
        filePath: filePath,
        ownerName: className,
        fieldName: callbackName,
      ) ||
      _matchesOwnedMethod(
        element: element,
        context: context,
        filePath: filePath,
        ownerName: className,
        elementName: callbackName,
      );
}

bool _matchesDirectOwnedMutationOwnerCallbackReference({
  required Expression expression,
  required GuardrailContext context,
  required String filePath,
  required String className,
  required String callbackName,
}) {
  return _matchesOwnedMutationOwnerCallback(
    element: _expressionElement(expression),
    context: context,
    filePath: filePath,
    className: className,
    callbackName: callbackName,
  );
}

_MutationBoundaryRouteKind? _mutationBoundaryRouteKindForMethodName(
  String methodName,
) {
  return switch (methodName) {
    'validateCameraOffset' =>
      _MutationBoundaryRouteKind.nonEffectfulBoundaryRoute,
    'write' ||
    'setBackgroundColor' ||
    'setGridEnabled' ||
    'setGridCellSize' ||
    'addNode' ||
    'ensureLayer' ||
    'patchNode' ||
    'removeNode' ||
    'clearScene' ||
    'setSelection' ||
    'toggleSelection' ||
    'clearSelection' ||
    'selectAll' ||
    'rotateSelection' ||
    'flipSelectionVertical' ||
    'flipSelectionHorizontal' ||
    'deleteSelection' ||
    'setCameraOffset' ||
    'replaceScene' => _MutationBoundaryRouteKind.effectfulBoundaryRoute,
    _ => null,
  };
}

final class _MutationBoundaryRoute {
  const _MutationBoundaryRoute({
    required this.methodName,
    required this.isEffectful,
  });

  final String methodName;
  final bool isEffectful;
}

enum _MutationBoundaryRouteKind {
  nonEffectfulBoundaryRoute,
  effectfulBoundaryRoute,
}
