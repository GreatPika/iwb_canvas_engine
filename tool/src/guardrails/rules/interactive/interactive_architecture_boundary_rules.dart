part of 'mutation_boundary_rules.dart';

const List<_InteractiveOwnerSpec> _interactiveOwnerSpecs =
    <_InteractiveOwnerSpec>[
      _InteractiveOwnerSpec(
        relativePath: 'internal/interactive_runtime.dart',
        ownerName: 'InteractiveRuntime',
      ),
      _InteractiveOwnerSpec(
        relativePath: 'internal/interactive_event_dispatcher.dart',
        ownerName: 'InteractiveEventDispatcher',
      ),
      _InteractiveOwnerSpec(
        relativePath: 'internal/interactive_draw_coordinator.dart',
        ownerName: 'InteractiveDrawCoordinator',
      ),
      _InteractiveOwnerSpec(
        relativePath: 'internal/interactive_draw_eraser_engine.dart',
        ownerName: 'InteractiveDrawEraserEngine',
      ),
      _InteractiveOwnerSpec(
        relativePath: 'internal/interactive_draw_eraser_exact_hit.dart',
        ownerName: 'InteractiveDrawEraserExactHit',
      ),
      _InteractiveOwnerSpec(
        relativePath: 'internal/interactive_draw_eraser_line_hit.dart',
        ownerName: 'InteractiveDrawEraserLineHit',
      ),
      _InteractiveOwnerSpec(
        relativePath: 'internal/interactive_draw_eraser_projection.dart',
        ownerName: 'InteractiveDrawProjectedEraser',
      ),
      _InteractiveOwnerSpec(
        relativePath: 'internal/interactive_draw_eraser_stroke_hit.dart',
        ownerName: 'InteractiveDrawEraserStrokeHit',
      ),
      _InteractiveOwnerSpec(
        relativePath: 'internal/interactive_draw_style.dart',
        ownerName: 'InteractiveDrawStyle',
      ),
      _InteractiveOwnerSpec(
        relativePath: 'internal/scene_controller_interaction_config.dart',
        ownerName: 'SceneControllerInteractionConfig',
      ),
      _InteractiveOwnerSpec(
        relativePath: 'scene_controller_interaction.dart',
        ownerName: 'SceneControllerInteraction',
        alternativeOwnerNames: <String>{'SceneControllerInteractionOwner'},
      ),
      _InteractiveOwnerSpec(
        relativePath: 'internal/scene_controller_interaction_runtime.dart',
        ownerName: 'SceneControllerInteractionRuntime',
      ),
      _InteractiveOwnerSpec(
        relativePath: 'internal/scene_controller_interaction_access.dart',
        ownerName: 'SceneControllerInteractionContext',
      ),
      _InteractiveOwnerSpec(
        relativePath: 'internal/scene_controller_scene_mutations.dart',
        ownerName: 'SceneControllerSceneMutations',
      ),
      _InteractiveOwnerSpec(
        relativePath: 'internal/scene_controller_selection_mutations.dart',
        ownerName: 'SceneControllerSelectionMutations',
      ),
      _InteractiveOwnerSpec(
        relativePath: 'internal/scene_controller_mutation_boundary.dart',
        ownerName: 'SceneControllerMutationBoundary',
      ),
      _InteractiveOwnerSpec(
        relativePath: 'internal/scene_controller_pointer_session.dart',
        ownerName: 'SceneControllerPointerSession',
      ),
      _InteractiveOwnerSpec(
        relativePath: 'internal/pointer_session_token.dart',
        ownerName: 'PointerSessionToken',
      ),
      _InteractiveOwnerSpec(
        relativePath: 'internal/interactive_selection_actions.dart',
        ownerName: 'InteractiveSelectionActions',
      ),
      _InteractiveOwnerSpec(
        relativePath: 'internal/scene_controller_graph.dart',
        ownerName: 'createSceneControllerGraph',
      ),
      _InteractiveOwnerSpec(
        relativePath: 'internal/scene_controller_scene_view_runtime.dart',
        ownerName: 'SceneControllerSceneViewRuntime',
      ),
      _InteractiveOwnerSpec(
        relativePath: 'internal/scene_controller_internal_access.dart',
        ownerName: 'SceneControllerInternalAccessRegistration',
        alternativeOwnerNames: <String>{
          'registerSceneControllerInternalAccess',
        },
      ),
      _InteractiveOwnerSpec(
        relativePath: '../contract/scene_view_runtime.dart',
        ownerName: 'SceneViewRuntime',
      ),
      _InteractiveOwnerSpec(
        relativePath: '../view/scene_view_interactive.dart',
        ownerName: 'SceneViewInteractive',
      ),
      _InteractiveOwnerSpec(
        relativePath: '../view/scene_view_runtime_host.dart',
        ownerName: 'SceneViewRuntimeHost',
      ),
      _InteractiveOwnerSpec(
        relativePath: '../view/scene_view_render_surface.dart',
        ownerName: 'SceneViewRenderSurface',
      ),
      _InteractiveOwnerSpec(
        relativePath: '../view/scene_view_interactive_pointer_host.dart',
        ownerName: 'SceneViewInteractivePointerHost',
      ),
    ];

const List<String> _deletedInteractiveResidualFiles = <String>[
  '/lib/src/interactive/internal/scene_controller_scene_access.dart',
  '/lib/src/interactive/internal/scene_controller_selection_access.dart',
  '/lib/src/interactive/internal/scene_controller_facade_assembly.dart',
  '/lib/src/interactive/internal/scene_controller_pointer_semantics.dart',
  '/lib/src/interactive/scene_view_pointer_semantics.dart',
];

Future<GuardrailViolation?> _checkInteractiveArchitectureBoundary(
  GuardrailContext context,
) async {
  return _checkInteractiveOwnerPresence(context) ??
      _checkDeletedInteractiveResidualSeams(context) ??
      await _checkInteractiveFacadeBoundary(context) ??
      _checkSceneViewRuntimeContract(context) ??
      await _checkInteractiveGraphAssembly(context) ??
      await _checkInteractiveViewRuntimeBoundary(context) ??
      await _checkPointerSessionBoundary(context) ??
      _checkPointerSessionTokenBoundary(context) ??
      await _checkInteractiveRuntimeBoundary(context) ??
      await _checkMutationBoundaryOwner(context) ??
      await _checkInteractiveInteractionRuntimeBoundary(context) ??
      _checkEligibilityPolicyBoundary(context) ??
      await _checkSceneMutationShellBoundary(context) ??
      await _checkSelectionMutationShellBoundary(context) ??
      await _checkSelectionActionsBoundary(context) ??
      _checkInternalAccessBoundary(context) ??
      await _checkPointerHostBoundary(context) ??
      await _checkRuntimeHostBoundary(context) ??
      await _checkSceneViewInteractiveBoundary(context) ??
      await _checkRenderSurfaceBoundary(context) ??
      _checkEventDispatcherBoundary(context) ??
      _checkDrawCoordinatorBoundary(context) ??
      _checkDrawEraserEngineBoundary(context) ??
      _checkDrawExactHitBoundary(context) ??
      _checkDrawLineHitBoundary(context) ??
      _checkDrawStrokeHitBoundary(context) ??
      _checkDrawProjectionBoundary(context) ??
      _checkDrawStyleBoundary(context);
}
