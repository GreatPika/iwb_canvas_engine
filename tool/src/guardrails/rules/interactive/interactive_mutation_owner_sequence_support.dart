part of 'mutation_boundary_rules.dart';

GuardrailViolation? _evaluateMutationOwnerGuardedSequence({
  required List<_MutationOwnerSemanticEvent> events,
  required String filePath,
  required int Function(int offset) lineFor,
  required int missingGuardOffset,
  required String className,
  required String methodName,
  required String requiredGuard,
}) {
  var sawRequiredGuard = false;
  for (final event in events) {
    switch (event.kind) {
      case _MutationOwnerEventKind.purePrelude:
      case _MutationOwnerEventKind.boundaryRoute:
        continue;
      case _MutationOwnerEventKind.requiredGuard:
        sawRequiredGuard = true;
        continue;
      case _MutationOwnerEventKind.effectfulBoundaryRoute:
        if (sawRequiredGuard) {
          return null;
        }
        return _mutationOwnerPolicyViolation(
          filePath: filePath,
          line: lineFor(event.statement.offset),
          className: className,
          methodName: methodName,
          requiredGuard: requiredGuard,
        );
      case _MutationOwnerEventKind.unsupported:
        if (sawRequiredGuard) {
          continue;
        }
        return _mutationOwnerPolicyViolation(
          filePath: filePath,
          line: lineFor(event.statement.offset),
          className: className,
          methodName: methodName,
          requiredGuard: requiredGuard,
        );
    }
  }
  return sawRequiredGuard
      ? null
      : _mutationOwnerPolicyViolation(
          filePath: filePath,
          line: lineFor(missingGuardOffset),
          className: className,
          methodName: methodName,
          requiredGuard: requiredGuard,
        );
}

GuardrailViolation? _evaluateSetCameraOffsetSequence({
  required List<_MutationOwnerSemanticEvent> events,
  required String filePath,
  required int Function(int offset) lineFor,
  required int missingGuardOffset,
  required String className,
  required String methodName,
  required String requiredGuard,
}) {
  var sawRequiredGuard = false;
  for (final event in events) {
    switch (event.kind) {
      case _MutationOwnerEventKind.purePrelude:
      case _MutationOwnerEventKind.boundaryRoute:
        if (!sawRequiredGuard) {
          continue;
        }
        return _mutationOwnerPolicyViolation(
          filePath: filePath,
          line: lineFor(event.statement.offset),
          className: className,
          methodName: methodName,
          requiredGuard: requiredGuard,
        );
      case _MutationOwnerEventKind.requiredGuard:
        sawRequiredGuard = true;
        continue;
      case _MutationOwnerEventKind.effectfulBoundaryRoute:
        if (sawRequiredGuard) {
          return null;
        }
        return _mutationOwnerPolicyViolation(
          filePath: filePath,
          line: lineFor(event.statement.offset),
          className: className,
          methodName: methodName,
          requiredGuard: requiredGuard,
        );
      case _MutationOwnerEventKind.unsupported:
        return _mutationOwnerPolicyViolation(
          filePath: filePath,
          line: lineFor(event.statement.offset),
          className: className,
          methodName: methodName,
          requiredGuard: requiredGuard,
        );
    }
  }
  return _mutationOwnerPolicyViolation(
    filePath: filePath,
    line: lineFor(missingGuardOffset),
    className: className,
    methodName: methodName,
    requiredGuard: requiredGuard,
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

_MutationOwnerSemanticEvent _classifySetCameraOffsetStatement({
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
    return _MutationOwnerSemanticEvent(
      kind: _MutationOwnerEventKind.boundaryRoute,
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

_MutationOwnerSemanticEvent _classifyMutationOwnerStatement({
  required Statement statement,
  required GuardrailContext context,
  required String filePath,
  required String className,
  required String requiredGuard,
}) {
  if (_isAllowedPurePreGuardStatement(statement)) {
    return _MutationOwnerSemanticEvent(
      kind: _MutationOwnerEventKind.purePrelude,
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
    return _MutationOwnerSemanticEvent(
      kind: boundaryRoute.isEffectful
          ? _MutationOwnerEventKind.effectfulBoundaryRoute
          : _MutationOwnerEventKind.boundaryRoute,
      statement: statement,
    );
  }

  final requiresArguments = requiredGuard != interruptForExternalMutationCall;
  final expression = switch (statement) {
    ExpressionStatement(:final expression) => expression,
    ReturnStatement(:final expression?) => expression,
    _ => null,
  };
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
  return _MutationOwnerSemanticEvent(
    kind: isRequiredGuard
        ? _MutationOwnerEventKind.requiredGuard
        : _MutationOwnerEventKind.unsupported,
    statement: statement,
  );
}

_MutationBoundaryRoute? _mutationBoundaryRouteForStatement({
  required Statement statement,
  required GuardrailContext context,
  required String filePath,
  required String className,
}) {
  final expression = switch (statement) {
    ExpressionStatement(:final expression) => expression,
    ReturnStatement(:final expression?) => expression,
    _ => null,
  };
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
  final expression = switch (statement) {
    ExpressionStatement(:final expression) => expression,
    ReturnStatement(:final expression?) => expression,
    _ => null,
  };
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
  for (final argument in expression.argumentList.arguments) {
    if (argument case NamedExpression(
      :final name,
      :final expression,
    ) when name.label.name == 'interruptBeforeApply') {
      return _matchesDirectOwnedMutationOwnerCallbackReference(
        expression: expression,
        context: context,
        filePath: filePath,
        className: className,
        callbackName: requiredGuard,
      );
    }
  }
  return false;
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

enum _MutationOwnerEventKind {
  purePrelude,
  requiredGuard,
  boundaryRoute,
  effectfulBoundaryRoute,
  unsupported,
}

final class _MutationOwnerSemanticEvent {
  const _MutationOwnerSemanticEvent({
    required this.kind,
    required this.statement,
  });

  final _MutationOwnerEventKind kind;
  final Statement statement;
}
