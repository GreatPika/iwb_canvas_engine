import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../support/guardrail_context.dart';
import '../../core/guardrail_element_utils.dart' as element_utils;

final class ForbiddenResolvedTypeLeak {
  const ForbiddenResolvedTypeLeak({
    required this.sourceElement,
    required this.forbiddenTypeName,
  });

  final Element sourceElement;
  final String forbiddenTypeName;
}

final class ForbiddenResolvedTypeSpec {
  const ForbiddenResolvedTypeSpec({
    required this.repoRelPath,
    required this.typeName,
  });

  final String repoRelPath;
  final String typeName;
}

const List<ForbiddenResolvedTypeSpec> committedReadForbiddenTypeSpecs =
    <ForbiddenResolvedTypeSpec>[
      ForbiddenResolvedTypeSpec(
        repoRelPath: '/lib/src/core/scene.dart',
        typeName: 'Scene',
      ),
      ForbiddenResolvedTypeSpec(
        repoRelPath: '/lib/src/core/scene_node.dart',
        typeName: 'SceneNode',
      ),
    ];

ForbiddenResolvedTypeLeak? findForbiddenResolvedTypeLeak({
  required DartType? type,
  required Element sourceElement,
  required GuardrailContext context,
  required List<ForbiddenResolvedTypeSpec> forbiddenTypes,
}) {
  if (type == null) {
    return null;
  }

  final elementLeak = _forbiddenTypeLeakForElement(
    element: type.element,
    sourceElement: sourceElement,
    context: context,
    forbiddenTypes: forbiddenTypes,
  );
  if (elementLeak != null) {
    return elementLeak;
  }

  final aliasElement = type.alias?.element;
  if (aliasElement is TypeAliasElement) {
    final aliasLeak = findForbiddenResolvedTypeLeak(
      type: aliasElement.aliasedType,
      sourceElement: sourceElement,
      context: context,
      forbiddenTypes: forbiddenTypes,
    );
    if (aliasLeak != null) {
      return aliasLeak;
    }
  }

  if (type is ParameterizedType) {
    for (final argument in type.typeArguments) {
      final leak = findForbiddenResolvedTypeLeak(
        type: argument,
        sourceElement: sourceElement,
        context: context,
        forbiddenTypes: forbiddenTypes,
      );
      if (leak != null) {
        return leak;
      }
    }
  }

  if (type is FunctionType) {
    final returnTypeLeak = findForbiddenResolvedTypeLeak(
      type: type.returnType,
      sourceElement: sourceElement,
      context: context,
      forbiddenTypes: forbiddenTypes,
    );
    if (returnTypeLeak != null) {
      return returnTypeLeak;
    }
    for (final parameter in type.formalParameters) {
      final leak = findForbiddenResolvedTypeLeak(
        type: parameter.type,
        sourceElement: sourceElement,
        context: context,
        forbiddenTypes: forbiddenTypes,
      );
      if (leak != null) {
        return leak;
      }
    }
    for (final typeParameter in type.typeParameters) {
      final leak = findForbiddenResolvedTypeLeak(
        type: typeParameter.bound,
        sourceElement: sourceElement,
        context: context,
        forbiddenTypes: forbiddenTypes,
      );
      if (leak != null) {
        return leak;
      }
    }
  }

  if (type is RecordType) {
    for (final field in type.positionalFields) {
      final leak = findForbiddenResolvedTypeLeak(
        type: field.type,
        sourceElement: sourceElement,
        context: context,
        forbiddenTypes: forbiddenTypes,
      );
      if (leak != null) {
        return leak;
      }
    }
    for (final field in type.namedFields) {
      final leak = findForbiddenResolvedTypeLeak(
        type: field.type,
        sourceElement: sourceElement,
        context: context,
        forbiddenTypes: forbiddenTypes,
      );
      if (leak != null) {
        return leak;
      }
    }
  }

  if (type is TypeParameterType) {
    return findForbiddenResolvedTypeLeak(
      type: type.bound,
      sourceElement: sourceElement,
      context: context,
      forbiddenTypes: forbiddenTypes,
    );
  }

  return null;
}

ForbiddenResolvedTypeLeak? findForbiddenExecutableSignatureLeak({
  required ExecutableElement element,
  required GuardrailContext context,
  required List<ForbiddenResolvedTypeSpec> forbiddenTypes,
}) {
  final typeParameterLeak = findForbiddenTypeParameterBoundLeak(
    typeParameterizedElement: element,
    context: context,
    forbiddenTypes: forbiddenTypes,
  );
  if (typeParameterLeak != null) {
    return typeParameterLeak;
  }

  if (element is! ConstructorElement) {
    final returnTypeLeak = findForbiddenResolvedTypeLeak(
      type: element.returnType,
      sourceElement: element,
      context: context,
      forbiddenTypes: forbiddenTypes,
    );
    if (returnTypeLeak != null) {
      return returnTypeLeak;
    }
  }

  for (final parameter in element.formalParameters) {
    final leak = findForbiddenResolvedTypeLeak(
      type: parameter.type,
      sourceElement: parameter,
      context: context,
      forbiddenTypes: forbiddenTypes,
    );
    if (leak != null) {
      return leak;
    }
  }

  return null;
}

ForbiddenResolvedTypeLeak? findForbiddenTypeParameterBoundLeak({
  required TypeParameterizedElement typeParameterizedElement,
  required GuardrailContext context,
  required List<ForbiddenResolvedTypeSpec> forbiddenTypes,
}) {
  for (final typeParameter in typeParameterizedElement.typeParameters) {
    final leak = findForbiddenResolvedTypeLeak(
      type: typeParameter.bound,
      sourceElement: typeParameter,
      context: context,
      forbiddenTypes: forbiddenTypes,
    );
    if (leak != null) {
      return leak;
    }
  }
  return null;
}

ForbiddenResolvedTypeLeak? _forbiddenTypeLeakForElement({
  required Element? element,
  required Element sourceElement,
  required GuardrailContext context,
  required List<ForbiddenResolvedTypeSpec> forbiddenTypes,
}) {
  if (element case ExtensionTypeElement(:final representation)) {
    final representationLeak = findForbiddenResolvedTypeLeak(
      type: representation.type,
      sourceElement: sourceElement,
      context: context,
      forbiddenTypes: forbiddenTypes,
    );
    if (representationLeak != null) {
      return representationLeak;
    }
  }

  final directSpec = _firstMatchingForbiddenTypeSpec(
    element: element,
    context: context,
    forbiddenTypes: forbiddenTypes,
  );
  if (directSpec != null) {
    return ForbiddenResolvedTypeLeak(
      sourceElement: sourceElement,
      forbiddenTypeName: directTypeLeakName(
        element: element,
        fallbackTypeName: directSpec.typeName,
      ),
    );
  }

  if (element case InterfaceElement()) {
    for (final supertype in element.allSupertypes) {
      final supertypeSpec = _firstMatchingForbiddenTypeSpec(
        element: supertype.element,
        context: context,
        forbiddenTypes: forbiddenTypes,
      );
      if (supertypeSpec == null) {
        continue;
      }
      return ForbiddenResolvedTypeLeak(
        sourceElement: sourceElement,
        forbiddenTypeName: directTypeLeakName(
          element: element,
          fallbackTypeName: supertypeSpec.typeName,
        ),
      );
    }
  }

  return null;
}

ForbiddenResolvedTypeSpec? _firstMatchingForbiddenTypeSpec({
  required Element? element,
  required GuardrailContext context,
  required List<ForbiddenResolvedTypeSpec> forbiddenTypes,
}) {
  final repoRelPath = repoRelForElement(element: element, context: context);
  final typeName = element?.displayName;
  if (repoRelPath == null || typeName == null || typeName.isEmpty) {
    return null;
  }

  for (final spec in forbiddenTypes) {
    if (repoRelPath == spec.repoRelPath && typeName == spec.typeName) {
      return spec;
    }
  }
  return null;
}

String directTypeLeakName({
  required Element? element,
  required String fallbackTypeName,
}) {
  final elementName = element?.displayName;
  if (elementName == null || elementName.isEmpty) {
    return fallbackTypeName;
  }
  return elementName;
}

int? lineForElement(Element element) {
  return element_utils.lineForElement(element);
}

String? repoRelForElement({
  required Element? element,
  required GuardrailContext context,
}) {
  return element_utils.repoRelPathForElement(
    element: element,
    context: context,
  );
}
