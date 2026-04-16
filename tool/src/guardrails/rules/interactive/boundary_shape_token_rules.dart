part of 'mutation_boundary_rules.dart';

GuardrailViolation? _checkInteractiveBoundaryShape(GuardrailContext context) {
  final facadeFile = _interactiveFile(context);
  final facadeFilePosixPath = _interactiveFilePosixPath(context, facadeFile);
  final parsed = _parseInteractiveFile(
    context,
    facadeFile,
    facadeFilePosixPath,
  );
  final runtimeFile = _interactiveSupportFile(
    context,
    'internal/interactive_runtime.dart',
  );
  final eventFile = _interactiveSupportFile(
    context,
    'internal/interactive_event_dispatcher.dart',
  );
  final drawCoordinatorFile = _interactiveSupportFile(
    context,
    'internal/interactive_draw_coordinator.dart',
  );
  final drawEraserFile = _interactiveSupportFile(
    context,
    'internal/interactive_draw_eraser_engine.dart',
  );
  final drawEraserExactHitFile = _interactiveSupportFile(
    context,
    'internal/interactive_draw_eraser_exact_hit.dart',
  );
  final drawEraserLineHitFile = _interactiveSupportFile(
    context,
    'internal/interactive_draw_eraser_line_hit.dart',
  );
  final drawEraserProjectionFile = _interactiveSupportFile(
    context,
    'internal/interactive_draw_eraser_projection.dart',
  );
  final drawEraserStrokeHitFile = _interactiveSupportFile(
    context,
    'internal/interactive_draw_eraser_stroke_hit.dart',
  );
  final drawStyleFile = _interactiveSupportFile(
    context,
    'internal/interactive_draw_style.dart',
  );
  final interactionConfigFile = _interactiveSupportFile(
    context,
    'internal/scene_controller_interaction_config.dart',
  );
  final interactionFile = _interactiveSupportFile(
    context,
    'scene_controller_interaction.dart',
  );
  final interactionRuntimeFile = _interactiveSupportFile(
    context,
    'internal/scene_controller_interaction_runtime.dart',
  );
  final interactionAccessFile = _interactiveSupportFile(
    context,
    'internal/scene_controller_interaction_access.dart',
  );
  final sceneMutationsFile = _interactiveSupportFile(
    context,
    'internal/scene_controller_scene_mutations.dart',
  );
  final selectionMutationsFile = _interactiveSupportFile(
    context,
    'internal/scene_controller_selection_mutations.dart',
  );
  final mutationBoundaryFile = _interactiveSupportFile(
    context,
    'internal/scene_controller_mutation_boundary.dart',
  );
  final pointerSessionFile = _interactiveSupportFile(
    context,
    'internal/scene_controller_pointer_session.dart',
  );
  final selectionActionsFile = _interactiveSupportFile(
    context,
    'internal/interactive_selection_actions.dart',
  );
  final ownerGraphFile = _interactiveSupportFile(
    context,
    'internal/scene_controller_graph.dart',
  );
  final viewRuntimeFile = _interactiveSupportFile(
    context,
    'internal/scene_controller_scene_view_runtime.dart',
  );
  final internalAccessFile = _interactiveSupportFile(
    context,
    'internal/scene_controller_internal_access.dart',
  );
  final runtimeContractFile = File(
    '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
    'src${Platform.pathSeparator}contract${Platform.pathSeparator}'
    'scene_view_runtime.dart',
  );
  final sceneViewInteractiveFile = File(
    '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
    'src${Platform.pathSeparator}view${Platform.pathSeparator}'
    'scene_view_interactive.dart',
  );
  final sceneViewRuntimeFile = File(
    '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
    'src${Platform.pathSeparator}view${Platform.pathSeparator}'
    'scene_view_runtime_host.dart',
  );
  final renderSurfaceFile = File(
    '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
    'src${Platform.pathSeparator}view${Platform.pathSeparator}'
    'scene_view_render_surface.dart',
  );
  final pointerHostFile = File(
    '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
    'src${Platform.pathSeparator}view${Platform.pathSeparator}'
    'scene_view_interactive_pointer_host.dart',
  );
  final pointerSessionTokenFile = _interactiveSupportFile(
    context,
    'internal/pointer_session_token.dart',
  );

  final missingOwnerViolation =
      _missingInteractiveOwnerViolation(context, <File, String>{
        runtimeFile: 'InteractiveRuntime',
        eventFile: 'InteractiveEventDispatcher',
        drawCoordinatorFile: 'InteractiveDrawCoordinator',
        drawEraserFile: 'InteractiveDrawEraserEngine',
        drawEraserExactHitFile: 'InteractiveDrawEraserExactHit',
        drawEraserLineHitFile: 'InteractiveDrawEraserLineHit',
        drawEraserProjectionFile: 'InteractiveDrawProjectedEraser',
        drawEraserStrokeHitFile: 'InteractiveDrawEraserStrokeHit',
        drawStyleFile: 'InteractiveDrawStyle',
        interactionConfigFile: 'SceneControllerInteractionConfig',
        interactionFile: 'SceneControllerInteraction',
        interactionRuntimeFile: 'SceneControllerInteractionRuntime',
        interactionAccessFile: 'SceneControllerInteractionContext',
        sceneMutationsFile: 'SceneControllerSceneMutations',
        selectionMutationsFile: 'SceneControllerSelectionMutations',
        mutationBoundaryFile: 'SceneControllerMutationBoundary',
        pointerSessionFile: 'SceneControllerPointerSession',
        pointerSessionTokenFile: 'PointerSessionToken',
        selectionActionsFile: 'InteractiveSelectionActions',
        ownerGraphFile: 'createSceneControllerGraph',
        viewRuntimeFile: 'SceneControllerSceneViewRuntime',
        internalAccessFile: 'SceneControllerInternalAccess',
        runtimeContractFile: 'SceneViewRuntime',
        sceneViewInteractiveFile: 'SceneViewInteractive',
        sceneViewRuntimeFile: 'SceneViewRuntimeHost',
        renderSurfaceFile: 'SceneViewRenderSurface',
        pointerHostFile: 'SceneViewInteractivePointerHost',
      });
  if (missingOwnerViolation != null) {
    return missingOwnerViolation;
  }
  for (final deletedPath in <String>[
    'internal/scene_controller_scene_access.dart',
    'internal/scene_controller_selection_access.dart',
    'internal/scene_controller_facade_assembly.dart',
    'internal/scene_controller_pointer_semantics.dart',
    'scene_view_pointer_semantics.dart',
  ]) {
    if (_interactiveSupportFile(context, deletedPath).existsSync()) {
      final detail = switch (deletedPath) {
        'internal/scene_controller_scene_access.dart' =>
          'SceneControllerSceneAccessAdapter is a deleted residual seam and '
              'must not exist.',
        'internal/scene_controller_selection_access.dart' =>
          'SceneControllerSelectionAccessAdapter is a deleted residual seam '
              'and must not exist.',
        'internal/scene_controller_facade_assembly.dart' =>
          'assembleSceneControllerFacade is a deleted residual seam and must '
              'not exist.',
        'internal/scene_controller_pointer_semantics.dart' =>
          'SceneControllerPointerSemantics is a deleted residual seam and '
              'must not exist.',
        'scene_view_pointer_semantics.dart' =>
          'SceneView pointer-semantics seam is deleted and must not exist.',
        _ => 'deleted residual seam must not exist ($deletedPath).',
      };
      return GuardrailViolation(
        filePath: 'lib/src/interactive/$deletedPath',
        line: 1,
        message: 'interactive API violation: $detail',
      );
    }
  }

  final facadeSource = facadeFile.readAsStringSync();
  final interactionSource = interactionFile.readAsStringSync();
  final runtimeSource = runtimeFile.readAsStringSync();
  final pointerSessionTokenSource = pointerSessionTokenFile.readAsStringSync();
  final eventSource = eventFile.readAsStringSync();
  final drawCoordinatorSource = drawCoordinatorFile.readAsStringSync();
  final drawEraserSource = drawEraserFile.readAsStringSync();
  final drawEraserExactHitSource = drawEraserExactHitFile.readAsStringSync();
  final drawEraserLineHitSource = drawEraserLineHitFile.readAsStringSync();
  final drawEraserProjectionSource = drawEraserProjectionFile
      .readAsStringSync();
  final drawEraserStrokeHitSource = drawEraserStrokeHitFile.readAsStringSync();
  final drawStyleSource = drawStyleFile.readAsStringSync();
  final internalAccessSource = internalAccessFile.readAsStringSync();
  final interactionRuntimeSource = interactionRuntimeFile.readAsStringSync();
  final sceneMutationsSource = sceneMutationsFile.readAsStringSync();
  final selectionMutationsSource = selectionMutationsFile.readAsStringSync();
  final mutationBoundarySource = mutationBoundaryFile.readAsStringSync();
  final pointerSessionSource = pointerSessionFile.readAsStringSync();
  final selectionActionsSource = selectionActionsFile.readAsStringSync();
  final graphSource = ownerGraphFile.readAsStringSync();
  final viewRuntimeSource = viewRuntimeFile.readAsStringSync();
  final runtimeContractSource = runtimeContractFile.readAsStringSync();
  final pointerHostSource = pointerHostFile.readAsStringSync();
  final sceneViewInteractiveSource = sceneViewInteractiveFile
      .readAsStringSync();
  final sceneViewRuntimeSource = sceneViewRuntimeFile.readAsStringSync();
  final renderSurfaceSource = renderSurfaceFile.readAsStringSync();
  final eligibilityPolicyFile = _interactiveSupportFile(
    context,
    'interaction_eligibility_policy.dart',
  );
  final eligibilityPolicySource = eligibilityPolicyFile.readAsStringSync();

  return _topLevelFacadeHelperViolation(context, parsed: parsed) ??
      requireSourceTokens(
        source: interactionSource,
        filePath: _interactiveFilePosixPath(context, interactionFile),
        requiredTokens: const <String>[],
        bannedTokens: const <String>[
          'SceneSnapshot get snapshot',
          'get snapshot => _access.snapshot',
        ],
        message:
            'interactive API violation: SceneControllerInteraction must not '
            'expose committed render-state through snapshot.',
      ) ??
      requireSourceTokens(
        source: facadeSource,
        filePath: facadeFilePosixPath,
        requiredTokens: const <String>[
          "import 'internal/scene_controller_graph.dart';",
          "import '../contract/scene_view_runtime.dart';",
          'createSceneControllerGraph(',
          'SceneControllerGraphRequest(',
          'SceneViewRuntime sceneControllerViewRuntimeOf(',
        ],
        bannedTokens: const <String>[
          'implements SceneViewRenderState',
          'createPointerSemanticsBridge(',
          "import 'internal/scene_controller_internal_access.dart';",
          "import 'internal/scene_controller_pointer_session.dart';",
          "import 'internal/interactive_draw_coordinator.dart';",
          "import 'internal/interactive_runtime.dart';",
          "import 'internal/interactive_event_dispatcher.dart';",
          '_runtime.handlePointer(',
          '_runtime.handleDoubleTap(',
          'StreamController<',
          '_timestampCursorMs',
        ],
        message:
            'interactive API violation: SceneController must remain '
            'a thin facade over the assembled controller graph.',
      ) ??
      requireSourceTokens(
        source: runtimeContractSource,
        filePath: toRepoRelPosixPath(
          absPosixPath: toPosixPath(runtimeContractFile.absolute.path),
          rootAbsPosixPath: context.rootAbsPosixPath,
        ),
        requiredTokens: const <String>[
          'abstract interface class SceneViewRuntime',
          'SceneViewPointerSession createPointerSession({',
          'abstract interface class SceneViewPointerSession',
          'void detach();',
        ],
        bannedTokens: const <String>[
          'handleControllerChanged(',
          'updateController(',
        ],
        message:
            'interactive API violation: SceneViewRuntime must remain the '
            'single internal runtime/session contract for view core.',
      ) ??
      requireSourceTokens(
        source: graphSource,
        filePath: _interactiveFilePosixPath(context, ownerGraphFile),
        requiredTokens: const <String>[
          'SceneControllerInteractionOwner(',
          'SceneControllerSelectionOwner(',
          'SceneControllerSceneOwner(',
          'SceneControllerSceneViewRuntime(',
          'SceneControllerInternalAccessRegistration(',
          'registerSceneControllerInternalAccess(',
        ],
        bannedTokens: const <String>[
          'createPointerSemanticsBridge(',
          'SceneControllerPointerSemantics',
        ],
        message:
            'interactive API violation: SceneController graph must '
            'assemble view runtime and internal access outside the facade.',
      ) ??
      requireSourceTokens(
        source: viewRuntimeSource,
        filePath: _interactiveFilePosixPath(context, viewRuntimeFile),
        requiredTokens: const <String>[
          'final class SceneControllerSceneViewRuntime',
          'final class SceneControllerSceneViewRenderState',
          'SceneControllerPointerSession(',
          'SceneControllerInteraction get _interaction',
          'createPointerSessionToken()',
          'detachPointerSession:',
          '_interactionRuntime.detachPointerSession',
          'releasePointerSessionToken:',
          '_interactionRuntime.releasePointerSessionToken',
          'handlePointerFromSession: _interactionRuntime.handlePointerFromSession',
        ],
        bannedTokens: const <String>[
          'SceneControllerPointerSemantics',
          'createPointerSemanticsBridge(',
          '_DisposedSceneViewPointerSession',
        ],
        message:
            'interactive API violation: SceneControllerSceneViewRuntime must '
            'own the render-state adapter and pointer-session factory.',
      ) ??
      requireSourceTokens(
        source: pointerSessionTokenSource,
        filePath: _interactiveFilePosixPath(context, pointerSessionTokenFile),
        requiredTokens: const <String>['final class PointerSessionToken'],
        bannedTokens: const <String>[
          'operator ==',
          'hashCode',
          ' id;',
          'toJson(',
        ],
        message:
            'interactive API violation: PointerSessionToken must remain an '
            'opaque internal nominal token.',
      ) ??
      requireSourceTokens(
        source: runtimeSource,
        filePath: _interactiveFilePosixPath(context, runtimeFile),
        requiredTokens: const <String>[
          "import 'interactive_draw_coordinator.dart';",
          "import 'interactive_event_dispatcher.dart';",
          "import 'interactive_move_session.dart';",
          "import 'interactive_pointer_normalizer.dart';",
          "import 'interactive_gesture_router.dart';",
          "import 'interactive_double_tap_router.dart';",
          'void handlePublicPointer(CanvasPointerInput input)',
          'void handlePublicDoubleTap({required Offset position, int? timestampMs})',
          'handlePointerFromSession(',
          'handleDoubleTapFromSession({',
        ],
        bannedTokens: const <String>[
          'StreamController<',
          '_timestampCursorMs',
          '_actionCounter',
          '_actions =',
          '_editTextRequests =',
          '_eraserHitsLine(',
          'void handlePointer(CanvasPointerInput input)',
          'void handleDoubleTap({required Offset position, int? timestampMs})',
        ],
        message:
            'interactive API violation: InteractiveRuntime must keep event '
            'timeline and draw-local geometry outside the boundary runtime.',
      ) ??
      requireSourceTokens(
        source: interactionRuntimeSource,
        filePath: _interactiveFilePosixPath(context, interactionRuntimeFile),
        requiredTokens: const <String>[
          "import 'pointer_session_token.dart';",
          "import '../../controller/scene_controller_committed_mutation_access.dart';",
          "import 'scene_controller_mutation_boundary.dart';",
          'required this.mutationAccess,',
          'final SceneControllerCommittedMutationAccess mutationAccess;',
          'PointerSessionToken createPointerSessionToken()',
          'void detachPointerSession(PointerSessionToken token)',
          'void releasePointerSessionToken(PointerSessionToken token)',
          'void handlePublicPointer(CanvasPointerInput input)',
          'void handlePublicDoubleTap({required Offset position, int? timestampMs})',
          'handlePointerFromSession(',
          'handleDoubleTapFromSession({',
          '_ensureKnownPointerSessionToken(token);',
          'mutationAccess: request.mutationAccess,',
          'writeSelectionReplace: mutationBoundary.setSelection,',
          'writeSelectionClear: mutationBoundary.clearSelection,',
          'commitMoveSelection: mutationBoundary.commitMoveSelection,',
          'commitDrawStroke: mutationBoundary.commitDrawStroke,',
          'mutationBoundary.commitDrawLineFromWorldSegment',
          'commitEraseNodes: mutationBoundary.commitEraseNodes,',
        ],
        bannedTokens: const <String>[
          'request.storeController.commands.writeSelectionReplace',
          'request.storeController.commands.writeSelectionClear',
          'request.storeController.draw.writeDrawStroke',
          'request.storeController.draw.writeDrawLineFromWorldSegment',
          'request.storeController.draw.writeEraseNodes',
          'void handlePointer(CanvasPointerInput input)',
          'void handleDoubleTap({required Offset position, int? timestampMs})',
        ],
        message:
            'interactive API violation: SceneControllerInteractionRuntime '
            'must route committed selection/draw callbacks through '
            'SceneControllerMutationBoundary.',
      ) ??
      requireSourceTokens(
        source: eligibilityPolicySource,
        filePath: _interactiveFilePosixPath(context, eligibilityPolicyFile),
        requiredTokens: const <String>['_snapshotBoundsWorld('],
        bannedTokens: const <String>[
          "../model/document.dart",
          'txnNodeFromSnapshot(',
        ],
        message:
            'interactive API violation: interaction_eligibility_policy must '
            'stay model-free and avoid document.dart materialization helpers.',
      ) ??
      requireSourceTokens(
        source: sceneMutationsSource,
        filePath: _interactiveFilePosixPath(context, sceneMutationsFile),
        requiredTokens: const <String>['mutations.'],
        bannedTokens: const <String>[
          'storeController.commands.',
          'storeController.writeReplaceScene(',
        ],
        bannedPatterns: <RegExp>[
          RegExp(r'storeController\.write\s*(<[^>]+>)?\s*\('),
        ],
        message:
            'interactive API violation: SceneControllerSceneMutations must '
            'delegate committed scene writes through '
            'SceneControllerMutationBoundary.',
      ) ??
      requireSourceTokens(
        source: selectionMutationsSource,
        filePath: _interactiveFilePosixPath(context, selectionMutationsFile),
        requiredTokens: const <String>['mutations.'],
        bannedTokens: const <String>['storeController.commands.'],
        bannedPatterns: <RegExp>[
          RegExp(r'storeController\.write\s*(<[^>]+>)?\s*\('),
        ],
        message:
            'interactive API violation: SceneControllerSelectionMutations '
            'must delegate committed selection writes through '
            'SceneControllerMutationBoundary.',
      ) ??
      requireSourceTokens(
        source: selectionActionsSource,
        filePath: _interactiveFilePosixPath(context, selectionActionsFile),
        requiredTokens: const <String>['mutations.'],
        bannedTokens: const <String>['core.commands.'],
        bannedPatterns: <RegExp>[RegExp(r'core\.write\s*(<[^>]+>)?\s*\(')],
        message:
            'interactive API violation: InteractiveSelectionActions must '
            'remain a thin routing shell over SceneControllerMutationBoundary.',
      ) ??
      requireSourceTokens(
        source: mutationBoundarySource,
        filePath: _interactiveFilePosixPath(context, mutationBoundaryFile),
        requiredTokens: const <String>[
          'class SceneControllerMutationBoundary',
          "import '../../controller/scene_controller_committed_mutation_access.dart';",
          'final SceneControllerCommittedMutationAccess mutationAccess;',
          'mutationAccess.clearSceneExactResult();',
          'if (!mutationAccess.replaceSelection(nodeIds)) {',
          'if (!mutationAccess.clearSelection()) {',
          'mutationAccess.deleteSelection();',
          'mutationAccess.transformSelection(delta);',
          'mutationAccess.replaceScene(',
          'mutationAccess.commitDrawStroke(',
          'mutationAccess.commitDrawLineFromWorldSegment(',
          'mutationAccess.commitEraseNodes(ids);',
          'mutationAccess.replaceScene(snapshot, beforeApply: interruptBeforeApply);',
        ],
        bannedTokens: const <String>[
          "import '../../controller/scene_store_controller.dart';",
          'SceneStoreController storeController;',
          'storeController.commands.',
          'storeController.draw.',
          'storeController.prepareSceneReplacement(',
          'storeController.writePreparedSceneReplacement(',
          'storeController.requestRepaint();',
          'storeController.writeReplaceScene(snapshot);',
          'mutationAccess.prepareSceneReplacement(',
          'mutationAccess.writePreparedSceneReplacement(',
          'txnSceneFromSnapshot(',
        ],
        message:
            'interactive API violation: SceneControllerMutationBoundary must '
            'remain the canonical scene/selection write owner.',
      ) ??
      requireSourceTokens(
        source: pointerSessionSource,
        filePath: _interactiveFilePosixPath(context, pointerSessionFile),
        requiredTokens: const <String>[
          'class SceneControllerPointerSession',
          'PointerInputTracker(',
          '_PendingTapFlushScheduler',
          '_ownerListenable.addListener(',
          'PointerSessionToken token,',
          'detachPointerSession',
          'releasePointerSessionToken',
          'PointerSessionToken token',
          'void detach()',
          '_detachPointerSession(_token);',
          '_releaseOwnedResources();',
          '_handlePointerFromSession(',
          '_handleDoubleTapFromSession(',
          'void _releaseOwnedResources()',
          '_ownerListenable.removeListener(_ownerListener);',
          '_releasePointerSessionToken(',
        ],
        bannedTokens: const <String>[
          'handleControllerChanged(',
          'SceneControllerInteraction',
          '_readInteraction',
          'Object? owner',
          'Object? session',
          'Object? context',
          'runtimeType',
        ],
        message:
            'interactive API violation: pointer session must stay owned by '
            'SceneControllerPointerSession.',
      ) ??
      requireSourceTokens(
        source: pointerHostSource,
        filePath: toRepoRelPosixPath(
          absPosixPath: toPosixPath(pointerHostFile.absolute.path),
          rootAbsPosixPath: context.rootAbsPosixPath,
        ),
        requiredTokens: const <String>[
          'SceneViewPointerSession',
          'replacePointerSession(',
          'current.detach();',
          'current.dispose();',
          '_pointerRouter.reset();',
          '_pointerSession = next;',
          '_pointerSession.detach();',
          '_pointerSession.dispose();',
        ],
        bannedTokens: const <String>[
          'SceneController',
          'createPointerSemanticsBridge(',
          'PointerInputTracker(',
          '_PendingTapFlushScheduler',
          '_pendingPointerSettings',
          '_SceneViewPointerSessionFactory',
        ],
        message:
            'interactive API violation: SceneViewInteractivePointerHost must '
            'remain a raw routing/lifecycle shell over pointer sessions.',
      ) ??
      requireTokenOrder(
        source: pointerHostSource,
        filePath: toRepoRelPosixPath(
          absPosixPath: toPosixPath(pointerHostFile.absolute.path),
          rootAbsPosixPath: context.rootAbsPosixPath,
        ),
        scopeRootStart: 'class _SceneViewInteractivePointerRuntime',
        methodStart: 'void replacePointerSession(SceneViewPointerSession next)',
        orderedTokens: const <String>[
          'current.detach();',
          'current.dispose();',
          '_pointerRouter.reset();',
          '_pointerSession = next;',
        ],
        message:
            'interactive API violation: SceneViewInteractivePointerHost must '
            'detach old sessions before dispose and router reset.',
      ) ??
      requireTokenOrder(
        source: pointerHostSource,
        filePath: toRepoRelPosixPath(
          absPosixPath: toPosixPath(pointerHostFile.absolute.path),
          rootAbsPosixPath: context.rootAbsPosixPath,
        ),
        scopeRootStart: 'class _SceneViewInteractivePointerRuntime',
        methodStart: 'void dispose()',
        orderedTokens: const <String>[
          '_pointerSession.detach();',
          '_pointerSession.dispose();',
        ],
        message:
            'interactive API violation: SceneViewInteractivePointerHost must '
            'detach current sessions before dispose.',
      ) ??
      requireSourceTokens(
        source: sceneViewInteractiveSource,
        filePath: toRepoRelPosixPath(
          absPosixPath: toPosixPath(sceneViewInteractiveFile.absolute.path),
          rootAbsPosixPath: context.rootAbsPosixPath,
        ),
        requiredTokens: const <String>[
          "import '../interactive/scene_controller.dart';",
          "import 'scene_view_runtime_host.dart';",
          'sceneControllerViewRuntimeOf(controller)',
        ],
        bannedTokens: const <String>['Listener(', 'SceneViewRenderSurface('],
        message:
            'interactive API violation: SceneViewInteractive must remain a '
            'thin public shell over SceneViewRuntimeHost.',
      ) ??
      requireSourceTokens(
        source: sceneViewRuntimeSource,
        filePath: toRepoRelPosixPath(
          absPosixPath: toPosixPath(sceneViewRuntimeFile.absolute.path),
          rootAbsPosixPath: context.rootAbsPosixPath,
        ),
        requiredTokens: const <String>[
          'class SceneViewRuntimeHost extends StatefulWidget',
          'late SceneViewRuntime _activeRuntime;',
          '_activeRuntime.createPointerSession(',
          'return runtime.createPointerSession(',
          'if (_activeRuntime == widget.runtime) {',
          'return;',
          '_createReplacementPointerSession(',
          '_pointerHost.replacePointerSession(',
          'final renderState = _activeRuntime.renderState;',
          '_activeRuntime = widget.runtime;',
          'SceneViewRenderSurface(',
        ],
        bannedTokens: const <String>[
          "import '../interactive/scene_controller.dart';",
          'createPointerSemanticsBridge(',
          'final renderState = widget.runtime.renderState;',
          'late SceneViewRuntime _requestedRuntime;',
          'FlutterError.reportError(',
          'if (nextPointerSession == null) {',
        ],
        message:
            'interactive API violation: SceneViewRuntimeHost must own '
            'runtime state beneath the public shell.',
      ) ??
      requireTokenOrder(
        source: sceneViewRuntimeSource,
        filePath: toRepoRelPosixPath(
          absPosixPath: toPosixPath(sceneViewRuntimeFile.absolute.path),
          rootAbsPosixPath: context.rootAbsPosixPath,
        ),
        scopeRootStart: 'class _SceneViewRuntimeHostState',
        methodStart: 'void didUpdateWidget(SceneViewRuntimeHost oldWidget)',
        orderedTokens: const <String>[
          'final nextPointerSession = _createReplacementPointerSession(',
          '_pointerHost.replacePointerSession(nextPointerSession);',
          '_activeRuntime = widget.runtime;',
        ],
        message:
            'interactive API violation: SceneViewRuntimeHost must create '
            'replacement sessions before install, propagate failed swaps to '
            'the owner, compare updates against the installed runtime, and '
            'switch the active runtime only after install succeeds.',
      ) ??
      requireSourceTokens(
        source: renderSurfaceSource,
        filePath: toRepoRelPosixPath(
          absPosixPath: toPosixPath(renderSurfaceFile.absolute.path),
          rootAbsPosixPath: context.rootAbsPosixPath,
        ),
        requiredTokens: const <String>[
          'required SceneViewRenderState renderState,',
        ],
        bannedTokens: const <String>[
          'SceneViewRenderSurface.store(',
          'SceneViewRenderSurface.interactive(',
          "import '../interactive/scene_controller.dart';",
          "import '../controller/scene_store_controller.dart';",
        ],
        message:
            'interactive API violation: SceneViewRenderSurface must remain a '
            'single render-state entrypoint.',
      ) ??
      requireSourceTokens(
        source: eventSource,
        filePath: _interactiveFilePosixPath(context, eventFile),
        requiredTokens: const <String>[
          "import 'dart:async';",
          'class InteractiveEventDispatcher',
          'resolveTimestampMs(',
          'emitAction(',
          'emitEditTextRequested(',
        ],
        bannedTokens: const <String>['_eraserHitsLine('],
        message:
            'interactive API violation: InteractiveEventDispatcher must remain '
            'the event/timeline owner.',
      ) ??
      requireSourceTokens(
        source: drawCoordinatorSource,
        filePath: _interactiveFilePosixPath(context, drawCoordinatorFile),
        requiredTokens: const <String>[
          "import 'interactive_draw_eraser_engine.dart';",
          "import 'interactive_draw_line_engine.dart';",
          "import 'interactive_draw_stroke_engine.dart';",
          "import 'interactive_draw_terminal_router.dart';",
        ],
        bannedTokens: const <String>[
          '_eraserHitsLine(',
          '_eraserHitsStroke(',
          '_localEraserSegmentsHitLine(',
          '_eraserSegmentHitsStrokeBatch(',
        ],
        message:
            'interactive API violation: InteractiveDrawCoordinator must remain '
            'a draw-family orchestrator and not re-own eraser geometry.',
      ) ??
      requireSourceTokens(
        source: drawEraserSource,
        filePath: _interactiveFilePosixPath(context, drawEraserFile),
        requiredTokens: const <String>[
          "import 'interactive_draw_eraser_exact_hit.dart';",
          'InteractiveDrawEraserExactHit(',
          '_exactHit.hitsNode(',
        ],
        bannedTokens: const <String>[
          '_eraserHitsNode(',
          '_eraserHitsLine(',
          '_eraserHitsStroke(',
          '_projectEraserToLocal(',
          '_fallbackWorldBoundsHit(',
          '_localEraserSegmentsHitLine(',
          '_eraserSegmentHitsStrokeBatch(',
        ],
        message:
            'interactive API violation: InteractiveDrawEraserEngine must '
            'delegate exact-hit geometry to eraser-local owners.',
      ) ??
      requireSourceTokens(
        source: drawEraserExactHitSource,
        filePath: _interactiveFilePosixPath(context, drawEraserExactHitFile),
        requiredTokens: const <String>[
          "import 'interactive_draw_eraser_line_hit.dart';",
          "import 'interactive_draw_eraser_projection.dart';",
          "import 'interactive_draw_eraser_stroke_hit.dart';",
          'class InteractiveDrawEraserExactHit',
          '_lineHit.hitsProjectedLine(',
          '_strokeHit.hitsProjectedStroke(',
          '_projectEraserToLocal(',
          '_fallbackWorldBoundsHit(',
        ],
        bannedTokens: const <String>[
          '_localEraserSegmentsHitLine(',
          '_eraserSegmentHitsStrokeBatch(',
        ],
        message:
            'interactive API violation: InteractiveDrawEraserExactHit must '
            'own shared dispatch/projection/fallback and delegate focused '
            'geometry bodies.',
      ) ??
      requireSourceTokens(
        source: drawEraserLineHitSource,
        filePath: _interactiveFilePosixPath(context, drawEraserLineHitFile),
        requiredTokens: const <String>[
          'class InteractiveDrawEraserLineHit',
          'hitsProjectedLine(',
          '_localEraserSegmentsHitLine(',
          'onPreciseSegmentCheck()',
        ],
        bannedTokens: const <String>['_eraserSegmentHitsStrokeBatch('],
        message:
            'interactive API violation: InteractiveDrawEraserLineHit must '
            'remain the focused line exact-hit owner.',
      ) ??
      requireSourceTokens(
        source: drawEraserStrokeHitSource,
        filePath: _interactiveFilePosixPath(context, drawEraserStrokeHitFile),
        requiredTokens: const <String>[
          'class InteractiveDrawEraserStrokeHit',
          'hitsProjectedStroke(',
          '_eraserSegmentHitsStrokeBatch(',
          'onPreciseSegmentCheck()',
        ],
        bannedTokens: const <String>['_localEraserSegmentsHitLine('],
        message:
            'interactive API violation: InteractiveDrawEraserStrokeHit must '
            'remain the focused stroke exact-hit owner.',
      ) ??
      requireSourceTokens(
        source: drawEraserProjectionSource,
        filePath: _interactiveFilePosixPath(context, drawEraserProjectionFile),
        requiredTokens: const <String>[
          'typedef InteractiveDrawProjectedEraser = ({',
          'List<Offset> points,',
          'double threshold,',
          'double thresholdSquared,',
        ],
        bannedTokens: const <String>[],
        message:
            'interactive API violation: InteractiveDrawProjectedEraser must '
            'remain the shared eraser exact-hit projection contract.',
      ) ??
      requireSourceTokens(
        source: drawStyleSource,
        filePath: _interactiveFilePosixPath(context, drawStyleFile),
        requiredTokens: const <String>[
          'typedef InteractiveDrawStyle = ({',
          'DrawTool drawTool,',
          'Color drawColor,',
          'double lineThickness,',
        ],
        bannedTokens: const <String>[],
        message:
            'interactive API violation: InteractiveDrawStyle must remain a '
            'shared interactive-local contract owner.',
      ) ??
      requireSourceTokens(
        source: internalAccessSource,
        filePath: _interactiveFilePosixPath(context, internalAccessFile),
        requiredTokens: const <String>[
          'registerSceneControllerInternalAccess(',
          'sceneControllerInternalEpoch(',
          'sceneControllerInternalPreviewDeltaForNode(',
          'sceneControllerInternalSetBeforePointerDispatchHook(',
        ],
        bannedTokens: const <String>[
          'SceneViewRuntime',
          'SceneViewPointerSession',
        ],
        message:
            'interactive API violation: internal interactive test/debug access '
            'must remain outside SceneController.',
      );
}

GuardrailViolation? _topLevelFacadeHelperViolation(
  GuardrailContext context, {
  required ParsedUnitResult parsed,
}) {
  for (final declaration in parsed.unit.declarations) {
    if (declaration is FunctionDeclaration) {
      final name = declaration.name.lexeme;
      if (name == 'sceneControllerViewRuntimeOf') {
        continue;
      }
      return GuardrailViolation(
        filePath: _interactiveFilePosixPath(context, _interactiveFile(context)),
        line: lineForOffset(parsed, declaration.offset),
        message:
            'interactive API violation: SceneController facade '
            'file must not own top-level helper functions.',
      );
    }
  }
  return null;
}

GuardrailViolation? _missingInteractiveOwnerViolation(
  GuardrailContext context,
  Map<File, String> requiredOwners,
) {
  for (final entry in requiredOwners.entries) {
    final file = entry.key;
    if (file.existsSync()) {
      continue;
    }
    return GuardrailViolation(
      filePath: _interactiveFilePosixPath(context, _interactiveFile(context)),
      line: 1,
      message:
          'interactive API violation: missing required split owner '
          '${entry.value} at '
          '${_interactiveFilePosixPath(context, file)}.',
    );
  }
  return null;
}

File _interactiveSupportFile(GuardrailContext context, String relativePath) {
  return File(
    '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
    'src${Platform.pathSeparator}interactive${Platform.pathSeparator}'
    '${relativePath.replaceAll('/', Platform.pathSeparator)}',
  );
}
