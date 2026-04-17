import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../support/guardrail_context.dart';
import '../../support/guardrail_path_utils.dart';
import '../../core/guardrail_element_utils.dart' as element_utils;
import '../../core/resolved_type_leak_traversal.dart';
import '../../core/signature_leak_support.dart';
import '../../core/guardrail_violation.dart';
import 'public_surface_rules.dart';

Future<List<GuardrailViolation>> runPublicSignatureHermeticityGuardrails({
  required GuardrailContext context,
  required Map<String, ExportedLibrarySurface> exportedSurfaces,
}) async {
  final violations = <GuardrailViolation>[];
  final publicVisibleTypeOwners = await _loadPublicVisibleTypeOwners(context);
  final exportedFiles = exportedSurfaces.keys.toList(growable: false)..sort();

  for (final repoRel in exportedFiles) {
    final library = await _resolveExportedLibrary(
      context: context,
      repoRel: repoRel,
    );
    if (library == null) {
      continue;
    }

    final violation = _scanResolvedLibraryForHermeticity(
      context: context,
      resolved: library,
      surface: exportedSurfaces[repoRel]!,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
    );
    if (violation != null) {
      violations.add(violation);
      return violations;
    }
  }

  return violations;
}

Future<Map<String, Set<String>>> _loadPublicVisibleTypeOwners(
  GuardrailContext context,
) async {
  final result = await context.getResolvedLibraryResult(
    context.publicEntrypointAbsPath,
  );
  if (result == null) {
    throw GuardrailToolFailure(
      GuardrailViolation(
        filePath: '/lib/iwb_canvas_engine.dart',
        line: 1,
        message:
            'tool failure: unable to resolve public entrypoint library '
            '(result: null)',
      ),
    );
  }

  final ownersByName = <String, Set<String>>{};
  for (final entry in result.element.exportNamespace.definedNames2.entries) {
    final element = entry.value;
    if (!_isPublicVisibleTypeElement(element)) {
      continue;
    }
    final ownerRepoRelPath = _repoRelForElement(
      element: element,
      context: context,
    );
    if (ownerRepoRelPath == null) {
      continue;
    }
    ownersByName.putIfAbsent(entry.key, () => <String>{}).add(ownerRepoRelPath);
  }
  return ownersByName;
}

Future<ResolvedLibraryResult?> _resolveExportedLibrary({
  required GuardrailContext context,
  required String repoRel,
}) {
  final file = File(posixJoin(context.root.path, repoRel.substring(1)));
  if (!file.existsSync()) {
    return Future<ResolvedLibraryResult?>.value(null);
  }
  return context.getResolvedLibraryResult(file.absolute.path);
}

GuardrailViolation? _scanResolvedLibraryForHermeticity({
  required GuardrailContext context,
  required ResolvedLibraryResult resolved,
  required ExportedLibrarySurface surface,
  required Map<String, Set<String>> publicVisibleTypeOwners,
}) {
  final forbiddenPublicTypeNames = _forbiddenPublicTypeNamesForLibrary(
    repoRelPath: surface.repoRelPath,
  );
  final exportedElements = _collectExportedElements(
    library: resolved.element,
    surface: surface,
  )..sort(element_utils.compareElementsBySourceOrder);

  for (final element in exportedElements) {
    final leak = _findLeakInExportedElement(
      element: element,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
      forbiddenPublicTypeNames: forbiddenPublicTypeNames,
    );
    if (leak == null) {
      continue;
    }

    final filePath = _repoRelForElement(
      element: leak.sourceElement,
      context: context,
    );
    final line = element_utils.lineForElement(leak.sourceElement);
    if (filePath == null || line == null) {
      continue;
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
      },
    );
  }

  return null;
}

List<Element> _collectExportedElements({
  required LibraryElement library,
  required ExportedLibrarySurface surface,
}) {
  return <Element>[
    ...library.classes.where(
      (element) => _exportsNamedElement(element, surface: surface),
    ),
    ...library.enums.where(
      (element) => _exportsNamedElement(element, surface: surface),
    ),
    ...library.mixins.where(
      (element) => _exportsNamedElement(element, surface: surface),
    ),
    ...library.extensions.where(
      (element) => _exportsExtensionElement(element, surface: surface),
    ),
    ...library.extensionTypes.where(
      (element) => _exportsNamedElement(element, surface: surface),
    ),
    ...library.typeAliases.where(
      (element) => _exportsNamedElement(element, surface: surface),
    ),
    ...library.topLevelFunctions.where(
      (element) => _exportsNamedElement(element, surface: surface),
    ),
    ...library.topLevelVariables.where(
      (element) => _exportsNamedElement(element, surface: surface),
    ),
    ...library.getters.where(
      (element) =>
          !element.isSynthetic &&
          _exportsNamedElement(element, surface: surface),
    ),
    ...library.setters.where(
      (element) =>
          !element.isSynthetic &&
          _exportsNamedElement(element, surface: surface),
    ),
  ];
}

bool _exportsNamedElement(
  Element element, {
  required ExportedLibrarySurface surface,
}) {
  final name = element.displayName;
  return name.isNotEmpty &&
      isPublicName(name) &&
      surface.exportsTopLevelName(name);
}

bool _exportsExtensionElement(
  ExtensionElement element, {
  required ExportedLibrarySurface surface,
}) {
  final name = element.displayName;
  return name.isEmpty
      ? surface.exportsUnnamedExtensions
      : isPublicName(name) && surface.exportsTopLevelName(name);
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

Set<String> _forbiddenPublicTypeNamesForLibrary({required String repoRelPath}) {
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

  final Element sourceElement;
  final String typeName;
  final String? ownerRepoRelPath;
  final String message;
  final _SignatureLeakKind kind;
}

enum _SignatureLeakKind { hermeticity, forbiddenPublicType }
