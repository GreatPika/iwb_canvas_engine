import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import 'guardrail_violation.dart';

enum SemanticSequenceEventKind {
  purePrelude,
  requiredGuard,
  boundaryRoute,
  effectfulBoundaryRoute,
  unsupported,
}

final class SemanticSequenceEvent {
  const SemanticSequenceEvent({required this.kind, required this.statement});

  final SemanticSequenceEventKind kind;
  final Statement statement;
}

final class EntrypointGuardScanResult<T> {
  const EntrypointGuardScanResult({
    required this.guardInfo,
    required this.guardLine,
    required this.violation,
  });

  final T? guardInfo;
  final int? guardLine;
  final GuardrailViolation? violation;
}

final class DirectInvocationRoutingAnalysis {
  const DirectInvocationRoutingAnalysis({
    required this.hasCanonicalRoute,
    required this.hasForbiddenSinkAccess,
  });

  final bool hasCanonicalRoute;
  final bool hasForbiddenSinkAccess;
}

typedef GuardInfoResolver<T> = T? Function(Expression expression);
typedef GuardrailViolationForLine = GuardrailViolation Function(int line);

EntrypointGuardScanResult<T> scanEntrypointGuard<T>({
  required FunctionBody body,
  required int Function(int offset) lineFor,
  required GuardrailViolationForLine missingGuardViolation,
  required GuardrailViolation Function(int line) missingBlockBodyViolation,
  required GuardInfoResolver<T> resolveGuardInfo,
}) {
  if (body is! BlockFunctionBody) {
    return EntrypointGuardScanResult<T>(
      guardInfo: null,
      guardLine: null,
      violation: missingBlockBodyViolation(lineFor(body.offset)),
    );
  }

  for (final statement in body.block.statements) {
    final expression = extractExpressionStatement(statement);
    if (expression != null) {
      final guardInfo = resolveGuardInfo(expression);
      if (guardInfo != null) {
        return EntrypointGuardScanResult<T>(
          guardInfo: guardInfo,
          guardLine: lineFor(statement.offset),
          violation: null,
        );
      }
    }

    if (!isAllowedPurePreludeStatement(statement)) {
      return EntrypointGuardScanResult<T>(
        guardInfo: null,
        guardLine: null,
        violation: missingGuardViolation(lineFor(statement.offset)),
      );
    }
  }

  return EntrypointGuardScanResult<T>(
    guardInfo: null,
    guardLine: null,
    violation: missingGuardViolation(lineFor(body.offset)),
  );
}

GuardrailViolation? evaluateRequiredGuardSequence({
  required List<SemanticSequenceEvent> events,
  required int Function(int offset) lineFor,
  required int missingGuardOffset,
  required GuardrailViolationForLine violationForLine,
  bool allowPurePreludeAfterGuard = true,
  bool allowBoundaryRouteAfterGuard = true,
  bool allowUnsupportedAfterGuard = false,
  bool requireEffectfulRouteAfterGuard = false,
}) {
  var sawRequiredGuard = false;
  var sawEffectfulRouteAfterGuard = false;
  for (final event in events) {
    switch (event.kind) {
      case SemanticSequenceEventKind.purePrelude:
        if (!sawRequiredGuard || allowPurePreludeAfterGuard) {
          continue;
        }
        return violationForLine(lineFor(event.statement.offset));
      case SemanticSequenceEventKind.boundaryRoute:
        if (!sawRequiredGuard || allowBoundaryRouteAfterGuard) {
          continue;
        }
        return violationForLine(lineFor(event.statement.offset));
      case SemanticSequenceEventKind.requiredGuard:
        sawRequiredGuard = true;
        continue;
      case SemanticSequenceEventKind.effectfulBoundaryRoute:
        if (!sawRequiredGuard) {
          return violationForLine(lineFor(event.statement.offset));
        }
        sawEffectfulRouteAfterGuard = true;
        return null;
      case SemanticSequenceEventKind.unsupported:
        if (sawRequiredGuard && allowUnsupportedAfterGuard) {
          continue;
        }
        return violationForLine(lineFor(event.statement.offset));
    }
  }

  if (!sawRequiredGuard) {
    return violationForLine(lineFor(missingGuardOffset));
  }
  if (requireEffectfulRouteAfterGuard && !sawEffectfulRouteAfterGuard) {
    return violationForLine(lineFor(missingGuardOffset));
  }
  return null;
}

Expression? extractExpressionStatement(Statement statement) {
  return switch (statement) {
    ExpressionStatement(:final expression) => expression,
    _ => null,
  };
}

Expression? extractStatementExpression(Statement statement) {
  return switch (statement) {
    ExpressionStatement(:final expression) => expression,
    ReturnStatement(:final expression?) => expression,
    _ => null,
  };
}

bool hasNamedArgumentMatching({
  required MethodInvocation invocation,
  required String argumentName,
  required bool Function(Expression expression) matchesExpression,
}) {
  for (final argument in invocation.argumentList.arguments) {
    if (argument case NamedExpression(
      :final name,
      :final expression,
    ) when name.label.name == argumentName) {
      return matchesExpression(expression);
    }
  }
  return false;
}

DirectInvocationRoutingAnalysis analyzeDirectInvocationRouting({
  required AstNode root,
  required bool Function(MethodInvocation invocation) isCanonicalRoute,
  required bool Function(SimpleIdentifier identifier) isForbiddenSinkAccess,
}) {
  var foundCanonicalRoute = false;
  var foundForbiddenSinkAccess = false;
  root.accept(
    _DirectInvocationRoutingCollector(
      onMethodInvocation: (invocation) {
        if (!foundCanonicalRoute) {
          foundCanonicalRoute = isCanonicalRoute(invocation);
        }
      },
      onPropertyAccess: (propertyAccess) {
        if (foundForbiddenSinkAccess) {
          return;
        }
        foundForbiddenSinkAccess = isForbiddenSinkAccess(
          propertyAccess.propertyName,
        );
      },
      onPrefixedIdentifier: (identifier) {
        if (foundForbiddenSinkAccess) {
          return;
        }
        foundForbiddenSinkAccess = isForbiddenSinkAccess(identifier.identifier);
      },
    ),
  );
  return DirectInvocationRoutingAnalysis(
    hasCanonicalRoute: foundCanonicalRoute,
    hasForbiddenSinkAccess: foundForbiddenSinkAccess,
  );
}

bool isAllowedPurePreludeStatement(Statement statement) {
  return switch (statement) {
    EmptyStatement() => true,
    AssertStatement(:final condition, :final message?) =>
      isPurePreludeExpression(condition) && isPurePreludeExpression(message),
    AssertStatement(:final condition) => isPurePreludeExpression(condition),
    VariableDeclarationStatement(:final variables) => variables.variables.every(
      (variable) => isPurePreludeExpression(variable.initializer),
    ),
    ReturnStatement(:final expression?) => isPurePreludeExpression(expression),
    ReturnStatement() => true,
    IfStatement(
      :final expression,
      :final thenStatement,
      :final elseStatement?,
    ) =>
      isPurePreludeExpression(expression) &&
          _isAllowedPureBranchStatement(thenStatement) &&
          _isAllowedPureBranchStatement(elseStatement),
    IfStatement(:final expression, :final thenStatement) =>
      isPurePreludeExpression(expression) &&
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
    ReturnStatement(:final expression?) => isPurePreludeExpression(expression),
    ReturnStatement() => true,
    EmptyStatement() => true,
    AssertStatement(:final condition, :final message?) =>
      isPurePreludeExpression(condition) && isPurePreludeExpression(message),
    AssertStatement(:final condition) => isPurePreludeExpression(condition),
    _ => false,
  };
}

bool isPurePreludeExpression(Expression? expression) {
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
    SimpleIdentifier() => _isAllowedPureReference(unparenthesized),
    NamedExpression(:final expression) => isPurePreludeExpression(expression),
    ConditionalExpression(
      :final condition,
      :final thenExpression,
      :final elseExpression,
    ) =>
      _isStaticallyKnownBool(condition) &&
          isPurePreludeExpression(condition) &&
          isPurePreludeExpression(thenExpression) &&
          isPurePreludeExpression(elseExpression),
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
    AsExpression(:final expression) => isPurePreludeExpression(expression),
    IsExpression(:final expression) => isPurePreludeExpression(expression),
    StringInterpolation(:final elements) =>
      elements.whereType<InterpolationExpression>().every(
        (interpolation) =>
            isPurePreludeExpression(interpolation.expression) &&
            _isStaticallyKnownScalar(interpolation.expression.staticType),
      ),
    _ => false,
  };
}

bool _isAllowedPureReference(SimpleIdentifier identifier) {
  final element = identifier.element;
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
  if (!isPurePreludeExpression(leftOperand) ||
      !isPurePreludeExpression(rightOperand)) {
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
  if (!isPurePreludeExpression(operand)) {
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

final class _DirectInvocationRoutingCollector
    extends RecursiveAstVisitor<void> {
  _DirectInvocationRoutingCollector({
    required this.onMethodInvocation,
    required this.onPropertyAccess,
    required this.onPrefixedIdentifier,
  });

  final void Function(MethodInvocation invocation) onMethodInvocation;
  final void Function(PropertyAccess propertyAccess) onPropertyAccess;
  final void Function(PrefixedIdentifier identifier) onPrefixedIdentifier;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    onMethodInvocation(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    onPropertyAccess(node);
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    onPrefixedIdentifier(node);
    super.visitPrefixedIdentifier(node);
  }
}

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
