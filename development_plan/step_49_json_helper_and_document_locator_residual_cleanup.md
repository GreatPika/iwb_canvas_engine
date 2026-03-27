language: russian

# Шаг 49. Закрыть post-closure helper seams в builder JSON helpers и document locator/index helpers

## 1. Change Mandate

Этот шаг закрывает два оставшихся post-closure seam-а внутри уже зафиксированного
`model` owner graph:
builder-side JSON helper family между `scene_builder_json_require.dart` и
`scene_builder_json_parse.dart`, и exact/shared helper duplication между
`document_locator.dart` и `document_scene_edit.dart`.

Цель шага не в reopening `model` architecture, а в том, чтобы убрать два
живых helper-level residual family, которые остались после closure step `48`.

## 2. Change Boundary

### Included in the Change

- `lib/src/model/scene_builder_json_require.dart`
- `lib/src/model/scene_builder_json_parse.dart`
- `lib/src/model/document_locator.dart`
- `lib/src/model/document_scene_edit.dart`
- Minimal call-site adaptation inside `lib/src/model/scene_builder_decode*.dart`
  only if it is strictly required by the helper cleanup and does not broaden
  the seam

### Not Included in the Change

- New `model` owner files for builder helper cleanup
- `scene_builder.dart`, `scene_document_codec.dart`, and runtime import/export
  ownership
- `scene_node_boundary_mapping*.dart`
- `scene_value_validation*.dart` and `scene_policy.dart`
- `document.dart`, `document_selection.dart`, and `document_node_patch*.dart`
  beyond direct reuse of the cleaned helper owners
- Guardrail or public API changes, unless a proof cannot be closed otherwise

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/model/scene_builder_json_require.dart`
- `lib/src/model/scene_builder_json_parse.dart`
- `lib/src/model/document_locator.dart`
- `lib/src/model/document_scene_edit.dart`

### Test Files

- `test/model/document_model_test.dart`
- `test/model/scene_builder_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/serialization/scene_fixture_test.dart`
- `test/controller/internal/scene_writer_test.dart`
- `test/controller/commands/scene_commands_test.dart`

### Fixture and Supporting Data Files

- `development_plan/model_target_architecture.md`
- `development_plan/step_48_model_residual_architecture_closure.md`
- `development_plan/step_49_json_helper_and_document_locator_residual_cleanup.md`

### Analysis Area

- `lib/src/model/scene_builder_json_require.dart`
- `lib/src/model/scene_builder_json_parse.dart`
- `lib/src/model/document_locator.dart`
- `lib/src/model/document_scene_edit.dart`
- `test/model/document_model_test.dart`
- `test/model/scene_builder_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/serialization/scene_fixture_test.dart`
- `test/controller/internal/scene_writer_test.dart`
- `test/controller/commands/scene_commands_test.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified builder helper file must either own structural require or own
  scalar/enum parse. The change must not re-mix those responsibilities.
- Every modified document helper file must either own locator/index helpers or
  consume them; duplicate copies are out of scope.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `development_plan/model_target_architecture.md` remains the source of truth
   for the post-step-`50` `model` graph; this step may refine helper seams
   only inside that graph.
2. `scene_builder_json_require.dart` remains the structural require /
   typed-extraction owner.
3. `scene_builder_json_parse.dart` remains the scalar/enum parse owner.
4. The builder helper seam is considered feasible only through two narrow
   primitives owned by `scene_builder_json_require.dart`:
   one optional typed field accessor and one optional object-map accessor.
   This step must use that path and must not invent a broader abstraction.
5. `document_locator.dart` is the correct owner for shared locator/index
   helper semantics reused by `document_scene_edit.dart`.
6. This step closes helper-level residuals only; it does not reopen accepted
   focused-owner residual metrics from the post-step-`48` audit.

## 5. Result Requirements

1. The helper family centered on
   `scene_builder_json_require.dart`
   and
   `scene_builder_json_parse.dart`
   no longer appears in the current cluster-`2` form.
2. `scene_builder_json_require.dart` owns presence/path/type extraction
   primitives, and `scene_builder_json_parse.dart` consumes those primitives
   instead of re-implementing the same field-presence/type branches locally.
3. The builder helper seam closes inside the existing two files through exactly
   two new narrow structural helpers in `scene_builder_json_require.dart`:
   an optional typed field accessor and an optional object-map accessor.
4. `sceneBuilderOptionalColor(...)` and `sceneBuilderOptionalSizeMap(...)`
   stop owning their own presence/type branches and delegate those concerns to
   the new `scene_builder_json_require.dart` primitives.
5. `scene_builder_json_parse.dart` does not become a second structural require
   owner; enum/scalar parsing remains explicit and local.
6. The exact duplicate pair
   `_txnResolveLayerNodesForLocator`
   and
   `_txnResolveLayerNodesForErase`
   is removed.
7. The structural duplicate pair
   `_txnWriteLayerNodeLocations`
   and
   `_txnReindexLayerNodes`
   is removed.
8. `dcm calculate-metrics` for the touched files does not introduce any new
   `HIGH` / `VERY HIGH` hotspot outside the already accepted residual list in
   `model_target_architecture.md`.
9. SceneBuilder diagnostics and document edit semantics remain behaviorally
   equivalent.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Post-step-`48` audit still shows a live helper cluster around
  `scene_builder_json_require.dart` and `scene_builder_json_parse.dart`
  as the most meaningful remaining builder-side clone family.
- Current call-sites show that the remaining duplication is concentrated in
  optional field presence/type access and can be closed inside the existing two
  files without introducing new owner modules.
- The same audit shows two locator/index duplicates spanning
  `document_locator.dart` and `document_scene_edit.dart`.
- The post-step-`48` audit also showed several accepted focused-owner
  residuals; this step must not reopen them just because they are still red.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/model/scene_builder_json_require.dart lib/src/model/scene_builder_json_parse.dart lib/src/model/document_locator.dart lib/src/model/document_scene_edit.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/analysis/find_similar_clones.dart lib/src/model`
- `dart run tool/check_import_boundaries.dart`
- MCP test runner:
  `test/model/document_model_test.dart test/model/scene_builder_test.dart`
- MCP test runner:
  `test/public_api/scene_builder_test.dart test/public_api/validated_boundary_value_test.dart`
- MCP test runner:
  `test/serialization/scene_codec_validation_test.dart test/serialization/scene_fixture_test.dart`
- MCP test runner:
  `test/controller/internal/scene_writer_test.dart test/controller/commands/scene_commands_test.dart`

### 6.3 Protected States, Data, or Structures

- `SceneDataException.code`, `path`, and message attribution for JSON decode
  failures.
- `SceneBuilder` parsed-map decode behavior.
- Locator/index maintenance and scene edit semantics.
- Layer-node resolution for background vs content layers.

### 6.4 Allowed Semantic Change Zones

- Internal helper allocation inside the listed files.
- Minimal call-site adaptation required by the helper cleanup.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- Helper cleanup must reduce duplication by clarifying ownership, not by
  introducing a broad `support` or `utils` bucket.
- The document helper cleanup should prefer reusing `document_locator.dart`
  rather than creating a third shared helper file unless reuse proves
  impossible from confirmed code constraints.
- Builder helper cleanup must keep structural require and scalar parse as two
  separate owners and must solve the seam through the two narrow optional
  access primitives named by this contract.

### 6.8 Prohibited

- Reopening `scene_builder_decode*.dart` ownership or dispatch graph.
- Reopening `document.dart` facade shape.
- Creating new builder helper owner files for this seam.
- Replacing explicit enum parsers with data-driven or reflection-like tables
  solely to reduce clones.
- Changing behavior solely to make clone tooling quieter.

## 7. Execution Rules

1. Slice `2` is forbidden until slice `1` is closed and verified.
2. This step closes only if both named helper seams are reduced without
   broadening the owner graph.
3. Scope expansion into accepted focused-owner residuals is forbidden.

## 8. Vertical Slices

### Slice 1. [x] Reduce builder JSON helper duplication without reopening decode ownership

#### Slice Contract

Structural require stays in `scene_builder_json_require.dart`, scalar/enum
parse stays in `scene_builder_json_parse.dart`, and the live helper cluster is
reduced by shared narrow primitives rather than by a new generic framework.

#### Change

Add the optional typed field accessor and optional object-map accessor inside
`scene_builder_json_require.dart`, route `sceneBuilderOptionalColor(...)` and
`sceneBuilderOptionalSizeMap(...)` through them, and remove the current
duplicated presence/type/path branches from those optional parse helpers.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_builder_json_require.dart lib/src/model/scene_builder_json_parse.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- MCP test runner:
  `test/model/scene_builder_test.dart`
- MCP test runner:
  `test/public_api/scene_builder_test.dart test/public_api/validated_boundary_value_test.dart`
- MCP test runner:
  `test/serialization/scene_codec_validation_test.dart test/serialization/scene_fixture_test.dart`

#### Closure Evidence

- Cluster `2` no longer appears in the same form.
- `scene_builder_json_require.dart` remains the only structural require owner.
- The seam is closed inside the existing two files, with no new owner modules.
- Builder decode behavior stays green through the listed proof surface.

### Slice 2. [x] Remove document locator/index helper duplication

#### Slice Contract

Locator/index helper semantics have one owner and are no longer duplicated
between `document_locator.dart` and `document_scene_edit.dart`.

#### Change

Promote or reuse focused locator/index helpers from `document_locator.dart`
and delete the duplicated erase/reindex helpers from
`document_scene_edit.dart`.

#### Verification

- `dcm calculate-metrics lib/src/model/document_locator.dart lib/src/model/document_scene_edit.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/model`
- MCP test runner:
  `test/model/document_model_test.dart`
- MCP test runner:
  `test/controller/internal/scene_writer_test.dart test/controller/commands/scene_commands_test.dart`

#### Closure Evidence

- The exact duplicate pair and structural duplicate pair named by this
  contract are removed.
- Scene edit and locator behavior remain green through the listed proof
  surface.

## 9. Final Verification Checklist

- [x] `dcm calculate-metrics lib/src/model/scene_builder_json_require.dart lib/src/model/scene_builder_json_parse.dart lib/src/model/document_locator.dart lib/src/model/document_scene_edit.dart --report-all`
- [x] `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- [x] `dart run tool/analysis/find_similar_clones.dart lib/src/model`
- [x] `dart run tool/check_import_boundaries.dart`
- [x] MCP test runner:
      `test/model/document_model_test.dart test/model/scene_builder_test.dart`
- [x] MCP test runner:
      `test/public_api/scene_builder_test.dart test/public_api/validated_boundary_value_test.dart`
- [x] MCP test runner:
      `test/serialization/scene_codec_validation_test.dart test/serialization/scene_fixture_test.dart`
- [x] MCP test runner:
      `test/controller/internal/scene_writer_test.dart test/controller/commands/scene_commands_test.dart`
