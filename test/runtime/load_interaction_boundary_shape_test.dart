// This test uses analyzer AST checks so the load cleanup seam shape is
// mechanically enforced instead of relying on review-only convention.
// ignore_for_file: number-of-external-imports

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:iwb_canvas_engine/src/runtime/load_interaction_boundary.dart';
import 'package:test/test.dart';

void main() {
  test('boundary exposes exactly one prepared cleanup method', () {
    expect(_expectBoundaryMethodShape, returnsNormally);
  });

  test('cleanup outcome is const immutable value data', () {
    expect(_expectCleanupOutcomeShape, returnsNormally);
  });
}

void _expectBoundaryMethodShape() {
  final boundary = _CompileTimeLoadBoundary();

  expect(
    boundary.prepareLoadCleanup(),
    const PointerCleanupOutcome(previewChanged: true),
  );

  final declaration = _classDeclaration(
    _loadInteractionBoundaryUnit(),
    'LoadInteractionBoundary',
  );
  final methods = declaration.body.members
      .whereType<MethodDeclaration>()
      .toList();

  expect(methods, hasLength(1));
  expect(methods.single.name.lexeme, 'prepareLoadCleanup');
  expect(methods.single.returnType?.toSource(), 'PointerCleanupOutcome');
}

void _expectCleanupOutcomeShape() {
  const outcome = PointerCleanupOutcome(previewChanged: true);
  expect(outcome.previewChanged, isTrue);
  expect(PointerCleanupOutcome.noChange.previewChanged, isFalse);

  final declaration = _classDeclaration(
    _loadInteractionBoundaryUnit(),
    'PointerCleanupOutcome',
  );

  _expectConstConstructor(declaration);
  _expectValueOnlyFields(declaration);
}

void _expectConstConstructor(ClassDeclaration declaration) {
  expect(
    declaration.body.members.whereType<ConstructorDeclaration>().any(
      (constructor) => constructor.constKeyword != null,
    ),
    isTrue,
  );
}

void _expectValueOnlyFields(ClassDeclaration declaration) {
  expect(declaration.body.members.whereType<MethodDeclaration>(), isEmpty);
  final fields = declaration.body.members
      .whereType<FieldDeclaration>()
      .toList();

  expect(fields, hasLength(2));
  for (final field in fields) {
    expect(field.fields.isFinal || field.fields.isConst, isTrue);
  }
  expect(_fieldTypesByName(fields), {
    'previewChanged': 'bool',
    'noChange': 'PointerCleanupOutcome',
  });
}

Map<String, String> _fieldTypesByName(List<FieldDeclaration> fields) {
  return {
    for (final field in fields)
      for (final variable in field.fields.variables)
        variable.name.lexeme: field.fields.type?.toSource() ?? '',
  };
}

final class _CompileTimeLoadBoundary implements LoadInteractionBoundary {
  @override
  PointerCleanupOutcome prepareLoadCleanup() {
    return const PointerCleanupOutcome(previewChanged: true);
  }
}

CompilationUnit _loadInteractionBoundaryUnit() {
  return parseFile(
    path:
        '${Directory.current.path}/lib/src/runtime/load_interaction_boundary.dart',
    featureSet: FeatureSet.latestLanguageVersion(),
  ).unit;
}

ClassDeclaration _classDeclaration(CompilationUnit unit, String className) {
  return unit.declarations.whereType<ClassDeclaration>().singleWhere(
    (declaration) => declaration.namePart.typeName.lexeme == className,
  );
}
