language: russian

# Шаг 14. Закрыть тестами и невозвратом все этапы через подшаги 14.1-14.4

## 1. Change Mandate

This change decomposes step 14 into four verifiable non-regression contracts for
`serialization/model/core`, `controller`, `interactive/view`, and
`render/cache`, so the final closure is tied to real ownership seams in the
current codebase.

## 2. Change Boundary

### Included in the Change
- `development_plan/step_14_test_and_non_regression_closure.md`
- `development_plan/step_14_1_serialization_model_and_core_regression_matrix.md`
- `development_plan/step_14_2_controller_regression_matrix.md`
- `development_plan/step_14_3_interactive_and_view_regression_matrix.md`
- `development_plan/step_14_4_render_and_cache_regression_matrix.md`
- `DEVELOPMENT_PLAN.md`

### Not Included in the Change
- Production code changes under `lib/**`, `test/**`, `tool/**`, or `example/**`
- Reopening semantics already fixed by steps `4.x-13.x`
- New guardrail categories outside the required validation policy already
  documented in repository instructions

## 3. File Map and Analysis Areas

### Implementation Files
- `lib/src/serialization/scene_codec.dart`
- `lib/src/serialization/codec_guards.dart`
- `lib/src/model/scene_policy.dart`
- `lib/src/model/scene_builder.dart`
- `lib/src/model/document.dart`
- `lib/src/core/background_layer_invariants.dart`
- `lib/src/core/id_generator.dart`
- `lib/src/core/revision_policy.dart`
- `lib/src/core/nodes.dart`
- `lib/src/controller/scene_writer.dart`
- `lib/src/controller/scene_controller.dart`
- `lib/src/controller/mutation_executor.dart`
- `lib/src/controller/commands/scene_commands.dart`
- `lib/src/controller/commands/draw_commands.dart`
- `lib/src/controller/commands/move_commands.dart`
- `lib/src/interactive/scene_controller_interactive.dart`
- `lib/src/interactive/interaction_eligibility_policy.dart`
- `lib/src/interactive/internal/**`
- `lib/src/view/scene_view_interactive.dart`
- `lib/src/view/scene_view_pointer_router.dart`
- `lib/src/render/scene_painter.dart`
- `lib/src/render/scene_grid_renderer.dart`
- `lib/src/render/scene_render_caches.dart`
- `lib/src/render/render_geometry_cache.dart`
- `lib/src/render/cache/**`

### Test Files
- `test/serialization/**`
- `test/model/**`
- `test/core/**`
- `test/controller/**`
- `test/interactive/**`
- `test/view/**`
- `test/render/**`

### Analysis Area
- `lib/src/serialization/**`
- `lib/src/model/**`
- `lib/src/core/**`
- `lib/src/controller/**`
- `lib/src/interactive/**`
- `lib/src/view/**`
- `lib/src/render/**`
- `test/serialization/**`
- `test/model/**`
- `test/core/**`
- `test/controller/**`
- `test/interactive/**`
- `test/view/**`
- `test/render/**`

### Outside the Change Boundary
- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified fixture must be tied to a specific verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Step `14` closes regressions on top of the current production semantics from
   steps `4.x-13.x`; it does not reopen those semantics for redesign.
2. The step is split by current ownership seams visible in the codebase:
   `serialization/model/core`, `controller`, `interactive/view`,
   `render/cache`.
3. The final closure for every listed problem still requires the triad from the
   original step description: a concrete changed file, a concrete closure
   mechanism, and a concrete regression proof.
4. Public behavior in this step is locked by runtime tests, targeted guardrails,
   and required CI checks; new sync glue or duplicate sources of truth are not
   part of the step.

## 5. Result Requirements

1. Every unresolved regression item from the original step `14` is assigned to
   exactly one substep contract.
2. No substep mixes ownership across the four active seams of the current
   codebase.
3. Every substep names the concrete implementation files, targeted tests, and
   required verifications needed to close its regression matrix.
4. The umbrella step defines the final verification set required before step
   `14` can be marked complete.

## 6. Implementation Specification

### 6.1 Analysis Scope
- Compare the original step list with the current `lib/**` and `test/**`
  structure before deciding the split.
- Keep each regression item in the substep that owns the production seam where
  the behavior lives today.
- Use existing repository validation policy as the final verification source of
  truth.

### 6.2 Target Verification Units
- `test/serialization/**`
- `test/model/**`
- `test/core/**`
- `test/controller/**`
- `test/interactive/**`
- `test/view/**`
- `test/render/**`
- `dart run tool/check_invariant_coverage.dart`
- The required formatting, analysis, DCM, shard, coverage, and tool-test runs
  from the repository validation policy

### 6.3 Protected States, Data, or Structures
- Public `SceneDataException` error contract
- Scene/model ownership of `backgroundLayer`, ids, structural limits, and
  revisions
- Controller commit lifecycle, immutable result payloads, and selection/write
  semantics
- Interactive gesture lifecycle, pointer normalization, and host-side pointer
  routing
- Render/cache key composition, invalidation, and painter/grid parity

### 6.4 Allowed Semantic Change Zones
- Regression-proof coverage for boundary and serialization semantics
- Regression-proof coverage for scene/model/core invariants
- Regression-proof coverage for controller write and commit semantics
- Regression-proof coverage for interactive/view pointer and gesture semantics
- Regression-proof coverage for render/cache structural contracts

### 6.8 Prohibited
- Reassigning one regression item to multiple substeps
- Using a substep to redefine behavior owned by already closed steps
- Treating “existing tests happen to cover it” as sufficient closure without an
  explicit contract entry
- Marking the umbrella step complete without the final verification set

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the
   trigger point must be attached.
7. If a slice changes an analysis rule, negative and positive scenarios must be
   covered where applicable to the subject of the change.
8. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [ ] Boundary and Model Regression Contract

#### Slice Contract
The original `serialization`, `model`, and `core` regression items are closed
by one substep contract with explicit ownership and verification.

#### Change
Create
`development_plan/step_14_1_serialization_model_and_core_regression_matrix.md`
and assign to it all original step `14` items that live in
`lib/src/serialization/**`, `lib/src/model/**`, and `lib/src/core/**`.

#### Verification
- Manual comparison of the original step `14` list against the new `14.1`
  contract
- File-map review against the current `lib/src/serialization/**`,
  `lib/src/model/**`, `lib/src/core/**`, `test/serialization/**`,
  `test/model/**`, and `test/core/**`

#### Closure Evidence
- The `14.1` file exists and uses the change-contract structure.
- No original boundary/model/core regression item remains only in the umbrella
  text.

### Slice 2. [ ] Controller Regression Contract

#### Slice Contract
The original controller regression items are closed by one substep contract
owned only by `controller` files and tests.

#### Change
Create `development_plan/step_14_2_controller_regression_matrix.md` and assign
to it the original controller-side regression matrix.

#### Verification
- Manual comparison of the original step `14` list against the new `14.2`
  contract
- File-map review against the current `lib/src/controller/**` and
  `test/controller/**`

#### Closure Evidence
- The `14.2` file exists and uses the change-contract structure.
- Controller regression items are no longer mixed with interactive or render
  ownership.

### Slice 3. [x] Interactive and View Regression Contract

#### Slice Contract
The original interactive and view regression items are closed by one substep
contract aligned with the current input-lifecycle seam.

#### Change
Create
`development_plan/step_14_3_interactive_and_view_regression_matrix.md` and
assign to it the original `interactive` and `view` regression matrix.

#### Verification
- Manual comparison of the original step `14` list against the new `14.3`
  contract
- File-map review against the current `lib/src/interactive/**`,
  `lib/src/view/**`, `test/interactive/**`, and `test/view/**`

#### Closure Evidence
- The `14.3` file exists and uses the change-contract structure.
- Interactive and view ownership stays in one substep and is not split across
  controller or render contracts.

### Slice 4. [ ] Render and Cache Regression Contract

#### Slice Contract
The original render and cache regression items are closed by one substep
contract aligned with the current render ownership seam.

#### Change
Create `development_plan/step_14_4_render_and_cache_regression_matrix.md` and
assign to it the original `render` regression matrix.

#### Verification
- Manual comparison of the original step `14` list against the new `14.4`
  contract
- File-map review against the current `lib/src/render/**` and `test/render/**`

#### Closure Evidence
- The `14.4` file exists and uses the change-contract structure.
- Render/cache regression items stay isolated from interactive and controller
  ownership.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test shards for:
  - `test/core`
  - `test/model test/serialization test/contract test/public_api test/entrypoints`
  - `test/controller/internal`
  - `test/controller/core test/controller/commands` plus controller-root
    `*_test.dart` files
  - `test/render test/view`
  - `test/interactive`
  - `example/test` with MCP root `example/`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart` when the tool-test trigger list is hit

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
