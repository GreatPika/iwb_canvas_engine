language: russian

# Шаг 53. Вынести snapshot fast path из `snapshot.dart` `part`-coupling в explicit internal owner-модули

## 1. Change Mandate

Этот шаг закрывает второй и последний реальный architecture seam в `contract`:
`snapshot.dart` больше не должен держать validated fast path через
`part 'internal/snapshot_fast_path.part.dart';`.

После шага public immutable snapshot surface остаётся в `snapshot.dart`, но
fast-path allocation ownership уходит в explicit internal owner-модули без
потери immutability contract, без возврата к giant constructor matrix inside
the public file и без metric-only reshaping.

## 2. Change Boundary

### Included in the Change

- `lib/src/contract/snapshot.dart`
- `lib/src/contract/internal/snapshot_fast_path.dart`
- `lib/src/contract/internal/snapshot_fast_path_scene.dart`
- `lib/src/contract/internal/snapshot_fast_path_node.dart`
- Removal of
  `lib/src/contract/internal/snapshot_fast_path.part.dart`
- `lib/src/model/**` only where fast-path imports or call sites must adapt
- `test/contract/**` only where fast-path import surfaces or helper semantics
  must adapt
- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`
- `development_plan/contract_target_architecture.md`
- `development_plan/step_53_snapshot_fast_path_explicit_internal_owners.md`

### Not Included in the Change

- Reopening the `node_boundary_schema` split from step `52` beyond direct
  compatibility work
- Splitting `snapshot.dart` into multiple public files
- Reopening `transform2d.dart`, `scene_data_exception.dart`, or validated value
  owners
- Public API expansion for downstream package users
- Generic constructor-builder abstractions created only to reduce metrics

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/contract/snapshot.dart`
- `lib/src/contract/internal/snapshot_fast_path.dart`
- `lib/src/contract/internal/snapshot_fast_path_scene.dart`
- `lib/src/contract/internal/snapshot_fast_path_node.dart`
- `ARCHITECTURE.md`

### Test Files

- `test/contract/validated_fast_path_contract_test.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/contract/contract_layer_smoke_test.dart`
- `test/public_api/snapshot_immutability_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/model/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/serialization/scene_fixture_test.dart`

### Fixture and Supporting Data Files

- `DEVELOPMENT_PLAN.md`
- `development_plan/contract_target_architecture.md`
- `development_plan/step_52_node_boundary_schema_explicit_owner_split.md`
- `development_plan/step_53_snapshot_fast_path_explicit_internal_owners.md`

### Analysis Area

- `lib/src/contract/snapshot.dart`
- `lib/src/contract/internal/snapshot_fast_path*.dart`
- `lib/src/model/**`
- `test/contract/**`
- `test/public_api/**`
- `test/model/**`
- `test/serialization/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified `snapshot_fast_path*` file must be tied either to scene-level
  fast-path ownership or to node-family fast-path ownership.
- Every modified `snapshot.dart` section must be tied either to preserving the
  public immutable boundary or to exposing the exact `@internal`
  prevalidated-allocation entrypoints required by the new fast-path modules.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. This step starts only after step `52` is closed and verified.
2. `snapshot.dart` remains the public immutable snapshot family surface and
   becomes `part`-free after this step.
3. The `snapshot_fast_path.part.dart` seam is removed, not renamed.
4. `snapshot.dart` exposes explicit `@internal` named constructors for the
   fast-path modules instead of relying on private-library `part` access.
5. The exact `@internal` prevalidated constructor family is:
   `SceneSnapshot.prevalidated`,
   `BackgroundLayerSnapshot.prevalidated`,
   `ContentLayerSnapshot.prevalidated`,
   `ScenePaletteSnapshot.prevalidated`,
   `ImageNodeSnapshot.prevalidated`,
   `TextNodeSnapshot.prevalidated`,
   `StrokeNodeSnapshot.prevalidated`,
   `LineNodeSnapshot.prevalidated`,
   `RectNodeSnapshot.prevalidated`,
   and
   `PathNodeSnapshot.prevalidated`.
6. `internal/snapshot_fast_path_scene.dart` owns:
   `sceneSnapshotFromValidated`,
   `backgroundLayerSnapshotFromValidated`,
   `contentLayerSnapshotFromValidated`,
   `cameraSnapshotFromValidated`,
   `backgroundSnapshotFromValidated`,
   `gridSnapshotFromValidated`,
   and
   `scenePaletteSnapshotFromValidated`.
7. `internal/snapshot_fast_path_node.dart` owns:
   `imageNodeSnapshotFromValidated`,
   `textNodeSnapshotFromValidated`,
   `strokeNodeSnapshotFromValidated`,
   `lineNodeSnapshotFromValidated`,
   `rectNodeSnapshotFromValidated`,
   and
   `pathNodeSnapshotFromValidated`.
8. `internal/snapshot_fast_path.dart` remains the canonical internal import
   surface and is thin only.
9. Public downstream users do not gain new supported public API entrypoints;
   the new constructors are internal-only and stay annotated `@internal`.

## 5. Result Requirements

1. `snapshot.dart` no longer contains
   `part 'internal/snapshot_fast_path.part.dart';`.
2. `snapshot_fast_path.part.dart` is deleted.
3. `snapshot_fast_path.dart`,
   `snapshot_fast_path_scene.dart`,
   and
   `snapshot_fast_path_node.dart`
   exist as normal modules.
4. The new fast-path modules do not call private `_internal` constructors
   directly; they use the exact `@internal` `*.prevalidated(...)` entrypoints
   declared in `snapshot.dart`.
5. Public snapshot immutability and validated-boundary semantics remain
   unchanged.
6. `dcm` and clone results improve on the fast-path seam because the
   constructor matrix no longer sits inside a `part`-shared public file.
7. No new `HIGH` / `VERY HIGH` hotspot appears outside the accepted focused
   public contract owners listed in
   `development_plan/contract_target_architecture.md`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Current `snapshot.dart` is large but architecturally acceptable as the public
  immutable snapshot surface.
- The actual owner problem is the `part`-attached fast-path matrix:
  scene/layer/palette helpers and node-family allocation helpers are hidden
  inside one library-private namespace and gain access to private `_internal`
  constructors only because they are parts of `snapshot.dart`.
- The right architectural fix is therefore:
  keep `snapshot.dart` as the public surface,
  add explicit internal-only prevalidated constructors,
  and move fast-path helpers into normal internal modules with scene vs node
  ownership.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/contract/snapshot.dart lib/src/contract/internal/snapshot_fast_path.dart lib/src/contract/internal/snapshot_fast_path_scene.dart lib/src/contract/internal/snapshot_fast_path_node.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract`
- `dart run tool/analysis/find_similar_clones.dart lib/src/contract`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner:
  `test/contract`
- MCP test runner:
  `test/model test/serialization test/public_api test/entrypoints`

### 6.3 Protected States, Data, or Structures

- Public immutable snapshot semantics and collection ownership behavior.
- Existing validated fast-path behavior used by model import/export and
  serialization flows.
- `SceneDataException` attribution propagated through snapshot-building flows.
- Public API shape exposed to downstream package users.

### 6.4 Allowed Semantic Change Zones

- Internal fast-path ownership and internal constructor access strategy.
- Documentation updates required to pin the contract target graph.

### 6.8 Prohibited

- Keeping any `part`-based fast-path attachment to `snapshot.dart`.
- Adding public constructors whose primary purpose is to expose fast-path
  allocation to downstream callers.
- Replacing the seam with a generic factory-builder framework.
- Reopening `node_boundary_schema` ownership beyond direct compatibility work.
- Cosmetic signature reshaping whose only purpose is to lower metrics.

## 7. Execution Rules

1. This step closes only if `snapshot.dart` becomes `part`-free and the
   fast-path seam is owned by explicit internal modules.
2. The new `@internal` prevalidated constructors must be the only supported
   constructor-access escape hatch for the fast-path modules.
3. Scope expansion into unrelated contract files is forbidden.

## 8. Vertical Slices

### Slice 1. [ ] Make `snapshot.dart` `part`-free through explicit internal prevalidated constructors

#### Slice Contract

`snapshot.dart` keeps the public immutable boundary surface but exposes the
exact internal-only constructor family needed by the fast-path modules.

#### Change

Add the `@internal` `*.prevalidated(...)` named constructors, keep them
redirecting or delegating to the existing private `_internal` constructors, and
remove the `part` attachment from `snapshot.dart`.

#### Verification

- `dcm calculate-metrics lib/src/contract/snapshot.dart --report-all`
- `rg -n \"part 'internal/snapshot_fast_path.part.dart'|\\.prevalidated\\(\" lib/src/contract/snapshot.dart -g '*.dart'`
- `dart run tool/check_public_api_surface.dart`

### Slice 2. [ ] Move scene and node fast-path helpers into explicit internal owner modules

#### Slice Contract

Validated snapshot allocation is split into scene-level and node-family
internal owners under a thin canonical fast-path import surface.

#### Change

Create `snapshot_fast_path_scene.dart` and `snapshot_fast_path_node.dart`,
move the confirmed helper families into them, reduce
`snapshot_fast_path.dart` to a thin canonical import surface, and delete
`snapshot_fast_path.part.dart`.

#### Verification

- `dcm calculate-metrics lib/src/contract/internal/snapshot_fast_path.dart lib/src/contract/internal/snapshot_fast_path_scene.dart lib/src/contract/internal/snapshot_fast_path_node.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract`
- `rg -n \"snapshot_fast_path.part.dart|_internal\\(\" lib/src/contract/internal -g '*.dart'`
- MCP test runner:
  `test/contract`
- MCP test runner:
  `test/model test/serialization test/public_api test/entrypoints`

## 9. Final Verification Checklist

- [ ] `snapshot.dart` is `part`-free.
- [ ] `snapshot_fast_path.part.dart` is deleted.
- [ ] The exact `@internal` `*.prevalidated(...)` constructor family exists.
- [ ] Scene-level and node-family fast-path owners are explicit modules.
- [ ] Public snapshot semantics are unchanged.
- [ ] Metrics and clone output improve on the fast-path seam.
- [ ] `development_plan/contract_target_architecture.md`,
      `DEVELOPMENT_PLAN.md`,
      and this step describe one consistent post-step state.
