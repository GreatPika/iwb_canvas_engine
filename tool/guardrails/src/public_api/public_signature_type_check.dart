import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/source.dart';

import 'resolved_public_surface_reader.dart';

List<String> resolvedPublicTypeViolations(ResolvedPublicSurface surface) {
  return _PublicSignatureTypeCheck(surface).run();
}

// Public signature validation is one cohesive analyzer traversal; splitting it
// by element kind obscures the first-leak search order without adding ownership.
// ignore: metrics
final class _PublicSignatureTypeCheck {
  _PublicSignatureTypeCheck(this.surface);

  final ResolvedPublicSurface surface;

  late final Map<String, Set<String>> publicTypeOwnersByName =
      surface.publicTypeOwnersByName;

  List<String> run() {
    final violations = <String>[...surface.typeDiagnostics];

    for (final exportedElement in surface.elements) {
      final invalidType = _findInvalidTypeInExportedElement(
        exportedElement.element,
      );
      if (invalidType != null) {
        violations.add(_formatViolation(exportedElement, invalidType));
      }
    }

    return violations;
  }

  String _formatViolation(
    ResolvedPublicElement exportedElement,
    _InvalidPublicType invalidType,
  ) {
    final path = pathWithoutLeadingSlash(exportedElement.ownerPath);
    return 'Undefined public signature type ${invalidType.name} in $path';
  }

  _InvalidPublicType? _findInvalidTypeInExportedElement(Element element) {
    return switch (element) {
      InterfaceElement() => _findInvalidTypeInInterface(element),
      TypeAliasElement() => _findInvalidTypeInTypeAlias(element),
      ExecutableElement() => _findInvalidTypeInExecutable(element),
      TopLevelVariableElement() => _findInvalidPublicType(element.type),
      _ => null,
    };
  }

  _InvalidPublicType? _findInvalidTypeInInterface(InterfaceElement element) {
    return _findInvalidTypeInTypeParameterBounds(element.typeParameters) ??
        _findInvalidTypeInSupertypes(element) ??
        _findInvalidTypeInConstructors(element.constructors) ??
        _findInvalidTypeInInstanceMembers(element);
  }

  _InvalidPublicType? _findInvalidTypeInSupertypes(InterfaceElement element) {
    return _findFirstInvalidPublicType(<DartType?>[
      element.supertype,
      ...element.interfaces,
      ...element.mixins,
    ]);
  }

  _InvalidPublicType? _findInvalidTypeInTypeAlias(TypeAliasElement element) {
    return _findInvalidTypeInTypeParameterBounds(element.typeParameters) ??
        _findInvalidPublicType(element.aliasedType);
  }

  _InvalidPublicType? _findInvalidTypeInExecutable(ExecutableElement element) {
    final typeParameterLeak = _findInvalidTypeInTypeParameterBounds(
      element.typeParameters,
    );
    if (typeParameterLeak != null) {
      return typeParameterLeak;
    }

    final returnTypeLeak = element is ConstructorElement
        ? null
        : _findInvalidPublicType(element.returnType);
    if (returnTypeLeak != null) {
      return returnTypeLeak;
    }

    return _findFirstInvalidPublicType(
      element.formalParameters.map((parameter) => parameter.type),
    );
  }

  _InvalidPublicType? _findInvalidTypeInConstructors(
    List<ConstructorElement> constructors,
  ) {
    for (final constructor in constructors) {
      if (!_isPublicConstructor(constructor)) {
        continue;
      }

      final leak = _findInvalidTypeInExecutable(constructor);
      if (leak != null) {
        return leak;
      }
    }

    return null;
  }

  _InvalidPublicType? _findInvalidTypeInInstanceMembers(
    InstanceElement element,
  ) {
    for (final field in element.fields) {
      if (field.isSynthetic || !_isPublicNamedElement(field)) {
        continue;
      }

      final leak = _findInvalidPublicType(field.type);
      if (leak != null) {
        return leak;
      }
    }

    final accessorLeak =
        _findInvalidTypeInAccessors(element.getters) ??
        _findInvalidTypeInAccessors(element.setters);
    if (accessorLeak != null) {
      return accessorLeak;
    }

    for (final method in element.methods) {
      if (!_isPublicNamedElement(method)) {
        continue;
      }

      final leak = _findInvalidTypeInExecutable(method);
      if (leak != null) {
        return leak;
      }
    }

    return null;
  }

  _InvalidPublicType? _findInvalidTypeInAccessors(
    List<PropertyAccessorElement> accessors,
  ) {
    for (final accessor in accessors) {
      if (accessor.isSynthetic || !_isPublicNamedElement(accessor)) {
        continue;
      }

      final leak = _findInvalidTypeInExecutable(accessor);
      if (leak != null) {
        return leak;
      }
    }

    return null;
  }

  _InvalidPublicType? _findInvalidTypeInTypeParameterBounds(
    List<TypeParameterElement> typeParameters,
  ) {
    return _findFirstInvalidPublicType(
      typeParameters.map((parameter) => parameter.bound),
    );
  }

  _InvalidPublicType? _findFirstInvalidPublicType(Iterable<DartType?> types) {
    for (final type in types) {
      final leak = _findInvalidPublicType(type);
      if (leak != null) {
        return leak;
      }
    }

    return null;
  }

  _InvalidPublicType? _findInvalidPublicType(DartType? rootType) {
    return _PublicTypeReferenceWalker(publicTypeOwnersByName).find(rootType);
  }
}

// Recursive DartType traversal needs the analyzer type variants and visited
// set together; smaller classes would only route through the same state.
// ignore: metrics
final class _PublicTypeReferenceWalker {
  _PublicTypeReferenceWalker(this.publicTypeOwnersByName);

  final Map<String, Set<String>> publicTypeOwnersByName;
  final Set<DartType> _visited = <DartType>{};

  _InvalidPublicType? find(DartType? rootType) => _visit(rootType);

  _InvalidPublicType? _visit(DartType? type) {
    if (type == null || !_visited.add(type)) {
      return null;
    }

    if (type is DynamicType || type is VoidType || type is NeverType) {
      return null;
    }

    if (type is TypeParameterType) {
      return _visit(type.bound);
    }

    return _classifyAliasOrElement(type) ??
        _visitComposedType(type) ??
        _unknownTypeLeak(type);
  }

  _InvalidPublicType? _classifyAliasOrElement(DartType type) {
    return _classifyPublicType(type.alias?.element, type) ??
        _classifyPublicType(type.element, type);
  }

  _InvalidPublicType? _visitComposedType(DartType type) {
    if (type is ParameterizedType) {
      return _findFirst(type.typeArguments);
    }

    if (type is FunctionType) {
      return _visit(type.returnType) ??
          _findFirst(type.formalParameters.map((parameter) => parameter.type));
    }

    if (type is RecordType) {
      return _findFirst(type.positionalFields.map((field) => field.type)) ??
          _findFirst(type.namedFields.map((field) => field.type));
    }

    return null;
  }

  _InvalidPublicType? _findFirst(Iterable<DartType?> types) {
    for (final type in types) {
      final leak = _visit(type);
      if (leak != null) {
        return leak;
      }
    }

    return null;
  }

  _InvalidPublicType? _unknownTypeLeak(DartType type) {
    if (type.element == null && type.alias?.element == null) {
      return _InvalidPublicType(type.getDisplayString());
    }

    return null;
  }

  _InvalidPublicType? _classifyPublicType(
    Element? element,
    DartType sourceType,
  ) {
    if (element == null || element.displayName.isEmpty) {
      return null;
    }

    final source = element.firstFragment.libraryFragment?.source;
    if (source == null) {
      return _InvalidPublicType(sourceType.getDisplayString());
    }

    if (_isAllowedExternalSource(source)) {
      return null;
    }

    return _localTypeViolation(element, source);
  }

  _InvalidPublicType? _localTypeViolation(Element element, Source source) {
    final ownerPath = repoRelativePathForElement(
      element: element,
      packageName: packageNameForElementUri(source.uri),
      rootAbsPosixPath: rootPathForElementSource(source.fullName),
    );

    final visibleOwners = publicTypeOwnersByName[element.displayName];
    if (ownerPath != null && visibleOwners?.contains(ownerPath) == true) {
      return null;
    }

    return _InvalidPublicType(element.displayName);
  }
}

bool _isAllowedExternalSource(Source source) {
  final uri = source.uri;
  if (_isAllowedSkyEngineFile(source.fullName)) {
    return true;
  }

  if (uri.scheme == 'dart') {
    return _allowedDartLibraries.contains(uri.toString());
  }

  return uri.scheme == 'package' && _isAllowedFlutterSource(uri.path);
}

bool _isAllowedFlutterSource(String packagePath) {
  return packagePath.startsWith('flutter/src/widgets/') ||
      packagePath.startsWith('flutter/src/foundation/') ||
      packagePath == 'flutter/widgets.dart' ||
      packagePath == 'flutter/foundation.dart';
}

bool _isAllowedSkyEngineFile(String fullName) {
  final path = toPosixPath(fullName);
  return path.contains('/sky_engine/lib/core/') ||
      path.contains('/sky_engine/lib/typed_data/') ||
      path.contains('/sky_engine/lib/ui/');
}

bool _isPublicNamedElement(Element element) {
  final name = element.displayName;
  return name.isNotEmpty && !name.startsWith('_');
}

bool _isPublicConstructor(ConstructorElement constructor) {
  final className = constructor.enclosingElement.displayName;
  final constructorName = constructor.name ?? '';
  return !className.startsWith('_') &&
      (constructorName.isEmpty ||
          constructorName == 'new' ||
          !constructorName.startsWith('_'));
}

const Set<String> _allowedDartLibraries = <String>{
  'dart:core',
  'dart:ui',
  'dart:typed_data',
};

final class _InvalidPublicType {
  const _InvalidPublicType(this.name);

  final String name;
}
