language: russian

# Шаг 97. Ликвидировать committed-only `SceneViewRenderState` путь из `SceneStoreController`

## 1. Change Mandate

This change removes the committed-only full `SceneViewRenderState` path from
`SceneStoreController` so the package no longer treats the committed store as a
production provider of the complete view render-state contract.

## 2. Change Boundary

### Included in the Change

- removing `SceneViewRenderState` ownership from
  `lib/src/controller/scene_store_controller.dart`
- migrating non-interactive render/view tests away from direct
  `SceneStoreController` render-state usage
- adding repository-local mechanical enforcement that prevents the controller
  layer from regaining the removed full view render-state role
- updating source-of-truth architecture and roadmap files for the removed path

### Not Included in the Change

- any public API widening or constructor change for `SceneController`,
  `SceneView`, `SceneViewRuntime`, or `SceneViewRenderSurface`
- introducing a new production committed-only adapter that replaces the
  removed path under `lib/**`
- changing interactive render-state assembly, pointer-session behavior, or the
  runtime/view public shell introduced by step `83`
- changing `SceneStoreController` write semantics, snapshot import semantics,
  or commit/runtime ownership outside the removed full view render-state role

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/controller/scene_store_controller.dart`
- `tool/src/guardrails/controller_api_guardrails.dart`
- `tool/invariant_registry.dart`
- `ARCHITECTURE.md`
- `PLAN.md`
- `plan/step_97_remove_committed_only_scene_view_render_state_path.md`

### Test Files

- `test/contract/runtime_contract_interfaces_test.dart`
- `test/view/scene_view_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_test.dart`
- `test/render/scene_static_layer_cache_test.dart`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`

### Fixture and Supporting Data Files

- `test/support/committed_scene_view_render_state.dart`
- `test/tool/support/guardrails_tool_test_support.dart`

### Analysis Area

- `lib/src/controller/**`
- `test/contract/**`
- `test/view/**`
- `test/render/**`
- `test/support/**`
- `tool/src/guardrails/**`
- `test/tool/guardrails/**`
- `tool/invariant_registry.dart`
- `ARCHITECTURE.md`
- `PLAN.md`
- `plan/step_83*.md`
- `plan/step_97*.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified fixture must be tied to a specific verification.
- Every newly proposed file or directory name must comply with the global
  `AGENTS.md` section `### File naming`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. This step removes the production committed-only full `SceneViewRenderState`
   path; it does not rename that path into a new production adapter under
   `lib/**`.
2. The public product-facing view path remains `SceneController` plus
   `SceneView`; no new public surface is introduced for the removed mode.
3. `SceneStoreController` remains a committed store/write facade and may remain
   consumable as `SceneRenderState`; only the full `SceneViewRenderState` role
   is removed in this step.
4. Full `SceneViewRenderState` ownership remains controller-owned through the
   assembled interactive runtime path introduced by step `83`.
5. Non-interactive render/view tests that still need a committed-only full
   render-state must use explicit test support types rather than
   `SceneStoreController` directly.
6. The no-return rule for the removed path must be mechanically enforced
   through the existing guardrails and invariant coverage pipeline rather than
   by prose alone.

## 5. Result Requirements

1. `lib/src/controller/scene_store_controller.dart` no longer imports or
   implements `SceneViewRenderState`.
2. `SceneStoreController` no longer exposes placeholder full-view getters whose
   only purpose was satisfying the removed `SceneViewRenderState` contract:
   committed camera offset, selection rectangle, preview-delta resolver, and
   line/stroke preview getters.
3. No production or test code casts `SceneStoreController` to
   `SceneViewRenderState`, subclasses it to satisfy `SceneViewRenderState`, or
   passes it directly into `SceneViewRenderSurface` or `ScenePainter` as a full
   view render-state provider.
4. Render/view tests that need committed-only full render-state behavior use an
   explicit test support owner and remain green with the same committed render
   and cache-invalidating behavior they currently prove.
5. Guardrails and invariant coverage fail if the controller layer regains a
   `SceneViewRenderState` import or if `SceneStoreController` regains that
   interface role.
6. `ARCHITECTURE.md` and `PLAN.md` describe the resulting architecture
   consistently: the committed store owns committed state and writes, while the
   full view render-state remains on the controller-owned assembled runtime
   path only.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `SceneStoreController` currently imports `scene_view_render_state.dart`,
  implements `SceneViewRenderState`, and returns committed-only placeholder
  values for `selectionRect`, preview delta, and line/stroke preview fields.
- `test/contract/runtime_contract_interfaces_test.dart` currently pins
  `SceneStoreController as SceneViewRenderState` and its committed-only
  placeholder defaults.
- `test/view/scene_view_test.dart` currently passes `SceneStoreController`
  directly into `SceneViewRenderSurface(renderState: controller)`.
- `test/render/scene_painter_frame_contract_test.dart` currently subclasses
  `SceneStoreController` only to satisfy `SceneViewRenderState`.
- `test/render/scene_painter_test.dart` and
  `test/render/scene_static_layer_cache_test.dart` currently pass
  `SceneStoreController` directly into `ScenePainter`.
- The current guardrails surface has no controller-layer rule that rejects
  `SceneViewRenderState` re-entry inside `lib/src/controller/**`.

### 6.2 Target Verification Units

- MCP test runner: `test/contract/runtime_contract_interfaces_test.dart`
- MCP test runner: `test/view/scene_view_test.dart`
- MCP test runner: `test/render/scene_painter_frame_contract_test.dart`
- MCP test runner: `test/render/scene_painter_test.dart`
- MCP test runner: `test/render/scene_static_layer_cache_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`

### 6.3 Protected States, Data, or Structures

- public `SceneController` + `SceneView` integration shape
- `SceneStoreController` committed snapshot/write behavior and existing
  `SceneRenderState` behavior
- current render/cache behavior proven by non-interactive render/view tests
- invariant registry ownership and guardrails execution surface

### 6.4 Allowed Semantic Change Zones

- controller-layer removal of the full committed-only view render-state role
- committed-only render/view test harness migration
- guardrail and invariant enforcement for the removed controller/view seam
- architecture and roadmap wording for the removed mode

### 6.5 Recognition Forms That Must Be Supported Within This Change

- direct `implements SceneViewRenderState` on `SceneStoreController`
- direct controller-layer import of `scene_view_render_state.dart`
- direct cast from `SceneStoreController` to `SceneViewRenderState`
- direct render wiring where `SceneStoreController` is passed into
  `SceneViewRenderSurface` or `ScenePainter`
- subclass-based test render-state providers that extend
  `SceneStoreController` only to satisfy `SceneViewRenderState`

### 6.6 Allowed Forms That Do Not Count as Violations

- `SceneStoreController` remaining consumable as `SceneRenderState`
- test-local `ChangeNotifier`-based helpers that explicitly implement
  `SceneViewRenderState`
- controller-owned assembled runtime code continuing to provide
  `SceneViewRenderState` through
  `SceneControllerSceneViewRenderState`

### 6.7 Requirements for Resolution of Links and Structural Analysis

- Add a dedicated controller-layer guardrail in
  `tool/src/guardrails/controller_api_guardrails.dart` that fails when
  `lib/src/controller/**` imports `scene_view_render_state.dart` or when
  `SceneStoreController` implements `SceneViewRenderState`.
- Add a new invariant entry in `tool/invariant_registry.dart` for the removed
  committed-only full view render-state path using the exact id
  `INV-ENG-CONTROLLER-NO-FULL-VIEW-RENDER-STATE`, with:
  `test/contract/runtime_contract_interfaces_test.dart` as the primary proof,
  `tool/check_guardrails.dart` as the enforcement path, and
  `test/tool/guardrails/guardrails_controller_api_tool_test.dart` as the
  regression path.
- Introduce one shared test support owner in
  `test/support/committed_scene_view_render_state.dart` that implements
  `SceneViewRenderState` explicitly for committed-only test scenarios.
  Its canonical API shape for this step is:
  - one constructor for static committed state:
    `CommittedSceneViewRenderState({required SceneSnapshot snapshot, Set<NodeId> selectedNodeIds = const <NodeId>{}, int controllerEpoch = 0, Offset Function(NodeId nodeId)? previewDeltaResolver, Rect? selectionRect})`
  - one constructor for controller-backed test mirroring:
    `CommittedSceneViewRenderState.mirror(SceneStoreController controller, {Offset Function(NodeId nodeId)? previewDeltaResolver, Rect? selectionRect})`
  The mirror constructor must keep the instance in sync through a listener on
  the supplied `SceneStoreController` instead of relying on
  `SceneStoreController` to satisfy the contract directly.

### 6.8 Prohibited

- introducing a new production committed-only `SceneViewRenderState` adapter
  under `lib/**`
- keeping contract tests that pin `SceneStoreController as SceneViewRenderState`
- preserving test-only subclassing of `SceneStoreController` to regain the
  removed interface role
- reopening the interactive assembled runtime boundary from step `83`

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
9. The plan must be detailed enough that the implementing agent has no
   material branch in how to execute a slice.
10. Every newly proposed file or directory name must comply with the global
    `AGENTS.md` section `### File naming` before the slice is considered valid.
11. If implementation reveals a still-required production dependency on the
    removed committed-only full render-state path outside tests, execution must
    stop and that dependency must be explicitly confirmed before the slice is
    expanded.

## 8. Vertical Slices

### Slice 1. [x] Remove The Controller-Layer Full View Render-State Role

#### Slice Contract

`SceneStoreController` no longer owns the full `SceneViewRenderState` contract,
and the repository’s contract proof surface reflects that removal.

#### Change

Update `lib/src/controller/scene_store_controller.dart` to remove the
`SceneViewRenderState` import and interface implementation. Remove the
placeholder committed-only getters that existed only for that interface:
`cameraOffset`, `selectionRect`, `previewDeltaResolver`, and the line/stroke
preview getters. Keep `controllerEpoch` only as the committed store revision
surface already used by controller internals.

Update `test/contract/runtime_contract_interfaces_test.dart` so it keeps the
`SceneRenderState` contract proof for `SceneStoreController`, removes the
committed-only `SceneViewRenderState` cast/defaults test, and explicitly proves
that the interactive `SceneController` runtime still exposes the full
`SceneViewRenderState` path while `SceneStoreController` does not.

#### Verification

- MCP test runner: `test/contract/runtime_contract_interfaces_test.dart`

#### Positive Scenarios

- `SceneStoreController` is still consumable as `SceneRenderState`, emits
  repaint notifications, and exposes committed snapshot plus selected ids.
- `sceneControllerViewRuntimeOf(SceneController)` still exposes a
  `SceneViewRuntime` whose `renderState` is a `SceneViewRenderState`.

#### Negative Scenarios

- `SceneStoreController` is not a `SceneViewRenderState`.
- The removed contract test no longer pins committed-only placeholder preview
  values on `SceneStoreController`.

#### Closure Evidence

- green run of the listed verification
- updated contract proof that `SceneStoreController` no longer satisfies
  `SceneViewRenderState`

### Slice 2. [x] Migrate Render And View Tests To Explicit Committed Render-State Support

#### Slice Contract

Non-interactive render/view tests no longer rely on `SceneStoreController`
being a full `SceneViewRenderState` provider.

#### Change

Add `test/support/committed_scene_view_render_state.dart` as the shared
committed-only test support owner. It must:

- extend `ChangeNotifier`
- implement `SceneViewRenderState`
- expose committed snapshot, selected ids, controller epoch, and camera offset
- return explicit null/zero values for interactive-only transient fields
- support listener-driven refresh from a `SceneStoreController` for tests that
  verify cache invalidation across controller writes or controller replacement

Rewire:

- `test/view/scene_view_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_test.dart`
- `test/render/scene_static_layer_cache_test.dart`

so they use the shared test support owner instead of passing
`SceneStoreController` directly into `SceneViewRenderSurface` or `ScenePainter`
and instead of subclassing `SceneStoreController` for render-state behavior.

#### Verification

- MCP test runner: `test/view/scene_view_test.dart`
- MCP test runner: `test/render/scene_painter_frame_contract_test.dart`
- MCP test runner: `test/render/scene_painter_test.dart`
- MCP test runner: `test/render/scene_static_layer_cache_test.dart`

#### Fixtures Used

- `test/support/committed_scene_view_render_state.dart`

#### Positive Scenarios

- Render-surface cache invalidation tests still prove epoch-driven cache clear
  behavior after committed controller writes and controller replacement.
- Painter tests still prove committed-only rendering, preview-delta rendering,
  and cache behavior through the explicit test support owner.

#### Negative Scenarios

- `test/view/scene_view_test.dart` no longer passes `SceneStoreController`
  directly as `renderState`.
- `test/render/scene_painter_frame_contract_test.dart` no longer subclasses
  `SceneStoreController` to satisfy `SceneViewRenderState`.
- `test/render/scene_painter_test.dart` and
  `test/render/scene_static_layer_cache_test.dart` no longer construct
  `ScenePainter(controller: controller)` where `controller` is a
  `SceneStoreController`.

#### Closure Evidence

- green run of the listed verifications
- shared committed-only render-state test support owner replaces every direct
  `SceneStoreController` full render-state usage in the targeted tests

### Slice 3. [x] Enforce And Document The Removed Path

#### Slice Contract

The repository mechanically prevents controller-layer return of the removed
committed-only full `SceneViewRenderState` path and records the resulting
architecture in the source of truth.

#### Change

Extend `tool/src/guardrails/controller_api_guardrails.dart` so it rejects:

- any `lib/src/controller/**` import of `scene_view_render_state.dart`
- `SceneStoreController` implementing `SceneViewRenderState`

Add matching negative and positive sandbox coverage in
`test/tool/guardrails/guardrails_controller_api_tool_test.dart`, updating
`test/tool/support/guardrails_tool_test_support.dart` only where needed for the
new controller-layer scaffold.

Add the invariant entry
`INV-ENG-CONTROLLER-NO-FULL-VIEW-RENDER-STATE` to
`tool/invariant_registry.dart` and place the matching `// INV:` marker in
`test/contract/runtime_contract_interfaces_test.dart`.

Update `ARCHITECTURE.md` so it states explicitly that `SceneStoreController`
owns committed store/write/signal responsibilities while the full
`SceneViewRenderState` remains controller-owned on the assembled runtime path.
Update `PLAN.md` and this step file to record the new roadmap item and its
execution contract.

#### Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Fixtures Used

- `test/tool/support/guardrails_tool_test_support.dart`

#### Positive Scenarios

- Controller-layer files pass guardrails without importing
  `scene_view_render_state.dart`.
- The invariant registry and proof markers agree on the removed committed-only
  full render-state path.

#### Negative Scenarios

- A sandbox `SceneStoreController` that implements `SceneViewRenderState`
  fails `check_guardrails.dart`.
- A sandbox controller-layer file that imports `scene_view_render_state.dart`
  fails `check_guardrails.dart`.

#### Closure Evidence

- green run of the listed verifications
- sandbox diagnostics naming the forbidden controller-layer view render-state
  re-entry
- invariant coverage passes with the new proof mapping

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP shard preset `core`
- MCP shard preset `model_contract`
- MCP shard preset `controller_internal`
- MCP shard preset `controller`
- MCP shard preset `render_view`
- MCP shard preset `interactive`
- MCP shard preset `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
