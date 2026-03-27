language: russian

# Шаг 51. Развести scene decode orchestration и scene mutation owners без reopening `model` graph

## 1. Change Mandate

Этот шаг закрывает два оставшихся owner-level residual seam-а в `model`:
`scene_builder_decode_scene.dart` и `document_scene_edit.dart`.
После шага scene decode orchestration и scene mutation ownership должны быть
разведены по отдельным focused owner-модулям без возврата к metric-only
декомпозиции и без reopening уже принятого `model` graph.

## 2. Change Boundary

### Included in the Change

- `lib/src/model/scene_builder_decode_scene.dart`
- `lib/src/model/scene_builder_decode_scene_metadata.dart`
- `lib/src/model/scene_builder_decode_layers.dart`
- `lib/src/model/scene_builder_decode_json.dart` only if direct call-site
  adaptation is required by the split
- `lib/src/model/document_scene_edit.dart`
- `lib/src/model/document_scene_insert.dart`
- `lib/src/model/document.dart`
- `tool/src/guardrails/model_architecture_guardrails.dart`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`
- `development_plan/model_target_architecture.md`
- `development_plan/step_51_scene_decode_and_scene_mutation_owner_split.md`

### Not Included in the Change

- `scene_builder_json_require.dart` and `scene_builder_json_parse.dart`
  beyond direct reuse of the already-closed helper seam
- `scene_builder_decode_node_common.dart`,
  `scene_builder_decode_node_family.dart`, and family decode owners
  beyond direct call-site adaptation
- `scene_value_validation*.dart` and `scene_policy.dart`
- `document_locator.dart`, `document_selection.dart`, and
  `document_node_patch*.dart`
  beyond direct reuse of existing helpers
- Public API shape changes outside the already existing `document.dart` and
  `SceneBuilder` facades

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/model/scene_builder_decode_scene.dart`
- `lib/src/model/scene_builder_decode_scene_metadata.dart`
- `lib/src/model/scene_builder_decode_layers.dart`
- `lib/src/model/document_scene_edit.dart`
- `lib/src/model/document_scene_insert.dart`
- `lib/src/model/document.dart`
- `tool/src/guardrails/model_architecture_guardrails.dart`
- `ARCHITECTURE.md`

### Test Files

- `test/model/scene_builder_test.dart`
- `test/model/document_model_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/serialization/scene_fixture_test.dart`
- `test/controller/internal/scene_writer_test.dart`
- `test/controller/commands/scene_commands_test.dart`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

### Fixture and Supporting Data Files

- `DEVELOPMENT_PLAN.md`
- `development_plan/model_target_architecture.md`
- `development_plan/step_50_model_post_closure_helper_rebaseline.md`
- `development_plan/step_51_scene_decode_and_scene_mutation_owner_split.md`

### Analysis Area

- `lib/src/model/scene_builder_decode*.dart`
- `lib/src/model/document*.dart`
- `tool/src/guardrails/model_architecture_guardrails.dart`
- `test/model/**`
- `test/public_api/**`
- `test/serialization/**`
- `test/controller/internal/scene_writer_test.dart`
- `test/controller/commands/scene_commands_test.dart`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified scene-builder decode file must be tied either to scene decode
  orchestration, scene metadata decode, or layer traversal decode.
- Every modified document scene file must be tied either to insert/layer-target
  ownership or to erase/clear ownership.
- Every modified guardrail or doc file must pin the new owner graph introduced
  by this step.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `development_plan/model_target_architecture.md` remains the source of truth
   for the post-step-`51` `model` graph.
2. `scene_builder_decode_scene.dart` stays the canonical scene decode entry
   below `scene_builder_decode_json.dart`, but after this step it is
   orchestration-only.
3. Schema-version and scene metadata decode move into
   `scene_builder_decode_scene_metadata.dart`.
4. Background/content layer traversal decode moves into
   `scene_builder_decode_layers.dart`.
5. `document_scene_insert.dart` is the owner for
   `txnInsertNodeInScene`,
   `txnResolveInsertLayerIndex`,
   and
   `txnFindContentLayerIndexById`.
6. `document_scene_edit.dart` is the owner for erase / prepared-removal /
   clear semantics only and must not retain insert or target-layer resolution.
7. `document.dart` remains the canonical downstream transaction facade and
   delegates to the focused insert/edit owners.
8. `scene_policy.dart` and `scene_value_validation_node.dart` remain accepted
   focused owners and must not be reopened by this step.

## 5. Result Requirements

1. `scene_builder_decode_scene.dart` no longer owns both scene metadata decode
   and layer traversal decode in the same file.
2. `scene_builder_decode_scene_metadata.dart` exists and owns
   schema-version / camera / background / palette decode.
3. `scene_builder_decode_layers.dart` exists and owns optional background layer
   decode, content layer traversal, and layer-node traversal decode.
4. `scene_builder_decode_scene.dart` remains the only orchestration entry below
   `scene_builder_decode_json.dart` and assembles the final
   `SceneSnapshot` from focused owners.
5. `document_scene_edit.dart` no longer declares
   `txnInsertNodeInScene`,
   `txnResolveInsertLayerIndex`,
   or
   `txnFindContentLayerIndexById`.
6. `document_scene_insert.dart` exists and owns insert and target-layer
   resolution semantics consumed by `document.dart`.
7. Builder decode diagnostics, node-budget enforcement, scene insertion, scene
   erasure, and clear-with-background behavior remain behaviorally equivalent.
8. `tool/check_guardrails.dart` and its tool test surface pin the new owner
   modules as internal model-only modules.
9. No new `HIGH` / `VERY HIGH` hotspot appears outside the accepted residual
   set in `development_plan/model_target_architecture.md`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Current `scene_builder_decode_scene.dart` contains both
  schema-version / metadata decode
  and
  background/content layer traversal decode in one file.
- Current `document_scene_edit.dart` contains both
  insert / target-layer resolution
  and
  erase / prepared-removal / clear semantics in one file.
- The post-step-`50` target spec still classifies
  `scene_builder_decode_scene.dart`
  and
  `document_scene_edit.dart`
  as the remaining owner-level residual seams that justify one more pass.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/model/scene_builder_decode_scene.dart lib/src/model/scene_builder_decode_scene_metadata.dart lib/src/model/scene_builder_decode_layers.dart lib/src/model/document_scene_edit.dart lib/src/model/document_scene_insert.dart lib/src/model/document.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/analysis/find_similar_clones.dart lib/src/model`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner:
  `test/model/scene_builder_test.dart test/model/document_model_test.dart`
- MCP test runner:
  `test/public_api/scene_builder_test.dart`
- MCP test runner:
  `test/serialization/scene_codec_validation_test.dart test/serialization/scene_fixture_test.dart`
- MCP test runner:
  `test/controller/internal/scene_writer_test.dart test/controller/commands/scene_commands_test.dart`
- `dart run tool/run_tool_tests.dart`

### 6.3 Protected States, Data, or Structures

- `SceneDataException.code`, `path`, and message attribution for scene decode
  failures.
- Scene decode node-budget enforcement and layer-count enforcement.
- The downstream `document.dart` transaction facade signatures.
- Node locator integrity during insert and erase flows.
- Canonical model-facade boundaries enforced by the model guardrail.

### 6.4 Allowed Semantic Change Zones

- Internal scene decode helper ownership between orchestration,
  scene metadata decode, and layer traversal decode.
- Internal scene mutation ownership between insert/layer-target resolution and
  erase/clear semantics.
- Guardrail and documentation updates required to pin the new owner graph.

### 6.8 Prohibited

- Introducing a generic `support`, `helpers`, or `utils` owner instead of the
  focused files named by this contract.
- Moving decode semantics out of `model/` or into `serialization/`.
- Reopening `scene_builder_json_require.dart` / `scene_builder_json_parse.dart`
  as part of this step.
- Reopening `scene_policy.dart` or `scene_value_validation*.dart` because they
  are large.
- Changing `document.dart` or `SceneBuilder` facade semantics solely to reduce
  metrics.
- Closing the step without guardrail pinning for the new internal owner files.

## 7. Execution Rules

1. Slice `2` is forbidden until slice `1` is closed and verified.
2. This step closes only if both owner seams are reduced without broadening
   the `model` graph.
3. Scope expansion into accepted focused-owner residuals is forbidden.

## 8. Vertical Slices

### Slice 1. [ ] Split scene decode orchestration from metadata and layer traversal owners

#### Slice Contract

`scene_builder_decode_scene.dart` becomes a thin orchestration owner, while
scene metadata decode and layer traversal decode move into explicit focused
owners.

#### Change

Create `scene_builder_decode_scene_metadata.dart` and
`scene_builder_decode_layers.dart`, move the confirmed helper families into
them, and reduce `scene_builder_decode_scene.dart` to orchestration that
delegates to those owners and assembles the final `SceneSnapshot`.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_builder_decode_scene.dart lib/src/model/scene_builder_decode_scene_metadata.dart lib/src/model/scene_builder_decode_layers.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- MCP test runner:
  `test/model/scene_builder_test.dart`
- MCP test runner:
  `test/public_api/scene_builder_test.dart`
- MCP test runner:
  `test/serialization/scene_codec_validation_test.dart test/serialization/scene_fixture_test.dart`

#### Closure Evidence

- `scene_builder_decode_scene.dart` no longer contains both scene metadata
  decode and layer traversal decode.
- `scene_builder_decode_scene_metadata.dart` and
  `scene_builder_decode_layers.dart` exist and own the exact split named by
  this contract.
- Builder decode behavior remains green through the listed proof surface.

### Slice 2. [ ] Split insert/layer-target ownership away from document scene edit

#### Slice Contract

Insert and target-layer resolution semantics have their own focused owner, and
`document_scene_edit.dart` keeps erase / prepared-removal / clear semantics
only.

#### Change

Create `document_scene_insert.dart`, move
`txnInsertNodeInScene`,
`txnResolveInsertLayerIndex`,
and
`txnFindContentLayerIndexById`
into it, update `document.dart` delegation, keep `document_scene_edit.dart`
focused on erase/clear flows, and extend the model guardrail to pin the new
internal owner files.

#### Verification

- `dcm calculate-metrics lib/src/model/document_scene_edit.dart lib/src/model/document_scene_insert.dart lib/src/model/document.dart --report-all`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner:
  `test/model/document_model_test.dart`
- MCP test runner:
  `test/controller/internal/scene_writer_test.dart test/controller/commands/scene_commands_test.dart`
- `dart run tool/run_tool_tests.dart`

#### Closure Evidence

- `document_scene_edit.dart` no longer declares insert or target-layer
  resolution entrypoints.
- `document_scene_insert.dart` owns the insert/layer-target functions named by
  this contract.
- `document.dart` remains the canonical downstream facade over the split
  owners.
- Guardrail and tool-test surfaces detect direct non-model imports of the new
  internal owner modules.

## 9. Final Verification

- `dcm calculate-metrics lib/src/model/scene_builder_decode_scene.dart lib/src/model/scene_builder_decode_scene_metadata.dart lib/src/model/scene_builder_decode_layers.dart lib/src/model/document_scene_edit.dart lib/src/model/document_scene_insert.dart lib/src/model/document.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/analysis/find_similar_clones.dart lib/src/model`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner:
  `test/model/scene_builder_test.dart test/model/document_model_test.dart`
- MCP test runner:
  `test/public_api/scene_builder_test.dart`
- MCP test runner:
  `test/serialization/scene_codec_validation_test.dart test/serialization/scene_fixture_test.dart`
- MCP test runner:
  `test/controller/internal/scene_writer_test.dart test/controller/commands/scene_commands_test.dart`
- `dart run tool/run_tool_tests.dart`
