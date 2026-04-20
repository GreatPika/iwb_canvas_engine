part of 'mutation_boundary_rules.dart';

bool _methodUsesSceneViewRenderSurfaceArgSource(
  MethodDeclaration method, {
  required ClassDeclaration ownerClass,
  required String argName,
  required List<String> sourceSegments,
}) {
  var found = false;
  method.body.accept(
    _ResolvedInvocationCollector(
      onMethodInvocation: (_) {},
      onFunctionInvocation: (_) {},
      onInstanceCreation: (candidate) {
        if (found ||
            candidate.constructorName.type.name.lexeme !=
                'SceneViewRenderSurface') {
          return;
        }
        for (final argument in candidate.argumentList.arguments) {
          if (argument is! NamedExpression ||
              argument.name.label.name != argName) {
            continue;
          }
          if (_expressionDerivesFromQualifiedSource(
            argument.expression,
            method: method,
            ownerClass: ownerClass,
            sourceSegments: sourceSegments,
          )) {
            found = true;
          }
        }
      },
    ),
  );
  return found;
}

bool _methodCreatesTypeNamed(
  MethodDeclaration method, {
  required String typeName,
}) {
  var found = false;
  method.body.accept(
    _ResolvedInvocationCollector(
      onMethodInvocation: (_) {},
      onFunctionInvocation: (_) {},
      onInstanceCreation: (candidate) {
        if (candidate.constructorName.type.name.lexeme == typeName) {
          found = true;
        }
      },
    ),
  );
  return found;
}

bool _methodCreatesOwnedTypeWithNamedArgInvokingOwnedTopLevelFunction(
  MethodDeclaration method, {
  required ClassDeclaration ownerClass,
  required GuardrailContext context,
  required String typeFilePath,
  required String typeName,
  required String argName,
  required String functionFilePath,
  required String functionName,
  required List<String> functionArgSegments,
}) {
  var found = false;
  method.body.accept(
    _ResolvedInvocationCollector(
      onMethodInvocation: (_) {},
      onFunctionInvocation: (_) {},
      onInstanceCreation: (candidate) {
        if (found ||
            !_matchesOwnedConstructor(
              element: candidate.constructorName.element,
              context: context,
              filePath: typeFilePath,
              ownerName: typeName,
            )) {
          return;
        }
        for (final argument in candidate.argumentList.arguments) {
          if (argument is! NamedExpression ||
              argument.name.label.name != argName) {
            continue;
          }
          if (_expressionDerivesFromOwnedTopLevelFunction(
            argument.expression,
            method: method,
            ownerClass: ownerClass,
            context: context,
            functionFilePath: functionFilePath,
            functionName: functionName,
            functionArgSegments: functionArgSegments,
          )) {
            found = true;
          }
        }
      },
    ),
  );
  return found;
}

bool _argumentListContainsQualifiedExpression(
  ArgumentList argumentList, {
  required List<String> segments,
}) {
  for (final argument in argumentList.arguments) {
    final expression = switch (argument) {
      NamedExpression(:final expression) => expression,
      _ => argument,
    };
    if (_qualifiedExpressionName(expression) == segments.join('.')) {
      return true;
    }
  }
  return false;
}

Expression? _findLocalVariableInitializer(
  MethodDeclaration method,
  String localName,
) {
  Expression? initializer;
  method.body.accept(
    _VariableDeclarationCollector(
      onDeclaration: (declaration) {
        if (initializer != null || declaration.name.lexeme != localName) {
          return;
        }
        initializer = declaration.initializer;
      },
    ),
  );
  return initializer;
}

bool _expressionDerivesFromQualifiedSource(
  Expression expression, {
  required MethodDeclaration method,
  required ClassDeclaration ownerClass,
  required List<String> sourceSegments,
  Set<String> visitedHelpers = const <String>{},
}) {
  final qualified = _qualifiedExpressionName(expression);
  if (qualified == sourceSegments.join('.')) {
    return true;
  }
  final localName = switch (expression.unParenthesized) {
    SimpleIdentifier(:final name) => name,
    _ => null,
  };
  if (localName != null) {
    final initializer = _findLocalVariableInitializer(method, localName);
    if (initializer != null) {
      return _expressionDerivesFromQualifiedSource(
        initializer,
        method: method,
        ownerClass: ownerClass,
        sourceSegments: sourceSegments,
        visitedHelpers: visitedHelpers,
      );
    }
  }
  final helperGetterName = _ownerLocalGetterName(expression);
  if (helperGetterName != null && !visitedHelpers.contains(helperGetterName)) {
    final helperGetter = _findOwnerLocalGetter(ownerClass, helperGetterName);
    final helperExpression = helperGetter == null
        ? null
        : _extractReturnedExpression(helperGetter);
    if (helperGetter != null &&
        helperExpression != null &&
        _expressionDerivesFromQualifiedSource(
          helperExpression,
          method: helperGetter,
          ownerClass: ownerClass,
          sourceSegments: sourceSegments,
          visitedHelpers: <String>{...visitedHelpers, helperGetterName},
        )) {
      return true;
    }
  }
  final helperName = switch (expression.unParenthesized) {
    MethodInvocation(:final target, :final methodName) when target == null =>
      methodName.name,
    _ => null,
  };
  if (helperName == null || visitedHelpers.contains(helperName)) {
    return false;
  }
  final helperMethod = _findMethodByName(ownerClass.members, helperName);
  if (helperMethod == null) {
    return false;
  }
  final helperExpression = _extractReturnedExpression(helperMethod);
  if (helperExpression == null) {
    return false;
  }
  return _expressionDerivesFromQualifiedSource(
    helperExpression,
    method: helperMethod,
    ownerClass: ownerClass,
    sourceSegments: sourceSegments,
    visitedHelpers: <String>{...visitedHelpers, helperName},
  );
}

bool _expressionDerivesFromOwnedTopLevelFunction(
  Expression expression, {
  required MethodDeclaration method,
  required ClassDeclaration ownerClass,
  required GuardrailContext context,
  required String functionFilePath,
  required String functionName,
  required List<String> functionArgSegments,
  Set<String> visitedHelpers = const <String>{},
}) {
  final invocation = switch (expression.unParenthesized) {
    MethodInvocation() => expression.unParenthesized as MethodInvocation,
    FunctionExpressionInvocation() =>
      expression.unParenthesized as FunctionExpressionInvocation,
    _ => null,
  };
  if (invocation != null) {
    final functionElement = switch (invocation) {
      MethodInvocation(:final methodName) => methodName.element,
      FunctionExpressionInvocation(:final function) =>
        switch (function.unParenthesized) {
          SimpleIdentifier(:final element) => element,
          PrefixedIdentifier(:final identifier) => identifier.element,
          PropertyAccess(:final propertyName) => propertyName.element,
          _ => null,
        },
      _ => null,
    };
    final argumentList = switch (invocation) {
      MethodInvocation(:final argumentList) => argumentList,
      FunctionExpressionInvocation(:final argumentList) => argumentList,
      _ => null,
    };
    if (argumentList != null &&
        _matchesOwnedTopLevelFunction(
          element: functionElement,
          context: context,
          filePath: functionFilePath,
          functionName: functionName,
        ) &&
        _argumentListContainsQualifiedExpression(
          argumentList,
          segments: functionArgSegments,
        )) {
      return true;
    }
  }
  final localName = switch (expression.unParenthesized) {
    SimpleIdentifier(:final name) => name,
    _ => null,
  };
  if (localName != null) {
    final initializer = _findLocalVariableInitializer(method, localName);
    if (initializer != null) {
      return _expressionDerivesFromOwnedTopLevelFunction(
        initializer,
        method: method,
        ownerClass: ownerClass,
        context: context,
        functionFilePath: functionFilePath,
        functionName: functionName,
        functionArgSegments: functionArgSegments,
        visitedHelpers: visitedHelpers,
      );
    }
  }
  final helperGetterName = _ownerLocalGetterName(expression);
  if (helperGetterName != null && !visitedHelpers.contains(helperGetterName)) {
    final helperGetter = _findOwnerLocalGetter(ownerClass, helperGetterName);
    final helperExpression = helperGetter == null
        ? null
        : _extractReturnedExpression(helperGetter);
    if (helperGetter != null &&
        helperExpression != null &&
        _expressionDerivesFromOwnedTopLevelFunction(
          helperExpression,
          method: helperGetter,
          ownerClass: ownerClass,
          context: context,
          functionFilePath: functionFilePath,
          functionName: functionName,
          functionArgSegments: functionArgSegments,
          visitedHelpers: <String>{...visitedHelpers, helperGetterName},
        )) {
      return true;
    }
  }
  final helperName = switch (expression.unParenthesized) {
    MethodInvocation(:final target, :final methodName) when target == null =>
      methodName.name,
    _ => null,
  };
  if (helperName == null || visitedHelpers.contains(helperName)) {
    return false;
  }
  final helperMethod = _findMethodByName(ownerClass.members, helperName);
  if (helperMethod == null) {
    return false;
  }
  final helperExpression = _extractReturnedExpression(helperMethod);
  if (helperExpression == null) {
    return false;
  }
  return _expressionDerivesFromOwnedTopLevelFunction(
    helperExpression,
    method: helperMethod,
    ownerClass: ownerClass,
    context: context,
    functionFilePath: functionFilePath,
    functionName: functionName,
    functionArgSegments: functionArgSegments,
    visitedHelpers: <String>{...visitedHelpers, helperName},
  );
}

Expression? _extractReturnedExpression(MethodDeclaration method) {
  final body = method.body;
  return switch (body) {
    ExpressionFunctionBody(:final expression) => expression,
    BlockFunctionBody(:final block)
        when block.statements.length == 1 &&
            block.statements.single is ReturnStatement =>
      (block.statements.single as ReturnStatement).expression,
    _ => null,
  };
}

MethodDeclaration? _findOwnerLocalGetter(
  ClassDeclaration ownerClass,
  String getterName,
) {
  final member = _findMethodByName(ownerClass.members, getterName);
  if (member == null || !member.isGetter) {
    return null;
  }
  return member;
}

String? _ownerLocalGetterName(Expression expression) {
  final unparenthesized = expression.unParenthesized;
  return switch (unparenthesized) {
    SimpleIdentifier(:final name) => name,
    PropertyAccess(:final target, :final propertyName)
        when target is ThisExpression =>
      propertyName.name,
    _ => null,
  };
}

String? _qualifiedExpressionName(Expression expression) {
  return switch (expression.unParenthesized) {
    PropertyAccess() => _qualifiedTargetName(
      expression.unParenthesized as PropertyAccess,
    ),
    PrefixedIdentifier() => expression.unParenthesized.toSource(),
    SimpleIdentifier(:final name) => name,
    _ => null,
  };
}

bool _nodeReferencesOwnedElement(
  AstNode node, {
  required GuardrailContext context,
  required String filePath,
  required String elementName,
}) {
  var found = false;
  node.accept(
    _ElementReferenceCollector(
      onElement: (element) {
        final normalizedElement = switch (element) {
          PropertyAccessorElement(:final variable) => variable,
          _ => element,
        };
        if (normalizedElement == null ||
            normalizedElement.displayName != elementName) {
          return;
        }
        if (element_utils.repoRelPathForElement(
              element: normalizedElement,
              context: context,
            ) ==
            filePath) {
          found = true;
        }
      },
    ),
  );
  return found;
}

bool _methodAssignsFieldFromOwnedGetter(
  MethodDeclaration method, {
  required String fieldName,
  required List<String> rhsSegments,
}) {
  var found = false;
  method.body.accept(
    _AssignmentCollector(
      onAssignment: (assignment) {
        final leftName = switch (assignment.leftHandSide.unParenthesized) {
          SimpleIdentifier(:final name) => name,
          PropertyAccess(:final propertyName) => propertyName.name,
          _ => null,
        };
        if (leftName != fieldName) {
          return;
        }
        final qualified = switch (assignment.rightHandSide.unParenthesized) {
          PropertyAccess() => _qualifiedTargetName(
            assignment.rightHandSide.unParenthesized as PropertyAccess,
          ),
          PrefixedIdentifier() =>
            assignment.rightHandSide.unParenthesized.toSource(),
          _ => null,
        };
        if (qualified == rhsSegments.join('.')) {
          found = true;
        }
      },
    ),
  );
  return found;
}

bool _statementIsEarlyReturnIfQualifiedEquality(
  Statement statement, {
  required List<String> leftSegments,
  required List<String> rightSegments,
}) {
  if (statement is! IfStatement) {
    return false;
  }
  final condition = statement.expression.unParenthesized;
  if (condition is! BinaryExpression || condition.operator.lexeme != '==') {
    return false;
  }
  final left = _expressionToQualifiedName(condition.leftOperand);
  final right = _expressionToQualifiedName(condition.rightOperand);
  final hasExpectedEquality =
      left == leftSegments.join('.') && right == rightSegments.join('.') ||
      left == rightSegments.join('.') && right == leftSegments.join('.');
  if (!hasExpectedEquality) {
    return false;
  }
  return _statementIsEarlyReturn(statement.thenStatement);
}

bool _methodContainsOrderedStatements(
  MethodDeclaration method,
  List<bool Function(Statement statement)> matchers,
) {
  if (matchers.isEmpty) {
    return true;
  }
  final body = method.body;
  if (body is! BlockFunctionBody) {
    return false;
  }
  var matcherIndex = 0;
  for (final statement in body.block.statements) {
    if (!matchers[matcherIndex](statement)) {
      continue;
    }
    matcherIndex += 1;
    if (matcherIndex == matchers.length) {
      return true;
    }
  }
  return false;
}

bool _methodContainsOrderedStatementsBeforeAnyForbidden(
  MethodDeclaration method, {
  required List<bool Function(Statement statement)> orderedMatchers,
  required List<bool Function(Statement statement)> forbiddenBeforeCompletion,
}) {
  if (orderedMatchers.isEmpty) {
    return true;
  }
  final body = method.body;
  if (body is! BlockFunctionBody) {
    return false;
  }
  var matcherIndex = 0;
  for (final statement in body.block.statements) {
    if (orderedMatchers[matcherIndex](statement)) {
      matcherIndex += 1;
      if (matcherIndex == orderedMatchers.length) {
        return true;
      }
      continue;
    }
    if (matcherIndex < orderedMatchers.length &&
        forbiddenBeforeCompletion.any((matcher) => matcher(statement))) {
      return false;
    }
  }
  return false;
}

bool _methodContainsOrderedStatementsWithForbiddenOutsideSequence(
  MethodDeclaration method, {
  required List<bool Function(Statement statement)> orderedMatchers,
  required List<bool Function(Statement statement)> forbiddenBeforeCompletion,
  required List<bool Function(Statement statement)> forbiddenAfterCompletion,
}) {
  if (orderedMatchers.isEmpty) {
    return true;
  }
  final body = method.body;
  if (body is! BlockFunctionBody) {
    return false;
  }
  var matcherIndex = 0;
  var completed = false;
  for (final statement in body.block.statements) {
    if (!completed && orderedMatchers[matcherIndex](statement)) {
      matcherIndex += 1;
      if (matcherIndex == orderedMatchers.length) {
        completed = true;
      }
      continue;
    }
    if (!completed &&
        forbiddenBeforeCompletion.any((matcher) => matcher(statement))) {
      return false;
    }
    if (completed &&
        forbiddenAfterCompletion.any((matcher) => matcher(statement))) {
      return false;
    }
  }
  return completed;
}

bool _statementInvokesOwnedMethod(
  Statement statement, {
  required GuardrailContext context,
  required String? filePath,
  required String ownerName,
  required String methodName,
  List<String>? targetSegments,
}) {
  var found = false;
  statement.accept(
    _ResolvedInvocationCollector(
      onMethodInvocation: (candidate) {
        if (targetSegments != null &&
            _expressionToQualifiedName(candidate.target) !=
                targetSegments.join('.')) {
          return;
        }
        if (_matchesOwnedMethodForBoundary(
          element: candidate.methodName.element,
          context: context,
          filePath: filePath,
          ownerName: ownerName,
          elementName: methodName,
        )) {
          found = true;
        }
      },
      onFunctionInvocation: (_) {},
      onInstanceCreation: (_) {},
    ),
  );
  return found;
}

bool _statementInvokesLocalMethod(
  Statement statement, {
  required String methodName,
  List<String>? targetSegments,
}) {
  var found = false;
  statement.accept(
    _ResolvedInvocationCollector(
      onMethodInvocation: (candidate) {
        if (candidate.methodName.name != methodName) {
          return;
        }
        if (targetSegments != null &&
            _expressionToQualifiedName(candidate.target) !=
                targetSegments.join('.')) {
          return;
        }
        if (targetSegments == null && candidate.target != null) {
          return;
        }
        found = true;
      },
      onFunctionInvocation: (candidate) {
        if (targetSegments != null) {
          return;
        }
        final function = candidate.function.unParenthesized;
        if (function is SimpleIdentifier && function.name == methodName) {
          found = true;
        }
      },
      onInstanceCreation: (_) {},
    ),
  );
  return found;
}

bool _statementInvokesOwnedMethodWithArgs(
  Statement statement, {
  required GuardrailContext context,
  required String? filePath,
  required String ownerName,
  required String methodName,
  required List<String> argSegments,
  List<String>? targetSegments,
}) {
  var found = false;
  statement.accept(
    _ResolvedInvocationCollector(
      onMethodInvocation: (candidate) {
        if (targetSegments != null &&
            _expressionToQualifiedName(candidate.target) !=
                targetSegments.join('.')) {
          return;
        }
        if (!_matchesOwnedMethodForBoundary(
              element: candidate.methodName.element,
              context: context,
              filePath: filePath,
              ownerName: ownerName,
              elementName: methodName,
            ) ||
            !_argumentListContainsQualifiedExpression(
              candidate.argumentList,
              segments: argSegments,
            )) {
          return;
        }
        found = true;
      },
      onFunctionInvocation: (_) {},
      onInstanceCreation: (_) {},
    ),
  );
  return found;
}

bool _statementAssignsFieldNamed(
  Statement statement, {
  required String fieldName,
}) {
  var found = false;
  statement.accept(
    _AssignmentCollector(
      onAssignment: (assignment) {
        final leftName = switch (assignment.leftHandSide.unParenthesized) {
          SimpleIdentifier(:final name) => name,
          PropertyAccess(:final propertyName) => propertyName.name,
          _ => null,
        };
        if (leftName == fieldName) {
          found = true;
        }
      },
    ),
  );
  return found;
}

bool _statementAssignsFieldFromQualifiedName(
  Statement statement, {
  required String fieldName,
  required List<String> rhsSegments,
}) {
  var found = false;
  statement.accept(
    _AssignmentCollector(
      onAssignment: (assignment) {
        final leftName = switch (assignment.leftHandSide.unParenthesized) {
          SimpleIdentifier(:final name) => name,
          PropertyAccess(:final propertyName) => propertyName.name,
          _ => null,
        };
        if (leftName != fieldName) {
          return;
        }
        if (_expressionToQualifiedName(assignment.rightHandSide) ==
            rhsSegments.join('.')) {
          found = true;
        }
      },
    ),
  );
  return found;
}

bool _statementAssignsFieldFromOwnedGetter(
  Statement statement, {
  required String fieldName,
  required List<String> rhsSegments,
}) {
  var found = false;
  statement.accept(
    _AssignmentCollector(
      onAssignment: (assignment) {
        final leftName = switch (assignment.leftHandSide.unParenthesized) {
          SimpleIdentifier(:final name) => name,
          PropertyAccess(:final propertyName) => propertyName.name,
          _ => null,
        };
        if (leftName != fieldName) {
          return;
        }
        final qualified = switch (assignment.rightHandSide.unParenthesized) {
          PropertyAccess() => _qualifiedTargetName(
            assignment.rightHandSide.unParenthesized as PropertyAccess,
          ),
          PrefixedIdentifier() =>
            assignment.rightHandSide.unParenthesized.toSource(),
          _ => null,
        };
        if (qualified == rhsSegments.join('.')) {
          found = true;
        }
      },
    ),
  );
  return found;
}

bool _statementDeclaresVariableNamedFromOwnedMethodWithArgs(
  Statement statement, {
  required String variableName,
  required GuardrailContext context,
  required String filePath,
  required String ownerName,
  required String methodName,
  required List<String> argSegments,
}) {
  var found = false;
  statement.accept(
    _VariableDeclarationCollector(
      onDeclaration: (declaration) {
        if (declaration.name.lexeme != variableName) {
          return;
        }
        final initializer = declaration.initializer?.unParenthesized;
        if (initializer is! MethodInvocation) {
          return;
        }
        if (_matchesOwnedMethodForBoundary(
              element: initializer.methodName.element,
              context: context,
              filePath: filePath,
              ownerName: ownerName,
              elementName: methodName,
            ) &&
            _argumentListContainsQualifiedExpression(
              initializer.argumentList,
              segments: argSegments,
            )) {
          found = true;
        }
      },
    ),
  );
  return found;
}

String? _expressionToQualifiedName(Expression? expression) {
  if (expression == null) {
    return null;
  }
  return switch (expression.unParenthesized) {
    PropertyAccess() => _qualifiedTargetName(
      expression.unParenthesized as PropertyAccess,
    ),
    PrefixedIdentifier() => expression.unParenthesized.toSource(),
    SimpleIdentifier(:final name) => name,
    ThisExpression() => 'this',
    _ => null,
  };
}

bool _statementIsEarlyReturn(Statement statement) {
  return switch (statement) {
    ReturnStatement(:final expression) when expression == null => true,
    Block(:final statements)
        when statements.length == 1 &&
            statements.single is ReturnStatement &&
            (statements.single as ReturnStatement).expression == null =>
      true,
    _ => false,
  };
}
