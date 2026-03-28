language: russian

# Шаг 56. Разрезать публичную поверхность `SceneController` на capability owner-ы

## 1. Change Mandate

Этот шаг вводит final public controller shape, где concrete `SceneController`
становится узким runtime entrypoint над capability owner-ами `interaction`,
`selection`, and `scene`, а текущий широкий surface `SceneControllerInteractive`
перестаёт быть архитектурным центром package API.

## 2. Change Boundary

### Included in the Change

- Canonical public controller entrypoint under `lib/src/interactive/`.
- Public capability owner split for interactive config/input/preview,
  selection actions, and committed scene mutation surface.
- View/example rewiring required to consume the new public shape.
- Public exports, docs, guardrails, and public-surface goldens required to pin
  the new API architecture.

### Not Included in the Change

- Reopening `SceneControllerCore`, `InteractiveRuntime`, or draw/eraser-local
  internals as the main subject of the refactor.
- Adding sync glue or duplicated mutable state between root controller and
  capability owner-ы.
- Preserving the old wide public API as a second canonical surface.
- New product behavior outside the API-shape migration itself.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/interactive/scene_controller.dart`
- `lib/src/interactive/scene_controller_interactive.dart`
- `lib/src/interactive/scene_controller_interaction.dart`
- `lib/src/interactive/scene_controller_selection.dart`
- `lib/src/interactive/scene_controller_scene.dart`
- `lib/src/interactive/internal/**`
- `lib/src/view/scene_view_interactive.dart`
- `lib/src/view/scene_view_interactive_overlay_painter.dart`
- `lib/src/view/scene_view_interactive_pointer_host.dart`
- `lib/iwb_canvas_engine.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `DEVELOPMENT_PLAN.md`
- `tool/goldens/public_api_symbols.txt`
- `tool/src/guardrails/public_surface_guardrails.dart`
- `tool/src/guardrails/interactive_api_guardrails.dart`
- `tool/invariant_registry.dart`

### Test Files

- `test/public_api/**`
- `test/entrypoints/**`
- `test/interactive/**`
- `test/view/**`
- `test/tool/guardrails/**`
- `example/test/**`

### Fixture and Supporting Data Files

- `development_plan/step_56_scene_controller_public_capability_split.md`

### Analysis Area

- `lib/src/interactive/**`
- `lib/src/view/**`
- `example/lib/**`
- `tool/src/guardrails/**`
- `test/public_api/**`
- `test/interactive/**`
- `test/view/**`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified public implementation file must either introduce one canonical
  capability owner or remove one residual method cluster from the old wide
  surface.
- Every modified internal file must be tied directly to adapting runtime
  ownership beneath the new public split and must not reopen settled internal
  boundaries.
- Every modified test, guardrail, or golden must pin one aspect of the new
  public capability split.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Concrete public root controller is `SceneController`.
2. `SceneController` remains the primary runtime entrypoint and the only public
   lifecycle/render/event boundary.
3. `SceneControllerInteractive` becomes a non-owning compatibility alias only
   and must not remain the canonical behavior-owning class.
4. Public capability owners are exactly `interaction`, `selection`, and
   `scene`.
5. Committed scene writes remain owned by `SceneControllerCore` internally and
   are exposed publicly through the new `scene` capability owner rather than
   through the root controller.
6. The new public split must not create duplicated mutable state, cross-owner
   synchronization, or parallel notifiers.
7. Metric improvement is evidence only; this step is closed by stable public
   ownership boundaries, not by hitting an arbitrary RFC target.

## 5. Result Requirements

1. `SceneController` is a concrete public class exported from the package and is
   the only canonical public root controller type.
2. Root `SceneController` keeps only:
   committed render state needed by `SceneRenderState`,
   asynchronous integration streams,
   `ChangeNotifier` lifecycle,
   and accessors to `interaction`, `selection`, and `scene`.
3. Public interactive config/input/preview APIs live under
   `SceneController.interaction`.
4. Public selection mutation and transform/delete APIs live under
   `SceneController.selection`.
5. Public committed scene mutation APIs, including the low-level `write(...)`
   transaction surface, live under `SceneController.scene`.
6. `SceneView`, the example app, and public tests consume the new capability
   split instead of the old wide root method surface.
7. Docs, goldens, and guardrails describe and enforce the same canonical public
   shape.
8. Measured hotspot evidence improves from the current confirmed baseline in
   `scene_controller_interactive.dart`:
   `22 imports`,
   `CBO 28`,
   `RFC 115`,
   `WMC 112`;
   any residual hotspot on the root controller must be explained only by its
   render/event boundary role, not by reabsorbed config, selection, or scene
   mutation methods.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `API_GUIDE.md` already documents the current public controller surface in
  separate semantic groups:
  read-only runtime state,
  configuration methods,
  scene/node mutation methods,
  and selection helpers.
- Current `SceneControllerInteractive` still mixes all those groups in one wide
  public class body.
- `SceneViewInteractive`, overlay painting, pointer hosting, tests, and the
  example app all consume the current wide controller surface directly.
- Existing internal interactive runtime owners are already split beneath the
  facade, so the remaining architecture debt is primarily the public API shape.

### 6.2 Target Verification Units

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

### 6.3 Protected States, Data, or Structures

- Single source of truth for committed scene state and interactive runtime
  state.
- Current runtime behavior for pointer handling, preview state, selection
  exclusivity, transform/delete preflight, and scene writes.
- `SceneRenderState` consumption by render/view code.
- Asynchronous `actions`, `editTextRequests`, and listener delivery semantics.
- Existing internal owner graph beneath the public surface unless a direct
  adaptation is required by the new public API shape.

### 6.4 Allowed Semantic Change Zones

- Canonical public root-controller type and package exports.
- Public capability boundaries for interaction, selection, and scene mutation.
- View/example/public-test adaptation to the new capability split.
- Public-surface docs, guardrails, and goldens tied directly to the new shape.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- direct root-method bypass where moved capability APIs remain callable on the
  root controller
- alias-based bypass where `SceneControllerInteractive` keeps the old wide
  public behavior instead of becoming a non-owning compatibility alias
- intermediate-call bypass where a capability owner simply forwards back into
  wide root methods that continue to own the logic
- state-duplication bypass where capability owners maintain their own mutable
  copies and rely on synchronization with the root controller

### 6.6 Allowed Forms That Do Not Count as Violations

- Root `SceneController` delegating render-state reads to shared internal state
  without owning moved capability logic.
- Capability owners sharing one backing controller/runtime state without extra
  listeners or sync glue.
- Compatibility aliasing that preserves symbol availability while keeping
  `SceneController` as the only behavior-owning root type.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- Public capability owner types must live under `lib/src/interactive/`.
- Structural assertions must fail if configuration/input, selection actions, or
  committed scene mutation methods return to the root controller body.
- Public-surface guardrails and symbol goldens must pin `SceneController` as
  canonical and must reject re-expansion of the root method surface.
- Internal interactive guardrails must extend their checks to the new root and
  capability split without weakening existing runtime-boundary constraints.

### 6.8 Prohibited

- Keeping both the old wide root surface and the new capability split as equal
  canonical APIs.
- Leaving `write(...)` on the root controller.
- Adding owner-local caches or synchronization to keep duplicated public state
  in sync across `interaction`, `selection`, `scene`, and the root.
- Moving internal runtime/controller responsibilities upward just to make the
  public split compile.
- Shipping the new public split without synchronized updates to package exports,
  API docs, changelog, and guardrails.

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

### Slice 1. [ ] Canonicalize the public root as `SceneController`

#### Slice Contract

The package has one concrete public root controller type, `SceneController`,
and `SceneControllerInteractive` no longer owns canonical behavior.

#### Change

Introduce `lib/src/interactive/scene_controller.dart` as the concrete public
root, move root behavior ownership there, reduce
`scene_controller_interactive.dart` to compatibility aliasing only, and update
package exports plus public-surface goldens.

#### Verification

- `dart run tool/check_public_api_surface.dart`
- MCP test runner: `test/public_api`
- MCP test runner: `test/entrypoints`

#### Closure Evidence

- Green run of the listed verifications.
- Public symbols and entrypoint tests show `SceneController` as canonical root.

### Slice 2. [ ] Move config, preview, and input APIs under `interaction`

#### Slice Contract

Public mode/tool/color/settings, pointer handling, and preview state no longer
live on the root controller.

#### Change

Create `scene_controller_interaction.dart`, move the public interactive
config/input/preview surface there, and adapt view/overlay/pointer host to
consume `controller.interaction`.

#### Verification

- `dcm calculate-metrics lib/src/interactive lib/src/view --report-all`
- MCP test runner: `test/interactive`
- MCP test runner: `test/view`
- `dart run tool/check_guardrails.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Root controller no longer owns the moved interaction methods and preview
  getters.

### Slice 3. [ ] Move selection APIs under `selection`

#### Slice Contract

External selection mutation and transform/delete helpers no longer live on the
root controller.

#### Change

Create `scene_controller_selection.dart`, move external selection actions there,
and preserve current gesture-exclusivity and transform/delete runtime behavior
through the shared backing owner graph.

#### Verification

- `dcm calculate-metrics lib/src/interactive --report-all`
- MCP test runner: `test/interactive`
- `dart run tool/check_guardrails.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Root controller no longer owns the moved selection methods.

### Slice 4. [ ] Move committed scene mutation APIs under `scene`

#### Slice Contract

Committed scene mutation methods, including transactional `write(...)`, no
longer live on the root controller.

#### Change

Create `scene_controller_scene.dart`, move committed scene mutation helpers and
the low-level transaction surface under `controller.scene`, and adapt example
and public call sites to the new shape.

#### Verification

- `dcm calculate-metrics lib/src/interactive --report-all`
- MCP test runner: `test/interactive`
- MCP test runner: `example/test` with root `example/`
- `dart run tool/check_public_api_surface.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Root controller no longer exposes `write(...)` or scene mutation helpers
  directly.

### Slice 5. [ ] Pin the final capability split in docs, guardrails, and baseline

#### Slice Contract

The new public capability architecture is documented, guarded, and measured as
the final controller shape.

#### Change

Update `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`,
guardrails, invariants, and final baseline evidence so the repo enforces the
capability split as the only accepted public controller architecture.

#### Verification

- `dcm calculate-metrics lib/src/interactive lib/src/view --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/tool/guardrails`

#### Closure Evidence

- Green run of the listed verifications.
- Docs, guardrails, and metrics all describe the same final public shape.

## 9. Final Verification

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
