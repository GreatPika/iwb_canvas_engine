language: russian

# Шаг 43. Свести `document.dart` к thin txn facade над focused model-local owner-ами

## 1. Change Mandate

Этот шаг завершает structural reduction внутри `document.dart`: файл должен
остаться canonical downstream txn facade для controller, interactive,
serialization, and builder-facing consumers, но mixed locator / scene-edit /
patch / selection ownership must move into focused model-local modules without
reopening the import, mapping, or validation seams closed by steps `40-42`.

## 2. Change Boundary

### Included in the Change

- `lib/src/model/document.dart`
- `lib/src/model/document_locator.dart`
- `lib/src/model/document_scene_edit.dart`
- `lib/src/model/document_node_patch.dart`
- `lib/src/model/document_selection.dart`
- Minimal consumer adaptation required to keep downstream imports on the
  canonical `document.dart` facade

### Not Included in the Change

- Runtime import/export ownership already closed by step `40`
- `scene_node_boundary_mapping*.dart` ownership already closed by step `41`
- `scene_value_validation*.dart` ownership already closed by step `42`
- `ScenePolicy` scene-level semantics
- Public API surface changes in `lib/iwb_canvas_engine.dart`

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/model/document.dart`
- `lib/src/model/document_locator.dart`
- `lib/src/model/document_scene_edit.dart`
- `lib/src/model/document_node_patch.dart`
- `lib/src/model/document_selection.dart`
- `lib/src/model/scene_builder_api.dart` only if a minimal import adaptation is
  required to keep facade-only consumption

### Test Files

- `test/model/document_model_test.dart`
- `test/model/scene_builder_test.dart`
- `test/controller/internal/change_set_txn_context_test.dart`
- `test/controller/internal/mutation_executor_test.dart`
- `test/controller/scene_invariants_test.dart`
- `test/controller/scene_controller_randomized_txn_test.dart`
- `test/serialization/scene_codec_validation_test.dart`

### Fixture and Supporting Data Files

- `development_plan/step_40_scene_builder_thin_facade_and_runtime_import_export_spine.md`
- `development_plan/step_41_scene_node_boundary_mapping_family_modules_without_parts.md`
- `development_plan/step_42_scene_value_validation_explicit_modules_without_parts.md`
- `development_plan/step_43_document_txn_facade_and_focused_owner_split.md`

### Analysis Area

- `lib/src/model/document*.dart`
- `lib/src/model/scene_builder_api.dart`
- `lib/src/controller/**`
- `lib/src/interactive/**`
- `lib/src/serialization/scene_codec.dart`
- `test/model/document_model_test.dart`
- `test/model/scene_builder_test.dart`
- `test/controller/internal/change_set_txn_context_test.dart`
- `test/controller/internal/mutation_executor_test.dart`
- `test/controller/scene_invariants_test.dart`
- `test/controller/scene_controller_randomized_txn_test.dart`
- `test/serialization/scene_codec_validation_test.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to one document-owner slice.
- Downstream consumer changes are allowed only when they preserve
  `document.dart` as the single canonical import surface.
- Every modified test must pin one document behavior or downstream facade
  guarantee.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. This step starts only after steps `40-42` have closed the shared import,
   mapping, and validation seams beneath `document.dart`.
2. `document.dart` remains the canonical downstream facade imported by
   `controller/**`, `interactive/**`, `serialization/**`, and
   `scene_builder_api.dart`.
3. Runtime conversion ownership stays in
   `scene_from_snapshot.dart`,
   `scene_snapshot_from_scene.dart`,
   and `scene_node_boundary_mapping.dart`; this step must not pull that logic
   back into `document.dart` or the new focused modules.
4. `document.dart` is allowed to keep small facade-local type declarations and
   thin entrypoints, but it must not remain the mixed owner of locator,
   scene-edit, patch, and selection logic.
5. Metrics must improve because ownership improved, not because signatures were
   reshaped to silence tooling.

## 5. Result Requirements

1. `lib/src/model/document.dart` becomes a thin txn facade over explicit
   focused owners:
   `document_locator.dart`,
   `document_scene_edit.dart`,
   `document_node_patch.dart`,
   and `document_selection.dart`.
2. Downstream consumers continue to import `document.dart`; the new focused
   modules do not become direct dependencies of controller, interactive,
   serialization, or builder-facing code.
3. `dcm calculate-metrics` no longer reports the current `HIGH` hotspots on
   `txnFindNodeByLocator(...)`,
   `txnInsertNodeInScene(...)`,
   and `_txnApplyCommonPatch(...)`
   in `lib/src/model/document.dart`.
4. `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
   no longer reports the current `document.dart` patch family in the same
   form.
5. `txnSceneFromSnapshot(...)`, `txnSceneToSnapshot(...)`,
   `txnNodeFromSnapshot(...)`, `txnNodeFromSpec(...)`,
   `txnApplyNodePatch(...)`, insert/erase helpers, and selection/grid helpers
   remain behaviorally equivalent for downstream callers.
6. The builder dependency removed in step `40` does not return:
   `document.dart` must not depend on `scene_builder.dart`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `document.dart` currently has `1009` lines and five `HIGH` hotspots:
  file `number-of-imports = 15`,
  `txnFindNodeByLocator(...)` cyclomatic complexity,
  `txnInsertNodeInScene(...)` parameter breadth and `source-lines-of-code`,
  and `_txnApplyCommonPatch(...)` `source-lines-of-code`.
- The current clone inventory in `lib/src/model` still contains a live
  `document.dart` patch-family cluster centered on
  `_txnApplyCommonPatch(...)`,
  `_txnApplyImagePatch(...)`,
  `_txnApplyStrokePatch(...)`,
  `_txnApplyLinePatch(...)`,
  `_txnApplyRectPatch(...)`,
  `_txnApplyPathPatch(...)`,
  `_txnApplyTextContentPatch(...)`,
  and `_txnApplyTextLayoutStylePatch(...)`.
- `document.dart` currently mixes four distinct ownership seams:
  locator/index lookup,
  scene insert/erase/clear,
  node patch application,
  and selection/grid normalization,
  plus thin conversion delegation that should remain thin after steps `40-42`.
- Downstream imports of `document.dart` currently exist across
  `controller/**`,
  `interactive/**`,
  `serialization/scene_codec.dart`,
  and `scene_builder_api.dart`; those consumers must stay on the facade.
- `document.dart` currently still imports `scene_builder.dart`; this step must
  assume the step-`40` replacement and prevent regression of that dependency.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/model/document.dart lib/src/model/document_locator.dart lib/src/model/document_scene_edit.dart lib/src/model/document_node_patch.dart lib/src/model/document_selection.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/check_import_boundaries.dart`
- `rg -n \"scene_builder\\.dart\" lib/src/model/document.dart`
- MCP test runner:
  `test/model/document_model_test.dart test/model/scene_builder_test.dart`
- MCP test runner:
  `test/controller/internal/change_set_txn_context_test.dart test/controller/internal/mutation_executor_test.dart`
- MCP test runner:
  `test/controller/scene_invariants_test.dart test/controller/scene_controller_randomized_txn_test.dart`
- MCP test runner:
  `test/serialization/scene_codec_validation_test.dart`

### 6.3 Protected States, Data, or Structures

- Current document-facing txn entrypoint surface and downstream imports.
- Runtime import/export delegation already owned by steps `40-42`.
- Scene mutation semantics for insert, erase, clear, and patch application.
- Selection normalization and grid normalization behavior.
- Derived text-size recomputation after text-layout patch changes.

### 6.4 Allowed Semantic Change Zones

- Physical file boundaries and imports inside the document seam.
- Minimal downstream import adaptations needed to preserve facade-only
  consumption.
- Tests that pin the final document facade and focused-owner split.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- New focused document modules are internal implementation owners; downstream
  consumers must continue importing `document.dart` rather than those modules
  directly.
- `document.dart` may import the focused modules and the explicit conversion
  owners from steps `40-42`, but it must not re-export the new focused
  modules.
- This step must not reintroduce the removed
  `document.dart -> scene_builder.dart` dependency.
- The change must not create a new generic `document_helpers.dart` or
  `document_utils.dart` bucket; ownership must stay aligned to the focused
  seams named by this contract.

### 6.8 Prohibited

- Pulling runtime import/export, mapping, or validation logic back into
  `document.dart` or the new focused modules.
- Letting controller, interactive, serialization, or builder-facing code
  import the new focused document modules directly.
- Leaving the replaced patch family or locator/scene-edit mixed bodies in
  parallel with the new focused modules.
- Changing behavior solely to reduce metrics.

## 7. Execution Rules

1. This step starts only after steps `40-42` are closed.
2. Slice `2` is forbidden until slice `1` is closed and verified.
3. This step closes only if `document.dart` becomes a true facade rather than
   a thinner mixed owner.
4. Scope expansion beyond the document seam and its direct downstream facade
   guarantees is forbidden.

## 8. Vertical Slices

### Slice 1. [ ] Locator and scene-edit ownership move behind the canonical document facade

#### Slice Contract

Node lookup/indexing and scene insert/erase/clear logic live in focused
modules, while `document.dart` keeps only thin entrypoint delegation for those
seams.

#### Change

Extract focused owners for locator/index work and scene edit work, route
`txnFindNodeById(...)`,
`txnBuildNodeLocator(...)`,
`txnFindNodeByLocator(...)`,
`txnShiftNodeLocatorLayersFrom(...)`,
`txnInsertNodeInScene(...)`,
erase helpers,
`txnClearSceneKeepBackground(...)`,
and layer-index helpers through them, and remove the replaced mixed bodies from
`document.dart`.

#### Verification

- `dcm calculate-metrics lib/src/model/document.dart lib/src/model/document_locator.dart lib/src/model/document_scene_edit.dart --report-all`
- `rg -n \"scene_builder\\.dart\" lib/src/model/document.dart`
- MCP test runner:
  `test/model/document_model_test.dart`
- MCP test runner:
  `test/controller/internal/change_set_txn_context_test.dart`
- MCP test runner:
  `test/controller/scene_invariants_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `document.dart` no longer contains the replaced locator and scene-edit
  bodies.
- Controller and serialization consumers still import only `document.dart`.

### Slice 2. [ ] Patch and selection/grid ownership move behind the same facade

#### Slice Contract

Node patch application and selection/grid helpers live in focused modules, and
the current `document.dart` patch family no longer exists in the same form.

#### Change

Extract focused owners for patch application and selection/grid helpers, route
`txnApplyNodePatch(...)`,
typed patch bodies,
`txnNormalizeSelection(...)`,
`txnIsSelectionCandidateId(...)`,
`txnTranslateSelection(...)`,
and `txnNormalizeGrid(...)` through them, while keeping conversion entrypoints
and facade-local declarations in `document.dart`.

#### Verification

- `dcm calculate-metrics lib/src/model/document.dart lib/src/model/document_node_patch.dart lib/src/model/document_selection.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/check_import_boundaries.dart`
- MCP test runner:
  `test/model/document_model_test.dart test/model/scene_builder_test.dart`
- MCP test runner:
  `test/controller/internal/mutation_executor_test.dart`
- MCP test runner:
  `test/controller/scene_controller_randomized_txn_test.dart`
- MCP test runner:
  `test/serialization/scene_codec_validation_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- The current `document.dart` patch-family clone cluster no longer appears in
  the same form.
- `document.dart` remains the only downstream import surface for the document
  seam.

## 9. Final Verification

- `dcm calculate-metrics lib/src/model/document.dart lib/src/model/document_locator.dart lib/src/model/document_scene_edit.dart lib/src/model/document_node_patch.dart lib/src/model/document_selection.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/check_import_boundaries.dart`
- `rg -n \"scene_builder\\.dart\" lib/src/model/document.dart`
- MCP test runner:
  `test/model/document_model_test.dart test/model/scene_builder_test.dart`
- MCP test runner:
  `test/controller/internal/change_set_txn_context_test.dart test/controller/internal/mutation_executor_test.dart`
- MCP test runner:
  `test/controller/scene_invariants_test.dart test/controller/scene_controller_randomized_txn_test.dart`
- MCP test runner:
  `test/serialization/scene_codec_validation_test.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
