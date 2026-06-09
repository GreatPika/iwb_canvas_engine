import 'interaction_guardrail_checks.dart';

const eventsActionAfterStateOrderGuardrailId =
    'events.action_after_state_order';
const selectedMoveMainOnlyPreviewGuardrailId =
    'preview.selected_move_main_only';
const marqueeOverlayOnlyPreviewGuardrailId = 'preview.marquee_overlay_only';
const toolPublicPortBehaviorGuardrailId = 'tools.public_port_behavior';

const selectionMoveGuardrailIds = {
  'load.prepares_before_interrupt',
  'load.success_interrupts_before_install',
  interactionNoConcreteStoreImportsGuardrailId,
  interactionNoConcreteSelectionImportsGuardrailId,
  interactionReadPortImmutableFactsGuardrailId,
  interactionNoCommandFactsImportGuardrailId,
  interactionCleanupCoordinatorDependencyBansGuardrailId,
  'interaction.pointer_cleanup_coordinator_only',
  interactionNoResolverOnCancelPathsGuardrailId,
  interactionNoStaleTerminalCommitGuardrailId,
  interactionTextEditStaleCommitGuardrailId,
  eventsActionAfterStateOrderGuardrailId,
  'preview.selected_move_main_repaint',
  selectedMoveMainOnlyPreviewGuardrailId,
  marqueeOverlayOnlyPreviewGuardrailId,
  toolPublicPortBehaviorGuardrailId,
};
