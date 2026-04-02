language: russian

# Шаг 82. Выровнять runtime numeric write semantics на reject-only policy для `opacity` и grid cell size

## 1. Change Mandate

Этот шаг убирает silent normalization у runtime write-paths для `SceneNode.opacity` и background grid cell size, переводит engine-owned numeric writes на reject-only policy и удаляет commit-time grid normalization как второй owner numeric semantics.

## 2. Change Boundary

### Included in the Change

- Перевод `SceneNode.opacity` setter semantics с clamp/fallback на reject-on-write.
- Перевод runtime `GridSettings` writes на reject-on-write semantics вместо post-write normalization.
- Удаление commit-time grid normalization owner из controller commit plan.
- Перевод interactive/controller mutation boundaries на reject semantics вместо clamping.
- Обновление repository source of truth: `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, `PLAN.md`, this step file, `tool/invariant_registry.dart`.

### Not Included in the Change

- Любая смена typed/public snapshot numeric contracts за пределами уже существующих boundary checks.
- Любая работа по palette mutability, stroke geometry owner, text layout ownership, transform convenience API.
- Любая отмена render/hit-test defensive crash-safety guards как read-side protection.
- Любая смена JSON schema.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/core/scene_node.dart`
- `lib/src/core/scene.dart`
- `lib/src/model/document_selection.dart`
- `lib/src/controller/internal/grid_normalizer.dart`
- `lib/src/controller/scene_controller_commit_plan.dart`
- `lib/src/interactive/internal/scene_controller_mutation_boundary.dart`
- `tool/invariant_registry.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Test Files

- `test/core/nodes_test.dart`
- `test/controller/internal/scene_writer_test.dart`
- `test/controller/core/scene_controller_writer_lifecycle_test.dart`
- `test/controller/scene_invariants_test.dart`
- `test/interactive/core/scene_controller_mutation_boundary_test.dart`
- `test/model/document_model_test.dart`
- `test/serialization/scene_codec_validation_test.dart`

### Fixture and Supporting Data Files

- `PLAN.md`
- `plan/step_82_runtime_numeric_write_reject_policy.md`
- `VERIFICATION.md`

### Analysis Area

- `lib/src/core/**`
- `lib/src/model/**`
- `lib/src/controller/**`
- `lib/src/interactive/**`
- `tool/**`
- `test/core/**`
- `test/model/**`
- `test/controller/**`
- `test/interactive/**`
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
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Engine-owned runtime write semantics for `SceneNode.opacity` become reject-only: invalid values must throw on write instead of being clamped or defaulted.
2. Engine-owned runtime write semantics for background grid cell size become reject-only: invalid values must throw on write instead of being clamped or normalized later during commit.
3. `GridSettings` itself becomes the runtime owner of its validity envelope: `cellSize` must stay finite and `> 0`, and enabling the grid must not permit a runtime state with `cellSize < kMinGridCellSize`.
4. `GridNormalizer` and commit-time grid normalization are removed as canonical write owners; commit planning may keep selection normalization but must not silently repair grid numeric state.
5. Interactive/controller mutation boundaries reject undersized or invalid grid writes instead of clamping them.
6. Read-side crash-safety guards in render/hit-test code may remain, but they are not allowed to define canonical write semantics.
7. No new `lib/**` production file is introduced for this step.
8. `GridSettings` constructor validates the resolved `(isEnabled, cellSize)` pair eagerly; `GridSettings.cellSize` setter rejects non-finite or non-positive values and rejects values `< kMinGridCellSize` while grid is enabled; `GridSettings.isEnabled` setter rejects enabling the grid when current `cellSize < kMinGridCellSize`.
9. This step does not keep any supported ordering trick where callers temporarily enter an invalid grid state and rely on a later write or commit phase to repair it.

## 5. Result Requirements

1. Writing invalid `opacity` to a runtime node throws instead of silently normalizing the value.
2. Writing invalid grid cell size to runtime/controller/interactive engine-owned paths throws instead of silently normalizing it.
3. Controller commit planning no longer has a grid normalization phase that repairs previously accepted invalid grid numeric state.
4. Runtime docs and invariant wording describe reject-only numeric write semantics consistently for the touched fields.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `lib/src/core/scene_node.dart` currently normalizes `opacity` with `clamp01Finite(...)` at assignment time.
- `lib/src/core/scene.dart` currently stores `GridSettings.cellSize` and `isEnabled` as unconstrained mutable fields with only prose guidance.
- `lib/src/model/document_selection.dart` currently contains `txnNormalizeGrid(...)`, which repairs undersized enabled-grid runtime state after mutation.
- `lib/src/controller/internal/grid_normalizer.dart` and `lib/src/controller/scene_controller_commit_plan.dart` currently keep commit-time grid normalization as a separate owner.
- `lib/src/interactive/internal/scene_controller_mutation_boundary.dart` currently clamps undersized enabled-grid writes instead of rejecting them.
- `test/core/nodes_test.dart` currently proves `opacity` clamping behavior.
- `tool/invariant_registry.dart` currently contains `INV-ENG-WRITE-NUMERIC-GUARDS` with wording that must stay aligned with the post-change reject-only semantics.

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

### 6.3 Protected States, Data, or Structures

- Typed/public snapshot validation remains reject-based.
- JSON decode/encode numeric contracts remain reject-based.
- Render/hit-test crash-safety guards remain defensive read-side logic.
- Selection normalization remains in commit planning.

### 6.4 Allowed Semantic Change Zones

- Runtime setter semantics for `opacity` and `GridSettings`.
- Controller commit planning for grid normalization.
- Interactive/controller mutation boundary semantics for grid writes.
- Runtime numeric-policy documentation and invariant wording.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- direct runtime setter writes to `opacity`;
- direct runtime writes to `GridSettings.cellSize` and grid enablement;
- controller write-path grid updates;
- interactive mutation-boundary grid updates;
- commit-plan flows that previously repaired invalid grid state after mutation.

### 6.6 Allowed Forms That Do Not Count as Violations

- Boundary rejection in typed snapshot and JSON decode paths.
- Read-side rendering that still degrades safely when handed invalid state by unsupported code.
- Existing positive finite checks in writer/controller mutation guards.

### 6.8 Prohibited

- Silent clamping or fallback assignment for `opacity`.
- Commit-time or interactive clamping for undersized grid cell size.
- Keeping a second numeric-policy owner that repairs invalid runtime grid state after write.
- Reintroducing mixed `normalize here / reject there` semantics for the touched numeric fields.
- Leaving `GridSettings` setter ordering ambiguous such that `isEnabled` and `cellSize` can still be written into an invalid pair and only fail later.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the trigger point must be attached.
7. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [ ] Reject-Only Runtime Setter Semantics

#### Slice Contract

`SceneNode.opacity` and runtime grid settings reject invalid numeric writes immediately instead of silently normalizing them.

#### Change

Перестроить `lib/src/core/scene_node.dart` and `lib/src/core/scene.dart` so `SceneNode.opacity`, `GridSettings.cellSize`, `GridSettings.isEnabled`, and the `GridSettings` constructor all reject invalid writes eagerly, update any direct runtime mutation helpers that depend on those setters, and rewrite the runtime proofs that currently assert clamping behavior.

#### Verification

- `flutter analyze`
- MCP test run: root `.` paths `test/core/nodes_test.dart`, `test/model/document_model_test.dart`

#### Positive Scenarios

- Writing valid `opacity` remains supported.
- Writing valid positive grid cell sizes remains supported.
- Enabling grid with a valid cell size remains supported.

#### Negative Scenarios

- Invalid `opacity` writes throw instead of clamping.
- Invalid or undersized enabled-grid writes throw instead of creating repairable runtime state.

#### Closure Evidence

- Green run of the listed verifications.

### Slice 2. [ ] Controller And Interactive Numeric Policy Alignment

#### Slice Contract

Controller commit planning and interactive/controller mutation boundaries no longer re-own numeric canonicalization for grid state; they reject invalid writes and commit without a grid normalization phase.

#### Change

Удалить `txnNormalizeGrid(...)`-based commit repair from `lib/src/model/document_selection.dart`, `lib/src/controller/internal/grid_normalizer.dart`, and `lib/src/controller/scene_controller_commit_plan.dart`, перевести `lib/src/interactive/internal/scene_controller_mutation_boundary.dart` на reject semantics, and обновить proofs in `test/controller/internal/scene_writer_test.dart`, `test/controller/core/scene_controller_writer_lifecycle_test.dart`, `test/controller/scene_invariants_test.dart`, `test/interactive/core/scene_controller_mutation_boundary_test.dart`, `test/serialization/scene_codec_validation_test.dart`, plus invariant wording in `tool/invariant_registry.dart`.

#### Verification

- `flutter analyze`
- MCP test run: root `.` paths `test/controller/internal/scene_writer_test.dart`, `test/controller/core/scene_controller_writer_lifecycle_test.dart`, `test/controller/scene_invariants_test.dart`
- MCP test run: root `.` paths `test/interactive/core/scene_controller_mutation_boundary_test.dart`
- MCP test run: root `.` paths `test/serialization/scene_codec_validation_test.dart`

#### Positive Scenarios

- Valid writer and interactive grid updates still succeed.
- Commit planning still performs selection normalization and other non-grid phases correctly.

#### Negative Scenarios

- No controller or interactive write path clamps invalid grid cell size.
- No commit plan phase silently repairs grid numeric state after mutation.

#### Closure Evidence

- Green run of the listed verifications.
- Diagnostic output for rejected invalid numeric writes where applicable.

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

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
