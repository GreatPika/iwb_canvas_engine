import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import 'package:iwb_canvas_engine/src/surface/text_editing_overlay.dart';
import '../../support/accept_commit.dart';
import '../../support/runtime_with_document.dart';

void main() {
  _testOverlayUsesEditableTextAndSessionGeometry();
  _testOverlayUsesEffectiveRuntimeFontFamily();
  _testFormattingRetainsInputObjectsAndEditingValue();
  _testOverlayAnchorsLiveWidthToTextAlignment();
  _testOverlayAppliesSessionTransform();
  _testAutoStartPolicy();
  _testOverlayEmptyTextPolicyCapture();
  _testReadOnlyPolicy();
  _testCameraPanRepositionsActiveEditor();
  _testCommitAndDismiss();
  _testOverlayClosesNewOriginDraftsWithoutInstallation();
  _testOverlayRetainsStaleDraftUntilCancellation();
  _testFocusLossCommit();
  _testMultilineGrowthAndMaxHeightPolicy();
  _testDisposesListeners();
  _testRuntimeSwapCancelsPreviousDraft();
  _testOverlayDoesNotMeasureText();
}

/// Covers both closing paths together to observe the unchanged canvas state.
// ignore: halstead-volume, reason: The mounted widget scenario must retain both close paths to observe unchanged canvas state.
void _testOverlayClosesNewOriginDraftsWithoutInstallation() {
  testWidgets(
    'stock overlay cancels and empties a new draft without a placeholder',
    (tester) async {
      final scenario = _OverlayScenario(inlineEditOnDoubleTap: false);
      addTearDown(scenario.dispose);
      await scenario.pump(tester);
      final documentRevision = scenario.runtime.state.value.revisions.document;
      final seed = CanvasTextElement(
        id: CanvasElementId('overlay-new-text'),
        revision: 4,
        text: 'seed',
        color: const Color(0xFF222244),
        textDirection: TextDirection.ltr,
        transform: CanvasTransform.translation(const Offset(24, 12)),
      );

      final admitted = scenario.runtime.textEditing.startNew(seed);
      expect(admitted, isA<CanvasTextEditStartSuccess>());
      await tester.pump();
      expect(_editableTextFinder(), findsOneWidget);
      expect(scenario.activeSession.origin, CanvasTextEditOrigin.newElement);
      await tester.enterText(_editableTextFinder(), 'cancelled new text');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(scenario.runtime.textEditing.activeSession.value, isNull);
      expect(_containsElement(scenario.runtime, seed.id), isFalse);
      expect(scenario.runtime.state.value.revisions.document, documentRevision);
      expect(scenario.actions, isEmpty);

      final empty = scenario.runtime.textEditing.startNew(seed);
      expect(empty, isA<CanvasTextEditStartSuccess>());
      await tester.pump();
      await tester.enterText(_editableTextFinder(), ' \n ');
      await tester.pump();
      tester
          .widget<EditableText>(_editableTextFinder())
          .onEditingComplete
          ?.call();
      await tester.pump();
      expect(scenario.runtime.textEditing.activeSession.value, isNull);
      expect(_containsElement(scenario.runtime, seed.id), isFalse);
      expect(scenario.runtime.state.value.revisions.document, documentRevision);
      expect(scenario.actions, isEmpty);
    },
  );
}

// The stock editor receives the runtime-resolved frame style. Checking both
// Flutter style carriers keeps a TextStyle-only fallback from appearing valid.
void _testOverlayUsesEffectiveRuntimeFontFamily() {
  testWidgets('overlay applies the effective family to text and strut styles', (
    tester,
  ) async {
    final scenario = _OverlayScenario(
      inlineEditOnDoubleTap: true,
      config: const CanvasRuntimeConfig(
        commitResolver: acceptCommit,
        defaultFontFamily: _unit7OverlayRobotoFamily,
      ),
    );
    addTearDown(scenario.dispose);
    await scenario.pump(tester);
    await scenario.doubleTapText(tester);
    expect(_editableTextFinder(), findsOneWidget);
    _expectEffectiveEditorFamily(tester, _unit7OverlayRobotoFamily);
  });
}

void _expectEffectiveEditorFamily(WidgetTester tester, String family) {
  final editable = tester.widget<EditableText>(_editableTextFinder());
  expect(editable.style.fontFamily, family);
  expect(editable.strutStyle.fontFamily, family);
}

const _unit7OverlayRobotoFamily = 'Unit7OverlayRoboto';

// The widget path keeps stale confirmation and explicit cancellation together
// so the official overlay's terminal behavior remains visible end to end.
// ignore: halstead-volume
void _testOverlayRetainsStaleDraftUntilCancellation() {
  testWidgets('overlay finishes a stale draft only when explicitly cancelled', (
    tester,
  ) async {
    final scenario = _OverlayScenario(inlineEditOnDoubleTap: true);
    addTearDown(scenario.dispose);
    await scenario.pump(tester);
    await scenario.doubleTapText(tester);
    final elementId = scenario.activeSession.elementId;
    await tester.enterText(
      find.byKey(canvasTextEditingOverlayEditableTextKey),
      'overlay draft',
    );
    await tester.pump();

    scenario.runtime.edits.edit(
      (edit) => edit.updateElement(
        CanvasTextElementUpdate(
          id: elementId,
          text: const CanvasFieldSet('external text'),
        ),
      ),
    );
    await tester.pump();
    tester
        .widget<EditableText>(_editableTextFinder())
        .onEditingComplete
        ?.call();
    await tester.pump();

    expect(_textElement(scenario.runtime).text, 'external text');
    expect(scenario.activeSession.liveText, 'overlay draft');
    expect(scenario.activeSession.isStale, isTrue);
    expect(scenario.actions, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(scenario.runtime.textEditing.activeSession.value, isNull);
    expect(_textElement(scenario.runtime).text, 'external text');
    expect(scenario.actions, isEmpty);
  });
}

void _testOverlayAnchorsLiveWidthToTextAlignment() {
  testWidgets('overlay grows live text from the aligned horizontal edge', (
    tester,
  ) async {
    await _expectLiveWidthAnchorFor(tester, TextAlign.left);
    await _expectLiveWidthAnchorFor(tester, TextAlign.right);
    await _expectLiveWidthAnchorFor(tester, TextAlign.center);

    expect(find.byKey(canvasTextEditingOverlayEditableTextKey), findsOneWidget);
  });
}

// This proof keeps geometry placement and style adoption together because the
// contract requires both to come from the same active session snapshot.
// ignore: halstead-volume, source-lines-of-code
void _testOverlayUsesEditableTextAndSessionGeometry() {
  testWidgets('overlay uses EditableText, session geometry, and style', (
    tester,
  ) async {
    final scenario = _OverlayScenario(
      document: _document(
        camera: const Offset(12, 4),
        text: 'styled',
        fontSize: 18,
        color: const Color(0xFF884422),
        isBold: true,
        isItalic: true,
        isUnderline: true,
        fontFamily: 'Roboto',
        lineHeight: 1.4,
        align: TextAlign.center,
        textDirection: TextDirection.ltr,
        transform: CanvasTransform.translation(const Offset(40, 20)),
      ),
      inlineEditOnDoubleTap: true,
    );
    addTearDown(scenario.dispose);

    await scenario.pump(tester);
    await scenario.doubleTapText(tester, const Offset(28, 16));

    expect(find.byKey(canvasTextEditingOverlayEditableTextKey), findsOneWidget);
    final hostTopLeft = tester.getTopLeft(
      find.byKey(canvasTextEditingOverlayEditorHostKey),
    );
    final session = scenario.activeSession;
    final localEditBounds = _localEditBoundsFor(session.geometry);
    final worldEditBounds = session.geometry.editBoundsWorld;
    final hostRect = _editorHostRect(tester);

    expect(
      hostTopLeft.dy,
      worldEditBounds.top - scenario.runtime.camera.offset.dy,
    );
    expect(
      hostRect.center.dx,
      worldEditBounds.center.dx - scenario.runtime.camera.offset.dx,
    );
    _expectEditorHostExtendsMeasuredWidth(tester, localEditBounds);

    final editable = tester.widget<EditableText>(_editableTextFinder());
    _expectInlineEditorDisablesScrollbar(tester, editable);
    expect(editable.style.fontSize, 18);
    expect(editable.style.color, const Color(0xFF884422));
    expect(editable.style.fontWeight, FontWeight.bold);
    expect(editable.style.fontStyle, FontStyle.italic);
    expect(editable.style.decoration, TextDecoration.underline);
    expect(editable.style.fontFamily, 'Roboto');
    expect(editable.style.height, 1.4);
    expect(editable.textAlign, TextAlign.center);
    expect(editable.textDirection, TextDirection.ltr);
    expect(editable.cursorColor, const Color(0xFF1565C0));
    expect(editable.selectionColor, const Color(0x331565C0));
  });
}

void _testOverlayAppliesSessionTransform() {
  testWidgets('overlay applies session transform in surface space', (
    tester,
  ) async {
    final transform = CanvasTransform.trs(
      translation: const Offset(40, 20),
      scaleX: 2,
      scaleY: 1.5,
    );
    final scenario = _OverlayScenario(
      inlineEditOnDoubleTap: true,
      document: _document(transform: transform),
    );
    addTearDown(scenario.dispose);
    await scenario.pump(tester);
    await scenario.doubleTapText(tester, const Offset(40, 20));

    final appliedTransform = tester.widget<Transform>(
      find.byKey(canvasTextEditingOverlayTransformKey),
    );
    final expected = transform
        .withTranslation(transform.translation - scenario.runtime.camera.offset)
        .toCanvasTransform();

    expect(appliedTransform.transform.storage, expected);
    _expectEditorHostExtendsMeasuredWidth(
      tester,
      _localEditBoundsFor(scenario.activeSession.geometry),
    );
  });
}

// This surface proof uses the actual EditableText value because a styled
// rendering assertion cannot detect a controller, focus, selection, or IME
// composition replacement. Its ordered formatting repaints stay together to
// preserve the one active-input invariant across each observable frame.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _testFormattingRetainsInputObjectsAndEditingValue() {
  testWidgets(
    'formatting retains active input identity and continues text input',
    (tester) async {
      final scenario = _OverlayScenario(
        inlineEditOnDoubleTap: true,
        autofocus: true,
      );
      addTearDown(scenario.dispose);
      await scenario.pump(tester);
      await scenario.doubleTapText(tester);
      final session = scenario.activeSession;
      final editable = tester.widget<EditableText>(_editableTextFinder());
      final controller = editable.controller;
      final focusNode = editable.focusNode;
      controller.value = const TextEditingValue(
        text: 'typed draft',
        selection: TextSelection(baseOffset: 1, extentOffset: 6),
        composing: TextRange(start: 1, end: 6),
      );
      await tester.pump();
      final valueBeforeFormatting = controller.value;
      final documentRevision = scenario.runtime.state.value.revisions.document;

      session.updateFormatting(isBold: true);
      await tester.pump();
      expect(session.style.isBold, isTrue);
      expect(session.style.isItalic, isFalse);
      expect(session.style.isUnderline, isFalse);
      _expectFormattedActiveInput(
        tester,
        session: session,
        textEditing: scenario.runtime.textEditing,
        controller: controller,
        focusNode: focusNode,
        value: valueBeforeFormatting,
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.normal,
      );

      session.updateFormatting(isItalic: true);
      await tester.pump();
      expect(session.style.isBold, isTrue);
      expect(session.style.isItalic, isTrue);
      expect(session.style.isUnderline, isFalse);
      _expectFormattedActiveInput(
        tester,
        session: session,
        textEditing: scenario.runtime.textEditing,
        controller: controller,
        focusNode: focusNode,
        value: valueBeforeFormatting,
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
      );

      session.updateFormatting(isUnderline: true);
      await tester.pump();
      expect(session.style.isBold, isTrue);
      expect(session.style.isItalic, isTrue);
      expect(session.style.isUnderline, isTrue);
      _expectFormattedActiveInput(
        tester,
        session: session,
        textEditing: scenario.runtime.textEditing,
        controller: controller,
        focusNode: focusNode,
        value: valueBeforeFormatting,
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
        decoration: TextDecoration.underline,
      );

      session.updateFormatting(
        isBold: false,
        isItalic: true,
        isUnderline: true,
      );
      await tester.pump();
      _expectFormattedActiveInput(
        tester,
        session: session,
        textEditing: scenario.runtime.textEditing,
        controller: controller,
        focusNode: focusNode,
        value: valueBeforeFormatting,
        fontWeight: FontWeight.normal,
        fontStyle: FontStyle.italic,
        decoration: TextDecoration.underline,
      );
      expect(_textElement(scenario.runtime).text, 'hello');
      expect(scenario.runtime.state.value.revisions.document, documentRevision);
      expect(scenario.actions, isEmpty);

      await tester.enterText(
        _editableTextFinder(),
        'continued after formatting',
      );
      await tester.pump();

      expect(scenario.activeSession, same(session));
      expect(session.liveText, 'continued after formatting');
      expect(focusNode.hasFocus, isTrue);
      expect(_textElement(scenario.runtime).text, 'hello');
      expect(scenario.runtime.state.value.revisions.document, documentRevision);
      expect(scenario.actions, isEmpty);
    },
  );
}

// The helper keeps every observation of one visible formatted editor together.
// Passing an opaque carrier would hide the surface interaction being proven.
// ignore: number-of-parameters
void _expectFormattedActiveInput(
  WidgetTester tester, {
  required CanvasTextEditSession session,
  required CanvasTextEditingPort textEditing,
  required TextEditingController controller,
  required FocusNode focusNode,
  required TextEditingValue value,
  required FontWeight fontWeight,
  required FontStyle fontStyle,
  TextDecoration? decoration,
}) {
  final editable = tester.widget<EditableText>(_editableTextFinder());

  expect(textEditing.activeSession.value, same(session));
  expect(editable.controller, same(controller));
  expect(editable.focusNode, same(focusNode));
  expect(focusNode.hasFocus, isTrue);
  expect(editable.style.fontWeight, fontWeight);
  expect(editable.style.fontStyle, fontStyle);
  expect(editable.style.decoration, decoration);
  expect(controller.value, value);
  expect(controller.value.selection, value.selection);
  expect(controller.value.composing, value.composing);
}

void _testAutoStartPolicy() {
  testWidgets('overlay auto-starts only when configured', (tester) async {
    final disabled = _OverlayScenario(inlineEditOnDoubleTap: false);
    addTearDown(disabled.dispose);
    await disabled.pump(tester);
    await disabled.doubleTapText(tester);

    expect(disabled.runtime.textEditing.activeSession.value, isNull);
    expect(find.byKey(canvasTextEditingOverlayEditableTextKey), findsNothing);

    final enabled = _OverlayScenario(inlineEditOnDoubleTap: true);
    addTearDown(enabled.dispose);
    await enabled.pump(tester);
    await enabled.doubleTapText(tester);

    expect(enabled.runtime.textEditing.activeSession.value, isNotNull);
    expect(find.byKey(canvasTextEditingOverlayEditableTextKey), findsOneWidget);
  });
}

// This follows the stock double-tap stream through widget replacement and
// completion, because a direct session start cannot show whether the overlay
// forwards its current configuration or overwrites an admitted session.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _testOverlayEmptyTextPolicyCapture() {
  testWidgets(
    'overlay captures configured empty policy across widget updates and repeat starts',
    (tester) async {
      final resolverRequests = <CanvasCommitRequest>[];
      late final _OverlayScenario scenario;
      scenario = _OverlayScenario(
        inlineEditOnDoubleTap: true,
        emptyTextBehavior: CanvasTextEditEmptyTextBehavior.deleteElement,
        config: CanvasRuntimeConfig(
          commitResolver: (request) {
            resolverRequests.add(request);
            expect(_textElement(scenario.runtime).text, 'hello');
            return const CanvasCommitAccept(lease: testAcceptingCommitLease);
          },
        ),
      );
      addTearDown(scenario.dispose);
      final documentRevision = scenario.runtime.state.value.revisions.document;

      await scenario.pump(tester);
      await scenario.doubleTapText(tester);
      final session = scenario.activeSession;
      final editable = tester.widget<EditableText>(_editableTextFinder());
      final controller = editable.controller;
      final focusNode = editable.focusNode;
      expect(
        session.emptyTextBehavior,
        CanvasTextEditEmptyTextBehavior.deleteElement,
      );

      await scenario.pump(
        tester,
        emptyTextBehavior: CanvasTextEditEmptyTextBehavior.keepElement,
      );
      await scenario.doubleTapText(tester);

      expect(scenario.activeSession, same(session));
      expect(
        scenario.activeSession.emptyTextBehavior,
        CanvasTextEditEmptyTextBehavior.deleteElement,
      );
      expect(
        tester.widget<EditableText>(_editableTextFinder()).controller,
        same(controller),
      );
      expect(
        tester.widget<EditableText>(_editableTextFinder()).focusNode,
        same(focusNode),
      );

      await tester.enterText(_editableTextFinder(), ' \n\t');
      await tester.pump();

      expect(_textElement(scenario.runtime).text, 'hello');
      expect(scenario.runtime.state.value.revisions.document, documentRevision);
      expect(resolverRequests, isEmpty);
      expect(scenario.actions, isEmpty);

      tester
          .widget<EditableText>(_editableTextFinder())
          .onEditingComplete
          ?.call();
      await tester.pump();

      expect(resolverRequests, hasLength(1));
      expect(resolverRequests.single, isA<CanvasDeleteCommitRequest>());
      expect(scenario.runtime.readDocument().layers.single.elements, isEmpty);
      expect(
        scenario.runtime.state.value.revisions.document,
        documentRevision + 1,
      );
      expect(scenario.actions, hasLength(1));
      expect(scenario.actions.single.type, CanvasActionType.deleteElements);
    },
  );

  testWidgets(
    'overlay reads changed empty policy for a later stock admission',
    (tester) async {
      final resolverRequests = <CanvasCommitRequest>[];
      final scenario = _OverlayScenario(
        inlineEditOnDoubleTap: true,
        emptyTextBehavior: CanvasTextEditEmptyTextBehavior.deleteElement,
        config: CanvasRuntimeConfig(
          commitResolver: (request) {
            resolverRequests.add(request);
            return const CanvasCommitAccept(lease: testAcceptingCommitLease);
          },
        ),
      );
      addTearDown(scenario.dispose);

      await scenario.pump(tester);
      await scenario.doubleTapText(tester);
      final initialSession = scenario.activeSession;
      expect(
        initialSession.emptyTextBehavior,
        CanvasTextEditEmptyTextBehavior.deleteElement,
      );

      await scenario.pump(
        tester,
        emptyTextBehavior: CanvasTextEditEmptyTextBehavior.keepElement,
      );
      initialSession.dismiss();
      await tester.pump();
      expect(scenario.runtime.textEditing.activeSession.value, isNull);

      await scenario.doubleTapText(tester);
      final laterSession = scenario.activeSession;
      expect(laterSession, isNot(same(initialSession)));
      expect(
        laterSession.emptyTextBehavior,
        CanvasTextEditEmptyTextBehavior.keepElement,
      );
      await tester.enterText(_editableTextFinder(), ' \n\t');
      await tester.pump();
      tester
          .widget<EditableText>(_editableTextFinder())
          .onEditingComplete
          ?.call();
      await tester.pump();

      expect(resolverRequests, hasLength(1));
      expect(resolverRequests.single, isA<CanvasTextEditCommitRequest>());
      expect(_textElement(scenario.runtime).text, ' \n\t');
      expect(scenario.actions.single.type, CanvasActionType.editText);
    },
  );

  test(
    'explicit ID admission with delete policy matches stock deletion',
    () async {
      final resolverRequests = <CanvasCommitRequest>[];
      final scenario = _OverlayScenario(
        inlineEditOnDoubleTap: false,
        config: CanvasRuntimeConfig(
          commitResolver: (request) {
            resolverRequests.add(request);
            return const CanvasCommitAccept(lease: testAcceptingCommitLease);
          },
        ),
      );
      try {
        final documentRevision =
            scenario.runtime.state.value.revisions.document;
        final result = scenario.runtime.textEditing.startForElement(
          CanvasElementId('text-a'),
          emptyTextBehavior: CanvasTextEditEmptyTextBehavior.deleteElement,
        );
        final session = switch (result) {
          CanvasTextEditStartSuccess(:final session) => session,
          CanvasTextEditStartRefusal(:final reason) => throw StateError(
            'Expected text session, got $reason.',
          ),
        };

        session.updateText(' \n\t');
        expect(_textElement(scenario.runtime).text, 'hello');
        expect(
          scenario.runtime.state.value.revisions.document,
          documentRevision,
        );
        expect(session.commit(), isTrue);

        expect(resolverRequests, hasLength(1));
        expect(resolverRequests.single, isA<CanvasDeleteCommitRequest>());
        expect(scenario.runtime.readDocument().layers.single.elements, isEmpty);
        expect(scenario.actions.single.type, CanvasActionType.deleteElements);
      } finally {
        await scenario.dispose();
      }
    },
  );

  testWidgets('omitted overlay empty policy keeps the whitespace text block', (
    tester,
  ) async {
    final resolverRequests = <CanvasCommitRequest>[];
    final scenario = _OverlayScenario(
      inlineEditOnDoubleTap: true,
      config: CanvasRuntimeConfig(
        commitResolver: (request) {
          resolverRequests.add(request);
          return const CanvasCommitAccept(lease: testAcceptingCommitLease);
        },
      ),
    );
    addTearDown(scenario.dispose);

    await scenario.pump(tester);
    await scenario.doubleTapText(tester);
    expect(
      scenario.activeSession.emptyTextBehavior,
      CanvasTextEditEmptyTextBehavior.keepElement,
    );
    await tester.enterText(_editableTextFinder(), ' \n\t');
    await tester.pump();
    tester
        .widget<EditableText>(_editableTextFinder())
        .onEditingComplete
        ?.call();
    await tester.pump();

    expect(resolverRequests, hasLength(1));
    expect(resolverRequests.single, isA<CanvasTextEditCommitRequest>());
    expect(_textElement(scenario.runtime).text, ' \n\t');
    expect(scenario.actions.single.type, CanvasActionType.editText);
  });
}

void _testReadOnlyPolicy() {
  testWidgets('overlay observes runtime read-only policy', (tester) async {
    final readOnlyStart = _OverlayScenario(inlineEditOnDoubleTap: true);
    addTearDown(readOnlyStart.dispose);
    readOnlyStart.runtime.textEditing.setReadOnly(true);
    await readOnlyStart.pump(tester);
    await readOnlyStart.doubleTapText(tester);

    expect(readOnlyStart.runtime.textEditing.activeSession.value, isNull);
    expect(find.byKey(canvasTextEditingOverlayEditableTextKey), findsNothing);

    final active = _OverlayScenario(inlineEditOnDoubleTap: true);
    addTearDown(active.dispose);
    await active.pump(tester);
    await active.doubleTapText(tester);

    expect(find.byKey(canvasTextEditingOverlayEditableTextKey), findsOneWidget);
    active.runtime.textEditing.setReadOnly(true);
    await tester.pump();

    expect(active.runtime.textEditing.activeSession.value, isNull);
    expect(find.byKey(canvasTextEditingOverlayEditableTextKey), findsNothing);
    expect(_textElement(active.runtime).text, 'hello');
  });
}

void _testCameraPanRepositionsActiveEditor() {
  testWidgets('overlay repositions active editor when runtime camera pans', (
    tester,
  ) async {
    final scenario = _OverlayScenario(
      inlineEditOnDoubleTap: true,
      document: _document(transform: CanvasTransform.translation(Offset.zero)),
    );
    addTearDown(scenario.dispose);
    await scenario.pump(tester);
    await scenario.doubleTapText(tester);
    final before = tester.getTopLeft(
      find.byKey(canvasTextEditingOverlayEditorHostKey),
    );

    scenario.runtime.camera.panBy(const Offset(12, 5));
    await tester.pump();

    expect(
      tester.getTopLeft(find.byKey(canvasTextEditingOverlayEditorHostKey)),
      before - const Offset(12, 5),
    );
    expect(scenario.activeSession.liveText, 'hello');
  });
}

// Commit and dismiss are paired here so the test proves both exits from the
// same official overlay lifecycle without duplicating fixture setup.
// ignore: halstead-volume
void _testCommitAndDismiss() {
  testWidgets(
    'overlay commits through session and dismisses without mutation',
    (tester) async {
      final committed = _OverlayScenario(inlineEditOnDoubleTap: true);
      addTearDown(committed.dispose);
      await committed.pump(tester);
      await committed.doubleTapText(tester);
      await tester.enterText(
        find.byKey(canvasTextEditingOverlayEditableTextKey),
        'committed',
      );
      await tester.pump();
      tester
          .widget<EditableText>(_editableTextFinder())
          .onEditingComplete
          ?.call();
      await tester.pump();

      expect(_textElement(committed.runtime).text, 'committed');
      expect(committed.runtime.textEditing.activeSession.value, isNull);
      expect(committed.actions.single.type, CanvasActionType.editText);

      final dismissed = _OverlayScenario(inlineEditOnDoubleTap: true);
      addTearDown(dismissed.dispose);
      await dismissed.pump(tester);
      await dismissed.doubleTapText(tester);
      await tester.enterText(
        find.byKey(canvasTextEditingOverlayEditableTextKey),
        'discarded',
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(_textElement(dismissed.runtime).text, 'hello');
      expect(dismissed.runtime.textEditing.activeSession.value, isNull);
      expect(dismissed.actions, isEmpty);
    },
  );
}

void _testFocusLossCommit() {
  testWidgets('overlay commits focus loss after focus notification completes', (
    tester,
  ) async {
    final otherFocusNode = FocusNode();
    addTearDown(otherFocusNode.dispose);
    final scenario = _OverlayScenario(
      inlineEditOnDoubleTap: true,
      autofocus: true,
      commitOnFocusLoss: true,
      trailingFocusNode: otherFocusNode,
    );
    addTearDown(scenario.dispose);
    await scenario.pump(tester);
    await scenario.doubleTapText(tester);
    expect(
      tester.widget<EditableText>(_editableTextFinder()).focusNode.hasFocus,
      isTrue,
    );

    await tester.enterText(
      find.byKey(canvasTextEditingOverlayEditableTextKey),
      'committed on blur',
    );
    await tester.pump();
    otherFocusNode.requestFocus();
    await tester.pump();
    await tester.pump();

    expect(_textElement(scenario.runtime).text, 'committed on blur');
    expect(scenario.runtime.textEditing.activeSession.value, isNull);
    expect(find.byKey(canvasTextEditingOverlayEditableTextKey), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

// Default growth and max-height scroll are the two sides of one sizing policy,
// keeping them adjacent makes the contrast explicit.
// ignore: halstead-volume, source-lines-of-code
void _testMultilineGrowthAndMaxHeightPolicy() {
  testWidgets('overlay grows with live multiline geometry by default', (
    tester,
  ) async {
    final scenario = _OverlayScenario(
      document: _document(maxWidth: 80, lineHeight: 1.0),
      inlineEditOnDoubleTap: true,
    );
    addTearDown(scenario.dispose);
    await scenario.pump(tester);
    await scenario.doubleTapText(tester);
    final initialTop = _editorHostRect(tester).top;
    final initialHeight = tester
        .getSize(find.byKey(canvasTextEditingOverlayEditorHostKey))
        .height;

    await tester.enterText(
      find.byKey(canvasTextEditingOverlayEditableTextKey),
      'line 1\nline 2\nline 3',
    );
    await tester.pump();

    final liveHeight = tester
        .getSize(find.byKey(canvasTextEditingOverlayEditorHostKey))
        .height;
    expect(_editorHostRect(tester).top, moreOrLessEquals(initialTop));
    expect(liveHeight, greaterThan(initialHeight));
    expect(
      liveHeight,
      _localEditBoundsFor(scenario.activeSession.geometry).height,
    );
    final editable = tester.widget<EditableText>(_editableTextFinder());
    expect(editable.scrollController, isNull);
    expect(editable.textInputAction, TextInputAction.newline);
    expect(editable.onSubmitted, isNull);
    expect(scenario.runtime.textEditing.activeSession.value, isNotNull);
    expect(scenario.actions, isEmpty);
  });

  testWidgets(
    'overlay clamps height and enables scroll when max height is set',
    (tester) async {
      const maxHeight = 24.0;
      final scenario = _OverlayScenario(
        document: _document(maxWidth: 80, lineHeight: 1.0),
        inlineEditOnDoubleTap: true,
        maxEditorHeight: maxHeight,
      );
      addTearDown(scenario.dispose);
      await scenario.pump(tester);
      await scenario.doubleTapText(tester);
      await tester.enterText(
        find.byKey(canvasTextEditingOverlayEditableTextKey),
        'line 1\nline 2\nline 3\nline 4',
      );
      await tester.pump();

      expect(
        tester
            .getSize(find.byKey(canvasTextEditingOverlayEditorHostKey))
            .height,
        maxHeight,
      );
      expect(
        tester.widget<EditableText>(_editableTextFinder()).scrollController,
        isNotNull,
      );
    },
  );
}

void _testDisposesListeners() {
  testWidgets('overlay disposes context and editor listeners', (tester) async {
    final scenario = _OverlayScenario(inlineEditOnDoubleTap: true);
    addTearDown(scenario.dispose);
    await scenario.pump(tester);
    await scenario.doubleTapText(tester);
    expect(find.byKey(canvasTextEditingOverlayEditableTextKey), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    scenario.runtime.tools.handleDoubleTap(position: Offset.zero);
    await tester.pump();

    expect(scenario.runtime.textEditing.activeSession.value, isNull);
    expect(tester.takeException(), isNull);
  });
}

// The runtime swap needs old-session cancellation and new-editor survival in
// one rendered lifecycle to rule out a local overlay replacement.
// ignore: halstead-volume
void _testRuntimeSwapCancelsPreviousDraft() {
  testWidgets(
    'overlay cancels its previous runtime draft during a runtime swap',
    (tester) async {
      final previous = _OverlayScenario(inlineEditOnDoubleTap: true);
      final replacement = _OverlayScenario(inlineEditOnDoubleTap: true);
      addTearDown(previous.dispose);
      addTearDown(replacement.dispose);
      await previous.pump(tester);
      await previous.doubleTapText(tester);
      final previousSession = previous.activeSession;
      final previousRevision = previous.runtime.state.value.revisions.document;
      final replacementSession = switch (replacement.runtime.textEditing
          .startForElement(CanvasElementId('text-a'))) {
        CanvasTextEditStartSuccess(:final session) => session,
        CanvasTextEditStartRefusal(:final reason) => throw StateError(
          'Expected replacement session, got $reason.',
        ),
      };

      await replacement.pump(tester);

      expect(previous.runtime.textEditing.activeSession.value, isNull);
      expect(previousSession.isActive, isFalse);
      expect(_textElement(previous.runtime).text, 'hello');
      expect(previous.runtime.state.value.revisions.document, previousRevision);
      expect(previous.actions, isEmpty);
      expect(
        replacement.runtime.textEditing.activeSession.value,
        same(replacementSession),
      );
      expect(
        find.byKey(canvasTextEditingOverlayEditableTextKey),
        findsOneWidget,
      );
      expect(_textElement(replacement.runtime).text, 'hello');
      expect(replacement.actions, isEmpty);
    },
  );
}

void _testOverlayDoesNotMeasureText() {
  test('official overlay does not construct a text measurer', () {
    final source = File(
      'lib/src/surface/text_editing_overlay.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('TextPainter')));
  });
}

// The scenario intentionally owns runtime, actions, surface host, and overlay
// configuration so each widget test observes the same public integration path.
// ignore: coupling-between-object-classes
final class _OverlayScenario {
  _OverlayScenario({
    required this.inlineEditOnDoubleTap,
    CanvasDocument? document,
    this.emptyTextBehavior,
    this.maxEditorHeight,
    this.autofocus = false,
    this.commitOnFocusLoss = false,
    this.trailingFocusNode,
    CanvasRuntimeConfig? config,
  }) : runtime = _runtimeWithOptionalConfig(document, config) {
    actionSubscription = runtime.actions.listen(actions.add);
  }

  final CanvasRuntime runtime;
  final bool inlineEditOnDoubleTap;
  final CanvasTextEditEmptyTextBehavior? emptyTextBehavior;
  final double? maxEditorHeight;
  final bool autofocus;
  final bool commitOnFocusLoss;
  final FocusNode? trailingFocusNode;
  final List<CanvasActionCommitted> actions = [];
  late final StreamSubscription<CanvasActionCommitted> actionSubscription;

  CanvasTextEditSession get activeSession {
    final session = runtime.textEditing.activeSession.value;
    if (session == null) {
      throw StateError('Expected an active text editing session.');
    }

    return session;
  }

  Future<void> pump(
    WidgetTester tester, {
    CanvasTextEditEmptyTextBehavior? emptyTextBehavior,
  }) {
    final configuredEmptyTextBehavior =
        emptyTextBehavior ?? this.emptyTextBehavior;
    final overlay = configuredEmptyTextBehavior == null
        ? CanvasTextEditingOverlay(
            runtime: runtime,
            inlineEditOnDoubleTap: inlineEditOnDoubleTap,
            maxEditorHeight: maxEditorHeight,
            autofocus: autofocus,
            commitOnFocusLoss: commitOnFocusLoss,
          )
        : CanvasTextEditingOverlay(
            runtime: runtime,
            inlineEditOnDoubleTap: inlineEditOnDoubleTap,
            emptyTextBehavior: configuredEmptyTextBehavior,
            maxEditorHeight: maxEditorHeight,
            autofocus: autofocus,
            commitOnFocusLoss: commitOnFocusLoss,
          );
    return tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 240,
          height: 160,
          child: Stack(
            children: [
              CanvasSurface(runtime: runtime, interactive: false),
              overlay,
              if (trailingFocusNode case final focusNode?)
                Focus(
                  focusNode: focusNode,
                  child: const SizedBox(width: 1, height: 1),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> doubleTapText(
    WidgetTester tester, [
    Offset position = Offset.zero,
  ]) async {
    runtime.tools.handleDoubleTap(position: position, timestampMs: 1);
    await tester.pump();
    await tester.pump();
  }

  Future<void> dispose() async {
    await actionSubscription.cancel();
    runtime.dispose();
  }
}

CanvasRuntime _runtimeWithOptionalConfig(
  CanvasDocument? document,
  CanvasRuntimeConfig? config,
) {
  final initialDocument = document ?? _document();
  if (config == null) {
    return runtimeWithDocument(initialDocument);
  }

  return runtimeWithDocument(initialDocument, config: config);
}

Finder _editableTextFinder() {
  return find.byKey(canvasTextEditingOverlayEditableTextKey);
}

void _expectEditorHostExtendsMeasuredWidth(
  WidgetTester tester,
  Rect localEditBounds,
) {
  final hostSize = tester.getSize(
    find.byKey(canvasTextEditingOverlayEditorHostKey),
  );

  expect(hostSize.height, localEditBounds.height);
  expect(hostSize.width, greaterThan(localEditBounds.width));
}

void _expectInlineEditorDisablesScrollbar(
  WidgetTester tester,
  EditableText editable,
) {
  final scrollBehavior = editable.scrollBehavior;
  if (scrollBehavior == null) {
    fail('Expected inline text editor to set a local scroll behavior.');
  }

  final child = scrollBehavior.buildScrollbar(
    tester.element(find.byKey(canvasTextEditingOverlayEditableTextKey)),
    const SizedBox(key: ValueKey<String>('inline-text-scroll-child')),
    const ScrollableDetails.vertical(),
  );
  expect(child.key, const ValueKey<String>('inline-text-scroll-child'));
}

Future<void> _expectLiveWidthAnchorFor(
  WidgetTester tester,
  TextAlign align,
) async {
  final scenario = _OverlayScenario(
    document: _document(text: 'edge', align: align),
    inlineEditOnDoubleTap: true,
  );
  addTearDown(scenario.dispose);

  await scenario.pump(tester);
  await scenario.doubleTapText(tester);
  final before = _editorHostRect(tester);

  await tester.enterText(
    find.byKey(canvasTextEditingOverlayEditableTextKey),
    'edge grows much wider',
  );
  await tester.pump();
  final after = _editorHostRect(tester);
  expect(after.width, greaterThan(before.width));

  switch (align) {
    case TextAlign.left:
    case TextAlign.start:
    case TextAlign.justify:
      expect(after.left, moreOrLessEquals(before.left));
    case TextAlign.right:
    case TextAlign.end:
      expect(after.right, moreOrLessEquals(before.right));
    case TextAlign.center:
      expect(after.center.dx, moreOrLessEquals(before.center.dx));
  }
}

Rect _editorHostRect(WidgetTester tester) {
  return tester.getRect(find.byKey(canvasTextEditingOverlayEditorHostKey));
}

Rect _localEditBoundsFor(CanvasTextEditGeometry geometry) {
  final bounds = geometry.editBoundsLocal;
  if (bounds == null) {
    throw StateError('Expected text edit local bounds.');
  }

  return bounds;
}

CanvasTextElement _textElement(CanvasRuntime runtime) {
  return runtime
      .readDocument()
      .layers
      .single
      .elements
      .whereType<CanvasTextElement>()
      .single;
}

bool _containsElement(CanvasRuntime runtime, CanvasElementId id) {
  return runtime.readDocument().layers.any(
    (layer) => layer.elements.any((element) => element.id == id),
  );
}

// Test documents list the public text style fields explicitly so each proof can
// opt into the exact style/geometry fact it asserts.
// ignore: number-of-parameters
CanvasDocument _document({
  Offset camera = Offset.zero,
  String text = 'hello',
  double fontSize = 16,
  Color color = const Color(0xFF111111),
  bool isBold = false,
  bool isItalic = false,
  bool isUnderline = false,
  String? fontFamily,
  double? lineHeight,
  TextAlign align = TextAlign.left,
  TextDirection textDirection = TextDirection.ltr,
  double? maxWidth,
  CanvasTransform transform = CanvasTransform.identity,
}) {
  return CanvasDocument(
    camera: CanvasCamera(offset: camera),
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasTextElement(
            id: CanvasElementId('text-a'),
            text: text,
            fontSize: fontSize,
            color: color,
            isBold: isBold,
            isItalic: isItalic,
            isUnderline: isUnderline,
            fontFamily: fontFamily,
            lineHeight: lineHeight,
            align: align,
            textDirection: textDirection,
            maxWidth: maxWidth,
            transform: transform,
          ),
        ],
      ),
    ],
  );
}
