language: russian

# Шаг 57. Убрать residual access seams, render-state leak и naming drift после public split `SceneController`

## 1. Change Mandate

This change fixes the residual controller seams left after the `SceneController`
capability split by deleting non-owning access adapters, restoring the root
render-state boundary, and aligning repo-local docs and structural guardrails
with the final controller architecture.

## 2. Change Boundary

### Included in the Change

- Deletion of the residual selection/scene access-adapter files under
  `lib/src/interactive/internal/`.
- Direct rewiring of `SceneControllerSelection` and `SceneControllerScene` to
  their retained runtime/mutation dependencies.
- Removal of committed render-state leakage from
  `SceneControllerInteraction` and the interactive overlay/view adaptation
  required by that cleanup.
- Guardrail, invariant-proof, and repo-doc cleanup required to pin the final
  post-split controller architecture.

### Not Included in the Change

- Any new public capability owner beyond `interaction`, `selection`, and
  `scene`.
- Further splitting `SceneControllerInteraction` into smaller public owners to
  chase metrics.
- New product behavior in pointer handling, selection flows, scene mutations,
  or event delivery.
- Changes outside the controller/view/doc/guardrail zones listed below unless
  a targeted verification cannot close without them.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/interactive/scene_controller.dart`
- `lib/src/interactive/scene_controller_interaction.dart`
- `lib/src/interactive/scene_controller_selection.dart`
- `lib/src/interactive/scene_controller_scene.dart`
- `lib/src/interactive/internal/scene_controller_facade_assembly.dart`
- `lib/src/interactive/internal/scene_controller_interaction_access.dart`
- `lib/src/interactive/internal/scene_controller_interaction_config.dart`
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
- `lib/src/interactive/internal/scene_controller_selection_access.dart`
- `lib/src/interactive/internal/scene_controller_selection_mutations.dart`
- `lib/src/interactive/internal/scene_controller_scene_access.dart`
- `lib/src/interactive/internal/scene_controller_scene_mutations.dart`
- `lib/src/view/scene_view_interactive.dart`
- `lib/src/view/scene_view_interactive_overlay_painter.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `PLAN.md`
- `tool/src/guardrails/interactive_api_guardrails.dart`
- `tool/invariant_registry.dart`

### Test Files

- `test/interactive/core/**`
- `test/interactive/test_support/interactive_controller_fixtures.dart`
- `test/view/scene_view_interactive_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/support/guardrails_tool_test_support.dart`

### Fixture and Supporting Data Files

- `plan/step_57_scene_controller_post_split_residual_cleanup.md`

### Analysis Area

- `lib/src/interactive/**`
- `lib/src/view/**`
- `tool/src/guardrails/**`
- `tool/invariant_registry.dart`
- `test/interactive/**`
- `test/view/**`
- `test/tool/guardrails/**`
- `test/tool/support/**`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified production file must either delete a residual forwarding seam,
  move behavior ownership directly into an already-approved capability owner,
  remove root render-state leakage from `interaction`, or fix repo-local
  architecture drift caused by the deleted facade.
- Every modified guardrail, invariant, or test file must pin one concrete
  outcome of that cleanup.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. The public controller shape is fixed as one root `SceneController` plus the
   capability owners `interaction`, `selection`, and `scene`.
2. `lib/src/interactive/internal/scene_controller_selection_access.dart` and
   `lib/src/interactive/internal/scene_controller_scene_access.dart` are
   residual seams and must not survive this step.
3. `lib/src/interactive/internal/scene_controller_interaction_access.dart`
   is retained as the single internal access bridge for the capability graph
   in this area.
4. Committed render state remains owned by root `SceneController`; capability
   owners must not expose `SceneSnapshot` or other root render-state mirrors
   that are not intrinsic to their own responsibility.
5. `lib/src/interactive/internal/scene_controller_facade_assembly.dart`
   is retained as the composition-root wiring owner and must not own
   duplicated public method surfaces, public guards, or business logic.
6. `SceneControllerInteraction` owns the entire surviving interaction
   capability surface after this cleanup and is not split further in this
   step.
7. `SceneView` remains the only public runtime alias in this area; repo-local
   docs and architecture proofs must not describe `SceneController` as an
   alias after this step.

## 5. Result Requirements

1. `lib/src/interactive/internal/scene_controller_selection_access.dart` does
   not exist in the production tree.
2. `lib/src/interactive/internal/scene_controller_scene_access.dart` does not
   exist in the production tree.
3. `SceneControllerSelection` owns its public guards and dispatches directly to
   its retained runtime/mutation dependencies without an intermediate access
   surface that duplicates the public selection API.
4. `SceneControllerScene` owns its public guards and dispatches directly to its
   retained runtime/mutation dependencies without an intermediate access
   surface that duplicates the public scene API.
5. `SceneControllerInteraction` does not expose `snapshot`, and interactive
   overlay/view code does not read committed snapshot or camera state through
   `interaction`.
6. `SceneController` remains the only committed render-state boundary used by
   interactive view/painter code.
7. `scene_controller_facade_assembly.dart` wires the owner graph without
   defining selection/scene access adapters or other duplicated forwarding
   surfaces.
8. `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`,
   `tool/invariant_registry.dart`, and the positive guardrail/proof files that
   describe current controller architecture no longer use deleted-facade naming
   or alias wording for `SceneController`.
9. The production tree contains no controller-side support file whose sole
   responsibility is forwarding a duplicated public method surface.
10. The final clone baseline for `lib/` does not exceed the current confirmed
    baseline of `44` clusters.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Step 56 already delivered the public split:
  `SceneController`, `SceneControllerInteraction`,
  `SceneControllerSelection`, and `SceneControllerScene` are present, and
  `SceneControllerInteractive` is deleted from production/public API.
- The current measured residual baseline is:
  `SceneController` in `lib/src/interactive/scene_controller.dart`
  has `12 imports` and `CBO 14`;
  `SceneControllerInteraction` in
  `lib/src/interactive/scene_controller_interaction.dart`
  has `RFC 53` and `WMC 56`;
  `assembleSceneControllerFacade(...)` in
  `lib/src/interactive/internal/scene_controller_facade_assembly.dart`
  sits in a file with `14 imports` and has `41` source lines;
  `SceneControllerSelection` and `SceneControllerScene` are already green at
  `RFC 19 / WMC 9` and `RFC 26 / WMC 13`.
- `lib/src/interactive/internal/scene_controller_selection_access.dart` and
  `lib/src/interactive/internal/scene_controller_scene_access.dart` currently
  duplicate public selection/scene signatures and forward into retained
  mutation/runtime owners.
- `SceneControllerInteraction.snapshot` is being removed as a public
  breaking-change boundary, and
  `SceneViewInteractiveOverlayPainter` is moving camera reads to
  `controller.snapshot`.
- Repo-local truth still drifts from the new shape:
  `README.md`, `ARCHITECTURE.md`, and `CHANGELOG.md` still describe
  `SceneController` as an alias family, and `API_GUIDE.md` still contains the
  `Public aliases` heading plus a duplicate `SceneController` runtime entry.
- The current clone baseline remains `44` clusters, and the step 56 split did
  not create a new controller-specific clone hotspot.

### 6.2 Target Verification Units

- `test ! -e lib/src/interactive/internal/scene_controller_selection_access.dart`
- `test ! -e lib/src/interactive/internal/scene_controller_scene_access.dart`
- `rg -n "interaction\\.snapshot" lib test README.md API_GUIDE.md ARCHITECTURE.md`
- `rg -n "SceneControllerInteractive" README.md API_GUIDE.md ARCHITECTURE.md CHANGELOG.md example lib test/view test/entrypoints test/public_api test/interactive/test_support tool/goldens/public_api_symbols.txt test/tool/support/public_entrypoint_contract.dart`
- `rg -n "^Public aliases:$|Public runtime aliases|Stable public runtime aliases: \`SceneController\` and \`SceneView\`|SceneController is a typedef alias" README.md API_GUIDE.md ARCHITECTURE.md CHANGELOG.md`
- `dcm calculate-metrics lib/src/interactive lib/src/view --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/interactive`
- MCP test runner: `test/view`
- MCP test runner: `test/tool/guardrails`

### 6.3 Protected States, Data, or Structures

- Single source of truth for committed scene state and interactive runtime
  state.
- Current runtime behavior for pointer handling, preview ephemerality,
  selection exclusivity, transform/delete preflight, scene mutation side
  effects, and action/event emission.
- Root `SceneRenderState` contract consumed by render/view code.
- Existing public capability surface:
  `controller.interaction`, `controller.selection`, and `controller.scene`.
- Current resolver purity and post-dispose guard semantics enforced through
  `_ensurePublicSideEffectAllowed(...)`.

### 6.4 Allowed Semantic Change Zones

- Dependency wiring inside the existing capability graph.
- Direct behavior ownership boundaries for `selection` and `scene`.
- Read-path ownership for committed snapshot/camera data between root and
  interactive overlay/view code.
- Guardrail and invariant enforcement that rejects the residual seams and stale
  architecture drift.
- Repo-local controller architecture wording in docs and proof files.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- access-adapter bypass where a public capability owner forwards through an
  intermediate access interface that duplicates the same public surface
- render-state leak where `interaction` mirrors committed root snapshot/camera
  state
- assembly-seam bypass where the composition root retains duplicated public
  forwarding surfaces or behavior logic
- architecture-drift bypass where current docs or proof files still describe
  `SceneController` as an alias or still pin the deleted facade name

### 6.6 Allowed Forms That Do Not Count as Violations

- `scene_controller_interaction_access.dart` exists as the listener/root-state
  bridge and does not duplicate any public selection or scene method surface.
- `scene_controller_facade_assembly.dart` exists as construction-only wiring.
- Negative guardrail fixtures mentioning deleted seams, legacy names, or banned
  getters only to assert rejection.
- `SceneView` continuing to be documented as a typedef alias of
  `SceneViewInteractive`.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- `tool/src/guardrails/interactive_api_guardrails.dart` must fail if either
  `lib/src/interactive/internal/scene_controller_selection_access.dart` or
  `lib/src/interactive/internal/scene_controller_scene_access.dart` exists.
- `tool/src/guardrails/interactive_api_guardrails.dart` must fail if
  `SceneControllerInteraction` declares a public `snapshot` getter or another
  public getter that mirrors committed root render state.
- `tool/invariant_registry.dart` proof coverage for
  `INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY` must point at a
  SceneController-named facade proof file.
- Positive-source searches listed in section 6.2 must stay empty after the
  change.

### 6.8 Prohibited

- Keeping any selection/scene access adapter layer in production code.
- Moving any selection or scene mutation method cluster back onto root
  `SceneController`.
- Introducing another public capability owner or splitting
  `SceneControllerInteraction` further to reduce metrics.
- Leaving committed render-state mirrors on `SceneControllerInteraction`.
- Replacing deleted access seams with another forwarding-only helper or adapter
  layer.
- Leaving alias wording for `SceneController` in current docs, invariant
  proofs, or positive guardrail fixtures.
- Claiming closure through metric redistribution that does not delete a real
  seam or close a real boundary leak.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the
   trigger point must be attached.
7. If a slice changes an analysis rule, negative and positive scenarios must
   be covered where applicable to the subject of the change.
8. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [x] Delete selection/scene access adapters and move ownership directly into public owners

#### Slice Contract

`selection` and `scene` are direct behavior-owning capability boundaries, and
the duplicated selection/scene access-adapter layer no longer exists.

#### Change

Delete `scene_controller_selection_access.dart` and
`scene_controller_scene_access.dart`, inject their retained dependencies
directly into `SceneControllerSelection` and `SceneControllerScene`, and
simplify `scene_controller_facade_assembly.dart` so it wires public owners
without recreating those adapter seams.

#### Verification

- `test ! -e lib/src/interactive/internal/scene_controller_selection_access.dart`
- `test ! -e lib/src/interactive/internal/scene_controller_scene_access.dart`
- `dcm calculate-metrics lib/src/interactive lib/src/view --report-all`
- `dart run tool/check_guardrails.dart`
- MCP test runner: `test/interactive`

#### Fixtures Used

- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/support/guardrails_tool_test_support.dart`

#### Positive Scenarios

- `SceneControllerSelection` still exposes the same public selection
  operations through direct retained dependencies.
- `SceneControllerScene` still exposes the same public scene operations through
  direct retained dependencies.
- `assembleSceneControllerFacade(...)` wires the owners without selection/scene
  access adapters.

#### Negative Scenarios

- Guardrails reject a retained
  `lib/src/interactive/internal/scene_controller_selection_access.dart`.
- Guardrails reject a retained
  `lib/src/interactive/internal/scene_controller_scene_access.dart`.

#### Closure Evidence

- Green run of the listed verifications.
- Both `test ! -e ...` checks pass.

### Slice 2. [x] Remove the committed render-state leak from `interaction`

#### Slice Contract

Committed snapshot/camera data is read from root `SceneController`, not through
`SceneControllerInteraction`.

#### Change

Remove the public `snapshot` leak from `SceneControllerInteraction`, adapt
`SceneViewInteractiveOverlayPainter` and its callers to read committed
render-state data from the root render-state boundary, and update the affected
interactive/view tests and test support.

#### Verification

- `rg -n "interaction\\.snapshot" lib test README.md API_GUIDE.md ARCHITECTURE.md`
- `dcm calculate-metrics lib/src/interactive lib/src/view --report-all`
- `dart run tool/check_guardrails.dart`
- MCP test runner: `test/interactive`
- MCP test runner: `test/view`

#### Fixtures Used

- `test/view/scene_view_interactive_test.dart`
- `test/interactive/test_support/interactive_controller_fixtures.dart`

#### Positive Scenarios

- Interactive overlay painting still uses committed camera offset and preview
  state correctly after the leak is removed.
- Existing interactive and view flows continue to observe the same preview and
  committed-scene behavior.

#### Negative Scenarios

- Guardrails reject a public `snapshot` getter on
  `SceneControllerInteraction`.

#### Closure Evidence

- Green run of the listed verifications.
- The `rg -n "interaction\\.snapshot" ...` search returns no matches.

### Slice 3. [x] Close repo-local docs, proofs, and guardrails on the final controller architecture

#### Slice Contract

Repo-local docs, proof files, and structural guardrails describe only the
current `SceneController` architecture and mechanically reject the residual
seams removed by this step.

#### Change

Update `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`,
`tool/src/guardrails/interactive_api_guardrails.dart`,
`tool/invariant_registry.dart`, and the positive guardrail/proof files so the
repo no longer documents `SceneController` as an alias, no longer pins the
deleted facade name in current-architecture proofs, and structurally rejects
the deleted access seams plus the `interaction` render-state leak.

#### Verification

- `rg -n "SceneControllerInteractive" README.md API_GUIDE.md ARCHITECTURE.md CHANGELOG.md example lib test/view test/entrypoints test/public_api test/interactive/test_support tool/goldens/public_api_symbols.txt test/tool/support/public_entrypoint_contract.dart`
- `rg -n "^Public aliases:$|Public runtime aliases|Stable public runtime aliases: \`SceneController\` and \`SceneView\`|SceneController is a typedef alias" README.md API_GUIDE.md ARCHITECTURE.md CHANGELOG.md`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dcm calculate-metrics lib/src/interactive lib/src/view --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/`
- MCP test runner: `test/tool/guardrails`

#### Fixtures Used

- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`

#### Positive Scenarios

- Docs and proof files describe the final controller architecture without alias
  wording for `SceneController`.
- Guardrails accept the cleaned post-split controller graph.

#### Negative Scenarios

- Guardrails reject a reintroduced selection/scene access seam.
- Guardrails reject a reintroduced committed render-state leak on
  `SceneControllerInteraction`.

#### Closure Evidence

- Green run of the listed verifications.
- Both `rg -n ...` doc/legacy searches return no matches.
- Clone baseline does not exceed `44` clusters.

## 9. Final Verification

- `test ! -e lib/src/interactive/internal/scene_controller_selection_access.dart`
- `test ! -e lib/src/interactive/internal/scene_controller_scene_access.dart`
- `rg -n "interaction\\.snapshot" lib test README.md API_GUIDE.md ARCHITECTURE.md`
- `rg -n "SceneControllerInteractive" README.md API_GUIDE.md ARCHITECTURE.md CHANGELOG.md example lib test/view test/entrypoints test/public_api test/interactive/test_support tool/goldens/public_api_symbols.txt test/tool/support/public_entrypoint_contract.dart`
- `rg -n "^Public aliases:$|Public runtime aliases|Stable public runtime aliases: \`SceneController\` and \`SceneView\`|SceneController is a typedef alias" README.md API_GUIDE.md ARCHITECTURE.md CHANGELOG.md`
- `dcm calculate-metrics lib/src/interactive lib/src/view --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/core`
- MCP test runner: `test/model test/serialization test/contract test/public_api test/entrypoints`
- MCP test runner: `test/controller/internal`
- MCP test runner: `test/controller/core test/controller/commands` plus controller-root `*_test.dart` files
- MCP test runner: `test/render test/view`
- MCP test runner: `test/interactive`
- MCP test runner: `example/test` with root `example/`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
