import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

import 'guardrail_violation.dart';
import 'public_api_surface.dart';
import 'repository_paths.dart';

Future<List<GuardrailViolation>> checkPublicSignatureShape({
  String? libraryPath,
}) async {
  final surface = await resolvePublicApiSurface(libraryPath: libraryPath);
  final checker = _PublicSignatureShapeChecker();

  for (final element in surface.exportedElements.values) {
    checker.visitExportedElement(element);
  }

  return [
    for (final message in checker.messages)
      GuardrailViolation(
        guardrailId: 'api.public_signature_shape',
        path: _displayPath(libraryPath),
        message: message,
      ),
  ];
}

String _displayPath(String? libraryPath) {
  if (libraryPath == null) {
    return 'lib/iwb_canvas_engine.dart';
  }

  final prefix = '$repositoryRoot/';

  return libraryPath.startsWith(prefix)
      ? libraryPath.substring(prefix.length)
      : libraryPath;
}

// Public signature traversal intentionally stays in one analyzer-backed checker
// so aliases, functions, records, generics, and return-shape policy are audited
// through the same resolved surface walk.
// ignore: metrics
final class _PublicSignatureShapeChecker {
  final Set<String> messages = {};
  final Set<DartType> _visitedTypes = {};

  void visitExportedElement(Element element) {
    switch (element) {
      case InterfaceElement():
        _visitInterfaceElement(element);
      case TypeAliasElement():
        _visitTypeParameterBounds(element.typeParameters);
        _visitNullableType(element.aliasedType);
      case TopLevelFunctionElement():
        _visitReturnType(element.returnType);
        _visitParameters(element.formalParameters);
      case TopLevelVariableElement():
        _visitType(element.type);
    }
  }

  void _visitInterfaceElement(InterfaceElement element) {
    _visitTypeParameterBounds(element.typeParameters);
    for (final field in element.fields.where(_isPublicField)) {
      _visitType(field.type);
    }
    for (final getter in element.getters.where(_isPublicExecutable)) {
      _visitReturnType(getter.returnType);
    }
    for (final method in element.methods.where(_isPublicExecutable)) {
      _visitReturnType(method.returnType);
      _visitParameters(method.formalParameters);
    }
    for (final constructor in element.constructors.where(_isPublicExecutable)) {
      _visitParameters(constructor.formalParameters);
    }
  }

  void _visitParameters(List<FormalParameterElement> parameters) {
    for (final parameter in parameters) {
      _visitType(parameter.type);
    }
  }

  void _visitTypeParameterBounds(List<TypeParameterElement> typeParameters) {
    for (final typeParameter in typeParameters) {
      _visitNullableType(typeParameter.bound);
    }
  }

  void _visitReturnType(DartType type) {
    _rejectNullableAsyncOrContainerReturn(type);
    _visitType(type);
  }

  void _visitNullableType(DartType? type) {
    if (type != null) {
      _visitType(type);
    }
  }

  // The Dart type model has several concrete variants; keeping the dispatch in
  // one method makes the rejection policy easier to audit than split visitors.
  // ignore: metrics
  void _visitType(DartType type) {
    if (!_visitedTypes.add(type)) {
      return;
    }
    if (_isFutureOr(type)) {
      messages.add('public signatures must not use ${type.getDisplayString()}');
    }

    switch (type) {
      case DynamicType():
        messages.add('public signatures must not expose dynamic');
      case InterfaceType():
        for (final typeArgument in type.typeArguments) {
          _visitType(typeArgument);
        }
      case FunctionType():
        _visitReturnType(type.returnType);
        _visitTypeParameterBounds(type.typeParameters);
        _visitParameters(type.formalParameters);
      case RecordType():
        for (final field in type.positionalFields) {
          _visitType(field.type);
        }
        for (final field in type.namedFields) {
          _visitType(field.type);
        }
      case TypeParameterType():
        break;
      case InvalidType():
        messages.add('public signatures must not expose invalid type');
    }
  }

  void _rejectNullableAsyncOrContainerReturn(DartType type) {
    if (type.nullabilitySuffix != NullabilitySuffix.question) {
      return;
    }
    if (_isAsyncOrContainer(type)) {
      messages.add(
        'public signatures must not return nullable '
        'async/container type ${type.getDisplayString()}',
      );
    }
  }

  bool _isAsyncOrContainer(DartType type) {
    final baseName = _interfaceName(type);

    return baseName == 'Future' ||
        baseName == 'Stream' ||
        baseName == 'List' ||
        baseName == 'Map' ||
        baseName == 'Set';
  }

  bool _isFutureOr(DartType type) {
    return type.getDisplayString().startsWith('FutureOr<');
  }

  String? _interfaceName(DartType type) {
    return switch (type) {
      InterfaceType(:final element) => element.name,
      _ => null,
    };
  }
}

bool _isPublicField(FieldElement field) {
  return field.isPublic && field.nonSynthetic == field;
}

bool _isPublicExecutable(ExecutableElement element) {
  return element.isPublic && element.nonSynthetic == element;
}
