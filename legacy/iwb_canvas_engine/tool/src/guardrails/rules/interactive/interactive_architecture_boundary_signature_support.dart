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

DartType? _formalParameterType(FormalParameter parameter) {
  return switch (parameter) {
    SimpleFormalParameter(:final type?) => type.type,
    FieldFormalParameter(:final type?) => type.type,
    SuperFormalParameter(:final type?) => type.type,
    _ => null,
  };
}
