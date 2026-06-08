import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:test/test.dart';

void main() {
  _testRecordingLoadBoundaryShape();
}

void _testRecordingLoadBoundaryShape() {
  test('recording load boundary exposes no deferred cleanup surface', () {
    final declaration = _classDeclaration(
      _loadOrderingFixtureUnit(),
      '_RecordingLoadBoundary',
    );

    expect(_fieldTypesByName(declaration), {
      'events': 'List<String>',
      'onPrepareCleanup': 'void Function()?',
    });
    expect(_methodNames(declaration), ['prepareLoadCleanup']);
  });
}

CompilationUnit _loadOrderingFixtureUnit() {
  return parseFile(
    path:
        '${Directory.current.path}/test/runtime/fixtures/load_document_ordering_fixture.dart',
    featureSet: FeatureSet.latestLanguageVersion(),
  ).unit;
}

ClassDeclaration _classDeclaration(CompilationUnit unit, String className) {
  return unit.declarations.whereType<ClassDeclaration>().singleWhere(
    (declaration) => declaration.namePart.typeName.lexeme == className,
  );
}

Map<String, String> _fieldTypesByName(ClassDeclaration declaration) {
  return {
    for (final field in declaration.body.members.whereType<FieldDeclaration>())
      for (final variable in field.fields.variables)
        variable.name.lexeme: field.fields.type?.toSource() ?? '',
  };
}

List<String> _methodNames(ClassDeclaration declaration) {
  return [
    for (final method
        in declaration.body.members.whereType<MethodDeclaration>())
      method.name.lexeme,
  ];
}
