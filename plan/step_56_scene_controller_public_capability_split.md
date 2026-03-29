language: russian

# Шаг 56. Сделать `SceneController` единственным public root и разрезать API по capability owner-ам

## 1. Change Mandate

Этот шаг удаляет legacy public facade `SceneControllerInteractive` и вводит
final controller architecture, в которой concrete `SceneController` является
единственным public root над capability owner-ами `interaction`,
`selection` и `scene`.

## 2. Change Boundary

### Included in the Change

- Canonical public controller root under `lib/src/interactive/`.
- Удаление `SceneControllerInteractive` из production code и public API.
- Public capability split для interactive config/input/preview, selection
  mutation surface и committed scene mutation surface.
- Rewiring view/example/test code, необходимый для потребления новой public
  формы.
- Public exports, docs, guardrails, invariants и public-surface goldens,
  которые должны зафиксировать новую controller architecture.

### Not Included in the Change

- Reopening `SceneControllerCore`, `InteractiveRuntime`, draw-local и
  eraser-local internal topology как самостоятельной цели рефактора.
- New product behavior вне migration на новую public controller surface.
- Any sync glue, duplicated mutable state, parallel notifiers или bridge
  layers между root и capability owner-ами.
- Preserving `SceneControllerInteractive` через alias, wrapper,
  deprecation layer или secondary public surface.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/interactive/scene_controller.dart`
- `lib/src/interactive/scene_controller_interactive.dart`
- `lib/src/interactive/scene_controller_interaction.dart`
- `lib/src/interactive/scene_controller_selection.dart`
- `lib/src/interactive/scene_controller_scene.dart`
- `lib/src/interactive/internal/scene_controller_interactive_internal_access.dart`
- `lib/src/contract/canvas_pointer_input.dart`
- `lib/src/view/scene_view_interactive.dart`
- `lib/src/view/scene_view_interactive_overlay_painter.dart`
- `lib/src/view/scene_view_interactive_pointer_host.dart`
- `lib/src/view/scene_view_render_surface.dart`
- `lib/iwb_canvas_engine.dart`
- `example/lib/**`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `PLAN.md`
- `tool/goldens/public_api_symbols.txt`
- `tool/src/guardrails/public_surface_guardrails.dart`
- `tool/src/guardrails/interactive_api_guardrails.dart`
- `tool/invariant_registry.dart`

### Test Files

- `test/public_api/**`
- `test/entrypoints/**`
- `test/interactive/**`
- `test/interactive/test_support/interactive_controller_fixtures.dart`
- `test/view/**`
- `test/tool/guardrails/**`
- `test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`
- `test/tool/support/public_entrypoint_contract.dart`
- `test/tool/support/guardrails_tool_test_support.dart`
- `example/test/**`

### Fixture and Supporting Data Files

- `plan/step_56_scene_controller_public_capability_split.md`

### Analysis Area

- `lib/src/interactive/**`
- `lib/src/view/**`
- `lib/src/contract/canvas_pointer_input.dart`
- `example/lib/**`
- `tool/src/guardrails/**`
- `tool/goldens/**`
- `tool/invariant_registry.dart`
- `test/public_api/**`
- `test/entrypoints/**`
- `test/interactive/**`
- `test/view/**`
- `test/tool/**`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must either introduce the canonical
  `SceneController` root, introduce one canonical capability owner, delete one
  residual `SceneControllerInteractive` dependency, or adapt a direct consumer
  to the new capability boundary.
- Every modified test, guardrail, golden, or invariant proof must pin one
  aspect of the new root-only public controller architecture.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `SceneController` is the only public runtime controller symbol exported by
   the package.
2. `SceneControllerInteractive` is removed from production code and public API;
   alias, wrapper, subclass shim, typedef shim, re-export, and deprecation
   layer are not allowed end-states for this step.
3. Root `SceneController` remains the only public `ChangeNotifier`,
   `SceneRenderState`, and action/event stream boundary.
4. The only public capability accessors on the root are `interaction`,
   `selection`, and `scene`.
5. Committed scene writes remain internally owned by `SceneControllerCore` and
   are surfaced publicly only through `controller.scene`, including the
   low-level `write(...)` transaction surface.
6. All public owners share one backing runtime/core state; duplicated mutable
   state, cross-owner synchronization, and parallel notifiers are forbidden.
7. Metric and clone cleanup counts only when it comes from real ownership
   transfer or legacy deletion; helper indirection and compatibility layers do
   not count as valid closure.

## 5. Result Requirements

1. `lib/iwb_canvas_engine.dart` exports `SceneController` and does not export
   `SceneControllerInteractive`.
2. No production file under `lib/src/**` defines a public top-level
   `SceneControllerInteractive` symbol, and
   `lib/src/interactive/scene_controller_interactive.dart` does not remain in
   the production tree as a legacy compatibility layer.
3. Positive public docs, example code, package exports, symbol goldens,
   canonical entrypoint manifests, and positive tests no longer refer to
   `SceneControllerInteractive`.
4. Root `SceneController` does not expose mode/tool/color/settings APIs,
   preview getters, selection mutation helpers, committed scene mutation
   helpers, or `write(...)`.
5. Root `SceneController` exposes only the committed render state required by
   `SceneRenderState`, action/event streams, `ChangeNotifier` lifecycle, and
   access to `interaction`, `selection`, and `scene`.
6. Public mode/tool/color/settings, pointer handling, and preview state live
   under `controller.interaction`.
7. Public selection mutation and transform/delete helpers live under
   `controller.selection`.
8. Public committed scene mutation APIs, including `write(...)`, live under
   `controller.scene`.
9. New or substantially rewritten production files introduced by this step are
   green against the current metric thresholds, and the previous
   `SceneControllerInteractive` hotspot no longer exists in the production
   metrics baseline.
10. Clone analysis for `lib/` does not report new controller-split clusters
    whose only purpose is forwarding, aliasing, or compatibility preservation.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `lib/iwb_canvas_engine.dart` currently exports
  `src/interactive/scene_controller_interactive.dart` and exposes both
  `SceneController` and `SceneControllerInteractive`.
- `API_GUIDE.md` currently states that `SceneController` is a typedef alias of
  `SceneControllerInteractive`.
- `SceneControllerInteractive` currently mixes committed render state,
  interactive config/input/preview state, selection mutation surface,
  committed scene mutation surface, and `write(...)` in one public class body.
- `tool/src/guardrails/public_surface_guardrails.dart` currently special-cases
  `scene_controller_interactive.dart` because `SceneController` mirrors the
  same surface through aliasing.
- `test/tool/support/public_entrypoint_contract.dart`,
  `tool/goldens/public_api_symbols.txt`, view code, interactive tests, and the
  example app currently pin or consume `SceneControllerInteractive`.
- `lib/src/interactive/internal/scene_controller_interactive_internal_access.dart`
  currently encodes legacy symbol ownership and must be removed or renamed as
  part of the migration to the new root-only shape.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib --report-all`
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
- Current runtime semantics for pointer handling, preview ephemerality,
  selection exclusivity, transform/delete preflight, and committed scene
  mutation.
- `SceneRenderState` consumption by render/view code.
- Action/event stream delivery through `actions` and `editTextRequests`.
- `MoveCommitDeltaResolver` purity boundary and other existing public-side
  effect guards that prevent resolver re-entry into stateful controller APIs.

### 6.4 Allowed Semantic Change Zones

- Canonical public controller type and package export ownership.
- Public capability boundaries for interaction, selection, and committed scene
  mutation.
- Internal access wiring only where required to keep one backing runtime/core
  state under the new root.
- View/example/public-test adaptation to the new capability split.
- Docs, guardrails, invariants, goldens, and metric/clone baseline closure tied
  directly to the final controller architecture.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- direct root-method bypass where moved APIs remain callable on the root
- typedef-alias bypass where `SceneControllerInteractive` survives as an alias
- subclass-wrapper bypass where `SceneControllerInteractive` survives as a thin
  wrapper around the new root
- re-export bypass where `SceneControllerInteractive` remains reachable through
  another public export path
- intermediate-call bypass where capability owners forward into wide root
  methods that still own the logic
- state-duplication bypass where capability owners maintain mutable copies and
  rely on synchronization with the root

### 6.6 Allowed Forms That Do Not Count as Violations

- Root `SceneController` delegating read-only render-state and stream access to
  shared backing state without owning moved capability logic.
- Capability owners delegating into shared internal runtime/core state without
  owning separate mutable state or a separate notifier graph.
- Negative guardrail, import-boundary, or tool fixtures mentioning
  `SceneControllerInteractive` only to assert rejection or historical drift.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- The package entrypoint and
  `test/tool/support/public_entrypoint_contract.dart` must resolve the
  canonical controller export owner to `scene_controller.dart` instead of
  `scene_controller_interactive.dart`.
- `tool/goldens/public_api_symbols.txt` must not contain
  `SceneControllerInteractive`.
- `tool/src/guardrails/public_surface_guardrails.dart` must stop using the
  alias-based targeted skip for the controller export and must not keep
  `SceneControllerInteractive` in mutable runtime type allowlists.
- Interactive architecture guardrails and
  `INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY` proof coverage must pin the new
  root-plus-capability boundary rather than the deleted facade file.

### 6.8 Prohibited

- Any production or public-API alias, wrapper, subclass, typedef, re-export,
  or deprecation shim for `SceneControllerInteractive`.
- Keeping both the old wide root surface and the new capability split as
  parallel supported APIs.
- Leaving `write(...)` or any other moved capability API on the root
  controller.
- Leaving legacy-named controller support files whose only purpose is to keep
  the removed symbol alive.
- Introducing duplicated mutable state, cross-owner synchronization, or bridge
  layers between root and capability owners.
- Claiming metric or clone improvement through forwarding helpers, cosmetic
  signature reshaping, or wrapper-only refactors.
- Shipping the new controller architecture without synchronized updates to
  exports, docs, changelog, goldens, guardrails, and invariant coverage.

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

### Slice 1. [ ] Canonicalize `SceneController` and delete the legacy symbol

#### Slice Contract

The package has one public runtime controller symbol, `SceneController`, and
`SceneControllerInteractive` no longer exists in production code or public API.

#### Change

Introduce `lib/src/interactive/scene_controller.dart` as the concrete root,
delete the legacy public facade symbol from
`lib/src/interactive/scene_controller_interactive.dart`, remove or rename
legacy symbol-bound internal-access wiring, and update the package barrel,
public-entrypoint manifest, and public-symbol golden.

#### Verification

- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- MCP test runner: `test/public_api test/entrypoints`

#### Fixtures Used

- `test/tool/support/public_entrypoint_contract.dart`
- `tool/goldens/public_api_symbols.txt`

#### Closure Evidence

- Green run of the listed verifications.
- The exported public controller symbol set contains `SceneController` and does
  not contain `SceneControllerInteractive`.

### Slice 2. [ ] Move interaction config, input, and preview under `interaction`

#### Slice Contract

Mode/tool/color/settings APIs, pointer handling, and preview state no longer
live on the root controller.

#### Change

Introduce the canonical interaction capability owner under
`lib/src/interactive/`, move the public interaction surface there, adapt view
consumers to `controller.interaction`, and update direct symbol references such
as the `CanvasPointerInput` API doc comment.

#### Verification

- `dcm calculate-metrics lib --report-all`
- `dart run tool/check_guardrails.dart`
- MCP test runner: `test/interactive`
- MCP test runner: `test/view`

#### Closure Evidence

- Green run of the listed verifications.
- Root `SceneController` no longer owns the moved interaction APIs.

### Slice 3. [ ] Move selection mutation APIs under `selection`

#### Slice Contract

External selection mutation and transform/delete helpers no longer live on the
root controller.

#### Change

Introduce the canonical selection capability owner under
`lib/src/interactive/`, move the public selection surface there, and preserve
existing gesture-exclusivity and transform/delete behavior through the shared
backing runtime/core state.

#### Verification

- `dcm calculate-metrics lib --report-all`
- `dart run tool/check_guardrails.dart`
- MCP test runner: `test/interactive`

#### Closure Evidence

- Green run of the listed verifications.
- Root `SceneController` no longer owns the moved selection APIs.

### Slice 4. [ ] Move committed scene mutations and `write(...)` under `scene`

#### Slice Contract

Committed scene mutation helpers and the transactional `write(...)` surface no
longer live on the root controller.

#### Change

Introduce the canonical scene capability owner under `lib/src/interactive/`,
move committed scene mutation APIs and `write(...)` there, and adapt example
and public call sites to `controller.scene`.

#### Verification

- `dcm calculate-metrics lib --report-all`
- `dart run tool/check_public_api_surface.dart`
- MCP test runner: `test/interactive`
- MCP test runner: `example/test` with root `example/`

#### Closure Evidence

- Green run of the listed verifications.
- Root `SceneController` no longer exposes `write(...)` or committed scene
  mutation helpers.

### Slice 5. [ ] Close the final controller architecture in docs, guardrails, and baseline

#### Slice Contract

The repo documents, guards, and measures only the final root-plus-capability
controller architecture, with no positive legacy references.

#### Change

Update `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`,
guardrails, invariant coverage, clone/metric baseline evidence, and positive
fixtures so the repo enforces the final `SceneController` architecture and no
longer documents or blesses `SceneControllerInteractive`.

#### Verification

- `dcm calculate-metrics lib --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/tool/guardrails`

#### Closure Evidence

- Green run of the listed verifications.
- Docs, guardrails, invariant proofs, and baseline artifacts all describe the
  same final controller architecture.

## 9. Final Verification

- `dcm calculate-metrics lib --report-all`
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
