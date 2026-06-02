import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:test/test.dart';

void main() {
  test('interaction unit files own the required primary declarations', () {
    expect(_verifyRequiredDeclarations, returnsNormally);
  });

  test('interaction read requests defensively copy captured session ids', () {
    expect(_verifySelectedMoveCommitRequestCopies, returnsNormally);
  });

  test('unit 1 pointer admission has no draw commit fields', () {
    expect(_verifyPointerAdmissionFields, returnsNormally);
  });
}

void _verifyRequiredDeclarations() {
  expect(
    _source('lib/src/interaction/interaction_engine.dart'),
    contains('final class InteractionEngine'),
  );
  expect(
    _source('lib/src/interaction/interaction_read_port.dart'),
    contains('abstract interface class InteractionReadPort'),
  );
  _verifyPointerSessionDeclarations();
  _verifyPointerNormalizerDeclarations();
  expect(
    _source('lib/src/interaction/move_machine.dart'),
    allOf(
      contains('final class MoveMachine'),
      contains('final class SelectedMoveTerminalDecision'),
    ),
  );
  expect(
    _source('lib/src/interaction/select_machine.dart'),
    allOf(
      contains('final class SelectMachine'),
      contains('final class MarqueeTerminalDecision'),
    ),
  );
}

void _verifyPointerSessionDeclarations() {
  expect(
    _source('lib/src/interaction/pointer_session.dart'),
    allOf(
      contains('final class PointerSession'),
      contains('enum PointerSessionKind'),
      contains('final class PointerSessionToken'),
      contains('final class PointerControllerEpoch'),
      contains('final class PointerSessionId'),
    ),
  );
}

void _verifyPointerNormalizerDeclarations() {
  expect(
    _source('lib/src/interaction/pointer_sample_normalizer.dart'),
    allOf(
      contains('final class PointerSampleNormalizer'),
      contains('final class NormalizedPointerSample'),
      contains('final class InvalidTerminalCleanupDecision'),
    ),
  );
}

void _verifySelectedMoveCommitRequestCopies() {
  expect(
    _source('lib/src/interaction/interaction_read_port.dart'),
    allOf(
      contains('sessionSelectedIds = List.unmodifiable(sessionSelectedIds)'),
      contains('sessionMovableIds = List.unmodifiable(sessionMovableIds)'),
      contains('movedElements = List.unmodifiable(movedElements)'),
      contains('_skippedSessionIds = List.unmodifiable(skippedSessionIds)'),
    ),
  );
}

void _verifyPointerAdmissionFields() {
  final unit = _parse(
    _source('lib/src/interaction/interaction_pointer_context.dart'),
  );
  final fields = _fieldNames(unit, 'InteractionPointerAdmission');

  expect(fields, {
    'kind',
    'sample',
    'cleanupDecision',
    'selectedMoveCommit',
    'marqueeCommit',
  });
  expect(fields.any((name) => name.contains('stroke')), isFalse);
  expect(fields.any((name) => name.contains('line')), isFalse);
  expect(fields.any((name) => name.contains('draw')), isFalse);
}

String _source(String path) => File(path).readAsStringSync();

CompilationUnit _parse(String content) {
  return parseString(
    content: content,
    featureSet: FeatureSet.latestLanguageVersion(),
  ).unit;
}

Set<String> _fieldNames(CompilationUnit unit, String className) {
  final declaration = unit.declarations
      .whereType<ClassDeclaration>()
      .singleWhere(
        (candidate) => candidate.namePart.typeName.lexeme == className,
      );

  return {
    for (final field in declaration.body.members.whereType<FieldDeclaration>())
      for (final variable in field.fields.variables) variable.name.lexeme,
  };
}
