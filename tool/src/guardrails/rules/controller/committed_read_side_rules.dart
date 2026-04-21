import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../core/guardrail_element_utils.dart' as element_utils;
import '../../core/resolved_type_leak_traversal.dart';
import '../../core/signature_leak_support.dart';
import '../../support/guardrail_context.dart';

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
  return findFirstResolvedTypeLeak<ForbiddenResolvedTypeLeak>(
    rootType: type,
    classifyType: (candidateType) {
      return _forbiddenTypeLeakForElement(
        element: candidateType.element,
        sourceElement: sourceElement,
        context: context,
        forbiddenTypes: forbiddenTypes,
      );
    },
    expandAlias: (candidateType) {
      final aliasElement = candidateType.alias?.element;
      if (aliasElement is! TypeAliasElement) {
        return null;
      }
      return aliasElement.aliasedType;
    },
  );
}

ForbiddenResolvedTypeLeak? findForbiddenExecutableSignatureLeak({
  required ExecutableElement element,
  required GuardrailContext context,
  required List<ForbiddenResolvedTypeSpec> forbiddenTypes,
}) {
  return findExecutableSignatureLeak<ForbiddenResolvedTypeLeak>(
    element: element,
    findTypeLeak: ({required type, required sourceElement}) {
      return findForbiddenResolvedTypeLeak(
        type: type,
        sourceElement: sourceElement,
        context: context,
        forbiddenTypes: forbiddenTypes,
      );
    },
  );
}

ForbiddenResolvedTypeLeak? findForbiddenTypeParameterBoundLeak({
  required TypeParameterizedElement typeParameterizedElement,
  required GuardrailContext context,
  required List<ForbiddenResolvedTypeSpec> forbiddenTypes,
}) {
  return findTypeParameterBoundLeak<ForbiddenResolvedTypeLeak>(
    element: typeParameterizedElement,
    findTypeLeak: ({required type, required sourceElement}) {
      return findForbiddenResolvedTypeLeak(
        type: type,
        sourceElement: sourceElement,
        context: context,
        forbiddenTypes: forbiddenTypes,
      );
    },
  );
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
