---
date: 2026-08-07
researcher: agent
commit: 121d2d54
branch: new-docs-and-skills
research_question: "Which existing iwb_canvas_engine documents contain durable architectural decisions that could later be synthesized into ADRs, and how do those historical decisions compare with current authoritative documentation, code, and tests?"
---

# Research: Architecture Decision Candidate Inventory

## Summary

Current package behavior is owned by the normative architecture and contract
documents, not by historical research, designs, or plans
(`docs/README.md:25`, `docs/README.md:38`, `AGENTS.md:32`). The registries record
machine-readable membership and relationships without replacing the semantic
owners (`docs/architecture/README.md:29`, `docs/_registry/public_api_v1.yaml:1`).
This inventory therefore treats history as evidence of context, considered
alternatives, selected forms, consequences, and later supersession; it uses
current docs first when deciding whether a historical decision still describes
the maintained package.

The sources form 14 architectural decision groups. Most historical selected
forms are represented in current architecture or contracts and have matching
production or executable-proof surfaces. Recorded stale forms are concentrated
in four areas: phase-aware and legacy-package terminology retired by the
maintained-package cleanup, the pre-session resource-cache snapshot, the early
app-owned text-edit snapshot, and the first flat one-report-key Flutter
performance route. The current owners and later historical designs replace
those forms with no-phase graph closure, `SurfaceResourceSession`, a
runtime-owned text-edit session boundary, and phase/repeat performance
artifacts, respectively.

This document inventories source groups only. It does not create an ADR,
assign an ADR identifier, define an ADR registry or lifecycle, or order the
groups by priority.

## Authority Used for Current-State Evaluation

- `docs/README.md:25` identifies architecture and contracts as normative
  sources; `docs/README.md:30` identifies `_registry` as structured relationship
  data.
- `docs/architecture/README.md:31` separates target-system shape, subsystem
  behavior, verification, and registry metadata.
- `docs/architecture/architecture_graph.yaml:30` owns structured required nodes
  and edges, and its source coverage begins at
  `docs/architecture/architecture_graph.yaml:1322`.
- `docs/planning/README.md:69` states that planning artifacts do not own current
  package behavior. There are no direct-child files in
  `docs/planning/designs/` or `docs/planning/plans/` in the inspected tree.
- `docs/history/designs/`, `docs/history/plans/`, and
  `docs/history/research/` are historical evidence from creation
  (`AGENTS.md:32`).

## Detailed Findings

### 1. Maintained Package, Public API, and Acyclic Runtime Ownership

- **Source group**: the contracts-layer selection and rejected cycle-exception
  alternatives are recorded in
  `docs/history/designs/2026-05-27-acyclic-runtime-public-api-architecture.md:307`
  and the selected form at
  `docs/history/designs/2026-05-27-acyclic-runtime-public-api-architecture.md:370`.
  The public-only example boundary is recorded in
  `docs/history/designs/2026-06-03-legacy-example-full-parity-port.md:379`.
  The later maintained-package cleanup and its replacement-before-deletion rule
  are recorded in
  `docs/history/designs/2026-06-08-legacy-phase-cleanup.md:485`.
- **Architectural topic**: one maintained package, one public barrel, one
  runtime root, and a directed internal owner graph without public/runtime
  cycles or a shipped fallback runtime.
- **Recorded decision**: stable public declarations live below a dependency-low
  public contracts layer; internal cross-owner seams live below an internal
  contracts layer; `api/**` remains the facade; application adapters and example
  UI remain external public consumers. Legacy, donor, phase, and compatibility
  package surfaces are removed only after current owners contain their retained
  facts (`docs/history/designs/2026-05-27-acyclic-runtime-public-api-architecture.md:372`,
  `docs/history/designs/2026-06-08-legacy-phase-cleanup.md:531`).
- **Context, alternatives, consequences**: the acyclicity design considered
  moving runtime declarations, API-owned adapters, and cycle exceptions
  (`docs/history/designs/2026-05-27-acyclic-runtime-public-api-architecture.md:307`).
  The cleanup design considered deleting only the nested legacy directory or
  retaining a phase roadmap (`docs/history/designs/2026-06-08-legacy-phase-cleanup.md:82`).
  The selected consequence is a public-only consumer surface plus mechanically
  checked directed ownership.
- **Current authoritative owner**: package scope and the single-runtime model are
  owned by `docs/architecture/00_architecture_overview.md:30`; public/internal
  placement and imports are owned by
  `docs/architecture/02_package_boundaries.md:32`; Public API semantics are
  owned by `docs/contracts/public_api_v1.md:76`, while the exported-name
  inventory is owned by `docs/_registry/public_api_v1.yaml:1`.
- **Current implementation alignment**: the root barrel exports API facades
  (`lib/iwb_canvas_engine.dart:1`), `CanvasRuntime` constructs the runtime root
  (`lib/src/api/canvas_runtime.dart:28`), the external compile fixture permits
  only the public barrel (`test/api_contract/public_integration_compile_fixture_test.dart:11`),
  and the repository has a single-runtime-root proof
  (`test/guardrails/single_runtime_root_test.dart:6`). These surfaces match the
  current owner.
- **Duplicates, conflicts, supersession, stale sources**: the historical
  phase-aware graph wording in
  `docs/history/designs/2026-05-22-architecture-graph-closure-checker.md:147`
  predates the no-phase cleanup. The retained decision is expected-versus-actual
  graph checking; phase ownership and legacy-package routes are stale under
  `docs/history/designs/2026-06-08-legacy-phase-cleanup.md:485` and the current
  single-package owner (`AGENTS.md:3`).

### 2. Committed Data, Lazy Public Projection, Selection, and Camera Ownership

- **Source group**: the historical camera/revision research distinguishes view
  camera, persisted document camera, and frame metadata
  (`docs/history/research/2026-05-17-frame-meta-revision-split.md:51`,
  `docs/history/research/2026-05-17-frame-meta-revision-split.md:63`).
- **Architectural topic**: a compact committed store is the document truth;
  public `CanvasDocument` is a lazy projection; selection and runtime view camera
  are separate owners.
- **Recorded decision**: document camera is persisted document state; view camera
  is runtime state and does not mutate the document. Selection ids are not part
  of committed document state. The proposed further split of
  `frameMetaRevision` was recorded as deferred rather than adopted
  (`docs/history/research/2026-05-17-frame-meta-revision-split.md:88`).
- **Context, alternatives, consequences**: the research records pressure to
  invalidate background, grid, and other frame metadata independently, but does
  not select the extra revision split
  (`docs/history/research/2026-05-17-frame-meta-revision-split.md:75`). The
  retained camera split means runtime pan publishes runtime/repaint changes
  without creating a document edit.
- **Current authoritative owner**: compact committed tables and lazy projection
  are owned by `docs/architecture/03_data_model.md:36`; selection separation is
  explicit at `docs/architecture/03_data_model.md:213`; runtime and persisted
  camera ownership is explicit at `docs/architecture/03_data_model.md:128`.
- **Current implementation alignment**: committed aggregate data and the
  projection cache are distinct production owners
  (`lib/src/store/committed_document.dart:10`,
  `lib/src/store/document_projection_cache.dart:11`), and the release proof
  requires store/projection/selection separation and camera-separation tests
  (`docs/verification/release_gates.md:129`,
  `docs/verification/release_gates.md:143`). The implementation evidence matches
  the current documented split.
- **Duplicates, conflicts, supersession, stale sources**: no current owner adopts
  the deferred `frameMetaRevision` split. The historical note remains evidence
  for the camera decision and evidence that the finer revision split was not an
  accepted decision.

### 3. Edit Transactions, Sparse Store Commits, Typed Effects, and Net No-Ops

- **Source group**: transaction ownership and rejected direct-runtime/store
  forms are recorded in
  `docs/history/designs/2026-05-24-p5-edit-core.md:226`; the selected edit seam is
  at `docs/history/designs/2026-05-24-p5-edit-core.md:299`. Sparse store editing
  is selected at
  `docs/history/designs/2026-06-06-incremental-edit-store.md:183`. Store-owned
  final equality and net-no-op behavior are selected at
  `docs/history/designs/2026-06-11-net-no-op-edit-commit.md:269` and traced at
  `docs/history/designs/2026-06-11-net-no-op-edit-commit.md:349`.
- **Architectural topic**: synchronous edit sessions, atomic rollback/install,
  sparse mutation preparation, typed invalidation, event ordering, and no-op
  elimination.
- **Recorded decision**: `EditKernel` owns session lifecycle and guards;
  `DocumentStoreKernel` owns committed facts and sparse/materialized
  finalization; `CommitCompiler` receives accepted facts and derives typed
  effects. A net-compensating edit performs no install, revision change, effect,
  projection, state publication, or action publication. Forced replacement is
  a separately retained exception
  (`docs/history/designs/2026-06-11-net-no-op-edit-commit.md:351`).
- **Context, alternatives, consequences**: alternatives included direct
  `RuntimeRoot` mutation, a command journal, store-owned mutable draft, changing
  only caps, an edit-owned indexed draft, a new public fast-edit API, sparse
  journal canonicalization, and full public-projection diffing
  (`docs/history/designs/2026-05-24-p5-edit-core.md:226`,
  `docs/history/designs/2026-06-06-incremental-edit-store.md:132`,
  `docs/history/designs/2026-06-11-net-no-op-edit-commit.md:234`). The selected
  consequence preserves the public edit API while removing eager full-document
  work from ordinary edits.
- **Current authoritative owner**: edit/rollback and finalization semantics are
  owned by `docs/contracts/edit_kernel.md:42`; accepted-fact compilation and
  no-op behavior are specified at `docs/contracts/edit_kernel.md:90` and
  `docs/contracts/edit_kernel.md:214`. Cross-owner effect rows are owned by
  `docs/contracts/operation_matrix.md:36`.
- **Current implementation alignment**: rollback fixtures preserve document,
  revisions, projection count, selection, and effect batches on rejected paths
  (`test/edit/fixtures/rollback_fixture.dart:41`,
  `test/edit/fixtures/rollback_fixture.dart:104`). The release gate requires
  rollback, exact touched invalidation, operation-matrix, and no-op coverage
  (`docs/verification/release_gates.md:135`,
  `docs/verification/release_gates.md:136`). This matches the current contract.
- **Duplicates, conflicts, supersession, stale sources**: the no-op design
  refines the sparse-store design rather than replacing its ownership split. It
  explicitly retires provisional sparse/materialized revision deltas as
  accepted truth (`docs/history/designs/2026-06-11-net-no-op-edit-commit.md:389`).
  The action-event research records that action events are notifications, not
  an undo journal (`docs/history/research/2026-05-18-action-events-notification-stream.md:98`);
  older “undo/redo action stream” wording recorded in that note is stale
  historical wording, not a second current owner.

### 4. Atomic Staged Load and the Canonical Schema V1 Reader

- **Source group**: prepared interaction cleanup before install is selected in
  `docs/history/designs/2026-05-26-p6-load-document.md:217`. The canonical JSON
  load boundary and rejected DTO/runtime-facade alternatives are recorded at
  `docs/history/designs/2026-06-07-canonical-schema-v1-json-load-api.md:130`.
  The later shared canonical reader and sink split are selected at
  `docs/history/designs/2026-06-14-schema-v1-reader-consolidation.md:237` and
  traced at `docs/history/designs/2026-06-14-schema-v1-reader-consolidation.md:334`.
- **Architectural topic**: external JSON replacement, validation and decoding,
  dependency-neutral import facts, prepared store rows, interaction cleanup,
  and one atomic cross-owner install.
- **Recorded decision**: the codec owns one Schema v1 reader. Public decode uses
  a codec-local DTO-building sink; runtime load uses an isolated store sink and
  does not materialize a public `CanvasDocument` before explicit read. Runtime
  prepares validation, import, store state, and cleanup before interruption;
  successful install publishes one state, while failure changes nothing.
- **Context, alternatives, consequences**: rejected forms include decoding a
  public `CanvasDocument` and then loading it, public row/builder APIs, a
  runtime-facade load method, duplicated full readers, retained fact graphs, and
  code generation
  (`docs/history/designs/2026-06-07-canonical-schema-v1-json-load-api.md:151`,
  `docs/history/designs/2026-06-14-schema-v1-reader-consolidation.md:189`). The
  consequence is a shared traversal without making the runtime load path retain
  public DTOs or event graphs.
- **Current authoritative owner**: atomic replacement is owned by
  `docs/contracts/load_document.md:27`; version/field semantics are owned by
  `docs/contracts/schema_v1.md:31`; the shared reader boundary is owned by
  `docs/contracts/codec_boundary.md:29` and its current dual use is stated at
  `docs/contracts/codec_boundary.md:68`.
- **Current implementation alignment**: staged load preparation has immutable
  identity and single-consume proof
  (`test/edit/fixtures/staged_document_load_success_failure_fixture.dart:42`,
  `test/edit/fixtures/staged_document_load_success_failure_fixture.dart:87`),
  and codec tests cover exact version/shape and absence of runtime side effects
  (`test/codec/schema_v1/known_fields_validation_test.dart:6`,
  `test/codec/decode_encode_no_runtime_side_effects_test.dart:6`). The current
  proof surfaces match the three current owners.
- **Duplicates, conflicts, supersession, stale sources**: the 2026-06-14 design
  retires duplicate decoder readers and element dispatch
  (`docs/history/designs/2026-06-14-schema-v1-reader-consolidation.md:312`). The
  earlier research accurately records that two read paths existed but its
  duplicated-traversal state is stale after the consolidation
  (`docs/history/research/2026-06-14-schema-v1-load-read-paths.md:198`).

### 5. Resource Descriptor, Dirty, Resolver Session, and Image Cache Ownership

- **Source group**: the narrow `ResourceCatalogPort` and dirty orchestration are
  selected at
  `docs/history/designs/2026-05-28-resource-kernel-read-seam-and-dirty-orchestration.md:304`;
  surface-session resolver/cache ownership is selected at
  `docs/history/designs/2026-05-28-p7-resource-session-resolver-lifecycle.md:147`;
  decoded-memory accounting is selected at
  `docs/history/designs/2026-06-14-resource-image-cache-memory-accounting.md:121`.
- **Architectural topic**: committed descriptors, public resource reads and
  dirty revision, active-surface resolution, bounded cache/budget policy, and
  invalidation routing.
- **Recorded decision**: the store owns descriptors; `ResourceKernel` owns the
  non-surface public port and resource visual revision; each active surface owns
  a `SurfaceResourceSession` with resolver generation, cache, per-frame budget,
  suppression, and invalidation. The cache is dual-limited by entry count and a
  decoded-image estimate; app-owned images are never disposed by the engine
  (`docs/history/designs/2026-06-14-resource-image-cache-memory-accounting.md:145`).
- **Context, alternatives, consequences**: alternatives place live image state
  in runtime, frame, widget, descriptor byte length, app-provided weights, or
  Flutter's global `ImageCache`
  (`docs/history/designs/2026-05-28-p7-resource-session-resolver-lifecycle.md:113`,
  `docs/history/designs/2026-06-14-resource-image-cache-memory-accounting.md:93`).
  The consequence is surface-bounded retention; an oversized image may satisfy
  the current resolve without being retained
  (`docs/history/designs/2026-06-14-resource-image-cache-memory-accounting.md:135`).
- **Current authoritative owner**: the complete lifecycle is owned by
  `docs/contracts/resources.md:46`; the descriptor/kernel/session split is at
  `docs/contracts/resources.md:50`, `docs/contracts/resources.md:57`, and
  `docs/contracts/resources.md:66`; cache keys, capacity, eviction, and probes
  are owned by `docs/contracts/cache_policy.md:33`.
- **Current implementation alignment**: `ResourceKernel` routes catalog reads
  and accepted dirty outcomes (`lib/src/resources/resource_kernel.dart:24`),
  while `SurfaceResourceSession` owns resolver, generation, cache, budget, and
  suppression (`lib/src/resources/surface_resource_session.dart:19`,
  `lib/src/resources/surface_resource_session.dart:46`). The executable proof
  inventory includes cache lifecycle, resolver swap, dirty invalidation,
  app-owned image lifetime, and reentrancy
  (`test/resources/surface_session_cache_lifecycle_test.dart:6`,
  `test/resources/resolver_reentrancy_rejected_test.dart:6`). This aligns with
  current ownership.
- **Duplicates, conflicts, supersession, stale sources**: the early snapshot
  placed cache state in `ResourceKernel` and lacked session/generation concepts
  (`docs/history/research/2026-05-18-resource-resolver-cache-surface-session.md:13`).
  It is superseded as a current-state description by the P7 design, current
  resources contract, and implemented session. The narrow dirty-seam design
  explicitly deferred the full resolver/session scope
  (`docs/history/designs/2026-05-28-resource-kernel-read-seam-and-dirty-orchestration.md:600`)
  and therefore complements rather than conflicts with P7.

### 6. Geometry and Derived Spatial Indexing

- **Source group**: the selected derived-spatial-kernel form is recorded at
  `docs/history/designs/2026-05-29-p8-geometry-spatial.md:151`; direct store
  reads, store-owned spatial truth, and a parallel facts port are the rejected
  alternatives at `docs/history/designs/2026-05-29-p8-geometry-spatial.md:121`.
  The earlier transform-fallback conflict is recorded in
  `docs/history/research/2026-05-18-non-invertible-transform-fallback.md:93`.
- **Architectural topic**: geometry/hit policy, derived spatial acceleration,
  touched-only updates, typed reliability results, bounded fallback, and
  corrupted-row behavior.
- **Recorded decision**: committed geometry remains store truth;
  `SpatialKernel` owns derived tile/outlier indexes and consumes touched effects.
  Typed non-candidate results cannot be converted to a successful empty
  candidate set, and ordinary edits do not full-clone the index.
- **Context, alternatives, consequences**: P8 supplies bounded candidates to
  frame, selection, eraser, and context paths without owning those user
  workflows (`docs/history/designs/2026-05-29-p8-geometry-spatial.md:17`). The
  delivery consequence is spatial update/rebuild before public state/observer
  publication (`docs/history/designs/2026-05-29-p8-geometry-spatial.md:392`).
- **Current authoritative owner**: exact geometry and corrupted-row policy are
  owned by `docs/contracts/geometry.md:33`; spatial ownership, touched updates,
  invalid-index fallback, and typed budget outcomes are owned by
  `docs/contracts/spatial_kernel.md:36`; transform admission limits are owned by
  `docs/contracts/validation_limits.md:80`.
- **Current implementation alignment**: `SpatialKernel` derives indexes from the
  frame-facts seam and applies touched sets
  (`lib/src/geometry/spatial_kernel.dart:38`,
  `lib/src/geometry/spatial_kernel.dart:67`). Executable proofs cover touched
  updates, no full clone, stale generation, budget, and invalid index
  (`test/spatial/touched_update_test.dart:6`,
  `test/spatial/fallback_budget_enforced_test.dart:8`). This matches the current
  split.
- **Duplicates, conflicts, supersession, stale sources**: the 2026-05-18 note
  records a then-current conflict between no-fallback validation and coarse
  fallback (`docs/history/research/2026-05-18-non-invertible-transform-fallback.md:101`).
  Current docs separate invalid-index spatial fallback from non-invertible
  transform admission and explicitly document current corrupted-row behavior
  (`docs/contracts/geometry.md:97`, `docs/contracts/spatial_kernel.md:66`), so
  the note is stale as current-contract evidence.

### 7. Frame Facade, Immutable Frame Capture, Planning, and Bounded Caches

- **Source group**: the frame-private facade and collaborator split are selected
  at `docs/history/designs/2026-05-19-frame-engine-internal-split.md:260` and
  carried into the P9 rendering/cache selection at
  `docs/history/designs/2026-05-29-p9-frame-rendering-and-caches.md:128`. P9
  reliability refinements are recorded at
  `docs/history/designs/2026-06-01-p9-frame-rendering-findings-closure.md:167`.
  Compact overlay capture is selected at
  `docs/history/designs/2026-06-10-overlay-frame-capture.md:110`.
- **Architectural topic**: committed-fact capture, immutable painter inputs,
  ordinary plan caching, selected supplements, decoration, asset binding,
  background planning, overlay planning, and repaint signals.
- **Recorded decision**: `FrameEngine` is a private orchestration facade over
  specialized collaborators. Painters consume immutable outputs and do not read
  live runtime or materialize public documents. Ordinary cache keys exclude
  selection and preview; selected supplements and overlays are staged outside
  ordinary cached plans. Overlay capture is compact and does not read the full
  main-scene snapshot.
- **Context, alternatives, consequences**: rejected forms include a monolithic
  renderer, a five-service partial split, cache-only extraction, public/runtime
  splitting, surface-first wiring, using the full main snapshot for overlays,
  and surface-built primitives
  (`docs/history/designs/2026-05-19-frame-engine-internal-split.md:194`,
  `docs/history/designs/2026-05-29-p9-frame-rendering-and-caches.md:98`,
  `docs/history/designs/2026-06-10-overlay-frame-capture.md:80`). The consequence
  is independent cache/admission ownership with no global scene sort and no
  painter-time runtime reads.
- **Current authoritative owner**: runtime placement is owned by
  `docs/architecture/01_runtime_ownership.md:60`; frame capture, planning,
  painter inputs, and cache behavior are owned by
  `docs/contracts/frame_rendering.md:59`; the cache ledger is owned by
  `docs/contracts/cache_policy.md:33`.
- **Current implementation alignment**: `FrameEngine` constructs distinct main
  and overlay outputs (`lib/src/frame/frame_engine.dart:74`,
  `lib/src/frame/frame_engine.dart:152`); main and overlay painters consume
  outputs (`lib/src/surface/main_painter.dart:10`,
  `lib/src/surface/overlay_painter.dart:10`). Frame proofs cover preview/selection
  exclusion and bounded capacity
  (`test/frame/fixtures/paint_plan_excludes_preview_delta_fixture.dart:8`,
  `test/frame/cache_capacity_eviction_policy_test.dart:6`). The implementation
  matches the current owner.
- **Duplicates, conflicts, supersession, stale sources**: P9 findings closure
  refines base-candidate admission and failure containment; it does not replace
  the facade decision. The deferred finer frame-meta revision split remains
  unadopted (`docs/history/research/2026-05-17-frame-meta-revision-split.md:88`).

### 8. Selection, Move Admission, and Frame-Owned Selection Chrome

- **Source group**: the interaction-owned selection/move spine and rejected
  runtime-local/direct-mutation forms are recorded at
  `docs/history/designs/2026-06-01-p10-selection-and-move.md:248`; the selected
  form begins at `docs/history/designs/2026-06-01-p10-selection-and-move.md:313`.
  Group chrome, order, and hit admission are selected at
  `docs/history/designs/2026-06-04-selection-chrome-and-move-hit-area.md:112` and
  traced at `docs/history/designs/2026-06-04-selection-chrome-and-move-hit-area.md:130`.
- **Architectural topic**: selection truth, selected-move session admission,
  preview, terminal edit, decoration planning, paint order, and group bounds.
- **Recorded decision**: `SelectionKernel` owns selected ids/revision;
  interaction owns the selected-move session and terminal edit routing; frame
  owns selection chrome. Multi-selection derives one union primitive; chrome is
  painted in scene order; group-area move admission is derived at the immutable
  interaction read boundary without replacing ordinary exact hit testing.
- **Context, alternatives, consequences**: alternatives included runtime-local
  interaction, direct mutation ports, planner-only union with a global
  post-paint pass, and an app/surface overlay hit box
  (`docs/history/designs/2026-06-01-p10-selection-and-move.md:250`,
  `docs/history/designs/2026-06-04-selection-chrome-and-move-hit-area.md:82`).
  The consequence is no duplicate stored group-bounds truth; visual and
  admission facts are derived by their respective owners.
- **Current authoritative owner**: selection separation is owned by
  `docs/architecture/03_data_model.md:213`; interaction read/session semantics
  are owned by `docs/contracts/interaction_engine.md:93`; frame decoration is
  owned by `docs/contracts/frame_rendering.md:147`.
- **Current implementation alignment**: selection decoration planning is a
  frame production owner (`lib/src/frame/selection_decoration_planner.dart:69`),
  and release proof explicitly includes selection-state cache independence,
  selected-move main repaint, and overlay split
  (`docs/verification/release_gates.md:143`,
  `docs/verification/release_gates.md:146`). No contradictory implementation
  evidence was found.
- **Duplicates, conflicts, supersession, stale sources**: the chrome design
  retires per-selected-element/global-after-pass and exact-only group admission
  behavior (`docs/history/designs/2026-06-04-selection-chrome-and-move-hit-area.md:165`).
  It refines P10 without replacing P10 ownership.

### 9. Interaction Tool Machines, Cleanup, Context Requests, and Terminal Input

- **Source group**: direct host double tap is selected at
  `docs/history/designs/2026-05-19-double-tap-context-action.md:227`; the shared
  cleanup coordinator at
  `docs/history/designs/2026-05-19-pointer-tool-cleanup-coordinator.md:305`;
  draw machines at `docs/history/designs/2026-06-02-p11-draw-tools.md:297`;
  eraser/context routing at
  `docs/history/designs/2026-06-02-p12-eraser-and-context-action-request.md:225`;
  live-only admitted request handling at
  `docs/history/designs/2026-06-03-p12-findings-closure.md:212`; and invalid
  terminal cleanup at
  `docs/history/designs/2026-06-10-api-surface-invalid-terminal-cleanup.md:257`.
- **Architectural topic**: pointer sessions, tool-specific machines, preview,
  cancellation, stale terminals, eraser reliability, context request
  admission, request lifecycle, and public terminal input shape.
- **Recorded decision**: `InteractionEngine` composes tool machines and one
  effect-only cleanup coordinator. Tool terminals route accepted mutations
  through the existing edit path. Context requests are issued only after an
  admitted target result, delivered asynchronously, and removed on consume or
  cleanup. Non-finite down/move samples are dropped; non-finite up/cancel is a
  no-position cleanup input that cannot commit or reserve an action timestamp.
- **Context, alternatives, consequences**: rejected forms include pending
  second-tap recognition, a new public double-tap method, cleanup distributed
  across sessions or runtime, public draw commands, direct store mutation,
  synchronous context delivery, retained retired request facts, relaxed finite
  sample validation, and a surface-only cleanup route
  (`docs/history/designs/2026-05-19-double-tap-context-action.md:172`,
  `docs/history/designs/2026-05-19-pointer-tool-cleanup-coordinator.md:234`,
  `docs/history/designs/2026-06-02-p11-draw-tools.md:305`,
  `docs/history/designs/2026-06-03-p12-findings-closure.md:297`,
  `docs/history/designs/2026-06-10-api-surface-invalid-terminal-cleanup.md:200`).
- **Current authoritative owner**: pointer sessions, previews, terminal commits,
  cleanup, repaint target, and double tap are owned by
  `docs/contracts/interaction_engine.md:93`,
  `docs/contracts/interaction_engine.md:227`,
  `docs/contracts/interaction_engine.md:302`, and
  `docs/contracts/interaction_engine.md:322`.
- **Current implementation alignment**: the coordinator exists as an internal
  interaction owner (`lib/src/interaction/pointer_tool_cleanup_coordinator.dart:1`),
  and import guardrails enforce a single caller and interaction dependency bans
  (`test/guardrails/import_boundaries_test.dart:27`). Release proof includes
  double tap, stale terminal, resolver-cancel, and interactive-false behavior
  (`docs/verification/release_gates.md:148`,
  `docs/verification/release_gates.md:153`). This matches the current contract.
- **Duplicates, conflicts, supersession, stale sources**: the pre-design
  research found no named coordinator
  (`docs/history/research/2026-05-19-pointer-tool-cleanup-coordinator.md:109`);
  that current-state observation is superseded by the design, contract, source
  file, and guardrails. P12 findings closure explicitly replaces fact-only
  target reads and retained retired request records with admitted/rejected and
  consume/remove semantics
  (`docs/history/designs/2026-06-03-p12-findings-closure.md:233`).

### 10. Runtime-Owned Text Editing with a Surface-Owned Flutter Overlay

- **Source group**: the early app-owned flow is recorded in
  `docs/history/research/2026-05-18-text-edit-stale-guard.md:13`; the later
  runtime-owned session, frame measurement, and Flutter overlay selection is
  recorded at
  `docs/history/designs/2026-06-04-inline-text-editing-contract.md:184` and its
  decision trace at
  `docs/history/designs/2026-06-04-inline-text-editing-contract.md:381`.
- **Architectural topic**: text-edit request admission, stale guards, live
  geometry/style, paint suppression, commit/dismiss, text measurement, and
  Flutter editable lifecycle.
- **Recorded decision**: the runtime owns one active guarded text-edit session
  and the public text-edit port; frame owns text layout measurement and
  suppression inputs; the surface owns the `EditableText` overlay. Editing does
  not hide the committed element by mutating document visibility.
- **Context, alternatives, consequences**: the selected form addresses the need
  for engine-derived geometry/style and stale request protection while leaving
  editor widgets and application decoration outside the runtime. Alternatives
  were an app-owned overlay followed by ordinary update and a core-owned
  automatic `EditableText`
  (`docs/history/designs/2026-06-04-inline-text-editing-contract.md:154`). The
  consequence is a reusable port for default and custom overlays with a single
  text measurement owner.
- **Current authoritative owner**: runtime text-edit ownership and exclusions
  are recorded at `docs/architecture/01_runtime_ownership.md:59`; public
  declarations and behavior are owned by
  `docs/contracts/public_api_v1.md:76`; frame measurement is owned by
  `docs/contracts/frame_rendering.md:143`.
- **Current implementation alignment**: the package contains a public text-edit
  API facade (`lib/src/api/canvas_text_editing.dart:1`) and a surface overlay
  owner (`lib/src/surface/text_editing_overlay.dart:1`); release proof includes
  guarded text commit (`docs/verification/release_gates.md:148`). These surfaces
  match the current split.
- **Duplicates, conflicts, supersession, stale sources**: the 2026-05-18 note's
  absence of request id, commit command, and runtime-held session is stale after
  the 2026-06-04 design and current runtime contract. It remains context for the
  rejected app-owned form, not a current decision owner.

### 11. Flutter Surface Ownership and Layer-Aware Repaint Routing

- **Source group**: the surface-owned widget and narrow bridge are selected at
  `docs/history/designs/2026-06-03-p13-flutter-surface.md:278`; layer-aware
  output caching and independent paint hosts are selected at
  `docs/history/designs/2026-06-13-layer-aware-surface-repaint-routing.md:136`
  and traced at
  `docs/history/designs/2026-06-13-layer-aware-surface-repaint-routing.md:154`.
- **Architectural topic**: single active surface, attach/detach/runtime swap,
  resource-session lifecycle, pointer adaptation, immutable frame-output cache,
  and independent main/overlay Flutter paint scheduling.
- **Recorded decision**: `CanvasSurface` owns Flutter lifecycle and the active
  surface token, uses a narrow runtime-surface bridge, creates the per-surface
  resource session only after accepted attach, normalizes pointer input before
  runtime delivery, and stores only transient immutable main/overlay outputs.
  Main and overlay paint layers invalidate independently from typed repaint
  targets.
- **Context, alternatives, consequences**: rejected forms include an API-owned
  widget, direct `RuntimeRoot` imports, surface-owned frame planning,
  painter-only `shouldRepaint`, state-delta inference, and direct painter reads
  from a repaint bus
  (`docs/history/designs/2026-06-03-p13-flutter-surface.md:245`,
  `docs/history/designs/2026-06-13-layer-aware-surface-repaint-routing.md:100`).
  The consequence is a surface-local output cache without a second document,
  frame, or resource-policy owner.
- **Current authoritative owner**: CanvasSurface ownership is specified at
  `docs/architecture/01_runtime_ownership.md:79`; package placement is owned by
  `docs/architecture/02_package_boundaries.md:291`; frame output and repaint
  semantics are owned by `docs/contracts/frame_rendering.md:59` and interaction
  repaint targeting by `docs/contracts/interaction_engine.md:302`.
- **Current implementation alignment**: the widget installs a surface resource
  session (`lib/src/surface/canvas_surface_widget.dart:115`), the output cache
  stores separate layers (`lib/src/surface/surface_frame_output_cache.dart:30`),
  and `LayerPaintHost` hosts layer painting
  (`lib/src/surface/layer_paint_host.dart:11`). Surface proofs cover one active
  surface, finite layout, no live painter reads, and interactive-false cleanup
  (`test/surface/single_active_surface_test.dart:6`,
  `test/surface/no_live_runtime_read_in_painters_test.dart:6`). This matches the
  current owner.
- **Duplicates, conflicts, supersession, stale sources**: the later repaint
  design retires the prior state-driven build of both outputs through one
  `CustomPaint` (`docs/history/designs/2026-06-13-layer-aware-surface-repaint-routing.md:186`)
  while retaining the P13 surface ownership decision.

### 12. Internal Diagnostics Hub, Public Diagnostic Types, and Routing Table

- **Source group**: diagnostics membership in the existing public API registry
  is selected at
  `docs/history/designs/2026-05-25-diagnostics-public-surface-guard.md:88`;
  the single normative producer-routing table is selected at
  `docs/history/designs/2026-05-28-diagnostics-hub-ssot-routing-table.md:195`.
- **Architectural topic**: internal diagnostics ownership, public diagnostic
  value membership, producer routing, disabled hot-path behavior, sanitization,
  and explicitly deferred/forbidden routes.
- **Recorded decision**: `docs/contracts/diagnostics.md` is the semantic owner of
  hub records and routing; registries and diagrams project membership and
  relationships. The public registry classifies approved diagnostic value
  types without exporting a public diagnostics stream. Disabled diagnostics
  avoid record/detail allocation.
- **Context, alternatives, consequences**: alternatives included a test-local
  allowlist, separate registry, name-prefix inference, per-producer tables,
  graph-only routing, and implementation tests as the semantic owner
  (`docs/history/designs/2026-05-25-diagnostics-public-surface-guard.md:55`,
  `docs/history/designs/2026-05-28-diagnostics-hub-ssot-routing-table.md:159`).
  The consequence is one routing policy with machine-projected membership.
- **Current authoritative owner**: diagnostics semantics and route status are
  owned by `docs/contracts/diagnostics.md:25` and its routing table at
  `docs/contracts/diagnostics.md:76`; public membership is owned by
  `docs/_registry/public_api_v1.yaml:116` while public semantics remain in
  `docs/contracts/public_api_v1.md:76`.
- **Current implementation alignment**: `DiagnosticsHub` applies disabled and
  sanitization policy (`lib/src/diagnostics/diagnostics_hub.dart:19`); disabled
  proof avoids lazy details and records
  (`test/diagnostics/fixtures/disabled_no_alloc_hot_path_fixture.dart:23`). This
  matches the current owner.
- **Duplicates, conflicts, supersession, stale sources**: the two designs are
  complementary: one owns public membership enforcement, the other writer and
  route semantics. Current docs explicitly retain deferred geometry and observer
  delivery routes, planned internal self-protection, and a forbidden v1 public
  stream (`docs/contracts/diagnostics.md:85`). Those statuses are current facts,
  not contradictions with the selected hub design.

### 13. Documentation Portal, Architecture Graph, Registries, and External Proof

- **Source group**: expected-versus-analyzer graph checking is selected at
  `docs/history/designs/2026-05-22-architecture-graph-closure-checker.md:147`;
  task-oriented docs plus registry-owned generated indexes at
  `docs/history/designs/2026-05-22-docs-documentation-portal.md:115`; an external
  public-consumer behavior smoke at
  `docs/history/designs/2026-05-23-public-incremental-smoke-test.md:111`; and
  replacement-before-retirement of phase/donor documents at
  `docs/history/designs/2026-06-08-legacy-phase-cleanup.md:485`.
- **Architectural topic**: separation of semantic docs, machine registries,
  generated navigation/views, analyzer-derived actual dependency evidence, and
  external public integration proof.
- **Recorded decision**: semantic Markdown owns meaning; registries own
  relationships and inventories; generated indexes and graph views are checked
  projections. The architecture graph owns expected obligations, while source
  analysis supplies actual facts. Public completeness is also tested from an
  external package importing only the public barrel.
- **Context, alternatives, consequences**: rejected forms include targeted-only
  guards, Mermaid as the source graph, generated actual graph as a durable
  owner, manual index repair, phase-first navigation, docs-as-data, in-package
  barrel smoke, and test-local adapter fixtures
  (`docs/history/designs/2026-05-22-architecture-graph-closure-checker.md:109`,
  `docs/history/designs/2026-05-22-docs-documentation-portal.md:79`,
  `docs/history/designs/2026-05-23-public-incremental-smoke-test.md:76`). The
  consequence is mechanically checked navigation, coverage, graph closure, and
  public consumption without making generated files semantic owners.
- **Current authoritative owner**: routes and source classes are defined by
  `docs/README.md:25` and `docs/architecture/README.md:29`; the graph is owned by
  `docs/architecture/architecture_graph.yaml:30`; section and diagram metadata
  are owned by `docs/_registry/sections.yaml:1` and
  `docs/_registry/diagrams.yaml:1`.
- **Current implementation alignment**: graph schema tests check source
  existence, coverage, obligations, and current closure
  (`test/architecture_graph/architecture_graph_schema_test.dart:82`,
  `test/architecture_graph/current_closure_checker_test.dart:221`); current docs
  navigation rejects retired routes (`test/docs/current_docs_navigation_test.dart:18`).
  These proof surfaces match the current documentation architecture.
- **Duplicates, conflicts, supersession, stale sources**: manual reverse indexes,
  phase closure, completed roadmaps, and donor documents are retired by the
  cleanup design (`docs/history/designs/2026-06-08-legacy-phase-cleanup.md:543`).
  The original graph design's phase-aware parameter is stale, while its
  expected/actual closure decision remains represented by the current graph and
  checker.

### 14. Release-Blocking Flutter Performance Route and Artifact Semantics

- **Source group**: the earlier custom benchmark/release-readiness route is
  selected in
  `docs/history/designs/2026-06-05-p14-release-readiness-benchmarks.md:343` and
  its measurement boundary at
  `docs/history/designs/2026-06-06-p14-benchmark-measurement-boundary.md:293`.
  The later official Flutter route and registered docs owner are selected at
  `docs/history/designs/2026-06-16-flutter-performance-verification-route.md:365`
  and implemented by the completed contract at
  `docs/history/plans/2026-06-16-flutter-performance-verification-route.md:276`.
  Phase-aware repeated measurement is selected at
  `docs/history/designs/2026-06-16-android-flutter-performance-benchmark-redesign.md:315`
  and implemented by the completed contract at
  `docs/history/plans/2026-06-16-android-flutter-performance-benchmark-redesign.md:300`.
- **Architectural topic**: official performance-route ownership, external
  Flutter profile execution, setup/action separation, repeated steady runs,
  artifact schema, local comparison, and release-gate meaning.
- **Recorded decision**: `docs/verification/performance.md` owns the official
  route. The example app runs as a public consumer through `integration_test`
  and `flutter drive --profile --no-dds`. The current catalog expands scenario
  groups to `setup`, `warm`, `steady`, or `single` report keys; redesigned
  steady phases have five repeats from equivalent canonical prepared state.
  Flutter timeline data remains the measurement source; the repository writes
  a manifest and comparison summary. The gate checks completion and artifact
  integrity, not numeric performance thresholds.
- **Context, alternatives, consequences**: alternatives included policy spread
  across tests/release docs, an unregistered `perf.md`, Android Macrobenchmark,
  manual reruns, restoring retired custom benchmark infrastructure, and
  custom/check-in measurement artifacts
  (`docs/history/designs/2026-06-16-flutter-performance-verification-route.md:314`,
  `docs/history/designs/2026-06-16-android-flutter-performance-benchmark-redesign.md:270`).
  The consequence is nested group/phase/repeat output plus local median/spread
  summaries without baseline, regression, CPU-attribution, or cross-device
  claims.
- **Current authoritative owner**: the route and exact report/artifact semantics
  are owned by `docs/verification/performance.md:30`; report-key grammar is at
  `docs/verification/performance.md:60`; artifact paths start at
  `docs/verification/performance.md:150`; unsupported numeric claims are stated
  at `docs/verification/performance.md:260`. Release meaning is owned by
  `docs/verification/release_gates.md:167`.
- **Current implementation alignment**: the checker explicitly records
  `numericThresholds: false` and `passFailPerformance: false`
  (`tool/check_flutter_performance_artifacts.dart:20`) and validates the
  manifest/comparison shape
  (`tool/check_flutter_performance_artifacts.dart:881`). Route tests verify the
  phase catalog and trace boundaries
  (`test/performance/flutter_performance_route_contract_test.dart:164`). The
  implementation matches the current route owner.
- **Duplicates, conflicts, supersession, stale sources**: the two 2026-06-16
  artifacts form one evolution: the first establishes the official owner and
  route; the second replaces one scenario id/one report key and flat artifacts
  with group/phase/repeat semantics
  (`docs/history/plans/2026-06-16-flutter-performance-verification-route.md:302`,
  `docs/history/plans/2026-06-16-android-flutter-performance-benchmark-redesign.md:40`).
  The custom P14 benchmark registry, `tool/bench/**`, checked-in baselines, and
  numeric gate selected in the earlier P14 designs are retired under the current
  route (`docs/verification/performance.md:269`).

## Consolidated Source Group Map

| Decision group | Historical documents grouped as one lineage | Current owner(s) |
|---|---|---|
| Maintained package and acyclic runtime | `docs/history/designs/2026-05-27-acyclic-runtime-public-api-architecture.md`, `docs/history/designs/2026-06-03-legacy-example-full-parity-port.md`, `docs/history/designs/2026-06-08-legacy-phase-cleanup.md` | `docs/architecture/00_architecture_overview.md`, `docs/architecture/02_package_boundaries.md`, `docs/contracts/public_api_v1.md` |
| Data/projection/selection/cameras | `docs/history/research/2026-05-17-frame-meta-revision-split.md` | `docs/architecture/03_data_model.md` |
| Edit/store/no-op | `docs/history/designs/2026-05-24-p5-edit-core.md`, `docs/history/designs/2026-06-06-incremental-edit-store.md`, `docs/history/designs/2026-06-11-net-no-op-edit-commit.md`, `docs/history/research/2026-05-18-action-events-notification-stream.md` | `docs/contracts/edit_kernel.md`, `docs/contracts/operation_matrix.md` |
| Load and Schema v1 | `docs/history/designs/2026-05-26-p6-load-document.md`, `docs/history/designs/2026-06-07-canonical-schema-v1-json-load-api.md`, `docs/history/designs/2026-06-14-schema-v1-reader-consolidation.md`, `docs/history/research/2026-06-14-schema-v1-load-read-paths.md` | `docs/contracts/load_document.md`, `docs/contracts/schema_v1.md`, `docs/contracts/codec_boundary.md` |
| Resources | `docs/history/designs/2026-05-28-resource-kernel-read-seam-and-dirty-orchestration.md`, `docs/history/designs/2026-05-28-p7-resource-session-resolver-lifecycle.md`, `docs/history/designs/2026-06-14-resource-image-cache-memory-accounting.md`, `docs/history/research/2026-05-18-resource-resolver-cache-surface-session.md`, `docs/history/research/2026-05-28-p7-resource-session-resolver-lifecycle.md`, `docs/history/research/2026-06-14-resource-image-cache-memory-accounting.md` | `docs/contracts/resources.md`, `docs/contracts/cache_policy.md` |
| Geometry/spatial | `docs/history/designs/2026-05-29-p8-geometry-spatial.md`, `docs/history/research/2026-05-18-non-invertible-transform-fallback.md` | `docs/contracts/geometry.md`, `docs/contracts/spatial_kernel.md`, `docs/contracts/validation_limits.md` |
| Frame/caches | `docs/history/designs/2026-05-19-frame-engine-internal-split.md`, `docs/history/designs/2026-05-29-p9-frame-rendering-and-caches.md`, `docs/history/designs/2026-06-01-p9-frame-rendering-findings-closure.md`, `docs/history/designs/2026-06-10-overlay-frame-capture.md`, `docs/history/research/2026-05-17-frame-meta-revision-split.md` | `docs/contracts/frame_rendering.md`, `docs/contracts/cache_policy.md` |
| Selection/move/chrome | `docs/history/designs/2026-06-01-p10-selection-and-move.md`, `docs/history/designs/2026-06-04-selection-chrome-and-move-hit-area.md` | `docs/contracts/interaction_engine.md`, `docs/contracts/frame_rendering.md` |
| Interaction/tools/cleanup | `docs/history/designs/2026-05-19-double-tap-context-action.md`, `docs/history/designs/2026-05-19-pointer-tool-cleanup-coordinator.md`, `docs/history/designs/2026-06-02-p11-draw-tools.md`, `docs/history/designs/2026-06-02-p12-eraser-and-context-action-request.md`, `docs/history/designs/2026-06-03-p12-findings-closure.md`, `docs/history/designs/2026-06-10-api-surface-invalid-terminal-cleanup.md`, `docs/history/research/2026-05-19-pointer-tool-cleanup-coordinator.md` | `docs/contracts/interaction_engine.md` |
| Text editing | `docs/history/research/2026-05-18-text-edit-stale-guard.md`, `docs/history/designs/2026-06-04-inline-text-editing-contract.md` | `docs/architecture/01_runtime_ownership.md`, `docs/contracts/public_api_v1.md`, `docs/contracts/frame_rendering.md` |
| Flutter surface/repaint | `docs/history/designs/2026-06-03-p13-flutter-surface.md`, `docs/history/designs/2026-06-13-layer-aware-surface-repaint-routing.md` | `docs/architecture/01_runtime_ownership.md`, `docs/contracts/frame_rendering.md`, `docs/contracts/interaction_engine.md` |
| Diagnostics | `docs/history/designs/2026-05-25-diagnostics-public-surface-guard.md`, `docs/history/designs/2026-05-28-diagnostics-hub-ssot-routing-table.md` | `docs/contracts/diagnostics.md`, `docs/contracts/public_api_v1.md`, `docs/_registry/public_api_v1.yaml` |
| Docs/graph/proof | `docs/history/designs/2026-05-22-architecture-graph-closure-checker.md`, `docs/history/designs/2026-05-22-docs-documentation-portal.md`, `docs/history/designs/2026-05-23-public-incremental-smoke-test.md`, `docs/history/designs/2026-06-08-legacy-phase-cleanup.md` | `docs/README.md`, `docs/architecture/README.md`, `docs/architecture/architecture_graph.yaml`, `docs/_registry/**` |
| Performance/release | `docs/history/designs/2026-06-05-p14-release-readiness-benchmarks.md`, `docs/history/designs/2026-06-06-p14-benchmark-measurement-boundary.md`, `docs/history/designs/2026-06-16-flutter-performance-verification-route.md`, `docs/history/designs/2026-06-16-android-flutter-performance-benchmark-redesign.md`, `docs/history/plans/2026-06-16-flutter-performance-verification-route.md`, `docs/history/plans/2026-06-16-android-flutter-performance-benchmark-redesign.md`, `docs/history/research/2026-06-16-flutter-performance-docs-ssot.md`, `docs/history/research/2026-06-16-android-performance-hotspot-paths.md` | `docs/verification/performance.md`, `docs/verification/release_gates.md` |

## Code References

- `lib/src/api/canvas_runtime.dart:28` - public facade constructs the runtime root.
- `lib/src/store/document_projection_cache.dart:11` - lazy public projection cache.
- `lib/src/resources/surface_resource_session.dart:46` - session-owned resolver/cache/budget path.
- `lib/src/geometry/spatial_kernel.dart:67` - touched spatial update path.
- `lib/src/frame/frame_engine.dart:74` - main frame construction.
- `lib/src/interaction/pointer_tool_cleanup_coordinator.dart:1` - named internal cleanup owner.
- `lib/src/surface/canvas_surface_widget.dart:115` - surface resource-session installation.
- `lib/src/diagnostics/diagnostics_hub.dart:19` - diagnostics policy admission.
- `test/api_contract/public_integration_compile_fixture_test.dart:11` - external public-only compile proof.
- `test/edit/fixtures/rollback_fixture.dart:41` - rejected edit preserves state and effects.
- `test/architecture_graph/current_closure_checker_test.dart:221` - current graph closure proof.
- `tool/check_flutter_performance_artifacts.dart:20` - current route disclaims numeric/pass-fail gates.

## Search Coverage

- **Inspected completely**: `AGENTS.md`; `docs/README.md`; all files under
  `docs/architecture/`, `docs/contracts/`, and `docs/_registry/`;
  `docs/planning/README.md`; `docs/planning/FOLLOW_UPS.md`; all 37 files under
  `docs/history/designs/`; both files under `docs/history/plans/`;
  `docs/verification/performance.md`; `docs/verification/release_gates.md`; and
  the historical research files directly cited for data/camera, action events,
  resource lifecycle, transform fallback, text-edit state, pointer cleanup,
  and Schema v1 read paths. Production and proof files
  listed in `Code References` were inspected for the cited facts.
- **Searched**: complete file inventories for `docs/history/research/` (64
  Markdown files), `docs/history/designs/`, `docs/history/plans/`, current docs,
  `lib/**`, `test/**`, and `tool/**`; headings and decision/adopted/canonical/
  owner/source-of-truth/alternative/consequence/supersession/retired/stale terms;
  public, runtime, edit, load, schema, resource, geometry, spatial, frame,
  interaction, surface, diagnostics, graph, and performance owner symbols.
- **Not found**: no active direct-child design or plan files; no current docs
  statement making history authoritative; no current implementation evidence
  contradicting the 14 current owner groups.
- **Not inspected completely**: historical research notes not cited for a
  candidate fact were included in the thematic search inventory but not read
  completely. Generated diagram bodies were not read individually because
  their current source is the architecture graph
  (`docs/_registry/diagrams.yaml:414`). Full production files larger than the
  cited owner seams were not used to infer unstated behavior.

## Observed Architecture Facts

- **Pattern observed**: semantic Markdown owns meaning, structured registries
  own membership/relationships, and generated material is a checked projection
  (`docs/architecture/README.md:31`, `docs/_registry/sections.yaml:1`).
- **Pattern observed**: stable cross-owner communication uses dependency-low
  public/internal contracts; facades compose owners without becoming duplicate
  state owners (`docs/architecture/02_package_boundaries.md:178`,
  `docs/architecture/02_package_boundaries.md:221`).
- **Data flow**: public edit/load input -> edit/codec preparation -> store
  accepted facts -> typed cross-owner effects -> one public state observation
  (`docs/contracts/edit_kernel.md:90`, `docs/contracts/load_document.md:58`,
  `docs/contracts/operation_matrix.md:48`).
- **Data flow**: committed descriptors -> resource kernel reads/dirty outcome ->
  active surface-session invalidation/resolution -> immutable frame asset
  binding (`docs/contracts/resources.md:50`, `docs/contracts/resources.md:66`,
  `docs/contracts/frame_rendering.md:154`).
- **Data flow**: immutable runtime facts -> spatial/frame/interaction planning ->
  surface-local immutable outputs -> independent main/overlay painters
  (`docs/architecture/01_runtime_ownership.md:117`,
  `docs/contracts/frame_rendering.md:112`).

## Open Questions

- Current diagnostics docs explicitly retain deferred and planned routes
  (`docs/contracts/diagnostics.md:85`). Their status is recorded here as current
  context; no completed decision is inferred for those deferred routes.
- The finer `frameMetaRevision` split remains a historical deferred option
  (`docs/history/research/2026-05-17-frame-meta-revision-split.md:88`), not a
  current selected architecture decision.
