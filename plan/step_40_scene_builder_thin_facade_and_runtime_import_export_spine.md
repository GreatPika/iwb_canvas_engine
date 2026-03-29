language: russian

# Шаг 40. Сделать `SceneBuilder` тонким import facade и вынести shared runtime import/export spine

## 1. Change Mandate

Этот шаг переводит builder-side import boundary на explicit model-local owner-ы
так, чтобы `SceneBuilder` стал тонким orchestration facade без `part`-coupling,
а `document.dart` перестал зависеть от `scene_builder.dart` ради runtime
import/export.

## 2. Change Boundary

### Included in the Change

- `SceneBuilder` orchestration ownership in `lib/src/model/scene_builder.dart`.
- Shared runtime `SceneSnapshot -> Scene` import owner beneath
  `SceneBuilder` and `document.dart`.
- Builder-local parsed-map require/decode ownership beneath `SceneBuilder`
  without `part` coupling.
- Documentation and roadmap updates required to pin the new builder/import
  owner graph.

### Not Included in the Change

- `scene_node_boundary_mapping*.dart` decomposition beyond the direct imports
  needed by the new shared runtime import owner.
- `scene_value_validation*.dart` decomposition or `ScenePolicy` semantic
  changes.
- `document.dart` locator, erase, selection, grid, or patch-application owner
  split outside the import/export delegation seam.
- Public API surface changes in `lib/iwb_canvas_engine.dart`.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/model/scene_builder.dart`
- `lib/src/model/scene_builder_json_require.part.dart`
- `lib/src/model/scene_builder_decode_json.part.dart`
- `lib/src/model/scene_builder_scene_from_snapshot.part.dart`
- `lib/src/model/scene_builder_snapshot_from_scene.part.dart`
- `lib/src/model/scene_from_snapshot.dart`
- `lib/src/model/scene_builder_json_require.dart`
- `lib/src/model/scene_builder_decode_json.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`
- `lib/src/model/document.dart`
- `ARCHITECTURE.md`
- `PLAN.md`

### Test Files

- `test/model/scene_builder_test.dart`
- `test/model/document_model_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/entrypoints/basic_smoke_test.dart`

### Fixture and Supporting Data Files

- `plan/step_40_scene_builder_thin_facade_and_runtime_import_export_spine.md`

### Analysis Area

- `lib/src/model/scene_builder*.dart`
- `lib/src/model/scene_from_snapshot.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`
- `lib/src/model/document.dart`
- `lib/src/serialization/scene_codec.dart`
- `test/model/scene_builder_test.dart`
- `test/model/document_model_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/entrypoints/basic_smoke_test.dart`
- `ARCHITECTURE.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to one builder/import owner
  slice.
- Every modified test must be tied to one behavioral or structural
  verification.
- Every modified documentation file must pin one final builder/import owner
  boundary.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `SceneBuilder` remains the public import and canonicalization gateway, and
   `scene_builder_api.dart` remains a thin public facade over model-local
   implementation.
2. `ScenePolicy` remains the single owner of scene-level traversal semantics
   across import, decode, and runtime canonicalization.
3. Runtime `SceneSnapshot -> Scene` import and `Scene -> SceneSnapshot` export
   remain model-owned conversions and must not be re-owned by `document.dart`
   or `serialization/**`.
4. `document.dart` remains the canonical downstream txn facade for controller,
   interactive, and serialization consumers.

## 5. Result Requirements

1. `lib/src/model/scene_builder.dart` no longer contains builder-local `part`
   declarations and becomes a thin orchestration facade over explicit
   model-local modules.
2. `lib/src/model/document.dart` no longer depends on
   `lib/src/model/scene_builder.dart` to access runtime import/export
   delegation.
3. One explicit model-local owner exists for typed `SceneSnapshot -> Scene`
   import, and both `scene_builder.dart` and `document.dart` consume it.
4. `dcm calculate-metrics` no longer reports the current `VERY HIGH`
   `number-of-imports` hotspot on `lib/src/model/scene_builder.dart`.
5. `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
   no longer reports the current builder-local require/decode family in the
   same form.
6. Public `SceneBuilder.buildFromSnapshot(...)` and
   `SceneBuilder.buildFromJson(...)` behavior, including stable
   `SceneDataException.code`, `path`, and immutable `details`, remains
   equivalent.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `lib/src/model/scene_builder.dart` currently has `89` lines and one
  `VERY HIGH` metric:
  file `number-of-imports = 22`.
- The current builder-local physical architecture still uses four `part`
  declarations in `scene_builder.dart`:
  `scene_builder_json_require.part.dart`,
  `scene_builder_decode_json.part.dart`,
  `scene_builder_scene_from_snapshot.part.dart`,
  and
  `scene_builder_snapshot_from_scene.part.dart`.
- `scene_builder_snapshot_from_scene.part.dart` currently keeps only a wrapper
  over `sceneSnapshotFromScene(...)`.
- `scene_builder_scene_from_snapshot.part.dart` currently owns the runtime
  import path that `document.dart` reaches indirectly through
  `scene_builder.dart`.
- `document.dart` currently imports `scene_builder.dart` as `model_builder`
  and uses it for `txnSceneFromSnapshot(...)`.
- Current clone inventory in `lib/src/model` still contains builder-local
  require/decode families centered on
  `scene_builder_json_require.part.dart` and
  `scene_builder_decode_json.part.dart`.
- `ARCHITECTURE.md` and `API_GUIDE.md` already lock two seam decisions that
  this step must preserve:
  `SceneBuilder` remains model-owned,
  and parsed-map normalization stays in `model/` rather than in
  `serialization/`.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/model/scene_builder.dart lib/src/model/scene_from_snapshot.dart lib/src/model/scene_builder_json_require.dart lib/src/model/scene_builder_decode_json.dart lib/src/model/scene_snapshot_from_scene.dart lib/src/model/document.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `rg -n "^part 'scene_builder_|^part of 'scene_builder" lib/src/model`
- MCP test runner:
  `test/model/scene_builder_test.dart test/model/document_model_test.dart`
- MCP test runner:
  `test/public_api/scene_builder_test.dart`
- MCP test runner:
  `test/serialization/scene_codec_validation_test.dart test/entrypoints/basic_smoke_test.dart`

### 6.3 Protected States, Data, or Structures

- `SceneBuilder` public facade behavior and diagnostics.
- Parsed-map decode parity between `SceneBuilder.buildFromJson(...)` and
  `decodeScene(...)`.
- Typed snapshot import canonicalization, including background-layer
  materialization and text-size re-derivation.
- Snapshot instance-revision resolution on runtime import.
- Downstream `document.dart` txn conversion entrypoints.

### 6.4 Allowed Semantic Change Zones

- Builder-local file boundaries and import graph.
- Shared model-local runtime import/export owner allocation.
- Builder-side parsed-map require/decode helper ownership.
- Structural proofs and architecture documentation that pin the final
  builder/import owner graph.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- `document.dart` and downstream non-builder consumers must not import
  builder-local require/decode modules directly.
- `serialization/scene_codec.dart` remains a consumer of
  `scene_builder.dart` entrypoints and must not bypass them to import the new
  builder-local modules directly.
- `scene_builder.dart` may import the new builder-local modules, but must not
  re-export them.
- This step removes `part` coupling in the builder seam by using explicit
  module dependencies, not by replacing one shared library namespace with a new
  wrapper barrel.

### 6.8 Prohibited

- Leaving `document.dart -> scene_builder.dart` as the runtime import path.
- Introducing new `part` / `part of` declarations in the builder seam.
- Moving scene-level policy or validated-boundary ownership into
  `scene_builder.dart`.
- Expanding the public `SceneBuilder` API surface to compensate for internal
  coupling.
- Changing import/decode behavior solely to reduce metrics.

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

### Slice 1. [x] Shared runtime import/export spine is explicit

#### Slice Contract

Typed runtime import/export no longer lives behind `SceneBuilder` `part`
wrappers, and `document.dart` no longer depends on `scene_builder.dart` for
snapshot-to-scene delegation.

#### Change

Create one explicit model-local `SceneSnapshot -> Scene` owner, route
`scene_builder.dart` and `document.dart` through it, keep
`scene_snapshot_from_scene.dart` as the reverse owner, and remove the current
builder-local runtime import/export wrapper parts.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_builder.dart lib/src/model/scene_from_snapshot.dart lib/src/model/scene_snapshot_from_scene.dart lib/src/model/document.dart --report-all`
- `dart run tool/check_import_boundaries.dart`
- MCP test runner:
  `test/model/document_model_test.dart test/model/scene_builder_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `document.dart` no longer imports `scene_builder.dart`.
- `scene_builder_scene_from_snapshot.part.dart` and
  `scene_builder_snapshot_from_scene.part.dart` no longer exist in their
  current wrapper form.

### Slice 2. [x] `SceneBuilder` becomes a part-free thin facade

#### Slice Contract

`scene_builder.dart` no longer owns parsed-map require/decode through one
shared `part`-coupled library surface; explicit builder-local modules own
their imports and the facade stays orchestration-only.

#### Change

Convert `scene_builder_json_require.part.dart` and
`scene_builder_decode_json.part.dart` into regular modules with explicit
imports, reduce `scene_builder.dart` to orchestration over those modules, and
update architecture docs and roadmap to pin the final builder/import owner
graph.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_builder.dart lib/src/model/scene_builder_json_require.dart lib/src/model/scene_builder_decode_json.dart lib/src/model/scene_from_snapshot.dart lib/src/model/scene_snapshot_from_scene.dart lib/src/model/document.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `rg -n "^part 'scene_builder_|^part of 'scene_builder" lib/src/model`
- MCP test runner:
  `test/model/scene_builder_test.dart test/model/document_model_test.dart`
- MCP test runner:
  `test/public_api/scene_builder_test.dart`
- MCP test runner:
  `test/serialization/scene_codec_validation_test.dart test/entrypoints/basic_smoke_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `rg -n "^part 'scene_builder_|^part of 'scene_builder" lib/src/model`
  returns no matches.
- `dcm calculate-metrics ... --report-all` no longer reports the current
  `VERY HIGH` file-import hotspot for `scene_builder.dart`.
- Clone inventory for `lib/src/model` no longer shows the reviewed
  builder-local require/decode family in the same form.

## 9. Final Verification

- `dcm calculate-metrics lib/src/model/scene_builder.dart lib/src/model/scene_from_snapshot.dart lib/src/model/scene_builder_json_require.dart lib/src/model/scene_builder_decode_json.dart lib/src/model/scene_snapshot_from_scene.dart lib/src/model/document.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `rg -n "^part 'scene_builder_|^part of 'scene_builder" lib/src/model`
- MCP test runner:
  `test/model/scene_builder_test.dart test/model/document_model_test.dart`
- MCP test runner:
  `test/public_api/scene_builder_test.dart`
- MCP test runner:
  `test/serialization/scene_codec_validation_test.dart test/entrypoints/basic_smoke_test.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
