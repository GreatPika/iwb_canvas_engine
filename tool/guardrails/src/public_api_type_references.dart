import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

Set<String> collectUndefinedTypeReferences({
  required Iterable<Element> exportedElements,
  required Iterable<String> exportedNamedExtensionNames,
  required Set<String> publicNames,
  required Set<String> approvedExternalTypeKeys,
}) {
  final visitor = _PublicTypeReferenceVisitor(
    publicNames: publicNames,
    approvedExternalTypeKeys: approvedExternalTypeKeys,
  );

  for (final name in exportedNamedExtensionNames) {
    visitor.rejectNamedExtension(name);
  }

  for (final element in exportedElements) {
    visitor.visitExportedElement(element);
  }

  return visitor.violations;
}

// The analyzer type model is the boundary this visitor validates, so the class
// intentionally touches several analyzer element/type variants in one traversal.
// ignore: metrics
final class _PublicTypeReferenceVisitor {
  _PublicTypeReferenceVisitor({
    required this.publicNames,
    required this.approvedExternalTypeKeys,
  });

  final Set<String> publicNames;
  final Set<String> approvedExternalTypeKeys;
  final Set<String> violations = {};
  final Set<DartType> _visitedTypes = {};

  void rejectNamedExtension(String name) {
    violations.add('exported named extension $name');
  }

  void visitExportedElement(Element element) {
    switch (element) {
      case InterfaceElement():
        _visitInterfaceElement(element);
      case TypeAliasElement():
        _visitTypeAliasElement(element);
      case TopLevelFunctionElement():
        _visitExecutable(element);
      case TopLevelVariableElement():
        _visitType(element.type);
    }
  }

  void _visitTypeAliasElement(TypeAliasElement element) {
    for (final typeParameter in element.typeParameters) {
      _visitNullableType(typeParameter.bound);
    }
    _visitType(element.aliasedType);
  }

  void _visitInterfaceElement(InterfaceElement element) {
    _visitDeclaredSupertypes(element);
    for (final typeParameter in element.typeParameters) {
      _visitNullableType(typeParameter.bound);
    }
    for (final field in element.fields.where(_isPublicField)) {
      _visitType(field.type);
    }
    for (final getter in element.getters.where(_isPublicExecutable)) {
      _visitExecutable(getter);
    }
    for (final method in element.methods.where(_isPublicExecutable)) {
      _visitExecutable(method);
    }
    for (final constructor in element.constructors.where(_isPublicExecutable)) {
      _visitExecutable(constructor);
    }
  }

  void _visitDeclaredSupertypes(InterfaceElement element) {
    _visitNullableType(element.supertype);
    for (final type in element.interfaces) {
      _visitType(type);
    }
    for (final type in element.mixins) {
      _visitType(type);
    }
    if (element case MixinElement(:final superclassConstraints)) {
      for (final type in superclassConstraints) {
        _visitType(type);
      }
    }
  }

  void _visitExecutable(FunctionTypedElement element) {
    _visitType(element.returnType);
    for (final typeParameter in element.typeParameters) {
      _visitNullableType(typeParameter.bound);
    }
    for (final parameter in element.formalParameters) {
      _visitType(parameter.type);
    }
  }

  void _visitType(DartType type) {
    if (!_visitedTypes.add(type)) {
      return;
    }

    switch (type) {
      case InterfaceType():
        _visitInterfaceType(type);
      case FunctionType():
        _visitFunctionType(type);
      case RecordType():
        _visitRecordType(type);
      case TypeParameterType():
        break;
      case InvalidType():
        violations.add(type.getDisplayString());
    }
  }

  void _visitNullableType(DartType? type) {
    if (type != null) {
      _visitType(type);
    }
  }

  void _visitInterfaceType(InterfaceType type) {
    final element = type.element;
    final name = element.name;
    if (!_isApprovedExternalType(element, approvedExternalTypeKeys) &&
        !publicNames.contains(name)) {
      violations.add(type.getDisplayString());
    }
    for (final typeArgument in type.typeArguments) {
      _visitType(typeArgument);
    }
  }

  void _visitFunctionType(FunctionType type) {
    _visitType(type.returnType);
    for (final typeParameter in type.typeParameters) {
      _visitNullableType(typeParameter.bound);
    }
    for (final parameter in type.formalParameters) {
      _visitType(parameter.type);
    }
  }

  void _visitRecordType(RecordType type) {
    for (final field in type.positionalFields) {
      _visitType(field.type);
    }
    for (final field in type.namedFields) {
      _visitType(field.type);
    }
  }
}

bool _isPublicField(FieldElement field) {
  return field.isPublic && field.nonSynthetic == field;
}

bool _isPublicExecutable(ExecutableElement element) {
  return element.isPublic && element.nonSynthetic == element;
}

bool _isApprovedExternalType(
  InterfaceElement element,
  Set<String> approvedExternalTypeKeys,
) {
  final uri = element.library.uri.toString();

  return uri == 'dart:async' ||
      uri == 'dart:core' ||
      uri == 'dart:typed_data' ||
      uri == 'dart:ui' ||
      uri == 'package:flutter/foundation.dart' ||
      uri == 'package:flutter/widgets.dart' ||
      _isApprovedFlutterSrcType(element, approvedExternalTypeKeys);
}

bool _isApprovedFlutterSrcType(
  InterfaceElement element,
  Set<String> approvedExternalTypeKeys,
) {
  final uri = element.library.uri.toString();

  // Analyzer reports many public Flutter declarations by their defining src
  // URI, so approval is based on public barrel export membership.
  return uri.startsWith('package:flutter/src/') &&
      approvedExternalTypeKeys.contains(externalTypeKey(element));
}

String externalTypeKey(InterfaceElement element) {
  return '${element.library.uri}#${element.name}';
}
