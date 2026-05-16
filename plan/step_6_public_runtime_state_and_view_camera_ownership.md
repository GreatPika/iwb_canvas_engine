# Change Contract

## 1. Change Mandate

Replace the public revision/listener model with one coherent runtime state
snapshot and lock camera panning as runtime view state instead of document
mutation.

## 2. Change Boundary

### Included in the Change

- Update documentation only: architecture docs, public API contract, subsystem
  contracts, implementation phase docs, diagrams, registries, indexes,
  verification inventories, `audit.md`, `redesign.md`, and this plan step when
  they mention public revision listeners, runtime summaries, camera revision
  ownership, camera persistence, state publication, or dispose listener
  lifecycle.
- Replace public `documentRevisionListenable` and `previewRevisionListenable`
  with one public `ValueListenable<CanvasRuntimeState> get state`.
- Define public `CanvasRuntimeState` as the atomic public runtime snapshot that
  contains `CanvasRuntimeRevisions revisions` and `CanvasRuntimeSummary summary`.
- Define public `CanvasRuntimeRevisions` with stable public revision domains:
  document, selection, preview, view camera, resource visual, interaction, and
  epoch.
- Define public `CanvasRuntimeSummary` for current runtime counts, including
  selected count, without duplicating revision or epoch fields.
- Keep `CanvasDocumentSummary` only for persisted document or draft-document
  facts; remove runtime selection and listener facts from that document-named
  summary.
- Document that runtime view camera changes through `CanvasCameraPort` update
  `state.revisions.viewCamera`, repaint affected surfaces, and do not increment
  document revision or invalidate public `CanvasDocument` projection.
- Document that persisted document camera is the default camera stored in
  `CanvasDocument` and schema v1, changed only through the document edit
  boundary, and read back through `readDocument`.
- Update operation matrix rows for selection, preview, resource dirty, tool or
  interaction settings, load, dispose, and camera operations so every public
  runtime change names its public state publication behavior.
- Update future verification descriptions so later implementation must prove
  state-listenable notification, terminal readability after dispose, and camera
  view/document separation.
- Record that the corresponding `redesign.md` backlog proposal and `audit.md`
  rows are removed only in the final cleanup slice, after the prior
  normative-documentation slices and their slice-local proof have passed, so
  neither file remains a second source of truth for accepted decisions.

### Not Included in the Change

- No production Dart implementation under `lib/**`.
- No Dart test implementation under `test/**`.
- No guardrail runner or structural-analysis implementation under `tool/**`.
- No generated fixture creation.
- No implementation of `RuntimeRoot`, revision notifiers, camera storage,
  `FrameEngine`, `InteractionEngine`, `CanvasSurface`, or cache classes.
- No public API compatibility shim for the retired
  `documentRevisionListenable` or `previewRevisionListenable`, because the root
  package is still in architecture rebuild before API freeze.
- No full split of `frameMetaRevision` into background, grid, or surface-style
  public revision domains. This step may remove runtime view camera from
  document/frame-meta semantics, but broader frame-meta cache decomposition is a
  separate optimization decision.
- No move of resource resolver cache ownership to surface sessions.
- No conversion of `CanvasPreviewState` to a sealed union.
- No execution of `dart analyze`, `dcm analyze .`, or
  `dcm calculate-metrics .`, because this step is documentation-only.
- No unrelated context-capsule baseline repair. If
  `dart run docs/tool/generate_context_capsules.dart --check` fails before this
  documentation edit begins, execution of this step must stop until that
  baseline is repaired by its owning documentation change.

## 3. Surrounding Code Review

### Inspected Artifacts

- `redesign.md` - currently contains the active proposal to replace separate
  public revision listenables with `CanvasRuntimeRevisions`, add
  `CanvasRuntimeSummary`, and split camera into runtime view camera and
  persisted document camera; those proposal notes must be deleted only after the
  same decisions are moved into normative docs and the step proof passes.
- `audit.md` - currently tracks operation matrix holes and still lists
  `setOffset`, `panBy`, `documentRevision`, `previewRevision`, and
  `frameMetaRevision` checklist items; this step must replace that stale
  backlog language with public runtime state/revision effects only after the
  normative docs and proof are complete.
- `PLAN.md` - is the active roadmap index and requires each step to link a
  dedicated contract under `plan/**`.
- `docs/contracts/public_api_v1.md` - currently exposes
  `CanvasDocumentSummary get summary`, `documentRevisionListenable`, and
  `previewRevisionListenable` on `CanvasRuntime`; it also defines
  `CanvasDocumentSummary` with `revision`, `epoch`, and `selectedCount`, uses
  `CanvasDocumentSummary` for `CanvasEdit.draftSummary`, defines
  `CanvasEdit.setCameraOffset`, and defines `CanvasCameraPort.setOffset` and
  `panBy`.
- `docs/_registry/public_api_v1.yaml` - is the machine-readable exported-name
  inventory and currently lists `CanvasDocumentSummary` but not
  `CanvasRuntimeState`, `CanvasRuntimeRevisions`, or `CanvasRuntimeSummary`.
- `docs/architecture/01_runtime_ownership.md` - documents `RuntimeRoot`,
  `DocumentStoreKernel`, `SelectionKernel`, `InteractionEngine`, `FrameEngine`,
  and their ownership boundaries, but does not name a public runtime state owner
  or distinguish view camera state from persisted document camera.
- `docs/architecture/03_data_model.md` - defines `documentRevision`,
  `resourceVisualRevision`, `frameMetaRevision`, `projectionRevision`,
  `previewRevision`, `selectionRevision`, and dispose behavior for the old
  public revision listenables.
- `docs/contracts/operation_matrix.md` - includes rows where `setCameraOffset`
  is a document/frame-meta/projection mutation, `markResourceDirty` changes only
  `resourceVisualRevision`, selection rows change only `selectionRevision`, and
  notes still refer to `documentRevisionListenable`.
- `docs/contracts/edit_kernel.md` - owns synchronous edit commit/rollback,
  public signal owners, and the post-install boundary that must publish one
  runtime state snapshot after an atomic commit.
- `docs/contracts/load_document.md` - owns replacement ordering and must publish
  one state snapshot after successful install, including epoch, document,
  selection, and preview cleanup effects.
- `docs/contracts/resources.md` - already states that `markResourceDirty`
  increments `resourceVisualRevision` without document mutation and must be
  connected to public state notification.
- `docs/contracts/interaction_engine.md` - owns pointer sessions, tools,
  preview state, terminal commit requests, and mode/tool cleanup that must map
  to public `interaction` and `preview` revisions.
- `docs/contracts/frame_rendering.md` - captures `frameMetaRevision`,
  `selectionRevision`, `resourceVisualRevision`, and `cameraOffset` for frames;
  camera capture must move to runtime view camera semantics without making
  ordinary paint-plan keys depend on view camera.
- `docs/contracts/cache_policy.md` - defines `StaticBackgroundCache` with
  background/grid/camera bucket and `frameMetaRevision`, and `PreviewStateSnapshot`
  keyed by `previewRevision`; cache wording must no longer imply that camera pan
  is a document mutation.
- `docs/implementation/p2_public_api_v1_freeze.md`,
  `docs/implementation/p4_runtime_spine.md`,
  `docs/implementation/p6_load_document.md`,
  `docs/implementation/p7_resources_and_images.md`,
  `docs/implementation/p9_frame_rendering_and_caches.md`,
  `docs/implementation/p10_selection_and_move.md`,
  `docs/implementation/p11_draw_tools.md`,
  `docs/implementation/p13_flutter_surface.md`, and
  `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md` -
  phase contracts that mention public API freeze, runtime revision lifecycle,
  load publication, resource dirty, frame cache behavior, selection-only
  updates, tool/preview behavior, surface listener cleanup, and release proof.
- `docs/verification/tests.md` - currently describes
  `test/runtime/dispose_lifecycle_test.dart` in terms of two old public revision
  listenables and describes future selection/frame tests that must also prove
  public state behavior.
- `docs/verification/guardrails.md`,
  `docs/verification/functional_ledger.md`, and
  `docs/verification/release_gates.md` - own future guardrail, functional, and
  release proof descriptions for public exports/signatures and runtime-visible
  state effects.
- `docs/diagrams/dfd_public_edit.mmd`, `docs/diagrams/seq_edit_success.mmd`,
  `docs/diagrams/seq_load_document_success.mmd`,
  `docs/diagrams/seq_load_document_failure.mmd`,
  `docs/diagrams/seq_dispose_during_gesture.mmd`, and
  `docs/diagrams/state_runtime_lifecycle.mmd` - directly mention public
  document/revision listeners, preview revision listener notification, or old
  revision-listenable disposal semantics.
- `docs/diagrams/dfd_cache_invalidation.mmd`,
  `docs/diagrams/dfd_main_paint_frame.mmd`,
  `docs/diagrams/seq_main_paint.mmd`,
  `docs/diagrams/dfd_overlay_frame.mmd`, and
  `docs/diagrams/seq_overlay_paint.mmd` - capture camera, frame-meta,
  preview, selection, and resource revision facts that must be aligned with
  public runtime state and view camera ownership.
- `docs/diagrams/dfd_resource_resolution.mmd`,
  `docs/diagrams/seq_resource_resolution.mmd`,
  `docs/diagrams/state_resource_resolution.mmd`,
  `docs/diagrams/dfd_pointer_preview_commit.mmd`, interaction sequence
  diagrams, and interaction state diagrams - describe resource dirty,
  preview/tool/selection transitions, and public signals that must map to the
  new state snapshot publication model.
- `docs/diagrams/README.md`, `docs/_registry/sections.yaml`, and
  `docs/indexes/**` - contain diagram, section, guardrail, and test mappings
  that must remain consistent after normative docs change.
- Root `lib/**`, `test/**`, and `tool/guardrails/**` - do not exist yet in the
  target package, so this step cannot and must not implement executable
  production, test, or guardrail code.
- `docs/tool/generate_context_capsules.dart` - is the executable
  registry-to-context-capsule consistency check required by the docs workflow.
- `docs/tool/check_docs.dart` - is the executable documentation consistency
  check for entrypoints, registries, ids, paths, diagram catalog membership, and
  phase navigation.

### Current Entry Path

- Roadmap entry: `PLAN.md` links to root `plan/**` Change Contracts.
- Documentation entry: `docs/README.md` routes architecture, contract,
  implementation, diagram, verification, registry, and index updates.
- Design-backlog entry: `redesign.md` contains the public-state and camera
  ownership proposals that must move into normative documentation before API
  freeze, then be removed in the step cleanup slice after proof passes.
- Future public runtime entry: `CanvasRuntime` in
  `docs/contracts/public_api_v1.md` exposes runtime ports and is the correct
  public owner for one state listenable.
- Future public camera entry: `CanvasCameraPort` is the public boundary for
  runtime view camera operations.
- Future persisted camera entry: `CanvasEdit.setCameraOffset` is the document
  edit boundary for persisted document camera changes.

### Current Owner

- `CanvasRuntime` currently owns public runtime access but exposes incomplete
  public revision listenables.
- `RuntimeRoot` is the composition root that can assemble document, selection,
  preview, resource, interaction, camera, and epoch facts into one public state.
- `DocumentStoreKernel` owns committed document content, persisted document
  camera, document revision, resource descriptors, and projection cache.
- `SelectionKernel` owns selected ids and `selectionRevision`.
- `InteractionEngine` owns pointer sessions, tools, interaction settings, and
  preview state.
- `ResourceKernel` owns resolver boundary, image resolve cache policy, dirty
  resource ids, and visual resource invalidation.
- `FrameEngine` owns frame capture, repaint buses, ordinary paint plans, and
  style/camera capture for painting.
- Future verification descriptions are owned by `docs/verification/**`,
  registries, and indexes.

### Adjacent Abstractions

- `CanvasDocument` remains the public immutable persisted document projection;
  it must not include transient runtime view camera.
- `CanvasRuntimeSummary` is the new runtime-count summary and may include
  selected count because selection is runtime state.
- `CanvasDocumentSummary` remains document-named and must not become a second
  runtime summary.
- `CanvasRuntimeRevisions` is a public coarse-grained revision summary, not the
  full internal revision state used for caches and frame correctness.
- `frameMetaRevision` remains an internal frame/cache revision family unless a
  later step splits it more broadly; this step does not expose it as public API.
- `PaintPlanCache` remains keyed by committed element facts and must not include
  view camera, preview, or selection-only state.
- `StaticBackgroundCache` may still use camera bucket and frame-meta facts for
  bounded frame work, but camera pan must not be described as document mutation.

### Existing Tests

- No target root `test/**` implementation exists yet.
- `docs/verification/tests.md` is the existing source of truth for future test
  inventory and must update future runtime state, dispose, selection,
  resource-dirty, interaction, and camera ownership proof descriptions.
- `docs/verification/guardrails.md` is the existing source of truth for future
  guardrail behavior and must keep public export/signature/equality guardrails
  aligned with the new state API.
- `docs/tool/generate_context_capsules.dart --check` and
  `docs/tool/check_docs.dart` are the executable documentation consistency
  checks for this step.

### Analogous Implementation Path

- `plan/step_5_selection_runtime_ownership_documentation.md` is the closest
  precedent for moving redesign decisions into normative documentation,
  updating registries and diagrams, and explicitly excluding production/test
  implementation.
- `docs/architecture/03_data_model.md` is the precedent for owning internal
  revision semantics and public dispose lifecycle in one data-model section.
- `docs/contracts/operation_matrix.md` is the precedent for tying every public
  operation to revision, projection, repaint, spatial, resource, and event
  effects.
- `docs/contracts/cache_policy.md` is the precedent for keeping public/runtime
  state out of ordinary committed paint-plan keys when it does not alter
  ordinary element records.

### Governing Repository Rules

- Documentation is written in English.
- Repository-specific source-of-truth knowledge must be updated in repository
  docs, not left only in chat.
- Prefer repository-local enforcement through future tests, guardrails, CI
  checks, or tooling rather than repeated prose reminders.
- Documentation-only changes do not require `dart analyze`, `dcm analyze .`, or
  `dcm calculate-metrics .`.
- `PLAN.md` is the active roadmap and source of truth for planned work.
- When adding a new `PLAN.md` step, use the `change-contract` template as the
  canonical step-contract structure.
- `docs/architecture/00_architecture_overview.md` states this repository is the
  new architecture rebuild; legacy code is only a functional oracle, not the
  target runtime shape.

### Rejected Misleading Local Patterns

- Keeping two public revision listenables and adding more separate listenables -
  rejected because it multiplies public subscription surfaces and can still
  leave summary reads inconsistent with revision reads.
- Publishing only `CanvasRuntimeRevisions` while leaving `summary` as a separate
  getter - rejected because applications can observe revisions and counts from
  different runtime moments.
- Keeping revision and epoch fields inside `CanvasRuntimeSummary` - rejected
  because it duplicates `CanvasRuntimeRevisions` and creates a second public
  source for the same facts.
- Leaving `selectedCount` inside a document-named summary - rejected because
  selection is runtime state, not persisted document content.
- Treating `CanvasCameraPort.setOffset` or `panBy` as document edits - rejected
  because viewport navigation should not dirty document state, invalidate public
  document projection, or imply save/undo work.
- Adding sync glue that keeps runtime view camera and persisted document camera
  continuously synchronized - rejected because view camera and persisted camera
  are intentionally separate states with explicit write boundaries.
- Adding `CanvasCameraPort.persistCurrentOffset` in this step - rejected because
  `CanvasEdit.setCameraOffset` is already the document mutation boundary and
  keeps persisted-camera writes owned by edit/document semantics. A convenience
  method can be reconsidered later only if it proves real repeated caller
  friction without hiding document mutation.
- Exposing internal `structuralRevision`, `boundsRevision`,
  `elementVisualRevision`, `frameMetaRevision`, or `projectionRevision` in the
  public state snapshot - rejected because those are internal cache/projection
  facts, not stable application-observation domains.
- Folding full `frameMetaRevision` decomposition into this step - rejected
  because background/grid/surface-style cache decomposition is a performance
  refinement beyond the public state and camera ownership decision.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- The public observation problem is owned by `CanvasRuntime` and `RuntimeRoot`,
  because only the runtime root can publish one coherent state after document,
  selection, preview, resource, interaction, camera, and epoch changes.
- The camera ownership problem is split between `CanvasCameraPort` for runtime
  view camera and `CanvasEdit`/`DocumentStoreKernel` for persisted document
  camera.

#### Selected Architectural Form

- Public runtime observation is one immutable snapshot:
  `ValueListenable<CanvasRuntimeState> get state`.
- `CanvasRuntimeState` contains `CanvasRuntimeRevisions revisions` and
  `CanvasRuntimeSummary summary`.
- `CanvasRuntimeRevisions` exposes only application-relevant public revision
  domains: document, selection, preview, view camera, resource visual,
  interaction, and epoch.
- `CanvasRuntimeSummary` exposes current runtime counts and does not duplicate
  revisions or epoch.
- `CanvasDocumentSummary` remains document-scoped and is not used as the public
  runtime summary.
- Runtime view camera is transient runtime state. Persisted document camera is
  document content and schema content.

#### Owning Layer or Module

- Public API declaration and exported type ownership: `docs/contracts/public_api_v1.md`
  and `docs/_registry/public_api_v1.yaml`.
- Runtime state and revision semantics: `docs/architecture/03_data_model.md`.
- Runtime and camera ownership boundaries:
  `docs/architecture/01_runtime_ownership.md`.
- Public operation effects: `docs/contracts/operation_matrix.md`.
- Edit-owned persisted camera mutation: `docs/contracts/edit_kernel.md` and
  the public edit API section in `docs/contracts/public_api_v1.md`.
- View camera capture and repaint behavior:
  `docs/contracts/frame_rendering.md` and `docs/contracts/cache_policy.md`.

#### Architectural Dependency / Import Direction

- Public API may depend on `package:flutter/foundation.dart` for
  `ValueListenable` and on Flutter/dart UI types already allowed by the public
  API contract.
- Runtime-root publication may read committed document summary facts,
  selection facts, preview facts, resource visual revision, interaction facts,
  and view camera facts through owning boundaries; those owners must not depend
  on public DTO materialization or Flutter widget state to publish core state.
- `CanvasSurface` may observe `CanvasRuntime.state` but must not own or mutate
  the public state snapshot.
- `FrameEngine` may capture view camera and revisions for painting, but
  ordinary paint plans must remain independent of view camera, preview, and
  selection-only state.
- `CanvasCameraPort` may mutate runtime view camera and schedule repaint, but
  persisted document camera mutation remains through the edit/document boundary.

#### State and Data Ownership

- `RuntimeRoot` owns the public `ValueListenable<CanvasRuntimeState>` handle and
  publishes new immutable state snapshots after accepted runtime changes.
- `DocumentStoreKernel` owns persisted document camera and document revisions.
- Runtime view camera is runtime state, not `CanvasDocument` projection state.
- `SelectionKernel` owns selected ids and `selectionRevision`; selected count in
  `CanvasRuntimeSummary` is derived from the selection owner.
- `InteractionEngine` owns interaction settings and preview state; public
  `interaction` revision covers mode, draw style, pointer policy, and other
  public interaction setting changes that are not preview snapshots.
- `ResourceKernel` owns resource visual invalidation and contributes
  `resourceVisual` to public revisions.
- Internal cache revisions remain internal unless explicitly listed in
  `CanvasRuntimeRevisions`.

#### Entry and Exit Boundaries

- Entry boundary for public observation: application reads `runtime.state.value`
  or registers a listener on `runtime.state`.
- Exit boundary for public state changes: runtime publishes one new
  `CanvasRuntimeState` after each accepted runtime state change and after
  atomic commit/install operations complete.
- Selection-only, preview-only, resource-dirty, interaction-setting, and
  view-camera changes publish state without incrementing document revision.
- No-op operations do not publish a new state snapshot.
- `dispose` leaves `state.value` readable, allows `removeListener`, and does not
  deliver notifications after dispose returns. The first dispose call may
  publish one final state before returning only when dispose clears active
  preview state.
- `readDocument` returns the persisted document camera, not the current runtime
  view camera.
- `loadDocument` initializes runtime view camera from the persisted document
  camera and publishes one state snapshot after successful install.

#### Permitted Extension Seam

- Future public revisions may be added to `CanvasRuntimeRevisions` only when a
  new public runtime observation domain is intentionally accepted before API
  freeze or versioned after freeze.
- Future internal cache revision splits, including background/grid/surface-style
  decomposition, must stay internal unless an application-observation use case
  justifies a public revision domain.
- A future convenience API for persisting the current view camera may be added
  only if it delegates through the edit boundary and is documented as document
  mutation.

#### Rejected Alternatives

- Separate public listenables per revision domain.
- `ValueListenable<CanvasRuntimeRevisions>` plus a separate summary getter.
- One public integer revision for all runtime changes.
- Exposing all internal cache/projection revisions publicly.
- Treating camera pan as a persisted document edit.
- Continuously synchronizing view camera into the persisted document camera.

#### Why This Level Is Correct

- Applications need one coherent signal for runtime-visible changes, but they
  do not need internal cache invalidation topology.
- The runtime root is the only owner that can publish a single atomic state
  after cross-owner effects such as document replacement plus selection clear
  plus preview cleanup.
- Keeping view camera out of document mutation prevents ordinary viewport
  navigation from dirtying saved document state, invalidating public document
  projection, or implying undo/redo work.
- Keeping persisted camera writes on the edit boundary preserves one owner for
  document mutations and avoids hidden sync behavior.

#### Verification Strategy

- Public API proof must compile against the new state surface and exported
  public types.
- Future runtime tests must prove state-listenable publication for document,
  selection-only, preview-only, resource-dirty, interaction-setting, view-camera,
  and load-success changes.
- Future dispose tests must prove `state.value` remains readable after dispose,
  dispose does not publish document revision changes, and no notifications occur
  after dispose returns.
- Future camera tests must prove `setOffset` and `panBy` publish view camera
  revision without document revision or projection invalidation, while
  `CanvasEdit.setCameraOffset` changes persisted document camera through the
  document edit path.
- Documentation consistency for this step is proven by
  `dart run docs/tool/generate_context_capsules.dart --check` and
  `dart run docs/tool/check_docs.dart`.

## 5. Locked Decisions

- The public runtime observation API is `CanvasRuntime.state`, not
  `CanvasRuntime.revisions`.
- `CanvasRuntimeState`, `CanvasRuntimeRevisions`, and `CanvasRuntimeSummary`
  are public exported API types.
- `CanvasRuntimeState`, `CanvasRuntimeRevisions`, and `CanvasRuntimeSummary`
  use value equality and immutable public fields.
- `CanvasRuntimeSummary` contains runtime counts only and does not contain
  revision or epoch fields.
- `CanvasDocumentSummary` is not the public runtime summary and must not contain
  runtime selection facts after this step.
- Public `CanvasRuntimeRevisions` contains `viewCamera`, not generic `camera`.
- Public `CanvasRuntimeRevisions` contains `interaction`, not `tools`, because
  the revision covers public mode, tool, draw style, pointer policy, and
  interaction-setting changes.
- `CanvasCameraPort.setOffset` and `CanvasCameraPort.panBy` mutate runtime view
  camera only.
- `CanvasEdit.setCameraOffset` remains the persisted document camera mutation
  path.
- Full `frameMetaRevision` decomposition is deferred.

## 6. Result Requirements

- Application code can subscribe to exactly one runtime state listenable and
  observe every runtime-visible change that v1 exposes.
- State snapshots are internally coherent: summary and revisions describe the
  same runtime moment.
- Selection-only changes update public state without changing document revision
  or document projection.
- Preview-only changes update public state without changing document revision.
- Resource dirty changes update public state through resource visual revision
  without changing document revision.
- Interaction setting changes update public state through interaction revision
  without changing document revision.
- Runtime view camera changes update public state through view camera revision
  without changing document revision or document projection.
- Persisted camera changes remain document edits and are visible through
  `readDocument`.
- Dispose semantics are expressed in terms of the single public state listenable.
- Diagrams, registries, indexes, verification inventories, and phase docs no
  longer describe the retired separate public revision listenables.

## 7. Execution Order and Gates

### Required Order

1. Update public API shape and exported-name registry before changing subsystem
   contracts that depend on the new type names.
2. Update runtime data model and ownership docs before operation matrix rows.
3. Update operation matrix and subsystem contracts before phase and verification
   docs.
4. Update diagrams after the normative text they visualize is stable.
5. Update generated or derived indexes and context coverage after registry,
   diagram, and verification references are final.
6. Run documentation consistency checks only after all planned documentation
   edits for this step are complete.

### Successor Seam and Retirement Gates

- Successor seam: `CanvasRuntime.state`.
- Retired public seams: `CanvasRuntime.documentRevisionListenable`,
  `CanvasRuntime.previewRevisionListenable`, and `CanvasRuntime.summary` as a
  separate runtime summary getter.
- Retirement gate: no normative docs, diagrams, verification inventories, or
  registries refer to the retired listenables as public API.
- Backlog retirement gate: `redesign.md` no longer proposes
  `ValueListenable<CanvasRuntimeRevisions> get revisions` plus a separate
  `CanvasRuntimeSummary get summary` as an active design.
- The existing `CanvasDocumentSummary` name is not retired, but its responsibility
  is narrowed to document/draft-document facts.

### Deferred Broad Verification

- `dart analyze`, `dcm analyze .`, and `dcm calculate-metrics .` are deferred
  until implementation changes exist.
- Future implementation slices must run the repository-required checks for code
  changes from the repository root.

## 8. File Map

### Implementation Files

- No production Dart files are changed in this documentation-only step.

### Test Files

- No Dart test files are changed in this documentation-only step.

### Fixtures and Supporting Data

- No fixtures are changed in this documentation-only step.

### Registry, Inventory, and Workflow Files

- `PLAN.md` - add this roadmap entry.
- `plan/step_6_public_runtime_state_and_view_camera_ownership.md` - this
  Change Contract.
- `redesign.md` - remove or rewrite the public runtime state and view camera
  backlog proposals after normative docs are updated and proof passes.
- `audit.md` - replace operation-matrix checklist language with public runtime
  state revision-domain wording after normative docs are updated and proof
  passes.
- `docs/contracts/public_api_v1.md` - define the public state API and camera
  boundary semantics.
- `docs/_registry/public_api_v1.yaml` - add new public exported types and keep
  summary exports aligned.
- `docs/architecture/01_runtime_ownership.md` - add runtime state and view
  camera ownership.
- `docs/architecture/03_data_model.md` - update revision and dispose semantics.
- `docs/contracts/operation_matrix.md` - update public operation effects and
  state publication.
- `docs/contracts/edit_kernel.md` - update post-install public state publication
  and persisted camera ownership language.
- `docs/contracts/load_document.md` - update successful replacement state
  publication and view camera initialization.
- `docs/contracts/resources.md` - connect resource dirty to public state.
- `docs/contracts/interaction_engine.md` - connect interaction settings and
  preview cleanup to public state.
- `docs/contracts/frame_rendering.md` - align camera capture and frame-meta
  language.
- `docs/contracts/cache_policy.md` - align cache keys and invalidation wording
  with view camera ownership.
- `docs/implementation/p2_public_api_v1_freeze.md` - update public API freeze
  requirements.
- `docs/implementation/p4_runtime_spine.md` - update runtime state and dispose
  exit gate.
- `docs/implementation/p6_load_document.md` - update load publication contract.
- `docs/implementation/p7_resources_and_images.md` - update resource dirty proof.
- `docs/implementation/p9_frame_rendering_and_caches.md` - update frame/cache
  camera wording.
- `docs/implementation/p10_selection_and_move.md` - update selection-only
  public state proof.
- `docs/implementation/p11_draw_tools.md` - update tool/preview public state
  proof.
- `docs/implementation/p13_flutter_surface.md` - update surface listener cleanup
  language.
- `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md` -
  update release-readiness proof references.
- `docs/verification/tests.md` - update future test inventory.
- `docs/verification/guardrails.md` - update guardrail proof descriptions when
  public API shape references change.
- `docs/verification/functional_ledger.md` - update functional rows for runtime
  state observation.
- `docs/verification/release_gates.md` - update release gate references.
- `docs/diagrams/README.md` - keep diagram catalog entries aligned if diagram
  descriptions change.
- `docs/diagrams/dfd_public_edit.mmd`
- `docs/diagrams/seq_edit_success.mmd`
- `docs/diagrams/seq_load_document_success.mmd`
- `docs/diagrams/seq_load_document_failure.mmd`
- `docs/diagrams/seq_dispose_during_gesture.mmd`
- `docs/diagrams/state_runtime_lifecycle.mmd`
- `docs/diagrams/dfd_cache_invalidation.mmd`
- `docs/diagrams/c4_component_runtime.mmd`
- `docs/diagrams/c4_code_edit_kernel.mmd`
- `docs/diagrams/dfd_load_document_success_failure.mmd`
- `docs/diagrams/dfd_resource_resolution.mmd`
- `docs/diagrams/seq_resource_resolution.mmd`
- `docs/diagrams/state_resource_resolution.mmd`
- `docs/diagrams/dfd_main_paint_frame.mmd`
- `docs/diagrams/seq_main_paint.mmd`
- `docs/diagrams/dfd_overlay_frame.mmd`
- `docs/diagrams/seq_overlay_paint.mmd`
- `docs/diagrams/dfd_pointer_preview_commit.mmd`
- `docs/diagrams/seq_selected_move_preview_commit.mmd`
- `docs/diagrams/seq_selected_move_cancel.mmd`
- `docs/diagrams/seq_marquee_select.mmd`
- `docs/diagrams/seq_pencil_marker_commit.mmd`
- `docs/diagrams/seq_line_two_tap_commit.mmd`
- `docs/diagrams/seq_eraser_commit.mmd`
- `docs/diagrams/seq_eraser_exact_budget.mmd`
- `docs/diagrams/seq_text_edit_request.mmd`
- `docs/diagrams/state_pointer_session.mmd`
- `docs/diagrams/state_selected_move.mmd`
- `docs/diagrams/state_select_marquee.mmd`
- `docs/diagrams/state_pencil_marker_draw.mmd`
- `docs/diagrams/state_two_tap_line.mmd`
- `docs/diagrams/state_eraser.mmd`
- `docs/diagrams/state_pending_text_edit_request.mmd`
- `docs/_registry/sections.yaml` - update section-to-test/guardrail/diagram
  mappings if references change.
- `docs/indexes/by_test_area.md`, `docs/indexes/by_guardrail.md`,
  `docs/indexes/context_coverage.md`, and `docs/indexes/donor_to_phase.md` -
  refresh if registry or phase metadata changes.

## 9. Implementation Rules

### Protected Invariants

- Runtime state publication must be atomic from the public API perspective.
- Public state snapshots must not require `CanvasDocument` projection
  materialization.
- Selection state remains outside persisted document state.
- Runtime view camera changes must not dirty document state.
- Persisted document camera changes must go through the document edit boundary.
- Internal cache/projection revisions must not leak into public API merely
  because they participate in rendering or invalidation.
- Ordinary committed paint plans must not become keyed by selection,
  preview-only, interaction-only, or view-camera state.
- Dispose must leave the public state value readable and must not publish after
  dispose returns.

### Required Proof

- `dart run docs/tool/generate_context_capsules.dart --check`
- `dart run docs/tool/check_docs.dart`
- Slice-local semantic proof commands must run in addition to documentation
  navigation checks. They may be written as `bash -lc`/`rg` assertions or, if
  the command becomes hard to maintain, as a small repository documentation
  check owned by this step and named in the slice closure evidence.
- Semantic proof commands must check both positive forms and retired-form
  absence in the normative files owned by the slice; do not rely on
  `docs/tool/check_docs.dart` for free-form Markdown wording.
- Future implementation proof descriptions in `docs/verification/tests.md` must
  cover public state publication for document, selection, preview, resource
  dirty, interaction, view camera, load success, no-op, and dispose behavior.
- Future public API guardrail descriptions must cover exported state types,
  equality policy, and retired listener signatures.

### Allowed Change Surface

- Documentation, diagrams, registries, indexes, and plan files listed in this
  contract.
- Wording updates required to keep existing section ownership and generated
  indexes consistent with the new public state and camera ownership model.

### Forbidden Moves

- Do not implement production runtime, notifier, camera, frame, interaction, or
  resource code in this step.
- Do not add public compatibility aliases for retired listenables.
- Do not expose internal cache revisions as public state fields.
- Do not make `CanvasCameraPort` mutate persisted document camera.
- Do not add hidden synchronization between runtime view camera and persisted
  document camera.
- Do not include full `frameMetaRevision` decomposition unless required only to
  remove contradictions created by view camera ownership.
- Do not leave `redesign.md` as a second source of truth for decisions moved
  into normative docs.

## 10. Vertical Slices

### Slice 1. [ ] Public Runtime State API Contract

#### Slice Contract

The public API contract and export registry define one runtime state listenable
and remove the old separate public revision listener model.

#### Change

- Update `docs/contracts/public_api_v1.md` to define
  `CanvasRuntime.state`, `CanvasRuntimeState`, `CanvasRuntimeRevisions`, and
  `CanvasRuntimeSummary`.
- Update equality policy for the new immutable public state types.
- Remove `documentRevisionListenable` and `previewRevisionListenable` from the
  public runtime contract.
- Narrow `CanvasDocumentSummary` to document/draft-document facts and remove
  runtime selection/listener facts from that type.
- Update `docs/_registry/public_api_v1.yaml` with the new exported public names.
- Update `docs/implementation/p2_public_api_v1_freeze.md`,
  `docs/verification/guardrails.md`, and `docs/verification/release_gates.md`
  where public export/signature proof references the old shape.

#### Behavioral Verification

- `bash -lc 'rg -n "ValueListenable<CanvasRuntimeState> get state|final class CanvasRuntimeState|final class CanvasRuntimeRevisions|final class CanvasRuntimeSummary" docs/contracts/public_api_v1.md && rg -n "CanvasRuntimeState|CanvasRuntimeRevisions|CanvasRuntimeSummary" docs/_registry/public_api_v1.yaml'`
- `bash -lc '! rg -n "ValueListenable<int> get documentRevisionListenable|ValueListenable<int> get previewRevisionListenable|ValueListenable<CanvasRuntimeRevisions> get revisions|CanvasRuntimeSummary get summary" docs/contracts/public_api_v1.md docs/_registry/public_api_v1.yaml'`
- `bash -lc '! awk "/final class CanvasRuntimeSummary /,/^}/ { print }" docs/contracts/public_api_v1.md | rg -n "final int (documentRevision|selectionRevision|epoch);|required this\\.(documentRevision|selectionRevision|epoch)"'`

#### Structural Verification

- `dart run docs/tool/generate_context_capsules.dart --check`
- `dart run docs/tool/check_docs.dart`

#### Fixtures Used

- None.

#### Positive Scenarios

- Application code has one public listenable for runtime-visible state.
- Summary and revisions are read from the same public state snapshot.

#### Negative Scenarios

- No public API contract continues to expose the two retired revision
  listenables.
- `CanvasRuntimeSummary` does not duplicate revision or epoch fields.

#### Closure Evidence

- Public API contract, public export registry, guardrail descriptions, release
  gate descriptions, and documentation checks are updated together.

### Slice 2. [ ] Runtime State Semantics and Dispose Lifecycle

#### Slice Contract

Runtime data-model docs, operation matrix, lifecycle diagrams, and future tests
describe one atomic public state publication model for all runtime-visible
changes.

#### Change

- Update `docs/architecture/03_data_model.md` with public state publication,
  revision-domain definitions, no-op behavior, and dispose behavior.
- Update `docs/contracts/operation_matrix.md` so selection-only, preview-only,
  resource-dirty, interaction-setting, load, dispose, and document edit rows
  state their public `CanvasRuntimeState` effects.
- Update `docs/contracts/edit_kernel.md` and `docs/contracts/load_document.md`
  so post-commit/install publication is one state snapshot after atomic success.
- Update `docs/contracts/resources.md` and
  `docs/contracts/interaction_engine.md` so resource dirty and interaction
  changes publish the correct public revisions.
- Update `docs/implementation/p4_runtime_spine.md`,
  `docs/implementation/p6_load_document.md`,
  `docs/implementation/p7_resources_and_images.md`,
  `docs/implementation/p10_selection_and_move.md`,
  `docs/implementation/p11_draw_tools.md`, and
  `docs/implementation/p13_flutter_surface.md` where they describe runtime
  revision lifecycle, listener cleanup, or proof obligations.
- Update `docs/verification/tests.md` and
  `docs/verification/functional_ledger.md` to name future proof for public
  state notification domains.
- Update lifecycle, edit, load, resource, pointer, and interaction diagrams that
  describe public signals or old revision listenables.

#### Behavioral Verification

- `bash -lc 'rg -n "CanvasRuntimeState|state\\.revisions|public state|state listenable" docs/architecture/03_data_model.md docs/contracts/operation_matrix.md docs/contracts/edit_kernel.md docs/contracts/load_document.md docs/contracts/resources.md docs/contracts/interaction_engine.md docs/verification/tests.md docs/verification/functional_ledger.md'`
- `bash -lc '! rg -n "documentRevisionListenable|previewRevisionListenable|document/revision listeners|preview revision listener|revision listenables" docs/architecture/03_data_model.md docs/contracts/operation_matrix.md docs/contracts/edit_kernel.md docs/contracts/load_document.md docs/contracts/resources.md docs/contracts/interaction_engine.md docs/implementation docs/verification docs/diagrams'`
- `bash -lc 'rg -n "selection.*state|preview.*state|resourceVisual|interaction|dispose.*state\\.value|no notifications.*after dispose" docs/architecture/03_data_model.md docs/contracts/operation_matrix.md docs/verification/tests.md'`

#### Structural Verification

- `dart run docs/tool/generate_context_capsules.dart --check`
- `dart run docs/tool/check_docs.dart`

#### Fixtures Used

- None.

#### Positive Scenarios

- Selection-only, preview-only, resource-dirty, interaction-setting, and
  load-success operations each have documented public state publication.
- Dispose leaves `state.value` readable and does not notify after dispose
  returns.

#### Negative Scenarios

- No operation matrix note refers to `documentRevisionListenable` as public API.
- No diagram shows `previewRevisionListenable` or `documentRevisionListenable`
  as the publication seam.

#### Closure Evidence

- Runtime data model, operation matrix, subsystem contracts, verification docs,
  phase docs, diagrams, and documentation checks agree on one state-listenable
  publication model.

### Slice 3. [ ] View Camera and Persisted Camera Ownership

#### Slice Contract

The architecture and contracts distinguish runtime view camera from persisted
document camera without pulling the full frame-meta split into this step.

#### Change

- Update `docs/architecture/01_runtime_ownership.md` and
  `docs/architecture/03_data_model.md` to state that runtime view camera is
  runtime state and persisted document camera is document state.
- Update `docs/contracts/public_api_v1.md` so `CanvasCameraPort.setOffset` and
  `panBy` mutate runtime view camera only, while `CanvasEdit.setCameraOffset`
  remains the persisted document camera mutation path.
- Update `docs/contracts/operation_matrix.md` so camera port rows update
  `viewCamera` without document revision or projection invalidation, and edit
  camera rows update persisted document camera through document revision and
  projection effects.
- Update `docs/contracts/frame_rendering.md` and
  `docs/contracts/cache_policy.md` so frame capture uses runtime view camera
  while ordinary paint-plan cache keys remain committed-element based.
- Update `docs/implementation/p9_frame_rendering_and_caches.md` and affected
  paint/frame diagrams to stop describing viewport pan as document/frame-meta
  document mutation.
- Update `audit.md` after camera ownership docs and matrix rows pass proof so
  it no longer assumes camera must always be expressed through
  `frameMetaRevision`.

#### Behavioral Verification

- `bash -lc 'rg -n "runtime view camera|viewCamera|persisted document camera|CanvasCameraPort|CanvasEdit\\.setCameraOffset" docs/architecture/01_runtime_ownership.md docs/architecture/03_data_model.md docs/contracts/public_api_v1.md docs/contracts/operation_matrix.md docs/contracts/frame_rendering.md docs/contracts/cache_policy.md docs/implementation/p9_frame_rendering_and_caches.md audit.md'`
- `bash -lc '! rg -n "setCameraOffset \\| meta \\| document, frameMeta, projection|setOffset.*documentRevision|panBy.*documentRevision|pan.*document mutation|view camera.*projection eviction" docs/contracts/operation_matrix.md docs/contracts/public_api_v1.md docs/architecture/03_data_model.md docs/contracts/frame_rendering.md docs/contracts/cache_policy.md docs/diagrams'`
- `bash -lc 'rg -n "PaintPlanCache key must not include|ordinary paint-plan|ordinary committed paint" docs/contracts/frame_rendering.md docs/contracts/cache_policy.md docs/implementation/p9_frame_rendering_and_caches.md'`

#### Structural Verification

- `dart run docs/tool/generate_context_capsules.dart --check`
- `dart run docs/tool/check_docs.dart`

#### Fixtures Used

- None.

#### Positive Scenarios

- Runtime camera pan has public `viewCamera` state effects and repaint effects.
- Persisted camera changes remain document edits and are visible in
  `CanvasDocument`.

#### Negative Scenarios

- Camera pan does not document a document revision, projection eviction, or
  persisted document camera change.
- This slice does not require a full background/grid/surface-style revision
  split.

#### Closure Evidence

- Public API, data model, operation matrix, frame/cache contracts, phase docs,
  diagrams, audit checklist, and documentation checks agree on camera ownership.

### Slice 4. [ ] Registry, Index, and Backlog Cleanup

#### Slice Contract

The new normative decisions are reflected in registries and indexes, and the
redesign/audit backlog is cleaned only after the earlier normative-documentation
slices have passed their slice-local proof.

#### Change

- Remove or rewrite the accepted public runtime state and view camera proposals
  from `redesign.md`.
- Update `audit.md` so HOLE-002 no longer carries the accepted camera/listener
  backlog rows and instead points to public runtime state effects.
- Update `docs/diagrams/README.md` where affected diagram descriptions change.
- Update `docs/_registry/sections.yaml` for changed test, guardrail, diagram,
  and section references.
- Refresh `docs/indexes/by_test_area.md`, `docs/indexes/by_guardrail.md`,
  `docs/indexes/context_coverage.md`, and `docs/indexes/donor_to_phase.md` if
  their source registry or phase metadata changes.
- Update `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md`
  after final proof references are stable.

#### Behavioral Verification

- `bash -lc '! rg -n "ValueListenable<CanvasRuntimeRevisions> get revisions|CanvasRuntimeSummary get summary|documentRevisionListenable|previewRevisionListenable" redesign.md audit.md docs/_registry docs/indexes docs/diagrams/README.md docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md'`
- `bash -lc '! rg -n "Добавить строки или явные alias-строки для .*(setOffset|panBy)|Для каждой строки указать .*(documentRevision|previewRevision|frameMetaRevision)" audit.md'`
- `bash -lc 'rg -n "CanvasRuntime.state|CanvasRuntimeState|view camera|persisted document camera|public runtime state" docs/_registry docs/indexes docs/diagrams/README.md docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md audit.md'`

#### Structural Verification

- `dart run docs/tool/generate_context_capsules.dart --check`
- `dart run docs/tool/check_docs.dart`

#### Fixtures Used

- None.

#### Positive Scenarios

- Navigation from docs, registry, indexes, and diagram catalog reaches the new
  state/camera contracts consistently.
- `redesign.md` no longer contains accepted decisions as active proposals.

#### Negative Scenarios

- No generated index points to retired listener terminology as an active public
  API contract.
- No registry entry references a diagram or test description that still depends
  on old public listener names.

#### Closure Evidence

- Backlog cleanup, registry/index updates, phase docs, and documentation checks
  are complete.

## 11. Final Verification

- `dart run docs/tool/generate_context_capsules.dart --check`
- `dart run docs/tool/check_docs.dart`
- Do not run `dart analyze`, `dcm analyze .`, or `dcm calculate-metrics .` for
  this documentation-only step.

## 12. Acceptance Criteria

- `PLAN.md` links this step and this step contract exists under `plan/**`.
- `docs/contracts/public_api_v1.md` defines one public runtime state listenable
  and no longer exposes the retired revision listenables.
- `docs/_registry/public_api_v1.yaml` lists the new public state types.
- Runtime state revision domains are documented and do not expose internal cache
  or projection revision facts.
- Runtime summary and document summary responsibilities are separated.
- Runtime view camera and persisted document camera ownership are documented
  consistently across public API, architecture, operation matrix, frame/cache
  contracts, and diagrams.
- Future verification inventories require executable proof for state-listenable
  publication and view/persisted camera separation.
- `redesign.md` and `audit.md` do not retain stale active backlog wording for
  accepted decisions.
- Registry, index, and diagram catalog references remain consistent.
- Final documentation consistency commands pass.
