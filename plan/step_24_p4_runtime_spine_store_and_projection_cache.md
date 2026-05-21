# Change Contract

Contract Mode: FULL
Contract Profile: BEHAVIOR_CHANGE
Contract Obligations: SEAM_MIGRATION

## 1. Mandate and Boundary

### Mandate

Implement P4 runtime spine, committed store, selection owner foundation,
runtime-owned public state publication, document projection cache, runtime id
generation, and narrow immutable read ports so later edit, load, resource,
frame, spatial, and interaction phases can read committed facts without
bypassing ownership.

### In Scope

- Replace the P0 runtime skeleton with one composed `RuntimeRoot` that owns the
  runtime lifecycle, state holder, config materialization, committed document
  store, selection kernel, projection cache, id generation, and read/query
  boundaries needed by P4.
- Store committed document facts in compact internal runtime/store structures
  instead of retaining a live public `CanvasDocument` as runtime state.
- Implement `CanvasRuntime.readDocument` as an explicit public projection path
  backed by `DocumentProjectionCache`.
- Keep `CanvasRuntime.state` as a public `ValueListenable<CanvasRuntimeState>`
  whose value remains readable after dispose and whose revisions/summary are
  produced from owner-provided runtime facts.
- Materialize `CanvasRuntimeConfig` into runtime-owned values, preserving the
  constructor-validated diagnostic verbose preview and list-entry limits without
  moving schema or codec ownership into `RuntimeRoot`.
- Add `SelectionKernel` as the internal owner for selected ids and
  `selectionRevision`, with P4-only selection facts available through narrow
  immutable ports.
- Add `FrameFactsPort` and document/selection read facts required by later
  frame, spatial, resource, and interaction owners without creating those later
  owners or their behavior.
- Add or extend executable tests and guardrails required by P4, with every P4
  guardrail using a selected pattern from
  `docs/verification/guardrail_design_patterns.md` and every P4 test using a
  selected form from `docs/verification/tests.md`.
- Update roadmap checkboxes in this step file and root `PLAN.md` only after the
  implementation step is actually complete.

### Out of Scope

- Edit sessions, draft mutation, commit/rollback, operation matrix effects,
  `loadDocument` replacement behavior, resource resolver/session behavior,
  geometry/spatial indexing, frame rendering, pointer routing, Flutter widget
  behavior, user-action events, and context-action requests.
- Public API signature changes, public export renames, new schema versions, or
  compatibility with legacy public API shapes.
- Storing selection in committed document state, schema v1, public document DTOs,
  or projection cache state.
- Building `CanvasDocument` projection in future pointer, hit-test, paint,
  frame, or interaction hot paths.
- Copying legacy controller, scene builder, scene codec, or whole store
  controller structure from donor code.
- Fully closing future-only branches of existing broad test responsibilities
  when those branches require P5+ owners; this contract must name those
  deferrals instead of adding placeholder behavior.

## 2. Evidence Map

### Baseline Evidence

These facts describe repository state before execution. They are evidence for
the change, not target-state requirements.

- `PLAN.md` owns the active roadmap index, and
  `plan/step_24_p4_runtime_spine_store_and_projection_cache.md` owns the
  executable Step 24 Change Contract once accepted.
- `docs/implementation/p4_runtime_spine.md` defines the P4 purpose, build
  scope, dependencies, donors, forbidden donor structures, diagrams, required
  tests, guardrails, exit gate, and risks.
- `docs/architecture/00_architecture_overview.md` owns the new-package scope
  decision and no-legacy-runtime boundary that P4 must preserve.
- `docs/architecture/01_runtime_ownership.md` owns the target runtime ownership
  model: public API, `RuntimeRoot`, `DocumentStoreKernel`, `FrameFactsPort`,
  `SelectionKernel`, `EditKernel`, `InteractionEngine`, `FrameEngine`,
  `ResourceKernel`, `SurfaceResourceSession`, `SpatialKernel`,
  `CodecBoundary`, and `DiagnosticsHub`.
- `docs/architecture/03_data_model.md` owns committed document tables,
  revision facts, runtime state domains, selection/document separation, runtime
  view camera separation, and `DocumentProjectionCache` policy.
- `docs/contracts/public_api_v1.md` owns the public `CanvasRuntime`,
  `CanvasRuntimeConfig`, `CanvasRuntimeState`, `CanvasRuntimeRevisions`,
  `CanvasRuntimeSummary`, `CanvasDocumentSummary`, id, document, resource, and
  port semantics that P4 may implement without changing public signatures.
- `docs/contracts/validation_limits.md` owns runtime config materialization
  limits, including `CanvasDiagnosticsVerbose` preview and list-entry bounds.
- `docs/verification/tests.md` owns required test ids, test shape rules, and
  broad future responsibilities for runtime, store, selection, and guardrail
  tests.
- `docs/verification/guardrails.md` owns mandatory guardrail ids and guardrail
  runner contract.
- `docs/verification/guardrail_design_patterns.md` owns guardrail pattern
  selection for `core.single_runtime_root`,
  `store.no_public_document_live_state`,
  `selection.owner_separate_from_document`, and
  `projection.only_explicit_read_paths`.
- `docs/_registry/sections.yaml` owns registry identity and section ownership
  for the source-of-truth documents that feed P4.
- `docs/_registry/donors.yaml` allows targeted adaptation of
  `store_scene_controller_read_paths`, `dto_node_boundary_mapping`, and
  `dto_document_helpers` for P4 while forbidding the listed whole legacy
  structures.
- `docs/_registry/public_api_v1.yaml` owns machine-readable public export
  inventory that P4 must not change unless Public API v1 is explicitly revised.
- `docs/diagrams/c4_component_runtime.mmd`, `docs/diagrams/c4_container.mmd`,
  `docs/diagrams/dfd_cache_invalidation.mmd`, and
  `docs/diagrams/state_runtime_lifecycle.mmd` show the target runtime
  component graph, cache invalidation ownership, and runtime lifecycle.
- `docs/architecture/02_package_boundaries.md` owns package layout, source
  boundary rules, `FrameFactsPort` placement, read-port constraints, and
  `test/**` ownership mirrors.
- `lib/src/runtime/runtime_root.dart` currently contains only the P0
  `RuntimeRoot` skeleton.
- `lib/src/api/canvas_runtime.dart` currently stores a public `CanvasDocument`
  directly inside `CanvasRuntime`, returns that object from `readDocument`, and
  throws `UnimplementedError` for most runtime ports and lifecycle operations.
- `tool/guardrails/src/guardrail_registry.dart` currently registers P0-P3
  blocking guardrail ids, including `core.single_runtime_root`, but not the P4
  store/selection/projection guardrail ids.

### Entry Paths

- Public runtime construction enters through `CanvasRuntime(...)` in
  `lib/src/api/canvas_runtime.dart`.
- Public document reads enter through `CanvasRuntime.readDocument`.
- Public state observation enters through `CanvasRuntime.state`.
- Public lifecycle closure enters through `CanvasRuntime.dispose`.
- Public runtime id generation enters through `CanvasRuntime.generateElementId`,
  `generateLayerId`, and `generateResourceId`.
- Guardrail execution enters `dart run tool/guardrails/run.dart`, with runner
  inventory in `tool/guardrails/src/guardrail_registry.dart` and dispatch in
  `tool/guardrails/src/guardrail_executor.dart`.

### Current Owners

- `lib/src/api/**` owns public value types, public constructor validation,
  public runtime API declarations, and public state DTOs.
- `lib/src/runtime/runtime_root.dart` is the existing runtime composition-root
  placeholder and must become the P4 composition owner.
- `lib/src/store/**` does not exist yet; P4 must create it as the owner for
  committed document tables, revision facts, and projection cache policy.
- `lib/src/selection/**` does not exist yet; P4 must create it as the owner for
  selected ids and `selectionRevision`.
- `lib/src/codec/**` owns schema v1 DTO validation and encode/decode behavior;
  P4 may use public DTOs and validated construction results but must not move
  codec ownership into runtime/store.
- `lib/src/diagnostics/**` owns diagnostic policy support from P3; P4 may
  materialize runtime config diagnostic limits but must not make diagnostics the
  document or store owner.
- `tool/guardrails/**` owns guardrail runner inventory, dispatch, and reusable
  structural checks.
- Existing `test/runtime/**` and `test/guardrails/**` own current runtime and
  guardrail proof. `test/store/**` and `test/selection/**` do not exist yet;
  P4 must create those proof mirrors because
  `docs/architecture/02_package_boundaries.md` requires production-owned tests
  to mirror top-level ownership folders under `lib/src/**`.

### Existing Checks

- `test/runtime/runtime_state_publication_test.dart` proves initial public state
  publication through an external consumer harness, but its current
  `readDocument` same-object expectation is evidence of the placeholder P2/P3
  runtime shape, not the target P4 projection policy.
- `test/guardrails/single_runtime_root_test.dart` proves
  `core.single_runtime_root`.
- `test/guardrails/import_boundaries_test.dart` proves source boundary behavior
  and contains an interaction/store negative import fixture.
- `test/guardrails/blocking_suite_test.dart` proves runner inventory and
  selection modes for currently executable guardrails.
- `dart analyze`, `dcm analyze .`, and `dcm calculate-metrics .` are the
  repository-required checks after code changes.

### Valid Precedents

- Existing guardrails use a thin runner dispatch over proof tests or tool-owned
  checks instead of reimplementing behavior in the runner.
- Existing public consumer tests under `test/api_contract/**` use
  `test/support/flutter_consumer_test_harness.dart` only when proving external
  consumer behavior.
- Existing in-package guardrail tests import shared checker logic from
  `tool/guardrails/**`, keeping production `lib/**` independent from tooling.
- Existing public DTO and codec tests construct public values through the
  public API and rely on public validators instead of private shape guesses.

### Repository Rules

- Root `PLAN.md` is the active roadmap. A completed implementation step must
  update both root `PLAN.md` and the linked step document in the same change.
- When adding a new `PLAN.md` step, the step document must use the current
  `change-contract` template, not historical step-file shapes.
- P4 depends on P0 package boundaries, P2 public runtime/DTO API, and P3 codec
  DTO validation.
- Mandatory guardrails must choose implementation patterns from
  `docs/verification/guardrail_design_patterns.md`.
- Required tests must follow the test shape rules in
  `docs/verification/tests.md`.
- Documentation-only changes do not require `dart analyze`, `dcm analyze .`, or
  `dcm calculate-metrics .`; code changes do.

### Misleading Patterns

- The current `CanvasRuntime` field `_document` is a placeholder live public
  DTO store, not an accepted committed-state owner.
- The current `RuntimeRoot` skeleton proves only the single-root guardrail and
  does not compose runtime services.
- Legacy `SceneController`, `SceneSnapshot`, `NodeSpec`, `NodePatch`,
  `PatchField`, whole `interactive_runtime.dart`, whole `scene_codec.dart`,
  whole `scene_store_controller.dart`, and public scene-builder structures are
  functional evidence only where donor records allow targeted adaptation; they
  are not target runtime architecture.
- Existing broad test responsibility prose in `docs/verification/tests.md`
  includes later edit/load/interaction/frame branches for some test ids. P4
  must not fake those branches before the owning phases exist.

## 3. Architecture Decision

### Selected Form

P4 uses `RuntimeRoot` as the single composition root behind `CanvasRuntime`.
`RuntimeRoot` owns runtime lifecycle, disposed-state admission, runtime state
publication, runtime config materialization, committed document store
composition, selection owner foundation, public id-generation facade routing,
and immutable read/query boundaries.
Committed state is stored as internal compact tables under `DocumentStoreKernel`
and projected lazily to public `CanvasDocument` only through explicit read
paths. Runtime id generation is backed by store-owned admission facts after the
initial document has been admitted, not by a temporary public-DTO scan or a
second id source. P4 creates the narrow read ports needed by later phases, but
those ports return immutable facts only and do not create edit, load, frame,
spatial, resource, interaction, or Flutter behavior.

### Ownership

`CanvasRuntime` remains the public facade and delegates lifecycle, reads, state,
and P4-supported ports to `RuntimeRoot`. `RuntimeRoot` owns service
composition, runtime-owned counters, disposed admission, `ValueNotifier` state
publication, and public facade wiring. `DocumentStoreKernel` owns the admission
state that backs collision-aware runtime id generation.
`DocumentStoreKernel` owns `CommittedDocument`, `ElementRegistry`,
`FamilyTables`, `LayerTable`, `RevisionState`, `DocumentProjectionCache`, id
admission facts, and committed document summary facts. `SelectionKernel` owns
selected ids and `selectionRevision`. Runtime read-port files under
`lib/src/runtime/**` own the immutable query seams; they do not own concrete
store or selection internals.
Tests own executable proof, and `tool/guardrails/**` owns reusable guardrail
enforcement and runner dispatch.

### Seam

The primary seams are:

```text
CanvasRuntime public facade -> RuntimeRoot -> DocumentStoreKernel
CanvasRuntime.readDocument -> DocumentProjectionCache -> public CanvasDocument
RuntimeRoot -> SelectionKernel -> SelectionFactsPort
RuntimeRoot -> SelectionKernel -> SelectionNormalizationPort
FrameEngine/later owners -> FrameFactsPort -> DocumentStoreKernel
Later interaction/spatial/resource owners -> narrow immutable read ports
```

These seams expose only public DTOs at public boundaries and immutable facts at
internal read boundaries. They do not expose mutable store tables, public
document projection internals, drafts, selection internals, mutation APIs,
frame render models, resource sessions, or Flutter widget state.

### Dependency Direction

`lib/src/api/canvas_runtime.dart` may depend on `lib/src/runtime/runtime_root.dart`
as the public facade implementation detail. `lib/src/runtime/**` may compose
`lib/src/store/**`, `lib/src/selection/**`, public API value owners, and
diagnostic config value owners. `lib/src/store/**` may depend on public DTO
types for input/projection and shared public validators, but must not import
interaction, frame, Flutter bridge, or concrete selection owner internals.
`lib/src/selection/**` may receive immutable document facts through runtime
composition, but must not store committed document content. Future frame,
interaction, spatial, and resource owners must depend on narrow runtime ports,
not concrete store or selection internals. Production `lib/**` must not import
`tool/**` or `test/**`.

### State and Data Ownership

Committed document membership, order, resources, persisted metadata, persisted
camera, internal revision facts, and projection revision are store-owned.
Runtime view camera, public state publication, public runtime summary assembly,
runtime config materialization, disposed state, and public id-generation facade
routing are runtime-root-owned. Id collision/admission facts are store-owned.
Selected ids and `selectionRevision` are selection-owned and
never stored in `CommittedDocument`, schema v1, `CanvasDocument`, or projection
cache. Public `CanvasRuntimeState` snapshots are runtime-owned immutable
publication values assembled from owner facts. `CanvasDocument` returned by
`readDocument` is a projection, not live state. P4's public selection surface is
limited to runtime-view selection operations: `selectedElementIds`,
`setSelection`, `toggleSelection`, `clearSelection`, and `selectAll`. The
document-mutating selection commands `moveSelection`,
`rotateSelectionClockwise`, `rotateSelectionCounterClockwise`,
`flipSelectionVertical`, `flipSelectionHorizontal`, and `deleteSelection` stay
rejected until the later edit/command phases own document mutation and action
events.

### Entry and Exit Boundaries

Runtime construction must validate and materialize the initial document and
runtime config before exposing state. `readDocument` exits through
`DocumentProjectionCache` and returns a public immutable projection. Dispose
exits by leaving `state.value` readable, suppressing notifications after
dispose returns, and making repeated dispose silent. P4 mutating operations that
belong to later phases must remain rejected with clear placeholder behavior
instead of partially mutating runtime state. P4 selection-only operations enter
through public `CanvasSelectionPort`, normalize to eligible content ids through
store-owned immutable facts, publish selection revision changes only when
membership changes, and exit without document revision or projection eviction.
Internal query ports exit through immutable facts only.

### Verification Strategy

P4 verification combines owner-seam behavior tests, structural guardrail tests,
guardrail runner dispatch, and broad repository checks. Test forms are selected
from `docs/verification/tests.md`; guardrail patterns are selected from
`docs/verification/guardrail_design_patterns.md`. Future-only proof branches
for edit/load/interaction/frame/spatial/resource behavior must be named as
deferred broad verification instead of implemented as placeholders.

### Required Donor Adaptation

| Donor id | P4 adaptation target | Slice ownership | Proof |
|---|---|---|---|
| `store_scene_controller_read_paths` | Adapt committed read, row/candidate resolve, descriptor lookup, and stale structuralRevision/generation rejection into store-owned immutable query-port facts; do not copy the controller facade shell. | Slice 2 for committed store facts and Slice 4 for document/frame read ports. | P2, P4 |
| `dto_node_boundary_mapping` | Keep codec-owned validated DTO family mapping under the existing P3 codec boundary, and adapt only the store-side mapping from public DTO families into committed row/fact families; do not move codec ownership into runtime/store and do not copy legacy node names or runtime shapes. | Slice 2 store tables, Slice 4 read-port fact projection, and P12 codec boundary verification. | P2, P4, P12 |
| `dto_document_helpers` | Adapt pure document summary/projection and selection normalization helper behavior under the store and selection owners; do not copy ownership that conflicts with the store/selection/edit split. | Slice 2 document summary/projection and Slice 3 selection normalization. | P2, P3 |

### Decision Ledger

| ID | Decision | Owner | Proof |
|---|---|---|---|
| D1 | Runtime construction, state publication, lifecycle, and config materialization are composed once behind `CanvasRuntime` by `RuntimeRoot`. | `lib/src/runtime/**` with facade wiring in `lib/src/api/canvas_runtime.dart` | P1, P5, P9 |
| D2 | Committed document facts and id admission facts are store-owned compact tables; public `CanvasDocument` is a lazy projection, not live runtime state, and runtime id generation is collision-aware through store admission. | `lib/src/store/**` with id-generation facade routing in `lib/src/api/canvas_runtime.dart` and `lib/src/runtime/**` | P2, P6, P9 |
| D3 | Selection ids and `selectionRevision` are owned by `SelectionKernel`, separate from committed document, schema, public document DTOs, and projection cache. | `lib/src/selection/**` and runtime selection facts ports | P3, P7, P9 |
| D4 | Later owners receive committed document and selection facts only through narrow immutable query ports, including `FrameFactsPort`; no later owner imports concrete store or selection internals. | `lib/src/runtime/**`, `tool/guardrails/**` | P4, P6, P7, P9 |
| D5 | P4 guardrails use the selected pattern ids from `docs/verification/guardrail_design_patterns.md`, and P4 tests use selected forms from `docs/verification/tests.md`. | `test/**`, `tool/guardrails/**` | P5, P6, P7, P8, P9 |

### Rejected Alternatives

- Keep `CanvasDocument` as live runtime state and return the same instance from
  `readDocument`: rejected because it violates `store.no_public_document_live_state`
  and makes projection/cache ownership impossible.
- Store selected ids in `CommittedDocument`, schema v1, or public document
  projection: rejected because selection is runtime view state owned by
  `SelectionKernel`.
- Expose concrete `DocumentStoreKernel`, `CommittedDocument`, family tables, or
  `SelectionKernel` internals to frame/interaction/spatial/resource code:
  rejected because later owners must depend on immutable intent-specific read
  ports.
- Implement edit/load/frame/spatial/resource/interaction behavior in P4 to make
  broad tests easier: rejected because P4 is the runtime spine phase and must
  not become a hidden infrastructure-plus-feature phase.
- Copy whole legacy controller, interactive runtime, scene builder, scene codec,
  or store controller structure: rejected by donor registry and P4 forbidden
  donor structure.

## 4. Execution Guardrails

### Required Order

1. Install failing or tightening P4 tests and guardrail fixtures before replacing
   the placeholder runtime behavior they prove.
2. Build `RuntimeRoot` lifecycle/state/config foundation before
   routing public facade methods to store or selection owners.
3. Build committed store tables and projection cache before changing
   `CanvasRuntime.readDocument` away from the placeholder live-document return
   or removing the facade's direct document ownership, and before implementing
   collision-aware runtime id generation.
4. Add selection owner and immutable selection facts after store identity/order
   facts exist, so selection normalization does not duplicate document state.
5. Add frame/document/selection read ports after the owning store and selection
   facts exist, and before any future owner is allowed to consume those facts.
6. Add each P4 guardrail runner entry and structural check inside the same
   slice that introduces or retires the seam it protects, before that slice can
   close.
7. Run blocking-suite consolidation after the slice-local guardrail proofs are
   executable.
8. Update step checkboxes in this file and root `PLAN.md` only after all P4
   proof commands pass.

### Cross-Slice Constraints

- Every file that stores runtime state must have exactly one owner; do not add
  synchronization glue between duplicate state sources.
- `CanvasDocument` projection may be cached, but the invariant is that store
  facts own truth and projection is invalidated by projection revision.
- Runtime config materialization may read public validated config values but
  must not duplicate schema/codec validation ownership.
- P4 may expose read/query ports for later owners, but must not implement later
  owner workflows.
- Diagrams listed by the P4 phase are read-only inputs for this contract. P4
  must implement the already documented runtime graph; if implementation
  evidence contradicts a listed diagram, stop and revise the contract/source
  documentation before continuing instead of deciding diagram edits during
  implementation.
- Future-only branches named by `docs/verification/tests.md` must be deferred
  explicitly when their owners do not exist yet; tests must not add skipped,
  vacuous, or placeholder assertions.

### Seam Migration

| Seam | Migration Order | Retirement Gate |
|---|---|---|
| Placeholder `CanvasRuntime` direct public document field to `RuntimeRoot` + `DocumentStoreKernel` + `DocumentProjectionCache` | Add owner tests, build runtime/store/projection owners, route public facade to root, remove direct `_document` live-state ownership from `CanvasRuntime`. | `readDocument` projection tests and `store.no_public_document_live_state` guardrail pass, and no production runtime code stores a live mutable public document as committed state. |
| P0 `RuntimeRoot` skeleton to composed runtime root | Add runtime lifecycle/state tests, implement composition, route public facade, keep `core.single_runtime_root` green. | `core.single_runtime_root` runner proof passes and production declares exactly one `RuntimeRoot`. |
| No selection owner to `SelectionKernel` + immutable selection facts ports | Add selection separation proof, implement `selectedElementIds`, `setSelection`, `toggleSelection`, `clearSelection`, and `selectAll`, and keep document-mutating selection commands rejected until later edit/command phases. | `selection.owner_separate_from_document` guardrail and `test/selection/runtime_owner_separation_test.dart` pass for P4-owned selection behavior, including negative proof that selected ids are not stored in committed document or projection state. |
| Direct future owner reads to immutable query ports | Create `FrameFactsPort` and P4 read facts before future owner consumption. | Structural guardrails prove frame/interaction-style owners cannot import concrete store/selection internals where those owners exist; P4 documents deferred checks for owners not created yet. |

### Forbidden Moves

- Do not add `SceneController`, `SceneSnapshot`, `NodeSpec`, `NodePatch`,
  `PatchField`, legacy public schema entrypoints, legacy runtime fallback, or
  app adapter types to production runtime.
- Do not export `RuntimeRoot`, store tables, selection internals, or read-port
  implementation classes from `lib/iwb_canvas_engine.dart`.
- Do not let `lib/src/store/**` import interaction, frame, Flutter bridge, or
  concrete selection internals.
- Do not let `lib/src/selection/**` store committed document content or expose
  selected order as an independent source of truth.
- Do not let `FrameFactsPort` return public `CanvasDocument`, store tables,
  drafts, mutation APIs, selection facts, or frame-owned render models.
- Do not broaden DCM suppressions to hide metrics without a nearby
  architecture/readability reason.

### Deferred Broad Verification

- `test.runtime.load_document_state_publication` remains deferred to P6 because
  P4 does not implement `loadDocument`.
- Edit/command-driven branches of `test.runtime.runtime_state_publication`
  remain deferred to implementation phases P5, P10, and P12 because P4 does not
  implement edit sessions or command commits.
- Document replacement, delete, clear, and eraser branches named under
  `test.selection.runtime_owner_separation` remain deferred to their owning
  edit/load/interaction phases; P4 closes the selection-owner foundation and
  selection-only separation proof.
- Pointer, hit-test, main paint, and overlay paint hot-path branches of
  `projection.only_explicit_read_paths` remain deferred until those owners
  exist; P4 closes the explicit read/projection-cache owner proof and structural
  bypass checks available in this phase.
- Frame-consuming `FrameFactsPort` guardrail proof remains deferred to the frame
  phase where `lib/src/frame/**` consumers exist; P4 must still create the port
  with an immutable facts-only surface.

## 5. Proof Plan

### Guardrail Pattern Selection

| Guardrail id | Pattern from `guardrail_design_patterns.md` | P4 proof obligation |
|---|---|---|
| `core.single_runtime_root` | Primary `resolved_element_identity`, secondary `parsed_ast_directive` | Prove production declarations resolve to exactly one `RuntimeRoot` owner after composition. |
| `store.no_public_document_live_state` | Primary `behavioral_seam_test`, secondary `resolved_element_identity` | Prove store/public projection behavior and block concrete live public document storage as committed state. |
| `selection.owner_separate_from_document` | Primary `resolved_element_identity`, secondary `behavioral_seam_test` | Prove selected ids and `selectionRevision` are selection-owned and not stored in committed document/projection/schema facts. |
| `projection.only_explicit_read_paths` | Primary `behavioral_seam_test`, secondary `resolved_element_identity` and `parsed_ast_directive` | Prove projection cache builds only through explicit P4 read paths and add structural protection against bypass calls where P4 owners exist. |

### Test Form Selection

| Test id | Test file | Form from `tests.md` | P4 responsibility |
|---|---|---|---|
| `test.runtime.dispose_lifecycle` | `test/runtime/dispose_lifecycle_test.dart` | In-package unit and behavior test | Prove dispose state readability, notification cutoff, repeated dispose silence, and no document revision increment. |
| `test.runtime.runtime_state_publication` | `test/runtime/runtime_state_publication_test.dart` | External consumer behavior test for public state readability, plus only P4-owned in-package behavior if internal counters are needed | Preserve public consumer proof for initial `CanvasRuntimeState`; remove placeholder live-document expectations that conflict with projection ownership. |
| P4 contract-local runtime config materialization proof | `test/runtime/runtime_config_materialization_test.dart` | In-package unit and behavior test | Prove runtime materialization preserves already validated `CanvasDiagnosticsVerbose` preview/list limits without moving schema or codec ownership into `RuntimeRoot`. |
| P4 contract-local runtime id generation proof | `test/runtime/runtime_id_generation_test.dart` | In-package unit and behavior test | Prove `generateElementId`, `generateLayerId`, and `generateResourceId` produce stable prefixes, advance monotonically within one runtime, are unique within the current runtime, and skip ids already present in the initial committed document. |
| P4 contract-local document summary proof | `test/runtime/document_summary_publication_test.dart` | In-package unit and behavior test | Prove `CanvasDocumentSummary` and `CanvasRuntimeSummary` are coherent projections of the same committed store facts. |
| `test.store.read_document_projection` | `test/store/read_document_projection_test.dart` | In-package unit and behavior test | Prove `readDocument` returns committed DTO state through the projection cache. |
| `test.store.no_projection_hot_path` | `test/store/no_projection_hot_path_test.dart` | Guardrail/behavioral proof test with owner-seam counters; shared scanner logic belongs in `tool/guardrails/**` if needed | Prove P4 projection counters are touched only by explicit read paths; later pointer/hit/paint branches are deferred. |
| `test.store.public_document_is_projection_only` | `test/store/public_document_is_projection_only_test.dart` | In-package unit and behavior test | Prove public document DTOs are projection-only and cannot mutate committed store state. |
| `test.selection.runtime_owner_separation` | `test/selection/runtime_owner_separation_test.dart` | In-package unit and behavior test | Prove P4 selection owner separation, `selectionRevision` independence from document revision, and no projection/cache ownership of selected ids. |
| P4 contract-local read-port surface proof | `test/guardrails/runtime_read_port_surface_test.dart` | Guardrail test | Prove P4-created read ports, especially `FrameFactsPort`, expose immutable facts only and do not leak public projections, store tables, drafts, mutation APIs, selection facts, or frame render models. |
| P4 contract-local read-port committed facts proof | `test/runtime/runtime_read_ports_test.dart` | In-package unit and behavior test | Prove document, frame, and selection read/query ports return committed facts from `DocumentStoreKernel` and `SelectionKernel`, including frame capture revisions, row resolution, descriptor snapshots, and stale structuralRevision/generation rejection where P4 facts exist. |
| `test.guardrails.blocking_suite` | `test/guardrails/blocking_suite_test.dart` | Guardrail test | Prove new P4 executable guardrail ids are represented in runner inventory and selectable. |

### P1. Runtime State, Config, And Lifecycle Proof

Proves D1 public runtime lifecycle, disposed-state behavior, and P4-owned public
state/config publication semantics before store-dependent projection facts are
introduced.

```sh
dart test test/runtime/dispose_lifecycle_test.dart test/runtime/runtime_state_publication_test.dart test/runtime/runtime_config_materialization_test.dart
```

Expected signal: tests pass with no post-dispose notifications, readable final
state, no dispose document revision bump, preserved validated diagnostics
verbose preview/list limits, and no placeholder live-document state assertion.

### P2. Store Projection And Admission Proof

Proves D2 committed store projection, explicit public read path, projection
cache ownership, and store-admission-backed runtime id generation.

```sh
dart test test/store/read_document_projection_test.dart test/store/no_projection_hot_path_test.dart test/store/public_document_is_projection_only_test.dart test/runtime/document_summary_publication_test.dart test/runtime/runtime_id_generation_test.dart
```

Expected signal: tests pass and projection counters show only explicit read
paths build public `CanvasDocument` projections, while `CanvasDocumentSummary`
and `CanvasRuntimeSummary` remain coherent projections of committed store facts,
and generated ids have stable prefixes with no collisions against initial
committed ids.

### P3. Selection Owner Proof

Proves D3 selection ownership separation for P4-owned behavior.

```sh
dart test test/selection/runtime_owner_separation_test.dart
```

Expected signal: tests pass and selection-only behavior advances selection facts
without advancing document revision or placing selected ids in public document
projection state.

### P4. Runtime Read-Port Structural Proof

Proves D4 immutable query-port boundaries, P4 read-port public/internal surface,
and import-direction constraints available in P4.

```sh
dart test test/guardrails/import_boundaries_test.dart
dart test test/guardrails/runtime_read_port_surface_test.dart
dart test test/runtime/runtime_read_ports_test.dart
```

Expected signal: tests pass with concrete store/selection internals blocked
outside approved owner and query-port boundaries, and `FrameFactsPort` plus P4
document/selection read ports expose immutable facts without `CanvasDocument`,
store tables, drafts, mutation APIs, selection facts on the frame port, or frame
render models. The same proof shows P4 read ports return committed facts from
store/selection owners, including frame-facing revisions, row resolution,
descriptor snapshots, and stale structuralRevision/generation rejection where
P4 facts exist.

### P5. Runtime Root Guardrail Proof

Proves the runtime-root seam migration keeps exactly one production root.

```sh
dart run tool/guardrails/run.dart --guardrail=core.single_runtime_root
```

Expected signal: `core.single_runtime_root` is selectable through the runner and
executes the intended resolved-identity proof.

### P6. Store And Projection Guardrail Proof

Proves the store/projection seam migration has owner-level guardrail proof.

```sh
dart run tool/guardrails/run.dart --guardrail=store.no_public_document_live_state
dart run tool/guardrails/run.dart --guardrail=projection.only_explicit_read_paths
```

Expected signal: both guardrail ids are selectable through the runner and
execute their intended behavioral/structural proof, including negative proof
that retired direct `_document` live-state ownership and non-explicit projection
build paths are absent from production runtime/store code.

### P7. Selection Owner Guardrail Proof

Proves the selection-owner seam migration has owner-level guardrail proof.

```sh
dart run tool/guardrails/run.dart --guardrail=selection.owner_separate_from_document
```

Expected signal: `selection.owner_separate_from_document` is selectable through
the runner and executes its intended resolved-identity/behavioral proof,
including negative proof that selected ids are absent from committed document,
schema, public document projection, and projection-cache state.

### P8. P4 Blocking Suite Proof

Proves P4 guardrail ids participate in the blocking runner inventory and
selection modes after the slice-local guardrail proofs exist.

```sh
dart test test/guardrails/blocking_suite_test.dart
```

Expected signal: every P4 guardrail id participates in the blocking suite
without unknown-id or empty-suite behavior.

### P9. Broad Repository Code Proof

Proves the current slice's code changes integrate with the package analyzer,
DCM rules, and metrics policy. Run this after each slice that changes code, and
again at the final gate.

```sh
dart analyze
dcm analyze .
dcm calculate-metrics .
```

Expected signal: all commands pass, except for explicit local metrics
suppressions that include the required nearby architecture/readability reason.

### P10. Public API Compatibility Proof

Proves P4 did not change Public API v1 signatures, exports, or public type
reference rules while replacing placeholder behavior.

```sh
dart test test/api_contract/public_exports_complete_test.dart test/api_contract/public_types_complete_test.dart test/api_contract/public_api_v1_compiles_as_written_test.dart test/api_contract/no_undefined_public_type_references_test.dart
```

Expected signal: existing Public API v1 contract tests pass without export,
signature, or undefined-type drift.

### P11. Forbidden Donor Structure Negative Proof

Proves P4 did not introduce forbidden legacy imports, public/controller shapes,
or whole donor structures from the P4 avoid-list into production code. This
negative proof does not forbid the targeted adaptations listed in Required Donor
Adaptation; those adaptations are proved by P2, P3, and P4.

```sh
dart run tool/guardrails/run.dart --guardrail=core.no_legacy_imports
dart run tool/guardrails/run.dart --guardrail=core.no_scene_controller_shape_dependency
dart run tool/guardrails/run.dart --guardrail=core.no_node_spec_patch_shape_dependency
! rg -n "SceneController|SceneSnapshot|NodeSpec|NodePatch|PatchField|SceneBuilder|SceneCodec|SceneStoreController|InteractiveRuntime|scene_controller|scene_snapshot|node_spec|node_patch|patch_field|scene_builder|scene_codec|scene_store_controller|interactive_runtime" lib
! sh -c 'rg --files lib | rg "(scene_controller|scene_snapshot|node_spec|node_patch|patch_field|scene_builder|scene_codec|scene_store_controller|interactive_runtime)"'
```

Expected signal: the guardrails pass, and the bounded production search returns
no content or file-name matches for the named forbidden donor structures.

### P12. Codec Mapping Boundary Proof

Proves the `dto_node_boundary_mapping` donor keeps codec-owned validated DTO
family mapping under the existing codec boundary while P4 adds only store/read
mapping ownership.

```sh
dart test test/codec/schema_v1/known_fields_validation_test.dart test/codec/schema_v1/canonical_encode_roundtrip_test.dart test/codec/decode_encode_no_runtime_side_effects_test.dart
dart run tool/guardrails/run.dart --guardrail=codec.no_runtime_side_effects
```

Expected signal: codec schema v1 mapping and no-runtime-side-effect proofs stay
green, and runtime/store P4 work has not moved codec ownership or mutation into
the runtime/store owners.

### P13. Roadmap Documentation Closure Proof

Proves roadmap checkbox updates keep documentation structure and generated
context capsules valid after P1 through P12 have already passed.

```sh
dart run docs/tool/generate_context_capsules.dart --check
dart run docs/tool/check_docs.dart
```

Expected signal: both documentation checks pass after `PLAN.md` and this step
contract are marked complete.

## 6. Vertical Slices

### Slice 1. [ ] Runtime root lifecycle and public state foundation

#### Implements

D1

#### Obligations Covered

SEAM_MIGRATION

#### Files

- Primary runtime composition: `lib/src/runtime/runtime_root.dart` — replace the
  P0 skeleton with the composition root for P4 owners, lifecycle, state holder,
  config materialization, and disposed guard.
- Proposed runtime config owner: `lib/src/runtime/runtime_config.dart` — hold
  runtime-materialized config values and diagnostic verbose limits without
  moving codec/schema ownership.
- Public facade wiring: `lib/src/api/canvas_runtime.dart` — delegate P4-supported
  construction, `state`, and dispose behavior to `RuntimeRoot` while leaving
  document reads, runtime id generation, and later-phase ports for their owning
  slices.
- Runtime lifecycle proof: `test/runtime/dispose_lifecycle_test.dart` — verify
  dispose behavior at the public runtime seam.
- Runtime state proof alignment: `test/runtime/runtime_state_publication_test.dart`
  — preserve public consumer state readability proof and remove live-document
  placeholder expectations.
- Runtime config materialization proof:
  `test/runtime/runtime_config_materialization_test.dart` — verify
  `CanvasRuntimeConfig` materialization preserves already validated diagnostic
  verbose preview/list limits.
- Runtime-root guardrail runner entry:
  `tool/guardrails/src/guardrail_registry.dart` — keep
  `core.single_runtime_root` represented for the runtime-root migration.
- Runtime-root guardrail dispatch:
  `tool/guardrails/src/guardrail_executor.dart` — keep
  `core.single_runtime_root` dispatching the single-root proof after
  composition.
- Runtime-root guardrail proof: `test/guardrails/single_runtime_root_test.dart`
  — prove the composed runtime still has exactly one production root.

#### Change

Runtime construction creates one root-owned runtime spine. `CanvasRuntime.state`
is backed by root-owned immutable snapshots, dispose is idempotent, final
`state.value` remains readable, no state notification occurs after dispose
returns, and config materialization remains runtime-root-owned.

#### Proof

Run P1 and P5 for slice-local behavior and structural proof, then P9 after this
slice's code changes.

#### Closure

All P4-supported runtime lifecycle/state/config behavior routes through
`RuntimeRoot`, without changing the document read or id-generation seams before
Slice 2 owns the store/projection/admission replacement.

### Slice 2. [ ] Committed document store and projection cache

#### Implements

D2

#### Obligations Covered

SEAM_MIGRATION

#### Files

- Proposed store owner: `lib/src/store/document_store_kernel.dart` — own
  committed document installation, summary facts, projection invalidation, and
  public projection reads.
- Proposed committed document model: `lib/src/store/committed_document.dart` —
  own compact committed document aggregate and admission state.
- Proposed registry owner: `lib/src/store/element_registry.dart` — own element
  handles, generations, families, order tokens, and revision facts needed by P4
  reads.
- Proposed family table owner: `lib/src/store/family_tables.dart` — own
  family-specific compact row tables mapped from public DTO families.
- Proposed layer table owner: `lib/src/store/layer_table.dart` — own content
  layer membership and order facts.
- Proposed revision owner: `lib/src/store/revision_state.dart` — own private
  committed document revision facts and public projection revision.
- Proposed projection owner: `lib/src/store/document_projection_cache.dart` —
  own lazy public `CanvasDocument` projection caching and counters/probe hooks
  needed for proof.
- Verify-only donor registry: `docs/_registry/donors.yaml` — confirms
  `store_scene_controller_read_paths`, `dto_node_boundary_mapping`, and
  `dto_document_helpers` are allowed P4 adaptations for this slice while whole
  legacy owner structures remain forbidden.
- Codec mapping boundary proof:
  `test/codec/schema_v1/known_fields_validation_test.dart`,
  `test/codec/schema_v1/canonical_encode_roundtrip_test.dart`, and
  `test/codec/decode_encode_no_runtime_side_effects_test.dart` — verify
  codec-owned DTO family mapping remains under the codec boundary while P4 adds
  store-side mapping.
- Store projection proof: `test/store/read_document_projection_test.dart` —
  verify `readDocument` projection matches committed DTO state.
- Projection hot-path proof: `test/store/no_projection_hot_path_test.dart` —
  verify projection cache builds only through explicit P4 read paths and expose
  deferred later hot-path branches.
- Public document projection proof:
  `test/store/public_document_is_projection_only_test.dart` — verify public DTO
  projection cannot mutate committed store state.
- Runtime/document summary proof:
  `test/runtime/document_summary_publication_test.dart` — verify
  `CanvasDocumentSummary` and `CanvasRuntimeSummary` are coherent projections of
  committed store facts.
- Public facade read routing: `lib/src/api/canvas_runtime.dart` — move
  `readDocument` away from direct live-document return only after store and
  projection cache owners exist.
- Runtime id generation facade routing: `lib/src/api/canvas_runtime.dart` and
  `lib/src/runtime/runtime_root.dart` — route `generateElementId`,
  `generateLayerId`, and `generateResourceId` through store-owned admission
  facts after the initial committed document is admitted.
- Runtime id generation proof: `test/runtime/runtime_id_generation_test.dart` —
  verify element, layer, and resource id generation sequence, runtime-local
  uniqueness, and collision avoidance against initial committed ids.
- Store/projection guardrail runner entries:
  `tool/guardrails/src/guardrail_registry.dart` — add
  `store.no_public_document_live_state` and
  `projection.only_explicit_read_paths` to the blocking inventory and suites.
- Store/projection guardrail dispatch:
  `tool/guardrails/src/guardrail_executor.dart` — dispatch the store and
  projection guardrails to their owning behavioral/structural proof.
- Store/projection guardrail checks: `tool/guardrails/src/core_boundary_checks.dart`
  and proposed focused helper
  `tool/guardrails/src/store_projection_checks.dart` — own reusable
  scanner/resolver logic for `store.no_public_document_live_state` and
  `projection.only_explicit_read_paths`.

#### Change

Initial documents are admitted into store-owned committed and id-admission
facts. Public `CanvasDocument` is materialized lazily from committed store facts
through `DocumentProjectionCache`, generated ids use the same admission owner to
avoid collisions, and mutation of returned public DTO instances cannot change
store truth. The public facade no longer owns committed document state directly
after this slice.

#### Proof

Run P2 and P6 for slice-local behavior and structural proof, then P9 after this
slice's code changes.

#### Closure

`CanvasRuntime.readDocument` returns a projection that matches committed state,
and no P4 runtime/store path treats public `CanvasDocument` as live committed
state.

### Slice 3. [ ] Selection owner and selection facts boundary

#### Implements

D3

#### Obligations Covered

SEAM_MIGRATION

#### Files

- Proposed selection owner: `lib/src/selection/selection_kernel.dart` — own
  selected ids, selection normalization foundation, and `selectionRevision`.
- Proposed selection read seam: `lib/src/runtime/selection_facts_port.dart` —
  expose immutable selection facts for runtime and future owners without
  exposing `SelectionKernel` internals.
- Proposed selection normalization seam:
  `lib/src/runtime/selection_normalization_port.dart` — expose runtime-owned
  normalization requests to `SelectionKernel` without making document state or
  selected-order cache a second source of truth.
- Verify-only donor registry: `docs/_registry/donors.yaml` — confirms
  `dto_document_helpers` is an allowed P4/P5 adaptation for pure selection
  helper behavior, while ownership that conflicts with the store/selection/edit
  split remains forbidden.
- Public facade wiring: `lib/src/api/canvas_runtime.dart` — expose a P4
  `CanvasSelectionPort` implementation for `selectedElementIds`,
  `setSelection`, `toggleSelection`, `clearSelection`, and `selectAll`; keep
  `moveSelection`, `rotateSelectionClockwise`,
  `rotateSelectionCounterClockwise`, `flipSelectionVertical`,
  `flipSelectionHorizontal`, and `deleteSelection` rejected until later
  edit/command phases own document mutation and action events.
- Selection separation proof:
  `test/selection/runtime_owner_separation_test.dart` — verify P4 selection
  facts are separate from document revision, committed document content, and
  projection cache ownership; verify selection-only operations normalize to
  eligible content ids, advance `selectionRevision` only on membership changes,
  do not increment document revision, do not evict projection cache, and leave
  later document-mutating selection commands rejected without effects.
- Selection guardrail runner entry:
  `tool/guardrails/src/guardrail_registry.dart` — add
  `selection.owner_separate_from_document` to the blocking inventory and suites.
- Selection guardrail dispatch:
  `tool/guardrails/src/guardrail_executor.dart` — dispatch the selection
  guardrail to its owning structural/behavioral proof.
- Selection guardrail checks: `tool/guardrails/src/core_boundary_checks.dart`
  and proposed focused helper
  `tool/guardrails/src/selection_boundary_checks.dart` — own reusable
  scanner/resolver logic for `selection.owner_separate_from_document`.

#### Change

Selection becomes runtime view state owned by `SelectionKernel`. Selected ids
and `selectionRevision` do not live in `CommittedDocument`, schema, public
`CanvasDocument`, or projection cache state. P4 public selection operations are
locked to selection membership only; transform/delete selection commands remain
out of scope and rejected.

#### Proof

Run P3 and P7 for slice-local behavior and structural proof, then P9 after this
slice's code changes.

#### Closure

P4 selection state has one owner and can be read only through an immutable
selection facts seam.

### Slice 4. [ ] Immutable document and frame facts read ports

#### Implements

D4

#### Obligations Covered

SEAM_MIGRATION

#### Files

- Proposed document facts seam: `lib/src/runtime/document_facts_port.dart` —
  expose immutable P4 document facts for later spatial/resource/interaction
  adoption without concrete store access.
- Proposed frame facts seam: `lib/src/runtime/frame_facts_port.dart` — expose
  immutable committed frame facts for future capture, row resolution, descriptor
  snapshots, and revision reads without frame-owned render models.
- Store integration: `lib/src/store/document_store_kernel.dart` — implement the
  backing facts needed by P4 read ports without exposing mutable tables.
- Verify-only donor registry: `docs/_registry/donors.yaml` — confirms
  `store_scene_controller_read_paths` and `dto_node_boundary_mapping` are
  allowed P4 adaptations for read-port facts while legacy controller/node
  structures remain forbidden.
- Boundary proof: `test/guardrails/import_boundaries_test.dart` — extend only
  where P4 creates enforceable concrete store/selection/query-port boundaries.
- Read-port surface proof: `test/guardrails/runtime_read_port_surface_test.dart`
  — verify P4 read-port declarations expose immutable fact types only and that
  `FrameFactsPort` does not expose public document projection, store tables,
  drafts, mutation APIs, selection facts, or frame render models.
- Read-port committed facts proof: `test/runtime/runtime_read_ports_test.dart`
  — verify document, frame, and selection read/query ports return committed
  facts from their owners, including frame capture revisions, row resolution,
  descriptor snapshots, and stale structuralRevision/generation rejection where
  P4 facts exist.

#### Change

Later phases receive narrow read seams with immutable fact DTOs. The seams are
present before later owners need them, and they do not leak public document
projection, mutable store tables, drafts, selection internals, or frame render
models. Required donor behavior is adapted only as committed fact/read-port
behavior, not as legacy owner structure.

#### Proof

Run P4 for structural boundary proof, then P9 after this slice's code changes.

#### Closure

The P4 read-port surface is available, its declarations are immutable and
facts-only, and future owners can adopt it without importing concrete store or
selection internals.

### Slice 5. [ ] P4 guardrail blocking-suite consolidation

#### Implements

D5

#### Obligations Covered

SEAM_MIGRATION

#### Files

- Guardrail runner inventory finalization:
  `tool/guardrails/src/guardrail_registry.dart` — verify the P4 ids and
  structural proof entries added by slices 1 through 4 are represented in the
  blocking inventory and suites where applicable.
- Guardrail dispatch finalization: `tool/guardrails/src/guardrail_executor.dart`
  — verify the P4 ids and structural proof entries added by slices 1 through 4
  dispatch to their owning tests/checks without duplicating behavior.
- Single-root proof: `test/guardrails/single_runtime_root_test.dart` — keep
  `core.single_runtime_root` green after runtime composition.
- Blocking-suite proof: `test/guardrails/blocking_suite_test.dart` — prove P4
  guardrail ids are represented and selectable.
- Store/selection/projection proof tests:
  `test/store/read_document_projection_test.dart`,
  `test/store/no_projection_hot_path_test.dart`,
  `test/store/public_document_is_projection_only_test.dart`, and
  `test/selection/runtime_owner_separation_test.dart` — serve as behavioral
  seam proofs for their guardrails where selected by the runner.

#### Change

The P4 guardrail ids already added by their owning migration slices are
consolidated into the blocking suite. Behavioral invariants stay in tests;
reusable structural scanner or resolver logic stays under `tool/guardrails/**`.

#### Proof

Run P8 for blocking-suite consolidation, then P9 after this slice's tooling/test
changes.

#### Closure

Every P4 guardrail id is selectable through the runner, has an owner-level proof
matching the selected pattern, and is included in the blocking suite.

### Slice 6. [ ] Roadmap closure after final gate

#### Implements

D1, D2, D3, D4, D5

#### Files

- Step contract finalization:
  `plan/step_24_p4_runtime_spine_store_and_projection_cache.md` — mark this
  step's slice checkboxes complete only after implementation proof passes.
- Roadmap index: `PLAN.md` — mark Step 24 complete only in the same change that
  marks this step contract complete.

#### Change

After P1 through P12 have passed, the roadmap accurately records P4 as complete.
This slice owns only checkbox finalization; it does not own or duplicate the
implementation proof surfaces.

#### Proof

Prerequisite: P1 through P12 have passed. After editing only the roadmap
checkboxes, run P13.

#### Closure

P1 through P12 have passed, the roadmap checkbox state matches the implemented
state, and P13 passes after the checkbox update.

## 7. Final Gate

### Run Proof Set

- P1
- P2
- P3
- P4
- P5
- P6
- P7
- P8
- P9
- P10
- P11
- P12
- P13

### Done When

- D1 through D5 have passing proof.
- The `SEAM_MIGRATION` obligation is satisfied by slices 1 through 5.
- P5 through P8 prove every P4 guardrail uses the selected pattern from section
  5 and is executable through the guardrail runner.
- Section 5 test forms are honored, and future-only branches are explicitly
  deferred rather than skipped or faked.
- P10 proves Public API v1 signatures and exports remain compatible.
- P11 proves no forbidden legacy structure is introduced.
- P12 proves codec-owned DTO family mapping remains under the codec boundary
  while P4 adds only store/read mapping ownership.
- P13 proves roadmap documentation remains structurally valid after completion
  checkboxes are updated.
- Required donors `store_scene_controller_read_paths`,
  `dto_node_boundary_mapping`, and `dto_document_helpers` are adapted only in
  their slice-owned target forms and have passing P2, P3, P4, or P12 proof.
- Root `PLAN.md` and this step contract are marked complete only after all
  implementation proof passes.
- No out-of-scope files were changed.
