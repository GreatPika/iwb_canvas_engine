# Change Contract

Contract Mode: FULL
Contract Profile: SOURCE_OF_TRUTH_DOCS
Contract Obligations: SEAM_MIGRATION

## 1. Mandate and Boundary

### Mandate

Convert `.design/2026-05-19-frame-engine-internal-split.md` into accepted
source-of-truth documentation for the future `FrameEngine` internal collaborator
split.

This is a documentation-only roadmap step. It must lock the selected design
form, update source-of-truth docs and diagrams, and document the future
implementation verification requirements. It must not implement production
Dart, tests, guardrail runner code, or frame collaborators.

### In Scope

- Document Candidate A from the design as the selected target form:
  `FrameEngine` remains the frame-internal facade and delegates to seven
  frame-private collaborators.
- Name the seven future collaborators and their ownership:
  `FrameCaptureService`, `OrdinaryPaintPlanner`,
  `SelectedMoveSupplementPlanner`, `SelectionDecorationPlanner`,
  `PaintAssetBindingService`, `StaticBackgroundPlanner`, and
  `OverlayPreviewPlanner`.
- Update active architecture, package-boundary, frame-rendering, resource,
  implementation-phase, verification, diagram, index, and registry source of
  truth surfaces needed to make the selected form durable.
- Document that future implementation must keep the public package barrel free
  of frame collaborators.
- Document that future implementation must keep committed document facts behind
  `FrameFactsPort`, selection facts behind the selection facts boundary, and
  resolver/session access isolated to `SurfaceResourceSession`.
- Document that `SelectionDecorationPlanner` owns the future
  `boundsRevision` invalidation requirement for selected element bounds changes
  with unchanged selection membership.
- Document the future graph-based Mermaid verification requirement: after
  implementation and diagram updates, a guardrail must parse changed
  frame-related Mermaid diagrams into graph facts and prove the selected design
  form through positive and forbidden-edge invariants.

### Out of Scope

- No production Dart implementation under `lib/**`.
- No Dart test implementation under `test/**`.
- No guardrail runner implementation under `tool/**`.
- No public API change and no root package export change.
- No package skeleton, frame collaborator files, runtime composition, cache
  code, painter code, or resource/session code changes.
- No behavioral bug fix in this step. The `boundsRevision` selection decoration
  behavior is documented as a future implementation requirement only.
- No execution of `dart analyze`, `dcm analyze .`, `dcm calculate-metrics .`,
  or `dart test`, because this step changes documentation only.
- No new source-of-truth document family unless existing architecture,
  contracts, implementation, verification, diagram, registry, or index surfaces
  cannot own a required fact.

## 2. Evidence Map

### Baseline Evidence

These facts describe repository state before execution. They are evidence for
the documentation change, not target-state requirements.

- `.design/2026-05-19-frame-engine-internal-split.md` has disposition
  `READY_FOR_CONTRACT` and selects Candidate A: `FrameEngine` as an internal
  facade over focused collaborators.
- `.design/2026-05-19-frame-engine-internal-split.md` states that the split is
  larger than the backlog's five-service example because selected move
  supplement staging and overlay preview primitive admission need explicit
  owners.
- `.design/2026-05-19-frame-engine-internal-split.md` assigns ownership for
  `FrameCaptureService`, `OrdinaryPaintPlanner`,
  `SelectedMoveSupplementPlanner`, `SelectionDecorationPlanner`,
  `PaintAssetBindingService`, `StaticBackgroundPlanner`, and
  `OverlayPreviewPlanner`.
- `docs/architecture/01_runtime_ownership.md:59` currently assigns captured
  main/overlay frames, ordinary paint plans, selection decoration/staging, and
  repaint buses to `FrameEngine`.
- `docs/architecture/01_runtime_ownership.md:98` through
  `docs/architecture/01_runtime_ownership.md:114` define `FrameFactsPort` as
  the accepted committed-state read seam and forbid it from returning
  frame-owned render models.
- `docs/architecture/02_package_boundaries.md:92` through
  `docs/architecture/02_package_boundaries.md:98` list target frame package
  files but do not yet list the proposed collaborator files.
- `docs/architecture/02_package_boundaries.md:152` states that the public
  package barrel exports only `src/api/**`.
- `docs/architecture/02_package_boundaries.md:160` requires
  `lib/src/frame/**` to obtain committed document facts through
  `runtime/frame_facts_port.dart`, not concrete store files.
- `docs/contracts/frame_rendering.md:157` through
  `docs/contracts/frame_rendering.md:161` require ordinary cached records to
  exclude selection-only state and selected move supplement records from
  `PaintPlanCache`.
- `docs/contracts/frame_rendering.md:179` through
  `docs/contracts/frame_rendering.md:200` define selected move supplement
  staging after ordinary paint-plan lookup and forbid global scene sort.
- `docs/contracts/frame_rendering.md:204` through
  `docs/contracts/frame_rendering.md:209` already require selection decoration
  invalidation to include `boundsRevision`.
- `docs/contracts/cache_policy.md:46` through
  `docs/contracts/cache_policy.md:49` define separate frame-owned cache
  identities for static background, ordinary paint plan, image resolve session,
  and selection decoration.
- `docs/contracts/resources.md:69` through `docs/contracts/resources.md:85`
  keep resolver lifecycle and image resolution with `SurfaceResourceSession`.
- `docs/verification/guardrails.md:191` and
  `docs/verification/guardrails.md:201` define committed-frame-facts and
  resolver-boundary guardrails.
- `docs/tool/check_docs.dart` states that free-form Mermaid edge text and
  runtime architecture invariants do not belong in the documentation checker;
  those constraints belong in structured registries, generated documentation,
  analyzer/lint rules, Dart tests, or benchmarks.
- `docs/verification/guardrail_design_patterns.md:151` maps
  `diagrams.all_required_present` to registry parity and runner inventory,
  which is weaker than the requested graph-invariant proof.
- `todo.md:24` through `todo.md:118` propose internal frame services and call
  out the `boundsRevision` selection decoration fix, but the design evidence
  adds separate selected move supplement and overlay preview owners.

### Entry Paths

- This documentation step starts from
  `.design/2026-05-19-frame-engine-internal-split.md`.
- The active roadmap entry is `PLAN.md`.
- The source-of-truth surfaces are `docs/**`, `docs/_registry/**`,
  `docs/indexes/**`, and `docs/diagrams/**`.

### Current Owners

- `docs/architecture/01_runtime_ownership.md` owns runtime/frame/resource
  ownership prose.
- `docs/architecture/02_package_boundaries.md` owns package layout and import
  boundary expectations.
- `docs/contracts/frame_rendering.md` owns frame rendering semantics,
  selected supplement staging, cache exclusions, painter input boundaries, and
  selection decoration invalidation requirements.
- `docs/contracts/resources.md` owns resolver/session boundary wording.
- `docs/implementation/p9_frame_rendering_and_caches.md` owns P9 frame
  implementation guidance, test expectations, guardrail expectations, and
  diagram update lists.
- `docs/verification/guardrails.md` owns mandatory guardrail ids and rules.
- `docs/verification/tests.md` owns planned test inventory and test ownership
  descriptions.
- `docs/diagrams/**` owns Mermaid source diagrams.
- `docs/_registry/**` and `docs/indexes/**` own generated or maintained
  navigation and lookup surfaces.

### Existing Checks

- `dart run docs/tool/generate_context_capsules.dart --check` validates
  generated documentation context capsules.
- `dart run docs/tool/check_docs.dart` validates documentation entrypoints,
  registries, diagram catalog membership, and navigation.
- Targeted `rg` proof can validate selected terminology, retired wording, and
  documented future verification requirements in bounded source-of-truth
  surfaces.

### Valid Precedents

- Step 16 is a `SOURCE_OF_TRUTH_DOCS` contract that updated architecture docs,
  frame/resource contracts, diagrams, guardrails, planned tests, indexes, and
  registry references without production Dart implementation.
- `docs/verification/tests.md` can document future tests and guardrail test
  ownership without creating the test files in the same documentation step.
- `docs/verification/guardrails.md` can document mandatory guardrail rules
  before their executable implementation arrives in a later code step.
- `docs/tool/check_docs.dart` is the right tool for documentation structure,
  while graph/runtime invariants are documented as future guardrail proof
  rather than added to the docs checker.

### Repository Rules

- `PLAN.md` is the active roadmap index and each step has a dedicated contract
  file.
- Documentation is written in English.
- Documentation-only changes do not require `dart analyze`,
  `dcm analyze .`, or `dcm calculate-metrics .`.
- Source-of-truth knowledge that changes future implementation, testing,
  debugging, operation, or architecture must be recorded in repository docs, not
  left only in chat.

### Misleading Patterns

- The backlog's five-service split is incomplete because it lacks explicit
  selected move supplement and overlay preview owners.
- A production implementation contract shape is misleading for this step; this
  step is documentation-only and must not own `lib/**`, `test/**`, or
  `tool/**` implementation.
- A text-only `rg` proof over Mermaid files is not enough for the requested
  future graph validation; the documentation must require a future graph parse
  into nodes, subgraphs, edges, and sequence messages.
- Adding graph-invariant checks to `docs/tool/check_docs.dart` would contradict
  that tool's stated scope.

## 3. Architecture Decision

### Selected Form

Document Candidate A as the accepted future form:

```text
FrameEngine facade -> frame-private collaborators
```

The seven future collaborators are:

- `FrameCaptureService` for one-time main/overlay live frame fact capture into
  `CapturedMainFrame` and `CapturedOverlayFrame`.
- `OrdinaryPaintPlanner` for ordinary committed `PaintPlanCache` lookup/build
  using structure, bounds, element visual, viewport, and DPR.
- `SelectedMoveSupplementPlanner` for per-frame selected move filtering,
  shifted candidate lookup, row resolution, and merge by `orderToken`.
- `SelectionDecorationPlanner` for selection UI decoration and
  `SelectionDecorationPlan` key ownership, including `boundsRevision`.
- `PaintAssetBindingService` for descriptor-to-asset binding for records with
  image resource ids through immutable descriptor facts and
  `SurfaceResourceSession`.
- `StaticBackgroundPlanner` for static background/grid plan and cache identity.
- `OverlayPreviewPlanner` for immutable overlay primitives admitted from
  `CapturedOverlayFrame`.

The documentation must preserve the design's full `Owns / Must not own` matrix:

| Future collaborator | Owns | Must not own |
|---|---|---|
| `FrameCaptureService` | one-time capture of main/overlay live frame facts into `CapturedMainFrame` and `CapturedOverlayFrame` | record planning, resolver/session calls, cache mutation beyond captured-frame construction |
| `OrdinaryPaintPlanner` | ordinary committed `PaintPlanCache` lookup/build using structure, bounds, element visual, viewport, and DPR | selection revision, selection style, selected move delta, preview state, resource resolver/session, static background identity |
| `SelectedMoveSupplementPlanner` | per-frame selected move filtering, shifted candidate lookup, row resolution, and merge by `orderToken` | ordinary paint plan cache writes, overlay rendering, global scene sort |
| `SelectionDecorationPlanner` | selection UI decoration and `SelectionDecorationPlan` key including `boundsRevision` | ordinary record cache identity, selected move supplement records, static background identity |
| `PaintAssetBindingService` | descriptor-to-asset binding for records with image resource ids, using immutable descriptor facts and `SurfaceResourceSession` | ordinary paint plan construction, painter resolver calls, app resolver ownership |
| `StaticBackgroundPlanner` | static background/grid plan and cache identity | selection, preview, resource visual, ordinary element visual identity |
| `OverlayPreviewPlanner` | immutable overlay primitives admitted from `CapturedOverlayFrame` | selected move rendering, resource resolver reads, cache invalidation, repaint scheduling |

`FrameEngine` remains the internal entry facade. It keeps future composition,
orchestration order, painter input assembly, repaint bus coordination, and the
internal entry seam.

### Ownership

- This step owns documentation updates only.
- Future production implementation remains under `lib/src/frame/**`.
- `FrameEngine` remains the documented frame facade and composition owner.
- Each future collaborator owns exactly the responsibility named in the
  selected form.
- `FrameFactsPort`, selection facts boundaries, `SpatialKernel`, and
  `SurfaceResourceSession` keep their existing documented ownership.

### Seam

This step migrates source-of-truth wording from the overloaded internal
`FrameEngine` responsibility seam to the documented future
`FrameEngine -> collaborator` seam.

No production seam is created, renamed, or retired in this step. The
implementation seam is documented for a later code step.

### Dependency Direction

The documentation must state these future dependency expectations:

- Frame collaborators stay frame-private and are not public exports.
- Frame code obtains committed facts through `FrameFactsPort`, not concrete
  store internals.
- `PaintAssetBindingService` is the only frame collaborator documented to
  receive `SurfaceResourceSession`.
- `OrdinaryPaintPlanner` is documented as free of selection revision, selection
  style, selected move delta, preview state, resolver/session APIs, and static
  background identity.
- Painters are documented as immutable-output consumers with no live runtime,
  store, resolver, or public document reads.

### State and Data Ownership

The documentation must preserve these owner facts:

- Committed document facts remain store-owned and exposed through
  `FrameFactsPort`.
- Selection facts remain selection-owned and enter frame code as captured
  selection facts.
- Preview and view-camera facts remain runtime/interaction-owned and are
  captured at frame boundaries.
- Resolver/cache state remains `SurfaceResourceSession` owned.
- Ordinary records, selected supplement records, selection decoration plans,
  static background plans, overlay primitives, and final painter inputs are
  future frame-owned derived data.

### Entry and Exit Boundaries

- Documentation entry: accepted design file plus active docs.
- Documentation exit: updated architecture, contract, implementation,
  verification, diagram, index, and registry source-of-truth surfaces.
- Future implementation entry and exit boundaries must be documented but not
  implemented in this step.

### Verification Strategy

Use documentation-only proof:

- targeted semantic search for all seven collaborators, facade wording,
  owner-specific responsibilities, must-not-own boundaries, and future
  graph-check expectations;
- targeted negative search for rejected public/runtime service wording and the
  retired all-in-one `FrameEngine` ownership phrase in active target docs;
- documentation structural checks through `generate_context_capsules.dart` and
  `check_docs.dart`.

### Decision Ledger

| ID | Decision | Owner | Proof |
|---|---|---|---|
| D1 | Candidate A is the documented future form: `FrameEngine` facade plus seven frame-private collaborators. | Source-of-truth docs | P1, P2, P5, P6 |
| D2 | The future split remains internal: no public barrel export and no runtime-level planner service. | Source-of-truth docs | P2, P3, P5, P6 |
| D3 | Future implementation must include graph-based Mermaid invariant proof after diagrams are updated. | Verification docs | P4, P5, P6 |

### Rejected Alternatives

- Five-service backlog split: rejected in docs because selected move supplement
  staging and overlay preview admission need explicit owners.
- Cache-wrapper-only split: rejected in docs because it leaves capture,
  planning, resolver/session work, selected move staging, and overlay preview
  admission in the overloaded facade.
- Public or runtime-level planner services: rejected in docs because frame
  planners are internal derived-data owners and must not become public package
  or runtime extension seams.
- Implementing the split in this step: rejected because the requested work is a
  documentation roadmap step from an accepted design artifact.

## 4. Execution Guardrails

### Required Order

1. Update architecture, package-boundary, frame-rendering, resource, and P9
   implementation docs to lock the selected future form.
2. Update frame-related diagrams so they name the future frame-side owners and
   preserve documented boundary direction.
3. Update verification docs to require future behavior tests, boundary
   guardrails, and graph-based Mermaid invariant proof after implementation.
4. Update registries and indexes only where documentation checks require it.
5. Run documentation-only proof.
6. Mark this step complete in `PLAN.md` and this step file only after proof
   passes.

### Cross-Slice Constraints

- Do not edit `lib/**`, `test/**`, or `tool/**` in this step.
- Do not add executable guardrail or test files in this step.
- Do not present future collaborators as public API or runtime-level services.
- Do not remove existing `FrameFactsPort`, selection facts, spatial, or
  `SurfaceResourceSession` ownership.
- Do not weaken existing cache identity or painter no-live-read requirements.
- Do not use broad repository-wide negative searches without bounded
  source-of-truth surfaces.

### Seam Migration

| Retired source-of-truth wording | Successor source-of-truth wording | Documentation surfaces | Retirement gate |
|---|---|---|---|
| `FrameEngine` as the single owner of capture, ordinary planning, selected supplement staging, selection decoration, asset binding, static background, and overlay preview admission | `FrameEngine` facade over seven frame-private collaborators | architecture, frame contract, P9 implementation docs, diagrams, verification docs | bounded negative proof finds no active all-in-one ownership wording |
| Backlog five-service split as sufficient future form | Candidate A with `SelectedMoveSupplementPlanner` and `OverlayPreviewPlanner` included | P9 implementation docs, frame contract, diagrams, verification docs | bounded positive proof finds all seven collaborators in active source-of-truth docs |
| Diagram presence checks as the only future diagram verification | future graph-based Mermaid invariant proof for frame diagrams | guardrails docs, tests docs, P9 implementation docs | bounded positive proof finds the graph-check requirement and command text documented |

### Forbidden Moves

- Do not create or edit production implementation files.
- Do not create or edit executable Dart tests.
- Do not create or edit guardrail runner code.
- Do not mark Step 17 complete until docs-only proof passes.
- Do not claim runtime behavior is fixed by this documentation step.

### Deferred Broad Verification

Runtime, analyzer, DCM, and Dart test verification is deferred to a later
implementation step. This step must document those future expectations but must
not execute them as proof for documentation closure.

## 5. Proof Plan

### P1. Documentation Structural Checks

This proves documentation navigation, registries, indexes, context capsules,
and diagram catalog references remain structurally coherent.

```sh
dart run docs/tool/generate_context_capsules.dart --check && dart run docs/tool/check_docs.dart
```

Expected signal: both documentation checks pass.

### P2. Selected Form Positive Semantic Proof

This proves active source-of-truth docs and diagrams name the selected
Candidate A form and all seven future frame collaborators.

```sh
sh -c 'for name in FrameCaptureService OrdinaryPaintPlanner SelectedMoveSupplementPlanner SelectionDecorationPlanner PaintAssetBindingService StaticBackgroundPlanner OverlayPreviewPlanner; do rg -q "$name" docs/architecture docs/contracts docs/implementation docs/verification docs/diagrams || exit 1; done; rg -q "FrameEngine.*facade|orchestration facade|frame-internal facade" docs/architecture docs/contracts docs/implementation docs/verification docs/diagrams'
```

Expected signal: every collaborator name is present in active source-of-truth
surfaces and `FrameEngine` is documented as a facade.

### P3. Rejected Public Runtime Surface Negative Proof

This proves active source-of-truth docs do not expose the future frame
collaborators as public API or runtime-level services.

```sh
sh -c '! rg -n "public .*FrameCaptureService|public .*OrdinaryPaintPlanner|public .*SelectedMoveSupplementPlanner|public .*SelectionDecorationPlanner|public .*PaintAssetBindingService|public .*StaticBackgroundPlanner|public .*OverlayPreviewPlanner|runtime-level .*FrameCaptureService|runtime-level .*OrdinaryPaintPlanner|runtime-level .*SelectedMoveSupplementPlanner|runtime-level .*SelectionDecorationPlanner|runtime-level .*PaintAssetBindingService|runtime-level .*StaticBackgroundPlanner|runtime-level .*OverlayPreviewPlanner" docs/architecture docs/contracts docs/implementation docs/verification docs/diagrams docs/_registry docs/indexes'
```

Expected signal: no active source-of-truth wording makes a frame collaborator
public or runtime-level.

### P4. Future Diagram Graph Proof Requirement

This proves the requested graph-based post-implementation diagram verification
is documented as a future guardrail/test expectation, without implementing it in
this step.

```sh
sh -c 'rg -q "frame_engine_diagram_graph_test|Frame Diagram Graph Invariant|Mermaid.*graph|nodes, subgraphs,.*edges|forbidden-edge" docs/implementation docs/verification && rg -q "FrameEngine.*delegates.*collaborator|PaintAssetBindingService.*SurfaceResourceSession|OrdinaryPaintPlanner.*selection.*preview.*resolver|direct.*FrameEngine.*DocumentStoreKernel" docs/implementation docs/verification'
```

Expected signal: implementation and verification docs require a future graph
guardrail that parses Mermaid diagrams into graph facts and checks positive and
forbidden-edge invariants for the selected design.

### P5. Retired Wording Negative Proof

This proves active target docs no longer preserve the retired all-in-one
`FrameEngine` ownership wording as the future form.

```sh
sh -c '! rg -n "FrameEngine owns capture, ordinary paint plans, selection decoration/staging|FrameEngine.*owns.*capture.*ordinary.*selection decoration.*asset binding|five-service split.*sufficient|FrameEngine.*directly.*owns.*overlay preview primitive admission" docs/architecture docs/contracts docs/implementation docs/verification docs/diagrams'
```

Expected signal: retired all-in-one ownership wording and the rejected
five-service-only future form are absent from active target docs.

### P6. Design Matrix Boundary Proof

This proves active source-of-truth docs preserve the design artifact's
collaborator responsibility boundaries, including the `must not own` side of
the matrix.

```sh
sh -c 'for pattern in "FrameCaptureService.*record planning" "FrameCaptureService.*resolver/session" "FrameCaptureService.*cache mutation" "OrdinaryPaintPlanner.*selection revision" "OrdinaryPaintPlanner.*selection style" "OrdinaryPaintPlanner.*selected move delta" "OrdinaryPaintPlanner.*preview state" "OrdinaryPaintPlanner.*resolver/session" "OrdinaryPaintPlanner.*static background" "SelectedMoveSupplementPlanner.*PaintPlanCache" "SelectedMoveSupplementPlanner.*overlay rendering" "SelectedMoveSupplementPlanner.*global scene sort" "SelectionDecorationPlanner.*ordinary record cache identity" "SelectionDecorationPlanner.*selected move supplement" "SelectionDecorationPlanner.*static background" "PaintAssetBindingService.*ordinary paint plan construction" "PaintAssetBindingService.*painter resolver" "PaintAssetBindingService.*app resolver ownership" "StaticBackgroundPlanner.*selection" "StaticBackgroundPlanner.*preview" "StaticBackgroundPlanner.*resource visual" "StaticBackgroundPlanner.*ordinary element visual" "OverlayPreviewPlanner.*selected move rendering" "OverlayPreviewPlanner.*resource resolver" "OverlayPreviewPlanner.*cache invalidation" "OverlayPreviewPlanner.*repaint scheduling"; do rg -q "$pattern" docs/architecture docs/contracts docs/implementation docs/verification docs/diagrams || exit 1; done'
```

Expected signal: active source-of-truth surfaces document each collaborator's
negative responsibility boundary from the design artifact, including selected
supplement no-cache/no-global-sort, post-record asset binding separation,
static background cache separation, and overlay preview exclusions.

## 6. Vertical Slices

### Slice 1. [ ] Lock Source-Of-Truth Ownership Wording

#### Implements

Implements D1 and D2.

#### Obligations Covered

SEAM_MIGRATION

#### Files

- Primary documentation edit:
  `docs/implementation/p9_frame_rendering_and_caches.md` - document Candidate A
  as the P9 future frame rendering form, name all seven collaborators, and
  record future tests/guardrails without implementing them.
- Primary documentation edit: `docs/architecture/01_runtime_ownership.md` -
  describe `FrameEngine` as a facade over frame-private collaborators while
  preserving existing owner boundaries.
- Primary documentation edit: `docs/architecture/02_package_boundaries.md` -
  list the future frame collaborator files under `lib/src/frame/**` as target
  package layout, not as files created by this step.
- Primary documentation edit: `docs/contracts/frame_rendering.md` - assign
  future capture, ordinary planning, supplement staging, decoration, asset
  binding, static background planning, and overlay preview planning to their
  documented owners.
- Conditional documentation edit: `docs/contracts/resources.md` - update only
  if resource wording needs the future `PaintAssetBindingService` owner to keep
  resolver access isolated to `SurfaceResourceSession`.

#### Change

Active source-of-truth docs describe the selected future frame form and no
longer rely on `FrameEngine` as the all-in-one owner for every frame-side
responsibility.

#### Proof

Run P2, P3, P5, and P6 for the documentation surfaces touched by this slice.

#### Closure

The selected Candidate A ownership form is documented in the core
source-of-truth docs without public/runtime leakage or retired all-in-one
ownership wording.

### Slice 2. [ ] Align Diagrams and Future Graph Proof Requirement

#### Implements

Implements D1, D2, and D3.

#### Obligations Covered

SEAM_MIGRATION

#### Files

- Diagram alignment:
  `docs/diagrams/c4_component_runtime.mmd`,
  `docs/diagrams/dfd_cache_invalidation.mmd`,
  `docs/diagrams/dfd_main_paint_frame.mmd`,
  `docs/diagrams/dfd_overlay_frame.mmd`,
  `docs/diagrams/seq_main_paint.mmd`,
  `docs/diagrams/seq_overlay_paint.mmd`,
  `docs/diagrams/seq_selected_move_preview_commit.mmd`, and
  `docs/diagrams/seq_selected_move_cancel.mmd` - name the future frame-side
  owners where the diagram shows frame ownership, data flow, or ordering.
- Documentation edit: `docs/verification/guardrails.md` - document the future
  graph-based Mermaid invariant guardrail requirement.
- Documentation edit: `docs/verification/tests.md` - document the future
  guardrail test ownership and expected graph invariants without creating the
  test file.
- Conditional documentation edit:
  `docs/verification/guardrail_design_patterns.md` - update only if the future
  graph-invariant check needs a documented guardrail pattern description beyond
  existing registry parity and semantic-sequence guidance.
- Index/registry alignment: `docs/indexes/**` and `docs/_registry/**` - update
  only generated or manually maintained references required by documentation
  checks.

#### Change

Frame-related diagrams and verification docs encode the selected future design
form and require a later implementation guardrail that parses changed Mermaid
diagrams into graph facts.

#### Proof

Run P1, P2, P3, P4, P5, and P6.

#### Closure

Diagrams and verification docs agree with the selected design, and the future
graph-based diagram check is documented clearly enough that a later
implementation step does not need to invent the verification strategy.

### Slice 3. [ ] Final Documentation Verification and Roadmap Closure

#### Implements

Implements D1, D2, and D3 by closing the documentation contract.

#### Obligations Covered

SEAM_MIGRATION

#### Files

- Finalization file: `PLAN.md` - mark Step 17 complete after documentation
  proof passes.
- Finalization file:
  `plan/step_17_frame_engine_internal_collaborator_split.md` - mark completed
  slices done after documentation proof passes.
- Verify-only file set: all documentation, diagram, index, and registry files
  touched by earlier slices.

#### Change

Run the full documentation proof set, repair any documentation contradictions at
the owning source-of-truth surface, and close the roadmap entry only after the
documentation seam migration has negative proof.

#### Proof

Run P1, P2, P3, P4, P5, and P6.

#### Closure

All documentation proof passes, no out-of-scope implementation files were
changed, and roadmap checkboxes are updated in both `PLAN.md` and this step
file.

## 7. Final Gate

### Run Proof Set

- P1. Documentation Structural Checks
- P2. Selected Form Positive Semantic Proof
- P3. Rejected Public Runtime Surface Negative Proof
- P4. Future Diagram Graph Proof Requirement
- P5. Retired Wording Negative Proof
- P6. Design Matrix Boundary Proof

### Done When

- D1 through D3 are satisfied by their Decision Ledger proof references;
- P1 through P6 pass;
- `SEAM_MIGRATION` is closed by the source-of-truth seam migration table and
  P2 through P6;
- no `lib/**`, `test/**`, or `tool/**` implementation files were changed;
- no runtime behavior or executable guardrail implementation is claimed as
  complete by this documentation step;
- whitespace validation passes.
