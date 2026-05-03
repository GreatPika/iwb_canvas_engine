# Change Contract

## 1. Change Mandate

Close `KI-6` by making fill-only path precise hit-testing honor the same
sanitized `hitPadding + kHitSlop` touch target that already admits runtime and
snapshot path hit-test candidates.

## 2. Change Boundary

### Included in the Change

- add owner-level regression proof that a filled path without stroke accepts a
  point outside the exact fill but within the sanitized path-contour hit
  padding
- keep runtime `PathNode` and `PathNodeSnapshot` hit-testing aligned through
  the core geometry owner
- preserve candidate-bounds admission as the first path hit-test gate
- codify the chosen fill-padding semantics as an invariant with repository
  proof coverage
- add a narrow `evenOdd` guard that fixes the intended behavior for inner path
  contours
- remove `KI-6` only after the behavioral and structural proof passes
- update public API/runtime behavior documentation and release notes for the
  corrected path hit-padding behavior
- refresh the core architecture family status only to the extent that removing
  `KI-6` changes the family status while `KI-7` remains active
- audit `README.md` under the landing-page sync rules and leave it unchanged
  when it remains accurate by delegating detailed hit-test semantics to
  `API_GUIDE.md`

### Not Included in the Change

- no public API rename, schema-version change, or new public import
- no change to path parsing, path storage, path fill-rule serialization, or
  render geometry cache keys
- no mathematically exact filled-shape dilation subsystem
- no local-bounds fallback for filled path hit-testing
- no change to coarse candidate-bounds padding semantics for non-path nodes
- no change to paint admission or spatial-index storage policy
- no implementation for `KI-7` or other active known issues

## 3. Surrounding Code Review

### Inspected Artifacts

- `KNOWN_ISSUES.md` - records `KI-6` as a confirmed `P2` defect where path
  candidate bounds include `hitPadding + kHitSlop`, but fill-only precise
  hit-testing ignores that padding.
- `docs/ARCHITECTURE_ATLAS.md` - routes architecture investigation through the
  engine and proof family registries and links active defects to
  `KNOWN_ISSUES.md`.
- `docs/architecture/overview.md` - marks
  `core_scene_graph_geometry_and_spatial_indexes` as `known issue`.
- `docs/architecture/families/core_scene_graph_geometry_and_spatial_indexes.md`
  - owns geometry calculations, hit testing, and spatial index query semantics;
  its target rules require hit testing and candidate bounds to stay aligned for
  each node family and forbid describing `KI-6` as target architecture.
- `docs/proof_architecture/overview.md` - routes proof ownership through the
  invariant registry and verification checks.
- `ARCHITECTURE.md` - names `core` as the layer for mutable scene graph,
  geometry, hit-testing, and spatial index behavior, and requires
  cross-cutting architecture changes to update code, tests, guardrails or
  invariants, architecture docs, and public docs.
- `tool/invariant_registry.dart` - maps
  `core_scene_graph_geometry_and_spatial_indexes` to
  `INV-ENG-RENDER-HIT-BOUNDS-PARITY`, but no current invariant states that
  precise path fill hit-testing must honor hit padding; this change must add
  `INV-ENG-PATH-FILL-HIT-PADDING-PARITY`.
- `lib/src/core/hit_test.dart` - exposes hit-test facades and candidate-bound
  facades, but delegates node hit-testing to `nodeGeometryHitTest` and
  `nodeSnapshotGeometryHitTest`.
- `lib/src/core/node_geometry.dart` - owns runtime and snapshot candidate bounds
  and precise geometry hit-testing; path candidate bounds inflate by
  `_geometryScenePadding`, while `_hitTestPathGeometry` accepts fill hits only
  through `Path.contains`.
- `lib/src/core/node_geometry.dart` - `_pathStrokeRadiusLocal` returns `0` when
  `strokeColor == null`, so fill-only paths do not receive a precise local hit
  radius.
- `lib/src/core/scene_spatial_index.dart` - hit-test query paths admit content
  candidates through `nodeHitTestCandidateBoundsWorld`, proving the spatial
  index owns candidate lookup rather than precise path geometry semantics.
- `test/core/node_geometry_test.dart` - already covers basic runtime and
  snapshot geometry hit-test branches, but lacks a fill-only path padding
  regression.
- `test/core/hit_test_test.dart` - proves public hit-test facades delegate to
  shared geometry owners and covers path fill/stroke basics, but does not prove
  fill-only path padding.
- `test/render/render_hit_bounds_parity_test.dart` - locks render world-bounds
  parity with core hit candidate bounds, which is adjacent proof but not a
  precise hit-test padding proof.
- `tool/run_repository_audits.dart` - current standalone audits pass while
  `KI-6` remains active, proving the existing audit contour does not catch this
  precise path hit-padding class.
- `dart run tool/lsp_trace_symbol.dart lib/src/core/node_geometry.dart
  nodeGeometryHitTest --direction=both --depth=2 --json` - confirms
  `hitTestNode` is an incoming facade and `_hitTestPathGeometry`,
  `_pathStrokeRadiusLocal`, candidate bounds, and path-local construction are
  outgoing owner-side dependencies.

### Current Entry Path

- Runtime hit path:
  `hitTestNode(point, SceneNode)` -> `nodeGeometryHitTest(point, node)` ->
  `NodeType.path` branch -> `_hitTestPathGeometry(...)`.
- Snapshot hit path:
  `hitTestNodeSnapshot(point, NodeSnapshot)` ->
  `nodeSnapshotGeometryHitTest(point, node)` -> `PathNodeSnapshot` branch ->
  `_hitTestPathGeometry(...)`.
- Spatial candidate path:
  committed hit-test query -> `nodeHitTestCandidateBoundsWorld(...)` ->
  `nodeGeometryCandidateBoundsWorld(...)` -> candidate admitted before the
  precise runtime or snapshot geometry hit-test runs.

### Current Owner

- The owning layer is `lib/src/core/**`, specifically
  `lib/src/core/node_geometry.dart`, because the defect is in the shared
  geometry hit-test policy consumed by runtime nodes, snapshots, hit-test
  facades, and spatial candidate resolution.

### Adjacent Abstractions

- `_geometryScenePadding` is the shared sanitizer for `hitPadding`, fixed
  `kNodeGeometryHitSlop`, and optional additional scene padding.
- `_sceneScalarToLocalMax` converts scene-space padding into a conservative
  local-space scalar for transformed path stroke hit-testing.
- `_hitTestPathStrokePrecise` and `_hitTestPathMetrics` are the closest
  existing precise path-contour distance policy.
- `_hitTestBoxGeometry` is the adjacent non-path precedent for applying scene
  padding in local geometry after transform inversion.
- `nodeGeometryCandidateBoundsWorld` and
  `nodeSnapshotGeometryCandidateBoundsWorld` are the coarse hit-test admission
  sources that must stay aligned with precise hit behavior.

### Existing Tests

- `test/core/node_geometry_test.dart` - verifies candidate-bound inflation and
  runtime/snapshot geometry hit-test basics.
- `test/core/hit_test_test.dart` - verifies hit-test facade delegation,
  top-most hit ordering, and basic path fill/stroke behavior.
- `test/core/hit_test_candidate_bounds_test.dart` - verifies candidate-bound
  padding remains strict scene padding and does not inflate by transform
  anisotropy.
- `test/render/render_hit_bounds_parity_test.dart` - verifies render
  world-bounds parity with runtime and snapshot hit candidate bounds.
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart` and
  import-boundary tests - provide structural precedent for invariant coverage,
  but do not own this core geometry behavior.

### Analogous Implementation Path

- `_hitTestPathStrokePrecise` in `lib/src/core/node_geometry.dart` is the
  closest valid precedent because it already implements precise path-contour
  distance using `PathMetrics` inside the same owner and is consumed by both
  runtime and snapshot path hit-testing.
- `_hitTestBoxGeometry` in `lib/src/core/node_geometry.dart` is the closest
  valid padding precedent because it applies sanitized scene padding to the
  precise local geometry check after transform inversion.

### Governing Repository Rules

- `AGENTS.md` - bugs must be fixed at the shared abstraction, invariant,
  contract, or boundary guard that owns the weakness, not at one downstream
  call site.
- `AGENTS.md` - important stable constraints should be mechanically enforced
  through repository-local tests, guardrails, structural tests, CI checks, or
  tooling rather than prose reminders.
- `AGENTS.md` - active known issues must be removed only in the same change
  that fixes them and adds regression proof.
- `ARCHITECTURE.md` - the `core` layer owns geometry and hit-testing.
- `docs/architecture/families/core_scene_graph_geometry_and_spatial_indexes.md`
  - hit testing and candidate bounds must stay aligned for each node family.
- `tool/invariant_registry.dart` - invariant ids and proof reachability must be
  declared in the registry and proven by executable tests or tools.
- `PLAN.md` - a new plan step must use the `$change-contract` template and the
  step checkbox must be updated with the linked step document when complete.

### Rejected Misleading Local Patterns

- `lib/src/core/scene_spatial_index.dart` - it owns candidate discovery and
  stored/query bounds, but changing it would only widen or narrow admission and
  would not repair precise path hit semantics.
- `lib/src/core/hit_test.dart` - it exposes facade helpers, but adding special
  path logic there would duplicate policy outside the geometry owner.
- `test/render/render_hit_bounds_parity_test.dart` - it proves coarse bounds
  parity with render geometry, but it does not prove exact hit behavior inside
  the admitted touch target.
- render geometry cache and path rendering code - they own drawing/caching, not
  hit-test acceptance semantics.
- inflated local-bounds checks for paths - they are a tempting shortcut, but
  would accept points in empty corners and holes that are not close to any path
  contour.
- exact geometric fill dilation - it is a different geometry subsystem with
  non-trivial fill-rule, hole, self-intersection, and transform behavior and is
  not required to close the touch-target inconsistency.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- Shared core geometry hit-test policy for path nodes.

#### Selected Architectural Form

- Path precise hit-testing remains an owner-side policy in
  `lib/src/core/node_geometry.dart`.
- A filled path hit is accepted when the point is inside the exact fill or, when
  the path has fill, when the point is within the sanitized local equivalent of
  `hitPadding + kHitSlop` from any path contour after candidate-bounds
  admission.
- The contour-padding rule intentionally applies to all fill boundaries,
  including inner contours produced by fill rules such as `evenOdd`.
- Stroked paths continue to use stroke-width radius plus the same sanitized
  padding.

#### Owning Layer or Module

- `lib/src/core/node_geometry.dart` owns the implementation.
- `test/core/node_geometry_test.dart` owns the behavioral regression proof.
- `tool/invariant_registry.dart` owns the new invariant entry for
  precise path hit-padding parity.

#### Dependency Direction

- `core` must depend only on `contract` and same-layer core helpers for this
  change.
- `hit_test.dart`, spatial index code, controller code, interactive code,
  render code, and public API surfaces must continue to consume core geometry
  helpers rather than reimplement path hit-padding policy.

#### State and Data Ownership

- No new persistent state, cache, schema field, or public data shape is added.
- The only data consumed by the new precise policy is existing path geometry,
  transform, fill/stroke presence, stroke width, and node `hitPadding`.
- Sanitization stays in the existing numeric/padding helper path that clamps
  non-finite or negative padding defensively for runtime geometry.

#### Entry and Exit Boundaries

- Entry boundaries are `nodeGeometryHitTest` for runtime nodes and
  `nodeSnapshotGeometryHitTest` for snapshots.
- The first path-specific exit remains `false` when the world point is outside
  candidate bounds.
- The final exit is a boolean hit decision; no path geometry object, metrics
  iterator, or local padding policy is exposed outside `node_geometry.dart`.

#### Permitted Extension Seam

- The permitted extension seam is private code inside `node_geometry.dart` that
  computes path fill contour-padding acceptance from an already-built local
  path, local point, and local padding radius.
- Existing private stroke contour helpers are the only contour-distance helpers
  available for reuse or generalization, and any such change must stay inside
  `node_geometry.dart` with names that keep stroke and fill semantics explicit.

#### Rejected Alternatives

- Spatial-index fix - rejected because candidate admission already includes the
  padding and the defect is in precise hit acceptance.
- Hit-test facade fix - rejected because it duplicates node-family geometry
  policy outside the shared geometry owner.
- Inflated local path bounds - rejected because it loses path precision and
  accepts points unrelated to the rendered or interactive contour.
- Exact filled-shape dilation - rejected because it creates a new geometry
  subsystem beyond the required touch-target contract.
- Render-owner fix - rejected because render geometry parity is adjacent proof,
  not the owner of hit-test decisions.

#### Why This Level Is Correct

- Runtime and snapshot geometry branches already converge inside
  `node_geometry.dart`, so fixing the core path hit policy closes both
  externally visible hit paths.
- The architecture family that owns the defect explicitly owns geometry and
  hit-testing and requires candidate bounds and hit-testing to stay aligned.
- Existing path stroke hit-testing already uses path metrics inside this file,
  making contour-distance padding the dominant local form instead of a new
  dependency or cross-layer policy.

### 4B. Architecture Decision Gate

- Not applicable.

## 5. Locked Decisions

1. Fill path padding uses contour-distance semantics, not filled-shape dilation
   and not inflated bounds.
2. Candidate bounds remain the first rejection gate for path precise
   hit-testing.
3. Runtime and snapshot path hit-testing must continue to stay behaviorally
   aligned through `node_geometry.dart`.
4. Inner contours are part of the fill boundary for hit-padding purposes; an
   `evenOdd` guard test must record this intentionally.
5. `KI-6` removal is deferred until the path hit-padding proof and invariant
   coverage pass.

## 6. Result Requirements

1. A fill-only path with positive `hitPadding` accepts points outside exact
   fill when the point is within the sanitized contour-padding radius.
2. The same fill-only path rejects points outside the candidate bounds.
3. Runtime `PathNode` and `PathNodeSnapshot` produce equivalent hit-padding
   behavior for the same geometry.
4. Stroked path hit behavior remains compatible with the existing stroke-width
   plus padding contract.
5. Points inside an `evenOdd` hole and away from any contour remain rejected.
6. Points inside an `evenOdd` hole but within the padding radius of the inner
   contour are accepted by the chosen touch-target semantics.
7. The invariant registry and proof coverage make future drift in precise path
   hit-padding behavior mechanically visible.

## 7. Execution Order and Gates

### Required Order

- First add the failing fill-only path reproducer and the neighboring guard
  scenarios in `test/core/node_geometry_test.dart` before implementation edits.
- Then make the minimal owner-side change in `lib/src/core/node_geometry.dart`.
- Then add `INV-ENG-PATH-FILL-HIT-PADDING-PARITY` in
  `tool/invariant_registry.dart` and
  mark the proof file with the matching
  `// INV:INV-ENG-PATH-FILL-HIT-PADDING-PARITY` marker.
- Then remove `KI-6` and update documentation/release notes after behavioral
  and structural proof passes.

### Successor Seam and Retirement Gates

- No public seam, support file, or shared caller seam is introduced or retired.
- The only retired artifact is the `KI-6` known-issue entry, and its retirement
  gate is: new reproducer and guard tests pass, invariant coverage passes, and
  the required code-change verification preset passes for the changed paths.

### Deferred Broad Verification

- The full `required_code_change` preset is reserved for the final gate after
  code, tests, invariant registry, known-issue, and documentation updates are
  complete.
- Slice-local verification must run before the final gate so broad
  verification does not compensate for missing owner-level proof.

## 8. File Map

### Implementation Files

- `lib/src/core/node_geometry.dart`

### Test Files

- `test/core/node_geometry_test.dart`
- `test/core/hit_test_test.dart` (verification only; no planned edits)

### Fixtures and Supporting Data

- None. Use inline path snapshots and runtime nodes.

### Registry, Inventory, and Workflow Files

- `tool/invariant_registry.dart`
- `KNOWN_ISSUES.md`
- `PLAN.md`
- `plan/step_36_path_fill_hit_padding_parity.md`
- `API_GUIDE.md`
- `CHANGELOG.md`
- `README.md`
- `docs/architecture/families/core_scene_graph_geometry_and_spatial_indexes.md`

### Analysis Area

- Not applicable. This change does not add or modify analyzer, rule-engine,
  bypass-detection, or structural-analysis recognition logic.

## 9. Implementation Rules

### Protected Invariants

- `INV-ENG-RENDER-HIT-BOUNDS-PARITY` must remain true; the fix must not change
  render-derived hit candidate bounds.
- Add `INV-ENG-PATH-FILL-HIT-PADDING-PARITY` for path precise hit-padding
  parity. The invariant title must state that path fill precise hit-testing
  accepts exact fill or path-contour distance within sanitized
  `hitPadding + kHitSlop` after candidate-bounds admission for runtime and
  snapshot geometry.
- `INV-G-LAYER-BOUNDARIES` and the core layer dependency direction must remain
  true; the fix must not import render, controller, interactive, model, or
  serialization code into `core`.

### Required Proof

- behavioral proof: `test/core/node_geometry_test.dart` must include one
  failing reproducer for fill-only path padding plus exactly three neighboring
  guard scenarios: runtime/snapshot parity, candidate-bound rejection, and one
  `evenOdd` inner-contour scenario with both away-from-contour rejection and
  near-inner-contour acceptance assertions.
- behavioral proof: existing facade delegation proof in
  `test/core/hit_test_test.dart` must remain green; no facade-level test edit is
  planned because the locked owner is `node_geometry.dart`.
- structural proof: `dart run tool/check_invariant_coverage.dart` must pass
  after the invariant registry change and proof marker are added.
- structural proof: `dart run tool/check_import_boundaries.dart` and
  `dart run tool/check_guardrails.dart` must pass to prove the owner-side fix
  did not move policy across layers.
- for this bug fix and invariant-enforcement gap: one failing reproducer first,
  plus 1 to 3 guard tests for neighboring branches of the same contract.

### Allowed Change Surface

- Modify private helpers and private call wiring in `lib/src/core/node_geometry.dart`.
- Add focused tests and helper assertions in `test/core/node_geometry_test.dart`.
- Do not edit `test/core/hit_test_test.dart` unless an existing facade test
  fails and the repair is limited to preserving the already-owned facade
  delegation contract.
- Add `INV-ENG-PATH-FILL-HIT-PADDING-PARITY` metadata in
  `tool/invariant_registry.dart`.
- Remove only the `KI-6` entry from `KNOWN_ISSUES.md` after proof exists.
- Update `API_GUIDE.md`, `CHANGELOG.md`, `README.md`, and the core architecture
  family document only for the fixed hit-padding contract and issue status.

### Forbidden Moves

- Do not add public APIs, schema fields, or migration behavior.
- Do not move hit-padding policy into `hit_test.dart`, spatial index,
  controller, interactive, render, model, or serialization layers.
- Do not replace path precise hit-testing with inflated bounds.
- Do not add exact fill-dilation dependencies or a new geometry subsystem.
- Do not change non-path node hit-padding semantics.
- Do not remove `KI-6` before the reproducer and guard proof is green.
- Do not claim `KI-7` is fixed or change its known-issue entry.

## 10. Vertical Slices

### Slice 1. [x] Path Fill Hit-Padding Proof And Owner Fix

#### Slice Contract

Lock and close the fill-only path precise hit-padding regression at the shared
core geometry owner while preserving runtime/snapshot parity, candidate-bound
rejection, and existing stroke path behavior.

#### Change

Add failing reproducer-first tests in `test/core/node_geometry_test.dart` for a
fill-only closed path whose outside-edge point is within
`hitPadding + kHitSlop`. Add exactly three guard scenarios: the same behavior
through `PathNodeSnapshot`, rejection for a point outside candidate bounds, and
one `evenOdd` hole scenario that asserts both away-from-contour rejection and
near-inner-contour acceptance. Then make the minimal owner-side change in
`lib/src/core/node_geometry.dart` so fill precise hit-testing accepts exact fill
or contour distance within the sanitized local padding radius after
candidate-bounds admission. Keep existing stroked path tests green.

#### Behavioral Verification

- `flutter test --no-pub test/core/node_geometry_test.dart`
- `flutter test --no-pub test/core/hit_test_test.dart`

#### Structural Verification

- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`

#### Fixtures Used

- Inline runtime `PathNode` and `PathNodeSnapshot` instances only.

#### Positive Scenarios

- Fill-only runtime path accepts exact fill.
- Fill-only runtime path accepts a point outside exact fill but within
  contour-padding radius.
- Fill-only snapshot path accepts the equivalent padded contour point.
- `evenOdd` path accepts a point near the inner contour within padding.
- Existing stroked path hit tests remain green.

#### Negative Scenarios

- Fill-only path rejects a point outside candidate bounds.
- `evenOdd` path rejects a point inside a hole and away from all contours.
- Invalid or unavailable local path still returns false.

#### Closure Evidence

- The new fill-only path reproducer fails before the implementation edit and
  passes after the owner-side fix.
- The guard scenarios pass after the owner-side fix.
- Slice-local behavioral tests pass.
- Import-boundary and guardrail checks remain green.

### Slice 2. [x] Invariant And Issue Closure

#### Slice Contract

Retire `KI-6` only after precise path hit-padding behavior is proven and the
new invariant makes future drift mechanically visible.

#### Change

Add `INV-ENG-PATH-FILL-HIT-PADDING-PARITY` in
`tool/invariant_registry.dart` with required proof in
`test/core/node_geometry_test.dart` and `stepId: scope_core`. Add the matching
`// INV:INV-ENG-PATH-FILL-HIT-PADDING-PARITY` marker to the proof test file.
Remove `KI-6` from `KNOWN_ISSUES.md` only after the invariant proof is
reachable. Update `API_GUIDE.md` for the public `hitPadding` behavior,
`CHANGELOG.md` for the user-visible fix, and
`docs/architecture/families/core_scene_graph_geometry_and_spatial_indexes.md`
for the remaining known-issue status while `KI-7` stays active. Audit
`README.md` under `$readme-sync` and leave it unchanged if it has no direct
hit-testing behavior claim.

#### Behavioral Verification

- `flutter test --no-pub test/core/node_geometry_test.dart`

#### Structural Verification

- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/check_architecture_atlas.dart`

#### Fixtures Used

- Inline path test data from Slice 1.

#### Positive Scenarios

- `INV-ENG-PATH-FILL-HIT-PADDING-PARITY` is listed under
  `core_scene_graph_geometry_and_spatial_indexes`.
- The invariant proof marker is present in `test/core/node_geometry_test.dart`.
- `KNOWN_ISSUES.md` no longer lists `KI-6`.
- The core architecture family still reports `known issue` if `KI-7` remains
  active.

#### Negative Scenarios

- Invariant coverage fails if the proof marker or required proof path is
  removed.
- Architecture atlas verification fails if family status or known-issue links
  contradict the active issue list.

#### Closure Evidence

- Invariant coverage is green.
- Architecture atlas verification is green.
- `KI-6` is absent while `KI-7` remains represented.
- Documentation and changelog describe only the fixed path hit-padding
  behavior and do not claim unrelated hit-test or paint-admission changes.

## 11. Final Verification

- Create the changed-paths file containing every modified, added, renamed, or
  deleted repository-relative path.
- Run
  `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path>`.
- Run no direct `dart test` command; use Flutter tests or repository
  verification wrappers as required by `AGENTS.md`.

## 12. Acceptance Criteria

- Fill-only path precise hit-testing honors sanitized `hitPadding + kHitSlop`
  for runtime and snapshot geometry after candidate-bounds admission.
- The selected contour-padding semantics, including inner-contour behavior, are
  locked by executable owner-level tests.
- Existing candidate-bound, stroke path, and render hit-bounds parity contracts
  remain green.
- The invariant registry exposes proof reachability for precise path
  hit-padding parity through `INV-ENG-PATH-FILL-HIT-PADDING-PARITY`.
- `KI-6` is removed, `KI-7` remains active, and public docs/release notes match
  the implemented behavior.
- The required code-change verification preset passes for the completed change.
