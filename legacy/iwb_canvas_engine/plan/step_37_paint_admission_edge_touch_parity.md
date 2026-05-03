# Change Contract

## 1. Change Mandate

Close `KI-7` by making committed and snapshot-local paint-candidate admission
use one strict edge-touch policy that admits paint candidates only when their
paint bounds actually overlap the query rectangle.

## 2. Change Boundary

### Included in the Change

- add owner-level regression proof that ordinary committed paint candidates are
  excluded when their paint bounds only touch the viewport edge
- prove committed and snapshot-local paint plans agree for the edge-touch-only
  ordinary-candidate case
- keep selected-node supplement widening behavior intact when the selected
  node's shifted paint bounds overlap the visibility rectangle
- keep hit-test spatial queries on their existing inclusive edge-touch
  predicate
- introduce one shared core paint-admission predicate and route committed
  spatial paint queries plus snapshot-local paint enumeration through it
- strengthen repository-local proof for the paint-admission predicate so later
  committed-versus-snapshot drift is mechanically visible
- remove `KI-7` only after the behavioral and structural proof passes
- update architecture documentation and release notes only for the corrected
  paint-admission parity behavior

### Not Included in the Change

- no public API, public export, schema, serialization, or JSON format change
- no change to hit-test candidate admission or precise hit-testing behavior
- no change to render geometry, text layout, SVG path parsing, render cache
  keys, or snapshot paint-admission bounds caching
- no replacement of `SceneSpatialIndex`, `SpatialIndexCache`, or committed
  dirty tracking
- no change to selection halo drawing, selected supplement ordering, or
  background/content draw order
- no implementation for `KI-13`, `KI-14`, or other active known issues

## 3. Surrounding Code Review

### Inspected Artifacts

- `KNOWN_ISSUES.md` - records `KI-7` as active because committed paint queries
  use an inclusive boundary predicate while snapshot-local fallback and painter
  culling use strict `Rect.overlaps`.
- `docs/architecture/families/core_scene_graph_geometry_and_spatial_indexes.md`
  - owns geometry calculations, hit testing, and spatial index query semantics;
  its target rules require shared policies instead of duplicated candidate
  logic and explicitly forbid describing `KI-7` as target architecture.
- `ARCHITECTURE.md` - states that committed ordinary candidates and selected
  supplements use committed spatial paint index bounds, snapshot-local fallback
  uses `SnapshotPaintAdmissionBoundsCache`, and render culling happens after
  admission.
- `tool/invariant_registry.dart` - `INV-ENG-PAINT-ADMISSION-BOUNDS-SOURCE`
  already covers explicit committed or snapshot-local paint-bounds sources, but
  its proof does not currently lock the edge-touch predicate used by those
  sources.
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart` -
  `preparePaintPlan(...)` branches between committed
  `SceneControllerPaintCandidateStage.prepareCommittedPaintPlan(...)` and
  snapshot-local `enumerateSnapshotPaintCandidates(...)`.
- `lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart` -
  ordinary committed candidates query the committed spatial index with
  `query.viewportRect`, while selected supplements use preview-shifted
  `query.visibilityRect` and already apply strict `visibilityRect.overlaps`
  after shifting the selected candidate bounds.
- `lib/src/core/scene_spatial_index.dart` - committed paint linear fallback and
  indexed paint resolution both call `_rectsIntersectInclusive(...)`, which is
  shared with hit-test query resolution.
- `lib/src/core/scene_snapshot_paint_candidates.dart` - snapshot-local
  candidate enumeration already uses strict `visibilityRect.overlaps`.
- `lib/src/render/scene_painter_node_renderer.dart` - final render culling uses
  strict `candidate.paintBoundsWorld.overlaps(nodeViewRect)` and then strict
  `viewRect.overlaps(worldBounds)`, so edge-touch-only candidates do not
  produce confirmed pixels.
- `test/render/scene_painter_frame_contract_test.dart` - covers committed vs
  snapshot paint-plan branch behavior, selected supplement visibility widening,
  stale snapshot rejection, and background supplement behavior, but does not
  cover ordinary edge-touch parity.
- `test/render/scene_painter_bounds_contract_test.dart` - structurally protects
  the frame and paint-admission modules, but currently checks source shape
  rather than a shared edge-touch predicate.
- `test/core/scene_spatial_index_test.dart` - covers spatial paint and hit-test
  query behavior, paint-vs-hit bounds separation, background/content paint
  scope, large spans, fallback, and incremental index behavior.
- `test/controller/core/scene_controller_spatial_index_test.dart` - uses
  zero-size hit-test probe rectangles and expects inclusive edge-touch hit-test
  behavior through committed controller queries.
- `dart run tool/lsp_trace_symbol.dart lib/src/interactive/internal/scene_controller_scene_view_runtime.dart SceneControllerSceneViewMainSceneRenderRead.preparePaintPlan --direction=both --depth=3 --json`
  - confirms the production branch point is committed stage versus
  snapshot-local enumeration.
- `dart run tool/lsp_trace_symbol.dart lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart SceneControllerPaintCandidateStage.prepareCommittedPaintPlan --direction=both --depth=3 --json`
  - confirms committed ordinary and selected supplement staging both consume
  committed paint candidates through the store spatial query surface.
- `dart run tool/lsp_trace_symbol.dart lib/src/core/scene_spatial_index.dart _querySceneSpatialIndexPaint --direction=both --depth=2 --json`
  - confirms committed paint candidate resolution reaches
  `_rectsIntersectInclusive(...)`.
- `dart run tool/lsp_trace_symbol.dart lib/src/core/scene_spatial_index.dart _rectsIntersectInclusive --direction=both --depth=2 --json`
  - confirms `_rectsIntersectInclusive(...)` is currently shared by hit-test
  and paint query branches.
- `dart run tool/run_repository_audits.dart` - current standalone audits pass
  while `KI-7` remains active, proving the existing audit contour does not
  catch this paint predicate drift.
- `dart run tool/check_invariant_coverage.dart` - current invariant proof
  coverage is complete, proving the gap is missing predicate proof inside an
  existing invariant family rather than an unregistered invariant id.

### Current Entry Path

- main render path:
  `ScenePainter.paint(...)` ->
  `ScenePainterShell.paint(...)` ->
  `ScenePainterFrameOwner.createPrepared(...)` ->
  `SceneViewMainSceneRenderRead.preparePaintPlan(...)`
- committed ordinary paint path:
  `SceneControllerSceneViewMainSceneRenderRead.preparePaintPlan(...)` ->
  `SceneControllerPaintCandidateStage.prepareCommittedPaintPlan(...)` ->
  `_stageOrdinaryCandidates(...)` ->
  `SceneStoreController.queryPaintCandidates(...)` ->
  `SpatialIndexCache.writeQueryPaintCandidates(...)` ->
  `SceneSpatialIndex.queryPaintCandidates(...)`
- snapshot-local fallback path:
  `SceneControllerSceneViewMainSceneRenderRead.preparePaintPlan(...)` ->
  `enumerateSnapshotPaintCandidates(...)`
- final render culling path:
  `ScenePainterNodeRenderer.paintNodeLayers(...)` ->
  `candidate.paintBoundsWorld.overlaps(nodeViewRect)` ->
  `_canPaintNodeInFrame(...)`

### Current Owner

- `lib/src/core/**` owns paint candidate query semantics and snapshot-local
  paint candidate enumeration.
- `lib/src/core/scene_spatial_index.dart` owns committed spatial candidate
  lookup.
- `lib/src/core/scene_snapshot_paint_candidates.dart` owns snapshot-local paint
  candidate enumeration when the frame snapshot diverges from the committed
  snapshot.
- The missing owner is a shared core paint-admission predicate consumed by both
  core paint-admission paths.

### Adjacent Abstractions

- `ScenePaintCandidateQuery` carries the viewport rectangle for ordinary
  candidates and the visibility rectangle for selected supplement widening.
- `ScenePaintSpatialCandidate` carries committed node location plus
  `paintBoundsWorld`.
- `ScenePaintCandidate` carries the snapshot node plus the paint bounds used by
  painter culling.
- `SnapshotPaintAdmissionBoundsSource` supplies snapshot-local paint bounds
  without direct text measurement or SVG parsing in enumeration.
- `_rectsIntersectInclusive(...)` is the existing hit-test-compatible edge
  predicate and must stop being the paint-admission predicate.

### Existing Tests

- `test/core/scene_spatial_index_test.dart` - owner-level spatial query tests
  for paint candidates, hit-test candidates, scopes, fallback, ordering, and
  incremental update behavior.
- `test/controller/core/scene_controller_spatial_index_test.dart` - controller
  committed spatial query tests including zero-size hit-test probes.
- `test/render/scene_painter_frame_contract_test.dart` - behavioral tests for
  committed/snapshot paint-plan branch behavior and selected supplement
  visibility widening.
- `test/render/scene_painter_bounds_contract_test.dart` - structural tests for
  painter frame boundaries and paint-admission module responsibilities.
- `test/render/scene_painter_test.dart` - integrated painter tests that confirm
  strict final culling and selected halo edge visibility.

### Analogous Implementation Path

- `SnapshotPaintAdmissionBoundsSource` is the closest valid precedent because
  it introduced a shared core seam for paint-admission bounds instead of
  letting committed and snapshot callers compute paint geometry independently.
- `nodeHitTestCandidateBoundsWorld(...)` and
  `nodePaintBoundsWorld(...)` are adjacent core query-bound helpers that keep
  candidate policy in core and let controller/render consumers call into it.

### Governing Repository Rules

- `AGENTS.md` - bugs must be fixed at the shared abstraction, invariant,
  contract, or boundary guard that owns the weakness, not at one downstream
  call site.
- `AGENTS.md` - important stable constraints should be mechanically enforced
  through repository-local tests, guardrails, structural tests, CI checks, or
  tooling.
- `AGENTS.md` - active known issues must be removed only in the same change
  that fixes them and adds regression proof.
- `AGENTS.md` - new production files under `lib/**` require
  `dcm calculate-metrics`.
- `ARCHITECTURE.md` - the core layer owns geometry, hit testing, and spatial
  index behavior; render consumes prepared paint candidates and performs late
  geometry resolution.
- `docs/architecture/families/core_scene_graph_geometry_and_spatial_indexes.md`
  - spatial index helpers must expose shared policies instead of duplicating
  candidate logic.
- `tool/invariant_registry.dart` - invariant ids and required proof paths must
  stay registered and reachable.
- `PLAN.md` - new roadmap work must use the `$change-contract` template and
  link a dedicated step document.

### Rejected Misleading Local Patterns

- `Rect.overlaps` calls in render modules - they prove the desired final cull
  semantics, but render is the wrong owner for committed spatial admission.
- changing `SceneControllerPaintCandidateStage._stageOrdinaryCandidates(...)`
  to filter committed candidates again - this would patch one consumer while
  leaving the committed spatial paint query contract divergent.
- changing `enumerateSnapshotPaintCandidates(...)` to use inclusive
  intersection - this would align the two plans by widening work against final
  renderer culling and would preserve the edge-touch-only extra candidate.
- changing `_rectsIntersectInclusive(...)` globally - this would alter hit-test
  candidate behavior and contradict existing zero-size hit-test probe tests.
- adding a guard only to `ScenePainterNodeRenderer` - final culling already
  rejects edge-touch-only candidates, so this would not remove committed plan
  drift or staging work.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- Shared core paint-candidate admission predicate.

#### Selected Architectural Form

- Introduce a focused core helper module that owns the paint-admission
  rectangle predicate.
- The paint predicate is strict overlap: edge-touch-only bounds are not paint
  candidates.
- Committed spatial paint query resolution and snapshot-local paint
  enumeration must both call the shared paint predicate.
- Existing inclusive rectangle intersection remains private to hit-test spatial
  admission or is renamed/re-scoped so paint code cannot use it by accident.

#### Owning Layer or Module

- `lib/src/core/paint_candidate_admission.dart` owns the shared predicate.
- `lib/src/core/scene_spatial_index.dart` consumes the predicate for committed
  paint queries only.
- `lib/src/core/scene_snapshot_paint_candidates.dart` consumes the predicate
  for snapshot-local paint enumeration.
- `test/core/scene_spatial_index_test.dart`,
  `test/render/scene_painter_frame_contract_test.dart`, and
  `test/render/scene_painter_bounds_contract_test.dart` own the behavioral and
  structural proof.

#### Dependency Direction

- Core paint admission must stay within `lib/src/core/**`.
- Controller, interactive, and render modules must continue to consume
  prepared candidates or core query surfaces rather than reimplementing the
  paint edge-touch predicate.
- The new helper must depend only on `dart:ui` and same-layer core helpers if
  needed.

#### State and Data Ownership

- No new persistent state, cache, schema value, or public data shape is added.
- The predicate consumes only two finite-or-validated `Rect` values: the query
  rectangle and candidate paint bounds.
- Finite-rect validation remains at the existing query/enumeration boundaries.

#### Entry and Exit Boundaries

- Entry boundaries are `SceneSpatialIndex.queryPaintCandidates(...)` for
  committed spatial paint candidates and `enumerateSnapshotPaintCandidates(...)`
  for snapshot-local paint candidates.
- Exit boundaries remain `ScenePaintSpatialCandidate` and
  `ScenePaintCandidate` lists.
- Hit-test entry boundaries remain `SceneSpatialIndex.queryHitTestCandidates`
  and must not consume the paint predicate.

#### Permitted Extension Seam

- The only permitted extension seam is the shared core predicate in
  `paint_candidate_admission.dart`.
- Future paint-admission consumers must use that predicate instead of calling
  `Rect.overlaps` or inclusive rectangle helpers directly.

#### Rejected Alternatives

- Use inclusive intersection everywhere - rejected because final renderer
  culling is strict and inclusive paint admission creates edge-touch-only
  staging work with no confirmed pixels.
- Use strict `Rect.overlaps` directly at each paint call site - rejected
  because it recreates the same drift risk and violates the family target rule
  for shared spatial index policies.
- Change hit-test queries to strict overlap - rejected because existing
  controller/core tests use zero-size hit-test probes and rely on inclusive
  edge behavior.
- Add downstream filtering in the painter or paint stage - rejected because the
  committed spatial query would still publish a divergent paint-candidate
  contract.

#### Why This Level Is Correct

- The defect is a shared paint-admission contract drift between two core
  candidate sources, not a render drawing bug.
- A core predicate fixes the behavior once, lets committed and snapshot
  admission share the same rule, and keeps hit-test semantics explicitly
  separate.
- The selected form matches the existing paint-bounds-source architecture:
  bounds source and candidate predicate are core admission concerns, while
  detailed render geometry remains late render work.

## 5. Locked Decisions

1. The implementation must start with a failing ordinary paint-plan edge-touch
   reproducer before implementation changes.
2. Behavioral guards for positive paint overlap and hit-test edge preservation
   must be added before the owner-side fix.
3. The existing selected-supplement overlap guard,
   `controller-owned render state supplements selected edge nodes through visibility rect without widening ordinary viewport candidates`,
   must be run before and after the owner-side fix.
4. `KI-7` is removed only after the new behavior, structural proof, and
   invariant coverage pass.

## 6. Result Requirements

1. Committed ordinary paint plans and snapshot-local fallback paint plans agree
   when an ordinary candidate only touches the viewport edge.
2. Edge-touch-only paint candidates are excluded before render-stage geometry
   resolution.
3. Paint candidates with a real positive-area overlap remain admitted.
4. Selected-node supplements remain admitted when their preview-shifted paint
   bounds overlap the visibility rectangle.
5. Hit-test candidates still support edge-touch and zero-size probe behavior.
6. Repository-local tests make future committed-versus-snapshot paint predicate
   drift visible.

## 7. Execution Order and Gates

### Required Order

- Add the failing paint-plan parity reproducer and neighboring guard tests
  before changing implementation.
- Introduce the shared core paint-admission predicate and migrate committed
  spatial paint plus snapshot-local enumeration to it.
- Strengthen structural proof and invariant wording after the shared predicate
  exists.
- Remove `KI-7` and update architecture/release documentation only after the
  behavioral and structural proof passes.

### Successor Seam and Retirement Gates

- Successor seam: `lib/src/core/paint_candidate_admission.dart`.
- Consumer migration order:
  `scene_snapshot_paint_candidates.dart` and the paint branches in
  `scene_spatial_index.dart` must consume the shared predicate in the same
  implementation slice.
- Retirement gate:
  no paint query or snapshot paint enumeration code may call
  `_rectsIntersectInclusive(...)` for paint admission after the migration.
- Registry and documentation gate:
  `tool/invariant_registry.dart`, `KNOWN_ISSUES.md`,
  `docs/architecture/families/core_scene_graph_geometry_and_spatial_indexes.md`,
  and `CHANGELOG.md` must be updated before closing the step.

### Deferred Broad Verification

- Run the full required code-change preset only at the final gate after code,
  tests, known issue, invariant, and documentation updates are complete.
- Run `dcm calculate-metrics lib/src/core/paint_candidate_admission.dart`
  after the new production file is created.

## 8. File Map

### Implementation Files

- `lib/src/core/paint_candidate_admission.dart`
- `lib/src/core/scene_spatial_index.dart`
- `lib/src/core/scene_snapshot_paint_candidates.dart`

### Test Files

- `test/core/scene_spatial_index_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`

### Fixtures and Supporting Data

- None.

### Registry, Inventory, and Workflow Files

- `tool/invariant_registry.dart`
- `KNOWN_ISSUES.md`
- `CHANGELOG.md`
- `PLAN.md`
- `plan/step_37_paint_admission_edge_touch_parity.md`

### Analysis Area

- `docs/architecture/families/core_scene_graph_geometry_and_spatial_indexes.md`
- `ARCHITECTURE.md` only if the invariant wording or architecture summary needs
  a release-ready statement of the shared paint-admission predicate
- `API_GUIDE.md` and `README.md` only if implementation changes public runtime
  behavior that those documents currently describe

## 9. Implementation Rules

### Protected Invariants

- `INV-ENG-PAINT-ADMISSION-BOUNDS-SOURCE` must cover both explicit
  paint-bounds sources and the shared strict paint-admission predicate.
- `INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION` must continue to hold: committed
  fast-path admission is used only when the active frame snapshot matches the
  committed snapshot, selected supplements are the only visibility-widened
  candidates, and render geometry resolves later.
- Existing hit-test behavior protected by core/controller spatial tests must
  remain unchanged.

### Required Proof

- behavioral proof: one failing ordinary edge-touch committed-vs-snapshot
  paint-plan reproducer first, plus guards for positive-overlap paint
  admission and hit-test edge-touch preservation, plus the existing selected
  supplement overlap guard named
  `controller-owned render state supplements selected edge nodes through visibility rect without widening ordinary viewport candidates`
  run before and after the owner-side fix
- structural proof: source-level or contract-level tests must prove committed
  and snapshot paint-admission modules consume the shared core predicate and
  paint branches do not use the inclusive hit-test predicate
- for this bug fix: add the reproducer and guard tests before implementation,
  then change only the shared predicate owner and its in-scope consumers by the
  minimum edit set needed to pass

### Allowed Change Surface

- add one focused core helper module for paint-candidate admission
- update imports and paint predicate calls in committed spatial paint and
  snapshot-local paint enumeration
- update narrow tests, invariant wording, known issue entry, architecture
  family status text, changelog entry, and this step checkbox when complete

### Forbidden Moves

- do not change hit-test query predicates to strict overlap
- do not add downstream paint filtering in controller, interactive, or render
  code as the primary fix
- do not widen snapshot fallback to inclusive paint admission
- do not change public API, exports, schema, serialization, or render geometry
  cache contracts
- do not introduce caching, background sync, or duplicate predicate state
- do not remove `KI-7` before the regression proof passes

## 10. Vertical Slices

### Slice 1. [x] Shared Strict Paint Admission Predicate

#### Slice Contract

Committed spatial paint queries and snapshot-local paint enumeration use one
shared strict overlap predicate, edge-touch-only ordinary paint candidates are
excluded consistently, and hit-test edge-touch behavior remains unchanged.

#### Change

1. Add the failing ordinary edge-touch parity reproducer in
   `test/render/scene_painter_frame_contract_test.dart`.
2. Add neighboring guard coverage in `test/core/scene_spatial_index_test.dart`
   for positive-overlap paint inclusion and hit-test edge-touch preservation.
3. Run the existing selected-supplement overlap guard in
   `test/render/scene_painter_frame_contract_test.dart` before the owner-side
   fix.
4. Add `lib/src/core/paint_candidate_admission.dart` and migrate
   `scene_spatial_index.dart` paint branches plus
   `scene_snapshot_paint_candidates.dart` to the shared predicate.
5. Add or extend structural proof in
   `test/render/scene_painter_bounds_contract_test.dart` so paint admission
   modules consume the shared core predicate and paint branches avoid the
   inclusive hit-test predicate.
6. Update `tool/invariant_registry.dart` to make the predicate parity
   obligation explicit under `INV-ENG-PAINT-ADMISSION-BOUNDS-SOURCE`.
7. Remove `KI-7`, update architecture/release documentation, and mark this
   slice and step complete only after proof passes.

#### Behavioral Verification

- first expected failure:
  `flutter test --no-pub test/render/scene_painter_frame_contract_test.dart --plain-name "committed and snapshot paint admission exclude ordinary edge-touch candidates"`
- before and after implementation:
  `flutter test --no-pub test/render/scene_painter_frame_contract_test.dart --plain-name "controller-owned render state supplements selected edge nodes through visibility rect without widening ordinary viewport candidates"`
- after implementation:
  `flutter test --no-pub test/render/scene_painter_frame_contract_test.dart --plain-name "committed and snapshot paint admission exclude ordinary edge-touch candidates"`
- after implementation:
  `flutter test --no-pub test/core/scene_spatial_index_test.dart --plain-name "paint admission uses strict edge overlap while hit-test remains inclusive"`

#### Structural Verification

- `flutter test --no-pub test/render/scene_painter_bounds_contract_test.dart --plain-name "paint admission modules share the core edge predicate"`
- `dart run tool/check_invariant_coverage.dart`
- `dcm calculate-metrics lib/src/core/paint_candidate_admission.dart`

#### Fixtures Used

- None.

#### Positive Scenarios

- a paint candidate with positive-area overlap is admitted
- a selected supplement whose shifted paint bounds overlap the visibility
  rectangle is admitted
- a hit-test candidate at an edge or zero-size probe remains admitted where
  existing tests require it

#### Negative Scenarios

- an ordinary paint candidate whose paint bounds only touch the viewport edge
  is excluded from committed and snapshot-local plans
- committed spatial paint resolution does not call the inclusive hit-test
  rectangle predicate for paint admission
- snapshot-local enumeration does not own a separate paint edge-touch rule

#### Closure Evidence

- `KI-7` is absent from `KNOWN_ISSUES.md`
- the core architecture family no longer lists `KI-7` as active known issue
- `CHANGELOG.md` contains an `Unreleased` entry for the paint-candidate parity
  fix
- `PLAN.md` and this step checkbox are marked complete in the implementation
  change

## 11. Final Verification

- Create the changed-paths file with every modified, added, renamed, or deleted
  repository-relative path.
- Run
  `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=.verification_changed_paths_step_37.txt`.
- Run `dcm calculate-metrics lib/src/core/paint_candidate_admission.dart` for
  the new production file if the verification preset does not already report
  that metrics command explicitly.

## 12. Acceptance Criteria

- Committed and snapshot-local paint plans agree for edge-touch-only ordinary
  candidates.
- Strict paint admission is centralized in a shared core predicate.
- Hit-test edge-touch behavior remains unchanged.
- `KI-7` is removed only with passing regression proof.
- Required repository verification passes for the completed implementation
  change.
