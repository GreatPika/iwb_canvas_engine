part of 'mutation_boundary_rules.dart';

bool _methodHasParameterType(
  MethodDeclaration method, {
  required String parameterName,
  required String typeName,
}) {
  final parameters = method.parameters?.parameters;
  if (parameters == null) {
    return false;
  }
  for (final parameter in parameters) {
    final normalized = switch (parameter) {
      DefaultFormalParameter(:final parameter) => parameter,
      _ => parameter,
    };
    if (_formalParameterName(normalized) != parameterName) {
      continue;
    }
    return _formalParameterTypeName(normalized) == typeName;
  }
  return false;
}

bool _methodHasNoParameters(MethodDeclaration method) {
  return method.parameters?.parameters.isEmpty ?? true;
}

bool _methodReturnsVoid(MethodDeclaration method) {
  return method.returnType is NamedType &&
      (method.returnType as NamedType).name.lexeme == 'void';
}

bool _methodHasReturnTypeName(
  MethodDeclaration method, {
  required String typeName,
}) {
  final returnType = method.returnType;
  return returnType is NamedType && returnType.name.lexeme == typeName;
}

String? _formalParameterName(FormalParameter parameter) {
  return switch (parameter) {
    SimpleFormalParameter(:final name?) => name.lexeme,
    FieldFormalParameter(:final name) => name.lexeme,
    FunctionTypedFormalParameter(:final name) => name.lexeme,
    SuperFormalParameter(:final name) => name.lexeme,
    _ => null,
  };
}

String? _formalParameterTypeName(FormalParameter parameter) {
  return switch (parameter) {
    SimpleFormalParameter(:final type?) => type.toSource(),
    FieldFormalParameter(:final type?) => type.toSource(),
    FunctionTypedFormalParameter(:final returnType?) => returnType.toSource(),
    SuperFormalParameter(:final type?) => type.toSource(),
    _ => null,
  };
}

bool _methodReturnsInterfaceType(
  MethodDeclaration method, {
  required String interfaceName,
}) {
  final type = method.returnType?.type;
  return switch (type) {
    InterfaceType(:final element) when element.name == interfaceName => true,
    _ => false,
  };
}

bool _methodInvokesOwnedMethod(
  MethodDeclaration method, {
  required GuardrailContext context,
  required String? filePath,
  required String ownerName,
  required String methodName,
}) {
  var found = false;
  method.body.accept(
    _ResolvedInvocationCollector(
      onMethodInvocation: (candidate) {
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

bool _methodInvokesMethodOnQualifiedTarget(
  MethodDeclaration method, {
  required List<String> targetSegments,
  required String methodName,
}) {
  var found = false;
  method.body.accept(
    _QualifiedMethodInvocationCollector(
      onInvocation: (qualifiedTarget, candidateMethodName) {
        if (candidateMethodName == methodName &&
            qualifiedTarget == targetSegments.join('.')) {
          found = true;
        }
      },
    ),
  );
  return found;
}

bool _methodInvokesMethodOnQualifiedTargetWithNamedArg(
  MethodDeclaration method, {
  required List<String> targetSegments,
  required String methodName,
  required String argName,
  required List<String> expressionSegments,
}) {
  var found = false;
  method.body.accept(
    _ResolvedInvocationCollector(
      onMethodInvocation: (candidate) {
        if (_expressionToQualifiedName(candidate.target) !=
                targetSegments.join('.') ||
            candidate.methodName.name != methodName) {
          return;
        }
        for (final argument in candidate.argumentList.arguments) {
          if (argument is! NamedExpression ||
              argument.name.label.name != argName) {
            continue;
          }
          if (_expressionToQualifiedName(argument.expression) ==
              expressionSegments.join('.')) {
            found = true;
          }
        }
      },
      onFunctionInvocation: (_) {},
      onInstanceCreation: (_) {},
    ),
  );
  return found;
}

DartType? _formalParameterType(FormalParameter parameter) {
  return switch (parameter) {
    SimpleFormalParameter(:final type?) => type.type,
    FieldFormalParameter(:final type?) => type.type,
    SuperFormalParameter(:final type?) => type.type,
    _ => null,
  };
}

bool _matchesOwnedMethodForBoundary({
  required Element? element,
  required GuardrailContext context,
  required String? filePath,
  required String ownerName,
  required String elementName,
}) {
  final normalizedElement = switch (element) {
    PropertyAccessorElement(:final variable) => variable,
    _ => element,
  };
  if (normalizedElement == null ||
      normalizedElement.displayName != elementName ||
      !_elementMatchesBoundaryOwner(
        normalizedElement.enclosingElement,
        ownerName: ownerName,
      )) {
    return false;
  }
  if (filePath == null) {
    return true;
  }
  return element_utils.repoRelPathForElement(
        element: normalizedElement,
        context: context,
      ) ==
      filePath;
}

bool _elementMatchesBoundaryOwner(Element? owner, {required String ownerName}) {
  if (owner == null) {
    return false;
  }
  if (owner.displayName == ownerName) {
    return true;
  }
  return switch (owner) {
    ExtensionElement(:final extendedType)
        when switch (extendedType) {
          InterfaceType(:final element) => element.name == ownerName,
          _ => false,
        } =>
      true,
    _ => false,
  };
}

bool _methodCreatesOwnedType(
  MethodDeclaration method, {
  required GuardrailContext context,
  required String? filePath,
  required String typeName,
}) {
  return _declarationCreatesOwnedType(
    method.body,
    context: context,
    filePath: filePath,
    typeName: typeName,
  );
}

bool _functionCreatesOwnedType(
  FunctionDeclaration function, {
  required GuardrailContext context,
  required String? filePath,
  required String typeName,
}) {
  final body = function.functionExpression.body;
  return _declarationCreatesOwnedType(
    body,
    context: context,
    filePath: filePath,
    typeName: typeName,
  );
}

bool _declarationCreatesOwnedType(
  AstNode body, {
  required GuardrailContext context,
  required String? filePath,
  required String typeName,
}) {
  var found = false;
  body.accept(
    _ResolvedInvocationCollector(
      onMethodInvocation: (_) {},
      onFunctionInvocation: (_) {},
      onInstanceCreation: (candidate) {
        if (_matchesOwnedConstructor(
          element: candidate.constructorName.element,
          context: context,
          filePath: filePath,
          ownerName: typeName,
        )) {
          found = true;
        }
      },
    ),
  );
  return found;
}

bool _classFieldInitializerInvokesOwnedTopLevelFunction(
  ClassDeclaration declaration, {
  required String fieldName,
  required GuardrailContext context,
  required String filePath,
  required String functionName,
}) {
  for (final field in declaration.members.whereType<FieldDeclaration>()) {
    for (final variable in field.fields.variables) {
      if (variable.name.lexeme != fieldName) {
        continue;
      }
      final initializer = variable.initializer;
      if (initializer == null) {
        return false;
      }
      return _nodeInvokesOwnedTopLevelFunction(
        initializer,
        context: context,
        filePath: filePath,
        functionName: functionName,
      );
    }
  }
  return false;
}

bool _classFieldInitializerCreatesOwnedType(
  ClassDeclaration declaration, {
  required String fieldName,
  required GuardrailContext context,
  required String filePath,
  required String typeName,
}) {
  for (final field in declaration.members.whereType<FieldDeclaration>()) {
    for (final variable in field.fields.variables) {
      if (variable.name.lexeme != fieldName) {
        continue;
      }
      final initializer = variable.initializer;
      if (initializer == null) {
        return false;
      }
      return _declarationCreatesOwnedType(
        initializer,
        context: context,
        filePath: filePath,
        typeName: typeName,
      );
    }
  }
  return false;
}

bool _constructorAssignsFieldFromOwnedTopLevelFunction(
  ConstructorDeclaration declaration, {
  required String fieldName,
  required GuardrailContext context,
  required String filePath,
  required String functionName,
}) {
  var found = false;
  declaration.body.accept(
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
        if (_nodeInvokesOwnedTopLevelFunction(
          assignment.rightHandSide,
          context: context,
          filePath: filePath,
          functionName: functionName,
        )) {
          found = true;
        }
      },
    ),
  );
  return found;
}

bool _constructorCreatesOwnedType(
  ConstructorDeclaration declaration, {
  required GuardrailContext context,
  required String filePath,
  required String typeName,
}) {
  return _declarationCreatesOwnedType(
    declaration.body,
    context: context,
    filePath: filePath,
    typeName: typeName,
  );
}

bool _nodeInvokesOwnedTopLevelFunction(
  AstNode node, {
  required GuardrailContext context,
  required String filePath,
  required String functionName,
}) {
  var found = false;
  node.accept(
    _ResolvedInvocationCollector(
      onMethodInvocation: (candidate) {
        if (_matchesOwnedTopLevelFunction(
          element: candidate.methodName.element,
          context: context,
          filePath: filePath,
          functionName: functionName,
        )) {
          found = true;
        }
      },
      onFunctionInvocation: (candidate) {
        final element = switch (candidate.function.unParenthesized) {
          SimpleIdentifier(:final element) => element,
          PrefixedIdentifier(:final identifier) => identifier.element,
          PropertyAccess(:final propertyName) => propertyName.element,
          _ => null,
        };
        if (_matchesOwnedTopLevelFunction(
          element: element,
          context: context,
          filePath: filePath,
          functionName: functionName,
        )) {
          found = true;
        }
      },
      onInstanceCreation: (_) {},
    ),
  );
  return found;
}

bool _functionAccessesField(
  FunctionDeclaration declaration, {
  required String fieldName,
}) {
  var found = false;
  declaration.functionExpression.body.accept(
    _FieldAccessCollector(
      onFieldAccess: (candidate) {
        if (candidate == fieldName) {
          found = true;
        }
      },
    ),
  );
  return found;
}

bool _methodReferencesOwnedExecutable(
  MethodDeclaration method, {
  required GuardrailContext context,
  required String filePath,
  required String ownerName,
  required String elementName,
}) {
  var found = false;
  method.body.accept(
    _ElementReferenceCollector(
      onElement: (element) {
        if (_matchesOwnedMethodForBoundary(
          element: element,
          context: context,
          filePath: filePath,
          ownerName: ownerName,
          elementName: elementName,
        )) {
          found = true;
        }
      },
    ),
  );
  return found;
}

bool _functionReferencesOwnedExecutable(
  FunctionDeclaration function, {
  required GuardrailContext context,
  required String filePath,
  required String ownerName,
  required String elementName,
}) {
  var found = false;
  function.functionExpression.body.accept(
    _ElementReferenceCollector(
      onElement: (element) {
        if (_matchesOwnedMethodForBoundary(
          element: element,
          context: context,
          filePath: filePath,
          ownerName: ownerName,
          elementName: elementName,
        )) {
          found = true;
        }
      },
    ),
  );
  return found;
}

bool _functionInvokesOwnedTopLevelFunction(
  FunctionDeclaration function, {
  required GuardrailContext context,
  required String filePath,
  required String functionName,
}) {
  var found = false;
  function.functionExpression.body.accept(
    _ResolvedInvocationCollector(
      onMethodInvocation: (candidate) {
        if (_matchesOwnedTopLevelFunction(
          element: candidate.methodName.element,
          context: context,
          filePath: filePath,
          functionName: functionName,
        )) {
          found = true;
        }
      },
      onFunctionInvocation: (candidate) {
        final element = switch (candidate.function.unParenthesized) {
          SimpleIdentifier(:final element) => element,
          PrefixedIdentifier(:final identifier) => identifier.element,
          PropertyAccess(:final propertyName) => propertyName.element,
          _ => null,
        };
        if (_matchesOwnedTopLevelFunction(
          element: element,
          context: context,
          filePath: filePath,
          functionName: functionName,
        )) {
          found = true;
        }
      },
      onInstanceCreation: (_) {},
    ),
  );
  return found;
}

bool _matchesOwnedTopLevelFunction({
  required Element? element,
  required GuardrailContext context,
  required String filePath,
  required String functionName,
}) {
  if (element is! ExecutableElement || element.displayName != functionName) {
    return false;
  }
  return element_utils.repoRelPathForElement(
        element: element,
        context: context,
      ) ==
      filePath;
}

bool _matchesOwnedConstructor({
  required ConstructorElement? element,
  required GuardrailContext context,
  required String? filePath,
  required String ownerName,
}) {
  if (element == null || element.enclosingElement.displayName != ownerName) {
    return false;
  }
  if (filePath == null) {
    return true;
  }
  return element_utils.repoRelPathForElement(
        element: element.enclosingElement,
        context: context,
      ) ==
      filePath;
}

bool _constructorHasParameterTypeFromAllowedFiles(
  ClassDeclaration declaration, {
  required GuardrailContext context,
  required String parameterName,
  required String typeName,
  required Set<String> allowedFilePaths,
}) {
  for (final constructor
      in declaration.members.whereType<ConstructorDeclaration>()) {
    for (final parameter in constructor.parameters.parameters) {
      final normalized = switch (parameter) {
        DefaultFormalParameter(:final parameter) => parameter,
        _ => parameter,
      };
      if (_formalParameterName(normalized) != parameterName) {
        continue;
      }
      final element = switch (_formalParameterType(normalized)) {
        InterfaceType(:final element) => element,
        _ => null,
      };
      if (element == null || element.name != typeName) {
        continue;
      }
      final repoRelPath = element_utils.repoRelPathForElement(
        element: element,
        context: context,
      );
      if (allowedFilePaths.contains(repoRelPath)) {
        return true;
      }
    }
  }
  return false;
}

bool _functionHasParameterTypeFromAllowedFiles(
  FunctionDeclaration declaration, {
  required GuardrailContext context,
  required String parameterName,
  required String typeName,
  required Set<String> allowedFilePaths,
}) {
  final parameters = declaration.functionExpression.parameters;
  if (parameters == null) {
    return false;
  }
  for (final parameter in parameters.parameters) {
    final normalized = switch (parameter) {
      DefaultFormalParameter(:final parameter) => parameter,
      _ => parameter,
    };
    if (_formalParameterName(normalized) != parameterName) {
      continue;
    }
    final element = switch (_formalParameterType(normalized)) {
      InterfaceType(:final element) => element,
      _ => null,
    };
    if (element == null || element.name != typeName) {
      continue;
    }
    final repoRelPath = element_utils.repoRelPathForElement(
      element: element,
      context: context,
    );
    if (allowedFilePaths.contains(repoRelPath)) {
      return true;
    }
  }
  return false;
}
