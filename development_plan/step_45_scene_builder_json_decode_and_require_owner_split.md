language: russian

# Шаг 45. Разрезать `scene_builder_decode_json` и `scene_builder_json_require` на focused JSON decode owner-ы

## 1. Change Mandate

Этот шаг переводит residual builder-side JSON decode seam с giant decode owner
на explicit scene-topology, node-common, node-family, and scalar-parse owners
так, чтобы `scene_builder.dart` остался thin import facade, а downstream
non-model code продолжал входить в decode через canonical model facades.

## 2. Change Boundary

### Included in the Change

- `lib/src/model/scene_builder.dart`
- `lib/src/model/scene_builder_decode_json.dart`
- `lib/src/model/scene_builder_json_require.dart`
- `lib/src/model/scene_builder_decode_scene.dart`
- `lib/src/model/scene_builder_decode_node_family.dart`
- `lib/src/model/scene_builder_decode_node_common.dart`
- `lib/src/model/scene_builder_decode_image.dart`
- `lib/src/model/scene_builder_decode_text.dart`
- `lib/src/model/scene_builder_decode_stroke.dart`
- `lib/src/model/scene_builder_decode_line.dart`
- `lib/src/model/scene_builder_decode_rect.dart`
- `lib/src/model/scene_builder_decode_path.dart`
- `lib/src/model/scene_builder_json_parse.dart`
- Guardrail pinning directly tied to the new internal decode owners:
  `tool/src/guardrails/model_architecture_guardrails.dart`
  and
  `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

### Not Included in the Change

- Runtime import/export ownership in `scene_from_snapshot.dart` /
  `scene_snapshot_from_scene.dart`
- `scene_node_boundary_mapping_support.dart` residual ownership
- `document_node_patch.dart` residual ownership
- `ScenePolicy` scene-level traversal semantics
- Public API surface changes in `lib/iwb_canvas_engine.dart`

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/model/scene_builder.dart`
- `lib/src/model/scene_builder_decode_json.dart`
- `lib/src/model/scene_builder_json_require.dart`
- `lib/src/model/scene_builder_decode_scene.dart`
- `lib/src/model/scene_builder_decode_node_family.dart`
- `lib/src/model/scene_builder_decode_node_common.dart`
- `lib/src/model/scene_builder_decode_image.dart`
- `lib/src/model/scene_builder_decode_text.dart`
- `lib/src/model/scene_builder_decode_stroke.dart`
- `lib/src/model/scene_builder_decode_line.dart`
- `lib/src/model/scene_builder_decode_rect.dart`
- `lib/src/model/scene_builder_decode_path.dart`
- `lib/src/model/scene_builder_json_parse.dart`
- `tool/src/guardrails/model_architecture_guardrails.dart`

### Test Files

- `test/model/scene_builder_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/serialization/scene_fixture_test.dart`
- `test/entrypoints/basic_smoke_test.dart`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

### Fixture and Supporting Data Files

- `development_plan/model_target_architecture.md`
- `development_plan/step_44_model_final_architecture_closure.md`
- `development_plan/step_45_scene_builder_json_decode_and_require_owner_split.md`

### Analysis Area

- `lib/src/model/scene_builder*.dart`
- `lib/src/model/scene_document_codec.dart`
- `lib/src/serialization/scene_codec.dart`
- `tool/src/guardrails/model_architecture_guardrails.dart`
- `test/model/scene_builder_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/serialization/scene_fixture_test.dart`
- `test/entrypoints/basic_smoke_test.dart`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to one decode-owner slice.
- Every modified guardrail or tool test must pin one new internal decode owner
  boundary introduced by this step.
- Every modified test must pin one decode or diagnostics equivalence guarantee.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `scene_builder.dart` remains the thin internal import facade consumed by
   `scene_builder_api.dart` and `scene_document_codec.dart`.
2. `scene_document_codec.dart` remains the canonical non-model runtime-scene
   decode/encode facade; downstream non-model code must not import internal
   decode owner modules directly.
3. `ScenePolicy` remains the single owner of scene-level traversal semantics
   after raw snapshot decode.
4. Parsed-map normalization remains inside `model/`; it does not move into
   `serialization/`.
5. This step addresses residual decode/require ownership, not runtime
   import/export or mapping ownership.
6. The exact post-step-`48` target graph and accepted residual policy are
   fixed in `development_plan/model_target_architecture.md`; this step may
   refine only the builder decode seam inside that target.

## 5. Result Requirements

1. `lib/src/model/scene_builder_decode_json.dart` becomes a thin orchestration
   facade over explicit scene-topology, node-common, node-family, and scalar
   parse owners.
2. One explicit decode owner exists for scene-topology work, one for node
   common decode, one for scalar/enum parse helpers, and one per supported
   node family:
   `image`,
   `text`,
   `stroke`,
   `line`,
   `rect`,
   and `path`.
3. `dcm calculate-metrics` no longer reports the current `HIGH`
   `number-of-imports` hotspot on
   `lib/src/model/scene_builder_decode_json.dart`.
4. `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
   no longer reports the current decode/require matrix in the same form.
5. Public and serialization-visible behavior remains equivalent for:
   `SceneBuilder.buildFromJson(...)`,
   `decodeScene(...)`,
   `decodeSceneDocument(...)`,
   schema-version validation,
   and stable `SceneDataException.code` / `path` / immutable `details`.
6. `tool/check_guardrails.dart` rejects non-model imports or re-exports of the
   new internal decode owner modules introduced by this step.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `scene_builder.dart` is already thin and currently delegates JSON parsed-map
  decode into `scene_builder_decode_json.dart`; that facade shape must
  survive this step.
- `scene_document_codec.dart` already exists as the canonical non-model
  runtime-scene decode/encode facade above `scene_builder.dart`; it must keep
  that role.
- `scene_builder_decode_json.dart` currently has `1029` lines, a `HIGH`
  `number-of-imports = 18` hotspot, and `_decodeBackgroundSnapshot(...)`
  at `43` source lines.
- Current clone inventory still contains live decode/require families centered
  on `scene_builder_decode_json.dart` and `scene_builder_json_require.dart`.
- `tool/src/guardrails/model_architecture_guardrails.dart` currently treats
  `scene_builder_decode_json.dart` and `scene_builder_json_require.dart` as
  restricted internal owner modules; any new internal decode owners created by
  this step must be pinned in the same proof surface.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/model/scene_builder.dart lib/src/model/scene_builder_decode_json.dart lib/src/model/scene_builder_json_require.dart lib/src/model/scene_builder_decode_scene.dart lib/src/model/scene_builder_decode_node_family.dart lib/src/model/scene_builder_decode_node_common.dart lib/src/model/scene_builder_decode_image.dart lib/src/model/scene_builder_decode_text.dart lib/src/model/scene_builder_decode_stroke.dart lib/src/model/scene_builder_decode_line.dart lib/src/model/scene_builder_decode_rect.dart lib/src/model/scene_builder_decode_path.dart lib/src/model/scene_builder_json_parse.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- MCP test runner:
  `test/model/scene_builder_test.dart`
- MCP test runner:
  `test/public_api/scene_builder_test.dart test/public_api/validated_boundary_value_test.dart`
- MCP test runner:
  `test/serialization/scene_codec_validation_test.dart test/serialization/scene_fixture_test.dart`
- MCP test runner:
  `test/entrypoints/basic_smoke_test.dart`
- `dart run tool/run_tool_tests.dart`

### 6.3 Protected States, Data, or Structures

- `SceneBuilder` parsed-map import behavior and diagnostics.
- `scene_document_codec.dart` canonical facade role for non-model runtime-scene
  decode.
- Schema-version validation and invalid-json payload mapping.
- Boundary field-path attribution for nested decode failures.

### 6.4 Allowed Semantic Change Zones

- Physical file boundaries and imports inside the builder JSON decode seam.
- Guardrail pinning for new internal decode owner modules.
- Minimal facade adaptations in `scene_builder.dart` required to keep it thin.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- `scene_builder.dart` and `scene_document_codec.dart` remain the only entry
  surfaces that non-model code may use for runtime-scene JSON decode beneath
  the public API.
- New internal decode owner modules are implementation-only and must not be
  imported or re-exported outside `model/`.
- This step must not replace one giant decode owner with a generic
  `scene_builder_decode_support.dart` dump; ownership must stay aligned to the
  scene-topology, node-common, node-family, and scalar-parse seams named by
  this contract.

### 6.8 Prohibited

- Reintroducing mixed JSON decode ownership back into `scene_builder.dart`.
- Moving parsed-map normalization into `serialization/**`.
- Leaving the replaced decode/require matrix bodies in parallel with the new
  owner split.
- Changing decode behavior solely to reduce metrics.

## 7. Execution Rules

1. Slice `2` is forbidden until slice `1` is closed and verified.
2. This step closes only if the builder JSON decode seam becomes both thinner
   and more explicitly owner-based.
3. Scope expansion beyond the builder JSON decode seam and its directly
   coupled guardrail/test surfaces is forbidden.

## 8. Vertical Slices

### Slice 1. [x] `scene_builder_decode_json.dart` becomes a thin orchestration facade

#### Slice Contract

Top-level scene decode, node-common decode, and node-family decode no longer
live as one giant owner inside `scene_builder_decode_json.dart`.

#### Change

Extract explicit scene-topology, node-common, and node-family decode owners,
route `sceneBuilderDecodeSnapshotFromJson(...)` through them, and keep
`scene_builder.dart` as the thin facade above that graph.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_builder.dart lib/src/model/scene_builder_decode_json.dart lib/src/model/scene_builder_decode_scene.dart lib/src/model/scene_builder_decode_node_family.dart lib/src/model/scene_builder_decode_node_common.dart lib/src/model/scene_builder_decode_image.dart lib/src/model/scene_builder_decode_text.dart lib/src/model/scene_builder_decode_stroke.dart lib/src/model/scene_builder_decode_line.dart lib/src/model/scene_builder_decode_rect.dart lib/src/model/scene_builder_decode_path.dart --report-all`
- MCP test runner:
  `test/model/scene_builder_test.dart`
- MCP test runner:
  `test/public_api/scene_builder_test.dart`
- MCP test runner:
  `test/serialization/scene_codec_validation_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `scene_builder_decode_json.dart` no longer owns the replaced giant decode
  bodies.
- `scene_builder.dart` remains thin and delegates into the explicit decode
  graph.

### Slice 2. [x] Scalar parse helpers and internal decode owners are pinned structurally

#### Slice Contract

Scalar/enum parse helpers are separated from structural require helpers, and
non-model code cannot bypass the canonical model facades to import the new
internal decode owners.

#### Change

Extract the scalar/enum parse owner from `scene_builder_json_require.dart`,
keep require/cast helpers focused, then update model architecture guardrails
and tool tests so the new internal decode owner modules remain restricted to
`model/`.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_builder_json_require.dart lib/src/model/scene_builder_json_parse.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- MCP test runner:
  `test/public_api/validated_boundary_value_test.dart`
- MCP test runner:
  `test/serialization/scene_codec_validation_test.dart test/serialization/scene_fixture_test.dart`
- MCP test runner:
  `test/entrypoints/basic_smoke_test.dart`
- `dart run tool/run_tool_tests.dart`

#### Closure Evidence

- Green run of the listed verifications.
- The current decode/require clone matrix no longer appears in the same form.
- Model guardrails reject direct non-model imports or re-exports of the new
  internal decode owner modules.

## 9. Final Verification

- `dcm calculate-metrics lib/src/model/scene_builder.dart lib/src/model/scene_builder_decode_json.dart lib/src/model/scene_builder_json_require.dart lib/src/model/scene_builder_decode_scene.dart lib/src/model/scene_builder_decode_node_common.dart lib/src/model/scene_builder_decode_image.dart lib/src/model/scene_builder_decode_text.dart lib/src/model/scene_builder_decode_stroke.dart lib/src/model/scene_builder_decode_line.dart lib/src/model/scene_builder_decode_rect.dart lib/src/model/scene_builder_decode_path.dart lib/src/model/scene_builder_json_parse.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- MCP test runner:
  `test/model/scene_builder_test.dart`
- MCP test runner:
  `test/public_api/scene_builder_test.dart test/public_api/validated_boundary_value_test.dart`
- MCP test runner:
  `test/serialization/scene_codec_validation_test.dart test/serialization/scene_fixture_test.dart`
- MCP test runner:
  `test/entrypoints/basic_smoke_test.dart`
- `dart run tool/run_tool_tests.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
