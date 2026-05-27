import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_error_details_sanitizer.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_errors.dart';
import 'package:test/test.dart';

void main() {
  _testMovedValueDeclarations();
  _testSurfaceValueDeclarations();
  _testConstAndEqualityShape();
  _testValidationHelperShape();
  _testErrorSanitizationBehavior();
  _testPublicPortReachability();
}

void _testMovedValueDeclarations() {
  test('public contract owner contains moved value declarations', () {
    final runtime = _contractSource('canvas_runtime.dart');
    final ids = _contractSource('canvas_ids.dart');
    final fieldUpdate = _contractSource('canvas_field_update.dart');
    final geometry = _contractSource('canvas_geometry.dart');

    expect(
      _topLevelNames(runtime),
      containsAll([
        'CanvasRuntimeConfig',
        'CanvasRuntimeState',
        'CanvasRuntimeRevisions',
        'CanvasRuntimeSummary',
        'CanvasEditPort',
        'CanvasEdit',
        'CanvasCommandPort',
        'CanvasSelectionPort',
        'CanvasCameraPort',
      ]),
    );
    expect(
      _topLevelNames(ids),
      containsAll([
        'CanvasElementId',
        'CanvasLayerId',
        'CanvasResourceId',
        'CanvasActionId',
        'CanvasInteractionRequestId',
      ]),
    );
    expect(
      _topLevelNames(fieldUpdate),
      containsAll([
        'CanvasFieldUpdate',
        'CanvasFieldAbsent',
        'CanvasFieldSet',
        'CanvasFieldClear',
      ]),
    );
    expect(_topLevelNames(geometry), contains('CanvasTransform'));
  });
}

void _testSurfaceValueDeclarations() {
  test('surface style values are contract-owned wrapper exports', () {
    final surface = _contractSource('canvas_surface.dart');

    expect(
      _topLevelNames(surface),
      containsAll(['CanvasSelectionStyle', 'CanvasGridStyle']),
    );
    expect(surface, contains('static const defaultStyle'));
    expect(surface, contains('bool operator ==(Object other)'));
  });
}

void _testConstAndEqualityShape() {
  test('moved values retain const constructors and equality members', () {
    final runtime = _contractSource('canvas_runtime.dart');
    final fieldUpdate = _contractSource('canvas_field_update.dart');
    final geometry = _contractSource('canvas_geometry.dart');

    expect(runtime, contains('const CanvasRuntimeConfig({'));
    expect(runtime, contains('const CanvasRuntimeState({'));
    expect(runtime, contains('const CanvasRuntimeRevisions({'));
    expect(runtime, contains('const CanvasRuntimeSummary({'));
    expect(runtime, contains('bool operator ==(Object other)'));
    expect(fieldUpdate, contains('const factory CanvasFieldUpdate.absent()'));
    expect(fieldUpdate, contains('bool operator ==(Object other)'));
    expect(geometry, contains('static const identity = CanvasTransform._('));
    expect(geometry, contains('bool operator ==(Object other)'));
  });
}

void _testValidationHelperShape() {
  test('validation helpers still throw public data exceptions', () {
    final validators = _contractSource('canvas_value_validators.dart');

    expect(validators, contains('String validateCanvasIdValue('));
    expect(validators, contains('void validateFiniteDouble('));
    expect(validators, contains('void validateOffset('));
    expect(validators, contains('void validateSize('));
    expect(validators, contains('throw CanvasDataException('));
    expect(validators, contains('CanvasDataErrorCode.fieldMustBeFinite'));
  });
}

void _testErrorSanitizationBehavior() {
  test('public error values still sanitize details at construction', () {
    final exception = CanvasDataException(
      code: CanvasDataErrorCode.invalidFieldType,
      message: 'invalid',
      details: {
        'long': 'abcdef',
        'unsupported': Object(),
        'infinite': double.infinity,
      },
    );

    expect(exception.details, containsPair('long', 'abcdef'));
    expect(exception.details['unsupported'], isA<Map<String, Object?>>());
    expect(exception.details['infinite'], isA<Map<String, Object?>>());

    final limited = sanitizeCanvasErrorDetailsWithLimits(
      {
        'abcdefgh': ['abcdef', 'ghijkl'],
      },
      maxPreviewLength: 3,
      maxListEntries: 1,
    );

    expect(limited.keys.single, 'abc<truncated>');
    expect(limited.values.single, ['abc<truncated>']);
  });
}

void _testPublicPortReachability() {
  test('public port interfaces stay reachable from contract owners', () {
    final runtime = _contractSource('canvas_runtime.dart');
    final tools = _contractSource('canvas_tools.dart');
    final resources = _contractSource('canvas_resource.dart');

    expect(
      _abstractInterfaceNames(runtime),
      containsAll([
        'CanvasEditPort',
        'CanvasEdit',
        'CanvasCommandPort',
        'CanvasSelectionPort',
        'CanvasCameraPort',
      ]),
    );
    expect(_abstractInterfaceNames(tools), contains('CanvasToolPort'));
    expect(
      _abstractInterfaceNames(resources),
      containsAll(['CanvasResourceResolver', 'CanvasResourcePort']),
    );
  });
}

String _contractSource(String fileName) {
  return File('lib/src/contracts/public/$fileName').readAsStringSync();
}

Set<String> _topLevelNames(String content) {
  final unit = _parse(content);
  return unit.declarations.map(_declarationName).nonNulls.toSet();
}

Set<String> _abstractInterfaceNames(String content) {
  final unit = _parse(content);
  return {
    for (final declaration in unit.declarations.whereType<ClassDeclaration>())
      if (declaration.abstractKeyword != null &&
          declaration.interfaceKeyword != null)
        declaration.namePart.typeName.lexeme,
  };
}

CompilationUnit _parse(String content) {
  return parseString(
    content: content,
    featureSet: FeatureSet.latestLanguageVersion(),
  ).unit;
}

String? _declarationName(CompilationUnitMember declaration) {
  return switch (declaration) {
    ClassDeclaration(:final namePart) => namePart.typeName.lexeme,
    EnumDeclaration(:final namePart) => namePart.typeName.lexeme,
    ExtensionDeclaration(:final name) => name?.lexeme,
    MixinDeclaration(:final name) => name.lexeme,
    FunctionDeclaration(:final name) => name.lexeme,
    TopLevelVariableDeclaration(:final variables) =>
      variables.variables.isEmpty
          ? null
          : variables.variables.first.name.lexeme,
    _ => null,
  };
}
