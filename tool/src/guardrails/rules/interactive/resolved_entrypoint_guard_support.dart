part of 'mutation_boundary_rules.dart';

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
