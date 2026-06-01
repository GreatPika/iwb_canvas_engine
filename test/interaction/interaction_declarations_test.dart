import 'dart:io';

import 'package:iwb_canvas_engine/src/contracts/public/canvas_ids.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_read_port.dart';
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
  final selected = [CanvasElementId('a')];
  final movable = [CanvasElementId('b')];
  final request = SelectedMoveCommitReadRequest(
    sessionSelectedIds: selected,
    sessionMovableIds: movable,
    selectionRevision: 3,
  );

  selected.add(CanvasElementId('changed'));
  movable.clear();

  expect(request.sessionSelectedIds, [CanvasElementId('a')]);
  expect(request.sessionMovableIds, [CanvasElementId('b')]);
  expect(
    () => request.sessionSelectedIds.add(CanvasElementId('blocked')),
    throwsUnsupportedError,
  );
}

String _source(String path) => File(path).readAsStringSync();
