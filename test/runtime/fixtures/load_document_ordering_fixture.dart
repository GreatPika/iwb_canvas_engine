import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/edit/commit_plan.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  test('failed load prepares before interaction interruption', () {
    expect(_expectFailedLoadDoesNotInterrupt, returnsNormally);
  });

  test('successful load interrupts before install and publishes once', () {
    expect(_expectSuccessOrderingAndGuards, returnsNormally);
  });
}

void _expectFailedLoadDoesNotInterrupt() {
  final boundary = _RecordingLoadBoundary();
  final root = _runtimeRoot(boundary);
  final beforeState = root.state.value;

  expect(
    () => root.edits.loadDocument(_invalidReplacementDocument()),
    throwsA(
      isA<CanvasDataException>().having(
        (error) => error.code,
        'code',
        CanvasDataErrorCode.duplicateElementId,
      ),
    ),
  );

  expect(boundary.events, isEmpty);
  expect(root.readDocument().layers.single.elements.single.id.value, 'old');
  expect(root.state.value, beforeState);
}

void _expectSuccessOrderingAndGuards() {
  _SuccessfulLoadOrderingScenario().run();
}

final class _SuccessfulLoadOrderingScenario {
  final _RecordingLoadBoundary boundary = _RecordingLoadBoundary();
  final List<String> events = [];
  late final RuntimeRoot root;

  void run() {
    boundary
      ..onInterrupt = _recordInterrupt
      ..onPostInstallCleanup = _recordPostInstallCleanup;
    root = _runtimeRoot(boundary, observeEffects: _recordObserver);
    root.state.addListener(_recordState);

    root.edits.loadDocument(_replacementDocument());

    expect(events, ['interrupt', 'post-install-cleanup', 'state', 'observer']);
    expect(boundary.events, ['interrupt', 'post-install-cleanup']);
  }

  void _recordInterrupt() {
    events.add('interrupt');
    expect(root.readDocument().layers.single.elements.single.id.value, 'old');
  }

  void _recordPostInstallCleanup() {
    events.add('post-install-cleanup');
    expect(root.readDocument().backgroundElements.single.id.value, 'new');
  }

  void _recordState() {
    events.add('state');
    _expectPublishedLoadState(root);
    _expectDeliveryGuards(root);
  }

  void _recordObserver(List<CommitEffect> effects) {
    events.add('observer');
    expect(effects.whereType<PublicStateEffect>(), hasLength(1));
    _expectPublishedLoadState(root);
    _expectDeliveryGuards(root);
  }
}

RuntimeRoot _runtimeRoot(
  _RecordingLoadBoundary boundary, {
  void Function(List<CommitEffect> effects)? observeEffects,
}) {
  return RuntimeRoot.test(
    initialDocument: _initialDocument(),
    config: const CanvasRuntimeConfig(),
    loadInteractionBoundary: boundary,
    commitEffectObserver: observeEffects,
  );
}

void _expectPublishedLoadState(RuntimeRoot root) {
  expect(root.readDocument().backgroundElements.single.id.value, 'new');
  expect(root.state.value.summary.elementCount, 1);
  expect(root.state.value.revisions.document, 1);
  expect(root.state.value.revisions.epoch, 1);
}

void _expectDeliveryGuards(RuntimeRoot root) {
  _expectGuarded(() => root.edits.edit((_) {}));
  _expectGuarded(() => root.edits.loadDocument(CanvasDocument()));
  _expectGuarded(() => root.selection.setSelection([CanvasElementId('new')]));
  _expectGuarded(() => root.cameraPort().setOffset(const Offset(1, 1)));
  _expectGuarded(root.generateElementId);
  _expectGuarded(root.generateLayerId);
  _expectGuarded(root.generateResourceId);
  _expectGuarded(root.dispose);
}

void _expectGuarded(void Function() action) {
  expect(
    action,
    throwsA(
      isA<StateError>().having(
        (error) => error.message,
        'message',
        contains('post-commit effect delivery'),
      ),
    ),
  );
}

CanvasDocument _initialDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer'),
        elements: [
          CanvasRectElement(id: CanvasElementId('old'), size: const Size(1, 1)),
        ],
      ),
    ],
  );
}

CanvasDocument _replacementDocument() {
  return CanvasDocument(
    backgroundElements: [
      CanvasRectElement(id: CanvasElementId('new'), size: const Size(1, 1)),
    ],
  );
}

CanvasDocument _invalidReplacementDocument() {
  return CanvasDocument(
    backgroundElements: [
      CanvasRectElement(
        id: CanvasElementId('duplicate'),
        size: const Size(1, 1),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('duplicate'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}

final class _RecordingLoadBoundary implements LoadInteractionBoundary {
  final List<String> events = [];
  void Function()? onInterrupt;
  void Function()? onPostInstallCleanup;

  @override
  void interruptPreparedLoad() {
    events.add('interrupt');
    onInterrupt?.call();
  }

  @override
  void clearPostInstallFacts() {
    events.add('post-install-cleanup');
    onPostInstallCleanup?.call();
  }
}
