# Change Contract

If `4B. Architecture Decision Gate` is filled, stop after section 4.

## 1. Change Mandate

Make the architecture documentation consistently state that selection is
runtime view state owned by a dedicated selection owner, not committed document
state stored by `DocumentStoreKernel`, and lock the documentation-only migration
needed before implementation phases depend on selection behavior.

## 2. Change Boundary

### Included in the Change

- Update documentation only: architecture docs, contracts, implementation phase
  docs, diagrams, registries, indexes, verification inventories, `audit.md`,
  `redesign.md`, and this plan step when they mention selection ownership,
  selection revision ownership, selection access paths, selection invalidation,
  or replacement ordering.
- Introduce a documented internal `SelectionKernel` or equivalently named
  selection owner under `RuntimeRoot`.
- Remove selection from the documented `DocumentStoreKernel` and
  `CommittedDocument` responsibilities.
- Keep public `CanvasSelectionPort` as the public API boundary; do not expose
  `SelectionKernel` as a public type.
- Document that `selectionRevision` belongs to the selection owner and that
  selection changes do not increment `documentRevision` or invalidate public
  `CanvasDocument` projection.
- Document that full document replacement clears selection through one atomic
  runtime operation across document, selection, revision, cache, repaint, and
  public-signal effects.
- Document that ordinary committed paint plans do not depend on
  `selectionRevision`, selected ids, or selection flags.
- Document that selection decoration and selected-move staging read selection
  facts through narrow immutable query boundaries.
- Document batch, intent-specific selection/document fact query ports for
  normalization, select-all, marquee, selected-move start, and selected-move
  commit paths; avoid a public or internal design based on repeated
  per-property `exists`/`isVisible`/`isLocked` reads.
- Document `selectedOrder` as derived data or a bounded cache keyed by
  `selectionRevision` and `structuralRevision`, not a second stored source of
  truth.
- Update future verification descriptions so later implementation must prove
  selection/document ownership separation, atomic cross-owner commits, no
  concrete interaction imports of the selection owner, and ordinary paint plan
  independence from selection changes.
- Delete the selection-owner redesign/audit backlog mentions from `redesign.md`
  and `audit.md` after the decision is moved into normative docs, and
  synchronize all remaining documentation, registry, index, verification, and
  diagram references so those deletions do not leave stale navigation or
  unresolved-plan wording.

### Not Included in the Change

- No production Dart implementation under `lib/**`.
- No Dart test implementation under `test/**`.
- No guardrail runner or structural-analysis implementation under `tool/**`.
- No generated fixture creation.
- No public API addition that exposes `SelectionKernel` or any internal
  selection runtime type.
- No implementation of `SelectionKernel`, `DocumentFactsPort`,
  `SelectionFactsPort`, `RuntimeRoot`, `EditKernel`, `FrameEngine`, or cache
  classes.
- No broad redesign of camera, resource resolver cache, surface style
  revisions, action events, diagnostics, or schema v1 beyond wording needed to
  keep their selection invariants accurate.
- No execution of `dart analyze`, `dcm analyze .`, or
  `dcm calculate-metrics .`, because this step is documentation-only.
- No unrelated context-capsule baseline repair. If
  `dart run docs/tool/generate_context_capsules.dart --check` fails before the
  selection documentation edits begin, execution of this step must stop until
  that baseline is repaired by its owning documentation change.

## 3. Surrounding Code Review

### Inspected Artifacts

- `redesign.md` - proposes moving selection out of `DocumentStoreKernel`,
  making v1 selection content-only, introducing unified runtime revisions, and
  removing selection from ordinary paint plan cache keys; these proposal notes
  must be deleted once the same decisions are moved into normative docs.
- `audit.md` - may contain active or stale ownership/backlog mentions that must
  not remain as a second source of truth after the normative docs are updated.
- `PLAN.md` - is the active roadmap index and requires each step to link a
  dedicated contract under `plan/**`.
- `docs/architecture/01_runtime_ownership.md` - currently lists selection under
  `DocumentStoreKernel` responsibility and says interaction reads selection ids
  through runtime/store read boundaries.
- `docs/architecture/02_package_boundaries.md` - currently places
  `selection_store.dart` under the future `store/` package boundary.
- `docs/architecture/03_data_model.md` - currently lists
  `selection: SelectionStore` inside `CommittedDocument` and defines
  `selectionRevision` alongside document revision counters.
- `docs/contracts/load_document.md` - currently says the prepared replacement
  payload includes cleared selection and that clearing selection is not a
  separate post-install mutation.
- `docs/contracts/edit_kernel.md` - currently describes draft mutations and
  rollback obligations that include document, resources, and selection in one
  edit path.
- `docs/contracts/operation_matrix.md` - currently lists selection as touched
  state for remove, set selection, marquee, delete, clear content, eraser, and
  load rows.
- `docs/contracts/frame_rendering.md` - currently includes `selectionRevision`,
  `selectionIds`, and `selectionFlags` in main-frame and render-record
  descriptions, and includes `selectionRevision` in the ordinary paint plan key.
- `docs/contracts/cache_policy.md` - currently lists selection in
  `PaintPlanCache` keys and also defines `SelectedOrderCache` keyed by
  `selectionRevision` and `structuralRevision`.
- `docs/contracts/public_api_v1.md` - owns `CanvasSelectionPort`,
  `CanvasDocumentSummary.selectedCount`, rollback wording, and action payload
  semantics for selection actions.
- `docs/contracts/interaction_engine.md` - currently requires interaction to
  read committed facts through narrow query ports and commit only through
  `EditKernel`, but it does not name a separate selection owner.
- `docs/implementation/p4_runtime_spine.md` - currently includes
  `SelectionStore` in the runtime/store spine scope.
- `docs/implementation/p5_edit_core.md` and
  `docs/implementation/p6_load_document.md` - currently rely on selection as a
  future rollback and replacement participant without a separate owner.
- `docs/implementation/p9_frame_rendering_and_caches.md` and
  `docs/implementation/p10_selection_and_move.md` - are the future phase docs
  most directly affected by selection reads, selected move staging, and
  selection mutation paths.
- `docs/diagrams/**` - multiple C4, DFD, sequence, and state diagrams show
  `DocumentStoreKernel` as selection owner, show selection in ordinary paint
  cache keys, or show store-local selection mutation during marquee, eraser,
  edit, and load flows.
- `docs/_registry/sections.yaml`, `docs/_registry/donors.yaml`,
  `docs/indexes/**`, and `docs/verification/**` - contain current owner,
  guardrail, donor, phase, and test references that will drift unless the
  selection owner is registered consistently.
- Root `lib/**`, `test/**`, and `tool/guardrails/**` - do not exist yet in the
  target package, so this step cannot and must not implement executable
  production, test, or guardrail code.
- `docs/tool/generate_context_capsules.dart` - is the existing executable
  registry-to-context-capsule consistency check required by the docs workflow.
- `docs/tool/check_docs.dart` - is the existing executable documentation index
  consistency check required by the docs workflow.

### Current Entry Path

- Roadmap entry: `PLAN.md` links to root `plan/**` Change Contracts.
- Documentation entry: `docs/README.md` routes architecture, contract,
  implementation, diagram, verification, registry, and index updates.
- Design-backlog entry: `redesign.md` contains the selection-owner proposal
  that must move into normative documentation before implementation.
- Future public runtime entry: `CanvasRuntime.selection` exposes
  `CanvasSelectionPort`; the public API must remain the boundary for
  application selection commands.
- Future internal mutation entries: edit commands, interaction terminal
  commits, eraser cleanup, clear content, delete selection, and
  `loadDocument` replacement currently document selection effects through
  store/edit paths.

### Current Owner

- Selection ownership is currently documented as part of
  `DocumentStoreKernel` and `CommittedDocument`.
- Public selection commands are owned by `CanvasSelectionPort` in
  `docs/contracts/public_api_v1.md`.
- Interaction selection decisions are owned by `InteractionEngine` but must use
  query ports and `EditKernel`, not concrete store imports.
- Frame capture and paint-plan caching are owned by `FrameEngine`.
- Replacement orchestration is owned by `RuntimeRoot` and the staged
  `loadDocument` contract.
- Future verification descriptions are owned by `docs/verification/**`,
  registries, and indexes.

### Adjacent Abstractions

- `DocumentStoreKernel` remains the committed document owner for elements,
  layers, resources, background, document metadata, projection cache, and
  document revisions.
- `EditKernel` remains the synchronous edit-session owner and must coordinate
  document and selection effects without making selection part of document
  draft state.
- `InteractionEngine` remains the pointer/session/preview owner and reads
  selection through query boundaries.
- `FrameEngine` remains the frame capture, ordinary paint plan, selection
  decoration, selected supplement staging, and repaint owner.
- `SpatialKernel` remains a derived candidate index, not a selection source of
  truth.
- `RuntimeRoot` remains the composition root and is the correct owner for
  atomic cross-kernel replacement orchestration.

### Existing Tests

- No target root `test/**` implementation exists yet.
- `docs/verification/tests.md` is the existing source of truth for future test
  inventory and must name the future selection-owner proof.
- `docs/verification/guardrails.md` is the existing source of truth for future
  guardrail behavior and must name the future selection-boundary structural
  proof.
- `docs/tool/generate_context_capsules.dart --check` and
  `docs/tool/check_docs.dart` are the executable documentation consistency
  checks for this step.

### Analogous Implementation Path

- `plan/step_4_dto_metadata_immutability_and_const_policy.md` is the precedent
  for a documentation-only step that moves a redesign/audit decision into
  normative docs, updates registries and diagrams, and explicitly excludes
  production/test/guardrail implementation.
- `docs/contracts/load_document.md` is the closest valid precedent for a
  cross-owner atomic runtime operation because it already requires successful
  preparation before interaction interruption and no public notification before
  install.
- `docs/contracts/cache_policy.md` already contains `SelectedOrderCache` keyed
  by `selectionRevision` and `structuralRevision`, which is the valid precedent
  for derived selected order rather than a second stored ordering source.

### Governing Repository Rules

- `AGENTS.md` - documentation is written in English.
- `AGENTS.md` - repository-specific source-of-truth knowledge must be updated
  in repository docs, not left only in chat.
- `AGENTS.md` - prefer repository-local enforcement through future tests,
  guardrails, CI checks, or tooling rather than repeated prose reminders.
- `AGENTS.md` - documentation-only changes do not require `dart analyze`,
  `dcm analyze .`, or `dcm calculate-metrics .`.
- Root `AGENTS.md` project doc - `PLAN.md` is the active roadmap and source of
  truth for planned work.
- Root `AGENTS.md` project doc - when adding a new `PLAN.md` step, use the
  `change-contract` template as the canonical step-contract structure.
- `docs/architecture/00_architecture_overview.md` - this repository is the new
  architecture rebuild; legacy code is only a functional oracle, not the target
  runtime shape.

### Rejected Misleading Local Patterns

- Keeping selection in `DocumentStoreKernel` because existing docs say so -
  rejected because the documented problem is that selection is runtime view
  state, not persisted document content.
- Making `SelectionKernel.clearForReplacement` a separate public or observable
  mutation before `DocumentStoreKernel.installReplacement` - rejected because
  replacement must remain atomic to callers and listeners.
- Adding sync glue between document state and a duplicate selection copy -
  rejected because selection has one owner and document operations emit
  explicit selection effects through the runtime commit boundary.
- Keeping selection in ordinary `PaintPlanCache` keys - rejected because
  selection changes do not alter ordinary committed element records.
- Storing `selectedOrder` as independent state - rejected because document
  order changes can affect selected order without changing selected ids.
- Designing `DocumentFactsPort` as many per-id/per-property reads - rejected
  because batch intent-specific queries are the safer documented form for
  consistent revision snapshots.
- Exposing `SelectionKernel` in public API - rejected because
  `CanvasSelectionPort` is already the stable public selection boundary.
- Copying legacy controller/store ownership shape - rejected because legacy is
  a donor oracle only and the new package has a new runtime architecture.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- Selection is runtime view state owned below `RuntimeRoot` and outside
  committed document storage.
- The documentation change is an architecture-source-of-truth correction, not a
  production implementation step.

#### Selected Architectural Form

- Add a dedicated internal selection owner, referred to as `SelectionKernel`
  unless a later implementation step deliberately chooses an equivalent local
  name while preserving the documented responsibility.
- `DocumentStoreKernel` owns committed document tables and document revision
  facts only; it does not store selected ids or own `selectionRevision`.
- `SelectionKernel` owns selected ids, `selectionRevision`, selection
  normalization, clear, toggle, select-all, content-only filtering, and ordered
  selection snapshots.
- `RuntimeRoot` or the runtime commit/applier boundary owns atomic
  cross-kernel orchestration for operations that change document state and
  selection state together.
- `FrameEngine` owns ordinary paint plans separately from selection
  decoration and selected-move staging.

#### Owning Layer or Module

- Normative ownership docs: `docs/architecture/**`.
- Behavioral contracts: `docs/contracts/**`.
- Future phase contracts: `docs/implementation/**` and `plan/**`.
- Diagram ownership: `docs/diagrams/**`.
- Registry and proof ownership: `docs/_registry/**`, `docs/indexes/**`, and
  `docs/verification/**`.

#### Dependency Direction

- Public API calls enter through `CanvasSelectionPort`, `CanvasEditPort`,
  interaction/tool ports, and `CanvasRuntime`.
- `RuntimeRoot` composes `DocumentStoreKernel`, `SelectionKernel`,
  `EditKernel`, `InteractionEngine`, `FrameEngine`, `SpatialKernel`,
  `ResourceKernel`, `CodecBoundary`, and `DiagnosticsHub`.
- `SelectionKernel` may read document facts only through narrow immutable
  query ports supplied by the runtime/document boundary.
- `InteractionEngine` may read selection facts only through intent-specific
  query ports and must not import or mutate concrete `SelectionKernel` or
  `DocumentStoreKernel`.
- `EditKernel` coordinates selection effects through the runtime/applier
  boundary; it must not make selection a field of committed document draft
  state.
- `FrameEngine` captures selection facts through a read boundary and must not
  make ordinary paint records or ordinary paint plan keys depend on selection.

#### State and Data Ownership

- `DocumentStoreKernel`: elements, layers, resources, background, persisted
  document metadata, document revision facts, id admission, and public document
  projection cache.
- `SelectionKernel`: selected element ids, selection membership revision,
  selection normalization rules, content-only filtering, selection clearing,
  select-all, toggle, and derived ordered selection snapshots.
- `RuntimeRoot` or commit/applier boundary: atomic publication of cross-owner
  document and selection effects, revision snapshots, invalidation effects,
  repaint requests, and public notifications.
- `FrameEngine`: ordinary paint plan cache, selection decoration plan, selected
  move supplement staging, and main/overlay repaint routing.

#### Entry and Exit Boundaries

- `loadDocument` entry validates and materializes replacement document data
  first, interrupts interaction only after successful preparation, and then
  installs document replacement plus selection clear as one atomic runtime
  operation before public notification.
- Selection-only commands update `SelectionKernel`, increment
  `selectionRevision` only when membership changes, repaint the main scene for
  selection UI, and do not increment `documentRevision` or evict public
  `CanvasDocument` projection.
- Document operations that remove selected elements emit a selection-prune
  effect to `SelectionKernel` inside the same atomic runtime commit.
- Frame capture reads document facts and selection facts as separate immutable
  captured inputs and paints selection UI without storing selection in ordinary
  committed render records.

#### Permitted Extension Seam

- Add or document narrow internal query ports such as `SelectionFactsPort`,
  `SelectionNormalizationPort`, or intent-specific read models for
  normalization, select-all, marquee, selected-move start, selected-move
  commit, and frame selection capture.
- Add or document structural guardrails that forbid direct concrete imports
  from interaction to store or selection owners.
- Add or document cache policy rows for selection decoration and selected order
  if the existing rows are insufficient after the split.

#### Rejected Alternatives

- Keep selection inside `DocumentStoreKernel` - rejected because it keeps view
  state mixed with committed document state and makes `documentRevision`
  semantics harder to keep legible.
- Move selection into `InteractionEngine` - rejected because selection is public
  runtime state used by API commands, frame capture, edit commands, and
  interactions, not only pointer-session state.
- Persist selection in `CanvasDocument` or schema v1 - rejected because current
  public document and schema contracts do not make selected ids document
  content.
- Use post-install selection cleanup after document replacement - rejected
  because it creates an observable cross-owner consistency gap unless hidden
  behind the same atomic runtime operation; the contract must document the
  atomic operation directly.
- Use per-property document fact reads for normalization - rejected because
  batch intent-specific reads better preserve snapshot consistency and make
  future structural tests easier to target.

#### Why This Level Is Correct

- Selection is shared runtime state visible through public commands, rendering,
  interaction, and edit effects, so it needs its own owner rather than being
  hidden in any one consumer.
- `RuntimeRoot` is already the composition root for cross-owner replacement and
  notification ordering, so it is the correct level for atomic document plus
  selection effects.
- Separating ordinary paint plans from selection state preserves cache
  correctness: selection changes affect selection UI, not ordinary committed
  element records.
- Documentation must be corrected before P4/P5/P6/P9/P10 implementation phases
  lock the wrong owner into code.

### 4B. Architecture Decision Gate

## 5. Locked Decisions

1. The new internal owner is documented as `SelectionKernel` unless a later
   implementation contract explicitly renames it while preserving the same
   boundaries.
2. `DocumentStoreKernel` documentation must no longer list selection,
   selected ids, selected order, or `selectionRevision` as committed document
   state.
3. `selectionRevision` is a runtime selection revision, not a document
   revision.
4. Selection-only changes do not increment `documentRevision`, do not evict
   `DocumentProjectionCache`, and do not update `SpatialKernel`.
5. Full document replacement clears selection atomically with replacement
   effects through the runtime/applier boundary.
6. Ordinary paint plan cache keys and cached ordinary records exclude
   selection membership, selection flags, and selected-move preview deltas.
7. Selection decoration, selected order, and selected move supplement staging
   are separate render concerns from ordinary committed paint plans.
8. Query ports for selection normalization and interaction decisions are
   batch, immutable, and intent-specific.
9. Future structural proof must make concrete interaction imports of store or
   selection owners visible.
10. This step is documentation-only and must not create `lib/**`, `test/**`,
    or `tool/**` implementation files.

## 6. Result Requirements

1. The normative docs present one coherent ownership model:
   `DocumentStoreKernel` owns committed document state and `SelectionKernel`
   owns runtime selection state.
2. Every documented mutation path that changes both document and selection
   state describes one atomic runtime result with no public intermediate state.
3. Every documented failure and rollback path states that both document and
   selection owners remain unchanged when the operation fails before commit.
4. Frame and cache docs make selection changes independent of ordinary paint
   plan invalidation.
5. Diagrams agree with the textual contracts on selection owner, selection
   revision owner, and ordinary paint cache independence.
6. Registries and indexes route future implementation and verification work to
   the selection owner instead of the document store.
7. Verification docs name future behavioral and structural proof for the split,
   even though this step does not implement tests or guardrails.
8. `redesign.md` and `audit.md` no longer contain obsolete selection-owner
   proposal or audit backlog mentions after the normative docs are updated.
9. Registry, index, verification, and diagram references remain synchronized
   with the deleted `redesign.md` and `audit.md` mentions.

## 7. Execution Order and Gates

### Required Order

- Before changing selection documentation, run
  `dart run docs/tool/generate_context_capsules.dart --check` and
  `dart run docs/tool/check_docs.dart` to confirm the documentation baseline is
  green. If either check fails on files unrelated to this step, stop and repair
  the baseline through its owning documentation change before executing this
  step.
- First update architecture and package-boundary docs so owner names and
  dependency direction are fixed.
- Then update contracts for public API semantics, edit, load, operation matrix,
  interaction, frame rendering, and cache policy.
- Then update implementation phase docs in dependency order: P4, P5, P6, P8,
  P9, P10, and only then secondary P11-P13 references.
- Then update diagrams to match the textual contracts.
- Then update registries, indexes, verification docs, audit, and redesign
  references.
- Delete the now-moved selection-owner mentions from `redesign.md` and
  `audit.md`, then re-check the rest of the documentation set for references
  that still point to those removed backlog entries.
- Finally run the full documentation consistency checks and review the diff for
  stale `DocumentStoreKernel` selection ownership wording.

### Successor Seam and Retirement Gates

- Successor seam: `SelectionKernel` plus narrow selection/document fact query
  ports replace the documented `SelectionStore` inside `DocumentStoreKernel`.
- Retirement gate: no normative architecture, contract, phase, diagram,
  registry, index, or verification doc may state that committed document state
  owns selection.
- Retirement gate: ordinary paint plan docs and diagrams no longer include
  selection in ordinary cache keys or ordinary cached render record state.
- Retirement gate: `redesign.md` and `audit.md` no longer carry the
  selection-owner decision as proposal, audit, or unresolved backlog text after
  the normative docs own it.
- Retirement gate: every remaining registry, index, verification, diagram, and
  phase-doc reference is synchronized with the deleted `redesign.md` and
  `audit.md` text.
- Retirement gate: future guardrail/test descriptions cover selection owner
  imports, selection/document revision separation, and ordinary paint cache
  independence.

### Deferred Broad Verification

- `dart analyze` is deferred because this is documentation-only.
- `dcm analyze .` is deferred because this is documentation-only.
- `dcm calculate-metrics .` is deferred because this is documentation-only.
- Future implementation steps must run the full code checks required by root
  `AGENTS.md` after code changes.

## 8. File Map

### Implementation Files

- None. Root `lib/**` does not exist and is out of scope for this
  documentation-only step.

### Test Files

- None. Root `test/**` does not exist and is out of scope for this
  documentation-only step.

### Fixtures and Supporting Data

- None.

### Registry, Inventory, and Workflow Files

- `PLAN.md` - active roadmap entry for this step.
- `plan/step_5_selection_runtime_ownership_documentation.md` - this change
  contract.
- `redesign.md` - delete the moved selection-owner proposal after the normative
  docs own the decision.
- `audit.md` - delete selection/store ownership audit mentions made obsolete by
  this documentation step.
- `docs/README.md` - update only if document navigation must mention the new
  selection owner source of truth.
- `docs/architecture/01_runtime_ownership.md` - runtime ownership table and
  query-boundary wording.
- `docs/architecture/02_package_boundaries.md` - future package layout and
  selection owner location.
- `docs/architecture/03_data_model.md` - committed document model, revision
  ownership, and projection/cache ownership.
- `docs/contracts/public_api_v1.md` - public selection semantics, summary
  semantics, rollback wording, and action payload wording.
- `docs/contracts/load_document.md` - staged replacement and atomic
  cross-owner selection clear.
- `docs/contracts/edit_kernel.md` - selection effects and rollback across
  owners.
- `docs/contracts/operation_matrix.md` - selection owner and revision effects
  per operation.
- `docs/contracts/interaction_engine.md` - selection fact query ports and
  import boundaries.
- `docs/contracts/frame_rendering.md` - selection capture, selection
  decoration, selected supplement staging, and ordinary record contents.
- `docs/contracts/cache_policy.md` - ordinary paint plan keys, selected order,
  and selection decoration cache policy.
- `docs/contracts/resources.md`, `docs/contracts/geometry.md`,
  `docs/contracts/spatial_kernel.md`, and `docs/contracts/diagnostics.md` -
  update only note-level selection invariants that name the wrong owner.
- `docs/implementation/p4_runtime_spine.md` - runtime composition and store
  spine scope.
- `docs/implementation/p5_edit_core.md` - edit rollback and selection effects.
- `docs/implementation/p6_load_document.md` - load replacement ordering and
  cross-owner atomicity.
- `docs/implementation/p8_geometry_and_spatial.md` - selection read ownership
  in geometry/spatial consumers.
- `docs/implementation/p9_frame_rendering_and_caches.md` - selection capture,
  selected supplement staging, and paint cache proof.
- `docs/implementation/p10_selection_and_move.md` - primary selection owner,
  API behavior, marquee, selected move, and interaction proof.
- `docs/implementation/p11_draw_tools.md`,
  `docs/implementation/p12_eraser_and_text_request.md`, and
  `docs/implementation/p13_flutter_surface.md` - secondary references only.
- `docs/_registry/sections.yaml` - section ownership, must-read dependencies,
  tests, and guardrail references.
- `docs/_registry/donors.yaml` - donor owner split for selection helpers and
  move/marquee selection donors.
- `docs/_registry/public_api_v1.yaml` - update only if public selection names
  change; adding `SelectionKernel` here is forbidden.
- `docs/indexes/by_guardrail.md`, `docs/indexes/by_test_area.md`,
  `docs/indexes/by_subsystem.md`, `docs/indexes/context_coverage.md`, and
  `docs/indexes/donor_to_phase.md` - update or regenerate references affected
  by the owner split.
- `docs/verification/guardrails.md` - future structural guardrail wording.
- `docs/verification/tests.md` - future test inventory for selection owner
  behavior and cache independence.
- `docs/verification/functional_ledger.md` - update only if selection behavior
  ownership wording appears there.
- `docs/tool/generate_context_capsules.dart` - no expected change; used as a
  required workflow check.
- `docs/tool/check_docs.dart` - no expected change unless the documentation
  index checker needs a new P-step mapping.

### Analysis Area

- `docs/diagrams/c4_component_runtime.mmd`
- `docs/diagrams/c4_code_edit_kernel.mmd`
- `docs/diagrams/c4_container.mmd`
- `docs/diagrams/dfd_cache_invalidation.mmd`
- `docs/diagrams/dfd_load_document_success_failure.mmd`
- `docs/diagrams/dfd_main_paint_frame.mmd`
- `docs/diagrams/dfd_pointer_preview_commit.mmd`
- `docs/diagrams/dfd_public_edit.mmd`
- `docs/diagrams/dfd_overlay_frame.mmd`
- `docs/diagrams/seq_dispose_during_gesture.mmd`
- `docs/diagrams/seq_edit_rollback.mmd`
- `docs/diagrams/seq_edit_success.mmd`
- `docs/diagrams/seq_eraser_commit.mmd`
- `docs/diagrams/seq_eraser_exact_budget.mmd`
- `docs/diagrams/seq_load_document_failure.mmd`
- `docs/diagrams/seq_load_document_success.mmd`
- `docs/diagrams/seq_main_paint.mmd`
- `docs/diagrams/seq_marquee_select.mmd`
- `docs/diagrams/seq_resource_resolution.mmd`
- `docs/diagrams/seq_selected_move_cancel.mmd`
- `docs/diagrams/seq_selected_move_preview_commit.mmd`
- `docs/diagrams/state_edit_session.mmd`
- `docs/diagrams/state_resource_resolution.mmd`
- `docs/diagrams/state_runtime_lifecycle.mmd`
- `docs/diagrams/state_select_marquee.mmd`

## 9. Implementation Rules

### Protected Invariants

- Selection is not persisted document content.
- Selection has exactly one runtime owner.
- Selection-only changes never mutate committed document tables, public
  document projection, spatial index, or document revision counters.
- Operations that change document membership and selection membership publish
  one atomic runtime result.
- Failed validation, rollback, no-op, dispose, and resource dirty paths do not
  accidentally mutate selection.
- Ordinary committed paint plans are independent of selection membership and
  selected-move preview state.
- Public `CanvasSelectionPort` remains the app-facing selection boundary.

### Required Proof

- behavioral proof: run `dart run docs/tool/generate_context_capsules.dart --check`
  and `dart run docs/tool/check_docs.dart` after the documentation edits and
  confirm the documentation index remains consistent.
- structural proof: review `rg -n "DocumentStoreKernel.*selection|CommittedDocument.*selection|PaintPlanCache.*selection|selection: SelectionStore|selectionRevision.*document"` results after the edits and ensure any remaining matches are either historical, explicitly rejected, or name the new selection owner correctly.
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps: not applicable because this step is a
  documentation-only architecture correction without production code.
- for refactors: this is a documentation refactor. Existing source-of-truth
  docs listed in section 3 are the characterization surface, and
  `docs/tool/generate_context_capsules.dart --check` plus
  `docs/tool/check_docs.dart` are the executable consistency checks.

### Allowed Change Surface

- Documentation and registry files listed in section 8.
- Diagram text under `docs/diagrams/**`.
- `audit.md` and `redesign.md` deletion edits directly related to removing
  obsolete selection ownership backlog/proposal mentions.
- This plan step and its `PLAN.md` entry.

### Forbidden Moves

- Do not add production code under `lib/**`.
- Do not add tests under `test/**`.
- Do not add guardrail runner code under `tool/**`.
- Do not expose `SelectionKernel` or any internal selection owner in
  `docs/_registry/public_api_v1.yaml`.
- Do not leave selection as a `CommittedDocument` field in normative docs.
- Do not describe selection clearing on load as a separate observable mutation.
- Do not keep selection in ordinary `PaintPlanCache` keys or cached ordinary
  records.
- Do not create sync glue or duplicate selection sources of truth.
- Do not broaden this step into camera, resource cache, surface style, or
  schema redesign items.

### Optional: Recognition Forms That Must Be Supported

- Documentation may use `SelectionKernel`, `selection owner`, or
  `SelectionRuntime` only when the term clearly refers to the same internal
  runtime owner.
- Diagrams may show selection as a separate participant or as a subcomponent of
  `RuntimeRoot`, but not as a subcomponent of `DocumentStoreKernel`.
- Operation matrix rows may name selection as an effect when the owner and
  revision scope are explicitly selection-owned.

### Optional: Allowed Forms That Are Not Violations

- It is allowed to say that an operation preserves selection when the statement
  is owner-neutral or explicitly points to `SelectionKernel`.
- It is allowed for frame capture to include selected ids as captured runtime
  facts when they are read from the selection owner and not cached in ordinary
  paint plans.
- It is allowed for delete, eraser, and clear-content operations to prune
  selected ids when the pruning is documented as an atomic selection effect.

### Optional: Resolution Rules

- If a document needs to mention both document and selection effects, list the
  document effect first and the selection-owner effect second, then state the
  atomic publication boundary once.
- If an index is generated from registry data, update the registry first and
  regenerate or manually align the index according to the existing docs
  workflow.
- If a note-only diagram mentions selection as an invariant without owner
  details, update it only when nearby text would otherwise imply store
  ownership.

## 10. Vertical Slices

### Slice 1. [ ] Lock Architecture Ownership Text

#### Slice Contract

The core architecture docs must define `SelectionKernel` as the runtime owner
for selected ids and `selectionRevision`, and must remove selection from
committed document ownership.

#### Change

Update `docs/architecture/01_runtime_ownership.md`,
`docs/architecture/02_package_boundaries.md`, and
`docs/architecture/03_data_model.md`.

#### Behavioral Verification

- Run `dart run docs/tool/generate_context_capsules.dart --check`.
- Run `dart run docs/tool/check_docs.dart`.

#### Structural Verification

- Run `rg -n "DocumentStoreKernel.*selection|CommittedDocument.*selection|selection: SelectionStore|selectionRevision.*document" docs/architecture`.

#### Fixtures Used

- None.

#### Positive Scenarios

- Runtime ownership table lists `SelectionKernel` separately from
  `DocumentStoreKernel`.
- Committed document model contains no `selection: SelectionStore` field.
- `selectionRevision` is documented as selection-owned runtime state.

#### Negative Scenarios

- Architecture docs state or imply that selected ids are committed document
  state.
- Package layout places the selection owner under store ownership.

#### Closure Evidence

- Architecture docs agree on selection owner and document-store exclusions.

### Slice 2. [ ] Align Mutation and Replacement Contracts

#### Slice Contract

Mutation, rollback, operation-matrix, and load contracts must describe
selection as a separate owner while preserving atomic public behavior for
cross-owner operations.

#### Change

Update `docs/contracts/public_api_v1.md`,
`docs/contracts/load_document.md`, `docs/contracts/edit_kernel.md`,
`docs/contracts/operation_matrix.md`, and
`docs/contracts/interaction_engine.md`.

#### Behavioral Verification

- Run `dart run docs/tool/generate_context_capsules.dart --check`.
- Run `dart run docs/tool/check_docs.dart`.

#### Structural Verification

- Run `rg -n "replacement payload.*selection|cleared selection.*payload|committed document.*selection|InteractionEngine.*(mutate|mutation|read).*SelectionKernel|InteractionEngine.*(mutate|mutation|read).*DocumentStoreKernel" docs/contracts`.

#### Fixtures Used

- None.

#### Positive Scenarios

- `loadDocument` succeeds with one atomic replacement plus selection-clear
  runtime result.
- Failed load preserves both document and selection owners.
- Selection-only API changes affect `selectionRevision`, not
  `documentRevision`.
- Remove, delete, clear, and eraser rows describe selection pruning as an
  atomic selection-owner effect.

#### Negative Scenarios

- Selection clear is described as a separate observable post-install mutation.
- Selection-only changes evict public document projection.
- Interaction directly reads or mutates concrete selection owner internals.

#### Closure Evidence

- Contract docs use one cross-owner atomicity model and no longer place
  selection in document draft state.

### Slice 3. [ ] Align Frame, Cache, and Diagram Sources

#### Slice Contract

Frame/cache docs and diagrams must remove selection from ordinary paint plan
keys and ordinary cached records while preserving selection decoration and
selected-move staging behavior.

#### Change

Update `docs/contracts/frame_rendering.md`,
`docs/contracts/cache_policy.md`, and affected diagrams listed in section 8.

#### Behavioral Verification

- Run `dart run docs/tool/generate_context_capsules.dart --check`.
- Run `dart run docs/tool/check_docs.dart`.

#### Structural Verification

- Run `rg -n "PaintPlanCache.*selection|ordinary.*cache.*selection|selectionFlags|selection flags|ordinary.*records.*selection" docs/contracts/frame_rendering.md docs/contracts/cache_policy.md docs/diagrams`.

#### Fixtures Used

- None.

#### Positive Scenarios

- Ordinary paint plan cache keys include document structure, bounds, element
  visual inputs, viewport inputs, and device/pixel inputs, but not selection.
- Selection decoration and selected order are separate selection-owned or
  frame-owned derived concerns.
- Selected move supplement records remain per-frame and uncached.

#### Negative Scenarios

- Selection changes invalidate ordinary committed paint plans.
- Ordinary cached render records store selection membership.
- Selected move preview delta enters ordinary paint plan cache keys or values.

#### Closure Evidence

- Textual contracts and diagrams agree on ordinary paint cache independence
  from selection.

### Slice 4. [ ] Align Phase, Registry, Verification, and Backlog Records

#### Slice Contract

Future implementation phases, registries, indexes, verification docs, and
backlog records must route selection ownership and proof to the new selection
owner, and obsolete `redesign.md` and `audit.md` mentions must be deleted after
their content is moved into normative docs.

#### Change

Update affected `docs/implementation/**`, `docs/_registry/**`,
`docs/indexes/**`, `docs/verification/**`, `audit.md`, `redesign.md`, and this
plan step if closure checkboxes are completed.

#### Behavioral Verification

- Run `dart run docs/tool/generate_context_capsules.dart --check`.
- Run `dart run docs/tool/check_docs.dart`.

#### Structural Verification

- Run `rg -n "SelectionStore|DocumentStoreKernel.*selection|store\\.no_public_document_live_state|interaction\\.no_concrete_store_imports|selection owner|SelectionKernel|redesign\\.md|audit\\.md" docs/implementation docs/_registry docs/indexes docs/verification audit.md redesign.md`.

#### Fixtures Used

- None.

#### Positive Scenarios

- P4 introduces the selection owner as a runtime component, not as store state.
- P5/P6 describe cross-owner rollback and replacement proof.
- P9/P10 point frame and interaction work at selection-owner query boundaries.
- Verification docs name future behavioral and structural proof for the split.
- `redesign.md` and `audit.md` no longer contain obsolete selection-owner
  proposal or audit backlog mentions.
- Remaining docs, registries, indexes, verification inventories, and diagrams
  do not point at deleted `redesign.md` or `audit.md` selection entries.

#### Negative Scenarios

- Future phase docs continue to send selection reads or writes to concrete
  `DocumentStoreKernel`.
- Guardrail docs only forbid concrete store imports but allow direct concrete
  selection owner imports from interaction.
- Backlog text in `redesign.md` or `audit.md` keeps the decision as unresolved
  after normative docs are updated.
- A registry, index, verification, or diagram reference still points at a
  deleted `redesign.md` or `audit.md` selection entry.

#### Closure Evidence

- Registry, index, verification, diagram, `redesign.md`, and `audit.md` records
  align with the locked architecture and contain no stale references to removed
  backlog entries.

## 11. Final Verification

- Run `dart run docs/tool/generate_context_capsules.dart --check`.
- Run `dart run docs/tool/check_docs.dart`.
- Run `rg -n "selection: SelectionStore|DocumentStoreKernel.*selection|CommittedDocument.*selection|PaintPlanCache.*selection|selection flags|selectionFlags|redesign\\.md|audit\\.md" docs PLAN.md plan audit.md redesign.md` and inspect remaining matches for correctness.
- Do not run `dart analyze`, `dcm analyze .`, or `dcm calculate-metrics .`
  for this documentation-only step.

## 12. Acceptance Criteria

- `PLAN.md` links this step.
- The normative docs state that selection is runtime view state owned by
  `SelectionKernel` or the documented equivalent selection owner.
- `DocumentStoreKernel` and `CommittedDocument` docs no longer own selected ids
  or `selectionRevision`.
- `loadDocument`, edit, delete, clear, eraser, marquee, and selected-move docs
  preserve atomic public behavior across document and selection effects.
- Ordinary paint plan documentation excludes selection membership and
  selected-move preview state from ordinary cache keys and cached ordinary
  records.
- Diagrams, registries, indexes, and verification docs align with the selected
  ownership model.
- Obsolete selection-owner mentions are deleted from `redesign.md` and
  `audit.md`, and the rest of the documentation set is synchronized with those
  deletions.
- The future proof inventory includes behavioral and structural proof for
  selection/document separation, selection query boundaries, and paint cache
  independence.
- Both documentation consistency checks pass:
  `dart run docs/tool/generate_context_capsules.dart --check` and
  `dart run docs/tool/check_docs.dart`.
