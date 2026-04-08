import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/canvas_pointer_input.dart';
import 'package:iwb_canvas_engine/src/contract/pointer_input.dart';
import 'package:iwb_canvas_engine/src/contract/scene_view_runtime.dart';
import 'package:iwb_canvas_engine/src/core/interaction_types.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/scene_controller_internal_access.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/pointer_session_token.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/scene_controller_interaction_runtime.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/scene_controller_pointer_session.dart';
import 'package:iwb_canvas_engine/src/interactive/scene_controller.dart';
import 'package:iwb_canvas_engine/src/interactive/scene_controller_interaction.dart';

// INV:INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY
// INV:INV-ENG-VIEW-POINTER-SEMANTICS-BOUNDARY

void main() {
  group('SceneController interaction contract', () {
    test('internal access exposes registered epoch and preview resolver', () {
      final controller = SceneController();
      addTearDown(controller.dispose);

      expect(sceneControllerInternalEpoch(controller), 0);
      expect(
        sceneControllerInternalPreviewDeltaForNode(controller, 'node-1'),
        Offset.zero,
      );
    });

    test('interaction listenable forwards add/remove listener', () {
      final controller = SceneController();
      addTearDown(controller.dispose);

      var completed = false;
      void listener() {}

      controller.interaction.addListener(listener);
      controller.interaction.removeListener(listener);

      completed = true;
      expect(completed, isTrue);
    });

    test('controller exposes view runtime pointer session through adapter', () {
      final controller = SceneController();
      addTearDown(controller.dispose);

      final runtime = sceneControllerViewRuntimeOf(controller);
      final session = runtime.createPointerSession(
        isMounted: () => true,
        hasLiveRawPointers: () => false,
      );
      addTearDown(session.dispose);

      expect(runtime, isA<SceneViewRuntime>());
      expect(session.pendingTapFlushTimestampMs, isNull);
    });

    test('session-routed pointer bypasses public interaction facade', () {
      final controller = _ThrowingInteractionController();
      addTearDown(controller.dispose);
      controller.interaction.setMode(CanvasMode.draw);
      controller.interaction.setDrawTool(DrawTool.pen);

      final session = sceneControllerViewRuntimeOf(controller)
          .createPointerSession(
            isMounted: () => true,
            hasLiveRawPointers: () => false,
          );
      addTearDown(session.dispose);

      expect(
        () => session.handleRoutedSample(
          const PointerSample(
            pointerId: 1,
            position: Offset(10, 10),
            timestampMs: 1,
            phase: PointerPhase.down,
            kind: PointerDeviceKind.touch,
          ),
          shouldTrackSignals: false,
        ),
        returnsNormally,
      );
      expect(controller.interaction.hasActiveStrokePreview, isTrue);
    });

    test('session runtime rejects unknown pointer session token', () {
      final controller = SceneController();
      addTearDown(controller.dispose);

      final runtime = sceneControllerInternalInteractionAccessForTest(
        controller,
      ).runtime;

      expect(
        () => runtime.handlePointerFromSession(
          const CanvasPointerInput(
            pointerId: 1,
            position: Offset(4, 4),
            phase: CanvasPointerPhase.down,
            kind: PointerDeviceKind.touch,
            timestampMs: 1,
          ),
          token: PointerSessionToken(),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Unknown pointer session token.',
          ),
        ),
      );
    });

    test('disposed session invalidates its pointer session token', () {
      final controller = SceneController();
      addTearDown(controller.dispose);
      controller.interaction.setMode(CanvasMode.draw);
      controller.interaction.setDrawTool(DrawTool.pen);

      final session = sceneControllerViewRuntimeOf(controller)
          .createPointerSession(
            isMounted: () => true,
            hasLiveRawPointers: () => false,
          );
      session.dispose();

      expect(
        () => session.handleRoutedSample(
          const PointerSample(
            pointerId: 1,
            position: Offset(10, 10),
            timestampMs: 1,
            phase: PointerPhase.down,
            kind: PointerDeviceKind.touch,
          ),
          shouldTrackSignals: false,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Unknown pointer session token.',
          ),
        ),
      );
    });

    test('session dispose stays safe after controller dispose', () {
      final controller = SceneController();
      final session = sceneControllerViewRuntimeOf(controller)
          .createPointerSession(
            isMounted: () => true,
            hasLiveRawPointers: () => false,
          );

      controller.dispose();

      expect(() => session.dispose(), returnsNormally);
    });

    test(
      'session pointer boundary routes double tap through session callback',
      () {
        final ownerListenable = ChangeNotifier();
        addTearDown(ownerListenable.dispose);
        final routedDoubleTaps = <(Offset, int?)>[];
        final session = SceneControllerPointerSession(
          ownerListenable: ownerListenable,
          token: PointerSessionToken(),
          readPointerSettings: () =>
              const PointerInputSettings(doubleTapMaxDelayMs: 300),
          isMounted: () => true,
          hasLiveRawPointers: () => false,
          releasePointerSessionToken: (_) {},
          handlePointerFromSession:
              (
                CanvasPointerInput input, {
                required PointerSessionToken token,
              }) {},
          handleDoubleTapFromSession:
              ({
                required Offset position,
                int? timestampMs,
                required PointerSessionToken token,
              }) {
                routedDoubleTaps.add((position, timestampMs));
              },
        );
        addTearDown(session.dispose);

        for (final sample in <PointerSample>[
          const PointerSample(
            pointerId: 1,
            position: Offset(8, 8),
            timestampMs: 1,
            phase: PointerPhase.down,
            kind: PointerDeviceKind.touch,
          ),
          const PointerSample(
            pointerId: 1,
            position: Offset(8, 8),
            timestampMs: 2,
            phase: PointerPhase.up,
            kind: PointerDeviceKind.touch,
          ),
          const PointerSample(
            pointerId: 1,
            position: Offset(8, 8),
            timestampMs: 3,
            phase: PointerPhase.down,
            kind: PointerDeviceKind.touch,
          ),
          const PointerSample(
            pointerId: 1,
            position: Offset(8, 8),
            timestampMs: 4,
            phase: PointerPhase.up,
            kind: PointerDeviceKind.touch,
          ),
        ]) {
          session.handleRoutedSample(sample, shouldTrackSignals: true);
        }

        expect(routedDoubleTaps, hasLength(1));
      },
    );
  });
}

class _ThrowingInteractionController extends SceneController {
  _ThrowingInteractionController();

  late final SceneControllerInteraction _interaction =
      _ThrowingSessionTransportInteraction(
        sceneControllerInternalInteractionAccessForTest(this),
      );

  @override
  SceneControllerInteraction get interaction => _interaction;
}

class _ThrowingSessionTransportInteraction extends SceneControllerInteraction {
  _ThrowingSessionTransportInteraction(super.access);

  @override
  void handlePointer(CanvasPointerInput input) {
    throw StateError('public handlePointer must not transport session input');
  }

  @override
  void handleDoubleTap({required Offset position, int? timestampMs}) {
    throw StateError(
      'public handleDoubleTap must not transport session double taps',
    );
  }
}
