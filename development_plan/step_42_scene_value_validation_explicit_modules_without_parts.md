language: russian

# Шаг 42. Разрезать `scene_value_validation` на explicit validation owner-модули без `part`-coupling

## 1. Change Mandate

Этот шаг переводит `scene_value_validation` с shared-library `part` layout на
explicit validation owner-модули так, чтобы
`scene_value_validation.dart` остался canonical facade для downstream
consumers, а реальная validation logic жила в обычных model-local modules без
reopening `ScenePolicy` или primitive-rule ownership.

## 2. Change Boundary

### Included in the Change

- `lib/src/model/scene_value_validation.dart`
- `lib/src/model/scene_value_validation_primitives.part.dart`
- `lib/src/model/scene_value_validation_palette_grid.part.dart`
- `lib/src/model/scene_value_validation_node.part.dart`
- `lib/src/model/scene_value_validation_top_level.part.dart`
- `lib/src/model/scene_value_validation_primitives.dart`
- `lib/src/model/scene_value_validation_palette_grid.dart`
- `lib/src/model/scene_value_validation_node.dart`
- `lib/src/model/scene_value_validation_top_level.dart`
- Tooling and proofs tied directly to the removed `part` layout:
  `tool/check_coverage.dart` and `test/tool/coverage_tool_test.dart`

### Not Included in the Change

- `scene_node_boundary_mapping*.dart` decomposition already covered by step
  `41`
- Builder-local decode/require ownership from step `40`
- `ScenePolicy` scene-level traversal, duplicate-id, and range semantics
- `document.dart` owner split
- Public API surface changes in `lib/iwb_canvas_engine.dart`

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/model/scene_value_validation.dart`
- `lib/src/model/scene_value_validation_primitives.part.dart`
- `lib/src/model/scene_value_validation_palette_grid.part.dart`
- `lib/src/model/scene_value_validation_node.part.dart`
- `lib/src/model/scene_value_validation_top_level.part.dart`
- `lib/src/model/scene_value_validation_primitives.dart`
- `lib/src/model/scene_value_validation_palette_grid.dart`
- `lib/src/model/scene_value_validation_node.dart`
- `lib/src/model/scene_value_validation_top_level.dart`
- `tool/check_coverage.dart`

### Test Files

- `test/model/scene_value_validation_primitives_test.dart`
- `test/model/scene_builder_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/tool/coverage_tool_test.dart`

### Fixture and Supporting Data Files

- `development_plan/step_41_scene_node_boundary_mapping_family_modules_without_parts.md`
- `development_plan/step_42_scene_value_validation_explicit_modules_without_parts.md`

### Analysis Area

- `lib/src/model/scene_value_validation*.dart`
- `lib/src/model/scene_policy.dart`
- `lib/src/model/scene_builder.dart`
- `lib/src/serialization/scene_codec.dart`
- `tool/check_coverage.dart`
- `test/model/scene_value_validation_primitives_test.dart`
- `test/model/scene_builder_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/tool/coverage_tool_test.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to one validation-owner
  slice.
- Every modified tool or tool test must be tied directly to the removed
  `scene_value_validation` `part` layout.
- Every modified test must pin one validation behavior or proof surface.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. This step starts only after step `41` has closed the part-free mapping
   graph beneath the builder/runtime import spine.
2. `scene_value_validation.dart` remains the canonical model-local validation
   facade for downstream consumers.
3. `ScenePolicy` remains the single owner of scene-level traversal, duplicate
   detection, and range semantics; this step does not move those rules into
   the validation modules.
4. Primitive validation ownership stays in the existing validated helpers and
   must not fork into a second private ruleset.
5. Removing `part` is a structural goal of this step, but it must not be
   achieved by hiding logic inside a new generic `helpers` bucket.

## 5. Result Requirements

1. `lib/src/model/scene_value_validation.dart` no longer contains
   `scene_value_validation*.part.dart` declarations and becomes a thin facade
   over explicit validation modules.
2. Explicit modules exist for the validation domains:
   `primitives`,
   `palette_grid`,
   `node`,
   and `top_level`.
3. `dcm calculate-metrics` no longer reports the current `HIGH`
   `number-of-imports` hotspot on `lib/src/model/scene_value_validation.dart`.
4. `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
   no longer reports the current validation-family matrix in the same form.
5. `ScenePolicy` continues to consume one validation facade and remains the
   only owner of duplicate-id and scene-range semantics.
6. Coverage tooling and its tool tests no longer assume real validation logic
   lives in `scene_value_validation*.part.dart`; missing explicit validation
   modules with real logic still fail the coverage check.
7. Boundary-visible validation behavior, including
   `SceneBuilder.buildFromJson(...)`,
   `sceneValidateSnapshotValues(...)`,
   `sceneValidateSceneValues(...)`,
   and `decodeScene(...)` diagnostics, remains equivalent.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `scene_value_validation.dart` currently still owns four `part` declarations
  and has a `HIGH` `number-of-imports = 17` hotspot.
- The current clone inventory in `lib/src/model` still includes live
  validation-family clusters across
  `scene_value_validation_primitives.part.dart`,
  `scene_value_validation_palette_grid.part.dart`,
  `scene_value_validation_node.part.dart`,
  and top-level validation wiring.
- `ScenePolicy.validateImportSnapshot(...)` and
  `ScenePolicy.validateRuntimeScene(...)` already consume the validation
  facade; duplicate-node and range semantics remain in `scene_policy.dart` and
  must not move.
- `tool/check_coverage.dart` currently allow-lists
  `lib/src/model/scene_value_validation.dart` as a declaration-only unit, and
  `test/tool/coverage_tool_test.dart` still contains a scenario pinned to the
  legacy `scene_value_validation_primitives.part.dart` layout.
- This step must update that tooling proof so the explicit-module layout is
  mechanically enforced instead of relying on stale `part` paths.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/model/scene_value_validation.dart lib/src/model/scene_value_validation_primitives.dart lib/src/model/scene_value_validation_palette_grid.dart lib/src/model/scene_value_validation_node.dart lib/src/model/scene_value_validation_top_level.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/check_import_boundaries.dart`
- `rg -n "^part 'scene_value_validation_|^part of 'scene_value_validation" lib/src/model`
- MCP test runner:
  `test/model/scene_value_validation_primitives_test.dart test/model/scene_builder_test.dart`
- MCP test runner:
  `test/public_api/validated_boundary_value_test.dart`
- MCP test runner:
  `test/serialization/scene_codec_validation_test.dart`
- `dart run tool/run_tool_tests.dart`

### 6.3 Protected States, Data, or Structures

- Boundary-visible validation behavior and diagnostic attribution.
- Primitive validation limits and contract-owned validated helpers.
- `ScenePolicy` ownership of scene-level duplicate and range rules.
- `SceneBuilder` and codec entrypoints that consume the validation facade.

### 6.4 Allowed Semantic Change Zones

- Physical file boundaries and imports inside the validation seam.
- Tooling/tests that pin the removed `part` layout.
- Minimal consumer adaptation needed to preserve one canonical validation
  facade.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- Downstream consumers such as `scene_policy.dart`, `scene_builder.dart`, and
  `serialization/scene_codec.dart` must continue to enter the validation seam
  through `scene_value_validation.dart`; the new domain modules are internal
  implementation owners and must not become ad hoc direct dependencies.
- `scene_value_validation.dart` may import the explicit validation modules, but
  it must not re-export them.
- Tooling proofs must stop referring to `scene_value_validation*.part.dart` as
  the real-logic surface and instead pin the new explicit-module layout.
- This step removes `part` coupling by explicit module ownership, not by
  relocating mixed validation logic into `scene_policy.dart` or a generic
  `validation_utils.dart` bucket.

### 6.8 Prohibited

- Reopening scene-level duplicate-id, layer-id, or range semantics inside the
  validation modules.
- Creating a second primitive validation owner.
- Introducing new `part` / `part of` declarations in the validation seam.
- Leaving the replaced validation matrix bodies in parallel with the new
  explicit modules.
- Changing validation behavior solely to reduce metrics.

## 7. Execution Rules

1. This step starts only after step `41` is closed.
2. Slice `2` is forbidden until slice `1` is closed and verified.
3. This step closes only if the validation seam becomes both part-free and
   still single-owned relative to `ScenePolicy`.
4. Scope expansion beyond validation ownership and directly coupled tooling
   proofs is forbidden.

## 8. Vertical Slices

### Slice 1. [x] `scene_value_validation.dart` becomes a part-free thin validation facade

#### Slice Contract

The validation seam exposes the same canonical facade, but real validation
logic lives in explicit domain modules rather than in `part` files.

#### Change

Create the explicit validation modules for
`primitives`,
`palette_grid`,
`node`,
and `top_level`, route the existing public/internal validation entrypoints
through them, and remove the replaced `part` bodies from the facade.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_value_validation.dart lib/src/model/scene_value_validation_primitives.dart lib/src/model/scene_value_validation_palette_grid.dart lib/src/model/scene_value_validation_node.dart lib/src/model/scene_value_validation_top_level.dart --report-all`
- `rg -n "^part 'scene_value_validation_|^part of 'scene_value_validation" lib/src/model`
- MCP test runner:
  `test/model/scene_value_validation_primitives_test.dart test/model/scene_builder_test.dart`
- MCP test runner:
  `test/public_api/validated_boundary_value_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `scene_value_validation.dart` no longer contains the replaced `part` bodies.
- `ScenePolicy` still consumes the facade rather than direct domain modules.

### Slice 2. [x] Tooling and downstream consumers are pinned to the explicit validation-module layout

#### Slice Contract

Coverage/tool proofs and downstream validation consumers recognize the new
module layout and fail if real logic leaks back into hidden `part` files or a
mixed owner shape.

#### Change

Update the directly coupled tooling proof in `tool/check_coverage.dart` and
`test/tool/coverage_tool_test.dart`, keep `scene_policy.dart`,
`scene_builder.dart`, and `scene_codec.dart` on the canonical validation
facade, and remove the replaced validation clone matrix.

#### Verification

- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/check_import_boundaries.dart`
- MCP test runner:
  `test/serialization/scene_codec_validation_test.dart`
- `dart run tool/run_tool_tests.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Coverage/tool proofs no longer depend on `scene_value_validation*.part.dart`
  paths.
- The current validation-family clone matrix no longer appears in the same
  form.

## 9. Final Verification

- `dcm calculate-metrics lib/src/model/scene_value_validation.dart lib/src/model/scene_value_validation_primitives.dart lib/src/model/scene_value_validation_palette_grid.dart lib/src/model/scene_value_validation_node.dart lib/src/model/scene_value_validation_top_level.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/check_import_boundaries.dart`
- `rg -n "^part 'scene_value_validation_|^part of 'scene_value_validation" lib/src/model`
- MCP test runner:
  `test/model/scene_value_validation_primitives_test.dart test/model/scene_builder_test.dart`
- MCP test runner:
  `test/public_api/validated_boundary_value_test.dart`
- MCP test runner:
  `test/serialization/scene_codec_validation_test.dart`
- `dart run tool/run_tool_tests.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
