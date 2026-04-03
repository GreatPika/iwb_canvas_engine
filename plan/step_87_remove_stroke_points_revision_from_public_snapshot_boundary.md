language: russian

# Change Contract

## 1. Change Mandate

Этот шаг убирает `StrokeNodeSnapshot.pointsRevision` из публичного snapshot boundary, перестаёт трактовать stroke geometry revision как часть scene document contract и переводит render/cache read-side на freshness contract, который не зависит от runtime metadata на публичной snapshot surface.

## 2. Change Boundary

### Included in the Change

- Удаление `pointsRevision` из публичного `StrokeNodeSnapshot` contract и из internal snapshot owners, которые materialize/back `StrokeNodeSnapshot` as public scene document data.
- Перепривязка model import/export, snapshot decode/import validation и serialization helpers так, чтобы публичный snapshot и JSON больше не принимали, не валидировали, не materialize-или не transport-или stroke `pointsRevision`.
- Перенос render/cache stroke freshness contract с публичного `StrokeNodeSnapshot.pointsRevision` на geometry/scalar payload, already visible on the public stroke snapshot.
- Обновление repository source of truth: `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, `PLAN.md`, this step file, `tool/invariant_registry.dart`.

### Not Included in the Change

- Любая смена runtime owner-а `StrokeNode.pointsRevision` в `core`; monotonic geometry revision и `StrokeNode.replacePoints(...)` semantics остаются runtime-only concern.
- Введение draft/raw snapshot слоя или any redesign of `SceneSnapshot` global validity semantics beyond stroke runtime-metadata removal.
- Любая смена scene-level duplicate-id policy owner-а `ScenePolicy`.
- Любая работа по palette contract alignment, grid semantics, text layout ownership, or other snapshot families outside stroke runtime metadata.
- Любая попытка сохранить `pointsRevision` как новый публичный JSON field или заменить его другим публичным stroke freshness field.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/contract/snapshot.dart`
- `lib/src/contract/internal/node_boundary_schema_snapshot.dart`
- `lib/src/contract/internal/snapshot_backing.dart`
- `lib/src/contract/internal/snapshot_materialization.dart`
- `lib/src/contract/internal/snapshot_boundary_impl.dart`
- `lib/src/contract/internal/snapshot_node_boundary_fallback.dart`
- `lib/src/model/scene_builder_decode_stroke.dart`
- `lib/src/model/scene_node_boundary_mapping_stroke.dart`
- `lib/src/model/scene_policy.dart`
- `lib/src/model/scene_value_validation_node_stroke.dart`
- `lib/src/render/cache/scene_stroke_path_cache.dart`
- `lib/src/render/render_geometry_builder.dart`
- `lib/src/serialization/scene_codec.dart`
- `tool/invariant_registry.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Test Files

- `test/contract/validated_fast_path_contract_test.dart`
- `test/core/nodes_test.dart`
- `test/model/document_model_test.dart`
- `test/model/scene_builder_test.dart`
- `test/model/scene_value_validation_primitives_test.dart`
- `test/public_api/snapshot_immutability_test.dart`
- `test/render/scene_stroke_path_cache_test.dart`
- `test/render/render_geometry_cache_test.dart`
- `test/render/scene_render_caches_test.dart`
- `test/render/render_hit_bounds_parity_test.dart`
- `test/controller/core/scene_controller_commit_atomicity_test.dart`
- `test/serialization/scene_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/view/scene_view_interactive_test.dart`
- `test/view/scene_view_test.dart`

### Fixture and Supporting Data Files

- `PLAN.md`
- `plan/step_87_remove_stroke_points_revision_from_public_snapshot_boundary.md`
- `VERIFICATION.md`

### Analysis Area

- `lib/src/contract/**`
- `lib/src/model/**`
- `lib/src/render/**`
- `lib/src/serialization/**`
- `tool/**`
- `test/contract/**`
- `test/core/**`
- `test/model/**`
- `test/render/**`
- `test/controller/**`
- `test/serialization/**`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every newly proposed file or directory name must comply with the global `AGENTS.md` section `### File naming`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `StrokeNode.pointsRevision` remains runtime metadata owned by the runtime stroke geometry owner and is not part of the public scene document contract.
2. `StrokeNodeSnapshot.pointsRevision` is removed from the public snapshot boundary in this step and is not replaced by another public stroke freshness field.
3. Public JSON stroke payload shape remains document-only; this step does not add `pointsRevision` to JSON and does not introduce a new schema field to preserve removed runtime metadata.
4. Render and cache read-side freshness for public stroke snapshots must stop depending on `StrokeNodeSnapshot.pointsRevision` and must use public stroke geometry/scalar payload instead.
5. Public snapshot import from typed snapshot and public JSON decode must no longer accept external stroke revision input; imported runtime stroke revisions are resolved only by runtime owner defaults and later runtime mutations.
6. `ScenePolicy` remains the single owner of scene-level semantics in this step; this change does not reopen duplicate-id or global-validity architecture.

## 5. Result Requirements

1. `StrokeNodeSnapshot` no longer exposes a public `pointsRevision` field or constructor parameter.
2. Public snapshot export, typed snapshot import, and JSON decode/encode no longer transport, validate, or preserve stroke `pointsRevision`.
3. Runtime `StrokeNode` keeps `pointsRevision` and continues to update it only through runtime stroke geometry ownership.
4. Stroke render/cache reuse for public snapshots continues to be correct without reading any public stroke revision metadata.
5. Repository docs and invariants describe `pointsRevision` as runtime-only metadata rather than persisted scene document data.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `lib/src/contract/snapshot.dart` currently exposes `pointsRevision` on the public `StrokeNodeSnapshot` constructor and getter.
- `lib/src/contract/internal/node_boundary_schema_snapshot.dart`, `lib/src/contract/internal/snapshot_backing.dart`, `lib/src/contract/internal/snapshot_materialization.dart`, `lib/src/contract/internal/snapshot_boundary_impl.dart`, and `lib/src/contract/internal/snapshot_node_boundary_fallback.dart` currently treat stroke snapshot revision as part of public snapshot state.
- `lib/src/model/scene_builder_decode_stroke.dart` already decodes public JSON with `pointsRevision: 0`, while `lib/src/serialization/scene_codec.dart` already omits the field from JSON, so typed snapshot import/export currently diverges from JSON persistence semantics.
- `lib/src/model/scene_node_boundary_mapping_stroke.dart`, `lib/src/model/scene_value_validation_node_stroke.dart`, and `lib/src/model/scene_policy.dart` currently read and validate public snapshot `pointsRevision`.
- `lib/src/render/cache/scene_stroke_path_cache.dart` and `lib/src/render/render_geometry_builder.dart` currently use `StrokeNodeSnapshot.pointsRevision` as part of the public stroke freshness contract.
- `tool/invariant_registry.dart`, `API_GUIDE.md`, and runtime/model tests currently document or assert the public presence of `StrokeNodeSnapshot.pointsRevision`.
- `test/view/scene_view_test.dart`, `test/view/scene_view_interactive_test.dart`, `test/render/scene_render_caches_test.dart`, `test/render/render_hit_bounds_parity_test.dart`, `test/model/scene_value_validation_primitives_test.dart`, and `test/public_api/snapshot_immutability_test.dart` currently construct public `StrokeNodeSnapshot` values through the public `pointsRevision` parameter and therefore must be kept inside the planned proof surface.

### 6.2 Target Verification Units

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test shard preset `core`
- MCP test shard preset `model_contract`
- MCP test shard preset `controller_internal`
- MCP test shard preset `controller`
- MCP test shard preset `render_view`
- MCP test shard preset `interactive`
- MCP test shard preset `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`

### 6.3 Protected States, Data, or Structures

- Runtime `StrokeNode.pointsRevision` monotonicity and no-op behavior under `StrokeNode.replacePoints(...)`.
- Public JSON stroke payload fields `localPoints`, `thickness`, and `color`.
- Existing `instanceRevision` identity semantics for public nodes and render/cache keys.
- Stroke render output and stroke bounds for unchanged public stroke geometry.
- Scene-level validation ownership in `ScenePolicy`.

### 6.4 Allowed Semantic Change Zones

- Public stroke snapshot contract shape.
- Public snapshot import/export and JSON/document persistence semantics for stroke runtime metadata.
- Stroke read-side render/cache freshness contract for public snapshots.
- Runtime-vs-public documentation and invariant wording for stroke geometry revision ownership.

### 6.6 Allowed Forms That Do Not Count as Violations

- Runtime `StrokeNode` continuing to own `pointsRevision` internally.
- Public JSON decode/import continuing to create runtime strokes with the runtime default revision before later geometry mutations advance it.
- Render/cache code using public stroke points and scalar geometry data to decide reuse.

### 6.8 Prohibited

- Keeping `pointsRevision` public on `StrokeNodeSnapshot` while only updating prose to describe it as internal.
- Adding `pointsRevision` to JSON as a compatibility escape hatch.
- Introducing a new public stroke revision/hash field as a replacement for the removed metadata.
- Leaving render/cache freshness dependent on hidden runtime metadata that is no longer part of the public stroke snapshot contract.
- Expanding this step into draft-layer work, snapshot-global-validity work, or palette contract work.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice changes public stroke render/cache freshness semantics, unchanged-geometry hit scenarios and changed-geometry rebuild scenarios must both be covered.
7. If a slice changes the public snapshot contract, typed import/export and JSON persistence behavior must both be covered.
8. Scope expansion is forbidden until the mandatory slices are closed.
9. The plan must be detailed enough that the implementing agent has no material branch in how to execute a slice.
10. Every newly proposed file or directory name must comply with the global `AGENTS.md` section `### File naming`.

## 8. Vertical Slices

### Slice 1. [ ] Stroke Render Freshness Without Public Revision

#### Slice Contract

Public stroke render/cache reuse no longer depends on `StrokeNodeSnapshot.pointsRevision`, while unchanged public stroke geometry still hits caches and changed public stroke geometry still rebuilds them.

#### Change

Перестроить `lib/src/render/cache/scene_stroke_path_cache.dart` и `lib/src/render/render_geometry_builder.dart` так, чтобы stroke cache/path/geometry validity keys for public snapshots used only public geometry/scalar payload already present on `StrokeNodeSnapshot` plus existing node identity inputs (`id`, `instanceRevision`, `transform` where applicable), and удалить read-side dependency on public `pointsRevision`. Обновить proofs in `test/render/scene_stroke_path_cache_test.dart`, `test/render/render_geometry_cache_test.dart`, and `test/controller/core/scene_controller_commit_atomicity_test.dart` so cache-hit/rebuild behavior is asserted through unchanged vs changed public stroke geometry instead of public revision access.

#### Verification

- MCP test runner: root `.` paths `test/render/scene_stroke_path_cache_test.dart`
- MCP test runner: root `.` paths `test/render/render_geometry_cache_test.dart`
- MCP test runner: root `.` paths `test/render/scene_render_caches_test.dart`
- MCP test runner: root `.` paths `test/render/render_hit_bounds_parity_test.dart`
- MCP test runner: root `.` paths `test/controller/core/scene_controller_commit_atomicity_test.dart`

#### Positive Scenarios

- Equivalent public stroke snapshots with the same points and thickness reuse render/cache results.
- Unrelated controller commits that do not change public stroke geometry keep render/cache hits.

#### Negative Scenarios

- Changing public stroke points rebuilds stroke path/render geometry entries.
- Changing public stroke thickness rebuilds stroke geometry/path consumers where thickness participates in the result.

#### Closure Evidence

- Green run of the listed verifications.

### Slice 2. [ ] Public Stroke Snapshot Contract Drops Runtime Revision Metadata

#### Slice Contract

`StrokeNodeSnapshot` stops carrying `pointsRevision` as public scene document data, and typed snapshot import/export plus JSON persistence no longer expose, validate, or preserve stroke runtime revision metadata.

#### Change

Удалить `pointsRevision` from public `StrokeNodeSnapshot` in `lib/src/contract/snapshot.dart`, then rewire `lib/src/contract/internal/node_boundary_schema_snapshot.dart`, `lib/src/contract/internal/snapshot_backing.dart`, `lib/src/contract/internal/snapshot_materialization.dart`, `lib/src/contract/internal/snapshot_boundary_impl.dart`, and `lib/src/contract/internal/snapshot_node_boundary_fallback.dart` so the public snapshot graph no longer stores stroke revision metadata. Update `lib/src/model/scene_builder_decode_stroke.dart`, `lib/src/model/scene_node_boundary_mapping_stroke.dart`, `lib/src/model/scene_value_validation_node_stroke.dart`, `lib/src/model/scene_policy.dart`, and `lib/src/serialization/scene_codec.dart` so public typed import/export and JSON persistence treat stroke revision as runtime-only metadata and create runtime strokes through runtime default revision semantics instead of external snapshot input. Rewrite the affected contract/model/serialization proofs in `test/contract/validated_fast_path_contract_test.dart`, `test/model/document_model_test.dart`, `test/model/scene_builder_test.dart`, and `test/serialization/scene_test.dart` / `test/serialization/scene_codec_validation_test.dart` around the new public contract.

#### Verification

- MCP test runner: root `.` paths `test/contract/validated_fast_path_contract_test.dart`
- MCP test runner: root `.` paths `test/model/document_model_test.dart`
- MCP test runner: root `.` paths `test/model/scene_builder_test.dart`
- MCP test runner: root `.` paths `test/model/scene_value_validation_primitives_test.dart`
- MCP test runner: root `.` paths `test/public_api/snapshot_immutability_test.dart`
- MCP test runner: root `.` paths `test/serialization/scene_test.dart`
- MCP test runner: root `.` paths `test/serialization/scene_codec_validation_test.dart`
- MCP test runner: root `.` paths `test/view/scene_view_interactive_test.dart`
- MCP test runner: root `.` paths `test/view/scene_view_test.dart`

#### Positive Scenarios

- Public stroke snapshots still preserve document data needed to rebuild runtime stroke geometry.
- `encodeScene` / `decodeScene` remain stable for stroke JSON payloads without introducing a new field.
- Runtime scene export to public snapshot still preserves stroke points, thickness, color, and node identity.

#### Negative Scenarios

- Public typed stroke snapshot creation no longer accepts a `pointsRevision` argument.
- Typed public snapshot import/export no longer preserves runtime stroke revision metadata across `txnSceneToSnapshot(...)` / `txnSceneFromSnapshot(...)`.
- Public snapshot validation and policy no longer expose path-aware failures for `layers[*].nodes[*].pointsRevision`.

#### Closure Evidence

- Green run of the listed verifications.

### Slice 3. [ ] Source Of Truth Pins Stroke Runtime/Public Split

#### Slice Contract

Repository docs, invariant wording, roadmap state, and public-surface/tool checks all describe `pointsRevision` as runtime-only stroke metadata and no longer describe it as public snapshot state.

#### Change

Обновить `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, `tool/invariant_registry.dart`, `PLAN.md`, and this step document so stroke revision ownership is documented consistently as runtime-only metadata. Run public-surface, guardrail, invariant, and tool-test checks required by `VERIFICATION.md` for a code change that touches public contract and tooling source-of-truth files.

#### Verification

- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`

#### Positive Scenarios

- Public API surface checks accept the updated `StrokeNodeSnapshot` contract.
- Invariant coverage stays exact after the registry wording changes.

#### Negative Scenarios

- No repository source-of-truth file still describes `StrokeNodeSnapshot.pointsRevision` as public persisted scene data.
- No public-surface or tool regression relies on the removed public field.

#### Closure Evidence

- Green run of the listed verifications.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test shard preset `core`
- MCP test shard preset `model_contract`
- MCP test shard preset `controller_internal`
- MCP test shard preset `controller`
- MCP test shard preset `render_view`
- MCP test shard preset `interactive`
- MCP test shard preset `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
