import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../support/guardrail_context.dart';
import '../../core/guardrail_element_utils.dart' as element_utils;
import '../../core/guardrail_rule.dart';
import '../../core/guardrail_rule_metadata.dart';
import '../../core/guardrail_run_state.dart';
import '../../core/resolved_type_leak_traversal.dart';
import '../../core/signature_leak_support.dart';
import '../../core/guardrail_violation.dart';
import 'public_export_namespace_support.dart';
import 'public_surface_rules.dart';

const Set<String> _forbiddenCallbackCollectionTypeNames = <String>{
  'List',
  'Map',
  'Set',
};

final GuardrailRule publicSignatureGuardrailRule = GuardrailRule(
  metadata: const GuardrailRuleMetadata(
    id: 'public-signature',
    invariantIds: <String>[
      'INV-ENG-PUBLIC-SURFACE-NO-MUTABLE-TYPES',
      'INV-ENG-PUBLIC-SIGNATURE-HERMETICITY',
    ],
    area: 'public',
    description:
        'Checks resolved exported signatures against hidden, internal, and '
        'mutable type leaks.',
    readsStateArtifacts: <String>[
      GuardrailRunState.effectivePublicExportNamespaceArtifact,
    ],
  ),
  run: _runPublicSignatureGuardrailRule,
);

Future<List<GuardrailViolation>> runPublicSignatureHermeticityGuardrails({
  required GuardrailContext context,
  required EffectivePublicExportNamespace effectivePublicExportNamespace,
}) async {
  final violations = <GuardrailViolation>[];
  final publicVisibleTypeOwners = _collectPublicVisibleTypeOwners(
    effectivePublicExportNamespace,
  );
  final exportedElements =
      effectivePublicExportNamespace.elements.toList(growable: false)..sort(
        (left, right) => element_utils.compareElementsBySourceOrder(
          left.element,
          right.element,
        ),
      );

  for (final exportedElement in exportedElements) {
    final violation = _scanExportedElementForHermeticity(
      context: context,
      exportedElement: exportedElement,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
    );
    if (violation != null) {
      violations.add(violation);
      return violations;
    }
  }

  return violations;
}

Future<List<GuardrailViolation>> _runPublicSignatureGuardrailRule(
  GuardrailContext context,
  GuardrailRunState state,
) {
  return runPublicSignatureHermeticityGuardrails(
    context: context,
    effectivePublicExportNamespace: state
        .requireArtifact<EffectivePublicExportNamespace>(
          artifactId: GuardrailRunState.effectivePublicExportNamespaceArtifact,
          readerRuleId: publicSignatureGuardrailRule.metadata.id,
        ),
  );
}

Map<String, Set<String>> _collectPublicVisibleTypeOwners(
  EffectivePublicExportNamespace effectivePublicExportNamespace,
) {
  final ownersByName = <String, Set<String>>{};
  for (final exportedElement in effectivePublicExportNamespace.elements) {
    final element = exportedElement.element;
    if (!_isPublicVisibleTypeElement(element)) {
      continue;
    }
    final ownerRepoRelPath = exportedElement.ownerPath;
    if (ownerRepoRelPath == null) {
      continue;
    }
    ownersByName
        .putIfAbsent(exportedElement.name, () => <String>{})
        .add(ownerRepoRelPath);
  }
  return ownersByName;
}

GuardrailViolation? _scanExportedElementForHermeticity({
  required GuardrailContext context,
  required EffectivePublicExportedElement exportedElement,
  required Map<String, Set<String>> publicVisibleTypeOwners,
}) {
  final forbiddenPublicTypeNames = _forbiddenPublicTypeNamesForLibrary(
    repoRelPath: exportedElement.ownerPath,
  );
  final leak = _findLeakInExportedElement(
    element: exportedElement.element,
    context: context,
    publicVisibleTypeOwners: publicVisibleTypeOwners,
    forbiddenPublicTypeNames: forbiddenPublicTypeNames,
  );
  if (leak == null) {
    return null;
  }

  final filePath = _repoRelForElement(
    element: leak.sourceElement,
    context: context,
  );
  final line = element_utils.lineForElement(leak.sourceElement);
  if (filePath == null || line == null) {
    return null;
  }

  return GuardrailViolation(
    filePath: filePath,
    line: line,
    message: switch (leak.kind) {
      _SignatureLeakKind.hermeticity =>
        'public signature hermeticity violation: exported public '
            'signature must not expose ${leak.typeName} '
            'from ${leak.ownerRepoRelPath}.',
      _SignatureLeakKind.forbiddenPublicType =>
        '${leak.message} (${leak.typeName}).',
      _SignatureLeakKind.rawCollectionCallbackParameter => leak.message,
    },
  );
}

bool _isPublicVisibleTypeElement(Element element) {
  return element is InterfaceElement || element is TypeAliasElement;
}

_SignatureLeak? _findLeakInExportedElement({
  required Element element,
  required GuardrailContext context,
  required Map<String, Set<String>> publicVisibleTypeOwners,
  required Set<String> forbiddenPublicTypeNames,
}) {
  final signatureLeak = _findLeakInElementSignature(
    element: element,
    context: context,
    publicVisibleTypeOwners: publicVisibleTypeOwners,
    forbiddenPublicTypeNames: forbiddenPublicTypeNames,
  );
  if (signatureLeak != null) {
    return signatureLeak;
  }

  return switch (element) {
    InterfaceElement() => _findLeakInInterfaceMembers(
      element: element,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
      forbiddenPublicTypeNames: forbiddenPublicTypeNames,
    ),
    ExtensionElement() => _findLeakInInstanceMembers(
      element: element,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
      forbiddenPublicTypeNames: forbiddenPublicTypeNames,
    ),
    _ => null,
  };
}

_SignatureLeak? _findLeakInElementSignature({
  required Element element,
  required GuardrailContext context,
  required Map<String, Set<String>> publicVisibleTypeOwners,
  required Set<String> forbiddenPublicTypeNames,
}) {
  return switch (element) {
    InterfaceElement() => _findLeakInInterfaceSignature(
      element: element,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
      forbiddenPublicTypeNames: forbiddenPublicTypeNames,
    ),
    ExtensionElement() => _findLeakInExtensionSignature(
      element: element,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
      forbiddenPublicTypeNames: forbiddenPublicTypeNames,
    ),
    TypeAliasElement() => _findLeakInTypeAliasSignature(
      element: element,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
      forbiddenPublicTypeNames: forbiddenPublicTypeNames,
    ),
    ExecutableElement() => findExecutableSignatureLeak<_SignatureLeak>(
      element: element,
      findTypeLeak: ({required type, required sourceElement}) {
        return _findLeakInType(
          type: type,
          sourceElement: sourceElement,
          context: context,
          publicVisibleTypeOwners: publicVisibleTypeOwners,
          forbiddenPublicTypeNames: forbiddenPublicTypeNames,
        );
      },
    ),
    TopLevelVariableElement() || FieldElement() => _findLeakInType(
      type: switch (element) {
        TopLevelVariableElement(:final type) => type,
        FieldElement(:final type) => type,
        _ => throw StateError('Unreachable variable element kind'),
      },
      sourceElement: element,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
      forbiddenPublicTypeNames: forbiddenPublicTypeNames,
    ),
    _ => null,
  };
}

_SignatureLeak? _findLeakInInterfaceSignature({
  required InterfaceElement element,
  required GuardrailContext context,
  required Map<String, Set<String>> publicVisibleTypeOwners,
  required Set<String> forbiddenPublicTypeNames,
}) {
  final typeParameterLeak = findTypeParameterBoundLeak<_SignatureLeak>(
    element: element,
    findTypeLeak: ({required type, required sourceElement}) {
      return _findLeakInType(
        type: type,
        sourceElement: sourceElement,
        context: context,
        publicVisibleTypeOwners: publicVisibleTypeOwners,
        forbiddenPublicTypeNames: forbiddenPublicTypeNames,
      );
    },
  );
  if (typeParameterLeak != null) {
    return typeParameterLeak;
  }

  if (element case ExtensionTypeElement(:final representation)) {
    final representationLeak = _findLeakInType(
      type: representation.type,
      sourceElement: representation,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
      forbiddenPublicTypeNames: forbiddenPublicTypeNames,
    );
    if (representationLeak != null) {
      return representationLeak;
    }
  }

  return _firstLeakInTypes(
    types: <DartType?>[
      element.supertype,
      ...element.mixins,
      ...element.interfaces,
      if (element case MixinElement(:final superclassConstraints))
        ...superclassConstraints,
    ],
    sourceElement: element,
    context: context,
    publicVisibleTypeOwners: publicVisibleTypeOwners,
    forbiddenPublicTypeNames: forbiddenPublicTypeNames,
  );
}

_SignatureLeak? _findLeakInExtensionSignature({
  required ExtensionElement element,
  required GuardrailContext context,
  required Map<String, Set<String>> publicVisibleTypeOwners,
  required Set<String> forbiddenPublicTypeNames,
}) {
  final typeParameterLeak = findTypeParameterBoundLeak<_SignatureLeak>(
    element: element,
    findTypeLeak: ({required type, required sourceElement}) {
      return _findLeakInType(
        type: type,
        sourceElement: sourceElement,
        context: context,
        publicVisibleTypeOwners: publicVisibleTypeOwners,
        forbiddenPublicTypeNames: forbiddenPublicTypeNames,
      );
    },
  );
  if (typeParameterLeak != null) {
    return typeParameterLeak;
  }

  return _findLeakInType(
    type: element.extendedType,
    sourceElement: element,
    context: context,
    publicVisibleTypeOwners: publicVisibleTypeOwners,
    forbiddenPublicTypeNames: forbiddenPublicTypeNames,
  );
}

_SignatureLeak? _findLeakInTypeAliasSignature({
  required TypeAliasElement element,
  required GuardrailContext context,
  required Map<String, Set<String>> publicVisibleTypeOwners,
  required Set<String> forbiddenPublicTypeNames,
}) {
  final typeParameterLeak = findTypeParameterBoundLeak<_SignatureLeak>(
    element: element,
    findTypeLeak: ({required type, required sourceElement}) {
      return _findLeakInType(
        type: type,
        sourceElement: sourceElement,
        context: context,
        publicVisibleTypeOwners: publicVisibleTypeOwners,
        forbiddenPublicTypeNames: forbiddenPublicTypeNames,
      );
    },
  );
  if (typeParameterLeak != null) {
    return typeParameterLeak;
  }

  return _findLeakInType(
    type: element.aliasedType,
    sourceElement: element,
    context: context,
    publicVisibleTypeOwners: publicVisibleTypeOwners,
    forbiddenPublicTypeNames: forbiddenPublicTypeNames,
  );
}

_SignatureLeak? _findLeakInInterfaceMembers({
  required InterfaceElement element,
  required GuardrailContext context,
  required Map<String, Set<String>> publicVisibleTypeOwners,
  required Set<String> forbiddenPublicTypeNames,
}) {
  for (final constructor in element.constructors) {
    if (!_isPublicConstructor(constructor)) {
      continue;
    }
    final leak = findExecutableSignatureLeak<_SignatureLeak>(
      element: constructor,
      findTypeLeak: ({required type, required sourceElement}) {
        return _findLeakInType(
          type: type,
          sourceElement: sourceElement,
          context: context,
          publicVisibleTypeOwners: publicVisibleTypeOwners,
          forbiddenPublicTypeNames: forbiddenPublicTypeNames,
        );
      },
    );
    if (leak != null) {
      return leak;
    }
  }

  return _findLeakInInstanceMembers(
    element: element,
    context: context,
    publicVisibleTypeOwners: publicVisibleTypeOwners,
    forbiddenPublicTypeNames: forbiddenPublicTypeNames,
  );
}

_SignatureLeak? _findLeakInInstanceMembers({
  required InstanceElement element,
  required GuardrailContext context,
  required Map<String, Set<String>> publicVisibleTypeOwners,
  required Set<String> forbiddenPublicTypeNames,
}) {
  for (final field in element.fields) {
    if (field.isSynthetic || !_isPublicNamedElement(field)) {
      continue;
    }
    final leak = _findLeakInType(
      type: field.type,
      sourceElement: field,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
      forbiddenPublicTypeNames: forbiddenPublicTypeNames,
    );
    if (leak != null) {
      return leak;
    }
  }

  for (final getter in element.getters) {
    if (getter.isSynthetic || !_isPublicNamedElement(getter)) {
      continue;
    }
    final leak = findExecutableSignatureLeak<_SignatureLeak>(
      element: getter,
      findTypeLeak: ({required type, required sourceElement}) {
        return _findLeakInType(
          type: type,
          sourceElement: sourceElement,
          context: context,
          publicVisibleTypeOwners: publicVisibleTypeOwners,
          forbiddenPublicTypeNames: forbiddenPublicTypeNames,
        );
      },
    );
    if (leak != null) {
      return leak;
    }
  }

  for (final setter in element.setters) {
    if (setter.isSynthetic || !_isPublicNamedElement(setter)) {
      continue;
    }
    final leak = findExecutableSignatureLeak<_SignatureLeak>(
      element: setter,
      findTypeLeak: ({required type, required sourceElement}) {
        return _findLeakInType(
          type: type,
          sourceElement: sourceElement,
          context: context,
          publicVisibleTypeOwners: publicVisibleTypeOwners,
          forbiddenPublicTypeNames: forbiddenPublicTypeNames,
        );
      },
    );
    if (leak != null) {
      return leak;
    }
  }

  for (final method in element.methods) {
    if (!_isPublicNamedElement(method)) {
      continue;
    }
    final leak = findExecutableSignatureLeak<_SignatureLeak>(
      element: method,
      findTypeLeak: ({required type, required sourceElement}) {
        return _findLeakInType(
          type: type,
          sourceElement: sourceElement,
          context: context,
          publicVisibleTypeOwners: publicVisibleTypeOwners,
          forbiddenPublicTypeNames: forbiddenPublicTypeNames,
        );
      },
    );
    if (leak != null) {
      return leak;
    }
  }

  return null;
}

_SignatureLeak? _findRawCollectionCallbackTypeLeak({
  required DartType? type,
  required Element sourceElement,
}) {
  final callbackType = _asCallbackFunctionType(type);
  if (callbackType == null) {
    return null;
  }

  for (final parameter in callbackType.formalParameters) {
    final collectionTypeName = _findForbiddenSdkCollectionTypeName(
      parameter.type,
    );
    if (collectionTypeName == null) {
      continue;
    }
    return _SignatureLeak.rawCollectionCallbackParameter(
      sourceElement: sourceElement,
      typeName: collectionTypeName,
    );
  }

  return null;
}

FunctionType? _asCallbackFunctionType(DartType? type) {
  final visited = <DartType>{};
  DartType? current = type;

  while (current != null && visited.add(current)) {
    if (current is FunctionType) {
      return current;
    }

    final aliasElement = current.alias?.element;
    current = aliasElement is TypeAliasElement
        ? aliasElement.aliasedType
        : null;
  }

  return null;
}

String? _findForbiddenSdkCollectionTypeName(DartType type) =>
    findFirstResolvedTypeLeak<String>(
      rootType: type,
      classifyType: _classifyForbiddenSdkCollectionTypeName,
      expandAlias: (candidateType) {
        final aliasElement = candidateType.alias?.element;
        if (aliasElement is! TypeAliasElement) {
          return null;
        }
        return aliasElement.aliasedType;
      },
    );

String? _classifyForbiddenSdkCollectionTypeName(DartType type) {
  if (type case InterfaceType(:final element)
      when element.library.isDartCore &&
          _forbiddenCallbackCollectionTypeNames.contains(element.name)) {
    return element.name;
  }
  return null;
}

bool _isPublicNamedElement(Element element) =>
    element_utils.isPublicNamedElement(element);

bool _isPublicConstructor(ConstructorElement element) =>
    element_utils.isPublicConstructor(element);

_SignatureLeak? _firstLeakInTypes({
  required Iterable<DartType?> types,
  required Element sourceElement,
  required GuardrailContext context,
  required Map<String, Set<String>> publicVisibleTypeOwners,
  required Set<String> forbiddenPublicTypeNames,
}) {
  for (final type in types) {
    final leak = _findLeakInType(
      type: type,
      sourceElement: sourceElement,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
      forbiddenPublicTypeNames: forbiddenPublicTypeNames,
    );
    if (leak != null) {
      return leak;
    }
  }
  return null;
}

_SignatureLeak? _findLeakInType({
  required DartType? type,
  required Element sourceElement,
  required GuardrailContext context,
  required Map<String, Set<String>> publicVisibleTypeOwners,
  required Set<String> forbiddenPublicTypeNames,
}) {
  final rawCollectionCallbackLeak = _findRawCollectionCallbackTypeLeak(
    type: type,
    sourceElement: sourceElement,
  );
  if (rawCollectionCallbackLeak != null) {
    return rawCollectionCallbackLeak;
  }

  return findFirstResolvedTypeLeak<_SignatureLeak>(
    rootType: type,
    classifyType: (candidateType) {
      final aliasLeak = _classifyElementLeak(
        element: candidateType.alias?.element,
        sourceElement: sourceElement,
        context: context,
        publicVisibleTypeOwners: publicVisibleTypeOwners,
        forbiddenPublicTypeNames: forbiddenPublicTypeNames,
      );
      if (aliasLeak != null) {
        return aliasLeak;
      }

      return _classifyElementLeak(
        element: candidateType.element,
        sourceElement: sourceElement,
        context: context,
        publicVisibleTypeOwners: publicVisibleTypeOwners,
        forbiddenPublicTypeNames: forbiddenPublicTypeNames,
      );
    },
  );
}

_SignatureLeak? _classifyElementLeak({
  required Element? element,
  required Element sourceElement,
  required GuardrailContext context,
  required Map<String, Set<String>> publicVisibleTypeOwners,
  required Set<String> forbiddenPublicTypeNames,
}) {
  final elementName = element?.displayName ?? '<unnamed>';
  if (forbiddenPublicTypeNames.contains(elementName)) {
    return _SignatureLeak.forbiddenPublicType(
      sourceElement: sourceElement,
      typeName: elementName,
    );
  }

  final ownerRepoRelPath = _repoRelForElement(
    element: element,
    context: context,
  );
  if (ownerRepoRelPath == null) {
    return null;
  }
  if (ownerRepoRelPath.contains('/internal/')) {
    return _SignatureLeak(
      sourceElement: sourceElement,
      typeName: elementName,
      ownerRepoRelPath: ownerRepoRelPath,
      message:
          'public signature hermeticity violation: exported public '
          'signature must not expose $elementName from $ownerRepoRelPath.',
    );
  }
  if (ownerRepoRelPath.startsWith('/lib/src/') &&
      !_isVisibleThroughPublicEntrypoint(
        element: element,
        ownerRepoRelPath: ownerRepoRelPath,
        publicVisibleTypeOwners: publicVisibleTypeOwners,
      )) {
    return _SignatureLeak(
      sourceElement: sourceElement,
      typeName: elementName,
      ownerRepoRelPath: ownerRepoRelPath,
      message:
          'public signature hermeticity violation: exported public '
          'signature must not expose $elementName from $ownerRepoRelPath.',
    );
  }
  return null;
}

Set<String> _forbiddenPublicTypeNamesForLibrary({
  required String? repoRelPath,
}) {
  return switch (repoRelPath) {
    '/lib/src/interactive/scene_controller.dart' ||
    '/lib/src/interactive/scene_controller_interaction.dart' ||
    '/lib/src/interactive/scene_controller_selection.dart' ||
    '/lib/src/interactive/scene_controller_scene.dart' ||
    '/lib/src/view/scene_view_interactive.dart' => mutableCoreTypeNames,
    _ => mutableContractTypeNames,
  };
}

String? _repoRelForElement({
  required Element? element,
  required GuardrailContext context,
}) {
  return element_utils.repoRelPathForElement(
    element: element,
    context: context,
    requireLibPrefix: true,
  );
}

bool _isVisibleThroughPublicEntrypoint({
  required Element? element,
  required String ownerRepoRelPath,
  required Map<String, Set<String>> publicVisibleTypeOwners,
}) {
  if (element == null || !_isPublicVisibleTypeElement(element)) {
    return true;
  }

  final name = element.displayName;
  if (name.isEmpty || !isPublicName(name)) {
    return false;
  }

  final visibleOwners = publicVisibleTypeOwners[name];
  if (visibleOwners == null) {
    return false;
  }
  return visibleOwners.contains(ownerRepoRelPath);
}

final class _SignatureLeak {
  const _SignatureLeak({
    required this.sourceElement,
    required this.typeName,
    required this.message,
    this.ownerRepoRelPath,
  }) : kind = _SignatureLeakKind.hermeticity;

  const _SignatureLeak.forbiddenPublicType({
    required this.sourceElement,
    required this.typeName,
  }) : kind = _SignatureLeakKind.forbiddenPublicType,
       ownerRepoRelPath = null,
       message =
           'public contract violation: exported API must not expose '
           'mutable core or runtime owner types.';

  const _SignatureLeak.rawCollectionCallbackParameter({
    required this.sourceElement,
    required this.typeName,
  }) : kind = _SignatureLeakKind.rawCollectionCallbackParameter,
       ownerRepoRelPath = null,
       message =
           'public signature hermeticity violation: exported callback '
           'parameter types must not expose raw SDK collection '
           'types such as $typeName anywhere in the callback parameter '
           'shape.';

  final Element sourceElement;
  final String typeName;
  final String? ownerRepoRelPath;
  final String message;
  final _SignatureLeakKind kind;
}

enum _SignatureLeakKind {
  hermeticity,
  forbiddenPublicType,
  rawCollectionCallbackParameter,
}
