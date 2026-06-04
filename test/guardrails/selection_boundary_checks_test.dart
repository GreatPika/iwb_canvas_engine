import 'package:test/test.dart';

import '../../tool/guardrails/src/selection_boundary_checks.dart';
import '../support/guardrail_fixture_scan.dart';

void main() {
  _testProductionCode();
  _testRuntimeSelectionState();
  _testStoreSelectionState();
  _testNonSelectionElementFacts();
  _testRuntimeReadBoundaryFacts();
  _testActionHistoryAllowanceScope();
  _testCodecSelectionState();
  _testPublicApiSelectionState();
}

void _testRuntimeSelectionState() {
  test('selection owner check rejects runtime selection mirrors', () {
    return expectLater(
      _expectSelectionBoundaryViolation({
        'lib/src/runtime/bad_runtime_selection_state.dart': '''
import 'package:iwb_canvas_engine/src/api/canvas_ids.dart';

class BadRuntimeSelectionState {
  final selectedElementIds = <CanvasElementId>{};
  final selectionRevision = 0;
}
''',
      }, contains('lib/src/runtime/bad_runtime_selection_state.dart')),
      completes,
    );
  });
}

void _testProductionCode() {
  test('production document and store code do not retain selection state', () {
    return expectLater(checkSelectionOwnerSeparation(), completion(isEmpty));
  });
}

void _testStoreSelectionState() {
  test('selection owner check rejects selected ids in store state', () {
    return expectLater(
      _expectSelectionBoundaryViolation({
        'lib/src/store/bad_selected_ids.dart': '''
import 'package:iwb_canvas_engine/src/api/canvas_ids.dart';

class BadStoreState {
  final selectedElementIds = <CanvasElementId>{};
  final selection = <CanvasElementId>{};
}
''',
      }, contains('lib/src/store/bad_selected_ids.dart')),
      completes,
    );
  });
}

void _testNonSelectionElementFacts() {
  test('selection owner check allows non-selection element id facts', () {
    return expectLater(
      _expectNoSelectionBoundaryViolation({
        'lib/src/store/good_element_ids.dart': '''
import 'package:iwb_canvas_engine/src/api/canvas_ids.dart';

class GoodStoreState {
  final activeElementIds = <CanvasElementId, bool>{};
  final indexedElementIds = <CanvasElementId>{};
}
''',
      }),
      completes,
    );
  });
}

void _testRuntimeReadBoundaryFacts() {
  test('selection owner check allows runtime read-boundary fact contexts', () {
    return expectLater(
      _expectNoSelectionBoundaryViolation({
        'lib/src/runtime/runtime_command_facts_adapter.dart': '''
import 'package:iwb_canvas_engine/src/contracts/internal/selection_facts_port.dart';

final class RuntimeCommandFactsAdapter {
  const RuntimeCommandFactsAdapter(this._selection);

  final SelectionFactsPort _selection;
}

final class _CommandReadContext {
  const _CommandReadContext({required this.selection});

  final SelectionFacts selection;
}
''',
        'lib/src/runtime/runtime_interaction_read_adapter.dart': '''
import 'package:iwb_canvas_engine/src/contracts/internal/selection_facts_port.dart';

final class RuntimeInteractionReadAdapter {
  const RuntimeInteractionReadAdapter(this._selection);

  final SelectionFactsPort _selection;
}

final class _SelectedMoveStartReadContext {
  const _SelectedMoveStartReadContext({required this.selection});

  final SelectionFacts selection;
}

final class _InteractionReadContext {
  const _InteractionReadContext({required this.selection});

  final SelectionFacts selection;
}
''',
      }),
      completes,
    );
  });
}

void _testActionHistoryAllowanceScope() {
  test(
    'selection owner check rejects action-history names outside payload',
    () {
      return expectLater(
        _expectSelectionBoundaryViolation(
          {
            'lib/src/store/bad_action_history_names.dart': '''
import 'package:iwb_canvas_engine/src/api/canvas_ids.dart';

class BadStoreState {
  final previousSelection = <CanvasElementId>{};
  final nextSelection = <CanvasElementId>{};
}
''',
            'lib/src/store/bad_action_payload_name.dart': '''
import 'package:iwb_canvas_engine/src/api/canvas_ids.dart';

class CanvasSelectionActionPayload {
  final previousSelection = <CanvasElementId>{};
  final nextSelection = <CanvasElementId>{};
}
''',
          },
          containsAll([
            'lib/src/store/bad_action_history_names.dart',
            'lib/src/store/bad_action_payload_name.dart',
          ]),
        ),
        completes,
      );
    },
  );
}

void _testCodecSelectionState() {
  test('selection owner check rejects selection revision in codec state', () {
    return expectLater(
      _expectSelectionBoundaryViolation({
        'lib/src/codec/bad_selection_revision.dart': '''
class BadCodecState {
  int selectionRevision = 0;
}
''',
      }, contains('lib/src/codec/bad_selection_revision.dart')),
      completes,
    );
  });
}

void _testPublicApiSelectionState() {
  test('selection owner check rejects selected ids in public API state', () {
    return expectLater(
      _expectSelectionBoundaryViolation({
        'lib/src/api/bad_runtime_state.dart': '''
import 'package:iwb_canvas_engine/src/api/canvas_ids.dart';

final class BadRuntimeState {
  final selectedElementIds = <CanvasElementId>{};
  final selectionRevision = 0;
}
''',
      }, contains('lib/src/api/bad_runtime_state.dart')),
      completes,
    );
  });
}

Future<void> _expectSelectionBoundaryViolation(
  Map<String, String> files,
  Matcher pathsMatcher,
) {
  return withGuardrailFixtureScan(files, (scan) async {
    final violations = await checkSelectionOwnerSeparation(
      sources: scan.sources,
      analysisIncludedPaths: scan.analysisIncludedPaths,
    );

    expect(violations.map((violation) => violation.path), pathsMatcher);
  });
}

Future<void> _expectNoSelectionBoundaryViolation(Map<String, String> files) {
  return withGuardrailFixtureScan(files, (scan) async {
    final violations = await checkSelectionOwnerSeparation(
      sources: scan.sources,
      analysisIncludedPaths: scan.analysisIncludedPaths,
    );
    final checkedPaths = files.keys.toSet();
    final violationPaths = violations
        .map((violation) => violation.path)
        .toSet();

    expect(violationPaths.intersection(checkedPaths), isEmpty);
  });
}
