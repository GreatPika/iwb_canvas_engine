language: english

# Change Contract

## 1. Change Mandate

Make terminal pointer cleanup exception-safe so `SceneViewInteractive` always
releases raw pointer lifecycle state and idle-gated pointer-setting side
effects even when downstream interactive terminal dispatch throws.

## 2. Change Boundary

### Included in the Change

- reproduce the finite terminal failure path where
  `SceneViewInteractivePointerHost` forwards `up` / `cancel`, downstream
  interactive dispatch throws, and raw-pointer release does not complete
- reproduce the invalid terminal failure path where router release happens, but
  `handleRawPointerRelease(...)` and session-local terminal cleanup can still be
  skipped by an exception
- land the minimal owner-side fix in
  `lib/src/view/scene_view_interactive_pointer_host.dart` so terminal release
  and `handleRawPointerRelease(...)` execute from `finally`
- add session-local defensive cleanup in
  `lib/src/interactive/internal/scene_controller_pointer_session.dart` only if
  needed to keep tracker/timer terminal state aligned when forwarding throws
- add an unreleased changelog entry because the fix changes observable
  exception-path cleanup behavior in `SceneViewInteractive`
- update the lifecycle invariant wording, regression surfaces, and any
  lifecycle-focused source-of-truth docs so exception-safe terminal cleanup is
  explicitly part of the checked-in contract
- keep the change inside the existing `SceneViewRuntime` /
  `SceneViewPointerSession` seam and add this step to `PLAN.md`

### Not Included in the Change

- no expansion or redesign of the public or internal
  `SceneViewRuntime` / `SceneViewPointerSession` contract
- no movement of `SceneViewPointerRouter` ownership into `interactive/**`
- no movement of `PointerInputTracker` ownership into `view/**`
- no broader pointer-session architecture rewrite beyond the minimum
  contract-tightening needed to prevent terminal cleanup drift
- no mutation-gateway, render-seam, or public controller API changes
- no unrelated cleanup of pointer routing, gesture policy, or pending tap
  heuristics outside the terminal exception path

## 3. Surrounding Code Review

### Inspected Artifacts

- `docs/adr/0001_target_engine_architecture.md` - the accepted target keeps one
  assembled `SceneViewRuntime` boundary, keeps the view shell from
  reconstructing ownership locally, and keeps pointer-session orchestration in
  the interaction family rather than as a new public seam
- `docs/target_architecture/families/view_runtime_and_render_seam.md` - the
  target family is `locked` and explicitly keeps `SceneViewRuntime` as the only
  view-facing runtime boundary, with `createPointerSession(...)` staying on
  that seam
- `docs/target_architecture/families/interaction_runtime.md` - the target
  family is `locked` and explicitly keeps `SceneControllerPointerSession` as
  the pointer-session adapter between the view-facing runtime boundary and the
  interaction family; it also forbids moving pointer-session ownership into the
  view shell
- `docs/target_architecture/execution_flows.md` - the pointer-input runtime-view
  artifact defines the intended architectural check: pointer hosting stays in
  `view/**`, while routed pointer-session work stays behind the
  `SceneViewRuntime` boundary
- `docs/target_architecture/evidence/pointer_input_flow.md` - current evidence
  already records `SceneViewInteractivePointerHost.handlePointerEvent(...)`
  calling `SceneViewPointerSession.handleRoutedSample(...)`,
  `SceneViewPointerRouter.release(...)`, and
  `SceneViewPointerSession.handleRawPointerRelease(...)` from the view shell
- `plan/step_5_interactive_pointer_session_lifecycle_boundary.md` - the prior
  closed step already locked runtime-owned session lifecycle ownership,
  synchronous epoch reset, and safe disposal deactivation, while explicitly
  preserving the existing `SceneViewRuntime` / `SceneViewPointerSession` seam
- `lib/src/view/scene_view_interactive_pointer_host.dart` - the current finite
  terminal path calls `_pointerSession.handleRoutedSample(...)` before
  `SceneViewPointerRouter.release(...)` and
  `_pointerSession.handleRawPointerRelease(...)`, both without `finally`; the
  invalid terminal path releases the router first, but still calls
  `handleRawPointerRelease(...)` only after forwarding
- `lib/src/view/scene_view_pointer_router.dart` - raw pointer slot ownership,
  routed pointer id reuse, signal-tracking gates, and idle-after-release state
  all belong to the view-local router
- `lib/src/contract/scene_view_runtime.dart` - the accepted seam already splits
  routed sample forwarding, invalid terminal forwarding, and raw-pointer
  release into existing session methods; the seam does not currently require a
  new atomic terminal API
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart` -
  `SceneControllerSceneViewRuntime.createPointerSession(...)` is the concrete
  implementation of the accepted runtime seam and constructs
  `SceneControllerPointerSession` without widening the boundary
- `lib/src/interactive/internal/scene_controller_pointer_session.dart` - the
  session currently forwards terminal samples into the interaction runtime
  before session-local tracker discard, signal tracking, flush-timer sync, and
  pending pointer-settings application, so some terminal local cleanup still
  depends on successful downstream dispatch
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart` -
  session-routed pointer dispatch remains a strict token-validated bridge into
  `InteractiveRuntime` and does not catch terminal exceptions
- `lib/src/interactive/internal/interactive_runtime.dart` - `_dispatchPointer`
  guarantees pointer normalizer release in `finally`, but deliberately
  rethrows downstream gesture exceptions
- `lib/src/interactive/internal/interactive_move_session.dart` - terminal move
  cleanup already uses `finally` to reset gesture state while still allowing
  `_commitMoveGesture(...)` exceptions to propagate
- `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
  - checked-in behavior already expects terminal `up` to throw in real
  supported scenarios such as resolver purity violations and invalid resolved
  deltas
- `test/view/scene_view_interactive_test.dart` - current lifecycle proof covers
  invalid terminal cleanup, pointer slot reuse, pending tap scheduling, and
  pointer-settings live-apply only on non-throwing paths
- `tool/invariant_registry.dart` - current lifecycle invariants cover pointer
  slot release, pointer-settings live-apply, pointer-session lifecycle, and
  runtime-host/session detach, but none of the current wording explicitly says
  terminal cleanup must survive downstream exceptions
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_pointer_host_rules.dart`
  - the current structural rule already locks the host as a raw
  routing/lifecycle shell and forbids moving tracker/runtime ownership into the
  view layer, but it does not enforce exception-safe terminal ordering
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_pointer_rules.dart`
  - the current structural rule already locks `SceneControllerPointerSession`
  as the pointer-session owner and keeps session lifecycle under
  `interactive/**`
- `dart run tool/lsp_trace_flow.dart lib/src/view/scene_view_interactive_pointer_host.dart _SceneViewInteractivePointerRuntime.handlePointerEvent --depth=8`
  - confirms the current primary flow still keeps both
  `SceneViewPointerRouter.release(...)` and
  `SceneViewPointerSession.handleRawPointerRelease(...)` in the host method
  after `SceneViewPointerSession.handleRoutedSample(...)`
- `dart run tool/lsp_trace_flow.dart lib/src/view/scene_view_interactive_pointer_host.dart _SceneViewInteractivePointerRuntime._forwardInvalidTerminalHostEvent --depth=8`
  - confirms the invalid terminal path still performs router release in the
  host shell and then calls `handleInvalidTerminalSample(...)` and
  `handleRawPointerRelease(...)` from the same method
- `dart run tool/lsp_trace_symbol.dart lib/src/contract/scene_view_runtime.dart SceneViewRuntime.createPointerSession --direction=both --depth=3 --json`
  - confirms the accepted runtime seam is already exercised by the view host
  and interactive tests, so widening the seam is unnecessary for this fix

### Current Entry Path

- finite terminal failure path:
  `SceneViewRuntimeHost -> SceneViewInteractivePointerHost.handlePointerEvent(...) -> _SceneViewInteractivePointerRuntime.handlePointerEvent(...) -> SceneViewPointerSession.handleRoutedSample(...) -> SceneControllerPointerSession.handleRoutedSample(...) -> SceneControllerInteractionRuntime.handlePointerFromSession(...) -> InteractiveRuntime._dispatchPointer(...) -> gesture terminal handler throws -> host-level router release and handleRawPointerRelease are skipped`
- invalid terminal failure path:
  `SceneViewRuntimeHost -> SceneViewInteractivePointerHost.handlePointerEvent(...) -> _SceneViewInteractivePointerRuntime._forwardInvalidTerminalHostEvent(...) -> SceneViewPointerRouter.release(...) -> SceneViewPointerSession.handleInvalidTerminalSample(...) -> downstream terminal dispatch throws -> handleRawPointerRelease is skipped`

### Current Owner

- raw pointer slot lifecycle is owned by the view pointer host and
  `SceneViewPointerRouter`
- pointer-session local tracker, timer, and pending-settings state is owned by
  `SceneControllerPointerSession`
- terminal gesture exceptions are owned by the interaction runtime path and are
  intentionally allowed to escape

### Adjacent Abstractions

- `lib/src/view/scene_view_runtime_host.dart` - adjacent runtime host that owns
  active runtime swaps and pointer-session replacement, but not raw-pointer
  routing policy
- `lib/src/view/scene_view_pointer_router.dart` - adjacent raw-pointer slot and
  signal gate owner whose state must stay consistent with actual terminal input
- `lib/src/interactive/internal/scene_controller_pointer_session.dart` -
  adjacent session-local tracker/timer owner and the natural secondary defense
  for terminal cleanup after the host performs release
- `lib/src/interactive/internal/interactive_runtime.dart` - adjacent
  downstream dispatch owner whose exception behavior must remain unchanged
- `lib/src/core/pointer_input_tracker.dart` - adjacent session-local tap/signal
  owner that must remain under the session, not the view shell

### Existing Tests

- `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
  - proves terminal dispatch may throw on supported public interactive paths
- `test/view/scene_view_interactive_test.dart` - proves raw-pointer cleanup,
  slot reuse, pending tap timer behavior, and pointer-settings live-apply on
  successful view-host routing paths
- `test/interactive/core/scene_controller_interaction_contract_test.dart` -
  proves pointer-session lifecycle ownership, token validation, and local
  no-op behavior after detach/dispose
- `test/view/scene_view_pointer_router_test.dart` - proves slot release and
  active-pointer gating at the raw router owner seam
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` - proves the
  structural lifecycle/ownership split between pointer host, runtime seam, and
  pointer session

### Analogous Implementation Path

- `lib/src/interactive/internal/interactive_move_session.dart` - closest valid
  precedent because `_moveHandleUp(...)` already uses `try/finally` to keep
  terminal gesture cleanup independent from commit failure while still allowing
  the exception to propagate

### Governing Repository Rules

- `AGENTS.md` - fix root causes at the owning seam instead of patching one
  downstream caller
- `AGENTS.md` - when recurring behavior matters, encode it in repository-local
  tests, invariants, and tooling rather than relying on prose
- project instructions in `AGENTS.md` - add or update automated tests for bug
  fixes and use the required verification preset instead of ad hoc
  `dart test`
- `docs/adr/0001_target_engine_architecture.md` - `SceneViewRuntime` remains
  the only view-facing bridge, and the view shell must not reconstruct
  controller/runtime ownership locally
- `docs/target_architecture/families/view_runtime_and_render_seam.md` - keep
  `createPointerSession(...)` on the runtime boundary rather than inventing a
  new view-owned orchestration seam
- `docs/target_architecture/families/interaction_runtime.md` - keep
  `SceneControllerPointerSession` as the pointer-session adapter and do not
  move pointer-session ownership into the view shell

### Rejected Misleading Local Patterns

- add a new atomic terminal method to `SceneViewPointerSession` first - wrong
  level because the accepted seam is already `locked`, the raw-pointer router is
  still view-owned, and this bug does not require a boundary-shape change
- move raw-pointer slot release into `SceneControllerPointerSession` - wrong
  owner because `SceneViewPointerRouter` lives in `view/**`
- move `PointerInputTracker` or pending pointer-settings state into the view
  host - wrong owner because session-local tracking belongs to
  `SceneControllerPointerSession` under the interaction family
- catch and swallow terminal exceptions in the interaction runtime - wrong
  behavior because current public tests intentionally lock terminal throws as a
  supported result
- reopen step 5 and rewrite it in place - wrong workflow because step 5 is a
  closed contract about session lifecycle ownership, while this bug is a new
  exception-safety gap discovered after that closure

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- one local lifecycle-hardening cut across the existing view-host shell and
  pointer-session adapter seams

#### Selected Architectural Form

- keep the accepted seam unchanged:
  `SceneViewInteractivePointerHost` remains the raw pointer host shell over
  `SceneViewPointerRouter` and `SceneViewPointerSession`
- make terminal cleanup exception-safe at the host owner level:
  on finite `up` / `cancel`, `SceneViewPointerRouter.release(...)` and
  `SceneViewPointerSession.handleRawPointerRelease(...)` must execute from
  `finally` regardless of whether routed terminal dispatch throws
- keep invalid terminal admission in the host shell and likewise guarantee
  `handleRawPointerRelease(...)` from `finally` after the already host-owned
  router release
- keep session-local tracker/timer/pending-setting ownership in
  `SceneControllerPointerSession`, and add only the minimum defensive terminal
  cleanup needed there so local tracking state does not depend entirely on
  successful downstream forwarding
- preserve current exception semantics:
  downstream interactive terminal exceptions still propagate to callers after
  lifecycle cleanup completes

#### Owning Layer or Module

- primary owner:
  `lib/src/view/scene_view_interactive_pointer_host.dart`
- secondary owner for session-local state alignment:
  `lib/src/interactive/internal/scene_controller_pointer_session.dart`

#### Dependency Direction

- host shell:
  `SceneViewInteractivePointerHost` ->
  `SceneViewPointerRouter` and `SceneViewPointerSession`
- session adapter:
  `SceneControllerPointerSession` ->
  `SceneControllerInteractionRuntime` for forwarding,
  but terminal local cleanup must not require successful downstream return
- no new dependency from `interactive/**` back into view-local router internals

#### State and Data Ownership

- raw pointer slot allocation, routed pointer id reuse, and idle-after-release
  state remain owned by `SceneViewPointerRouter`
- pending pointer-settings application gates remain session-local and continue
  to trigger through `handleRawPointerRelease(...)`
- tap history, tracker discard, and pending flush timer state remain owned by
  `SceneControllerPointerSession`
- gesture exceptions remain owned by the interaction runtime and are not turned
  into view-host policy

#### Entry and Exit Boundaries

- entry boundary:
  `SceneViewInteractivePointerHost.handlePointerEvent(...)`
- owner-to-owner internal boundary:
  `SceneViewPointerSession.handleRoutedSample(...)`,
  `handleInvalidTerminalSample(...)`, and `handleRawPointerRelease(...)`
- exit boundary:
  raw pointer slot state, session-local idle/pending-setting state, and the
  existing propagated terminal exception surface visible to the caller/test

#### Permitted Extension Seam

- `try/finally` ordering changes inside the existing host methods are allowed
- small session-local `try/finally` cleanup around terminal local state is
  allowed if required by the new reproducer tests
- invariant wording, regression tests, and existing guardrail fixtures may be
  updated to make the landed lifecycle form mechanically visible
- no new public or contract-facing method is allowed in this step

#### Rejected Alternatives

- widen `SceneViewPointerSession` with a new atomic terminal API - rejected
  because the target seam is already `locked`, and this defect is solvable at
  the current owners without boundary churn
- relocate all terminal cleanup into `SceneControllerPointerSession` - rejected
  because raw pointer slot lifecycle is not session-owned
- relocate all terminal cleanup into the interaction runtime - rejected because
  that would make `interactive/**` own view-local router state

#### Why This Level Is Correct

- the defect is specifically that a view-owned lifecycle effect is sequenced
  after downstream dispatch without `finally`
- the accepted target architecture already says the view shell remains the host
  over the assembled runtime boundary rather than changing the seam shape for
  each bug
- keeping the fix in the existing owners closes the defect once without
  widening the contract or moving ownership to the wrong layer

## 5. Locked Decisions

1. The first reproducer is a finite terminal `PointerUpEvent` path through
   `SceneViewInteractive` where the controller-side terminal dispatch throws and
   `debugSceneViewInteractiveLiveRawPointerCountOf(...)` must still become `0`.
2. At least one neighboring guard test must cover invalid terminal throw
   behavior where router release already happened, but
   `handleRawPointerRelease(...)` must still complete.
3. The host fix must preserve exception propagation; tests assert both the
   throw and the cleanup, not cleanup instead of the throw.
4. The step updates lifecycle invariant wording instead of inventing a brand
   new owner family or widening the seam.
5. Structural enforcement remains limited to the existing ownership split unless
   implementation proves one narrow lifecycle-shape check can be added without
   hard-coding implementation trivia.

## 6. Result Requirements

1. After any terminal `up` or `cancel` routed through `SceneViewInteractive`,
   the raw pointer slot is released even if downstream interactive dispatch
   throws.
2. When that terminal release leaves the router idle, pending pointer settings
   are applied through `handleRawPointerRelease(...)` even if terminal dispatch
   throws.
3. Invalid terminal host events still preserve terminal phase forwarding, still
   release the raw pointer, and still complete idle-gated release side effects
   when forwarding throws.
4. Session-local terminal tracking state no longer depends entirely on a
   successful downstream return on the exercised terminal failure paths.
5. The accepted target seam remains intact:
   `SceneViewRuntime` is still the only view-facing boundary and
   `SceneControllerPointerSession` is still the pointer-session adapter.
6. Checked-in lifecycle invariants and tests explicitly cover terminal
   exception-safe cleanup rather than implying it only from happy-path routing.

## 7. Execution Order and Gates

### Required Order

- add the finite terminal throwing reproducer and 1 to 3 neighboring guard
  tests before changing host or session implementation
- land the minimal host-side `finally` fix before any optional session-local
  defensive cleanup
- add session-local defensive cleanup only if the reproducer or new guard tests
  prove the host fix alone leaves tracker/timer state inconsistent
- update invariant wording, changelog, lifecycle docs, and any structural proof
  after the host fix is green; this proof/documentation slice is mandatory even
  if no session-local cleanup is needed

### Successor Seam and Retirement Gates

- no successor seam is introduced in this step; the existing
  `SceneViewRuntime` / `SceneViewPointerSession` seam remains authoritative
- retirement gate:
  do not add or keep any experimental widened terminal API once the exception-
  safe behavior is proven at the current owners
- invariant gate:
  lifecycle wording in `tool/invariant_registry.dart` must move before the step
  can close, so future work cannot regress to happy-path-only proof language

### Deferred Broad Verification

- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<file>`
  - reserved for the final implementation gate
- any broader target-map evidence refresh is deferred unless the landed change
  updates files referenced by the target architecture family docs

## 8. File Map

### Implementation Files

- `lib/src/view/scene_view_interactive_pointer_host.dart`
- `lib/src/interactive/internal/scene_controller_pointer_session.dart`

### Test Files

- `test/view/scene_view_interactive_test.dart`
- `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
  only if an adjacent locking scenario or helper needs clarification rather than
  a new behavior change
- `test/interactive/core/scene_controller_interaction_contract_test.dart`
  only if the lifecycle invariant wording requires a matching owner-side
  contract test

### Fixtures and Supporting Data

- existing `SceneViewInteractive` test fixtures in
  `test/view/scene_view_interactive_test.dart`
- existing guardrail sandbox fixtures only if one new structural regression
  case is added

### Registry, Inventory, and Workflow Files

- `tool/invariant_registry.dart`
- `CHANGELOG.md`
- `PLAN.md`
- `plan/step_24_exception_safe_pointer_terminal_lifecycle.md`
- `ARCHITECTURE.md` only if the landed wording changes an architectural claim
  about owner, boundary, or responsibility; do not touch it for proof-only or
  lifecycle-wording clarification that is fully captured by
  `tool/invariant_registry.dart`

### Analysis Area

- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_pointer_host_rules.dart`
  only if one narrow lifecycle-shape regression is needed after the behavior is
  locked
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
  only if that new structural regression is added

## 9. Implementation Rules

### Protected Invariants

- `INV-ENG-INTERACTIVE-POINTER-SESSION-LIFECYCLE`
- `INV-ENG-VIEW-POINTER-SETTINGS-LIVE-APPLY`
- `INV-ENG-VIEW-POINTER-SLOT-LIFECYCLE`
- `INV-ENG-VIEW-POINTER-SESSION-DETACH`
- `INV-ENG-VIEW-POINTER-SEMANTICS-BOUNDARY`

### Required Proof

- behavioral proof:
  new failing reproducer in `test/view/scene_view_interactive_test.dart` for
  finite terminal throw cleanup, plus 1 to 3 neighboring guard tests covering
  invalid terminal throw cleanup, routed pointer id reuse after throw, and
  idle-gated pointer-settings apply after throw
- structural proof:
  run the existing interactive guardrail ownership split on every slice that
  changes or closes the locked host/session lifecycle form; add one narrow
  structural regression only if the final host/session form would otherwise be
  easy to drift away from without detection
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard
  tests for neighboring branches of the same contract
- for refactors: existing locking tests must be named or missing
  characterization tests must be added before structural edits, plus 1 to 3
  guard tests for neighboring branches when needed

### Allowed Change Surface

- terminal ordering and `try/finally` structure inside
  `scene_view_interactive_pointer_host.dart`
- minimal terminal local cleanup adjustments inside
  `scene_controller_pointer_session.dart`
- lifecycle invariant wording and matching lifecycle tests
- narrow guardrail fixture/test updates only if needed to encode the final
  owner-side lifecycle shape

### Forbidden Moves

- no new public exports or public runtime contract methods
- no swallowing or transforming downstream terminal exceptions
- no movement of router ownership out of `view/**`
- no movement of tracker/timer ownership out of
  `SceneControllerPointerSession`
- no broad cleanup wave across unrelated pointer or gesture paths

## 10. Vertical Slices

### Slice 1. [ ] Reproduce Throwing Terminal Cleanup Gap

#### Slice Contract

Lock the current defect with one failing finite terminal reproducer and
neighboring guard tests that prove exception-safe cleanup is missing on the
checked-in host path.

#### Change

- add a `SceneViewInteractive` test where terminal `PointerUpEvent` dispatch
  throws from the controller path and assert both the throw and the expected
  host/session cleanup outcome
- add 1 to 3 guard tests covering invalid terminal throw cleanup, routed
  pointer id reuse after a throwing terminal release, and pending pointer
  settings apply after idle release on a throwing path

#### Behavioral Verification

- `flutter test test/view/scene_view_interactive_test.dart`

#### Structural Verification

- none for this reproducer slice; it locks behavior before structure changes

#### Fixtures Used

- existing `SceneController` + `SceneViewInteractive` host fixtures in
  `test/view/scene_view_interactive_test.dart`

#### Positive Scenarios

- finite terminal throw still releases raw pointer state
- next routed pointer reuses the expected slot after the throw
- idle-gated pending pointer settings still apply after the throw

#### Negative Scenarios

- invalid terminal throw must not skip `handleRawPointerRelease(...)`
- the test must still observe the original thrown exception

#### Closure Evidence

- the new reproducer fails on the checked-in implementation before the fix

### Slice 2. [ ] Harden Host-Level Terminal Cleanup

#### Slice Contract

Fix the root cause at the host owner so terminal cleanup executes from
`finally` without changing seam shape or exception propagation.

#### Change

- update `lib/src/view/scene_view_interactive_pointer_host.dart` so finite
  terminal release and `handleRawPointerRelease(...)` execute from `finally`
- update invalid terminal forwarding so `handleRawPointerRelease(...)` also
  executes from `finally` after router release
- keep throw behavior unchanged after cleanup completes

#### Behavioral Verification

- `flutter test test/view/scene_view_interactive_test.dart`

#### Structural Verification

- `dart run tool/check_guardrails.dart`
- `flutter test test/interactive/core/scene_controller_interaction_contract_test.dart`
  if the fix relies on existing session contract behavior and that contract
  needs confirmation at the owner seam

#### Fixtures Used

- existing `SceneViewInteractive` host fixtures

#### Positive Scenarios

- finite terminal throw path now leaves live raw pointer count at `0`
- invalid terminal throw path now still completes idle-release side effects

#### Negative Scenarios

- terminal exception still propagates
- non-terminal paths do not regress

#### Closure Evidence

- slice 1 tests turn green with only owner-side host changes unless session-
  local cleanup still proves inconsistent

### Slice 3. [ ] Update Lifecycle Invariant And Release Proof

#### Slice Contract

Make the landed exception-safe terminal cleanup part of the checked-in
lifecycle contract, changelog, and structural proof surface regardless of
whether session-local cleanup changes were needed.

#### Change

- update `tool/invariant_registry.dart` so lifecycle wording explicitly covers
  exception-safe terminal cleanup
- add the matching changelog entry in `CHANGELOG.md`
- update `ARCHITECTURE.md` only if the landed wording changes an architectural
  statement about the current owner seam rather than only making lifecycle
  proof wording explicit
- add one narrow guardrail regression only if the landed host/session form
  still needs extra drift protection beyond the existing guardrails

#### Behavioral Verification

- `flutter test test/view/scene_view_interactive_test.dart`

#### Structural Verification

- `dart run tool/check_guardrails.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
  only if that new structural regression lands

#### Fixtures Used

- existing lifecycle regression fixtures
- existing guardrail sandbox support only if structural proof is extended

#### Positive Scenarios

- lifecycle invariant wording now matches the actual enforced behavior
- changelog records the behavior correction

#### Negative Scenarios

- no new widened terminal seam appears
- no contradictory happy-path-only lifecycle wording remains in checked-in
  proof surfaces

#### Closure Evidence

- invariant registry, changelog, and any needed structural proof are updated in
  the same change as the landed behavior fix

### Slice 4. [ ] Align Session Local Terminal State If Host Fix Is Insufficient

#### Slice Contract

Only if host hardening alone is insufficient, make the minimum session-local
terminal cleanup independent from successful downstream forwarding while
preserving the same accepted seam and proof shape.

#### Change

- add only the required terminal local cleanup in
  `lib/src/interactive/internal/scene_controller_pointer_session.dart`

#### Behavioral Verification

- `flutter test test/view/scene_view_interactive_test.dart`
- `flutter test test/interactive/core/scene_controller_interaction_contract_test.dart`
  if session-local contract behavior changes are now explicitly asserted

#### Structural Verification

- `dart run tool/check_guardrails.dart`

#### Fixtures Used

- existing interactive contract fixtures

#### Positive Scenarios

- session-local terminal tracking state stays aligned after throwing terminal
  dispatch

#### Negative Scenarios

- no new widened terminal seam appears
- no view shell tracker ownership leak appears

#### Closure Evidence

- session-local cleanup is added only if slice 2 plus slice 3 still leave the
  exercised terminal failure path inconsistent

## 11. Final Verification

- `flutter test test/view/scene_view_interactive_test.dart`
- `flutter test test/interactive/core/scene_controller_interaction_contract_test.dart`
  if touched
- `dart run tool/check_guardrails.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
  if guardrail fixtures or structural lifecycle cases are touched
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<file>`

## 12. Acceptance Criteria

- terminal `SceneViewInteractive` cleanup is exception-safe on both finite and
  invalid terminal paths
- raw pointer slots and idle-gated release side effects no longer depend on
  successful downstream terminal dispatch
- the accepted `SceneViewRuntime` / `SceneViewPointerSession` seam remains
  unchanged
- lifecycle proof explicitly covers the throwing terminal path, the updated
  invariant wording, and the changelog records the behavior correction
