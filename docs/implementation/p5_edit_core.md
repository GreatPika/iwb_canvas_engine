# P5 - edit core and rollback-safe commits

## Purpose

Implement synchronous edit sessions and atomic commit/rollback semantics before
load, resources, interaction, or commands can mutate committed state.

## Build scope

- `EditKernel`
- `EditSession`
- `DraftDocument`
- `TouchedSet`
- `CommitCompiler`
- `CommitPlan`
- `CommitApplier`
- sync/non-nested edit enforcement
- Future-return rejection
- stale edit handle enforcement
- rollback with no committed state, selection-owner, revision, event, repaint,
  resource, spatial, preview, or projection side effects
- low-level `CanvasEdit.removeElement` and `CanvasEdit.clearContent` emit no
  user action events
- exact touched invalidation for ordinary edits
- typed effects emitted without depending on concrete `FrameEngine`
- operation matrix executable effect assertions for edit-owned operations.

## Dependencies on earlier phases

- P4 runtime spine owns committed store, selection owner, projection, revisions,
  and narrow read boundaries.

## Read first

- `section_10_runtime_data_model` -> `docs/architecture/03_data_model.md`
- `section_11_edit_kernel` -> `docs/contracts/edit_kernel.md`
- `section_13_operation_matrix` -> `docs/contracts/operation_matrix.md`
- `section_23_tests` -> `docs/verification/tests.md`

## Required donors

- `dto_document_helpers` - decision: `adapt`; target owner: DocumentStoreKernel, SelectionKernel, and EditKernel helpers
- `interaction_mutation_boundary` - decision: `adapt`; target owner: Interaction-owned mutation bridge into EditKernel

## Forbidden donor structure

- `avoid_scene_controller_facades` - decision: `avoid`
- `avoid_interactive_runtime_whole` - decision: `avoid`
- `avoid_scene_builder_public_architecture` - decision: `avoid`
- `avoid_scene_codec_whole` - decision: `avoid`
- `avoid_scene_store_controller_whole` - decision: `avoid`

## Diagrams to read or update

- `c4_code_edit_kernel` -> `docs/diagrams/c4_code_edit_kernel.mmd`
- `c4_component_runtime` -> `docs/diagrams/c4_component_runtime.mmd`
- `dfd_cache_invalidation` -> `docs/diagrams/dfd_cache_invalidation.mmd`
- `dfd_public_edit` -> `docs/diagrams/dfd_public_edit.mmd`
- `seq_edit_rollback` -> `docs/diagrams/seq_edit_rollback.mmd`
- `seq_edit_success` -> `docs/diagrams/seq_edit_success.mmd`
- `state_edit_session` -> `docs/diagrams/state_edit_session.mmd`

## Contracts satisfied by this phase

- edit write and rollback sequences from `section_11_edit_kernel`
- operation matrix rows for ordinary edit and low-level command-free mutations
  from `section_13_operation_matrix`
- exact touched invalidation and typed effect boundary from
  `section_11_edit_kernel`
- cross-owner document and selection rollback/commit atomicity from
  `section_11_edit_kernel`

## Tests and guardrails that prove this phase

- `test.edit.low_level_mutations_do_not_emit_actions` -> `test/edit/low_level_mutations_do_not_emit_actions_test.dart`
- `test.edit.sync_non_nested_async_stale` -> `test/edit/sync_non_nested_async_stale_test.dart`
- `test.edit.rollback` -> `test/edit/rollback_test.dart`
- `test.edit.operation_matrix_effects` -> `test/edit/operation_matrix_effects_test.dart`
- `test.edit.exact_touched_invalidation` -> `test/edit/exact_touched_invalidation_test.dart`
- `test.edit.typed_effects_no_frame_dependency` -> `test/edit/typed_effects_no_frame_dependency_test.dart`
- `test.runtime.runtime_state_publication` -> `test/runtime/runtime_state_publication_test.dart`
- `test.selection.runtime_owner_separation` -> `test/selection/runtime_owner_separation_test.dart`
- `edit.sync_non_nested`
- `edit.rollback_no_effects`
- `edit.stale_handle_rejected`
- `edit.operation_matrix_complete`
- `edit.no_global_invalidation_except_replacement`
- `edit.typed_effects_no_frame_dependency`
- `events.low_level_edit_no_user_actions`
- `selection.owner_separate_from_document`
- `core.single_runtime_root`

## Exit gate

- sync/non-nested/async/stale tests green
- rollback tests green
- rollback tests prove document and selection owners remain unchanged before
  the atomic install boundary
- operation matrix tests green for edit-owned operations
- ordinary document edits publish one coherent `CanvasRuntimeState`, while
  no-op edits and no-op runtime operations are public-state silent
- exact touched invalidation tests green
- typed effect boundary tests green
- low-level edits produce no user action events.

## Risks and trade-offs

- Letting `CommitCompiler` call concrete frame, spatial, or resource owners would
  couple mutation to downstream side effects. It must produce typed effects only.
- Deferring rollback proof would make every later mutation phase suspect.

## Why this phase belongs here

Every state-changing feature after P5 must use `EditKernel`. Atomic edit and
rollback behavior across document and selection owners must be proven before
load, resources, selection, drawing, or eraser commits are added.
