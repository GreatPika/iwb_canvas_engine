import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';

import '../support/guardrail_ast_utils.dart';
import '../support/guardrail_context.dart';
import 'guardrail_element_utils.dart' as element_utils;
import 'guardrail_violation.dart';

typedef SurfaceContractViolationBuilder =
    GuardrailViolation? Function({
      required GuardrailContext context,
      required Element sourceElement,
      required String detail,
    });

typedef ConstructorTypeLeak = ({
  String forbiddenTypeName,
  Element sourceElement,
});

typedef ConstructorTypeLeakFinder =
    ConstructorTypeLeak? Function(ConstructorElement constructor);

enum SurfaceContractParameterKind { positional, requiredNamed }

final class SurfaceContractTypeIdentitySpec {
  const SurfaceContractTypeIdentitySpec({
    required this.repoRelPath,
    required this.typeName,
  });

  final String repoRelPath;
  final String typeName;
}

final class SurfaceContractParameterSpec {
  const SurfaceContractParameterSpec.positional({
    required this.name,
    required this.typeSource,
  }) : kind = SurfaceContractParameterKind.positional;

  const SurfaceContractParameterSpec.requiredNamed({
    required this.name,
    required this.typeSource,
  }) : kind = SurfaceContractParameterKind.requiredNamed;

  final String name;
  final String typeSource;
  final SurfaceContractParameterKind kind;
}

final class SurfaceContractMethodSignatureSpec {
  const SurfaceContractMethodSignatureSpec({
    required this.detail,
    this.returnTypeSource = 'void',
    this.parameters = const <SurfaceContractParameterSpec>[],
  });

  final String detail;
  final String returnTypeSource;
  final List<SurfaceContractParameterSpec> parameters;
}

GuardrailViolation? validateExactPublicTopLevelSurface({
  required GuardrailContext context,
  required LibraryElement library,
  required Set<String> allowedNames,
  Set<String>? requiredNames,
  required SurfaceContractViolationBuilder buildViolation,
  required String Function(String unexpectedName) unexpectedDetail,
  required String Function(String requiredName) missingDetail,
}) {
  final publicElements = publicTopLevelElements(library)
    ..sort(element_utils.compareElementsBySourceOrder);
  for (final element in publicElements) {
    if (allowedNames.contains(element.displayName)) {
      continue;
    }
    return buildViolation(
      context: context,
      sourceElement: element,
      detail: unexpectedDetail(element.displayName),
    );
  }

  final effectiveRequiredNames = requiredNames ?? allowedNames;
  for (final requiredName in effectiveRequiredNames) {
    final present = publicElements.any(
      (element) => element.displayName == requiredName,
    );
    if (present) {
      continue;
    }
    return buildViolation(
      context: context,
      sourceElement: library,
      detail: missingDetail(requiredName),
    );
  }
  return null;
}

List<Element> publicTopLevelElements(LibraryElement library) {
  return <Element>[
    ...library.classes.where(element_utils.isPublicNamedElement),
    ...library.enums.where(element_utils.isPublicNamedElement),
    ...library.mixins.where(element_utils.isPublicNamedElement),
    ...library.extensions.where(element_utils.isPublicNamedElement),
    ...library.extensionTypes.where(element_utils.isPublicNamedElement),
    ...library.typeAliases.where(element_utils.isPublicNamedElement),
    ...library.topLevelFunctions.where(element_utils.isPublicNamedElement),
    ...library.topLevelVariables.where(element_utils.isPublicNamedElement),
    ...library.getters.where(
      (element) =>
          !element.isSynthetic && element_utils.isPublicNamedElement(element),
    ),
    ...library.setters.where(
      (element) =>
          !element.isSynthetic && element_utils.isPublicNamedElement(element),
    ),
  ];
}

GuardrailViolation? validateExactPublicMemberSurface({
  required GuardrailContext context,
  required InstanceElement owner,
  required Set<String> allowedNames,
  Set<String>? requiredNames,
  required SurfaceContractViolationBuilder buildViolation,
  required String Function(Element member) unexpectedDetail,
  required String Function(String requiredKey) missingDetail,
}) {
  final publicMembers = publicInstanceMembers(owner)
    ..sort(element_utils.compareElementsBySourceOrder);
  for (final member in publicMembers) {
    final memberKey = publicMemberSurfaceKey(member);
    if (allowedNames.contains(memberKey)) {
      continue;
    }
    return buildViolation(
      context: context,
      sourceElement: member,
      detail: unexpectedDetail(member),
    );
  }

  final publicMemberNames = publicMembers.map(publicMemberSurfaceKey).toSet();
  final effectiveRequiredNames = requiredNames ?? allowedNames;
  for (final requiredName in effectiveRequiredNames) {
    if (publicMemberNames.contains(requiredName)) {
      continue;
    }
    return buildViolation(
      context: context,
      sourceElement: owner,
      detail: missingDetail(requiredName),
    );
  }
  return null;
}

List<Element> publicInstanceMembers(InstanceElement owner) {
  return <Element>[
    ...owner.fields.where(
      (field) =>
          !field.isSynthetic && element_utils.isPublicNamedElement(field),
    ),
    ...owner.getters.where(
      (getter) =>
          !getter.isSynthetic && element_utils.isPublicNamedElement(getter),
    ),
    ...owner.setters.where(
      (setter) =>
          !setter.isSynthetic && element_utils.isPublicNamedElement(setter),
    ),
    ...owner.methods.where(element_utils.isPublicNamedElement),
  ];
}

String publicMemberSurfaceKey(Element member) {
  final name = member.displayName;
  if (member is FieldElement) {
    return 'field:$name';
  }
  if (member is PropertyAccessorElement) {
    return member is SetterElement ? 'setter:$name' : 'getter:$name';
  }
  if (member is MethodElement) {
    return 'method:$name';
  }
  return 'member:$name';
}

String describePublicMemberSurface(Element member) {
  if (member is FieldElement) {
    return 'public field "${member.displayName}"';
  }
  if (member is PropertyAccessorElement) {
    return member is SetterElement
        ? 'public setter "${member.displayName}"'
        : 'public getter "${member.displayName}"';
  }
  if (member is MethodElement) {
    return 'public method "${member.displayName}"';
  }
  return 'public member "${member.displayName}"';
}

String describePublicMemberSurfaceKey(String key) {
  final parts = key.split(':');
  if (parts.length != 2) {
    return 'public member "$key"';
  }
  final kind = parts.first;
  final name = parts.last;
  return switch (kind) {
    'field' => 'public field "$name"',
    'getter' => 'public getter "$name"',
    'setter' => 'public setter "$name"',
    'method' => 'public method "$name"',
    _ => 'public member "$name"',
  };
}

GuardrailViolation? validateSingleUnnamedPublicConstructor({
  required GuardrailContext context,
  required InterfaceElement owner,
  required SurfaceContractViolationBuilder buildViolation,
  required String detail,
}) {
  final publicConstructors =
      owner.constructors
          .where(element_utils.isPublicConstructor)
          .toList(growable: false)
        ..sort(element_utils.compareElementsBySourceOrder);
  if (publicConstructors.length != 1 ||
      element_utils
          .normalizedConstructorName(publicConstructors.single)
          .isNotEmpty) {
    return buildViolation(
      context: context,
      sourceElement: publicConstructors.isEmpty
          ? owner
          : publicConstructors.first,
      detail: detail,
    );
  }
  return null;
}

GuardrailViolation? validateNoExplicitPublicConstructors({
  required GuardrailContext context,
  required InterfaceElement owner,
  required SurfaceContractViolationBuilder buildViolation,
  required String detail,
}) {
  final explicitPublicConstructor =
      owner.constructors
          .where(element_utils.isPublicConstructor)
          .where((constructor) => !constructor.isSynthetic)
          .toList(growable: false)
        ..sort(element_utils.compareElementsBySourceOrder);
  if (explicitPublicConstructor.isEmpty) {
    return null;
  }
  return buildViolation(
    context: context,
    sourceElement: explicitPublicConstructor.first,
    detail: detail,
  );
}

GuardrailViolation? validatePublicConstructorSurface({
  required ConstructorElement constructor,
  required GuardrailContext context,
  required Set<String> allowedParameterNames,
  required ConstructorTypeLeakFinder findForbiddenSignatureLeak,
  required SurfaceContractViolationBuilder buildViolation,
  required String namedConstructorDetail,
  required String Function(String forbiddenTypeName) forbiddenTypeDetail,
  required String Function(String parameterName) extraParameterDetail,
}) {
  if (!element_utils.isPublicConstructor(constructor)) {
    return null;
  }

  final constructorName = element_utils.normalizedConstructorName(constructor);
  if (constructorName.isNotEmpty) {
    return buildViolation(
      context: context,
      sourceElement: constructor,
      detail: namedConstructorDetail,
    );
  }

  final leak = findForbiddenSignatureLeak(constructor);
  if (leak != null) {
    return buildViolation(
      context: context,
      sourceElement: leak.sourceElement,
      detail: forbiddenTypeDetail(leak.forbiddenTypeName),
    );
  }

  for (final parameter in constructor.formalParameters) {
    if (allowedParameterNames.contains(parameter.displayName)) {
      continue;
    }
    return buildViolation(
      context: context,
      sourceElement: parameter,
      detail: extraParameterDetail(parameter.displayName),
    );
  }

  return null;
}

GuardrailViolation? validateExactImplementedInterfaces({
  required GuardrailContext context,
  required InterfaceElement owner,
  required List<SurfaceContractTypeIdentitySpec> exactInterfaces,
  required SurfaceContractViolationBuilder buildViolation,
  required String detail,
}) {
  final interfaces = owner.interfaces;
  if (interfaces.length != exactInterfaces.length) {
    return buildViolation(
      context: context,
      sourceElement: owner,
      detail: detail,
    );
  }
  final expectedKeys = exactInterfaces
      .map((spec) => '${spec.repoRelPath}::${spec.typeName}')
      .toSet();
  final actualKeys = interfaces
      .map(
        (interfaceType) =>
            identityKeyForElement(interfaceType.element, context),
      )
      .toSet();
  if (actualKeys.length != expectedKeys.length ||
      !actualKeys.containsAll(expectedKeys)) {
    return buildViolation(
      context: context,
      sourceElement: owner,
      detail: detail,
    );
  }
  return null;
}

bool matchesTypeIdentity({
  required GuardrailContext context,
  required Element? element,
  required SurfaceContractTypeIdentitySpec spec,
}) {
  return identityKeyForElement(element, context) ==
      '${spec.repoRelPath}::${spec.typeName}';
}

String? identityKeyForElement(Element? element, GuardrailContext context) {
  if (element == null) {
    return null;
  }
  final repoRelPath = element_utils.repoRelPathForElement(
    element: element,
    context: context,
  );
  if (repoRelPath == null) {
    return null;
  }
  return '$repoRelPath::${element.displayName}';
}

ClassDeclaration? findClassDeclarationByName(
  Iterable<CompilationUnitMember> declarations,
  String className,
) {
  for (final declaration in declarations) {
    if (declaration is ClassDeclaration &&
        declaration.name.lexeme == className) {
      return declaration;
    }
  }
  return null;
}

MethodDeclaration? findMethodDeclarationByName(
  Iterable<ClassMember> members,
  String name,
) {
  for (final member in members) {
    if (member is MethodDeclaration && member.name.lexeme == name) {
      return member;
    }
  }
  return null;
}

bool hasClassLikeDeclaration(
  ParsedUnitResult parsed,
  String className, {
  required bool requireInterface,
}) {
  final classDeclaration = findClassDeclarationByName(
    parsed.unit.declarations,
    className,
  );
  if (classDeclaration == null) {
    return false;
  }
  if (!requireInterface) {
    return true;
  }
  return classDeclaration.abstractKeyword != null &&
      classDeclaration.interfaceKeyword != null;
}

MethodDeclaration? findClassMethodDeclarationInParsedUnit(
  ParsedUnitResult parsed,
  String className,
  String methodName,
) {
  final declaration = findClassDeclarationByName(
    parsed.unit.declarations,
    className,
  );
  if (declaration == null) {
    return null;
  }
  return findMethodDeclarationByName(declaration.members, methodName);
}

bool classOwnsMethod(
  ParsedUnitResult parsed,
  String className,
  String methodName,
) {
  return findClassMethodDeclarationInParsedUnit(
        parsed,
        className,
        methodName,
      ) !=
      null;
}

bool classImplementsNamedInterface(
  ClassDeclaration declaration,
  String interfaceName,
) {
  final implementsClause = declaration.implementsClause;
  if (implementsClause == null) {
    return false;
  }
  return implementsClause.interfaces.any(
    (type) => type.name.lexeme == interfaceName,
  );
}

bool classHasOnlyUnnamedConstructor(ClassDeclaration declaration) {
  final constructors = declaration.members.whereType<ConstructorDeclaration>();
  if (constructors.isEmpty) {
    return false;
  }
  return constructors.every((constructor) => constructor.name == null);
}

GuardrailViolation? validateExactMethodSignature({
  required ParsedUnitResult parsed,
  required MethodDeclaration? member,
  required String filePath,
  required SurfaceContractMethodSignatureSpec spec,
}) {
  if (member == null ||
      !_matchesTypeAnnotation(member.returnType, spec.returnTypeSource) ||
      member.typeParameters != null) {
    return GuardrailViolation(
      filePath: filePath,
      line: member == null ? 1 : lineForOffset(parsed, member.offset),
      message: 'controller API violation: ${spec.detail}',
    );
  }

  final parameters = member.parameters?.parameters ?? const <FormalParameter>[];
  if (parameters.length != spec.parameters.length) {
    return GuardrailViolation(
      filePath: filePath,
      line: lineForOffset(parsed, member.offset),
      message: 'controller API violation: ${spec.detail}',
    );
  }
  for (var index = 0; index < parameters.length; index++) {
    if (!_matchesParameter(parameters[index], spec.parameters[index])) {
      return GuardrailViolation(
        filePath: filePath,
        line: lineForOffset(parsed, member.offset),
        message: 'controller API violation: ${spec.detail}',
      );
    }
  }
  return null;
}

bool _matchesParameter(
  FormalParameter actual,
  SurfaceContractParameterSpec expected,
) {
  return switch (expected.kind) {
    SurfaceContractParameterKind.positional =>
      actual is SimpleFormalParameter &&
          actual.name?.lexeme == expected.name &&
          _matchesTypeAnnotation(actual.type, expected.typeSource),
    SurfaceContractParameterKind.requiredNamed =>
      actual is DefaultFormalParameter &&
          actual.isRequiredNamed == true &&
          actual.parameter is SimpleFormalParameter &&
          (actual.parameter as SimpleFormalParameter).name?.lexeme ==
              expected.name &&
          _matchesTypeAnnotation(
            (actual.parameter as SimpleFormalParameter).type,
            expected.typeSource,
          ),
  };
}

bool _matchesTypeAnnotation(TypeAnnotation? actual, String expectedTypeSource) {
  if (actual == null) {
    return false;
  }
  if (actual is NamedType && actual.question == null) {
    final name = actual.name;
    if (name.lexeme == expectedTypeSource) {
      return true;
    }
  }
  return actual.beginToken.lexeme == expectedTypeSource &&
      actual.endToken.lexeme == expectedTypeSource &&
      actual.beginToken.offset == actual.endToken.offset;
}
