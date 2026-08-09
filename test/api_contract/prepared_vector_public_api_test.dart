import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api_surface.dart';
import '../../tool/guardrails/src/repository_paths.dart';

const _fixturePath =
    'test/api_contract/fixtures/prepared_vector_public_api_fixture.dart';

void main() {
  test('external root barrel exposes only prepared vector use', () async {
    await expectLater(_expectPermittedUseCompiles(), completes);
  });

  test('external root barrel rejects each prepared vector internal', () async {
    for (final source in _forbiddenConsumerSources) {
      final analyze = await _analyzeConsumerSource(source);

      expect(analyze.exitCode, isNot(0), reason: _processOutput(analyze));
    }
  });

  test('resolved root surface keeps prepared vector opaque', () async {
    final surface = await resolvePublicApiSurface();
    final preparedVector = surface.exportedElements['CanvasPreparedVector'];
    final prepare = surface.exportedElements['prepareVector'];

    expect(preparedVector, isA<ClassElement>());
    expect(prepare, isA<TopLevelFunctionElement>());

    final vectorClass = preparedVector as ClassElement;
    final prepareVector = prepare as TopLevelFunctionElement;
    _expectPreparedVectorMembers(vectorClass);
    _expectPrepareVectorSignature(prepareVector, vectorClass);
    _expectNoForbiddenPreparedVectorSurfaceTypes(
      surface,
      vectorClass,
      prepareVector,
    );
  });
}

void _expectNoForbiddenPreparedVectorSurfaceTypes(
  PublicApiSurface surface,
  ClassElement vectorClass,
  TopLevelFunctionElement prepareVector,
) {
  final visitor = _PreparedVectorSurfaceTypeVisitor(
    vectorClass: vectorClass,
    prepareVector: prepareVector,
  );
  for (final entry in surface.exportedElements.entries) {
    visitor.visitRootExport(entry.key, entry.value);
  }

  expect(visitor.violations, isEmpty);
}

void _expectPreparedVectorMembers(ClassElement vectorClass) {
  _expectNoPublicPreparedVectorConstructors(vectorClass);
  _expectPreparedVectorMemberSurface(vectorClass);
}

void _expectNoPublicPreparedVectorConstructors(ClassElement vectorClass) {
  expect(
    vectorClass.constructors.where((constructor) => constructor.isPublic),
    isEmpty,
  );
}

void _expectPreparedVectorMemberSurface(ClassElement vectorClass) {
  _expectOnlyIntrinsicSizeField(vectorClass);
  _expectNoPublicPreparedVectorAccessors(vectorClass);
  _expectOnlyDisposeMethod(vectorClass);
}

void _expectOnlyIntrinsicSizeField(ClassElement vectorClass) {
  final publicFields = _publicFields(vectorClass);
  expect(publicFields.map((field) => field.name), ['intrinsicSize']);
  _expectInterfaceType(
    publicFields.single.type,
    name: 'Size',
    libraryUri: 'dart:ui',
  );
}

void _expectNoPublicPreparedVectorAccessors(ClassElement vectorClass) {
  expect(_publicGetters(vectorClass), isEmpty);
  expect(_publicSetters(vectorClass), isEmpty);
}

void _expectOnlyDisposeMethod(ClassElement vectorClass) {
  expect(_publicMethods(vectorClass).map((method) => method.name), ['dispose']);

  final dispose = vectorClass.getMethod('dispose');
  expect(dispose, isA<MethodElement>());
  final disposeMethod = dispose as MethodElement;
  expect(disposeMethod.isPublic, isTrue);
  expect(disposeMethod.formalParameters, isEmpty);
  expect(disposeMethod.returnType.getDisplayString(), 'void');
}

List<FieldElement> _publicFields(InterfaceElement vectorClass) {
  return vectorClass.fields
      .where((field) => field.isPublic && field.nonSynthetic == field)
      .toList();
}

List<GetterElement> _publicGetters(ClassElement vectorClass) {
  return vectorClass.getters
      .where((getter) => getter.isPublic && getter.nonSynthetic == getter)
      .toList();
}

List<SetterElement> _publicSetters(ClassElement vectorClass) {
  return vectorClass.setters
      .where((setter) => setter.isPublic && setter.nonSynthetic == setter)
      .toList();
}

List<MethodElement> _publicMethods(ClassElement vectorClass) {
  return vectorClass.methods
      .where((method) => method.isPublic && method.nonSynthetic == method)
      .toList();
}

// The resolved traversal must keep all exported element and type variants in
// one visitor so aliases cannot bypass the same Picture/upstream boundary.
// ignore: coupling-between-object-classes, weighted-methods-per-class
final class _PreparedVectorSurfaceTypeVisitor {
  _PreparedVectorSurfaceTypeVisitor({
    required this.vectorClass,
    required this.prepareVector,
  });

  final ClassElement vectorClass;
  final TopLevelFunctionElement prepareVector;
  final Set<(DartType, bool)> _visitedTypes = {};
  final Set<String> violations = {};

  void visitRootExport(String name, Element element) {
    switch (element) {
      case InterfaceElement():
        _visitInterfaceElement(name, element);
      case TypeAliasElement():
        _visitTypeAlias(name, element);
      case TopLevelFunctionElement():
        _visitExecutable(
          name,
          element,
          permitsPreparedVectorInReturn: identical(element, prepareVector),
        );
      case TopLevelVariableElement():
        _visitType(name, element.type, permitsPreparedVector: false);
      case ExtensionElement():
        _visitExtension(name, element);
    }
  }

  // Fields and members need one traversal so the two explicit return
  // allowances cannot accidentally leak into every exported interface member.
  // ignore: halstead-volume
  void _visitInterfaceElement(String owner, InterfaceElement element) {
    _visitNullableType(owner, element.supertype, permitsPreparedVector: false);
    for (final type in [...element.interfaces, ...element.mixins]) {
      _visitType(owner, type, permitsPreparedVector: false);
    }
    for (final parameter in element.typeParameters) {
      _visitNullableType(owner, parameter.bound, permitsPreparedVector: false);
    }
    for (final field in _publicFields(element)) {
      _visitType(
        '$owner.${field.name}',
        field.type,
        permitsPreparedVector: false,
      );
    }
    for (final executable in [
      ...element.getters.where(_isPublicExecutable),
      ...element.setters.where(_isPublicExecutable),
      ...element.methods.where(_isPublicExecutable),
      ...element.constructors.where(_isPublicExecutable),
    ]) {
      _visitExecutable(
        '$owner.${executable.name}',
        executable,
        permitsPreparedVectorInReturn:
            element.name == 'CanvasResourceResolver' &&
            element.library.uri.toString() ==
                'package:iwb_canvas_engine/src/contracts/public/canvas_resource.dart' &&
            executable is MethodElement &&
            executable.name == 'resolveVector',
      );
    }
  }

  void _visitExtension(String owner, ExtensionElement element) {
    _visitType(owner, element.extendedType, permitsPreparedVector: false);
    for (final parameter in element.typeParameters) {
      _visitNullableType(owner, parameter.bound, permitsPreparedVector: false);
    }
    for (final executable in [
      ...element.getters.where(_isPublicExecutable),
      ...element.setters.where(_isPublicExecutable),
      ...element.methods.where(_isPublicExecutable),
    ]) {
      _visitExecutable('$owner.${executable.name}', executable);
    }
  }

  void _visitTypeAlias(String owner, TypeAliasElement element) {
    for (final parameter in element.typeParameters) {
      _visitNullableType(owner, parameter.bound, permitsPreparedVector: false);
    }
    _visitType(owner, element.aliasedType, permitsPreparedVector: false);
  }

  void _visitExecutable(
    String owner,
    FunctionTypedElement executable, {
    bool permitsPreparedVectorInReturn = false,
  }) {
    _visitType(
      owner,
      executable.returnType,
      permitsPreparedVector: permitsPreparedVectorInReturn,
    );
    for (final parameter in executable.typeParameters) {
      _visitNullableType(owner, parameter.bound, permitsPreparedVector: false);
    }
    for (final parameter in executable.formalParameters) {
      _visitType(owner, parameter.type, permitsPreparedVector: false);
    }
  }

  void _visitNullableType(
    String owner,
    DartType? type, {
    required bool permitsPreparedVector,
  }) {
    if (type != null) {
      _visitType(owner, type, permitsPreparedVector: permitsPreparedVector);
    }
  }

  void _visitType(
    String owner,
    DartType type, {
    required bool permitsPreparedVector,
  }) {
    if (!_visitedTypes.add((type, permitsPreparedVector))) {
      return;
    }

    switch (type) {
      case InterfaceType():
        _recordInterfaceType(owner, type, permitsPreparedVector);
        for (final argument in type.typeArguments) {
          _visitType(
            owner,
            argument,
            permitsPreparedVector: permitsPreparedVector,
          );
        }
      case FunctionType():
        _visitFunctionType(
          owner,
          type,
          permitsPreparedVector: permitsPreparedVector,
        );
      case RecordType():
        for (final field in [...type.positionalFields, ...type.namedFields]) {
          _visitType(
            owner,
            field.type,
            permitsPreparedVector: permitsPreparedVector,
          );
        }
      case TypeParameterType():
        _visitNullableType(
          owner,
          type.element.bound,
          permitsPreparedVector: permitsPreparedVector,
        );
      case InvalidType():
        violations.add('$owner: invalid public type');
    }
  }

  void _visitFunctionType(
    String owner,
    FunctionType type, {
    required bool permitsPreparedVector,
  }) {
    _visitType(
      owner,
      type.returnType,
      permitsPreparedVector: permitsPreparedVector,
    );
    for (final parameter in type.typeParameters) {
      _visitNullableType(owner, parameter.bound, permitsPreparedVector: false);
    }
    for (final parameter in type.formalParameters) {
      _visitType(
        owner,
        parameter.type,
        permitsPreparedVector: permitsPreparedVector,
      );
    }
  }

  void _recordInterfaceType(
    String owner,
    InterfaceType type,
    bool permitsPreparedVector,
  ) {
    final element = type.element;
    final libraryUri = element.library.uri.toString();
    if (identical(element, vectorClass) && !permitsPreparedVector) {
      violations.add('$owner exposes CanvasPreparedVector');
    }
    if (element.name == 'Picture' && libraryUri == 'dart:ui') {
      violations.add('$owner exposes dart:ui Picture');
    }
    if (libraryUri.startsWith('package:vector_graphics') ||
        libraryUri.startsWith('package:vector_graphics_codec')) {
      violations.add('$owner exposes $libraryUri ${element.name}');
    }
  }
}

bool _isPublicExecutable(ExecutableElement executable) {
  return executable.isPublic && executable.nonSynthetic == executable;
}

void _expectPrepareVectorSignature(
  TopLevelFunctionElement prepareVector,
  ClassElement vectorClass,
) {
  final future = _expectInterfaceType(
    prepareVector.returnType,
    name: 'Future',
    libraryUri: 'dart:async',
  );
  expect(future.typeArguments, hasLength(1));
  expect(future.typeArguments.single, isA<InterfaceType>());
  expect(
    (future.typeArguments.single as InterfaceType).element,
    same(vectorClass),
  );

  expect(prepareVector.formalParameters, hasLength(2));
  final bytes = prepareVector.formalParameters.first;
  expect(bytes.name, 'bytes');
  expect(bytes.isRequiredPositional, isTrue);
  _expectInterfaceType(
    bytes.type,
    name: 'ByteData',
    libraryUri: 'dart:typed_data',
  );

  final context = prepareVector.formalParameters.last;
  expect(context.name, 'context');
  expect(context.isOptionalNamed, isTrue);
  expect(context.type.nullabilitySuffix, NullabilitySuffix.question);
  _expectInterfaceType(
    context.type,
    name: 'BuildContext',
    libraryUriPrefix: 'package:flutter/',
  );
}

InterfaceType _expectInterfaceType(
  DartType type, {
  required String name,
  String? libraryUri,
  String? libraryUriPrefix,
}) {
  expect(type, isA<InterfaceType>());
  final interfaceType = type as InterfaceType;
  expect(interfaceType.element.name, name);
  final resolvedLibraryUri = interfaceType.element.library.uri.toString();
  if (libraryUri != null) {
    expect(resolvedLibraryUri, libraryUri);
  }
  if (libraryUriPrefix != null) {
    expect(resolvedLibraryUri, startsWith(libraryUriPrefix));
  }
  return interfaceType;
}

Future<void> _expectPermittedUseCompiles() async {
  final fixture = File(_fixturePath).readAsStringSync();
  final analyze = await _analyzeConsumerSource(fixture);

  expect(analyze.exitCode, 0, reason: _processOutput(analyze));
}

Future<ProcessResult> _analyzeConsumerSource(String source) async {
  final packageDir = await Directory.systemTemp.createTemp(
    'iwb_canvas_engine_prepared_vector_consumer_',
  );

  try {
    await Directory('${packageDir.path}/lib').create();
    await File(
      '${packageDir.path}/pubspec.yaml',
    ).writeAsString(_consumerPubspec());
    await File(
      '${packageDir.path}/lib/prepared_vector_consumer.dart',
    ).writeAsString(source);

    final pubGet = await Process.run('flutter', [
      'pub',
      'get',
    ], workingDirectory: packageDir.path);
    expect(pubGet.exitCode, 0, reason: _processOutput(pubGet));

    return await Process.run('dart', [
      'analyze',
      'lib/prepared_vector_consumer.dart',
    ], workingDirectory: packageDir.path);
  } finally {
    await packageDir.delete(recursive: true);
  }
}

String _consumerPubspec() {
  return '''
name: iwb_canvas_engine_prepared_vector_consumer
publish_to: none

environment:
  sdk: ^3.10.4

dependencies:
  flutter:
    sdk: flutter
  iwb_canvas_engine:
    path: $repositoryRoot
''';
}

String _processOutput(ProcessResult result) {
  return '''
stdout:
${result.stdout}

stderr:
${result.stderr}
''';
}

const _forbiddenConsumerSources = <String>[
  '''
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void constructPreparedVector() {
  CanvasPreparedVector();
}
''',
  '''
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void inspectPreparedVectorLiveness(CanvasPreparedVector value) {
  value.isDisposed;
}
''',
  '''
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void inspectPreparedVectorDebugLiveness(CanvasPreparedVector value) {
  value.debugDisposed;
}
''',
  '''
import 'dart:ui' as ui;

import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

ui.Picture extractPreparedVectorPicture(CanvasPreparedVector value) =>
    value.picture;
''',
  '''
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

CanvasDocument useCodecLocalDecodeHelper(Map<String, Object?> json) =>
    decodeSchemaV1Document(json);
''',
  '''
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

VectorGraphic exposeUpstreamVectorType(VectorGraphic value) => value;
''',
  '''
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

Object inspectPreparedVectorDiagnostics(CanvasPreparedVector value) =>
    value.diagnostics;
''',
  '''
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

Object inspectVectorElementDiagnostics(CanvasVectorElement value) =>
    value.diagnostics;
''',
  '''
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

Object inspectPreparedVectorCreationInternals(CanvasPreparedVector value) =>
    liveCanvasPreparedVectorPicture(value);
''',
];
