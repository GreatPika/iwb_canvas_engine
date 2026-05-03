part of 'mutation_boundary_rules.dart';

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
