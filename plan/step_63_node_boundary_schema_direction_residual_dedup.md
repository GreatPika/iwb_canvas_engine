language: russian

# Шаг 63. Убрать residual duplication между direction owner-ами в `node_boundary_schema`

## 1. Change Mandate

Этот шаг дожимает residual duplication внутри уже правильно разрезанного
`node_boundary_schema` graph:
`node_boundary_schema_common.dart`,
`node_boundary_schema_patch.dart`,
`node_boundary_schema_spec.dart`,
и
`node_boundary_schema_snapshot.dart`
сохраняют текущие owner boundaries, но перестают повторять общий field-level
смысл там, где patch/spec/snapshot всё ещё выражают один и тот же контракт
параллельными каркасами.

После шага
`node_boundary_schema.dart`
остаётся thin canonical internal import surface,
`node_boundary_schema_common.dart`
остаётся владельцем truly shared field semantics,
а direction owner-ы держат только direction-specific requiredness,
`PatchField` semantics, и snapshot/spec-specific assembly.

## 2. Change Boundary

### Included in the Change

- `lib/src/contract/internal/node_boundary_schema.dart`
- `lib/src/contract/internal/node_boundary_schema_common.dart`
- `lib/src/contract/internal/node_boundary_schema_patch.dart`
- `lib/src/contract/internal/node_boundary_schema_spec.dart`
- `lib/src/contract/internal/node_boundary_schema_snapshot.dart`
- `lib/src/contract/node_patch.dart` only if direct adaptation is required to
  preserve the thin canonical schema surface
- `lib/src/contract/node_spec.dart` only if direct adaptation is required to
  preserve the thin canonical schema surface
- `lib/src/contract/snapshot.dart` only if direct adaptation is required to
  preserve the thin canonical schema surface
- `lib/src/serialization/scene_codec.dart` only if direct adaptation is
  required by the residual dedup
- `lib/src/model/**` only where a call site must adapt to the deduplicated
  internal schema surface without taking schema ownership
- `test/contract/patch_field_test.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/contract/validated_fast_path_contract_test.dart`
- `test/contract/validated_internal_helpers_test.dart`
- `test/contract/contract_layer_smoke_test.dart`
- `test/public_api/node_patch_semantics_test.dart`
- `test/public_api/snapshot_immutability_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/model/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/serialization/scene_fixture_test.dart`
- `PLAN.md`
- `plan/contract_target_architecture.md`
- `plan/step_52_node_boundary_schema_explicit_owner_split.md`
- `plan/step_54_node_spec_and_patch_explicit_fast_path_modules.md`
- `plan/step_55_contract_final_architecture_closure.md`
- `plan/step_63_node_boundary_schema_direction_residual_dedup.md`

### Not Included in the Change

- `lib/src/contract/internal/node_patch_fast_path.dart`
- `lib/src/contract/internal/node_spec_fast_path.dart`
- `lib/src/contract/internal/snapshot_backing.dart`
- `lib/src/contract/internal/snapshot_materialization.dart`
- `lib/src/model/scene_node_boundary_mapping*.dart`
- `lib/src/model/scene_value_validation*.dart`
- `ARCHITECTURE.md`
- `API_GUIDE.md`
- `README.md`
- `CHANGELOG.md`
- Any new generic schema bucket such as `node_boundary_schema_support.dart`
- Reopening the direction split already closed by step `52`

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/contract/internal/node_boundary_schema.dart`
- `lib/src/contract/internal/node_boundary_schema_common.dart`
- `lib/src/contract/internal/node_boundary_schema_patch.dart`
- `lib/src/contract/internal/node_boundary_schema_spec.dart`
- `lib/src/contract/internal/node_boundary_schema_snapshot.dart`
- `PLAN.md`

### Test Files

- `test/contract/patch_field_test.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/contract/validated_fast_path_contract_test.dart`
- `test/contract/validated_internal_helpers_test.dart`
- `test/contract/contract_layer_smoke_test.dart`
- `test/public_api/node_patch_semantics_test.dart`
- `test/public_api/snapshot_immutability_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/model/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/serialization/scene_fixture_test.dart`

### Fixture and Supporting Data Files

- `plan/contract_target_architecture.md`
- `plan/step_52_node_boundary_schema_explicit_owner_split.md`
- `plan/step_54_node_spec_and_patch_explicit_fast_path_modules.md`
- `plan/step_55_contract_final_architecture_closure.md`
- `plan/step_63_node_boundary_schema_direction_residual_dedup.md`

### Analysis Area

- `lib/src/contract/internal/node_boundary_schema*.dart`
- `lib/src/contract/node_patch.dart`
- `lib/src/contract/node_spec.dart`
- `lib/src/contract/snapshot.dart`
- `lib/src/serialization/scene_codec.dart`
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

- Every modified schema file must be tied either to one truly shared
  field-level contract moved into `node_boundary_schema_common.dart` or to one
  direction-local simplification that removes duplicated common scaffolding.
- Every modified downstream file must only adapt to the deduplicated internal
  schema surface; it must not take ownership of schema logic.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `plan/contract_target_architecture.md` remains the source of truth for the
   post-step-`55` contract graph.
2. `lib/src/contract/internal/node_boundary_schema.dart` remains the thin
   canonical internal schema import surface.
3. `lib/src/contract/internal/node_boundary_schema_common.dart` remains the
   only owner of truly shared field semantics, primitive validations, and
   validated-to-field transforms that are meaningfully identical across
   directions.
4. `lib/src/contract/internal/node_boundary_schema_patch.dart`,
   `lib/src/contract/internal/node_boundary_schema_spec.dart`,
   and
   `lib/src/contract/internal/node_boundary_schema_snapshot.dart`
   keep ownership only of direction-specific semantics:
   requiredness,
   `PatchField` nullability rules,
   and snapshot/spec-specific field assembly.
5. This step must not reintroduce a static schema bucket, a descriptor system
   for its own sake, or a new `support/helpers/utils` module.
6. Public boundary types remain the only public owners; internal schema logic
   must not move into public files.
7. Metric or clone improvement counts only when duplicated shared meaning is
   genuinely unified, not when code is hidden behind opaque indirection.

## 5. Result Requirements

1. `node_boundary_schema.dart` remains a thin barrel and does not regain mixed
   schema logic.
2. Shared field semantics that are currently duplicated across
   `patch/spec/snapshot` owners live in one canonical place in
   `node_boundary_schema_common.dart`.
3. Direction owners keep only the logic that is genuinely direction-specific.
4. Residual duplicated scaffolding for common node fields and shared family
   field semantics is reduced without changing public behavior.
5. `NodePatch`, `NodeSpec`, `NodeSnapshot`, `SceneBuilder`, and
   `scene_codec.dart` keep the same visible behavior and error attribution.
6. No new generic schema bucket or second internal schema path is introduced.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Step `52` already closed the structural split: `node_boundary_schema.dart`
  is a thin barrel over explicit common / patch / spec / snapshot owners.
- The residual seam is now inside those direction owners:
  `node_boundary_schema_common.dart` already owns primitive validators,
  but direction files still carry parallel field-level assembly for common
  node fields and some family-local optional or collection semantics.
- `node_boundary_schema_snapshot.dart` already legitimately reuses
  `node_boundary_schema_spec.dart` for part of text and stroke validation;
  this step must extend the same principle only where the meaning is truly
  shared.
- `PatchField` behavior in `node_boundary_schema_patch.dart` remains
  direction-specific and must not be flattened into spec/snapshot code.
- `node_patch.dart`, `node_spec.dart`, `snapshot.dart`, `scene_codec.dart`,
  and model call sites may adapt only to the deduplicated internal surface.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/contract/internal/node_boundary_schema.dart lib/src/contract/internal/node_boundary_schema_common.dart lib/src/contract/internal/node_boundary_schema_patch.dart lib/src/contract/internal/node_boundary_schema_spec.dart lib/src/contract/internal/node_boundary_schema_snapshot.dart lib/src/contract/node_patch.dart lib/src/contract/node_spec.dart lib/src/contract/snapshot.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract`
- `dart run tool/analysis/find_similar_clones.dart lib/src/contract`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner preset: `model_contract`
- MCP test runner preset: `core`
- MCP test runner preset: `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`

### 6.3 Protected States, Data, or Structures

- Public `NodePatch`, `NodeSpec`, and `NodeSnapshot` semantics.
- Error-code, path, and details attribution on validated boundary failures.
- Snapshot immutability guarantees and owned-collection semantics.
- Thin canonical internal import through `node_boundary_schema.dart`.

### 6.4 Allowed Semantic Change Zones

- Shared field-level schema semantics in
  `lib/src/contract/internal/node_boundary_schema_common.dart`
- Direction-local assembly cleanup in
  `lib/src/contract/internal/node_boundary_schema_patch.dart`,
  `lib/src/contract/internal/node_boundary_schema_spec.dart`,
  and
  `lib/src/contract/internal/node_boundary_schema_snapshot.dart`
- Minimal downstream rewiring required to preserve the thin canonical schema
  surface after the dedup

### 6.8 Prohibited

- Reopening the direction split from step `52`.
- Replacing residual duplication with a new opaque descriptor framework whose
  primary purpose is only to appease metrics or clone tools.
- Moving internal schema logic into public boundary files.
- Reopening `node_patch_fast_path.dart`, `node_spec_fast_path.dart`,
  or snapshot materialization as part of this step.
- Expanding the scope into model validation, scene import/export, or render
  work.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice changes field validation attribution, the exact visible failure
   surface must be pinned by tests in the same change.
7. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [ ] Centralize truly shared field semantics in `node_boundary_schema_common.dart`

#### Slice Contract

Field-level semantics that are genuinely identical across directions are owned
once in `node_boundary_schema_common.dart` instead of being rebuilt in
parallel by `patch/spec/snapshot` owners.

#### Change

Move or factor the confirmed shared field-level validation and
validated-to-field assembly into
`lib/src/contract/internal/node_boundary_schema_common.dart`
while keeping only direction-specific wrappers in the direction owners.

#### Verification

- `dcm calculate-metrics lib/src/contract/internal/node_boundary_schema_common.dart lib/src/contract/internal/node_boundary_schema_patch.dart lib/src/contract/internal/node_boundary_schema_spec.dart lib/src/contract/internal/node_boundary_schema_snapshot.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract`
- MCP test runner preset: `model_contract`

#### Positive Scenarios

- Shared text optional field semantics stay identical across spec/snapshot and
  any direction that reuses them.
- Shared common node-field semantics keep the same accepted values and failure
  attribution.

#### Negative Scenarios

- `PatchField`-specific nullability rules do not leak into spec or snapshot.
- `node_boundary_schema_common.dart` does not become a second mixed bucket for
  direction-specific logic.

#### Closure Evidence

- Green run of the listed verifications.
- Confirmed shared field semantics have one canonical owner in
  `node_boundary_schema_common.dart`.

### Slice 2. [ ] Reduce residual scaffolding in patch/spec/snapshot direction owners

#### Slice Contract

Direction owners keep only direction-specific semantics and stop carrying
parallel copies of common field or family scaffolding that is already owned by
the common schema module.

#### Change

Refactor
`lib/src/contract/internal/node_boundary_schema_patch.dart`,
`lib/src/contract/internal/node_boundary_schema_spec.dart`,
and
`lib/src/contract/internal/node_boundary_schema_snapshot.dart`
so they delegate shared field semantics to the common owner while preserving
their direction-specific wrappers, `PatchField` handling, and snapshot/spec
assembly rules.

#### Verification

- `dcm calculate-metrics lib/src/contract/internal/node_boundary_schema_patch.dart lib/src/contract/internal/node_boundary_schema_spec.dart lib/src/contract/internal/node_boundary_schema_snapshot.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract`
- MCP test runner preset: `model_contract`
- MCP test runner preset: `core`
- MCP test runner preset: `example`

#### Positive Scenarios

- `NodePatch`, `NodeSpec`, and `NodeSnapshot` still expose the same visible
  semantics.
- `SceneBuilder` and codec paths still construct the same validated schema
  objects.
- Snapshot/spec reuse stays explicit where the meaning is shared.

#### Negative Scenarios

- `node_boundary_schema.dart` does not regain logic beyond barrel exports.
- Direction owners do not reintroduce the removed parallel scaffolding through
  local wrappers with different names.
- No second internal schema path appears beside the canonical barrel.

#### Closure Evidence

- Green run of the listed verifications.
- Direction owners are visibly narrower in shared scaffolding and remain
  focused on direction-specific semantics.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner preset: `core`
- MCP test runner preset: `model_contract`
- MCP test runner preset: `controller_internal`
- MCP test runner preset: `controller`
- MCP test runner preset: `render_view`
- MCP test runner preset: `interactive`
- MCP test runner preset: `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
