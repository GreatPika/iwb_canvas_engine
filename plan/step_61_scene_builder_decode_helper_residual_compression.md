language: russian

# Шаг 61. Сжать residual JSON decode helper matrix в `SceneBuilder`

## 1. Change Mandate

Этот шаг дожимает residual JSON decode helper matrix внутри уже существующего
`SceneBuilder` decode owner graph:
`scene_builder_json_require.dart`,
`scene_builder_decode_node_common.dart`,
`scene_builder_decode_node_family.dart`,
и family decode owner-ы для
`image`,
`text`,
`stroke`,
`line`,
`rect`,
`path`
перестают выражать остаточные `require/optional/typed` и family decode
паттерны как параллельные ручные формы, сохраняя текущее разделение owner-ов,
не меняя поведение `scene_builder.dart` и не вводя новый generic support file.

## 2. Change Boundary

### Included in the Change

- `lib/src/model/scene_builder_json_require.dart`
- `lib/src/model/scene_builder_decode_node_common.dart`
- `lib/src/model/scene_builder_decode_node_family.dart`
- `lib/src/model/scene_builder_decode_text.dart`
- `lib/src/model/scene_builder_decode_image.dart`
- `lib/src/model/scene_builder_decode_stroke.dart`
- `lib/src/model/scene_builder_decode_line.dart`
- `lib/src/model/scene_builder_decode_rect.dart`
- `lib/src/model/scene_builder_decode_path.dart`
- `test/model/scene_builder_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/entrypoints/basic_smoke_test.dart`
- `PLAN.md`
- `plan/model_target_architecture.md`
- `plan/step_45_scene_builder_json_decode_and_require_owner_split.md`
- `plan/step_49_json_helper_and_document_locator_residual_cleanup.md`
- `plan/step_50_model_post_closure_helper_rebaseline.md`
- `plan/step_51_scene_decode_and_scene_mutation_owner_split.md`
- `plan/step_61_scene_builder_decode_helper_residual_compression.md`

### Not Included in the Change

- `lib/src/model/scene_builder.dart`
- `lib/src/model/scene_builder_decode_json.dart`
- `lib/src/model/scene_builder_decode_scene.dart`
- `lib/src/model/scene_builder_decode_scene_metadata.dart`
- `lib/src/model/scene_builder_decode_layers.dart`
- `lib/src/model/scene_builder_json_parse.dart`
- `lib/src/model/scene_document_codec.dart`
- `lib/src/model/scene_from_snapshot.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`
- `ARCHITECTURE.md`
- `API_GUIDE.md`
- `README.md`
- `CHANGELOG.md`
- Any new helper dump such as `scene_builder_decode_support.dart`
- Reopening the SceneBuilder owner split already closed by steps `45`, `49`,
  and `51`

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/model/scene_builder_json_require.dart`
- `lib/src/model/scene_builder_decode_node_common.dart`
- `lib/src/model/scene_builder_decode_node_family.dart`
- `lib/src/model/scene_builder_decode_text.dart`
- `lib/src/model/scene_builder_decode_image.dart`
- `lib/src/model/scene_builder_decode_stroke.dart`
- `lib/src/model/scene_builder_decode_line.dart`
- `lib/src/model/scene_builder_decode_rect.dart`
- `lib/src/model/scene_builder_decode_path.dart`
- `PLAN.md`

### Test Files

- `test/model/scene_builder_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/entrypoints/basic_smoke_test.dart`

### Fixture and Supporting Data Files

- `plan/model_target_architecture.md`
- `plan/step_45_scene_builder_json_decode_and_require_owner_split.md`
- `plan/step_49_json_helper_and_document_locator_residual_cleanup.md`
- `plan/step_50_model_post_closure_helper_rebaseline.md`
- `plan/step_51_scene_decode_and_scene_mutation_owner_split.md`
- `plan/step_61_scene_builder_decode_helper_residual_compression.md`

### Analysis Area

- `lib/src/model/scene_builder_json_require.dart`
- `lib/src/model/scene_builder_decode_node_common.dart`
- `lib/src/model/scene_builder_decode_node_family.dart`
- `lib/src/model/scene_builder_decode_text.dart`
- `lib/src/model/scene_builder_decode_image.dart`
- `lib/src/model/scene_builder_decode_stroke.dart`
- `lib/src/model/scene_builder_decode_line.dart`
- `lib/src/model/scene_builder_decode_rect.dart`
- `lib/src/model/scene_builder_decode_path.dart`
- `test/model/scene_builder_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/entrypoints/basic_smoke_test.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied either to one canonical
  structural require path in `scene_builder_json_require.dart` or to one
  family/common decode call-site alignment that removes duplicated access
  scaffolding.
- Every modified test must pin one proof that SceneBuilder decode behavior,
  diagnostics, or public entry behavior stayed equivalent after the helper
  compression.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `plan/model_target_architecture.md` remains the source of truth for the
   `SceneBuilder` decode owner graph.
2. `lib/src/model/scene_builder.dart` remains the thin internal import facade.
3. `lib/src/model/scene_builder_json_require.dart` remains the structural
   require / typed-extraction owner only; scalar and enum parsing stays in
   `scene_builder_json_parse.dart`.
4. `lib/src/model/scene_builder_decode_node_family.dart` remains the node-type
   dispatcher only.
5. Family decode responsibility remains in the focused family files:
   `scene_builder_decode_image.dart`,
   `scene_builder_decode_text.dart`,
   `scene_builder_decode_stroke.dart`,
   `scene_builder_decode_line.dart`,
   `scene_builder_decode_rect.dart`,
   and
   `scene_builder_decode_path.dart`.
6. This step must not introduce a new umbrella support file or a second helper
   surface parallel to the current owner graph.
7. Metric or clone improvement counts only when duplicated access or decode
   scaffolding is genuinely removed; indirection added only to satisfy tooling
   does not count as closure.

## 5. Result Requirements

1. `lib/src/model/scene_builder_json_require.dart` no longer repeats the same
   presence, nullability, path, and type-check scaffolding across the current
   residual `require/optional/typed/validated` helper family in parallel form.
2. `lib/src/model/scene_builder_decode_node_common.dart` and the family decode
   owner files reuse canonical require/optional/typed access paths instead of
   re-encoding the same extraction idioms inline.
3. `lib/src/model/scene_builder_decode_node_family.dart` remains a thin
   dispatcher and does not gain new mixed decode ownership.
4. Family decode owner files remain focused on family-specific validated field
   assembly rather than repeating generic JSON access scaffolding.
5. Public and downstream-visible behavior remains equivalent for
   `sceneBuildFromJsonMap(...)`,
   `SceneBuilder.buildFromJson(...)`,
   and the stable `SceneDataException.code` / `path` / `details` surface.
6. No new support file or parallel helper surface is introduced.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Steps `45`, `49`, and `51` already closed the structural `SceneBuilder`
  owner split; this step is residual compression inside that existing graph.
- The current code still shows repeated helper forms:
  required typed bool flags in
  `scene_builder_decode_node_common.dart`
  and
  `scene_builder_decode_text.dart`,
  repeated typed-string + parse patterns in
  `scene_builder_decode_node_family.dart`,
  `scene_builder_decode_text.dart`,
  and
  `scene_builder_decode_path.dart`,
  and repeated required-field + validated-value patterns across family owners.
- The residual seam is local to structural require helpers and the way family
  decode owners consume them; it is not a missing file split.
- `scene_builder_json_parse.dart` already owns scalar and enum parsing and must
  keep that responsibility.
- `scene_builder.dart` already behaves as the thin import facade and must not
  be reopened in this step.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/model/scene_builder_json_require.dart lib/src/model/scene_builder_decode_node_common.dart lib/src/model/scene_builder_decode_node_family.dart lib/src/model/scene_builder_decode_text.dart lib/src/model/scene_builder_decode_image.dart lib/src/model/scene_builder_decode_stroke.dart lib/src/model/scene_builder_decode_line.dart lib/src/model/scene_builder_decode_rect.dart lib/src/model/scene_builder_decode_path.dart --report-all`
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

- `SceneBuilder` parsed-map import behavior and failure semantics.
- Stable field-path attribution for nested decode failures.
- Stable `SceneDataException.code`, `path`, and `details` shapes for the
  covered decode paths.
- The current owner graph from `plan/model_target_architecture.md`.

### 6.4 Allowed Semantic Change Zones

- Shared presence/path/null/type scaffolding inside
  `lib/src/model/scene_builder_json_require.dart`
- Call-site alignment in
  `lib/src/model/scene_builder_decode_node_common.dart`
  and the listed family decode files
- Minimal local helper shaping required to keep
  `scene_builder_decode_node_family.dart`
  a thin dispatcher while family owners consume one canonical helper surface
- Test adaptation required to prove behavior equivalence after helper
  compression

### 6.8 Prohibited

- Reopening `lib/src/model/scene_builder.dart`,
  `scene_builder_decode_json.dart`,
  `scene_builder_decode_scene.dart`,
  `scene_builder_decode_scene_metadata.dart`,
  or
  `scene_builder_decode_layers.dart` as part of this step.
- Moving scalar or enum parsing responsibilities from
  `scene_builder_json_parse.dart` into `scene_builder_json_require.dart`.
- Introducing a new support bucket such as `scene_builder_decode_support.dart`
  or any second parallel helper surface.
- Changing `SceneDataException` behavior solely to fit helper consolidation.
- Expanding the scope into snapshot materialization, node boundary mapping,
  scene validation, or scene graph traversal work.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice changes decode-failure behavior, the exact failure surface must
   be pinned by tests in the same change.
7. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [ ] Centralize structural require and optional access scaffolding

#### Slice Contract

`scene_builder_json_require.dart` exposes one canonical path for the shared
presence, nullability, path, and type-check scaffolding currently repeated
across the residual helper family.

#### Change

Refactor `lib/src/model/scene_builder_json_require.dart` so the current
`require/optional/typed/validated` helpers reuse one internal structural
access path instead of carrying parallel copies of the same extraction
scaffolding.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_builder_json_require.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- MCP test runner preset: `model_contract`

#### Positive Scenarios

- Required field extraction still reports the same missing-field paths.
- Optional extraction still preserves `missing` versus `null` behavior.
- Typed and validated helpers still accept the same valid JSON inputs.

#### Negative Scenarios

- Scalar and enum parsing does not move into `scene_builder_json_require.dart`.
- A new generic support file is not introduced.

#### Closure Evidence

- Green run of the listed verifications.
- `scene_builder_json_require.dart` no longer expresses the current residual
  access scaffolding as parallel helper copies.

### Slice 2. [ ] Align node-common and family decode owners to canonical helper paths

#### Slice Contract

Node-common and family decode owner files consume one canonical structural
helper surface and stop repeating the same typed/validated JSON access idioms
in slightly different local forms.

#### Change

Update
`lib/src/model/scene_builder_decode_node_common.dart`,
`lib/src/model/scene_builder_decode_node_family.dart`,
`lib/src/model/scene_builder_decode_text.dart`,
`lib/src/model/scene_builder_decode_image.dart`,
`lib/src/model/scene_builder_decode_stroke.dart`,
`lib/src/model/scene_builder_decode_line.dart`,
`lib/src/model/scene_builder_decode_rect.dart`,
and
`lib/src/model/scene_builder_decode_path.dart`
so they stay focused on common or family-specific validated assembly while
consuming the compressed helper surface from
`scene_builder_json_require.dart`.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_builder_decode_node_common.dart lib/src/model/scene_builder_decode_node_family.dart lib/src/model/scene_builder_decode_text.dart lib/src/model/scene_builder_decode_image.dart lib/src/model/scene_builder_decode_stroke.dart lib/src/model/scene_builder_decode_line.dart lib/src/model/scene_builder_decode_rect.dart lib/src/model/scene_builder_decode_path.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- MCP test runner preset: `model_contract`
- MCP test runner preset: `core`
- MCP test runner preset: `example`

#### Positive Scenarios

- Node type dispatch still routes each supported node type to the same family
  owner.
- Common node fields still decode to the same validated values and defaults.
- Family owners still materialize the same snapshot backing objects for valid
  JSON payloads.

#### Negative Scenarios

- `scene_builder_decode_node_family.dart` does not accumulate new mixed decode
  logic.
- Family owners do not gain scalar/enum parse responsibilities.
- Public `SceneBuilder` behavior and decode diagnostics do not drift.

#### Closure Evidence

- Green run of the listed verifications.
- Family and common owner files are visibly narrower in generic extraction
  scaffolding and remain focused on their declared owner role.

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
