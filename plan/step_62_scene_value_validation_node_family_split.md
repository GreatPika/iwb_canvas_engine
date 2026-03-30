language: russian

# Шаг 62. Разрезать residual node-validation matrix на focused family owner-ы

## 1. Change Mandate

Этот шаг дожимает residual node-validation matrix:
`scene_value_validation_node.dart` перестаёт быть смешанным владельцем
base-field validation, snapshot/runtime branching, и family-local rule bodies
для
`image`,
`text`,
`stroke`,
`line`,
`rect`,
`path`.
После шага
`scene_value_validation.dart`
остаётся canonical validation entrypoint,
`scene_policy.dart`
остаётся единственным владельцем scene-level semantics,
а
`scene_value_validation_node.dart`
держит только общий каркас и dispatch над focused family owner-модулями.

## 2. Change Boundary

### Included in the Change

- `lib/src/model/scene_value_validation.dart`
- `lib/src/model/scene_value_validation_node.dart`
- `lib/src/model/scene_value_validation_node_image.dart`
- `lib/src/model/scene_value_validation_node_text.dart`
- `lib/src/model/scene_value_validation_node_stroke.dart`
- `lib/src/model/scene_value_validation_node_line.dart`
- `lib/src/model/scene_value_validation_node_rect.dart`
- `lib/src/model/scene_value_validation_node_path.dart`
- `lib/src/model/scene_value_validation_primitives.dart` only if direct
  adaptation is required to avoid a second primitive ruleset
- `lib/src/model/scene_value_validation_support.dart` only if direct
  adaptation is required to host already-shared helper types or reporting
  helpers without introducing a new bucket
- `test/model/scene_value_validation_primitives_test.dart`
- `test/model/scene_builder_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `PLAN.md`
- `plan/model_target_architecture.md`
- `plan/step_42_scene_value_validation_explicit_modules_without_parts.md`
- `plan/step_48_model_residual_architecture_closure.md`
- `plan/step_50_model_post_closure_helper_rebaseline.md`
- `plan/step_62_scene_value_validation_node_family_split.md`

### Not Included in the Change

- `lib/src/model/scene_policy.dart`
- `lib/src/model/scene_value_validation_top_level.dart`
- `lib/src/model/scene_value_validation_palette_grid.dart`
- `lib/src/model/scene_builder.dart`
- `lib/src/model/scene_builder_decode*.dart`
- `lib/src/model/scene_from_snapshot.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`
- `ARCHITECTURE.md`
- `API_GUIDE.md`
- `README.md`
- `CHANGELOG.md`
- Any new generic helper bucket such as
  `scene_value_validation_node_support.dart`
- Reopening the full validation graph beyond the residual node-family split

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/model/scene_value_validation.dart`
- `lib/src/model/scene_value_validation_node.dart`
- `lib/src/model/scene_value_validation_node_image.dart`
- `lib/src/model/scene_value_validation_node_text.dart`
- `lib/src/model/scene_value_validation_node_stroke.dart`
- `lib/src/model/scene_value_validation_node_line.dart`
- `lib/src/model/scene_value_validation_node_rect.dart`
- `lib/src/model/scene_value_validation_node_path.dart`
- `PLAN.md`

### Test Files

- `test/model/scene_value_validation_primitives_test.dart`
- `test/model/scene_builder_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/serialization/scene_codec_validation_test.dart`

### Fixture and Supporting Data Files

- `plan/model_target_architecture.md`
- `plan/step_42_scene_value_validation_explicit_modules_without_parts.md`
- `plan/step_48_model_residual_architecture_closure.md`
- `plan/step_50_model_post_closure_helper_rebaseline.md`
- `plan/step_62_scene_value_validation_node_family_split.md`

### Analysis Area

- `lib/src/model/scene_value_validation.dart`
- `lib/src/model/scene_value_validation_node*.dart`
- `lib/src/model/scene_value_validation_primitives.dart`
- `lib/src/model/scene_value_validation_support.dart`
- `test/model/scene_value_validation_primitives_test.dart`
- `test/model/scene_builder_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/serialization/scene_codec_validation_test.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied either to
  `scene_value_validation_node.dart` becoming a thin node-validation facade or
  to one explicit node-family validation owner.
- Every modified test must pin one proof that node validation behavior or
  diagnostics stayed equivalent after the family split.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `scene_value_validation.dart` remains the canonical validation facade.
2. `ScenePolicy` remains the single owner of scene-level traversal, duplicate,
   and range semantics; this step must not move any of those rules into the
   node-validation modules.
3. `scene_value_validation_node.dart` becomes a thin node-validation facade
   that keeps only the shared base-field validation frame and node-family
   dispatch.
4. Family-local validation ownership moves into explicit files:
   `scene_value_validation_node_image.dart`,
   `scene_value_validation_node_text.dart`,
   `scene_value_validation_node_stroke.dart`,
   `scene_value_validation_node_line.dart`,
   `scene_value_validation_node_rect.dart`,
   and
   `scene_value_validation_node_path.dart`.
5. Existing primitive and support validation owners remain the only shared
   helper owners; this step must not create a second primitive ruleset.
6. This step must not introduce a new generic node-validation support bucket.
7. Metric or clone improvement counts only when the current mixed family-rule
   matrix is genuinely removed from `scene_value_validation_node.dart`.

## 5. Result Requirements

1. `lib/src/model/scene_value_validation_node.dart` no longer contains the
   current mixed matrix of family-local rule bodies for
   `image`,
   `text`,
   `stroke`,
   `line`,
   `rect`,
   and
   `path`.
2. Each supported node family has one explicit focused validation owner file.
3. `scene_value_validation.dart` remains the only canonical entry surface used
   by downstream model consumers.
4. `scene_policy.dart` continues to consume one validation facade and remains
   the only owner of scene-level semantics.
5. Runtime and snapshot node validation behavior remains equivalent for
   `sceneValidateNodeSnapshot(...)`,
   `sceneValidateNode(...)`,
   `SceneBuilder.buildFromJson(...)`,
   and decode diagnostics that depend on these validations.
6. No new generic helper bucket or parallel validation path is introduced.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `scene_value_validation_node.dart` is currently `603` lines and mixes
  base-field validation, snapshot/runtime routing, family-local rule bodies,
  and low-level field helpers.
- The current residual seam is not the top-level validation facade;
  it is the fact that family-local rules still live in one large node owner.
- `scene_value_validation.dart` already behaves as the canonical facade and
  must keep that role.
- `scene_policy.dart` already owns duplicate-id, layer-id, and range
  semantics; those rules must not move.
- Shared primitive validation and reporting helpers already live in
  `scene_value_validation_primitives.dart`
  and
  `scene_value_validation_support.dart`;
  they must be reused instead of being forked.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/model/scene_value_validation.dart lib/src/model/scene_value_validation_node.dart lib/src/model/scene_value_validation_node_image.dart lib/src/model/scene_value_validation_node_text.dart lib/src/model/scene_value_validation_node_stroke.dart lib/src/model/scene_value_validation_node_line.dart lib/src/model/scene_value_validation_node_rect.dart lib/src/model/scene_value_validation_node_path.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
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

- Boundary-visible validation behavior and diagnostic attribution.
- `ScenePolicy` ownership of scene-level semantics.
- Primitive validation rules and shared error-reporting helpers.
- Canonical validation entry through `scene_value_validation.dart`.

### 6.4 Allowed Semantic Change Zones

- File boundaries and imports inside the node-validation seam
- Shared base-field validation and dispatch shaping inside
  `lib/src/model/scene_value_validation_node.dart`
- Family-local rule ownership inside the explicit node-family files
- Minimal test adaptation required to prove behavior equivalence after the
  split

### 6.8 Prohibited

- Reopening `scene_policy.dart` scene-level semantics.
- Moving validation entry away from `scene_value_validation.dart`.
- Reopening `scene_value_validation_top_level.dart` or
  `scene_value_validation_palette_grid.dart` as part of this step.
- Creating a new generic support bucket such as
  `scene_value_validation_node_support.dart`.
- Creating a second primitive validation owner or duplicating the existing
  boundary rules inside family modules.
- Expanding the scope into builder decode, snapshot materialization, or scene
  graph traversal work.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice changes failure attribution, the exact field paths and error
   surfaces must be pinned by tests in the same change.
7. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [x] Make `scene_value_validation_node.dart` a thin node-validation facade

#### Slice Contract

`scene_value_validation_node.dart` keeps only the shared base-field validation
frame and node-family dispatch instead of owning the full family-rule matrix.

#### Change

Refactor `lib/src/model/scene_value_validation_node.dart` so it retains only
shared snapshot/runtime base validation, node-family dispatch, and the minimum
shared frame needed to route node-family validation to explicit family owners.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_value_validation_node.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- MCP test runner preset: `model_contract`

#### Positive Scenarios

- `sceneValidateNodeSnapshot(...)` still validates common node boundary fields.
- `sceneValidateNode(...)` still validates common runtime node boundary fields.
- The same node family is dispatched for the same snapshot/runtime node type.

#### Negative Scenarios

- `scene_value_validation_node.dart` does not retain the replaced inline
  family-rule bodies beside the new family modules.
- `ScenePolicy` does not start importing family modules directly.

#### Closure Evidence

- Green run of the listed verifications.
- `scene_value_validation_node.dart` is visibly reduced to shared frame and
  dispatch responsibilities.

### Slice 2. [x] Move family-local node validation rules into focused owner modules

#### Slice Contract

Each node family has one explicit focused validation owner that contains only
its family-local validation rules for snapshot/runtime forms.

#### Change

Introduce and wire
`scene_value_validation_node_image.dart`,
`scene_value_validation_node_text.dart`,
`scene_value_validation_node_stroke.dart`,
`scene_value_validation_node_line.dart`,
`scene_value_validation_node_rect.dart`,
and
`scene_value_validation_node_path.dart`
so family-local rules live in the matching owner module and reuse the
existing primitive/support validation owners rather than duplicating them.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_value_validation_node_image.dart lib/src/model/scene_value_validation_node_text.dart lib/src/model/scene_value_validation_node_stroke.dart lib/src/model/scene_value_validation_node_line.dart lib/src/model/scene_value_validation_node_rect.dart lib/src/model/scene_value_validation_node_path.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- MCP test runner preset: `model_contract`
- MCP test runner preset: `core`
- MCP test runner preset: `example`

#### Positive Scenarios

- Each node family keeps the same accepted valid values in snapshot/runtime
  validation.
- Family-local optional fields keep the same nullability and path semantics.
- Downstream decode or validation entrypoints keep the same visible behavior.

#### Negative Scenarios

- Family modules do not reimplement primitive validation rules.
- No generic node-validation support bucket appears beside the family files.
- `scene_value_validation.dart` remains the only validation entry surface.

#### Closure Evidence

- Green run of the listed verifications.
- Every supported node family has one explicit focused owner file.
- The previous family-rule matrix is absent from
  `scene_value_validation_node.dart`.

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
