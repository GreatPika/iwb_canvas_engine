import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('interaction unit files own the required primary declarations', () {
    expect(_verifyRequiredDeclarations, returnsNormally);
  });

  test('interaction read requests defensively copy captured session ids', () {
    expect(_verifySelectedMoveCommitRequestCopies, returnsNormally);
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

String _source(String path) => File(path).readAsStringSync();
