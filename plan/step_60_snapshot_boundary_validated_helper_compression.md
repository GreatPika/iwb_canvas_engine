language: russian

# Шаг 60. Сжать residual validated-helper matrix в snapshot boundary

## 1. Change Mandate

Этот шаг сжимает residual validated-helper matrix в snapshot boundary:
`snapshot_materialization.dart` перестаёт выражать node-family helper surface
как ручную матрицу длинных почти одинаковых `*SnapshotFromValidated(...)`
функций, сохраняя текущий backing/materialization split и не меняя public
snapshot boundary.

## 2. Change Boundary

### Included in the Change

- `lib/src/contract/internal/snapshot_materialization.dart`
- `lib/src/contract/internal/snapshot_fast_path.dart`
- `lib/src/contract/internal/snapshot_backing.dart` only if direct helper
  assembly alignment is required to close a slice
- `test/contract/validated_fast_path_contract_test.dart`
- `test/model/document_model_test.dart`
- `test/model/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/controller/core/scene_controller_commit_failures_test.dart`
- `test/controller/scene_snapshot_invariant_assertions_test.dart`
- `test/render/render_geometry_cache_test.dart`
- `test/render/scene_text_layout_cache_test.dart`
- `reports/dcm-calculate-metrics-lib.txt`
- `reports/find-similar-clones-lib-clusters.txt`
- `PLAN.md`
- `plan/contract_target_architecture.md`
- `plan/step_53_snapshot_fast_path_explicit_internal_owners.md`
- `plan/step_55_contract_final_architecture_closure.md`
- `plan/step_60_snapshot_boundary_validated_helper_compression.md`

### Not Included in the Change

- `lib/src/contract/snapshot.dart`
- `lib/iwb_canvas_engine.dart`
- `lib/src/model/**`
- `lib/src/contract/node_spec.dart`
- `lib/src/contract/node_patch.dart`
- `ARCHITECTURE.md`
- `API_GUIDE.md`
- `README.md`
- `CHANGELOG.md`
- Any producer-side model rewiring or public API migration
- Reopening the snapshot backing/materialization architecture established by
  step `53`

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/contract/internal/snapshot_materialization.dart`
- `lib/src/contract/internal/snapshot_fast_path.dart`
- `lib/src/contract/internal/snapshot_backing.dart`
- `PLAN.md`

### Test Files

- `test/contract/validated_fast_path_contract_test.dart`
- `test/model/document_model_test.dart`
- `test/model/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/controller/core/scene_controller_commit_failures_test.dart`
- `test/controller/scene_snapshot_invariant_assertions_test.dart`
- `test/render/render_geometry_cache_test.dart`
- `test/render/scene_text_layout_cache_test.dart`

### Fixture and Supporting Data Files

- `reports/dcm-calculate-metrics-lib.txt`
- `reports/find-similar-clones-lib-clusters.txt`
- `plan/contract_target_architecture.md`
- `plan/step_53_snapshot_fast_path_explicit_internal_owners.md`
- `plan/step_55_contract_final_architecture_closure.md`
- `plan/step_60_snapshot_boundary_validated_helper_compression.md`

### Analysis Area

- `lib/src/contract/internal/snapshot*.dart`
- `test/contract/**`
- `test/model/**`
- `test/serialization/**`
- `test/controller/**`
- `test/render/**`
- `reports/dcm-calculate-metrics-lib.txt`
- `reports/find-similar-clones-lib-clusters.txt`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied either to centralizing
  shared validated-helper assembly, preserving the canonical internal fast-path
  import surface, or keeping the backing/materialization split intact while the
  helper matrix is compressed.
- Every modified test must pin one direct proof that helper compatibility,
  malformed-snapshot coverage, or downstream consumer behavior remained green
  after the helper compression.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `plan/contract_target_architecture.md` remains the source of truth for the
   post-step-`55` contract owner graph.
2. `lib/src/contract/internal/snapshot_backing.dart` remains the owner of the
   immutable internal snapshot graph.
3. `lib/src/contract/internal/snapshot_materialization.dart` remains the owner
   of wrapper materialization and internal validated compatibility helpers.
4. `lib/src/contract/internal/snapshot_fast_path.dart` remains the canonical
   internal import surface for snapshot backing builders and validated helper
   functions.
5. Public snapshot types and public snapshot entrypoints in
   `lib/src/contract/snapshot.dart` remain unchanged in this step.
6. This step must not move helper assembly back into `model/**` or into the
   public snapshot library.
7. Metric and clone cleanup counts only when duplicate helper assembly is
   actually removed; helper indirection whose primary purpose is to appease
   tooling does not count as closure.

## 5. Result Requirements

1. `lib/src/contract/internal/snapshot_materialization.dart` no longer
   expresses node-family validated helper assembly as six inline duplicated
   `common + fields + materialize` matrices.
2. Shared node snapshot validated assembly has one canonical contract-local
   path used by every node-family `*SnapshotFromValidated(...)` helper.
3. `sceneSnapshotFromValidated`, scene/layer/palette validated helpers, and
   node-family validated helpers remain reachable through
   `lib/src/contract/internal/snapshot_fast_path.dart`.
4. The backing/materialization split introduced by step `53` remains intact:
   backing owners stay in `snapshot_backing.dart`, wrapper materialization
   stays in `snapshot_materialization.dart`.
5. Public snapshot API shape and runtime behavior remain unchanged.
6. Clone analysis for `lib/` no longer reports the current dense
   `snapshot_materialization.dart` node-helper matrix as an unresolved six-way
   contract hotspot.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Step `53` already established the correct architecture:
  immutable backing in `snapshot_backing.dart`,
  wrapper materialization in `snapshot_materialization.dart`,
  and canonical internal imports through `snapshot_fast_path.dart`.
- The residual seam is local to the validated helper family that still lives
  in `snapshot_materialization.dart`, especially the repeated node-family
  `*SnapshotFromValidated(...)` functions.
- Fresh reports in
  `reports/dcm-calculate-metrics-lib.txt`
  and
  `reports/find-similar-clones-lib-clusters.txt`
  confirm that the residual contract hotspot is helper-matrix duplication, not
  a missing backing/materialization split.
- Contract and downstream tests currently use these helpers as internal proof
  surfaces, so this step must preserve internal reachability through
  `snapshot_fast_path.dart`.
- This step is local to `contract/internal` and must not reopen model-side
  producer rewiring or public snapshot API work.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/contract/internal/snapshot*.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract/internal`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner:
  `test/model test/serialization test/contract test/public_api test/entrypoints`
- MCP test runner:
  `test/controller/core test/controller/commands` plus controller-root
  `*_test.dart` files
- MCP test runner:
  `test/render test/view`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`

### 6.3 Protected States, Data, or Structures

- Public snapshot type identities, field semantics, defaults, and immutable
  ownership guarantees.
- The existing internal snapshot backing/materialization split.
- Internal helper availability through `snapshot_fast_path.dart`.
- Existing malformed-snapshot and downstream-consumer proof scenarios that use
  validated helper functions.

### 6.4 Allowed Semantic Change Zones

- Shared validated-helper assembly inside
  `lib/src/contract/internal/snapshot_materialization.dart`
- Canonical internal helper exports from
  `lib/src/contract/internal/snapshot_fast_path.dart`
- Direct contract-local backing-helper alignment only where required to close
  the helper compression honestly
- Test adaptation required to keep internal proof callers green after the
  helper compression

### 6.8 Prohibited

- Reopening `lib/src/contract/snapshot.dart` as part of this step.
- Moving helper assembly into `model/**` or any public library.
- Introducing a second parallel snapshot construction model beside the
  existing backing/materialization split.
- Replacing the duplicated helper matrix with a generic support bucket whose
  primary purpose is only to silence clone or metric tooling.
- Expanding the scope into `NodeSpec`, `NodePatch`, `SceneBuilder`,
  `scene_value_validation`, or scene graph traversal work.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the
   trigger point must be attached.
7. If a slice changes an analysis rule, negative and positive scenarios must be
   covered where applicable to the subject of the change.
8. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [ ] Centralize node-family validated helper assembly

#### Slice Contract

Every node-family `*SnapshotFromValidated(...)` helper reuses one canonical
contract-local path for shared snapshot-common assembly instead of rebuilding
the same `common + materialize` scaffold inline.

#### Change

Refactor
`lib/src/contract/internal/snapshot_materialization.dart`
so shared node snapshot validated assembly is centralized and family helpers
only contribute their family-specific validated field bundles plus the final
wrapper materialization edge.

#### Verification

- `dcm calculate-metrics lib/src/contract/internal/snapshot*.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract/internal`
- `flutter analyze`
- `dcm analyze .`
- MCP test runner:
  `test/model test/serialization test/contract test/public_api test/entrypoints`

#### Positive Scenarios

- Every node-family validated helper still produces the same concrete snapshot
  subtype as before.
- Internal white-box helper callers continue to resolve the helper names
  through `snapshot_fast_path.dart`.

#### Negative Scenarios

- Malformed snapshot constructions used by existing contract and downstream
  tests still fail at the intended downstream boundary instead of regaining a
  public-boundary dependency.

#### Closure Evidence

- Green targeted metrics and clone runs showing the previous node-helper matrix
  is compressed.
- Green targeted contract/model/serialization verification.

### Slice 2. [ ] Align fast-path surface and downstream proof callers

#### Slice Contract

The internal snapshot fast-path surface remains coherent after helper
compression, and every direct proof caller that depends on validated helpers
stays green without reopening public snapshot ownership.

#### Change

Adjust
`lib/src/contract/internal/snapshot_fast_path.dart`
and any in-scope direct proof callers only as required to keep the canonical
internal helper surface stable after slice `1`.

#### Verification

- `flutter analyze`
- `dcm analyze .`
- MCP test runner:
  `test/controller/core test/controller/commands` plus controller-root
  `*_test.dart` files
- MCP test runner:
  `test/render test/view`

#### Positive Scenarios

- Controller-side malformed snapshot regressions remain constructible.
- Render/model proof tests that use validated snapshot helpers remain green.

#### Closure Evidence

- Green downstream test shards that cover direct helper consumers.
- No new in-scope caller bypasses `snapshot_fast_path.dart` to reach helper
  assembly through another owner.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dcm calculate-metrics lib/src/contract/internal/snapshot*.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract/internal`
- MCP test runner:
  `test/model test/serialization test/contract test/public_api test/entrypoints`
- MCP test runner:
  `test/controller/core test/controller/commands` plus controller-root
  `*_test.dart` files
- MCP test runner:
  `test/render test/view`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
