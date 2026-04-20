part of 'mutation_boundary_rules.dart';

bool _hasTopLevelOwner(
  ParsedUnitResult parsed,
  String ownerName, {
  Set<String> alternativeOwnerNames = const <String>{},
}) {
  final acceptedNames = <String>{ownerName, ...alternativeOwnerNames};
  for (final declaration in parsed.unit.declarations) {
    switch (declaration) {
      case ClassDeclaration(:final name)
          when acceptedNames.contains(name.lexeme):
        return true;
      case MixinDeclaration(:final name)
          when acceptedNames.contains(name.lexeme):
        return true;
      case EnumDeclaration(:final name)
          when acceptedNames.contains(name.lexeme):
        return true;
      case ExtensionDeclaration(:final name?)
          when acceptedNames.contains(name.lexeme):
        return true;
      case GenericTypeAlias(:final name)
          when acceptedNames.contains(name.lexeme):
        return true;
      case FunctionDeclaration(:final name)
          when acceptedNames.contains(name.lexeme):
        return true;
      default:
        break;
    }
  }
  return false;
}

bool _hasDisallowedTopLevelHelper(ParsedUnitResult parsed) {
  for (final declaration in parsed.unit.declarations) {
    if (declaration is! FunctionDeclaration) {
      continue;
    }
    if (declaration.name.lexeme == 'sceneControllerViewRuntimeOf') {
      continue;
    }
    return true;
  }
  return false;
}

bool _hasImport(ParsedUnitResult parsed, String suffix) {
  for (final directive in parsed.unit.directives.whereType<ImportDirective>()) {
    final uri = directive.uri.stringValue;
    if (uri == suffix || uri?.endsWith(suffix) == true) {
      return true;
    }
  }
  return false;
}

bool _hasForbiddenImports(ParsedUnitResult parsed, Set<String> suffixes) {
  for (final directive in parsed.unit.directives.whereType<ImportDirective>()) {
    final uri = directive.uri.stringValue ?? '';
    if (suffixes.any(uri.endsWith)) {
      return true;
    }
  }
  return false;
}

bool _hasTopLevelFunction(ParsedUnitResult parsed, String functionName) {
  return parsed.unit.declarations.any(
    (declaration) =>
        declaration is FunctionDeclaration &&
        declaration.name.lexeme == functionName,
  );
}

bool _containsTopLevelGetter(ParsedUnitResult parsed, String getterName) {
  return parsed.unit.declarations.any(
    (declaration) =>
        declaration is FunctionDeclaration &&
        declaration.isGetter &&
        declaration.name.lexeme == getterName,
  );
}

bool _classOrInterfaceOwnsGetter(ParsedUnitResult parsed, String getterName) {
  for (final declaration
      in parsed.unit.declarations.whereType<ClassDeclaration>()) {
    for (final member in declaration.members.whereType<MethodDeclaration>()) {
      if (member.isGetter && member.name.lexeme == getterName) {
        return true;
      }
    }
  }
  for (final declaration
      in parsed.unit.declarations.whereType<ClassTypeAlias>()) {
    if (declaration.name.lexeme == getterName) {
      return true;
    }
  }
  return false;
}

bool _hasClassLikeDeclaration(
  ParsedUnitResult parsed,
  String className, {
  required bool requireInterface,
}) {
  final classDeclaration = _findClassDeclaration(parsed.unit, className);
  if (classDeclaration == null) {
    return false;
  }
  if (!requireInterface) {
    return true;
  }
  return classDeclaration.abstractKeyword != null &&
      classDeclaration.interfaceKeyword != null;
}

MethodDeclaration? _findClassMethodDeclaration(
  ParsedUnitResult parsed,
  String className,
  String methodName,
) {
  final declaration = _findClassDeclaration(parsed.unit, className);
  if (declaration == null) {
    return null;
  }
  for (final method in declaration.members.whereType<MethodDeclaration>()) {
    if (method.name.lexeme == methodName) {
      return method;
    }
  }
  return null;
}

bool _classOwnsMethod(
  ParsedUnitResult parsed,
  String className,
  String methodName,
) {
  return _findClassMethodDeclaration(parsed, className, methodName) != null;
}

ClassDeclaration? _findClassDeclaration(
  CompilationUnit unit,
  String className,
) {
  for (final declaration in unit.declarations.whereType<ClassDeclaration>()) {
    if (declaration.name.lexeme == className) {
      return declaration;
    }
  }
  return null;
}

MethodDeclaration? _findExtensionMethodOnType(
  CompilationUnit unit,
  String extendedTypeName,
  String methodName,
) {
  for (final declaration
      in unit.declarations.whereType<ExtensionDeclaration>()) {
    final extendedType = declaration.onClause?.extendedType;
    if (extendedType is! NamedType ||
        extendedType.name.lexeme != extendedTypeName) {
      continue;
    }
    for (final member in declaration.members.whereType<MethodDeclaration>()) {
      if (member.name.lexeme == methodName) {
        return member;
      }
    }
  }
  return null;
}

bool _classImplements(ClassDeclaration declaration, String interfaceName) {
  final implementsClause = declaration.implementsClause;
  if (implementsClause == null) {
    return false;
  }
  return implementsClause.interfaces.any(
    (type) => type.name.lexeme == interfaceName,
  );
}

bool _classHasFieldNamed(ClassDeclaration declaration, String fieldName) {
  for (final field in declaration.members.whereType<FieldDeclaration>()) {
    for (final variable in field.fields.variables) {
      if (variable.name.lexeme == fieldName ||
          variable.name.lexeme == '_$fieldName') {
        return true;
      }
    }
  }
  return false;
}

bool _classIsFinal(ClassDeclaration declaration) {
  final source = declaration.toSource().trimLeft();
  return source.startsWith('final class ') ||
      source.startsWith('base final class ') ||
      source.startsWith('sealed final class ');
}

bool _classHasOnlyUnnamedConstructor(ClassDeclaration declaration) {
  final constructors = declaration.members.whereType<ConstructorDeclaration>();
  if (constructors.isEmpty) {
    return false;
  }
  return constructors.every((constructor) => constructor.name == null);
}

bool _classHasFieldTypeFromAllowedFiles(
  ClassDeclaration declaration, {
  required GuardrailContext context,
  required String typeName,
  required Set<String> allowedFilePaths,
}) {
  for (final field in declaration.members.whereType<FieldDeclaration>()) {
    final fieldType = field.fields.type?.type;
    final fieldTypeName = switch (fieldType) {
      InterfaceType(:final element) => element.name,
      _ => field.fields.type?.toSource(),
    };
    if (fieldTypeName != typeName) {
      continue;
    }
    final element = switch (fieldType) {
      InterfaceType(:final element) => element,
      _ => null,
    };
    if (element == null) {
      return false;
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

bool _classOwnsMethodDeclaration(
  ClassDeclaration declaration,
  String methodName,
) {
  return declaration.members.whereType<MethodDeclaration>().any(
    (method) => method.name.lexeme == methodName,
  );
}

bool _classOwnsGetterOrMethod(ClassDeclaration declaration, String name) {
  return declaration.members.whereType<MethodDeclaration>().any(
    (method) => method.name.lexeme == name,
  );
}

bool _unitContainsIdentifier(CompilationUnit unit, String identifier) {
  var found = false;
  unit.accept(
    _IdentifierCollector(
      onIdentifier: (candidate) {
        if (candidate == identifier) {
          found = true;
        }
      },
    ),
  );
  if (found) {
    return true;
  }
  final pattern = RegExp(
    '(?<![A-Za-z0-9_])${RegExp.escape(identifier)}(?![A-Za-z0-9_])',
  );
  return pattern.hasMatch(unit.toSource());
}

bool _unitContainsQualifiedPrefix(CompilationUnit unit, List<String> segments) {
  var found = false;
  unit.accept(
    _QualifiedNameCollector(
      onName: (candidate) {
        if (candidate.startsWith(segments.join('.'))) {
          found = true;
        }
      },
    ),
  );
  return found;
}

FunctionDeclaration? _findTopLevelFunctionByName(
  NodeList<CompilationUnitMember> declarations,
  String functionName,
) {
  for (final declaration in declarations) {
    if (declaration is FunctionDeclaration &&
        declaration.name.lexeme == functionName) {
      return declaration;
    }
  }
  return null;
}
