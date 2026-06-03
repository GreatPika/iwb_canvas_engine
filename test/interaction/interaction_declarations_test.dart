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

  test('pointer admission carries concrete draw commit fields', () {
    expect(_verifyPointerAdmissionFields, returnsNormally);
  });

  test('draw stroke commit intent has no generated element id', () {
    expect(_verifyDrawStrokeCommitIntentFields, returnsNormally);
  });

  test('draw line commit intent has no generated element id', () {
    expect(_verifyDrawLineCommitIntentFields, returnsNormally);
  });

  test('eraser commit intent carries eraser facts only', () {
    expect(_verifyEraserCommitIntentFields, returnsNormally);
  });
}

void _verifyRequiredDeclarations() {
  _verifyCoreDeclarations();
  _verifyMachineDeclarations();
  _verifyRuntimeIntentDeclarations();
  _verifyPayloadOwnershipDeclarations();
}

void _verifyCoreDeclarations() {
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
}

void _verifyMachineDeclarations() {
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
  expect(
    _source('lib/src/interaction/draw_stroke_machine.dart'),
    allOf(
      contains('final class DrawStrokeMachine'),
      contains('final class PointerStrokeCapture'),
      isNot(contains('final class DrawStrokeCommitIntent')),
    ),
  );
  expect(
    _source('lib/src/interaction/eraser_machine.dart'),
    allOf(
      contains('final class EraserMachine'),
      contains('final class PointerEraserCapture'),
      isNot(contains('final class EraserCommitIntent')),
    ),
  );
  expect(
    _source('lib/src/interaction/line_machine.dart'),
    allOf(
      contains('final class LineMachine'),
      contains('final class PointerLineFirstTapCapture'),
      contains('final class PointerLineEndpointCapture'),
      isNot(contains('final class DrawLineCommitIntent')),
    ),
  );
}

void _verifyRuntimeIntentDeclarations() {
  expect(
    _source('lib/src/interaction/interaction_runtime_intents.dart'),
    allOf(
      contains('final class ContextActionRequestIntent'),
      contains('final class SelectedMoveCommitIntent'),
      contains('final class MarqueeCommitIntent'),
      contains('final class DrawStrokeCommitIntent'),
      contains('final class DrawLineCommitIntent'),
      contains('final class EraserCommitIntent'),
    ),
  );
}

void _verifyPayloadOwnershipDeclarations() {
  expect(
    _source('lib/src/interaction/pointer_session.dart'),
    allOf(
      isNot(contains('final class PointerStrokeCapture')),
      isNot(contains('final class PointerEraserCapture')),
      isNot(contains('final class PointerLineEndpointCapture')),
    ),
  );
}

void _verifyPointerSessionDeclarations() {
  expect(
    _source('lib/src/interaction/pointer_session.dart'),
    allOf(
      contains('final class PointerSession'),
      contains('enum PointerSessionKind'),
      contains('final class PointerControllerEpoch'),
      isNot(contains('final class PointerSessionToken')),
      isNot(contains('final class PointerSessionId')),
    ),
  );
  expect(
    _source('lib/src/interaction/interaction_runtime_intents.dart'),
    allOf(
      contains('final class PointerSessionToken'),
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
    'publishRuntimeState',
    'cleanupDecision',
    'selectedMoveCommit',
    'marqueeCommit',
    'strokeCommit',
    'eraserCommit',
    'lineCommit',
    'contextRequest',
  });
  expect(fields.any((name) => name.contains('draw')), isFalse);
}

void _verifyEraserCommitIntentFields() {
  final unit = _parse(
    _source('lib/src/interaction/interaction_runtime_intents.dart'),
  );
  final fields = _fieldNames(unit, 'EraserCommitIntent');

  expect(fields, {
    'sessionId',
    'pointerToken',
    'eraserThickness',
    'corridorPointCount',
    'erasedElementIds',
  });
}

void _verifyDrawStrokeCommitIntentFields() {
  final unit = _parse(
    _source('lib/src/interaction/interaction_runtime_intents.dart'),
  );
  final fields = _fieldNames(unit, 'DrawStrokeCommitIntent');

  expect(fields, {
    'sessionId',
    'pointerToken',
    'tool',
    'points',
    'color',
    'thickness',
    'opacity',
  });
  expect(fields.any((name) => name.toLowerCase().contains('element')), isFalse);
}

void _verifyDrawLineCommitIntentFields() {
  final unit = _parse(
    _source('lib/src/interaction/interaction_runtime_intents.dart'),
  );
  final fields = _fieldNames(unit, 'DrawLineCommitIntent');

  expect(fields, {
    'sessionId',
    'pointerToken',
    'startWorld',
    'endWorld',
    'color',
    'thickness',
    'opacity',
  });
  expect(fields.any((name) => name.toLowerCase().contains('element')), isFalse);
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
