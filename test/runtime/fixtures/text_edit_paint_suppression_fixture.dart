import 'dart:async';
import 'dart:io';
import 'dart:ui';
import "../../support/runtime_root_with_document.dart";

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/frame/frame_paint_output.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  _testActiveSessionSuppressesTextPaintAndSelection();
  _testSelectedMoveSupplementKeepsSuppressedTextHidden();
  _testActiveSuppressionKeepsContextTargetMembership();
  _testSessionCommitRestoresCommittedTextPaint();
  _testDismissAndReadOnlyRestoreCommittedTextPaint();
  _testStaleGuardMismatchDisablesSuppression();
  _testSuccessfulLoadClearsSuppressionBeforeNextFrame();
  _testMainFramePainterDoesNotReadRuntime();
}

void _testActiveSessionSuppressesTextPaintAndSelection() {
  test('active session suppresses matching text paint and selection', () async {
    final scenario = _Scenario();
    try {
      scenario.root.selection.setSelection([_textId]);
      _expectFramePaint(scenario.root, textVisible: true);
      expect(_frameOutput(scenario.root).selectionDecorationPlan.primitives, [
        isA<Object>(),
      ]);

      await scenario.startTextSession();
      final activeOutput = _frameOutput(scenario.root);

      _expectFramePaint(scenario.root, textVisible: false);
      expect(_recordIds(activeOutput), contains(_rectId));
      expect(activeOutput.selectionDecorationPlan.primitives, isEmpty);
      _expectDocumentTextUnchanged(scenario.root);
      expect(_textElement(scenario.root).isVisible, isTrue);
    } finally {
      await scenario.dispose();
    }
  });
}

void _testSelectedMoveSupplementKeepsSuppressedTextHidden() {
  test('selected move supplement keeps suppressed text hidden', () async {
    final scenario = _Scenario();
    try {
      scenario.root.selection.setSelection([_textId]);
      await scenario.startTextSession();

      scenario.root.replaceInteractionPreview(
        const CanvasSelectedMovePreview(delta: Offset(10, 0)),
      );
      final output = _frameOutput(scenario.root);

      expect(_recordIds(output), isNot(contains(_textId)));
      expect(
        output.selectedMoveSupplementPlan.mergedRecords.map(
          (record) => record.id,
        ),
        isNot(contains(_textId)),
      );
    } finally {
      await scenario.dispose();
    }
  });
}

void _testActiveSuppressionKeepsContextTargetMembership() {
  test('active suppression keeps context target membership', () async {
    final scenario = _Scenario();
    try {
      await scenario.startTextSession();

      final request = await scenario.issueTextRequest();

      expect(scenario.root.textEditing.sessionCandidateFor(request), isNotNull);
      _expectFramePaint(scenario.root, textVisible: false);
    } finally {
      await scenario.dispose();
    }
  });
}

void _testSessionCommitRestoresCommittedTextPaint() {
  test('session commit restores committed text paint', () async {
    final scenario = _Scenario();
    try {
      final session = await scenario.startTextSession();
      session.updateText('committed');

      expect(session.commit(timestampMs: 1), isTrue);

      _expectFramePaint(scenario.root, textVisible: true);
      expect(_textElement(scenario.root).text, 'committed');
    } finally {
      await scenario.dispose();
    }
  });
}

void _testDismissAndReadOnlyRestoreCommittedTextPaint() {
  test('dismiss and read-only restore committed text paint', () async {
    final dismissed = _Scenario();
    try {
      final session = await dismissed.startTextSession();
      session.dismiss();

      _expectFramePaint(dismissed.root, textVisible: true);
      expect(_recordIds(_frameOutput(dismissed.root)), contains(_textId));
    } finally {
      await dismissed.dispose();
    }

    final readOnly = _Scenario();
    try {
      await readOnly.startTextSession();
      readOnly.root.textEditing.setReadOnly(true);

      _expectFramePaint(readOnly.root, textVisible: true);
      expect(_recordIds(_frameOutput(readOnly.root)), contains(_textId));
    } finally {
      await readOnly.dispose();
    }
  });
}

void _testStaleGuardMismatchDisablesSuppression() {
  test(
    'stale guard mismatch disables suppression and stale commit cleans up',
    () async {
      final scenario = _Scenario();
      try {
        final session = await scenario.startTextSession();
        scenario.root.edits.edit(
          (edit) => edit.updateElement(
            CanvasTextElementUpdate(
              id: _textId,
              fontSize: const CanvasFieldSet(20),
            ),
          ),
        );

        _expectFramePaint(scenario.root, textVisible: true);
        expect(session.commit(timestampMs: 2), isFalse);
        expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
        _expectFramePaint(scenario.root, textVisible: true);
      } finally {
        await scenario.dispose();
      }
    },
  );
}

void _testSuccessfulLoadClearsSuppressionBeforeNextFrame() {
  test('successful load clears suppression before next frame', () async {
    final scenario = _Scenario();
    try {
      await scenario.startTextSession();

      scenario.root.edits.loadDocumentFromJson(
        encodeCanvasDocumentToJson(_document(text: 'loaded')),
      );

      expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
      _expectFramePaint(scenario.root, textVisible: true);
      expect(_textElement(scenario.root).text, 'loaded');
    } finally {
      await scenario.dispose();
    }
  });
}

void _testMainFramePainterDoesNotReadRuntime() {
  test('main frame painter does not read live runtime state', () {
    final source = File(
      'lib/src/frame/main_frame_record_painter.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('RuntimeRoot')));
    expect(source, isNot(contains('CanvasRuntime')));
    expect(source, isNot(contains('CanvasTextEditingPort')));
    expect(source, isNot(contains('textEditing')));
  });
}

final class _Scenario {
  _Scenario()
    : root = runtimeRootWithDocument(
        _document(),
        config: const CanvasRuntimeConfig(),
      ) {
    requestSubscription = root.contextActionRequests.listen(requests.add);
  }

  final RuntimeRoot root;
  late final StreamSubscription<CanvasContextActionRequested>
  requestSubscription;
  final List<CanvasContextActionRequested> requests = [];
  var _disposed = false;

  Future<CanvasTextEditSession> startTextSession() async {
    final request = await issueTextRequest();
    final session = root.textEditing.startFromContextAction(request);
    expect(session, isNotNull);

    return session as CanvasTextEditSession;
  }

  Future<CanvasContextActionRequested> issueTextRequest() async {
    root.handleDoubleTap(position: Offset.zero, timestampMs: 1);
    await Future<void>.delayed(Duration.zero);
    final request = requests.single;
    requests.clear();

    return request;
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await requestSubscription.cancel();
    root.dispose();
  }
}

void _expectFramePaint(RuntimeRoot root, {required bool textVisible}) {
  final ids = _recordIds(_frameOutput(root));
  if (textVisible) {
    expect(ids, contains(_textId));
  } else {
    expect(ids, isNot(contains(_textId)));
  }
}

List<CanvasElementId> _recordIds(MainFramePaintOutput output) {
  return [for (final record in output.ordinaryPlan.ordinaryRecords) record.id];
}

MainFramePaintOutput _frameOutput(RuntimeRoot root) {
  return root.buildResourceFreeMainFrame(
    viewportWorldBounds: const Rect.fromLTWH(-20, -20, 220, 120),
    devicePixelRatio: 1,
    selectionStyle: CanvasSelectionStyle.defaultStyle,
    gridStyle: CanvasGridStyle.defaultStyle,
  );
}

void _expectDocumentTextUnchanged(RuntimeRoot root) {
  expect(_textElement(root).text, 'hello');
  expect(root.state.value.revisions.document, 0);
}

CanvasTextElement _textElement(RuntimeRoot root) {
  return root
      .readDocument()
      .layers
      .single
      .elements
      .whereType<CanvasTextElement>()
      .single;
}

CanvasDocument _document({String text = 'hello'}) {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasTextElement(
            id: _textId,
            text: text,
            fontSize: 16,
            color: const Color(0xFF111111),
            textDirection: TextDirection.ltr,
          ),
          CanvasRectElement(
            id: _rectId,
            size: const Size(20, 20),
            transform: CanvasTransform.translation(const Offset(120, 0)),
          ),
        ],
      ),
    ],
  );
}

final _textId = CanvasElementId('text-a');
final _rectId = CanvasElementId('rect-a');
