import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/canvas_pointer_input.dart';
import 'package:iwb_canvas_engine/src/contract/pointer_input.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/core/immutable_collections.dart';
import 'package:iwb_canvas_engine/src/contract/scene_view_runtime.dart';
import 'package:iwb_canvas_engine/src/core/interaction_types.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/scene_controller_internal_access.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/pointer_session_token.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/scene_controller_interaction_runtime.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/scene_controller_pointer_session.dart';
import 'package:iwb_canvas_engine/src/interactive/scene_controller.dart';
import 'package:iwb_canvas_engine/src/interactive/scene_controller_interaction.dart';

// INV:INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY
// INV:INV-ENG-INTERACTIVE-POINTER-SESSION-LIFECYCLE
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

    test(
      'internal access routes move commit resolver through request seam',
      () {
        late MoveCommitDeltaRequest capturedRequest;
        final controller = SceneController(
          moveCommitDeltaResolver: (request) {
            capturedRequest = request;
            expect(
              () => (request.movedNodes as List<NodeSnapshot>).removeLast(),
              throwsUnsupportedError,
            );
            return const Offset(7, 0);
          },
        );
        addTearDown(controller.dispose);

        final snapshot = SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-0',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(id: 'node', size: const Size(20, 10)),
              ],
            ),
          ],
        );
        final request = MoveCommitDeltaRequest(
          snapshot: snapshot,
          movedNodes: snapshot.layers.single.nodes,
          proposedDelta: const Offset(5, 0),
        );

        final resolved =
            sceneControllerInternalRunMoveCommitDeltaResolverForTest(
              controller,
              request,
            );

        expect(resolved, const Offset(7, 0));
        expect(capturedRequest, same(request));
        expect(capturedRequest.proposedDelta, const Offset(5, 0));
        expect(capturedRequest.movedNodes.map((node) => node.id), <NodeId>[
          'node',
        ]);
      },
    );

    test('move commit request reuses already frozen moved nodes', () {
      final snapshot = SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'layer-auto-0',
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(id: 'node', size: const Size(20, 10)),
            ],
          ),
        ],
      );
      final frozenMovedNodes = freezeList<NodeSnapshot>(
        snapshot.layers.single.nodes,
      );

      final request = MoveCommitDeltaRequest(
        snapshot: snapshot,
        movedNodes: frozenMovedNodes,
        proposedDelta: const Offset(5, 0),
      );
      final movedNodes = request.movedNodes as List<NodeSnapshot>;

      expect(request.movedNodes, same(frozenMovedNodes));
      expect(
        () => movedNodes[0] = RectNodeSnapshot(
          id: 'other',
          size: const Size(10, 10),
        ),
        throwsUnsupportedError,
      );
      expect(() => movedNodes.length = 0, throwsUnsupportedError);
      expect(() => movedNodes.removeLast(), throwsUnsupportedError);
    });

    test('controller exposes view runtime pointer session through adapter', () {
      final controller = SceneController();
      addTearDown(controller.dispose);

      final runtime = sceneControllerViewRuntimeOf(controller);
      final session = runtime.createPointerSession(
        isMounted: () => true,
        hasLiveRawPointers: () => false,
      );
      addTearDown(() {
        session.detach();
        session.dispose();
      });

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
      addTearDown(() {
        session.detach();
        session.dispose();
      });

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

    test('disposed session turns later routed samples into local no-op', () {
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
        returnsNormally,
      );
      expect(controller.interaction.hasActiveStrokePreview, isFalse);
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
      'disposed controller turns an already-created live session into local no-op',
      () {
        final controller = SceneController();
        final session = sceneControllerViewRuntimeOf(controller)
            .createPointerSession(
              isMounted: () => true,
              hasLiveRawPointers: () => false,
            );
        var actionCount = 0;
        var editRequestCount = 0;
        final actionSub = controller.actions.listen((_) {
          actionCount += 1;
        });
        final editSub = controller.editTextRequests.listen((_) {
          editRequestCount += 1;
        });
        addTearDown(actionSub.cancel);
        addTearDown(editSub.cancel);

        controller.dispose();

        expect(
          () => session.handleRoutedSample(
            const PointerSample(
              pointerId: 1,
              position: Offset(4, 4),
              timestampMs: 1,
              phase: PointerPhase.down,
              kind: PointerDeviceKind.touch,
            ),
            shouldTrackSignals: true,
          ),
          returnsNormally,
        );
        expect(
          () => session.handleRoutedSample(
            const PointerSample(
              pointerId: 1,
              position: Offset(4, 4),
              timestampMs: 2,
              phase: PointerPhase.up,
              kind: PointerDeviceKind.touch,
            ),
            shouldTrackSignals: true,
          ),
          returnsNormally,
        );
        expect(
          () => session.handleInvalidTerminalSample(
            input: const CanvasPointerInput(
              pointerId: 1,
              position: Offset(4, 4),
              phase: CanvasPointerPhase.cancel,
              kind: PointerDeviceKind.touch,
              timestampMs: 3,
            ),
            pointerId: 1,
            referenceTimestampMs: 3,
          ),
          returnsNormally,
        );
        expect(actionCount, 0);
        expect(editRequestCount, 0);
      },
    );

    test(
      'disposed runtime turns previously live runtime callbacks into local no-op',
      () {
        final controller = SceneController();
        final runtime = sceneControllerInternalInteractionAccessForTest(
          controller,
        ).runtime;
        final ownerListenable = ChangeNotifier();
        addTearDown(ownerListenable.dispose);
        final token = runtime.createPointerSessionToken();
        final session = SceneControllerPointerSession(
          ownerListenable: ownerListenable,
          token: token,
          readPointerSettings: () => const PointerInputSettings(),
          isMounted: () => true,
          hasLiveRawPointers: () => false,
          detachPointerSession: runtime.detachPointerSession,
          releasePointerSessionToken: runtime.releasePointerSessionToken,
          handlePointerFromSession: runtime.handlePointerFromSession,
          handleDoubleTapFromSession: runtime.handleDoubleTapFromSession,
        );
        addTearDown(session.dispose);
        runtime.registerPointerSession(session, token: token);

        controller.dispose();

        expect(
          () => runtime.handlePointerFromSession(
            const CanvasPointerInput(
              pointerId: 1,
              position: Offset(4, 4),
              phase: CanvasPointerPhase.down,
              kind: PointerDeviceKind.touch,
              timestampMs: 1,
            ),
            token: token,
          ),
          returnsNormally,
        );
        expect(
          () => runtime.handleDoubleTapFromSession(
            position: const Offset(4, 4),
            timestampMs: 2,
            token: token,
          ),
          returnsNormally,
        );
      },
    );

    test('disposed controller runtime rejects pointer session creation', () {
      final controller = SceneController();
      final runtime = sceneControllerViewRuntimeOf(controller);

      controller.dispose();

      expect(
        () => runtime.createPointerSession(
          isMounted: () => true,
          hasLiveRawPointers: () => false,
        ),
        throwsStateError,
      );
    });

    test(
      'detached session becomes local no-op and keeps dispose sequence safe',
      () async {
        final ownerListenable = _TrackingListenable();
        final pointerInputs = <CanvasPointerInput>[];
        final detachedTokens = <PointerSessionToken>[];
        final releasedTokens = <PointerSessionToken>[];
        final session = SceneControllerPointerSession(
          ownerListenable: ownerListenable,
          token: PointerSessionToken(),
          readPointerSettings: () =>
              const PointerInputSettings(doubleTapMaxDelayMs: 20),
          isMounted: () => true,
          hasLiveRawPointers: () => false,
          detachPointerSession: detachedTokens.add,
          releasePointerSessionToken: releasedTokens.add,
          handlePointerFromSession:
              (CanvasPointerInput input, {required PointerSessionToken token}) {
                pointerInputs.add(input);
              },
          handleDoubleTapFromSession:
              ({
                required Offset position,
                int? timestampMs,
                required PointerSessionToken token,
              }) {},
        );
        addTearDown(session.dispose);

        session.handleRoutedSample(
          const PointerSample(
            pointerId: 1,
            position: Offset(8, 8),
            timestampMs: 1,
            phase: PointerPhase.down,
            kind: PointerDeviceKind.touch,
          ),
          shouldTrackSignals: true,
        );
        session.handleRoutedSample(
          const PointerSample(
            pointerId: 1,
            position: Offset(8, 8),
            timestampMs: 2,
            phase: PointerPhase.up,
            kind: PointerDeviceKind.touch,
          ),
          shouldTrackSignals: true,
        );

        expect(session.pendingTapFlushTimestampMs, isNotNull);

        session.detach();
        session.detach();

        expect(session.pendingTapFlushTimestampMs, isNull);
        expect(detachedTokens, hasLength(1));
        expect(releasedTokens, hasLength(1));
        expect(ownerListenable.activeListenerCount, 0);

        ownerListenable.notifyListeners();
        session.handleRoutedSample(
          const PointerSample(
            pointerId: 2,
            position: Offset(12, 12),
            timestampMs: 3,
            phase: PointerPhase.down,
            kind: PointerDeviceKind.touch,
          ),
          shouldTrackSignals: true,
        );
        session.handleInvalidTerminalSample(
          input: const CanvasPointerInput(
            pointerId: 1,
            position: Offset(8, 8),
            timestampMs: 4,
            phase: CanvasPointerPhase.cancel,
            kind: PointerDeviceKind.touch,
          ),
          pointerId: 1,
          referenceTimestampMs: 4,
        );
        session.handleRawPointerRelease(isIdleAfterRelease: true);

        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(pointerInputs, hasLength(2));
        expect(releasedTokens, hasLength(1));

        session.dispose();
        session.detach();

        expect(releasedTokens, hasLength(1));
      },
    );

    test('dispose preserves detach semantics for live session', () {
      final ownerListenable = ChangeNotifier();
      addTearDown(ownerListenable.dispose);
      final detachedTokens = <PointerSessionToken>[];
      final releasedTokens = <PointerSessionToken>[];
      final session = SceneControllerPointerSession(
        ownerListenable: ownerListenable,
        token: PointerSessionToken(),
        readPointerSettings: () => const PointerInputSettings(),
        isMounted: () => true,
        hasLiveRawPointers: () => false,
        detachPointerSession: detachedTokens.add,
        releasePointerSessionToken: releasedTokens.add,
        handlePointerFromSession:
            (CanvasPointerInput input, {required PointerSessionToken token}) {},
        handleDoubleTapFromSession:
            ({
              required Offset position,
              int? timestampMs,
              required PointerSessionToken token,
            }) {},
      );

      session.dispose();

      expect(detachedTokens, hasLength(1));
      expect(releasedTokens, hasLength(1));
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
          detachPointerSession: (_) {},
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

final class _TrackingListenable implements Listenable {
  final List<VoidCallback> _listeners = <VoidCallback>[];

  int get activeListenerCount => _listeners.length;

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void notifyListeners() {
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }
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

class _ThrowingSessionTransportInteraction
    extends SceneControllerInteractionOwner {
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
