import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api_registry.dart';
import '../../tool/guardrails/src/public_api_surface.dart';
import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  test(
    'public diagnostics surface exposes only sanitized data shapes',
    () async {
      final registry = readPublicApiRegistryFromYaml(
        File(
          '$repositoryRoot/docs/_registry/public_api_v1.yaml',
        ).readAsStringSync(),
      );
      final surface = await resolvePublicApiSurface();

      expect(_canvasDataExceptionFields(surface), {
        'code': 'CanvasDataErrorCode',
        'message': 'String',
        'path': 'String?',
        'details': 'Map<String, Object?>',
      });
      expect(
        _missingDiagnosticsPublicSurface(
          surface,
          registry.diagnosticsPublicSurface,
        ),
        isEmpty,
      );
      expect(
        _diagnosticsRuntimeLeaks(surface, registry.diagnosticsPublicSurface),
        isEmpty,
      );
    },
  );
}

Map<String, String> _canvasDataExceptionFields(PublicApiSurface surface) {
  final element = surface.exportedElements['CanvasDataException'];
  if (element is! InterfaceElement) {
    throw StateError('CanvasDataException is not an interface element.');
  }

  return Map.fromEntries(
    element.fields.where(_isPublicField).map(_fieldTypeEntry).nonNulls,
  );
}

MapEntry<String, String>? _fieldTypeEntry(FieldElement field) {
  final name = field.name;
  if (name == null) {
    return null;
  }

  return MapEntry(name, field.type.getDisplayString());
}

Set<String> _missingDiagnosticsPublicSurface(
  PublicApiSurface surface,
  Set<String> diagnosticsPublicSurface,
) {
  return diagnosticsPublicSurface.difference(
    surface.exportedElements.keys.toSet(),
  );
}

Set<String> _diagnosticsRuntimeLeaks(
  PublicApiSurface surface,
  Set<String> diagnosticsPublicSurface,
) {
  final leaks = <String>{};
  for (final name in diagnosticsPublicSurface) {
    final element = surface.exportedElements[name];
    if (element == null) {
      continue;
    }
    leaks.addAll(_runtimeLeakTypesInElement(name, element));
  }

  return leaks;
}

Iterable<String> _runtimeLeakTypesInElement(
  String name,
  Element element,
) sync* {
  switch (element) {
    case InterfaceElement():
      yield* _runtimeLeaksInInterface(name, element);
    case TypeAliasElement():
      yield* _runtimeLeakTypeNames(name, element.aliasedType);
    case TopLevelFunctionElement():
      yield* _runtimeLeaksInExecutable(name, element);
    case TopLevelVariableElement():
      yield* _runtimeLeakTypeNames(name, element.type);
  }
}

Iterable<String> _runtimeLeaksInInterface(
  String name,
  InterfaceElement element,
) sync* {
  for (final field in element.fields.where(_isPublicField)) {
    yield* _runtimeLeakTypeNames('$name.${field.name}', field.type);
  }
  for (final getter in element.getters.where(_isPublicExecutable)) {
    yield* _runtimeLeakTypeNames('$name.${getter.name}', getter.returnType);
  }
  for (final method in element.methods.where(_isPublicExecutable)) {
    yield* _runtimeLeaksInExecutable('$name.${method.name}', method);
  }
  for (final constructor in element.constructors.where(_isPublicExecutable)) {
    yield* _runtimeLeaksInExecutable(
      '$name.${constructor.name ?? 'new'}',
      constructor,
    );
  }
}

Iterable<String> _runtimeLeaksInExecutable(
  String name,
  ExecutableElement element,
) sync* {
  yield* _runtimeLeakTypeNames(name, element.returnType);
  for (final parameter in element.formalParameters) {
    yield* _runtimeLeakTypeNames('$name.${parameter.name}', parameter.type);
  }
}

Iterable<String> _runtimeLeakTypeNames(String owner, DartType type) sync* {
  final display = type.getDisplayString();
  if (_isRuntimeLeakType(display)) {
    yield '$owner:$display';
  }
  switch (type) {
    case InterfaceType():
      for (final typeArgument in type.typeArguments) {
        yield* _runtimeLeakTypeNames(owner, typeArgument);
      }
    case FunctionType():
      yield* _runtimeLeakTypeNames(owner, type.returnType);
      for (final parameter in type.formalParameters) {
        yield* _runtimeLeakTypeNames(owner, parameter.type);
      }
    case RecordType():
      for (final field in type.positionalFields) {
        yield* _runtimeLeakTypeNames(owner, field.type);
      }
      for (final field in type.namedFields) {
        yield* _runtimeLeakTypeNames(owner, field.type);
      }
  }
}

bool _isRuntimeLeakType(String type) {
  return type.contains('CanvasRuntime') ||
      type.contains('CanvasDocument') ||
      type.contains('CanvasElement') ||
      type.contains('CanvasLayer') ||
      type.contains('CanvasResource') ||
      type.contains('Image') ||
      type.contains('Offset') ||
      type.contains('Size') ||
      type.contains('Rect') ||
      type.contains('Color');
}

bool _isPublicField(FieldElement field) {
  return field.isPublic && field.nonSynthetic == field;
}

bool _isPublicExecutable(ExecutableElement element) {
  return element.isPublic && element.nonSynthetic == element;
}
