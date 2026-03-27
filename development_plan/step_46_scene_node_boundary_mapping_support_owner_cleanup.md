language: russian

# Шаг 46. Довести `scene_node_boundary_mapping_support` до true-common owner и вынести family assembly

## 1. Change Mandate

Этот шаг закрывает residual mapping seam после step `41`: из
`scene_node_boundary_mapping_support.dart` нужно убрать family-specific node
assembly и оставить в mapping common-owner только реально shared
schema-bridge/runtime-common helpers, чтобы mapping graph снова соответствовал
family-first architecture instead of hiding a second mixed owner behind the
word `support`.

## 2. Change Boundary

### Included in the Change

- `lib/src/model/scene_node_boundary_mapping.dart`
- `lib/src/model/scene_node_boundary_mapping_support.dart`
- `lib/src/model/scene_node_boundary_mapping_common.dart`
- `lib/src/model/scene_node_boundary_mapping_image.dart`
- `lib/src/model/scene_node_boundary_mapping_text.dart`
- `lib/src/model/scene_node_boundary_mapping_stroke.dart`
- `lib/src/model/scene_node_boundary_mapping_line.dart`
- `lib/src/model/scene_node_boundary_mapping_rect.dart`
- `lib/src/model/scene_node_boundary_mapping_path.dart`
- Guardrail pinning directly tied to the final mapping-internal graph:
  `tool/src/guardrails/model_architecture_guardrails.dart`
  and
  `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

### Not Included in the Change

- Builder JSON decode/require residual ownership from step `45`
- `scene_from_snapshot.dart`, `scene_snapshot_from_scene.dart`,
  `document.dart`, and `document_clone.dart` beyond minimal adaptation that is
  strictly required by the final mapping module graph
- `scene_value_validation*.dart` and `scene_policy.dart`
- `document_node_patch.dart` residual ownership from step `47`
- Contract-side `NodeBoundarySchema` ownership or fast-path surface

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/model/scene_node_boundary_mapping.dart`
- `lib/src/model/scene_node_boundary_mapping_support.dart`
- `lib/src/model/scene_node_boundary_mapping_common.dart`
- `lib/src/model/scene_node_boundary_mapping_image.dart`
- `lib/src/model/scene_node_boundary_mapping_text.dart`
- `lib/src/model/scene_node_boundary_mapping_stroke.dart`
- `lib/src/model/scene_node_boundary_mapping_line.dart`
- `lib/src/model/scene_node_boundary_mapping_rect.dart`
- `lib/src/model/scene_node_boundary_mapping_path.dart`
- `tool/src/guardrails/model_architecture_guardrails.dart`

### Test Files

- `test/model/document_model_test.dart`
- `test/model/document_clone_test.dart`
- `test/model/scene_builder_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/serialization/scene_fixture_test.dart`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

### Fixture and Supporting Data Files

- `development_plan/model_target_architecture.md`
- `development_plan/step_41_scene_node_boundary_mapping_family_modules_without_parts.md`
- `development_plan/step_45_scene_builder_json_decode_and_require_owner_split.md`
- `development_plan/step_46_scene_node_boundary_mapping_support_owner_cleanup.md`

### Analysis Area

- `lib/src/model/scene_node_boundary_mapping*.dart`
- `tool/src/guardrails/model_architecture_guardrails.dart`
- `test/model/document_model_test.dart`
- `test/model/document_clone_test.dart`
- `test/model/scene_builder_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/serialization/scene_fixture_test.dart`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must either become a true common mapping
  owner or a family-local mapping owner.
- Every modified guardrail or tool test must pin one mapping-internal boundary
  introduced or clarified by this step.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Step `41` remains valid: `scene_node_boundary_mapping.dart` stays the
   canonical dispatcher facade, and node family remains the primary ownership
   axis for this seam.
2. `NodeBoundarySchema` remains the single owner of boundary field semantics;
   this step only relocates model-side runtime assembly ownership.
3. Shared mapping helpers may live in one common owner module, but that module
   must stay common-only and must not become a second family implementation
   bucket.
4. `TextNodeSnapshotSizePolicy` remains exported through
   `scene_node_boundary_mapping.dart`; downstream runtime consumers must not
   import internal mapping owner modules directly.
5. This step fixes residual mixed mapping ownership, not runtime import/export
   ownership and not builder JSON decode ownership.
6. The exact target state for this seam is removal of
   `scene_node_boundary_mapping_support.dart` from the final graph; the common
   owner after this step is `scene_node_boundary_mapping_common.dart`.

## 5. Result Requirements

1. `scene_node_boundary_mapping_support.dart` is removed from the final model
   graph and replaced by `scene_node_boundary_mapping_common.dart` as the only
   common mapping owner.
2. One explicit family-local owner module exists per supported boundary family,
   and each such module owns all of its family assembly directions:
   snapshot -> runtime,
   spec -> runtime,
   and
   runtime -> snapshot.
3. `scene_node_boundary_mapping.dart` remains a thin dispatcher/export facade
   and does not absorb the assembly bodies removed from the old support file.
4. `dcm calculate-metrics` for the affected mapping files stays green against
   current thresholds; no new `HIGH` / `VERY HIGH` hotspot is introduced by the
   replacement graph.
5. `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
   no longer reports the current support/family clone family in the same form.
6. `tool/check_guardrails.dart` rejects non-model imports or re-exports of any
   new internal mapping owner modules introduced by this step.
7. `sceneNodeFromSnapshotViaBoundarySchema(...)`,
   `sceneNodeFromSpecViaBoundarySchema(...)`,
   `sceneNodeSnapshotFromViaBoundarySchema(...)`,
   and `cloneSceneNodeViaBoundarySchema(...)` remain behaviorally equivalent.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Step `41` removed `part` coupling and introduced family-local mapping files,
  but the current graph still leaves `scene_node_boundary_mapping_support.dart`
  at `501` lines with both common schema-bridge helpers and family-specific
  builders.
- Current clone inventory for `lib/src/model` still includes a live mapping
  family centered on `scene_node_boundary_mapping_support.dart` together with
  family files such as `scene_node_boundary_mapping_text.dart` and
  `scene_node_boundary_mapping_path.dart`.
- `scene_node_boundary_mapping.dart` currently exports
  `TextNodeSnapshotSizePolicy` from `scene_node_boundary_mapping_support.dart`;
  after this step the same symbol must remain exported, but through the new
  common owner graph rather than the residual support file.
- The family files are currently small enough to absorb their own assembly
  bodies; this step must prefer moving code into the existing family owners
  instead of creating a second layer of generic helpers.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/model/scene_node_boundary_mapping.dart lib/src/model/scene_node_boundary_mapping_common.dart lib/src/model/scene_node_boundary_mapping_image.dart lib/src/model/scene_node_boundary_mapping_text.dart lib/src/model/scene_node_boundary_mapping_stroke.dart lib/src/model/scene_node_boundary_mapping_line.dart lib/src/model/scene_node_boundary_mapping_rect.dart lib/src/model/scene_node_boundary_mapping_path.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- MCP test runner:
  `test/model/document_model_test.dart test/model/document_clone_test.dart test/model/scene_builder_test.dart`
- MCP test runner:
  `test/public_api/validated_boundary_value_test.dart`
- MCP test runner:
  `test/serialization/scene_fixture_test.dart`
- `dart run tool/run_tool_tests.dart`

### 6.3 Protected States, Data, or Structures

- Runtime conversion parity between `SceneNode`, `NodeSnapshot`, and `NodeSpec`
  for all supported families.
- `TextNodeSnapshotSizePolicy` behavior and derived text-size semantics.
- `NodeBoundarySchema` ownership of validated boundary fields.

### 6.4 Allowed Semantic Change Zones

- Physical file boundaries and imports inside the mapping seam.
- Minimal export/import adaptation needed to keep the façade role of
  `scene_node_boundary_mapping.dart`.
- Guardrail and tool-test pinning for the new internal mapping graph.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- `scene_node_boundary_mapping.dart` remains the only canonical mapping entry
  surface; family owners and the common owner are implementation-only.
- The replacement graph must not introduce a new generic bucket such as
  `helpers.dart`, `utils.dart`, or a renamed `support.dart` that still mixes
  family assembly.
- If `scene_node_boundary_mapping_common.dart` is introduced, its name must
  match its responsibility: only truly shared runtime-common and schema-bridge
  abstractions may live there.

### 6.8 Prohibited

- Keeping the existing family-specific builders in the common owner file while
  only renaming it.
- Moving field-validation or schema semantics out of `NodeBoundarySchema`.
- Reintroducing direction-first or catch-all owner shapes to silence clone
  tooling.
- Changing runtime mapping behavior solely to reduce metrics.

## 7. Execution Rules

1. This step starts only after step `45` is closed or explicitly deferred.
2. Slice `2` is forbidden until slice `1` is closed and verified.
3. This step closes only if mapping common ownership becomes truly common and
   family-local modules become complete owners of their assembly logic.
4. Scope expansion into document patch or builder decode ownership is
   forbidden.

## 8. Vertical Slices

### Slice 1. [ ] Replace the mixed support bucket with a true common mapping owner

#### Slice Contract

The mapping seam has one common owner for shared runtime/schema bridge helpers,
not a disguised second family bucket.

#### Change

Create the common-only mapping module, move family-specific builders out of
`scene_node_boundary_mapping_support.dart`, remove that residual support file,
and keep `TextNodeSnapshotSizePolicy` re-exported through the dispatcher
facade.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_node_boundary_mapping.dart lib/src/model/scene_node_boundary_mapping_common.dart --report-all`
- `dart run tool/check_guardrails.dart`
- MCP test runner:
  `test/public_api/validated_boundary_value_test.dart`

#### Closure Evidence

- `scene_node_boundary_mapping_support.dart` no longer exists.
- The common owner file contains only shared helpers/types.
- `scene_node_boundary_mapping.dart` still exports
  `TextNodeSnapshotSizePolicy`.

### Slice 2. [ ] Make every mapping family own all of its assembly directions

#### Slice Contract

Each mapping family owns its snapshot/spec/runtime assembly logic end-to-end.

#### Change

Move per-family runtime builders and snapshot encoders into the corresponding
`image`, `text`, `stroke`, `line`, `rect`, and `path` owner modules, and keep
the dispatcher facade limited to family dispatch and clone helpers.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_node_boundary_mapping.dart lib/src/model/scene_node_boundary_mapping_common.dart lib/src/model/scene_node_boundary_mapping_image.dart lib/src/model/scene_node_boundary_mapping_text.dart lib/src/model/scene_node_boundary_mapping_stroke.dart lib/src/model/scene_node_boundary_mapping_line.dart lib/src/model/scene_node_boundary_mapping_rect.dart lib/src/model/scene_node_boundary_mapping_path.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- MCP test runner:
  `test/model/document_model_test.dart test/model/document_clone_test.dart test/model/scene_builder_test.dart`
- MCP test runner:
  `test/serialization/scene_fixture_test.dart`

#### Closure Evidence

- Each family module owns all of its own mapping directions.
- The current support/family clone family no longer appears in the same form.
- `sceneNodeFromSnapshotViaBoundarySchema(...)`,
  `sceneNodeFromSpecViaBoundarySchema(...)`,
  `sceneNodeSnapshotFromViaBoundarySchema(...)`,
  and `cloneSceneNodeViaBoundarySchema(...)`
  remain green through the listed proof surface.

## 9. Final Verification Checklist

- [ ] `dcm calculate-metrics lib/src/model/scene_node_boundary_mapping.dart lib/src/model/scene_node_boundary_mapping_common.dart lib/src/model/scene_node_boundary_mapping_image.dart lib/src/model/scene_node_boundary_mapping_text.dart lib/src/model/scene_node_boundary_mapping_stroke.dart lib/src/model/scene_node_boundary_mapping_line.dart lib/src/model/scene_node_boundary_mapping_rect.dart lib/src/model/scene_node_boundary_mapping_path.dart --report-all`
- [ ] `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- [ ] `dart run tool/check_import_boundaries.dart`
- [ ] `dart run tool/check_guardrails.dart`
- [ ] MCP test runner:
      `test/model/document_model_test.dart test/model/document_clone_test.dart test/model/scene_builder_test.dart`
- [ ] MCP test runner:
      `test/public_api/validated_boundary_value_test.dart`
- [ ] MCP test runner:
      `test/serialization/scene_fixture_test.dart`
- [ ] `dart run tool/run_tool_tests.dart`
