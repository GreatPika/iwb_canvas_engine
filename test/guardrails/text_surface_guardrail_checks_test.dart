import 'package:test/test.dart';

import '../../tool/guardrails/src/guardrail_violation.dart';
import '../../tool/guardrails/src/text_surface_guardrail_checks.dart';
import 'fixtures/runner_backed_guardrail_test_support.dart';

void main() {
  _testRunnerBackedRegistration();
  _testFormulaTextBoundsRejection();
  _testHelperExtractedFormulaTextBoundsRejection();
  _testRuntimeFormulaTextBoundsRejection();
  _testUnauthorizedTextPainterRejection();
  _testOverlayTextPainterRejection();
  _testEditableTextOwnerRejection();
}

void _testRunnerBackedRegistration() {
  test('text and surface guardrails are runner-backed', () async {
    for (final spec in _runnerBackedSpecs) {
      expect(
        await guardrailIsRunnerBacked(
          id: spec.id,
          suites: spec.suites,
          proofPaths: spec.proofPaths,
        ),
        isTrue,
        reason: spec.id,
      );
    }
  });
}

void _testFormulaTextBoundsRejection() {
  test('formula-based text bounds fixture is rejected structurally', () async {
    final violations = checkTextSingleMeasuredLayoutSourceSources({
      'lib/src/frame/frame_text_layout_measurer.dart': _validMeasurerSource,
      'lib/src/geometry/geometry_policy.dart': '''
Rect _textBounds(FrameElementFacts facts) {
  if (facts.kind == CanvasElementKind.text) {
    return Rect.fromLTWH(0, 0, facts.text.length * facts.fontSize, facts.lineHeight);
  }
  return Rect.zero;
}
''',
    });

    expect(_guardrailIds(violations), {
      textSingleMeasuredLayoutSourceGuardrailId,
    });
    expect(
      await _violationsAreRunnerRejected(
        id: textSingleMeasuredLayoutSourceGuardrailId,
        violations: violations,
      ),
      isTrue,
    );
  });
}

void _testHelperExtractedFormulaTextBoundsRejection() {
  test('helper-extracted formula text bounds fixture is rejected', () async {
    final violations = checkTextSingleMeasuredLayoutSourceSources({
      'lib/src/frame/frame_text_layout_measurer.dart': _validMeasurerSource,
      'lib/src/geometry/geometry_policy.dart': '''
Rect _textBounds(FrameElementFacts facts) {
  return Rect.fromLTWH(0, 0, _estimatedWidth(facts), _estimatedHeight(facts));
}

double _estimatedWidth(FrameElementFacts facts) {
  return facts.text.length * facts.fontSize;
}

double _estimatedHeight(FrameElementFacts facts) {
  return facts.lineHeight;
}
''',
      'lib/src/runtime/runtime_root.dart': '''
CanvasTextEditGeometry _geometryFor(_RuntimeTextEditSessionState state) {
  return CanvasTextEditGeometry(
    paintBoundsWorld: Rect.zero,
    editBoundsWorld: Rect.fromLTRB(0, 0, state.liveText.length * state.style.fontSize, state.style.lineHeight),
    transform: CanvasTransform.identity,
    maxWidth: state.style.maxWidth,
    editBoundsLocal: Rect.zero,
  );
}
''',
    });

    expect(_guardrailIds(violations), {
      textSingleMeasuredLayoutSourceGuardrailId,
    });
    expect(
      await _violationsAreRunnerRejected(
        id: textSingleMeasuredLayoutSourceGuardrailId,
        violations: violations,
      ),
      isTrue,
    );
  });
}

void _testRuntimeFormulaTextBoundsRejection() {
  test('runtime formula-based edit geometry fixture is rejected', () async {
    final violations = checkTextSingleMeasuredLayoutSourceSources({
      'lib/src/frame/frame_text_layout_measurer.dart': _validMeasurerSource,
      'lib/src/runtime/runtime_root.dart': '''
CanvasTextEditGeometry _geometryFor(_RuntimeTextEditSessionState state) {
  return CanvasTextEditGeometry(
    paintBoundsWorld: Rect.zero,
    editBoundsWorld: Rect.fromLTWH(0, 0, state.liveText.length * state.style.fontSize, state.style.lineHeight),
    transform: CanvasTransform.identity,
    maxWidth: state.style.maxWidth,
    editBoundsLocal: Rect.zero,
  );
}
''',
    });

    expect(_guardrailIds(violations), {
      textSingleMeasuredLayoutSourceGuardrailId,
    });
    expect(
      await _violationsAreRunnerRejected(
        id: textSingleMeasuredLayoutSourceGuardrailId,
        violations: violations,
      ),
      isTrue,
    );
  });
}

void _testUnauthorizedTextPainterRejection() {
  test('non-source TextPainter fixtures are rejected structurally', () async {
    final violations = checkTextSingleMeasuredLayoutSourceSources({
      'lib/src/frame/frame_text_layout_measurer.dart': _validMeasurerSource,
      'lib/src/runtime/runtime_root.dart':
          'final painter = TextPainter(textDirection: TextDirection.ltr);',
      'lib/src/frame/render_family_caches.dart':
          'final painter = TextPainter .new(textDirection: TextDirection.ltr);',
    });

    expect(_guardrailIds(violations), {
      textSingleMeasuredLayoutSourceGuardrailId,
    });
    expect(
      await _violationsAreRunnerRejected(
        id: textSingleMeasuredLayoutSourceGuardrailId,
        violations: violations,
      ),
      isTrue,
    );
  });
}

void _testOverlayTextPainterRejection() {
  test(
    'duplicate overlay TextPainter fixture is rejected structurally',
    () async {
      final violations = checkNoOverlayTextPainterMeasurementSources({
        'example/lib/src/canvas_text_edit_overlay.dart':
            'final painter = TextPainter .new(textDirection: TextDirection.ltr);',
      });

      expect(_guardrailIds(violations), {
        textNoOverlayTextPainterMeasurementGuardrailId,
      });
      expect(
        await _violationsAreRunnerRejected(
          id: textNoOverlayTextPainterMeasurementGuardrailId,
          violations: violations,
        ),
        isTrue,
      );
    },
  );
}

void _testEditableTextOwnerRejection() {
  test('non-surface EditableText fixture is rejected structurally', () async {
    final violations = checkEditableTextSurfaceOnlySources({
      'lib/src/runtime/runtime_root.dart':
          'final editor = EditableText(controller: c, focusNode: f);',
      'lib/src/surface/text_editing_overlay.dart': 'EditableText();',
      'example/lib/src/example_editor.dart': 'EditableText();',
    });

    expect(_guardrailIds(violations), {
      surfaceEditableTextSurfaceOnlyGuardrailId,
    });
    expect(
      await _violationsAreRunnerRejected(
        id: surfaceEditableTextSurfaceOnlyGuardrailId,
        violations: violations,
      ),
      isTrue,
    );
  });
}

Set<String> _guardrailIds(List<GuardrailViolation> violations) {
  return violations.map((violation) => violation.guardrailId).toSet();
}

Future<bool> _violationsAreRunnerRejected({
  required String id,
  required List<GuardrailViolation> violations,
}) {
  return guardrailRejectsStructuralViolations(id: id, violations: violations);
}

const _validMeasurerSource = '''
final class FrameTextLayoutMeasurer implements MeasuredTextLayoutPort {
  TextPainter _textPainterFor() => TextPainter();
}
MeasuredTextLayout _measuredLayoutFor(TextPainter painter) => throw UnimplementedError();
''';

const _runnerBackedSpecs = [
  _GuardrailSpec(
    id: textSingleMeasuredLayoutSourceGuardrailId,
    suites: {'blocking', 'text', 'frame', 'geometry'},
    proofPaths: [
      'test/frame/measured_text_layout_test.dart',
      'test/guardrails/text_surface_guardrail_checks_test.dart',
    ],
  ),
  _GuardrailSpec(
    id: textNoOverlayTextPainterMeasurementGuardrailId,
    suites: {'blocking', 'text', 'surface'},
    proofPaths: [
      'test/surface/text_editing_overlay_test.dart',
      'test/guardrails/text_surface_guardrail_checks_test.dart',
    ],
  ),
  _GuardrailSpec(
    id: surfaceEditableTextSurfaceOnlyGuardrailId,
    suites: {'blocking', 'surface'},
    proofPaths: [
      'test/surface/text_editing_overlay_test.dart',
      'test/guardrails/text_surface_guardrail_checks_test.dart',
    ],
  ),
];

final class _GuardrailSpec {
  const _GuardrailSpec({
    required this.id,
    required this.suites,
    required this.proofPaths,
  });

  final String id;
  final Set<String> suites;
  final List<String> proofPaths;
}
