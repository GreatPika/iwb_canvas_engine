import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../guardrail_support/guardrail_context.dart';
import '../guardrail_support/guardrail_path_utils.dart';
import 'public_surface_guardrails.dart';

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
  final result = await context.getLibraryByUriResult(
    'package:${context.packageName}/iwb_canvas_engine.dart',
  );
  if (result is! LibraryElementResult) {
    throw GuardrailToolFailure(
      GuardrailViolation(
        filePath: '/lib/iwb_canvas_engine.dart',
        line: 1,
        message:
            'tool failure: unable to resolve public entrypoint library '
            '(result: ${result.runtimeType})',
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
  final exportedElements = _collectExportedElements(
    library: resolved.element,
    surface: surface,
  )..sort(_compareElementsBySourceOrder);

  for (final element in exportedElements) {
    final leak = _findLeakInExportedElement(
      element: element,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
    );
    if (leak == null) {
      continue;
    }

    final filePath = _repoRelForElement(
      element: leak.sourceElement,
      context: context,
    );
    final line = _lineForElement(leak.sourceElement);
    if (filePath == null || line == null) {
      continue;
    }

    return GuardrailViolation(
      filePath: filePath,
      line: line,
      message:
          'public signature hermeticity violation: exported public signature '
          'must not expose ${leak.typeName} from ${leak.ownerRepoRelPath}.',
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

int _compareElementsBySourceOrder(Element left, Element right) {
  final leftPath = left.firstFragment.libraryFragment?.source.fullName ?? '';
  final rightPath = right.firstFragment.libraryFragment?.source.fullName ?? '';
  final pathCompare = leftPath.compareTo(rightPath);
  if (pathCompare != 0) {
    return pathCompare;
  }
  return left.firstFragment.offset.compareTo(right.firstFragment.offset);
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
}) {
  final signatureLeak = _findLeakInElementSignature(
    element: element,
    context: context,
    publicVisibleTypeOwners: publicVisibleTypeOwners,
  );
  if (signatureLeak != null) {
    return signatureLeak;
  }

  return switch (element) {
    InterfaceElement() => _findLeakInInterfaceMembers(
      element: element,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
    ),
    ExtensionElement() => _findLeakInInstanceMembers(
      element: element,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
    ),
    _ => null,
  };
}

_SignatureLeak? _findLeakInElementSignature({
  required Element element,
  required GuardrailContext context,
  required Map<String, Set<String>> publicVisibleTypeOwners,
}) {
  return switch (element) {
    InterfaceElement() => _findLeakInInterfaceSignature(
      element: element,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
    ),
    ExtensionElement() => _findLeakInExtensionSignature(
      element: element,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
    ),
    TypeAliasElement() => _findLeakInTypeAliasSignature(
      element: element,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
    ),
    ExecutableElement() => _findLeakInExecutableSignature(
      element: element,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
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
    ),
    _ => null,
  };
}

_SignatureLeak? _findLeakInInterfaceSignature({
  required InterfaceElement element,
  required GuardrailContext context,
  required Map<String, Set<String>> publicVisibleTypeOwners,
}) {
  final typeParameterLeak = _findLeakInTypeParameterBounds(
    element: element,
    context: context,
    publicVisibleTypeOwners: publicVisibleTypeOwners,
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
  );
}

_SignatureLeak? _findLeakInExtensionSignature({
  required ExtensionElement element,
  required GuardrailContext context,
  required Map<String, Set<String>> publicVisibleTypeOwners,
}) {
  final typeParameterLeak = _findLeakInTypeParameterBounds(
    element: element,
    context: context,
    publicVisibleTypeOwners: publicVisibleTypeOwners,
  );
  if (typeParameterLeak != null) {
    return typeParameterLeak;
  }

  return _findLeakInType(
    type: element.extendedType,
    sourceElement: element,
    context: context,
    publicVisibleTypeOwners: publicVisibleTypeOwners,
  );
}

_SignatureLeak? _findLeakInTypeAliasSignature({
  required TypeAliasElement element,
  required GuardrailContext context,
  required Map<String, Set<String>> publicVisibleTypeOwners,
}) {
  final typeParameterLeak = _findLeakInTypeParameterBounds(
    element: element,
    context: context,
    publicVisibleTypeOwners: publicVisibleTypeOwners,
  );
  if (typeParameterLeak != null) {
    return typeParameterLeak;
  }

  return _findLeakInType(
    type: element.aliasedType,
    sourceElement: element,
    context: context,
    publicVisibleTypeOwners: publicVisibleTypeOwners,
  );
}

_SignatureLeak? _findLeakInInterfaceMembers({
  required InterfaceElement element,
  required GuardrailContext context,
  required Map<String, Set<String>> publicVisibleTypeOwners,
}) {
  for (final constructor in element.constructors) {
    if (!_isPublicConstructor(constructor)) {
      continue;
    }
    final leak = _findLeakInExecutableSignature(
      element: constructor,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
    );
    if (leak != null) {
      return leak;
    }
  }

  return _findLeakInInstanceMembers(
    element: element,
    context: context,
    publicVisibleTypeOwners: publicVisibleTypeOwners,
  );
}

_SignatureLeak? _findLeakInInstanceMembers({
  required InstanceElement element,
  required GuardrailContext context,
  required Map<String, Set<String>> publicVisibleTypeOwners,
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
    );
    if (leak != null) {
      return leak;
    }
  }

  for (final getter in element.getters) {
    if (getter.isSynthetic || !_isPublicNamedElement(getter)) {
      continue;
    }
    final leak = _findLeakInExecutableSignature(
      element: getter,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
    );
    if (leak != null) {
      return leak;
    }
  }

  for (final setter in element.setters) {
    if (setter.isSynthetic || !_isPublicNamedElement(setter)) {
      continue;
    }
    final leak = _findLeakInExecutableSignature(
      element: setter,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
    );
    if (leak != null) {
      return leak;
    }
  }

  for (final method in element.methods) {
    if (!_isPublicNamedElement(method)) {
      continue;
    }
    final leak = _findLeakInExecutableSignature(
      element: method,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
    );
    if (leak != null) {
      return leak;
    }
  }

  return null;
}

bool _isPublicNamedElement(Element element) {
  final name = element.displayName;
  return name.isNotEmpty && isPublicName(name);
}

bool _isPublicConstructor(ConstructorElement element) {
  final typeName = element.enclosingElement.displayName;
  if (typeName.isEmpty || !isPublicName(typeName)) {
    return false;
  }

  final constructorName = element.name;
  return constructorName == null ||
      constructorName.isEmpty ||
      isPublicName(constructorName);
}

_SignatureLeak? _findLeakInTypeParameterBounds({
  required TypeParameterizedElement element,
  required GuardrailContext context,
  required Map<String, Set<String>> publicVisibleTypeOwners,
}) {
  for (final typeParameter in element.typeParameters) {
    final leak = _findLeakInType(
      type: typeParameter.bound,
      sourceElement: typeParameter,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
    );
    if (leak != null) {
      return leak;
    }
  }
  return null;
}

_SignatureLeak? _findLeakInExecutableSignature({
  required ExecutableElement element,
  required GuardrailContext context,
  required Map<String, Set<String>> publicVisibleTypeOwners,
}) {
  final typeParameterLeak = _findLeakInTypeParameterBounds(
    element: element,
    context: context,
    publicVisibleTypeOwners: publicVisibleTypeOwners,
  );
  if (typeParameterLeak != null) {
    return typeParameterLeak;
  }

  if (element is! ConstructorElement) {
    final returnTypeLeak = _findLeakInType(
      type: element.returnType,
      sourceElement: element,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
    );
    if (returnTypeLeak != null) {
      return returnTypeLeak;
    }
  }

  for (final parameter in element.formalParameters) {
    final leak = _findLeakInType(
      type: parameter.type,
      sourceElement: parameter,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
    );
    if (leak != null) {
      return leak;
    }
  }

  return null;
}

_SignatureLeak? _firstLeakInTypes({
  required Iterable<DartType?> types,
  required Element sourceElement,
  required GuardrailContext context,
  required Map<String, Set<String>> publicVisibleTypeOwners,
}) {
  for (final type in types) {
    final leak = _findLeakInType(
      type: type,
      sourceElement: sourceElement,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
    );
    if (leak != null) {
      return leak;
    }
  }
  return null;
}

int? _lineForElement(Element element) {
  final lineInfo = element.firstFragment.libraryFragment?.lineInfo;
  if (lineInfo == null) {
    return null;
  }
  return lineInfo.getLocation(element.firstFragment.offset).lineNumber;
}

_SignatureLeak? _findLeakInType({
  required DartType? type,
  required Element sourceElement,
  required GuardrailContext context,
  required Map<String, Set<String>> publicVisibleTypeOwners,
}) {
  if (type == null) {
    return null;
  }

  final aliasLeak = _classifyElementLeak(
    element: type.alias?.element,
    sourceElement: sourceElement,
    context: context,
    publicVisibleTypeOwners: publicVisibleTypeOwners,
  );
  if (aliasLeak != null) {
    return aliasLeak;
  }

  final elementLeak = _classifyElementLeak(
    element: type.element,
    sourceElement: sourceElement,
    context: context,
    publicVisibleTypeOwners: publicVisibleTypeOwners,
  );
  if (elementLeak != null) {
    return elementLeak;
  }

  if (type is ParameterizedType) {
    for (final argument in type.typeArguments) {
      final leak = _findLeakInType(
        type: argument,
        sourceElement: sourceElement,
        context: context,
        publicVisibleTypeOwners: publicVisibleTypeOwners,
      );
      if (leak != null) {
        return leak;
      }
    }
  }

  if (type is FunctionType) {
    final returnTypeLeak = _findLeakInType(
      type: type.returnType,
      sourceElement: sourceElement,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
    );
    if (returnTypeLeak != null) {
      return returnTypeLeak;
    }
    for (final parameter in type.formalParameters) {
      final leak = _findLeakInType(
        type: parameter.type,
        sourceElement: sourceElement,
        context: context,
        publicVisibleTypeOwners: publicVisibleTypeOwners,
      );
      if (leak != null) {
        return leak;
      }
    }
    for (final typeParameter in type.typeParameters) {
      final leak = _findLeakInType(
        type: typeParameter.bound,
        sourceElement: sourceElement,
        context: context,
        publicVisibleTypeOwners: publicVisibleTypeOwners,
      );
      if (leak != null) {
        return leak;
      }
    }
  }

  if (type is RecordType) {
    for (final field in type.positionalFields) {
      final leak = _findLeakInType(
        type: field.type,
        sourceElement: sourceElement,
        context: context,
        publicVisibleTypeOwners: publicVisibleTypeOwners,
      );
      if (leak != null) {
        return leak;
      }
    }
    for (final field in type.namedFields) {
      final leak = _findLeakInType(
        type: field.type,
        sourceElement: sourceElement,
        context: context,
        publicVisibleTypeOwners: publicVisibleTypeOwners,
      );
      if (leak != null) {
        return leak;
      }
    }
  }

  if (type is TypeParameterType) {
    return _findLeakInType(
      type: type.bound,
      sourceElement: sourceElement,
      context: context,
      publicVisibleTypeOwners: publicVisibleTypeOwners,
    );
  }

  return null;
}

_SignatureLeak? _classifyElementLeak({
  required Element? element,
  required Element sourceElement,
  required GuardrailContext context,
  required Map<String, Set<String>> publicVisibleTypeOwners,
}) {
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
      typeName: element?.displayName ?? '<unnamed>',
      ownerRepoRelPath: ownerRepoRelPath,
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
      typeName: element?.displayName ?? '<unnamed>',
      ownerRepoRelPath: ownerRepoRelPath,
    );
  }
  return null;
}

String? _repoRelForElement({
  required Element? element,
  required GuardrailContext context,
}) {
  if (element == null) {
    return null;
  }
  final source = element.firstFragment.libraryFragment?.source;
  if (source == null) {
    return null;
  }
  if (source.uri.scheme == 'dart') {
    return null;
  }
  if (source.uri.scheme == 'package') {
    final segments = source.uri.pathSegments;
    if (segments.isNotEmpty && segments.first != context.packageName) {
      return null;
    }
  }
  final absPosixPath = toPosixPath(source.fullName);
  if (!absPosixPath.startsWith('${context.rootAbsPosixPath}/')) {
    return null;
  }
  final repoRelPath = toRepoRelPosixPath(
    absPosixPath: absPosixPath,
    rootAbsPosixPath: context.rootAbsPosixPath,
  );
  return repoRelPath.startsWith('/lib/') ? repoRelPath : null;
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
    required this.ownerRepoRelPath,
  });

  final Element sourceElement;
  final String typeName;
  final String ownerRepoRelPath;
}
