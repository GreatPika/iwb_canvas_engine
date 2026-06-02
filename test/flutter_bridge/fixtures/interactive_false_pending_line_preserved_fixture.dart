import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  _testInteractiveFalsePreservesPendingLineAndClearsEndpoint();
  _testInteractiveFalseRuntimeSwapCleansOldRuntime();
}

void _testInteractiveFalsePreservesPendingLineAndClearsEndpoint() {
  testWidgets('interactive false preserves pending line and clears endpoint', (
    tester,
  ) async {
    final scenario = _SurfaceScenario();
    addTearDown(scenario.dispose);

    await tester.pumpWidget(_surfaceHost(scenario.runtime, interactive: true));

    _startPendingLine(scenario.runtime);
    final pending = scenario.runtime.preview as CanvasPendingLineStartPreview;
    final before = scenario.runtime.state.value;

    await tester.pumpWidget(_surfaceHost(scenario.runtime, interactive: false));
    _expectPendingLinePreserved(scenario.runtime, before, pending);
    expect(scenario.actions, isEmpty);

    await tester.pumpWidget(_surfaceHost(scenario.runtime, interactive: true));
    _startLineEndpoint(scenario.runtime);
    expect(scenario.runtime.preview, isA<CanvasLinePreview>());

    await tester.pumpWidget(_surfaceHost(scenario.runtime, interactive: false));
    await _expectEndpointSessionCleared(tester, scenario);
  });
}

void _testInteractiveFalseRuntimeSwapCleansOldRuntime() {
  testWidgets('interactive false runtime swap cleans old runtime', (
    tester,
  ) async {
    final oldScenario = _SurfaceScenario();
    final newScenario = _SurfaceScenario();
    addTearDown(oldScenario.dispose);
    addTearDown(newScenario.dispose);

    await tester.pumpWidget(
      _surfaceHost(oldScenario.runtime, interactive: true),
    );
    _startPendingLine(oldScenario.runtime);
    _startLineEndpoint(oldScenario.runtime);
    expect(oldScenario.runtime.preview, isA<CanvasLinePreview>());

    await tester.pumpWidget(
      _surfaceHost(newScenario.runtime, interactive: false),
    );
    await tester.pump();

    expect(oldScenario.runtime.preview, isA<CanvasNoPreview>());
    expect(oldScenario.actions, isEmpty);
    expect(newScenario.runtime.preview, isA<CanvasNoPreview>());
    expect(newScenario.actions, isEmpty);
  });
}

void _startPendingLine(CanvasRuntime runtime) {
  runtime.tools.setMode(CanvasInteractionMode.draw);
  runtime.tools.setDrawStyle(
    CanvasDrawStyle(
      tool: CanvasDrawTool.line,
      color: const Color(0xFF778899),
      lineThickness: 4,
    ),
  );
  runtime.tools.handlePointer(
    _sample(CanvasPointerLifecyclePhase.down, const Offset(1, 2)),
  );
  runtime.tools.handlePointer(
    _sample(CanvasPointerLifecyclePhase.up, const Offset(1, 2), 12),
  );
}

void _expectPendingLinePreserved(
  CanvasRuntime runtime,
  CanvasRuntimeState before,
  CanvasPendingLineStartPreview expected,
) {
  final preview = runtime.preview as CanvasPendingLineStartPreview;
  expect(preview.start, expected.start);
  expect(preview.timestampMs, expected.timestampMs);
  expect(preview.color, expected.color);
  expect(preview.thickness, expected.thickness);
  expect(runtime.state.value.revisions.document, before.revisions.document);
  expect(runtime.state.value.revisions.preview, before.revisions.preview);
}

void _startLineEndpoint(CanvasRuntime runtime) {
  runtime.tools.handlePointer(
    _sample(CanvasPointerLifecyclePhase.down, const Offset(3, 4)),
  );
}

Future<void> _expectEndpointSessionCleared(
  WidgetTester tester,
  _SurfaceScenario scenario,
) async {
  expect(scenario.runtime.preview, isA<CanvasNoPreview>());
  expect(scenario.runtime.readDocument().layers, isEmpty);
  await tester.pump();
  expect(scenario.actions, isEmpty);

  scenario.runtime.tools.handlePointer(
    _sample(CanvasPointerLifecyclePhase.down, const Offset(3, 4)),
  );
  scenario.runtime.tools.handlePointer(
    _sample(CanvasPointerLifecyclePhase.up, const Offset(3, 4), 13),
  );

  final nextFirstTap =
      scenario.runtime.preview as CanvasPendingLineStartPreview;
  expect(nextFirstTap.start, const Offset(3, 4));
  expect(scenario.runtime.readDocument().layers, isEmpty);
  await tester.pump();
  expect(scenario.actions, isEmpty);
}

CanvasPointerSample _sample(
  CanvasPointerLifecyclePhase phase,
  Offset position, [
  int? timestampMs,
]) {
  return CanvasPointerSample(
    pointerId: 1,
    position: position,
    phase: phase,
    kind: PointerDeviceKind.touch,
    timestampMs: timestampMs,
  );
}

Widget _surfaceHost(CanvasRuntime runtime, {required bool interactive}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: 100,
      height: 100,
      child: CanvasSurface(runtime: runtime, interactive: interactive),
    ),
  );
}

final class _SurfaceScenario {
  _SurfaceScenario() {
    subscription = runtime.actions.listen(actions.add);
  }

  final runtime = CanvasRuntime();
  final actions = <CanvasActionCommitted>[];
  late final StreamSubscription<CanvasActionCommitted> subscription;

  Future<void> dispose() async {
    await subscription.cancel();
    runtime.dispose();
  }
}
