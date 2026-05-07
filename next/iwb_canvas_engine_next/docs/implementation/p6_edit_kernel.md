# P6 - edit kernel

## Build

- EditSession
- DraftDocument
- TouchedSet
- CommitCompiler
- CommitPlan
- CommitApplier
- rollback and stale handle enforcement
- staged loadDocument
- replaceDraftDocument.

## Read first

- `section_10_runtime_data_model` -> `docs/architecture/03_data_model.md`
- `section_11_edit_kernel` -> `docs/contracts/edit_kernel.md`
- `section_12_load_document` -> `docs/contracts/load_document.md`
- `section_13_operation_matrix` -> `docs/contracts/operation_matrix.md`

## Required donors

- `dto_document_helpers` - decision: `adapt`; target owner: DocumentStoreKernel and EditKernel helpers
- `interaction_mutation_boundary` - decision: `adapt`; target owner: Interaction-owned mutation bridge into EditKernel
- `staged_load_runtime_materialization` - decision: `adapt`; target owner: loadDocument staged materialization
- `validated_import_draft` - decision: `adapt`; target owner: Validated document import draft

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
- `dfd_load_document_success_failure` -> `docs/diagrams/dfd_load_document_success_failure.mmd`
- `dfd_public_edit` -> `docs/diagrams/dfd_public_edit.mmd`
- `seq_edit_rollback` -> `docs/diagrams/seq_edit_rollback.mmd`
- `seq_edit_success` -> `docs/diagrams/seq_edit_success.mmd`
- `seq_load_document_failure` -> `docs/diagrams/seq_load_document_failure.mmd`
- `seq_load_document_success` -> `docs/diagrams/seq_load_document_success.mmd`
- `state_edit_session` -> `docs/diagrams/state_edit_session.mmd`

## Guardrails

- `edit.rollback_no_effects` - rollback discards events/repaint/resources/spatial
- `edit.stale_handle_rejected` - stale edit handle throws
- `edit.sync_non_nested` - nested/async edit rejected
- `edit.operation_matrix_complete` - every operation matrix row has executable effect assertions
- `edit.no_global_invalidation_except_replacement` - ordinary edits compile exact touched invalidation only
- `edit.typed_effects_no_frame_dependency` - CommitCompiler produces typed effects without depending on FrameEngine
- `events.low_level_edit_no_user_actions` - CanvasEdit.removeElement/clearContent emit no user action events
- `load.prepares_before_interrupt` - failed load does not interrupt gesture
- `load.success_interrupts_before_install` - success interrupt happens before atomic install
- `core.single_runtime_root` - exactly one production RuntimeRoot

## Tests

- `test.edit.low_level_mutations_do_not_emit_actions` -> `test/edit/low_level_mutations_do_not_emit_actions_test.dart`
- `test.edit.sync_non_nested_async_stale` -> `test/edit/sync_non_nested_async_stale_test.dart`
- `test.edit.rollback` -> `test/edit/rollback_test.dart`
- `test.edit.operation_matrix_effects` -> `test/edit/operation_matrix_effects_test.dart`
- `test.edit.exact_touched_invalidation` -> `test/edit/exact_touched_invalidation_test.dart`
- `test.edit.typed_effects_no_frame_dependency` -> `test/edit/typed_effects_no_frame_dependency_test.dart`
- `test.edit.staged_document_load_success_failure` -> `test/edit/staged_document_load_success_failure_test.dart`

## Exit gate

- sync/non-nested/async/stale tests green
- rollback tests green
- loadDocument staged tests green
- operation matrix tests green
- exact touched invalidation tests green
- typed effect boundary tests green.
