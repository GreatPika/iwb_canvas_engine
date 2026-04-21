language: english

# Change Contract

## 1. Change Mandate

Reestablish one controller-owned lifecycle boundary for live `SceneView`
pointer sessions so semantic interactive epoch breaks clear stale tap history
and controller disposal deactivates late routed callbacks without internal token
faults.

## 2. Change Boundary

### Included in the Change

- Runtime-owned lifecycle coordination for live `SceneControllerPointerSession`
  instances created by the assembled `SceneViewRuntime`.
- Synchronous tap-history reset for successful semantic epoch-break paths:
  `replaceScene(...)`, `setMode(...)`, `setDrawTool(...)`, and real
  `setCameraOffset(...)` changes.
- Safe live-session deactivation on controller disposal so still-mounted view
  hosts cannot route late callbacks into disposed runtime state.
- Behavioral regression tests, structural guardrails, invariant registration,
  and source-of-truth documentation updates for the lifecycle rule.

### Not Included in the Change

- Moving `PointerInputTracker` ownership out of
  `SceneControllerPointerSession`.
- Expanding the public `SceneViewRuntime` / `SceneViewPointerSession` contract.
- Changing pointer-slot allocation, runtime-swap detach semantics, or pointer
  settings live-apply behavior except where required to preserve them.
- Changing public fail-fast behavior for direct controller API calls after
  `dispose()`.

## 3. Surrounding Code Review

### Inspected Artifacts

- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart` —
  owns pointer-session tokens, interrupt entrypoints, and controller disposal,
  but currently does not own live concrete session lifecycle.
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart` —
  owns `SceneViewRuntime` adaptation and concrete pointer-session creation.
- `lib/src/interactive/internal/scene_controller_pointer_session.dart` —
  owns `PointerInputTracker`, pending-tap timer, pointer-settings live-apply,
  detach, and dispose semantics.
- `lib/src/interactive/internal/interactive_runtime.dart` — owns controller-side
  gesture interruption, pointer normalization, draw/move state, and session
  detach handling.
- `lib/src/interactive/internal/scene_controller_scene_mutations.dart` —
  routes real `setCameraOffset(...)` changes through
  `interruptForExternalMutation()`.
- `lib/src/interactive/scene_controller_interaction.dart` — routes real
  `setMode(...)` and `setDrawTool(...)` changes through
  `interruptForInteractionConfigChange()`.
- `lib/src/interactive/internal/scene_controller_mutation_boundary.dart` —
  keeps `replaceScene(...)` on the pre-apply interrupt path and clears pointer
  normalization state after replacement.
- `lib/src/view/scene_view_runtime_host.dart` — keeps the same pointer session
  when the runtime instance does not change.
- `lib/src/view/scene_view_interactive_pointer_host.dart` — view shell stays a
  raw router/lifecycle shell and only performs `detach -> dispose -> reset` on
  runtime swap or host disposal.
- `lib/src/view/scene_view_pointer_router.dart` — reuses freed pointer ids,
  which allows stale session-local tap windows to rebind to later taps.
- `lib/src/core/pointer_input_tracker.dart` — stores pending taps by routed
  pointer id and emits `doubleTap` when the same id reappears inside the
  allowed window.
- `lib/src/interactive/internal/interactive_double_tap_router.dart` — resolves
  double-tap behavior against current mode and current snapshot at dispatch
  time.
- `lib/src/interactive/scene_controller.dart` and
  `lib/src/interactive/internal/scene_controller_graph.dart` — dispose the
  store before disposing the interactive graph, so disposal-time session
  teardown must not perform write-side restore work.
- `lib/src/interactive/internal/interactive_event_dispatcher.dart` — public
  listener notifications are microtask-scheduled, so `ownerListenable`
  callbacks are not a safe synchronous reset channel.
- `ARCHITECTURE.md` — locks the `view/**` shell, `SceneViewRuntime` seam, and
  `SceneControllerInteractionRuntime` ownership of pointer-session tokens.
- `tool/invariant_registry.dart` — records current interactive and view
  invariants, including interruption semantics, pointer-settings live-apply,
  pointer-session detach, and pointer-semantics boundaries.
- `test/interactive/core/scene_controller_interaction_contract_test.dart` —
  proves unknown-token throws, disposed session local no-op, and safe
  `session.dispose()` after `controller.dispose()`, but not live-session late
  callbacks.
- `test/view/scene_view_interactive_test.dart` — proves pending tap timer
  flush, stale timer cancellation on runtime/controller swap, timer ignore
  after widget dispose, and pointer-settings live-apply.
- `test/interactive/core/scene_controller_interactive_basics_test.dart` —
  proves active gesture reset on `replaceScene(...)` and real
  `setCameraOffset(...)`, but not pending tap-history reset.
- `test/interactive/core/scene_controller_mutation_boundary_test.dart` —
  proves `replaceScene(...)` currently clears pointer normalization state.
- `test/interactive/core/scene_controller_architecture_boundary_test.dart` and
  `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_pointer_rules.dart`
  — mechanically enforce the current pointer-session ownership split and keep
  `view/**` free of tracker/runtime ownership.

### Current Entry Path

- Stale double-tap path:
  `SceneViewInteractive -> SceneViewRuntimeHost -> SceneViewInteractivePointerHost.handlePointerEvent(...) -> SceneControllerPointerSession.handleRoutedSample(...) -> PointerInputTracker.handle(...) -> SceneControllerInteractionRuntime.handleDoubleTapFromSession(...) -> InteractiveDoubleTapRouter.handleDoubleTap(...)`.
- Semantic epoch-break path:
  `controller.scene.replaceScene(...) -> SceneControllerSceneMutations.replaceScene(...) -> interruptBeforeApply`,
  `controller.scene.setCameraOffset(...) -> SceneControllerSceneMutations.setCameraOffset(...) -> interruptForExternalMutation()`,
  `controller.interaction.setMode(...) / setDrawTool(...) -> interruptForInteractionConfigChange()`.
- Disposal path:
  `SceneController.dispose() -> _storeController.dispose() -> disposeSceneControllerGraph(...) -> SceneControllerInteractionRuntime.dispose()`,
  while a still-mounted `SceneViewInteractivePointerHost` may continue to call
  its existing live `SceneControllerPointerSession`.

### Current Owner

- The problem belongs to `lib/src/interactive/internal`, with
  `SceneControllerInteractionRuntime` as the owner of pointer-session lifecycle
  policy and `SceneControllerPointerSession` as the owner of session-local
  tracking state.

### Adjacent Abstractions

- `InteractiveRuntime` — controller-owned gesture and normalization state.
- `SceneControllerPointerSession` — session-local tracker/timer/settings owner.
- `SceneControllerSceneViewRuntime` — factory for controller-owned runtime and
  session adaptation.
- `SceneControllerMutationBoundary` — committed-mutation owner for interactive
  work.
- `SceneViewInteractivePointerHost` — host-side router shell that must not own
  tracker policy.

### Existing Tests

- `test/interactive/core/scene_controller_interaction_contract_test.dart` —
  locks token ownership, local no-op after session disposal, and strict
  unknown-token failure.
- `test/view/scene_view_interactive_test.dart` — locks runtime swap lifecycle,
  pending-tap timer behavior, pointer settings live-apply, and pointer-slot
  reuse.
- `test/interactive/core/scene_controller_interactive_basics_test.dart` —
  locks public-mutation gesture reset semantics for `replaceScene(...)` and
  `setCameraOffset(...)`.
- `test/interactive/core/scene_controller_mutation_boundary_test.dart` — locks
  `replaceScene(...)` boundary sequencing and pointer-normalizer clearing.
- `test/interactive/core/scene_controller_architecture_boundary_test.dart` —
  locks the structural split between controller facade, runtime owner, view
  runtime adapter, and concrete pointer session.
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` plus the
  interactive architecture boundary fixture suites — lock the pointer-session
  ownership seam and keep `view/**` as a routing shell.

### Analogous Implementation Path

- `SceneControllerPointerSession._resetPointerTracking(...)` in
  `lib/src/interactive/internal/scene_controller_pointer_session.dart` already
  proves the dominant local form for “same session instance, new tracking
  epoch”: clear pending-tap scheduler, replace tracker state, and keep the
  session object alive.

### Governing Repository Rules

- `ARCHITECTURE.md` section 7.3 and 8.3 — `SceneControllerInteractionRuntime`
  owns pointer-session tokens and `view/**` remains the Flutter host shell over
  the runtime seam.
- `tool/invariant_registry.dart` —
  `INV-ENG-INTERACTIVE-INTERRUPTION-SEMANTICS`,
  `INV-ENG-INTERACTIVE-PUBLIC-MUTATION-EXCLUSIVITY`,
  `INV-ENG-VIEW-POINTER-SETTINGS-LIVE-APPLY`,
  `INV-ENG-VIEW-POINTER-SESSION-DETACH`, and
  `INV-ENG-VIEW-POINTER-SEMANTICS-BOUNDARY` already define adjacent lifecycle
  and ownership rules.
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_pointer_rules.dart`
  — pointer session must stay owned by `SceneControllerPointerSession`.
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_pointer_host_rules.dart`
  — `SceneViewInteractivePointerHost` must remain a raw routing/lifecycle shell
  over pointer sessions.
- Repository verification policy in `AGENTS.md` — code changes must add or
  update automated tests and run the required verification preset instead of
  ad hoc `dart test`.

### Rejected Misleading Local Patterns

- Reusing `ownerListenable` notifications as the reset channel —
  `InteractiveNotifyScheduler.schedule()` is asynchronous, so it does not close
  the same-turn race between a boundary mutation and the next routed tap.
- Moving `PointerInputTracker` or pending-tap ownership into
  `SceneViewInteractivePointerHost` — violates the enforced shell-only owner in
  `view/**`.
- Calling ordinary `session.detach()` during controller disposal — detach can
  cascade into controller-owned gesture teardown paths that restore baseline
  selection through write-side callbacks, which is the wrong semantic once the
  store is already disposed.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- Interactive runtime lifecycle ownership for live pointer sessions.

#### Selected Architectural Form

- `SceneControllerInteractionRuntime` becomes the authoritative owner of live
  pointer-session lifecycle orchestration, not just token identity.
- `SceneControllerSceneViewRuntime.createPointerSession(...)` registers each new
  concrete `SceneControllerPointerSession` with owner-only lifecycle hooks.
- The runtime exposes one internal semantic “interactive epoch reset” broadcast
  for successful same-runtime epoch breaks and one internal semantic “owner
  dispose deactivation” broadcast for controller teardown.
- `SceneControllerPointerSession` keeps tracker/timer/settings ownership and
  implements the owner-only hooks as local state transitions:
  one reset path that clears session-local tracking state without destroying the
  session instance, and one terminal deactivation path that permanently stops
  routing, releases token/listener ownership, and never writes back into the
  controller store.

#### Owning Layer or Module

- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
  owns live-session registration, epoch-reset broadcast, and owner-dispose
  deactivation order.
- `lib/src/interactive/internal/scene_controller_pointer_session.dart` owns the
  concrete reset/deactivation mechanics for session-local state.
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart` owns
  wiring the concrete session into the runtime-owned lifecycle registry.

#### Dependency Direction

- `view/**` continues to depend only on the `SceneViewRuntime` /
  `SceneViewPointerSession` contract seam and remains unaware of controller
  internals.
- `SceneControllerSceneViewRuntime` remains the only controller-owned adapter
  that can create concrete pointer sessions and bind them to
  `SceneControllerInteractionRuntime`.
- `SceneControllerInteractionRuntime` may coordinate concrete sessions through
  internal owner-only hooks, but no new dependency is introduced from `view/**`
  back into controller-specific types.

#### State and Data Ownership

- `SceneControllerPointerSession` continues to own:
  `PointerInputTracker`, pending-tap timer state, applied/pending pointer
  settings, detach/dispose flags, and owner-listener attachment.
- `SceneControllerInteractionRuntime` owns:
  token set, live-session registration, synchronous epoch-reset broadcast,
  disposal-time deactivation order, and fallback post-dispose callback safety.
- `InteractiveRuntime` continues to own controller-side gesture, preview, draw,
  move, and pointer-normalizer state.
- `SceneControllerMutationBoundary` remains the sole interactive owner of
  committed writes.

#### Entry and Exit Boundaries

- Entry boundaries for epoch reset:
  `interruptForInteractionConfigChange()` and
  `interruptForExternalMutation()`, reached from `setMode(...)`,
  `setDrawTool(...)`, real `setCameraOffset(...)`, and `replaceScene(...)`
  pre-apply sequencing.
- Entry boundary for teardown:
  `SceneControllerInteractionRuntime.dispose()`.
- Exit boundaries:
  internal session reset/deactivation hooks, no-op routed callbacks after
  disposal, and unchanged public runtime/view interfaces.

#### Permitted Extension Seam

- Internal-only lifecycle registration and hook invocation between
  `SceneControllerSceneViewRuntime`,
  `SceneControllerInteractionRuntime`, and `SceneControllerPointerSession`.
- Internal helper extraction inside those files is allowed if it preserves the
  existing ownership split and keeps `view/**` unchanged.

#### Rejected Alternatives

- Extend `SceneViewPointerSession` with new public reset/deactivation members —
  this would leak controller lifecycle policy into the contract seam and every
  runtime implementation.
- Move tracker/tap-window ownership into `InteractiveRuntime` — wider seam
  change than required, higher blast radius, and it fights the currently
  enforced `SceneControllerPointerSession` ownership.
- Route same-runtime epoch resets through widget rebuilds, runtime swaps, or
  `ChangeNotifier` delivery — wrong owner and not synchronous.
- Relax unknown-token failure globally — hides misuse in normal live runtime
  state instead of fixing disposal-time ownership.

#### Why This Level Is Correct

- Both reported defects come from one missing owner: runtime currently owns the
  policy that should decide when a session is still valid, but it only tracks
  opaque tokens.
- The concrete session already owns the local state that must be cleared or
  deactivated, so the correct fix is to let the runtime coordinate that
  existing owner instead of relocating state into another layer.
- This closes the class of bugs once at the lifecycle owner without weakening
  the `view/**` boundary or duplicating reset policy across public mutation
  call sites.

## 5. Locked Decisions

1. Only successful semantic epoch breaks reset session-local tap history.
   Setter no-ops, failed validation, and other non-applied paths must not clear
   the pending-tap window.
2. `replaceScene(...)` keeps its reset on the existing `interruptBeforeApply`
   path, so the pointer-session epoch reset stays coupled to the same pre-apply
   moment as controller-owned gesture interruption.
3. `setMode(...)`, `setDrawTool(...)`, and real `setCameraOffset(...)` share
   the same runtime-owned epoch-reset helper rather than introducing
   path-specific tap-reset code.
4. Controller disposal uses a dedicated owner-dispose deactivation path, not
   ordinary `detach()`, because disposal-time teardown must not restore baseline
   selection or perform any other store writes.
5. `handlePointerFromSession(...)` and `handleDoubleTapFromSession(...)`
   become safe no-ops after `_isDisposed`, while the existing
   `Unknown pointer session token.` failure remains the contract for
   non-disposed runtime misuse.
6. Pointer settings live-apply remains session-local. Epoch reset may clear the
   current tracker/timer state, but it must not re-own pending pointer-settings
   policy in the view shell or drop deferred settings adoption rules.

## 6. Result Requirements

1. A pending tap or double-tap window from one interactive epoch cannot survive
   into a later successful `replaceScene(...)`, real `setCameraOffset(...)`,
   `setMode(...)`, or `setDrawTool(...)` epoch.
2. A still-mounted `SceneViewInteractive` may receive late `down` / `up` /
   `cancel` events after `controller.dispose()` without throwing and without
   dispatching actions, edit requests, or controller mutations.
3. Public direct controller APIs after `dispose()` still fail fast with
   `StateError`; only routed stale session callbacks become local no-ops.
4. Pointer slot reuse, runtime swap detach/dispose ordering, and pointer
   settings live-apply remain behaviorally unchanged for supported flows.
5. The lifecycle rule is mechanically visible in tests, guardrails, the
   invariant registry, and release-ready documentation.

## 7. Execution Order and Gates

### Required Order

- Add the failing behavioral reproducers and neighboring guard tests at the
  current owner surfaces before implementation.
- Add or extend structural proof surfaces so the runtime-owned session
  registration seam is mechanically enforced before the minimal owner-side code
  fix is finalized.
- Implement the live-session registry and concrete session hooks only in the
  locked owner files.
- Update invariant registry and user/maintainer documentation after the runtime
  contract is green.

### Successor Seam and Retirement Gates

- Successor seam:
  runtime-owned live-session lifecycle registration replaces the current
  token-only ownership as the authoritative coordination point for same-runtime
  epoch resets and controller teardown.
- Consumer migration order:
  `SceneControllerSceneViewRuntime.createPointerSession(...)` must register the
  concrete session first; then `SceneControllerInteractionRuntime` interrupt and
  dispose paths must route through the registry; only after that may the old
  implicit “token set alone is enough” assumption be considered retired.
- Retirement gate:
  no same-runtime boundary path may rely on `ownerListenable` notifications,
  runtime swaps, or token clearing alone for stale tap-history reset or
  disposal safety.
- Registry, inventory, and workflow references:
  `tool/invariant_registry.dart`,
  `test/interactive/core/scene_controller_architecture_boundary_test.dart`,
  `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_pointer_rules.dart`,
  `test/tool/guardrails/interactive_api/architecture_boundary/view_surface_and_runtime_cases.dart`,
  `ARCHITECTURE.md`, `API_GUIDE.md`, `README.md`, and `CHANGELOG.md` must all
  reflect the successor seam before the step is closed.

### Deferred Broad Verification

- Final gate for all changed paths in this step:
  ```sh
  cat <<'EOF' | dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-
  PLAN.md
  plan/step_5_interactive_pointer_session_lifecycle_boundary.md
  lib/src/interactive/internal/scene_controller_interaction_runtime.dart
  lib/src/interactive/internal/scene_controller_scene_view_runtime.dart
  lib/src/interactive/internal/scene_controller_pointer_session.dart
  test/interactive/core/scene_controller_interaction_contract_test.dart
  test/view/scene_view_interactive_test.dart
  test/interactive/core/scene_controller_architecture_boundary_test.dart
  test/tool/guardrails/interactive_api/architecture_boundary/view_surface_and_runtime_cases.dart
  test/tool/guardrails/guardrails_interactive_api_tool_test.dart
  test/tool/support/guardrails_sandbox_support.dart
  tool/src/guardrails/rules/interactive/interactive_architecture_boundary_pointer_rules.dart
  tool/src/guardrails/rules/interactive/interactive_architecture_boundary_pointer_host_rules.dart
  tool/invariant_registry.dart
  ARCHITECTURE.md
  API_GUIDE.md
  README.md
  CHANGELOG.md
  EOF
  ```
- `dart run tool/check_guardrails.dart` — final guardrail gate after structural
  proof and documentation changes land.

## 8. File Map

### Implementation Files

- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- `lib/src/interactive/internal/scene_controller_pointer_session.dart`

### Test Files

- `test/interactive/core/scene_controller_interaction_contract_test.dart`
- `test/view/scene_view_interactive_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/view_surface_and_runtime_cases.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

### Fixtures and Supporting Data

- Existing interactive guardrail sandbox fixtures under
  `test/tool/support/guardrails_sandbox_support.dart`

### Registry, Inventory, and Workflow Files

- `PLAN.md`
- `plan/step_5_interactive_pointer_session_lifecycle_boundary.md`
- `tool/invariant_registry.dart`
- `ARCHITECTURE.md`
- `API_GUIDE.md`
- `README.md`
- `CHANGELOG.md`

### Analysis Area

- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_pointer_rules.dart`
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_pointer_host_rules.dart`

## 9. Implementation Rules

### Protected Invariants

- Preserve
  `INV-ENG-INTERACTIVE-INTERRUPTION-SEMANTICS`,
  `INV-ENG-INTERACTIVE-PUBLIC-MUTATION-EXCLUSIVITY`,
  `INV-ENG-VIEW-POINTER-SETTINGS-LIVE-APPLY`,
  `INV-ENG-VIEW-POINTER-SESSION-DETACH`, and
  `INV-ENG-VIEW-POINTER-SEMANTICS-BOUNDARY`.
- Add a new invariant entry
  `INV-ENG-INTERACTIVE-POINTER-SESSION-LIFECYCLE` covering runtime-owned
  live-session epoch reset and disposal deactivation semantics.

### Required Proof

- behavioral proof:
  add one failing reproducer first for
  `tap-up -> replaceScene(...) -> tap-up` on the same controller/runtime and
  one failing reproducer first for `controller.dispose()` while the view host
  remains mounted and still receives late routed pointer events.
- behavioral guard tests:
  add 1 to 3 neighboring guard tests covering
  `tap-up -> setMode(...) -> tap-up`,
  `tap-up -> setDrawTool(...) -> tap-up`,
  `tap-up -> real setCameraOffset(...) -> tap-up`,
  and at least one no-op branch that must preserve the pending-tap window.
- structural proof:
  extend architecture and guardrail proof surfaces so the runtime-owned
  live-session registration seam is mechanically enforced and `view/**` remains
  tracker-free.
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard
  tests for neighboring branches of the same contract.

### Allowed Change Surface

- Internal lifecycle helpers and registration hooks inside the locked
  `interactive/internal` owner files.
- Targeted tests, invariant registration, guardrail rules, and release-ready
  docs that describe the lifecycle contract.

### Forbidden Moves

- Do not expand the public `SceneViewPointerSession` interface.
- Do not move `PointerInputTracker` or pending-tap timer ownership into
  `view/**`.
- Do not use `ChangeNotifier` / microtask delivery as the authoritative reset
  mechanism for same-turn boundary changes.
- Do not call ordinary disposal-time `detach()` if that path can restore
  selection or perform write-side controller mutations.
- Do not relax `Unknown pointer session token.` for non-disposed runtime state.

### Optional: Allowed Forms That Are Not Violations

- Reusing existing session-local tracker reset mechanics inside a new
  owner-triggered helper is allowed if the session object identity remains
  stable.
- Adding internal, concrete-session lifecycle methods that are not part of
  `SceneViewPointerSession` is allowed.
- Returning early from routed runtime callbacks after `_isDisposed` is allowed
  as a disposal-time safety belt, provided strict unknown-token failure remains
  for non-disposed misuse.

### Optional: Resolution Rules

- When a boundary candidate is a semantic no-op, preserve pending tap history.
- When controller disposal deactivates a live session, release owner-listener
  and token ownership exactly once and leave later routed samples as local
  no-ops.

## 10. Vertical Slices

### Slice 1. [ ] Lock lifecycle reproducers and structural owner contract

#### Slice Contract

Close same-runtime interactive epoch reset as one end-to-end result:
land the reproducers, neighboring guards, the minimal owner-side fix for stale
tap-history reuse across successful epoch breaks, and the structural proof for
runtime-owned live-session registration.

#### Change

- Add the failing `tap-up -> replaceScene(...) -> tap-up` reproducer first, plus
  neighboring guard tests for `setMode(...)`, `setDrawTool(...)`,
  real `setCameraOffset(...)`, and one no-op branch that must preserve pending
  tap history.
- Extend structural proof so runtime-owned live-session registration is part of
  the architecture contract.
- Implement the minimum runtime/session changes needed to make the same-runtime
  epoch-reset reproducers and guards pass.

#### Behavioral Verification

- `flutter test test/interactive/core/scene_controller_interaction_contract_test.dart`
- `flutter test test/view/scene_view_interactive_test.dart`

#### Structural Verification

- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

#### Fixtures Used

- Existing controller/view test helpers in `test/view/scene_view_interactive_test.dart`
- Existing guardrail sandbox support in
  `test/tool/support/guardrails_sandbox_support.dart`

#### Positive Scenarios

- `tap-up -> replaceScene(...) -> tap-up` does not reuse stale pending tap
  history.
- `tap-up -> setMode(...) -> tap-up`,
  `tap-up -> setDrawTool(...) -> tap-up`, and
  `tap-up -> real setCameraOffset(...) -> tap-up` do not reuse stale pending
  tap history.

#### Negative Scenarios

- No-op `setMode(...)`, `setDrawTool(...)`, or `setCameraOffset(...)` does not
  clear pending tap history.

#### Closure Evidence

- The new epoch-reset reproducers and neighboring guard tests are green on the
  owner-side fix.
- Architecture and guardrail proof surfaces pass with runtime-owned session
  registration and without moving tracker policy into `view/**`.

### Slice 2. [ ] Implement runtime-owned pointer-session lifecycle orchestration

#### Slice Contract

Close controller-disposal session deactivation as one end-to-end result:
land the still-mounted late-callback reproducer, the minimal owner-dispose
deactivation path, invariant registration, and release-ready documentation for
the full lifecycle rule.

#### Change

- Add the failing still-mounted late-callback reproducer first, plus the
  neighboring guard that preserves strict unknown-token failure for
  non-disposed runtime misuse.
- Add the owner-dispose deactivation path in `SceneControllerPointerSession`
  and route controller teardown through the runtime-owned live-session
  registry.
- Add the invariant entry and update release-ready documentation to describe the
  new lifecycle contract.

#### Behavioral Verification

- `flutter test test/interactive/core/scene_controller_interaction_contract_test.dart`
- `flutter test test/view/scene_view_interactive_test.dart`

#### Structural Verification

- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

#### Fixtures Used

- Existing architecture-boundary analysis fixture in
  `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- Existing guardrail sandbox fixtures under `test/tool/guardrails/interactive_api/architecture_boundary/`

#### Positive Scenarios

- Still-mounted hosts ignore late routed `down` / `up` / `cancel` after
  `controller.dispose()` and emit no actions or edit requests.
- Pointer settings live-apply still works on the same controller/session.

#### Negative Scenarios

- Widget-runtime swap behavior still uses the existing host-driven
  `detach -> dispose -> router reset` path and does not regress.
- Normal live runtime unknown-token misuse still throws.
- Disposal-time deactivation performs no write-side restore or selection
  mutation.

#### Closure Evidence

- Slice 1 epoch-reset reproducers and guards remain green.
- Architecture and guardrail proof surfaces pass without introducing tracker
  policy into `view/**`.
- Invariant registry and release-ready docs reflect the landed lifecycle rule.

## 11. Final Verification

- `flutter test test/interactive/core/scene_controller_interaction_contract_test.dart`
- `flutter test test/view/scene_view_interactive_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- Final required preset run:
  ```sh
  cat <<'EOF' | dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-
  PLAN.md
  plan/step_5_interactive_pointer_session_lifecycle_boundary.md
  lib/src/interactive/internal/scene_controller_interaction_runtime.dart
  lib/src/interactive/internal/scene_controller_scene_view_runtime.dart
  lib/src/interactive/internal/scene_controller_pointer_session.dart
  test/interactive/core/scene_controller_interaction_contract_test.dart
  test/view/scene_view_interactive_test.dart
  test/interactive/core/scene_controller_architecture_boundary_test.dart
  test/tool/guardrails/interactive_api/architecture_boundary/view_surface_and_runtime_cases.dart
  test/tool/guardrails/guardrails_interactive_api_tool_test.dart
  test/tool/support/guardrails_sandbox_support.dart
  tool/src/guardrails/rules/interactive/interactive_architecture_boundary_pointer_rules.dart
  tool/src/guardrails/rules/interactive/interactive_architecture_boundary_pointer_host_rules.dart
  tool/invariant_registry.dart
  ARCHITECTURE.md
  API_GUIDE.md
  README.md
  CHANGELOG.md
  EOF
  ```

## 12. Acceptance Criteria

- Live session-local tap history cannot survive a successful same-runtime
  interactive epoch break.
- Controller disposal deactivates live sessions so late routed callbacks are
  ignored without exceptions or side effects.
- Direct public controller entrypoints after disposal still fail fast with
  `StateError`.
- `SceneViewRuntime` / `SceneViewPointerSession` public interfaces remain
  unchanged.
- `view/**` stays a raw routing/lifecycle shell and does not re-own tracker or
  tap-window policy.
- The new lifecycle rule is captured in invariant registry, structural proof,
  and release-ready documentation.
