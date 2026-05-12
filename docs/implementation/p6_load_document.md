# P6 - loadDocument and draft replacement

## Purpose

Implement full document replacement as a staged, validated, atomic operation,
and keep failed loads from interrupting existing runtime or interaction state.

## Build scope

- `PreparedDocumentLoad`
- validated import draft materialization
- `CanvasEditPort.loadDocument`
- `CanvasEdit.replaceDraftDocument`
- success path: validate/materialize, interrupt active interaction through a
  narrow runtime boundary, clear preview, install replacement payload, increment
  controller epoch and replacement revisions, clear pointer normalization hooks,
  invalidate projection/spatial/frame/resource caches, and notify after install
- failure path: validation/materialization failure leaves committed document,
  selection, preview, pointer normalization, repaint, events, and active gesture
  state unchanged
- replacement uses one atomic install boundary and includes cleared selection in
  the replacement payload.

## Dependencies on earlier phases

- P4 runtime spine owns store, revisions, projection, and controller epoch.
- P5 edit core owns rollback-safe draft mutation and typed effects.

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

- `dfd_load_document_success_failure` -> `docs/diagrams/dfd_load_document_success_failure.mmd`
- `dfd_public_edit` -> `docs/diagrams/dfd_public_edit.mmd`
- `seq_load_document_failure` -> `docs/diagrams/seq_load_document_failure.mmd`
- `seq_load_document_success` -> `docs/diagrams/seq_load_document_success.mmd`
- `state_runtime_lifecycle` -> `docs/diagrams/state_runtime_lifecycle.mmd`
- `state_edit_session` -> `docs/diagrams/state_edit_session.mmd`

## Contracts satisfied by this phase

- staged `loadDocument` success and failure ordering from
  `section_12_load_document`
- replacement rows in `section_13_operation_matrix`
- draft replacement behavior from `section_11_edit_kernel`
- runtime lifecycle replacement effects from `section_10_runtime_data_model`

## Tests and guardrails that prove this phase

- `test.edit.staged_document_load_success_failure` -> `test/edit/staged_document_load_success_failure_test.dart`
- `load.prepares_before_interrupt`
- `load.success_interrupts_before_install`
- `edit.rollback_no_effects`
- `edit.stale_handle_rejected`
- `edit.operation_matrix_complete`
- `core.single_runtime_root`

## Exit gate

- `loadDocument` staged tests green
- failed load preserves active interaction through the runtime interrupt boundary
- successful load interrupts before install and installs one replacement payload
  with cleared selection
- `replaceDraftDocument` is rollback-safe inside an edit session
- load success/failure operation matrix effects are executable and green.

## Risks and trade-offs

- Interrupting interaction before validation would destroy user state on bad
  input. Validation and materialization must complete first.
- Implementing load as a normal edit sequence would risk separate selection,
  epoch, cache, and projection updates. Replacement is one atomic boundary.

## Why this phase belongs here

Resources, spatial indexes, frames, and interaction all need a reliable document
replacement contract. P6 follows edit core and precedes features that must react
to load success or failure.
