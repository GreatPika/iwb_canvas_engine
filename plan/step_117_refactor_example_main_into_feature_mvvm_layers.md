language: english

# Change Contract

## 1. Change Mandate

This change refactors `example/lib/main.dart` into a feature-scoped MVVM example structure so the shipped example stays a direct witness of the public `iwb_canvas_engine` API while aligning with Flutter's app-architecture guidance on separation of concerns, view/view-model pairing, dependency boundaries, and testability.

## 2. Change Boundary

### Included in the Change

- Splitting the current `example/lib/main.dart` responsibilities into:
  - a composition root and app shell;
  - one feature view;
  - one feature view model;
  - one example-owned data service for sample image loading.
- Preserving the current example feature set:
  - `SceneView` rendering;
  - draw and move controls;
  - inline text editing;
  - camera/grid/background controls;
  - JSON export/import;
  - sample object insertion with the cat image.
- Preserving the constructor injection seam used by tests:
  `CanvasExampleApp(controller: ...)`.
- Adding example-side behavioral and structural tests that lock the new owner
  boundaries.

### Not Included in the Change

- Any modification to package production code under `lib/**`.
- Any change to the public package surface, public docs, or package runtime
  semantics.
- Converting the example into a reusable starter architecture or multi-screen
  app shell.
- Adding a global dependency-injection/state-management package such as
  `provider` for this step.
- Adding persistence, routing, or new example capabilities beyond the current
  demo contract.

## 3. Surrounding Code Review

### Inspected Artifacts

- `example/lib/main.dart` — current owner; one 1400+ line file where
  `_CanvasExampleScreenState` owns app composition, controller lifecycle,
  stream subscription, widget composition, dialogs, asset decode, sample node
  generation, text-edit orchestration, and overlay geometry.
- `example/test/widget_test.dart` — current behavioral proof that the example
  renders and that an outside tap closes inline text editing while saving the
  updated text.
- `example/README.md` — locks the example's role as a manual integration demo
  for the public runtime API rather than a reusable UI template.
- `test/entrypoints/example_public_api_contract_test.dart` — locks the example
  to `package:iwb_canvas_engine/iwb_canvas_engine.dart` and forbids imports of
  internal package entrypoints.
- `lib/src/interactive/scene_controller.dart` — shows that `SceneController`
  is already the public `ChangeNotifier` integration surface and that command
  responsibilities are split into `interaction`, `selection`, and `scene`
  capability owners.
- `AGENTS.md` — package boundary explicitly says the package does not own app
  UI or product workflows, so the refactor must stay inside `example/**`.
- `tool/src/verification_contract/verification_contract_registry.dart` —
  proves `scope_example` runs `flutter test --no-pub test` inside `example`,
  so example-side tests are part of the repository verification contract.
- Flutter app architecture guide
  (`https://docs.flutter.dev/app-architecture/guide`) — locks the view /
  view-model split, one feature = one view + one view model, and "views stay
  light, logic lives outside widgets" guidance.
- Flutter architecture recommendations
  (`https://docs.flutter.dev/app-architecture/recommendations`) — locks
  separation of concerns, dependency injection, `ChangeNotifier` / `Listenable`
  suitability, component-specific tests, and naming/layout guidance.
- Flutter architecture case study
  (`https://docs.flutter.dev/app-architecture/case-study`) — gives the closest
  upstream package-structure precedent for `ui/<feature>/view_models` and
  `ui/<feature>/widgets` without forcing a larger application stack than this
  example needs.

### Current Entry Path

- `main()` creates `CanvasExampleApp`.
- `CanvasExampleApp.build(...)` creates `CanvasExampleScreen` directly from
  `main.dart`.
- `_CanvasExampleScreenState.initState()` either creates a `SceneController` or
  adopts an injected one, subscribes to `editTextRequests`, and starts sample
  image loading.
- `_CanvasExampleScreenState.build(...)` creates the full widget tree and wires
  user actions directly to `_controller.interaction`, `_controller.selection`,
  `_controller.scene`, codec helpers, and asset-loading helpers.
- Inline text edit events enter through
  `_controller.editTextRequests.listen(_beginInlineTextEdit)` and patch scene
  state directly from the widget state object.

### Current Owner

- `example/lib/main.dart`, specifically `_CanvasExampleScreenState`, is the
  single owner for nearly all example presentation, orchestration, and data
  loading concerns.

### Adjacent Abstractions

- `SceneController` and its public capability owners:
  `SceneControllerInteraction`, `SceneControllerSelection`,
  `SceneControllerScene`.
- `SceneView` with `imageResolver`.
- `EditTextRequested` asynchronous stream.
- Public snapshot/patch/spec/codec helpers such as `SceneSnapshot`,
  `TextNodePatch`, `RectNodeSpec`, `TextNodeSpec`, `ImageNodeSpec`,
  `encodeSceneToJson(...)`, and `decodeSceneFromJson(...)`.
- Flutter-owned view objects: `TextEditingController`, `FocusNode`, dialogs,
  and `ScaffoldMessenger`.
- External asset APIs: `rootBundle.load(...)` and `ui.instantiateImageCodec(...)`.

### Existing Tests

- `example/test/widget_test.dart` — proves app render and the outside-tap text
  edit dismissal/save path.
- `test/entrypoints/example_public_api_contract_test.dart` — proves example
  code imports only the public package entrypoint.
- No dedicated example view-model tests, service tests, or architecture tests
  exist today.

### Analogous Implementation Path

- `lib/src/interactive/scene_controller.dart` together with
  `lib/src/interactive/scene_controller_interaction.dart`,
  `lib/src/interactive/scene_controller_selection.dart`, and
  `lib/src/interactive/scene_controller_scene.dart` — the repository already
  uses focused capability owners instead of letting every caller reach into one
  lower-level mutable owner. The example refactor should apply the same idea at
  the app-feature boundary: widgets call one dedicated owner instead of
  scattering engine mutations across the view tree.

### Governing Repository Rules

- `AGENTS.md` product boundary — app UI and workflows belong in `example/**`,
  not package production code.
- `test/entrypoints/example_public_api_contract_test.dart` — example code may
  import only `package:iwb_canvas_engine/iwb_canvas_engine.dart`.
- `tool/src/verification_contract/verification_contract_registry.dart` —
  example-side tests and analysis are already part of the required repository
  verification preset.
- Flutter app architecture guide and recommendations — views contain only
  simple UI/layout logic; view models own presentation logic and commands;
  services own external data access; components should be tested separately and
  together.

### Rejected Misleading Local Patterns

- Private helper extraction inside `example/lib/main.dart` only — wrong seam
  because owner boundaries do not change and logic still lives in the view.
- Moving example orchestration into package `lib/**` or `lib/src/**` — wrong
  owner because the package explicitly does not own app UI/workflow logic.
- Wrapping all `iwb_canvas_engine` calls in a full repository/domain/provider
  stack — wrong level for a single-feature integration witness and would hide
  the public API the example is supposed to demonstrate.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- UI/presentation orchestration for one shipped example feature, with one
  external data-service seam for asset loading.

#### Selected Architectural Form

- `example/lib/main.dart` stays the composition root and app shell only:
  `main()`, `CanvasExampleApp`, theme, and feature wiring.
- `CanvasExampleScreen` is the feature view. It renders the widget tree,
  presents dialogs/snackbars, owns widget-only objects such as
  `TextEditingController` and `FocusNode`, and delegates every scene-changing
  action to one feature owner.
- `CanvasExampleViewModel extends ChangeNotifier` is the single feature owner
  paired 1:1 with `CanvasExampleScreen`. It owns:
  - controller lifecycle when the controller is not injected;
  - rebroadcast of controller changes for the feature view;
  - `editTextRequests` subscription;
  - example UI state derived from the controller;
  - example command methods for draw/move, camera/grid/background controls,
    selected-text mutations, JSON export/import orchestration, and sample node
    insertion;
  - sample image state and the public `imageResolver` callback used by
    `SceneView`.
- `SampleImageAssetService` is the only data/service owner in this refactor.
  It resolves the sample image asset using the current fallback keys and
  decodes it into `ui.Image`.
- `SceneController` remains the engine model and public mutation boundary. The
  example does not create a second repository layer that mirrors the package's
  public API.
- Feature widgets are split by UI region under
  `example/lib/ui/canvas_example/widgets/**`. They receive view-model state and
  callbacks only. The only widget allowed to instantiate `SceneView` is the
  dedicated scene-surface adapter.

#### Owning Layer or Module

- `example/lib/ui/canvas_example/**` for the view and view-model layer.
- `example/lib/data/services/sample_image_asset_service.dart` for external
  asset loading and decode.

#### Dependency Direction

- `example/lib/main.dart -> ui/canvas_example/widgets ->
  ui/canvas_example/view_models -> data/services`.
- `CanvasExampleViewModel -> package:iwb_canvas_engine/iwb_canvas_engine.dart`
  public API.
- `canvas_scene_surface.dart` may depend on the public package entrypoint only
  to render `SceneView`.
- Forbidden reverse edges:
  - widget files importing data services directly;
  - widget files mutating the engine through `controller.scene`,
    `controller.selection`, or `controller.interaction`;
  - any example file importing `package:iwb_canvas_engine/src/**`.

#### State and Data Ownership

- `SceneController` and its capability owners remain the authoritative owner of
  scene/runtime state.
- `CanvasExampleViewModel` owns example-specific presentation state and the
  injected-vs-owned controller lifetime rule.
- `CanvasExampleScreenState` owns only widget-local editing objects and dialog
  presentation state synchronized from the view model.
- `SampleImageAssetService` owns asset lookup and image decode.

#### Entry and Exit Boundaries

- User events enter the feature through widget callbacks into
  `CanvasExampleViewModel` commands.
- `EditTextRequested` enters the feature through `CanvasExampleViewModel`.
- Asset bytes and image decode enter through `SampleImageAssetService`.
- Render data exits the feature through view-model getters, the
  `SceneController` passed to `SceneView`, and pure callback props passed into
  child widgets.
- Dialog/snackbar presentation remains in the view; the view consumes return
  values and errors from view-model commands but does not perform scene logic.

#### Permitted Extension Seam

- New example behaviors extend `CanvasExampleViewModel` with new commands and
  derived getters.
- New example-owned external I/O must enter through
  `example/lib/data/services/**`.
- New UI regions attach under `example/lib/ui/canvas_example/widgets/**`
  without gaining direct engine mutation logic.

#### Rejected Alternatives

- Keep one giant `StatefulWidget` and extract only smaller widgets — rejected
  because the real problem is owner concentration, not line wrapping.
- Introduce `provider`, a global dependency container, or a wider repository /
  domain layer in this step — rejected because the example is still one feature
  with an existing constructor-injection seam, and the added indirection would
  be disproportionate to the current owner problem.
- Move `TextEditingController` and `FocusNode` into the view model — rejected
  because they are widget-owned presentation objects, not feature logic.

#### Why This Level Is Correct

- The defect is example-side ownership drift, not package engine behavior. A
  feature-scoped view/view-model boundary fixes that once at the UI layer,
  keeps the example a clear witness of the public package API, and stays
  proportional to a one-screen demo while following Flutter's recommended
  architectural split.

## 5. File Map

### Implementation Files

- `example/lib/main.dart`
- `example/lib/data/services/sample_image_asset_service.dart`
- `example/lib/ui/canvas_example/view_models/canvas_example_view_model.dart`
- `example/lib/ui/canvas_example/widgets/canvas_example_screen.dart`
- `example/lib/ui/canvas_example/widgets/canvas_scene_surface.dart`
- `example/lib/ui/canvas_example/widgets/canvas_controls_dock.dart`
- `example/lib/ui/canvas_example/widgets/canvas_text_options_panel.dart`
- `example/lib/ui/canvas_example/widgets/canvas_text_edit_overlay.dart`

### Test Files

- `example/test/widget_test.dart`
- `example/test/data/services/sample_image_asset_service_test.dart`
- `example/test/ui/canvas_example/canvas_example_view_model_test.dart`
- `example/test/ui/canvas_example/canvas_example_architecture_test.dart`
- `test/entrypoints/example_public_api_contract_test.dart`

### Fixtures and Supporting Data

- None.

### Analysis Area

- `example/lib/**`
- `example/test/**`
- `test/entrypoints/example_public_api_contract_test.dart`
- `AGENTS.md`
- `tool/src/verification_contract/verification_contract_registry.dart`

### File Rules

- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified fixture must be tied to a specific verification.
- Every proposed path must follow the global `File naming`.
- Untied changes are out of scope.

## 6. Locked Decisions

1. `example/lib/main.dart` becomes bootstrap/app-shell wiring only; it must not
   keep controller mutations, asset decoding, JSON codec orchestration, or
   inline text-edit ownership.
2. One `CanvasExampleScreen` / `CanvasExampleViewModel` pair is the only new
   feature boundary introduced in this step.
3. Constructor injection through `CanvasExampleApp(controller: ...)` is
   preserved and remains the primary test seam.
4. The example continues to depend only on
   `package:iwb_canvas_engine/iwb_canvas_engine.dart`; no package-internal
   imports are introduced.
5. `CanvasExampleViewModel` owns the injected-vs-owned controller disposal
   policy: injected controllers are never disposed by the example; internally
   created controllers are disposed by the example.
6. `SampleImageAssetService` is the only owner of `rootBundle` lookup and
   `instantiateImageCodec(...)` image decode.
7. Widget files may present dialogs/snackbars and own text-field focus/control
   objects, but they must not perform scene mutation logic directly.
8. The only widget allowed to instantiate `SceneView` is the dedicated
   scene-surface adapter.
9. Architecture drift is enforced mechanically by example-side structure tests
   plus the existing root example public-entrypoint contract.

## 7. Result Requirements

1. `example/lib/main.dart` contains only app bootstrap, theme, and feature
   wiring for the example app.
2. All current example scene mutations route through `CanvasExampleViewModel`
   commands rather than through widget methods.
3. Sample image asset lookup and image decode occur only through
   `SampleImageAssetService`.
4. The example preserves its current public behaviors: rendering, move/draw
   controls, inline text editing, camera/grid/background controls, JSON
   export/import, and sample object insertion.
5. `CanvasExampleApp(controller: injectedController)` remains supported and does
   not transfer disposal ownership to the example.
6. Example-side tests cover the feature view model, the asset service, and the
   screen/widget regression path.
7. Architecture drift back into `main.dart` or widget files fails mechanically.
8. Example code continues to satisfy the existing public-entrypoint contract.

## 8. Implementation Rules

### Analysis Scope

- Refactor only example-side ownership and file layout around the current
  feature set.
- Preserve the current public `iwb_canvas_engine` call surface used by the
  example unless a change is explicitly locked in this contract.
- Treat this as a maintainability refactor, not as a feature expansion.

### Target Verification Units

- Example screen/widget behavior.
- Example feature view-model state and commands.
- Sample image asset service behavior.
- Example architecture owner-file contract.
- Existing root public-entrypoint contract.

### Protected States, Data, or Structures

- Injected vs internally-created controller ownership semantics.
- `canvas-example-text-edit-dismiss-overlay` widget key.
- `editTextRequests` asynchronous subscription lifecycle.
- `lastExportedJson` reuse for the import dialog.
- Monotonic sample/node seed progression and the `sample-cat` image id.
- Selected-text patch behavior, including line-height preservation when font
  size changes.
- Current sample image asset fallback keys.

### Allowed Semantic Change Zones

- Example file organization.
- Distribution of example logic between screen, view model, and service.
- Dialog presentation plumbing and callback wiring.
- Naming and placement of feature-private widgets/helpers.

### Structural Enforcement

- `example/test/ui/canvas_example/canvas_example_architecture_test.dart`
  enforces owner-file allow-lists over example source files.
- That test must fail when any of the following drifts occur:
  - `example/lib/main.dart` contains `SceneController(`, `controller.scene`,
    `controller.selection`, `controller.interaction`, `encodeSceneToJson`,
    `decodeSceneFromJson`, `rootBundle.load`, `instantiateImageCodec`,
    `RectNodeSpec`, `TextNodeSpec`, `ImageNodeSpec`, or `TextNodePatch`.
  - Any widget file under
    `example/lib/ui/canvas_example/widgets/**` contains direct engine mutation
    tokens such as `controller.scene`, `controller.selection`,
    `controller.interaction`, `encodeSceneToJson`, `decodeSceneFromJson`, or
    `TextNodePatch`.
  - Any file other than
    `example/lib/data/services/sample_image_asset_service.dart` contains
    `rootBundle.load` or `instantiateImageCodec`.
  - Any file other than
    `example/lib/ui/canvas_example/widgets/canvas_scene_surface.dart`
    instantiates `SceneView(`.
- `test/entrypoints/example_public_api_contract_test.dart` remains the root
  structural proof that example code imports only the public package barrel.

### Required Test Strategy

- `example/test/data/services/sample_image_asset_service_test.dart`
  - package-asset success path;
  - local-asset fallback path;
  - total failure path.
- `example/test/ui/canvas_example/canvas_example_view_model_test.dart`
  - internally-created controller is disposed by the view model;
  - injected controller is not disposed by the view model;
  - `EditTextRequested` starts an edit session and hides the target node until
    commit/cancel;
  - selected-text formatting commands patch the correct nodes;
  - export returns the current scene JSON;
  - import applies a decoded scene and reports invalid JSON failures without
    corrupting the current state;
  - sample insertion adds the expected node types with monotonic ids.
- `example/test/widget_test.dart`
  - app still renders from `CanvasExampleApp(controller: ...)`;
  - outside tap still closes inline text editing and persists updated text.
- `example/test/ui/canvas_example/canvas_example_architecture_test.dart`
  - owner-file structural assertions described above.
- `test/entrypoints/example_public_api_contract_test.dart`
  - existing root structural regression remains green.

### Prohibited

- Direct widget-owned calls to `controller.scene`, `controller.selection`, or
  `controller.interaction`.
- Any import of `package:iwb_canvas_engine/src/**`.
- Introducing a global singleton container or `provider` dependency in this
  refactor.
- Moving example UI/workflow logic into package `lib/**`.
- Asset decode or bundle lookup outside `SampleImageAssetService`.
- Reimplementing engine behavior in example helper classes.
- Shipping the refactor without mechanical architecture checks.

## 9. Vertical Slices

### Slice 1. [x] Establish the composition root and feature view-model boundary

#### Slice Contract

`example/lib/main.dart` becomes app-shell wiring only, and one
`CanvasExampleViewModel` owns controller lifetime and the feature's command
surface.

#### Change

- Move `CanvasExampleScreen` out of `example/lib/main.dart` into
  `example/lib/ui/canvas_example/widgets/canvas_example_screen.dart`.
- Create
  `example/lib/ui/canvas_example/view_models/canvas_example_view_model.dart`.
- Move controller creation, injected-vs-owned lifetime tracking, controller
  change rebroadcast, and the current feature command surface out of the widget
  state object and into the view model.
- Keep `CanvasExampleApp(controller: ...)` as the feature-composition seam.

#### Behavioral Verification

- `example/test/ui/canvas_example/canvas_example_view_model_test.dart` —
  internally-created controller is disposed by the view model.
- `example/test/ui/canvas_example/canvas_example_view_model_test.dart` —
  injected controller is never disposed by the view model.
- `example/test/widget_test.dart` — `CanvasExampleApp(controller: ...)`
  still renders the example screen.

#### Structural Verification

- `example/test/ui/canvas_example/canvas_example_architecture_test.dart` —
  `main.dart` contains no engine mutation, codec, asset-loading, or node-spec
  owner tokens.

#### Fixtures Used

- None.

#### Positive Scenarios

- App bootstraps from `main.dart` without creating a second feature owner.
- Tests can still inject a controller from the app constructor.

#### Negative Scenarios

- Internal controller ownership does not leak after dispose.
- Injected controller disposal does not regress to widget/view-model ownership.

#### Closure Evidence

- green run of the listed behavioral verifications;
- green run of the listed structural verifications;
- no remaining controller-creation or controller-mutation owner tokens in
  `example/lib/main.dart`.

### Slice 2. [x] Move inline text editing and selected-text commands to the view-model/view boundary

#### Slice Contract

Inline text-edit orchestration and selected-text mutation commands live in the
view model, while widget-local text-field objects stay in the view.

#### Change

- Move edit-session ownership, selected-text discovery, selected-text patching,
  and text-style command methods out of the widget state object and into
  `CanvasExampleViewModel`.
- Keep `TextEditingController`, `FocusNode`, text measurement, and overlay
  positioning/rendering in the view layer.
- Create
  `example/lib/ui/canvas_example/widgets/canvas_text_edit_overlay.dart` and
  `example/lib/ui/canvas_example/widgets/canvas_text_options_panel.dart` as
  the widget owners for edit/render logic.

#### Behavioral Verification

- `example/test/ui/canvas_example/canvas_example_view_model_test.dart` —
  `EditTextRequested` opens an edit session and hides the node until
  commit/cancel.
- `example/test/ui/canvas_example/canvas_example_view_model_test.dart` — font
  size changes preserve line-height ratio for nodes that already have an
  explicit line height.
- `example/test/widget_test.dart` — outside tap still closes inline text edit
  and saves the updated text.

#### Structural Verification

- `example/test/ui/canvas_example/canvas_example_architecture_test.dart` —
  `TextNodePatch` and direct `controller.scene` / `controller.selection` /
  `controller.interaction` tokens appear only in the view-model owner file.

#### Fixtures Used

- None.

#### Positive Scenarios

- Text style toggles, alignment, color, font size, and line-height updates are
  still available from the selected-text panel.
- Edit overlay still appears over the selected text node and requests focus.

#### Negative Scenarios

- Switching away from move mode while editing does not leave a hidden text node
  behind.
- A stale or missing text node id does not crash the edit-session cleanup path.

#### Closure Evidence

- green run of the listed behavioral verifications;
- green run of the listed structural verifications;
- no remaining text-edit mutation logic in feature widget files.

### Slice 3. [x] Extract asset loading, JSON orchestration, and sample-node insertion out of widgets

#### Slice Contract

External asset loading and data-facing example commands stop living in widgets
and are owned by the service/view-model boundary.

#### Change

- Create `example/lib/data/services/sample_image_asset_service.dart` with the
  current package/local asset fallback behavior and image decode.
- Move sample image loading, image resolution, JSON export/import orchestration,
  and sample-node insertion into `CanvasExampleViewModel`.
- Keep dialogs in the screen/view layer, but route JSON and sample-object
  actions through view-model methods.
- Make the scene-surface widget consume only view-model-exposed render inputs.

#### Behavioral Verification

- `example/test/data/services/sample_image_asset_service_test.dart` — package
  asset success, local fallback success, and total failure paths.
- `example/test/ui/canvas_example/canvas_example_view_model_test.dart` — export
  returns current JSON, import applies a decoded scene, invalid JSON does not
  corrupt current state, and sample insertion adds rect/text/image nodes with
  monotonic ids.

#### Structural Verification

- `example/test/ui/canvas_example/canvas_example_architecture_test.dart` — only
  `sample_image_asset_service.dart` contains `rootBundle.load` or
  `instantiateImageCodec`, and only `canvas_example_view_model.dart` contains
  codec and node-spec owner tokens.

#### Fixtures Used

- None.

#### Positive Scenarios

- Sample image rendering still works through `SceneView(imageResolver: ...)`.
- Export/import menu actions still work against the current scene.
- Sample insertion still creates the same three node families.

#### Negative Scenarios

- Invalid JSON import leaves the current scene untouched.
- Sample image load failure leaves the image resolver empty without crashing the
  screen build.

#### Closure Evidence

- green run of the listed behavioral verifications;
- green run of the listed structural verifications;
- no remaining asset-loading or codec-owner logic in widget files.

### Slice 4. [x] Split the feature UI into region widgets and lock drift mechanically

#### Slice Contract

The example screen is decomposed into feature widgets that consume state and
callbacks only, and owner drift back into `main.dart` or widget files fails
mechanically.

#### Change

- Create region widgets under `example/lib/ui/canvas_example/widgets/**` for:
  - screen assembly;
  - scene surface;
  - controls dock;
  - text options panel;
  - text edit overlay.
- Move widget-only helpers such as the color palette, camera controls,
  indicators, and pending-line painter into the appropriate feature widget
  files as private helpers.
- Add `example/test/ui/canvas_example/canvas_example_architecture_test.dart`
  with the owner-file allow-list rules defined in section 8.

#### Behavioral Verification

- `example/test/widget_test.dart` — app still renders the example scaffold and
  the sample-action affordance.
- `example/test/widget_test.dart` — text-edit dismiss overlay key remains
  present during inline editing.

#### Structural Verification

- `example/test/ui/canvas_example/canvas_example_architecture_test.dart`.
- `test/entrypoints/example_public_api_contract_test.dart`.

#### Fixtures Used

- None.

#### Positive Scenarios

- The screen still shows the scene surface, camera affordances, control dock,
  text options panel, and text edit overlay in the same feature flow.
- `SceneView` remains localized to one scene-surface adapter widget.

#### Negative Scenarios

- Widget files cannot reacquire direct engine mutation or asset-loading logic
  without failing the architecture test.
- `main.dart` cannot regress into a second monolithic feature owner without
  failing the architecture test.

#### Closure Evidence

- green run of the listed behavioral verifications;
- green run of the listed structural verifications;
- widget files contain only view composition, local presentation helpers, and
  callback wiring.

## 10. Final Verification

- full run of
  `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`
  with every changed repository-relative path provided from stdin or file;
- full run of `cd example && flutter test --no-pub test` while the new example
  tests are in place;
- full run of `cd example && flutter analyze lib test` if targeted triage is
  needed before the required preset;
- green `test/entrypoints/example_public_api_contract_test.dart` in the final
  preset run;
- final audit that the architecture-owner allow-list in
  `canvas_example_architecture_test.dart` matches the locked file map.

## 11. Acceptance Criteria

- The change mandate is satisfied.
- The surrounding code review records actual repository evidence.
- The architectural form is explicit, justified, and locked at the correct
  level.
- No material architectural choice remains to the implementing agent.
- Result requirements are satisfied.
- Implementation rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
