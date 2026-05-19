# Change Contract

Contract Mode: FULL
Contract Profile: SOURCE_OF_TRUTH_DOCS
Contract Obligations: SEAM_MIGRATION

## 1. Mandate and Boundary

### Mandate

Introduce `FrameFactsPort` as the accepted committed-state read boundary between
`FrameEngine` and `DocumentStoreKernel` for frame capture, render-row
resolution, and resource descriptor snapshots.

### In Scope

- Add `FrameFactsPort` to the target architecture as the frame-intent committed
  facts query boundary.
- Replace accepted source-of-truth relationships that allow
  `FrameEngine -> DocumentStoreKernel` committed frame reads with
  `FrameEngine -> FrameFactsPort -> DocumentStoreKernel`.
- Define the frame-facing facts available through the port:
  `documentRevision`, `structuralRevision`, `boundsRevision`,
  `elementVisualRevision`, `backgroundRevision`, `gridRevision`, immutable
  committed render-row snapshots, stale row rejection by captured
  `structuralRevision` and generation, immutable resource descriptor snapshots,
  and `resourceRevision`.
- Keep frame-owned render models in `FrameEngine`: `FrameFactsPort` supplies
  committed row facts, not `RenderElementRecord`, `PaintPlan`, selection
  decoration plans, or selected supplement records.
- Keep selection, preview, view camera, resource visual, spatial, resolver,
  diagnostics, and public projection ownership with their existing owners and
  boundaries.
- Align architecture docs, frame/resource contracts, diagrams, implementation
  phase guidance, verification guardrails, planned tests, indexes, and registry
  references that currently describe direct store reads in frame paths.
- Add source-of-truth enforcement expectations so future production
  `lib/src/frame/**` code obtains committed frame facts through
  `FrameFactsPort` rather than concrete store imports.

### Out of Scope

- No production Dart implementation under `lib/**`.
- No Dart test implementation under `test/**`.
- No public API change and no root package export change.
- No change to `SelectionFactsPort`, `SurfaceResourceSession`,
  `ResourceKernel`, `SpatialKernel`, runtime view camera, preview ownership, or
  diagnostics ownership except references needed to preserve their existing
  boundaries.
- No generic `DocumentFactsPort` expansion as a substitute for the
  frame-intent boundary.
- No broad store facade, public document projection access, draft access,
  diagnostics dump access, mutation access, or raw committed table access from
  frame paths.
- No change to paint-plan cache identity, resource resolver cache identity, or
  selection decoration cache identity except wording needed to route committed
  document facts through `FrameFactsPort`.

## 2. Evidence Map

### Baseline Evidence

These facts describe repository state before execution. They are evidence for
the change, not target-state requirements.

- `.research/2026-05-19-frame-facts-port-docs-research.md:13` records that
  `FrameEngine` owns captured frames, ordinary paint plans, selection
  decoration/staging, and repaint buses.
- `.research/2026-05-19-frame-facts-port-docs-research.md:15` records that the
  current component diagram permits `FrameEngine -> DocumentStoreKernel`, and
  main-paint/resource-resolution diagrams show direct store reads for committed
  frame facts, row resolution, and descriptor snapshots.
- `.research/2026-05-19-frame-facts-port-docs-research.md:17` records that the
  existing docs already contain the adjacent query-port pattern through
  `document_facts_port.dart`, `selection_facts_port.dart`, and P4 narrow
  immutable query-port requirements.
- `.research/2026-05-19-frame-facts-port-docs-research.md:31` records the three
  current direct store-read categories in frame paths: capture committed
  tables/revisions/resources once, resolve candidate handles against captured
  structural revision/generation, and read descriptor snapshots by resource id.
- `docs/diagrams/c4_component_runtime.mmd:35` currently marks
  `FrameEngine -> DocumentStoreKernel` as allowed.
- `docs/diagrams/c4_container.mmd:15` currently shows
  `FrameEngine --> Store`.
- `docs/diagrams/seq_main_paint.mmd:19`, `docs/diagrams/seq_main_paint.mmd:42`,
  and `docs/diagrams/seq_main_paint.mmd:73` currently show `FrameEngine`
  reading committed frame facts, row facts, and descriptor snapshots directly
  from `DocumentStoreKernel`.
- `docs/diagrams/seq_resource_resolution.mmd:24` and
  `docs/diagrams/seq_resource_resolution.mmd:31` currently show resource
  resolution capturing committed frame facts and descriptor snapshots directly
  from `DocumentStoreKernel`.
- `docs/diagrams/dfd_main_paint_frame.mmd:73`,
  `docs/diagrams/dfd_main_paint_frame.mmd:91`, and
  `docs/diagrams/dfd_main_paint_frame.mmd:117` currently route committed frame
  facts, row facts, and descriptor snapshots through the store node.
- `docs/diagrams/dfd_resource_resolution.mmd:81` currently reads committed
  descriptor snapshots directly from the descriptor table.
- `docs/diagrams/seq_selected_move_preview_commit.mmd:63` and
  `docs/diagrams/seq_selected_move_preview_commit.mmd:72` currently show
  selected-move main repaint capture and row resolution as direct frame-store
  reads.
- `docs/diagrams/seq_selected_move_cancel.mmd:54` and
  `docs/diagrams/seq_selected_move_cancel.mmd:63` currently show selected-move
  cancel repaint capture and row resolution as direct frame-store reads.
- `docs/diagrams/seq_dispose_during_gesture.mmd:48` currently shows dispose
  cleanup repaint capture as a direct frame-store read.
- `docs/diagrams/state_resource_resolution.mmd:43` currently says a resolve
  request transitions to descriptor snapshot through "Frame reads descriptor
  snapshot."
- `docs/verification/release_gates.md:134` through
  `docs/verification/release_gates.md:136` already list frame guardrails in the
  release gate, so the new frame facts guardrail needs an explicit release-gate
  update in this step.

### Entry Paths

- Main paint starts at `CanvasSurface` and asks `FrameEngine` for a main-scene
  paint frame with viewport, device pixel ratio, style inputs, and a
  `SurfaceResourceSession`.
- Ordinary paint-plan misses query `SpatialKernel` for bounded candidate
  handles, then resolve each handle against captured `structuralRevision` and
  generation before building committed render records.
- Image records carry `resourceId`, and paint-time resource resolution needs an
  immutable descriptor snapshot plus `resourceRevision` before calling
  `SurfaceResourceSession`.
- Public document projection remains an explicit read/encode/test/tool or
  draft-read path and must not enter paint, hit-test, or pointer hot paths.

### Current Owners

- `DocumentStoreKernel` owns committed document state, document revisions,
  resource descriptors, and projection cache according to
  `docs/architecture/01_runtime_ownership.md:54`.
- `FrameEngine` owns captured frames, ordinary paint plans, selection
  decoration/staging, and repaint buses according to
  `docs/architecture/01_runtime_ownership.md:58`.
- `SelectionKernel` owns selected ids and `selectionRevision`; current frame
  capture already uses `SelectionFactsPort` instead of concrete selection
  internals.
- `SurfaceResourceSession` owns resolver callback lifecycle,
  `resolverGeneration`, `ImageResolveCache`, resolver budget, and same-frame
  missing/null suppression.
- `SpatialKernel` owns candidate lookup and stale candidate gate inputs; it is
  not the source of truth for scene rows.

### Existing Checks

- `docs/verification/guardrails.md:163` defines
  `store.no_public_document_live_state`.
- `docs/verification/guardrails.md:165` defines
  `projection.only_explicit_read_paths`.
- `docs/verification/guardrails.md:185` defines
  `spatial.stale_candidate_rejected`.
- `docs/verification/guardrails.md:187` through
  `docs/verification/guardrails.md:190` define frame and cache guardrails around
  no global sort, paint-plan exclusion of preview/selection facts, and
  next-owned revision cache keys.
- `docs/verification/guardrails.md:196` through
  `docs/verification/guardrails.md:198` define resource resolver session
  ownership and resource-resolution budget/missing retry checks.
- `docs/indexes/by_test_area.md:362` through
  `docs/indexes/by_test_area.md:397` map planned P9 frame tests for capture,
  no live painter reads, paint-plan exclusion, and camera-pan cache behavior.
- `test ! -d lib && test ! -d test` confirms there is no root package
  production or test implementation yet; this step is documentation/source of
  truth only.

### Valid Precedents

- `docs/architecture/02_package_boundaries.md:58` and
  `docs/architecture/02_package_boundaries.md:59` already list
  `document_facts_port.dart` and `selection_facts_port.dart` under
  `lib/src/runtime/`.
- `docs/implementation/p4_runtime_spine.md:27` requires narrow immutable
  document and selection read/query ports for later frame, spatial, resource,
  and interaction phases.
- `docs/implementation/p4_runtime_spine.md:104` through
  `docs/implementation/p4_runtime_spine.md:106` require later owners to obtain
  committed and selection facts only through narrow immutable query ports, not
  concrete owner tables or internals.
- `docs/diagrams/c4_component_runtime.mmd:8` and
  `docs/diagrams/c4_component_runtime.mmd:36` show `SelectionFactsPort` as an
  intent-specific query boundary for immutable selection facts used by
  interaction and frame capture.
- `docs/contracts/resources.md:78` through `docs/contracts/resources.md:85`
  already require immutable descriptor snapshots and `resourceRevision` to enter
  paint/resource resolution while forbidding the resource module from importing,
  reading, or mutating `DocumentStoreKernel`.

### Repository Rules

- `PLAN.md` is the active roadmap; each step has a dedicated contract file.
- When adding a new step to `PLAN.md`, the `$change-contract` skill is the
  canonical step-contract template.
- Repository documentation under `docs/**`, registry files, diagrams, guardrails,
  indexes, and phase documents are source-of-truth surfaces.
- Documentation changes do not require `dart analyze`, `dcm analyze .`, or
  `dcm calculate-metrics .`.
- Documentation navigation and registry consistency are checked with
  `dart run docs/tool/generate_context_capsules.dart --check` and
  `dart run docs/tool/check_docs.dart`.
- Repository communication is Russian, while repository documentation is
  written in English.

### Misleading Patterns

- The current direct `FrameEngine -> DocumentStoreKernel` relationship is the
  broad seam being narrowed, not the target design.
- A general-purpose `DocumentFactsPort` expansion would risk becoming a
  mini-store for multiple consumers rather than an intent-specific frame
  boundary.
- Returning `RenderElementRecord` from `FrameFactsPort` would move frame-owned
  render model construction into the committed document boundary.
- Moving selection facts into `FrameFactsPort` would duplicate or bypass the
  existing `SelectionFactsPort` owner.
- Moving resource resolver calls into `FrameFactsPort` would bypass
  `SurfaceResourceSession`, which owns resolver lifecycle and budget.
- Returning raw family tables, `CommittedDocument`, or `CanvasDocument`
  projection would preserve the broad store-read problem under a new name.

## 3. Architecture Decision

### Selected Form

Add `FrameFactsPort` as the narrow committed frame facts query boundary:

```text
FrameEngine -> FrameFactsPort -> DocumentStoreKernel
```

The port supplies only frame-facing committed facts needed by frame capture,
bounded render-row resolution, and image descriptor lookup. It does not expose
raw store structures or frame-owned render models.

The port surface is locked semantically as three intent-specific capabilities:

- capture committed frame revision facts once for the paint frame;
- resolve immutable committed render-row facts for bounded frame candidate
  handles, rejecting stale candidates by captured `structuralRevision` and
  generation;
- read immutable resource descriptor snapshots and `resourceRevision` by
  `resourceId` for paint-time resource resolution.

Exact Dart signatures are deferred to implementation, but those signatures must
preserve the three capabilities above and must not add broader document/store
access.

### Ownership

- `DocumentStoreKernel` remains owner of committed document tables, resource
  descriptors, resource descriptor revision, document/cache revision families,
  and `DocumentProjectionCache`.
- `FrameFactsPort` is a runtime-owned intent boundary for committed facts used
  by frame capture. It owns no mutable document state.
- `RuntimeRoot` owns composition: future `FrameEngine` instances receive a
  `FrameFactsPort`, not a concrete `DocumentStoreKernel`.
- `FrameEngine` owns `CapturedMainFrame`, `CapturedOverlayFrame`,
  `RenderElementRecord`, `PaintPlan`, selected supplement records, selection
  decoration plans, repaint buses, and frame render caches.
- `SelectionFactsPort`, `ResourceKernel`, `SurfaceResourceSession`,
  `SpatialKernel`, runtime view camera, preview state, and `DiagnosticsHub`
  keep their existing ownership.

### Seam

The retired accepted seam is direct committed frame reads:

```text
FrameEngine -> DocumentStoreKernel
```

The successor seam is:

```text
FrameEngine -> FrameFactsPort -> DocumentStoreKernel
```

The successor seam is frame-specific. It is not a generic document read facade,
not a public API, and not a mutation boundary.

### Dependency Direction

`FrameEngine` may depend on `FrameFactsPort`, `SelectionFactsPort`,
`SpatialKernel`, `ResourceKernel` resource visual facts, and
`SurfaceResourceSession`. `FrameEngine` must not import or depend on concrete
`DocumentStoreKernel`, `CommittedDocument`, family tables, resource tables, or
`DocumentProjectionCache`.

`FrameFactsPort` may be backed by `DocumentStoreKernel` through runtime
composition. Store-side code must not depend on frame-owned render models such
as `RenderElementRecord`, `PaintPlan`, selected supplement records, selection
decoration plans, or frame cache classes.

### State and Data Ownership

`FrameFactsPort` may expose immutable values for:

```text
documentRevision
structuralRevision
boundsRevision
elementVisualRevision
backgroundRevision
gridRevision
committed render-row facts for bounded frame candidate handles
resource descriptor snapshots
resourceRevision
```

`FrameFactsPort` must not expose:

```text
CanvasDocument
DocumentProjectionCache
CommittedDocument
raw family tables
raw resource table
edit draft
selection mutable state
interaction state
diagnostics internals
mutation methods
```

`resourceVisualRevision` remains a resource runtime fact, not committed document
state. `selectionRevision` and selected ids remain selection facts, not
committed document facts.

### Entry and Exit Boundaries

- Entry: main paint frame capture, paint-plan cache miss row resolution,
  selected supplement row resolution, and image descriptor lookup for records
  that carry `resourceId`.
- Exit: updated source-of-truth architecture docs, frame/resource contracts,
  diagrams, phase guidance, guardrails, planned tests, indexes, and registry
  entries that describe `FrameFactsPort` as the only accepted committed
  document-read boundary for frame paths.
- Forbidden exit: no source-of-truth surface may continue to describe direct
  `FrameEngine -> DocumentStoreKernel` committed frame reads as accepted target
  architecture after this step is complete.

### Verification Strategy

Semantic proof must show the selected docs define `FrameFactsPort`, its allowed
facts, its exclusions, and the successor relationship. Negative semantic proof
must show active source-of-truth surfaces no longer accept direct
`FrameEngine -> DocumentStoreKernel` committed frame reads, direct descriptor
snapshot reads, or direct row-resolution reads. Structural proof must run the
repository documentation tooling after registries, indexes, and context
navigation are aligned.

### Decision Ledger

| ID | Decision | Owner | Proof |
|---|---|---|---|
| D1 | `FrameFactsPort` is the successor committed frame facts seam between `FrameEngine` and `DocumentStoreKernel`. | Runtime/document boundary | P1, P2, P3 |
| D2 | `FrameFactsPort` exposes only frame-facing committed revision, row, stale-rejection, descriptor snapshot, and `resourceRevision` facts. | Runtime/document boundary | P1, P2 |
| D3 | `FrameEngine` owns render records, paint plans, selected supplement records, and decoration plans; the port must not return frame-owned render models. | Frame boundary | P1, P2 |
| D4 | Future frame production code must obtain committed document facts through `FrameFactsPort` and must not import concrete store internals. | Guardrail/source boundary | P1, P3 |

### Rejected Alternatives

- Keep direct `FrameEngine -> DocumentStoreKernel` reads with prose-only
  restrictions: rejected because diagrams and package boundaries would still
  allow broad store access.
- Expand a generic `DocumentFactsPort` for frame capture: rejected because the
  request and research identify a frame-specific seam, and a general document
  port would invite unrelated consumers and broaden over time.
- Put `FrameFactsPort` under `lib/src/frame/**`: rejected because the
  store-backed side would need to depend on frame-owned placement or the
  boundary would read as frame-owned instead of runtime/document-owned.
- Put `FrameFactsPort` under `lib/src/store/**`: rejected because frame code
  would still import a store namespace for committed reads.
- Return `RenderElementRecord` or `PaintPlan` from `FrameFactsPort`: rejected
  because those are frame-owned render/cache models.
- Include selection facts in `FrameFactsPort`: rejected because
  `SelectionFactsPort` already owns selection facts for frame capture.
- Include resolver access or resolved image cache state in `FrameFactsPort`:
  rejected because `SurfaceResourceSession` owns resolver lifecycle and budget.
- Expose public `CanvasDocument` projection, drafts, diagnostics internals, or
  raw committed tables through the port: rejected because those are explicitly
  excluded from paint hot paths and would preserve the broad store-read problem.

## 4. Execution Guardrails

### Required Order

1. Update architecture ownership and package boundary docs so `FrameFactsPort`
   has a named file, owner, dependency direction, allowed facts, and forbidden
   imports before sequence diagrams are rewritten.
2. Update frame/resource contracts and diagrams to route the three current
   direct store-read categories through `FrameFactsPort`.
3. Update phase guidance, guardrails, planned tests, indexes, registry entries,
   and release-gate references so enforcement follows the new seam.
4. Run targeted semantic positive/negative proof and documentation structural
   checks after all source-of-truth surfaces are aligned.

### Cross-Slice Constraints

- Do not move selection facts, preview facts, view camera facts, resource visual
  facts, spatial candidate ownership, resolver calls, or diagnostics ownership
  into `FrameFactsPort`.
- Do not change paint-plan cache keys, selected supplement staging, resource
  resolver cache keys, or projection policy except wording needed to route
  committed document facts through `FrameFactsPort`.
- Do not add production implementation or tests in this documentation-only step.
- Do not leave mixed diagrams where one active source-of-truth diagram routes
  frame committed reads through `FrameFactsPort` while another still routes them
  directly through `DocumentStoreKernel`.

### Seam Migration

| Retired seam or wording | Successor seam or wording | Affected consumers or documents | Migration order | Retirement proof |
|---|---|---|---|---|
| `FrameEngine -> DocumentStoreKernel` for committed frame reads | `FrameEngine -> FrameFactsPort -> DocumentStoreKernel` | `docs/architecture/01_runtime_ownership.md`, `docs/architecture/02_package_boundaries.md`, `docs/diagrams/c4_component_runtime.mmd`, `docs/diagrams/c4_container.mmd`, `docs/implementation/p4_runtime_spine.md`, `docs/implementation/p9_frame_rendering_and_caches.md` | Slice 1 before diagram sequence/data-flow rewrites | P2 |
| Direct `Frame->>Store` capture and row-resolution messages | `FrameEngine` reads committed frame facts and row snapshots through `FrameFactsPort` | `docs/contracts/frame_rendering.md`, `docs/diagrams/seq_main_paint.mmd`, `docs/diagrams/dfd_main_paint_frame.mmd`, `docs/diagrams/seq_selected_move_preview_commit.mmd`, `docs/diagrams/seq_selected_move_cancel.mmd`, `docs/diagrams/seq_dispose_during_gesture.mmd` | Slice 2 after package boundary owner is documented | P2 |
| Direct descriptor snapshot reads by `FrameEngine` from store | descriptor snapshots and `resourceRevision` enter paint through `FrameFactsPort`; resolver access remains `SurfaceResourceSession` | `docs/contracts/resources.md`, `docs/diagrams/seq_resource_resolution.mmd`, `docs/diagrams/dfd_resource_resolution.mmd`, `docs/diagrams/seq_main_paint.mmd`, `docs/diagrams/dfd_main_paint_frame.mmd`, `docs/diagrams/state_resource_resolution.mmd` | Slice 2 after the frame fact surface is documented | P2 |
| No named frame committed-facts guardrail | `frame.committed_facts_via_frame_facts_port` and package-boundary wording that blocks concrete store imports from `lib/src/frame/**` | `docs/verification/guardrails.md`, `docs/verification/tests.md`, `docs/indexes/by_guardrail.md`, `docs/indexes/by_test_area.md`, `docs/_registry/sections.yaml`, `docs/verification/release_gates.md` | Slice 3 after docs and diagrams name the successor seam | P1, P3 |

### Forbidden Moves

- Do not implement a broad store facade and name it `FrameFactsPort`.
- Do not let `FrameFactsPort` return `CanvasDocument`, `CommittedDocument`, raw
  tables, mutable collections, drafts, selection internals, interaction state,
  diagnostics internals, or mutation APIs.
- Do not make resource descriptor lookup a `ResourceKernel` store read; the
  resource module must still avoid reading or mutating `DocumentStoreKernel`.
- Do not make `FrameFactsPort` responsible for spatial candidate lookup,
  resolver calls, resolved image cache entries, render record construction, or
  paint-plan cache ownership.
- Do not update generated or indexed documentation by hand when the repository
  docs tooling owns the generated form.

### Deferred Broad Verification

`dart analyze`, `dcm analyze .`, and `dcm calculate-metrics .` are deferred
because this is a documentation/source-of-truth step with no production Dart or
test implementation in scope. The later production implementation step must run
those checks after code changes.

## 5. Proof Plan

### P1. Positive FrameFactsPort Semantics

This proof shows active source-of-truth docs name `FrameFactsPort`, route frame
committed facts through it, and document the new enforcement guardrail.

```sh
rg -n "FrameFactsPort|frame.committed_facts_via_frame_facts_port|frame_facts_port\\.dart" docs
```

Expected signal: matches appear in the architecture/package-boundary docs,
frame/resource contracts or diagrams, and verification docs/indexes.

### P2. Retired Direct Store Read Semantics

This proof shows active target source-of-truth docs no longer accept direct
`FrameEngine -> DocumentStoreKernel` committed frame reads, row-resolution
reads, or descriptor snapshot reads.

```sh
rg -n "Rel\\(FrameEngine, DocumentStoreKernel|FrameEngine --> Store|Frame->>Store|Store-->>Frame|Frame reads descriptor snapshot|Frame reads committed descriptor|read committed descriptor snapshot|resolve row data by captured revisions|capture committed tables" docs
```

Expected signal: no matches. Retired or forbidden wording must use different
phrasing that names `FrameFactsPort` as the accepted path, so this proof remains
machine-ambiguous only on actual stale direct-read language.

### P3. Documentation Structural Checks

This proof shows registry, context capsule, index, and documentation navigation
state are coherent after the source-of-truth updates.

```sh
dart run docs/tool/generate_context_capsules.dart --check
dart run docs/tool/check_docs.dart
```

Expected signal: both commands exit successfully.

## 6. Vertical Slices

### Slice 1. [x] Lock FrameFactsPort Ownership And Package Boundary

#### Implements

D1, D2, D3, D4

#### Obligations Covered

SEAM_MIGRATION

#### Files

- Primary architecture owner: `docs/architecture/01_runtime_ownership.md` —
  define `FrameFactsPort` as the committed frame facts boundary and describe
  the successor relationship without giving it frame-owned render
  responsibilities.
- Package boundary owner: `docs/architecture/02_package_boundaries.md` — add
  `runtime/frame_facts_port.dart` to the target layout, strengthen
  `lib/src/frame/**` source rules to require committed document facts through
  `FrameFactsPort`, and keep public projection/draft/store internals excluded.
- Runtime data model alignment: `docs/architecture/03_data_model.md` — mention
  that frame-facing committed revision facts are read through `FrameFactsPort`
  without changing revision ownership or projection policy.
- Component diagram owner: `docs/diagrams/c4_component_runtime.mmd` — add
  `FrameFactsPort`, remove the accepted direct `FrameEngine ->
  DocumentStoreKernel` relationship, and show the port backed by
  `DocumentStoreKernel`.
- Container diagram owner: `docs/diagrams/c4_container.mmd` — replace
  `FrameEngine --> Store` with the `FrameFactsPort` relationship.
- P4 phase guidance owner: `docs/implementation/p4_runtime_spine.md` — include
  `FrameFactsPort` in the narrow immutable committed fact boundaries that later
  frame phases must use.

#### Change

The accepted architecture names the new frame-specific committed facts seam,
places the file under `lib/src/runtime/`, locks the dependency direction, and
removes direct store access from the frame-facing component/container views.

#### Proof

Run P1 to confirm the new seam is named in architecture/package-boundary docs.
Run P2 to confirm component/container diagrams no longer accept direct
`FrameEngine -> DocumentStoreKernel` frame reads.

#### Closure

Slice 1 is complete when architecture docs and owner diagrams agree that
`FrameEngine` receives committed document facts only through `FrameFactsPort`.

### Slice 2. [x] Route Frame And Resource Capture Through The Port

#### Implements

D1, D2, D3

#### Obligations Covered

SEAM_MIGRATION

#### Files

- Frame contract owner: `docs/contracts/frame_rendering.md` — define the
  frame-facing committed facts available through `FrameFactsPort`, preserve
  `SelectionFactsPort` separation, and state that render records remain
  frame-owned.
- Resource contract owner: `docs/contracts/resources.md` — replace wording that
  permits descriptor snapshots from an allowed reader such as `FrameEngine` with
  descriptor snapshots supplied to frame paint through `FrameFactsPort`, while
  keeping resolver access in `SurfaceResourceSession`.
- Main paint sequence owner: `docs/diagrams/seq_main_paint.mmd` — replace direct
  `Frame->>Store` capture, row-resolution, and descriptor snapshot messages
  with `FrameFactsPort` messages.
- Resource resolution sequence owner: `docs/diagrams/seq_resource_resolution.mmd`
  — route committed main-frame facts and descriptor snapshot reads through
  `FrameFactsPort`.
- Main paint data-flow owner: `docs/diagrams/dfd_main_paint_frame.mmd` — add the
  port as the committed frame facts boundary and remove direct frame-to-store
  row/descriptor flows.
- Resource resolution data-flow owner: `docs/diagrams/dfd_resource_resolution.mmd`
  — route paint descriptor lookup through `FrameFactsPort` while preserving
  committed descriptor ownership in `DocumentStoreKernel`.
- Selected move preview sequence owner:
  `docs/diagrams/seq_selected_move_preview_commit.mmd` — route selected-move
  main repaint committed frame capture, ordinary row resolution, and selected
  supplement row resolution through `FrameFactsPort`.
- Selected move cancel sequence owner:
  `docs/diagrams/seq_selected_move_cancel.mmd` — route selected-move cancel
  repaint committed frame capture, ordinary row resolution, and selected
  supplement row resolution through `FrameFactsPort`.
- Dispose cleanup sequence owner: `docs/diagrams/seq_dispose_during_gesture.mmd`
  — route selected-move dispose cleanup committed frame capture through
  `FrameFactsPort`.
- Resource resolution state owner: `docs/diagrams/state_resource_resolution.mmd`
  — replace the state transition that says frame reads descriptor snapshots with
  the committed-state owner passing descriptor facts through `FrameFactsPort`.
- P9 phase guidance owner: `docs/implementation/p9_frame_rendering_and_caches.md`
  — require P9 implementation to consume `FrameFactsPort` for committed frame
  facts and to avoid concrete store imports in frame code.

#### Change

The frame and resource contracts plus sequence/data-flow diagrams describe the
three researched direct store-read categories as `FrameFactsPort` calls:
committed revision capture, bounded row snapshot resolution, and descriptor
snapshot lookup.

#### Proof

Run P1 to confirm frame/resource contracts and diagrams use `FrameFactsPort`.
Run P2 to confirm direct store-read wording is gone or explicitly marked
retired/forbidden.

#### Closure

Slice 2 is complete when main paint and resource resolution docs no longer leave
any accepted path where `FrameEngine` reads committed document rows or
descriptors directly from `DocumentStoreKernel`.

### Slice 3. [x] Add Verification And Index Coverage

#### Implements

D4

#### Obligations Covered

SEAM_MIGRATION

#### Files

- Guardrail owner: `docs/verification/guardrails.md` — add
  `frame.committed_facts_via_frame_facts_port` with enforcement expectations
  for frame committed facts and concrete store import blocking.
- Test ledger owner: `docs/verification/tests.md` — map the new guardrail to
  planned frame/guardrail proof without inventing production tests outside the
  documentation plan.
- Guardrail index owner: `docs/indexes/by_guardrail.md` — add the new guardrail
  mapping to relevant sections, diagrams, and planned tests.
- Test-area index owner: `docs/indexes/by_test_area.md` — align planned P9 frame
  test entries with the new frame facts boundary where those tests prove capture
  or no live store reads.
- Section registry owner: `docs/_registry/sections.yaml` — add the guardrail,
  diagram, or required-test references needed by the edited source-of-truth
  docs.
- Release gate owner: `docs/verification/release_gates.md` — include the new
  `frame.committed_facts_via_frame_facts_port` guardrail with the existing
  frame guardrails in the release gate.

#### Change

Verification docs and indexes contain an executable future-proof obligation for
the new seam, including a named guardrail that blocks concrete store access from
frame implementation and requires committed frame facts to flow through
`FrameFactsPort`.

#### Proof

Run P1 to confirm verification docs and indexes name the guardrail. Run P3 to
confirm documentation structure remains coherent.

#### Closure

Slice 3 is complete when the new boundary has guardrail/test/index coverage and
documentation tooling passes.

### Slice 4. [x] Final Semantic Retirement Check

#### Implements

D1, D2, D3, D4

#### Obligations Covered

SEAM_MIGRATION

#### Files

- Verification-only evidence: `.research/2026-05-19-frame-facts-port-docs-research.md`
  — use as baseline evidence only; do not edit it.
- Finalization owner: `PLAN.md` — mark this step complete only in the same
  change that closes the linked step contract after all required proof passes.
- Finalization owner: `plan/step_16_frame_facts_port_committed_frame_facts_boundary.md`
  — mark slice checkboxes complete only when the implementation change has
  actually closed each slice and proof has passed.

#### Change

No new architecture is introduced in this slice. The slice verifies that the
source-of-truth set has converged on the selected seam and that the old direct
store-read seam is not still accepted anywhere active.

#### Proof

Run P1, P2, and P3.

#### Closure

Slice 4 is complete when positive proof finds the successor seam, negative proof
does not find accepted direct frame-store reads, documentation structural checks
pass, and this step plus `PLAN.md` are marked complete in the same change.

## 7. Final Gate

### Run Proof Set

- P1. Positive FrameFactsPort Semantics
- P2. Retired Direct Store Read Semantics
- P3. Documentation Structural Checks

### Done When

- all referenced Decision Ledger decisions have passing proof;
- all Contract Obligations are satisfied;
- all retired seams have negative proof;
- no out-of-scope files were changed;
- `FrameFactsPort` is documented as the only accepted committed document facts
  boundary for frame capture, row snapshot resolution, and descriptor snapshot
  lookup;
- selection, preview, view camera, resource visual, spatial, resolver,
  diagnostics, and projection ownership remain with their existing boundaries;
- `PLAN.md` and this linked step contract are marked complete in the same
  closing change;
- whitespace validation passes.
