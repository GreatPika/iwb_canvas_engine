// ignore_for_file: missing-test-assertion

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/surface_frame_signal.dart';
import 'package:iwb_canvas_engine/src/surface/surface_frame_output_cache.dart';

void main() {
  _testOverlayRuntimeTarget();
  _testMainRuntimeTarget();
  _testBothLayerTargets();
  _testBothLayerLocalInputChanges();
  _testMainOnlyLocalInputChanges();
  _testLocalInputFailureDoesNotCommitKey();
  _testOneLayerFailureKeepsPreviousOutput();
  _testBothLayerFailurePublishesNeitherOutput();
}

void _testOverlayRuntimeTarget() {
  test('overlay runtime target rebuilds only overlay output', () {
    final scenario = _Scenario();
    addTearDown(scenario.dispose);

    scenario.updateLocalInputs();
    final initialMain = scenario.cache.mainOutput.value;
    final initialOverlay = scenario.cache.overlayOutput.value;

    scenario.applyRuntime(main: false, overlay: true);
    expect(scenario.mainBuilds, 1);
    expect(scenario.overlayBuilds, 2);
    expect(scenario.cache.mainOutput.value, same(initialMain));
    expect(scenario.cache.overlayOutput.value, isNot(same(initialOverlay)));
    expect(scenario.mainNotifications, 1);
    expect(scenario.overlayNotifications, 2);
  });
}

void _testMainRuntimeTarget() {
  test('main runtime target rebuilds only main output', () {
    final scenario = _Scenario();
    addTearDown(scenario.dispose);

    scenario.updateLocalInputs();
    final initialOverlay = scenario.cache.overlayOutput.value;
    scenario.applyRuntime(main: true, overlay: false);
    expect(scenario.mainBuilds, 2);
    expect(scenario.overlayBuilds, 1);
    expect(scenario.cache.overlayOutput.value, same(initialOverlay));
    expect(scenario.mainNotifications, 2);
    expect(scenario.overlayNotifications, 1);
  });
}

void _testBothLayerTargets() {
  test('both-layer and unknown targets build both outputs once', () {
    final scenario = _Scenario();
    addTearDown(scenario.dispose);

    scenario.applyRuntime(main: true, overlay: true, reason: 'camera');
    expect(scenario.mainBuilds, 1);
    expect(scenario.overlayBuilds, 1);
    expect(scenario.mainNotifications, 1);
    expect(scenario.overlayNotifications, 1);

    scenario.applyRuntime(
      main: true,
      overlay: true,
      reason: 'unclassified_runtime_state',
    );
    expect(scenario.mainBuilds, 2);
    expect(scenario.overlayBuilds, 2);
    expect(scenario.mainNotifications, 2);
    expect(scenario.overlayNotifications, 2);
  });
}

void _testBothLayerLocalInputChanges() {
  test('both-layer local input key changes rebuild both outputs', () {
    final scenario = _Scenario();
    addTearDown(scenario.dispose);

    scenario.updateLocalInputs();
    _expectBuilds(scenario, main: 1, overlay: 1);
    scenario.updateLocalInputs();
    _expectBuilds(scenario, main: 1, overlay: 1);

    scenario.updateLocalInputs(const _LocalInputChange(runtimeKey: Object()));
    _expectBuilds(scenario, main: 2, overlay: 2);
    scenario.updateLocalInputs(
      const _LocalInputChange(viewport: Rect.fromLTWH(0, 0, 20, 20)),
    );
    _expectBuilds(scenario, main: 3, overlay: 3);
    scenario.updateLocalInputs(const _LocalInputChange(devicePixelRatio: 2));
    _expectBuilds(scenario, main: 4, overlay: 4);
    scenario.updateLocalInputs(
      _LocalInputChange(
        selectionStyle: CanvasSelectionStyle(color: const Color(0xFF0000FF)),
      ),
    );
    _expectBuilds(scenario, main: 5, overlay: 5);
  });
}

void _testMainOnlyLocalInputChanges() {
  test('main-only local input key changes preserve overlay output', () {
    final scenario = _Scenario();
    addTearDown(scenario.dispose);

    scenario.updateLocalInputs();
    _expectBuilds(scenario, main: 1, overlay: 1);

    final overlayBeforeMainOnly = scenario.cache.overlayOutput.value;
    scenario.updateLocalInputs(
      _LocalInputChange(gridStyle: CanvasGridStyle(strokeWidth: 2)),
    );
    _expectBuilds(scenario, main: 2, overlay: 1);
    scenario.updateLocalInputs(const _LocalInputChange(resolverGeneration: 1));
    _expectBuilds(scenario, main: 3, overlay: 1);
    scenario.applyBudgetFollowUp();
    _expectBuilds(scenario, main: 4, overlay: 1);
    expect(scenario.cache.overlayOutput.value, same(overlayBeforeMainOnly));
  });
}

void _testLocalInputFailureDoesNotCommitKey() {
  test('local input build failure does not commit the new key', () {
    final scenario = _Scenario();
    addTearDown(scenario.dispose);

    scenario.updateLocalInputs();
    final failedKey = _LocalInputChange(
      selectionStyle: CanvasSelectionStyle(color: const Color(0xFFAA00AA)),
    );
    expect(
      () => scenario.updateLocalInputsWithMainBuilder(
        failedKey,
        scenario.throwingMain,
      ),
      throwsStateError,
    );

    scenario.updateLocalInputs(failedKey);

    expect(scenario.mainBuilds, 2);
    expect(scenario.overlayBuilds, 2);
  });
}

void _testOneLayerFailureKeepsPreviousOutput() {
  test('one-layer build failure keeps previous output published', () {
    final scenario = _Scenario();
    addTearDown(scenario.dispose);
    scenario.updateLocalInputs();
    final previousMain = scenario.cache.mainOutput.value;
    final previousOverlay = scenario.cache.overlayOutput.value;

    expect(
      () => scenario.cache.applyRuntimeFrame(
        _frame(main: true, overlay: false),
        buildMain: scenario.throwingMain,
        buildOverlay: scenario.buildOverlay,
      ),
      throwsStateError,
    );

    expect(scenario.cache.mainOutput.value, same(previousMain));
    expect(scenario.cache.overlayOutput.value, same(previousOverlay));
    expect(scenario.mainNotifications, 1);
    expect(scenario.overlayNotifications, 1);
  });
}

void _testBothLayerFailurePublishesNeitherOutput() {
  test('both-layer build failure publishes neither layer output', () {
    final scenario = _Scenario();
    addTearDown(scenario.dispose);
    scenario.updateLocalInputs();
    final previousMain = scenario.cache.mainOutput.value;
    final previousOverlay = scenario.cache.overlayOutput.value;

    expect(
      () => scenario.cache.applyRuntimeFrame(
        _frame(main: true, overlay: true),
        buildMain: scenario.buildMain,
        buildOverlay: scenario.throwingOverlay,
      ),
      throwsStateError,
    );

    expect(scenario.cache.mainOutput.value, same(previousMain));
    expect(scenario.cache.overlayOutput.value, same(previousOverlay));
    expect(scenario.mainNotifications, 1);
    expect(scenario.overlayNotifications, 1);
  });
}

final class _Scenario {
  _Scenario() {
    cache.mainOutput.addListener(() {
      mainNotifications += 1;
    });
    cache.overlayOutput.addListener(() {
      overlayNotifications += 1;
    });
  }

  final cache = SurfaceFrameOutputCache<_Output, _Output>();
  int mainBuilds = 0;
  int overlayBuilds = 0;
  int mainNotifications = 0;
  int overlayNotifications = 0;
  Object _runtimeKey = Object();
  Rect _viewport = const Rect.fromLTWH(0, 0, 10, 10);
  double _devicePixelRatio = 1;
  CanvasSelectionStyle _selectionStyle = CanvasSelectionStyle.defaultStyle;
  CanvasGridStyle _gridStyle = CanvasGridStyle.defaultStyle;
  int _resolverGeneration = 0;

  void applyRuntime({
    required bool main,
    required bool overlay,
    String reason = 'test',
  }) {
    cache.applyRuntimeFrame(
      _frame(main: main, overlay: overlay, reason: reason),
      buildMain: buildMain,
      buildOverlay: buildOverlay,
    );
  }

  void updateLocalInputs([
    _LocalInputChange change = const _LocalInputChange(),
  ]) {
    updateLocalInputsWithMainBuilder(change, buildMain);
  }

  void updateLocalInputsWithMainBuilder(
    _LocalInputChange change,
    _Output Function() mainBuilder,
  ) {
    _runtimeKey = change.runtimeKey ?? _runtimeKey;
    _viewport = change.viewport ?? _viewport;
    _devicePixelRatio = change.devicePixelRatio ?? _devicePixelRatio;
    _selectionStyle = change.selectionStyle ?? _selectionStyle;
    _gridStyle = change.gridStyle ?? _gridStyle;
    _resolverGeneration = change.resolverGeneration ?? _resolverGeneration;
    cache.updateLocalInputs(
      SurfaceFrameLocalInputKey(
        runtimeKey: _runtimeKey,
        viewportWorldBounds: _viewport,
        devicePixelRatio: _devicePixelRatio,
        selectionStyle: _selectionStyle,
        gridStyle: _gridStyle,
        resolverGeneration: _resolverGeneration,
      ),
      buildMain: mainBuilder,
      buildOverlay: buildOverlay,
    );
  }

  void applyBudgetFollowUp() {
    cache.applyLocalRepaintRequest(
      SurfaceFrameLocalRepaintRequest.resourceBudgetFollowUp,
      buildMain: buildMain,
    );
  }

  _Output buildMain() {
    mainBuilds += 1;

    return _Output('main-$mainBuilds');
  }

  _Output buildOverlay() {
    overlayBuilds += 1;

    return _Output('overlay-$overlayBuilds');
  }

  _Output throwingMain() {
    throw StateError('main build failed');
  }

  _Output throwingOverlay() {
    throw StateError('overlay build failed');
  }

  void dispose() {
    cache.dispose();
  }
}

final class _LocalInputChange {
  const _LocalInputChange({
    this.runtimeKey,
    this.viewport,
    this.devicePixelRatio,
    this.selectionStyle,
    this.gridStyle,
    this.resolverGeneration,
  });

  final Object? runtimeKey;
  final Rect? viewport;
  final double? devicePixelRatio;
  final CanvasSelectionStyle? selectionStyle;
  final CanvasGridStyle? gridStyle;
  final int? resolverGeneration;
}

final class _Output {
  const _Output(this.id);

  final String id;
}

CanvasRuntimeSurfaceFrame _frame({
  required bool main,
  required bool overlay,
  String reason = 'test',
}) {
  return CanvasRuntimeSurfaceFrame(
    state: _state(),
    generation: 1,
    repaintTarget: CanvasSurfaceRepaintTarget(
      mainCanvas: main,
      overlayCanvas: overlay,
      reason: reason,
    ),
  );
}

CanvasRuntimeState _state() {
  return const CanvasRuntimeState(
    revisions: CanvasRuntimeRevisions(
      document: 0,
      selection: 0,
      preview: 0,
      viewCamera: 0,
      resourceVisual: 0,
      interaction: 0,
      epoch: 0,
    ),
    summary: CanvasRuntimeSummary(
      elementCount: 0,
      layerCount: 0,
      resourceCount: 0,
      selectedCount: 0,
    ),
  );
}

void _expectBuilds(
  _Scenario scenario, {
  required int main,
  required int overlay,
}) {
  expect(scenario.mainBuilds, main);
  expect(scenario.overlayBuilds, overlay);
}
