part of 'mutation_boundary_rules.dart';

const String _sceneControllerFilePath =
    '/lib/src/interactive/scene_controller.dart';
const String _interactionRuntimeFilePath =
    '/lib/src/interactive/internal/scene_controller_interaction_runtime.dart';

const Set<String> _boolBinaryOperators = <String>{'&&', '||'};
const Set<String> _comparisonBinaryOperators = <String>{
  '==',
  '!=',
  '<',
  '<=',
  '>',
  '>=',
};
const Set<String> _numericBinaryOperators = <String>{
  '+',
  '-',
  '*',
  '/',
  '~/',
  '%',
};

class EnsureCallInfo {
  const EnsureCallInfo({required this.hasAllowAfterDispose});

  final bool hasAllowAfterDispose;
}

final class _EntrypointGuardScanResult {
  const _EntrypointGuardScanResult({
    required this.ensureCallInfo,
    required this.guardLine,
    required this.violation,
  });

  final EnsureCallInfo? ensureCallInfo;
  final int? guardLine;
  final GuardrailViolation? violation;
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
  final scan = _scanEntrypointGuard(
    body: member.body,
    filePath: filePath,
    lineFor: lineFor,
    missingGuardViolation: (line) =>
        _interactiveGuardViolation(filePath: filePath, line: line),
    missingBlockBodyDetail:
        'public SceneController entrypoint "${member.name.lexeme}" must use '
        'a block body guarded by _ensurePublicSideEffectAllowed(...).',
    resolveGuardInfo: (expression) =>
        _resolveRootEnsureCallInfo(expression: expression, context: context),
  );
  if (scan.violation != null) {
    return scan.violation;
  }

  return _validateEnsureCall(
    ensureCallInfo: scan.ensureCallInfo,
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

_EntrypointGuardScanResult _scanEntrypointGuard({
  required FunctionBody body,
  required String filePath,
  required int Function(int offset) lineFor,
  required GuardrailViolation Function(int line) missingGuardViolation,
  required String missingBlockBodyDetail,
  required EnsureCallInfo? Function(Expression expression) resolveGuardInfo,
}) {
  if (body is! BlockFunctionBody) {
    return _EntrypointGuardScanResult(
      ensureCallInfo: null,
      guardLine: null,
      violation: _capabilityGuardViolation(
        filePath: filePath,
        line: lineFor(body.offset),
        detail: missingBlockBodyDetail,
      ),
    );
  }

  for (final statement in body.block.statements) {
    if (statement is ExpressionStatement) {
      final ensureCallInfo = resolveGuardInfo(statement.expression);
      if (ensureCallInfo != null) {
        return _EntrypointGuardScanResult(
          ensureCallInfo: ensureCallInfo,
          guardLine: lineFor(statement.offset),
          violation: null,
        );
      }
    }

    if (!_isAllowedPurePreGuardStatement(statement)) {
      return _EntrypointGuardScanResult(
        ensureCallInfo: null,
        guardLine: null,
        violation: missingGuardViolation(lineFor(statement.offset)),
      );
    }
  }

  return _EntrypointGuardScanResult(
    ensureCallInfo: null,
    guardLine: null,
    violation: missingGuardViolation(lineFor(body.offset)),
  );
}

bool _isAllowedPurePreGuardStatement(Statement statement) {
  return switch (statement) {
    EmptyStatement() => true,
    AssertStatement(:final condition, :final message?) =>
      _isPurePreGuardExpression(condition) &&
          _isPurePreGuardExpression(message),
    AssertStatement(:final condition) => _isPurePreGuardExpression(condition),
    VariableDeclarationStatement(:final variables) => variables.variables.every(
      (variable) => _isPurePreGuardExpression(variable.initializer),
    ),
    ReturnStatement(:final expression?) => _isPurePreGuardExpression(
      expression,
    ),
    ReturnStatement() => true,
    IfStatement(
      :final expression,
      :final thenStatement,
      :final elseStatement?,
    ) =>
      _isPurePreGuardExpression(expression) &&
          _isAllowedPureBranchStatement(thenStatement) &&
          _isAllowedPureBranchStatement(elseStatement),
    IfStatement(:final expression, :final thenStatement) =>
      _isPurePreGuardExpression(expression) &&
          _isAllowedPureBranchStatement(thenStatement),
    Block(:final statements) => statements.every(_isAllowedPureBranchStatement),
    _ => false,
  };
}

bool _isAllowedPureBranchStatement(Statement? statement) {
  if (statement == null) {
    return true;
  }
  return switch (statement) {
    Block(:final statements) => statements.every(_isAllowedPureBranchStatement),
    ReturnStatement(:final expression?) => _isPurePreGuardExpression(
      expression,
    ),
    ReturnStatement() => true,
    EmptyStatement() => true,
    AssertStatement(:final condition, :final message?) =>
      _isPurePreGuardExpression(condition) &&
          _isPurePreGuardExpression(message),
    AssertStatement(:final condition) => _isPurePreGuardExpression(condition),
    _ => false,
  };
}

bool _isPurePreGuardExpression(Expression? expression) {
  if (expression == null) {
    return true;
  }
  final unparenthesized = expression.unParenthesized;
  return switch (unparenthesized) {
    AdjacentStrings() => true,
    BooleanLiteral() => true,
    DoubleLiteral() => true,
    IntegerLiteral() => true,
    NullLiteral() => true,
    SimpleStringLiteral() => true,
    SimpleIdentifier() => _isAllowedPureReference(unparenthesized.element),
    NamedExpression(:final expression) => _isPurePreGuardExpression(expression),
    ConditionalExpression(
      :final condition,
      :final thenExpression,
      :final elseExpression,
    ) =>
      _isStaticallyKnownBool(condition) &&
          _isPurePreGuardExpression(condition) &&
          _isPurePreGuardExpression(thenExpression) &&
          _isPurePreGuardExpression(elseExpression),
    BinaryExpression(
      :final operator,
      :final leftOperand,
      :final rightOperand,
    ) =>
      _isAllowedPureBinaryExpression(
        operator: operator.lexeme,
        leftOperand: leftOperand,
        rightOperand: rightOperand,
      ),
    PrefixExpression(:final operator, :final operand) =>
      _isAllowedPurePrefixExpression(operator.lexeme, operand),
    AsExpression(:final expression) => _isPurePreGuardExpression(expression),
    IsExpression(:final expression) => _isPurePreGuardExpression(expression),
    StringInterpolation(:final elements) =>
      elements.whereType<InterpolationExpression>().every(
        (interpolation) =>
            _isPurePreGuardExpression(interpolation.expression) &&
            _isStaticallyKnownScalar(interpolation.expression.staticType),
      ),
    _ => false,
  };
}

bool _isAllowedPureReference(Element? element) {
  return switch (element) {
    LocalVariableElement() => true,
    FormalParameterElement() => true,
    _ => false,
  };
}

bool _isAllowedPureBinaryExpression({
  required String operator,
  required Expression leftOperand,
  required Expression rightOperand,
}) {
  if (!_isPurePreGuardExpression(leftOperand) ||
      !_isPurePreGuardExpression(rightOperand)) {
    return false;
  }
  if (_boolBinaryOperators.contains(operator)) {
    return _isStaticallyKnownBool(leftOperand) &&
        _isStaticallyKnownBool(rightOperand);
  }
  if (_comparisonBinaryOperators.contains(operator)) {
    if ((operator == '==' || operator == '!=') &&
        (leftOperand.unParenthesized is NullLiteral ||
            rightOperand.unParenthesized is NullLiteral)) {
      return true;
    }
    return _isStaticallyKnownScalar(leftOperand.staticType) &&
        _isStaticallyKnownScalar(rightOperand.staticType);
  }
  if (_numericBinaryOperators.contains(operator)) {
    return _isStaticallyKnownNum(leftOperand) &&
        _isStaticallyKnownNum(rightOperand);
  }
  return false;
}

bool _isAllowedPurePrefixExpression(String operator, Expression operand) {
  if (!_isPurePreGuardExpression(operand)) {
    return false;
  }
  return switch (operator) {
    '!' => _isStaticallyKnownBool(operand),
    '-' || '+' => _isStaticallyKnownNum(operand),
    _ => false,
  };
}

bool _isStaticallyKnownBool(Expression expression) {
  return _normalizedTypeOf(expression)?.isDartCoreBool ?? false;
}

bool _isStaticallyKnownNum(Expression expression) {
  final type = _normalizedTypeOf(expression);
  return _isCoreInterfaceType(type, 'int') ||
      _isCoreInterfaceType(type, 'double') ||
      _isCoreInterfaceType(type, 'num');
}

bool _isStaticallyKnownScalar(DartType? type) {
  if (type == null) {
    return false;
  }
  return _isCoreInterfaceType(type, 'bool') ||
      _isCoreInterfaceType(type, 'double') ||
      _isCoreInterfaceType(type, 'int') ||
      _isCoreInterfaceType(type, 'num') ||
      _isCoreInterfaceType(type, 'String');
}

DartType? _normalizedTypeOf(Expression expression) {
  final type = expression.staticType;
  return type is TypeParameterType ? type.bound : type;
}

bool _isCoreInterfaceType(DartType? type, String name) {
  if (type == null) {
    return false;
  }
  final normalized = type is TypeParameterType ? type.bound : type;
  return switch (normalized) {
    InterfaceType(:final element)
        when element.name == name && element.library.isDartCore =>
      true,
    _ => false,
  };
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
  final scan = _scanEntrypointGuard(
    body: member.body,
    filePath: filePath,
    lineFor: lineFor,
    missingGuardViolation: (line) => _capabilityGuardViolation(
      filePath: filePath,
      line: line,
      detail:
          'public $className entrypoints must guard resolver purity with '
          '$primaryGuardCall(...).',
    ),
    missingBlockBodyDetail:
        'public $className entrypoints must use a block body guarded by '
        '$primaryGuardCall(...).',
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

  if (expression is FunctionExpressionInvocation &&
      className == 'SceneControllerSceneOwner') {
    return _matchesOwnedFieldReference(
          element: _expressionElement(expression.function),
          context: context,
          filePath: filePath,
          ownerName: className,
          fieldName: 'ensurePublicSideEffectAllowed',
        )
        ? const EnsureCallInfo(hasAllowAfterDispose: false)
        : null;
  }

  return null;
}

bool _matchesOwnedAccessRuntimeTarget({
  required Expression? target,
  required GuardrailContext context,
  required String filePath,
  required String ownerName,
}) {
  final rootTarget = switch (target?.unParenthesized) {
    PropertyAccess(:final target?, :final propertyName) => (
      root: _expressionElement(target),
      propertyName: propertyName.name,
    ),
    PrefixedIdentifier(:final prefix, :final identifier) => (
      root: prefix.element,
      propertyName: identifier.name,
    ),
    _ => null,
  };
  if (rootTarget == null) {
    return false;
  }
  return _matchesOwnedFieldReference(
        element: rootTarget.root,
        context: context,
        filePath: filePath,
        ownerName: ownerName,
        fieldName: '_access',
      ) &&
      rootTarget.propertyName == 'runtime';
}

Future<ResolvedUnitResult> _resolveInteractiveUnitOrFail({
  required GuardrailContext context,
  required File file,
  required String filePath,
}) async {
  final resolved = await context.getResolvedUnitResult(file.absolute.path);
  if (resolved != null) {
    return resolved;
  }
  throw GuardrailToolFailure(
    GuardrailViolation(
      filePath: filePath,
      line: 1,
      message: 'tool failure: unable to resolve Dart unit (result: null)',
    ),
  );
}

int _lineForResolvedOffset(ResolvedUnitResult resolved, int offset) {
  return resolved.lineInfo.getLocation(offset).lineNumber;
}

bool _matchesOwnedMethod({
  required Element? element,
  required GuardrailContext context,
  required String filePath,
  required String ownerName,
  required String elementName,
}) {
  final normalizedElement = switch (element) {
    PropertyAccessorElement(:final variable) => variable,
    _ => element,
  };
  if (normalizedElement == null ||
      normalizedElement.displayName != elementName) {
    return false;
  }
  if (normalizedElement.enclosingElement?.displayName != ownerName) {
    return false;
  }
  return element_utils.repoRelPathForElement(
        element: normalizedElement,
        context: context,
      ) ==
      filePath;
}

bool _matchesOwnedFieldReference({
  required Element? element,
  required GuardrailContext context,
  required String filePath,
  required String ownerName,
  required String fieldName,
}) {
  final Element? normalizedElement = switch (element) {
    FieldElement() => element,
    PropertyAccessorElement(:final variable, isSynthetic: true)
        when variable is FieldElement =>
      variable,
    PropertyAccessorElement() => element,
    _ => null,
  };
  if (normalizedElement == null || normalizedElement.displayName != fieldName) {
    return false;
  }
  if (normalizedElement.enclosingElement?.displayName != ownerName) {
    return false;
  }
  return element_utils.repoRelPathForElement(
        element: normalizedElement,
        context: context,
      ) ==
      filePath;
}

bool _matchesOwnedElement({
  required Element? element,
  required GuardrailContext context,
  required String filePath,
  required String ownerName,
  required String elementName,
}) {
  final normalizedElement = _normalizeOwnedElement(element);
  if (normalizedElement == null ||
      normalizedElement.displayName != elementName) {
    return false;
  }
  if (normalizedElement.enclosingElement?.displayName != ownerName) {
    return false;
  }
  return element_utils.repoRelPathForElement(
        element: normalizedElement,
        context: context,
      ) ==
      filePath;
}

Element? _normalizeOwnedElement(Element? element) {
  if (element is PropertyAccessorElement) {
    if (element.isSynthetic) {
      return element.variable;
    }
    return element;
  }
  return element;
}

Element? _expressionElement(Expression? expression) {
  if (expression == null) {
    return null;
  }
  return switch (expression.unParenthesized) {
    SimpleIdentifier(:final element) => element,
    PrefixedIdentifier(:final identifier) => identifier.element,
    PropertyAccess(:final propertyName) => propertyName.element,
    _ => null,
  };
}
