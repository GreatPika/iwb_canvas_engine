import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';
import 'package:yaml/yaml.dart';

final class PublicApiSurface {
  PublicApiSurface._({
    required this.exportedNames,
    required this.exportedElements,
  });

  final Set<String> exportedNames;
  final Map<String, Element> exportedElements;
}

Future<PublicApiSurface> resolvePublicApiSurface() async {
  final collection = AnalysisContextCollection(includedPaths: [repoRoot]);
  try {
    final libraryPath = '$repoRoot/lib/iwb_canvas_engine.dart';
    final context = collection.contextFor(libraryPath);
    final result = await context.currentSession.getResolvedLibrary(libraryPath);
    if (result is! ResolvedLibraryResult) {
      throw StateError('Could not resolve $libraryPath: $result');
    }
    _throwOnErrorDiagnostics(result);
    final namespace = result.element.exportNamespace;
    final elements = namespace.definedNames2;
    final publicEntries = Map.fromEntries(
      elements.entries.where((entry) => _isPublicExportName(entry.key)),
    );

    return PublicApiSurface._(
      exportedNames: publicEntries.keys.toSet(),
      exportedElements: publicEntries,
    );
  } finally {
    await collection.dispose();
  }
}

Set<String> readPublicApiRegistry() {
  final file = File('$repoRoot/docs/_registry/public_api_v1.yaml');
  final parsed = loadYaml(file.readAsStringSync()) as YamlMap;
  final exports = parsed['public_exports'] as YamlList;

  return exports.cast<String>().toSet();
}

Set<String> collectUndefinedPublicTypeReferences(PublicApiSurface surface) {
  final visitor = _PublicTypeReferenceVisitor(surface.exportedNames);

  for (final element in surface.exportedElements.values) {
    visitor.visitExportedElement(element);
  }

  return visitor.violations;
}

String get repoRoot => Directory.current.absolute.path;

bool _isPublicExportName(String name) {
  return !name.startsWith('_') && !name.endsWith('=');
}

void _throwOnErrorDiagnostics(ResolvedLibraryResult result) {
  final errors = result.units
      .expand((unit) => unit.diagnostics)
      .where((diagnostic) {
        return diagnostic.diagnosticCode.severity == DiagnosticSeverity.ERROR;
      })
      .map((diagnostic) {
        return '${diagnostic.source.fullName}:${diagnostic.offset}: '
            '${diagnostic.message}';
      })
      .toList();

  if (errors.isNotEmpty) {
    throw StateError(errors.join('\n'));
  }
}

final class _PublicTypeReferenceVisitor {
  _PublicTypeReferenceVisitor(this.publicNames);

  final Set<String> publicNames;
  final Set<String> violations = {};
  final Set<DartType> _visitedTypes = {};

  void visitExportedElement(Element element) {
    switch (element) {
      case InterfaceElement():
        _visitInterfaceElement(element);
      case TypeAliasElement():
        _visitType(element.aliasedType);
      case TopLevelFunctionElement():
        _visitExecutable(element);
      case TopLevelVariableElement():
        _visitType(element.type);
    }
  }

  void _visitInterfaceElement(InterfaceElement element) {
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
    final uri = element.library.uri.toString();
    if (!_isApprovedExternalType(uri) && !publicNames.contains(name)) {
      violations.add(type.getDisplayString());
    }
    for (final typeArgument in type.typeArguments) {
      _visitType(typeArgument);
    }
  }

  void _visitFunctionType(FunctionType type) {
    _visitType(type.returnType);
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
  return field.isPublic && !field.isSynthetic;
}

bool _isPublicExecutable(ExecutableElement element) {
  return element.isPublic && !element.isSynthetic;
}

bool _isApprovedExternalType(String? uri) {
  return uri == null ||
      uri == 'dart:async' ||
      uri == 'dart:core' ||
      uri == 'dart:typed_data' ||
      uri == 'dart:ui' ||
      uri == 'package:flutter/foundation.dart' ||
      uri == 'package:flutter/widgets.dart' ||
      uri.startsWith('package:flutter/src/foundation/') ||
      uri.startsWith('package:flutter/src/widgets/');
}
