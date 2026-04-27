language: english

# Change Contract

## 1. Change Mandate

Close `KI-3` by making interactive draw terminal cleanup exception-safe at the
existing draw owner seam so draw gesture session, preview, pending line, and
tool-local buffers cannot survive a failing terminal commit path.

## 2. Change Boundary

### Included in the Change

- reproduce the current failing terminal commit paths for stroke, dragged line,
  eraser, and router-owned draw gesture cleanup
- land the minimum owner-side `finally` cleanup in the existing draw terminal
  owners so cleanup no longer depends on successful commit or action emission
- keep the current draw-family architecture shape:
  `InteractiveDrawCoordinator` remains the draw orchestrator,
  `InteractiveDrawTerminalRouter` remains the terminal router, and the draw
  engines keep their tool-local state ownership
- preserve current exception propagation from failing draw terminal commit and
  action-emission paths
- preserve current non-failing draw behavior, including preview-on-up
  semantics, captured-style snapshots, and two-tap line ownership/provenance
- use the existing standalone audits as the primary structural enforcement for
  this defect family without widening audit or guardrail code in this step
- keep `tool/invariant_registry.dart` wording unchanged because the current
  lifecycle invariant already states the target exception-safe terminal cleanup
  guarantee
- update `README.md` and `API_GUIDE.md` in the implementation change because
  the step changes observable runtime behavior after failing draw terminal
  commit paths
- remove `KI-3` from `KNOWN_ISSUES.md`, update the interaction-runtime family
  status, and update release notes in the same change that proves closure
- add this contract as a new step in `PLAN.md`

### Not Included in the Change

- no coordinator-owned terminal mega-API or ownership refactor
- no movement of draw cleanup into `SceneControllerMutationBoundary`
- no movement of draw cleanup into the view host or pointer-session boundary
- no change to eraser geometry ownership, line pending-line ownership, or
  mutation-boundary callback shape beyond the minimum exception-safe cleanup
- no swallowing, remapping, or suppression of draw terminal exceptions
- no public API, schema, import/export, or render-pipeline changes
- no implementation for any active known issue other than `KI-3`

## 3. Surrounding Code Review

### Inspected Artifacts

- `KNOWN_ISSUES.md` - records `KI-3` as an active `P1` defect and names the
  current detections, evidence files, and required direction: guarantee draw
  terminal cleanup through `finally` at the draw owner seam.
- `docs/ARCHITECTURE_ATLAS.md` - the atlas is the navigation entrypoint and
  routes active confirmed defects through `KNOWN_ISSUES.md`.
- `docs/architecture/families/interaction_runtime.md` - the interaction family
  is the accepted owner of ephemeral draw runtime state, lists
  `InteractiveDrawCoordinator` as the local subsystem anchor, and already marks
  draw terminal cleanup as an active known issue.
- `ARCHITECTURE.md` - `interactive/**` owns controller-side gesture state while
  `SceneControllerMutationBoundary` remains the only committed-write bridge;
  interaction previews stay ephemeral until commit.
- `tool/invariant_registry.dart` - the active lifecycle invariant
  `INV-ENG-INTERACTIVE-POINTER-SESSION-LIFECYCLE` already says terminal cleanup
  must stay exception-safe across the runtime boundary.
- `docs/proof_architecture/evidence/proof_inventory.json` - the checked-in
  proof inventory binds that lifecycle invariant to interactive/view proof
  surfaces and already treats terminal exception-safety as repository policy.
- `lib/src/interactive/internal/interactive_draw_coordinator.dart` - the
  coordinator owns draw-family orchestration, current tool routing, gesture
  cancellation, and public overlay exposure, but not the inner implementation
  details of each tool-local commit path.
- `lib/src/interactive/internal/interactive_draw_terminal_router.dart` - the
  terminal router currently calls tool-specific `commitOnUp(...)` paths and
  only clears `gestureSession` / line preview after successful completion.
- `lib/src/interactive/internal/interactive_draw_stroke_engine.dart` - stroke
  terminal commit owns `_pathBuffer` cleanup locally, but currently clears it
  only after successful commit and action emission.
- `lib/src/interactive/internal/interactive_draw_line_engine.dart` - line
  terminal handling owns active preview and owner-scoped pending-line state;
  dragged-line cleanup currently runs after `_emitLineCommit(...)`.
- `lib/src/interactive/internal/interactive_draw_eraser_engine.dart` - eraser
  terminal commit owns `_pathBuffer` and debug counters locally, but currently
  clears the path buffer only after successful erase commit.
- `lib/src/interactive/internal/scene_controller_mutation_boundary.dart` -
  draw writes are committed here, but the boundary owns only committed
  mutation/invalidation and does not own draw session or preview state.
- `lib/src/interactive/internal/interactive_move_session.dart` - `_moveHandleUp`
  is the closest accepted precedent because it already uses `try/finally` to
  preserve terminal cleanup while still propagating commit exceptions.
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_draw_rules.dart`
  - existing structural policy keeps `InteractiveDrawCoordinator` as a draw
  orchestrator and rejects re-owning eraser geometry there.
- `test/tool/guardrails/interactive_api/architecture_boundary/runtime_and_draw_ownership_cases.dart`
  - regression coverage already locks that coordinator-orchestrator ownership
  split.
- `test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart`
  - existing behavioral proof covers dragged line flow, pending two-tap flow,
  and captured-style snapshot ownership.
- `test/interactive/core/scene_controller_interactive_guardrails_line_test.dart`
  - existing behavioral proof locks the line preview/no-commit-before-up
  invariant.
- `test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart`
  - existing behavioral proof locks stroke preview visibility and cleanup on a
  successful terminal up path.
- `test/interactive/core/interactive_draw_eraser_engine_test.dart` - existing
  owner-level eraser tests already exercise direct `commitOnUp(...)` behavior.
- `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
  - existing owner-level router wiring tests already assemble direct
  router/engine instances and are the nearest local fixture for direct draw
  terminal owner tests.
- `dart run tool/audit_terminal_cleanup_safety.dart lib/src` - currently
  reports four draw-family violations:
  `InteractiveDrawTerminalRouter.handleUp`,
  `InteractiveDrawStrokeEngine.commitOnUp`,
  `InteractiveDrawLineEngine._commitDraggedLine`, and
  `InteractiveDrawEraserEngine.commitOnUp`.
- `dart run tool/audit_post_commit_cleanup_order.dart lib/src` - currently
  reports three draw-family post-commit cleanup-order violations:
  `InteractiveDrawTerminalRouter.handleUp`,
  `InteractiveDrawStrokeEngine.commitOnUp`, and
  `InteractiveDrawLineEngine._commitDraggedLine`.
- `dart run tool/lsp_trace_flow.dart lib/src/interactive/internal/scene_controller_interaction_runtime.dart _createInteractiveRuntime --depth=4`
  - confirms the current runtime route keeps draw orchestration in
  `InteractiveRuntime -> InteractiveDrawCoordinator` and draw writes as direct
  callbacks into `SceneControllerMutationBoundary`.
- `dart run tool/lsp_trace_symbol.dart lib/src/interactive/internal/interactive_draw_terminal_router.dart InteractiveDrawTerminalRouter.handleUp --direction=outgoing --depth=4 --json`
  - confirms router terminal handling currently fans out to the stroke, line,
  and eraser engines and only then clears the shared gesture session.

### Current Entry Path

- draw terminal dispatch:
  `SceneControllerInteractionRuntime -> InteractiveRuntime._dispatchPointer(...) -> InteractiveGestureRouter._handleOwnedPointerSample(...) -> InteractiveDrawCoordinator.handlePointer(...) -> _handleUp(...) -> InteractiveDrawTerminalRouter.handleUp(...)`
- failing stroke path:
  `InteractiveDrawTerminalRouter.handleUp(...) -> InteractiveDrawStrokeEngine.commitOnUp(...) -> commitDrawStroke(...) or emitStrokeCommit(...) throws -> router cleanup and stroke-local buffer cleanup are skipped`
- failing dragged-line path:
  `InteractiveDrawTerminalRouter.handleUp(...) -> InteractiveDrawLineEngine.commitOnUp(...) -> _commitDraggedLine(...) -> _emitLineCommit(...) throws -> line pending-line cleanup and router cleanup are skipped`
- failing eraser path:
  `InteractiveDrawTerminalRouter.handleUp(...) -> InteractiveDrawEraserEngine.commitOnUp(...) -> _eraseAnnotations(...) or commitEraseNodes(...) throws -> eraser-local buffer cleanup and router cleanup are skipped`
- failing eraser action-emission path:
  `InteractiveDrawTerminalRouter.handleUp(...) -> InteractiveDrawEraserEngine.commitOnUp(...) -> emitEraseCommit(...) throws -> router cleanup is skipped`

### Current Owner

- `InteractiveDrawCoordinator` / `InteractiveDrawTerminalRouter` own draw
  gesture terminal orchestration and shared draw-session state exposure
- `InteractiveDrawStrokeEngine` owns stroke preview points and local path
  buffer cleanup
- `InteractiveDrawLineEngine` owns active line preview and owner-scoped pending
  two-tap line state
- `InteractiveDrawEraserEngine` owns eraser path-buffer cleanup and eraser
  debug counters
- `SceneControllerMutationBoundary` owns committed draw writes only and does
  not own any draw-session cleanup state

### Adjacent Abstractions

- `lib/src/interactive/internal/interactive_runtime.dart` - adjacent runtime
  owner that guarantees pointer normalizer cleanup in `finally` while allowing
  downstream exceptions to propagate
- `lib/src/interactive/internal/interactive_gesture_router.dart` - adjacent
  gesture-family router that already interrupts active gesture ownership from
  `finally` on terminal samples
- `lib/src/interactive/internal/interactive_draw_action_emitter.dart` -
  adjacent action projection helper used by stroke, line, and eraser terminal
  paths
- `lib/src/interactive/internal/scene_controller_mutation_boundary.dart` -
  adjacent committed-write seam used by draw callbacks but intentionally not a
  gesture-state owner
- `lib/src/interactive/internal/interactive_move_session.dart` - adjacent
  interactive terminal precedent that already uses owner-level `finally`
  cleanup

### Existing Tests

- `test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart`
  - proves drag-line, two-tap pending-line, and draw-style snapshot behavior
- `test/interactive/core/scene_controller_interactive_guardrails_line_test.dart`
  - proves line preview stays ephemeral until terminal commit
- `test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart`
  - proves stroke preview is visible during drag and clears on successful up
- `test/interactive/core/interactive_draw_eraser_engine_test.dart` - proves
  direct eraser `commitOnUp(...)` behavior over owner-local engine seams
- `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
  - proves current direct draw router/engine fixture wiring and invalid
  terminal router semantics
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` - proves
  the interaction family ownership split through the existing guardrail runner

### Analogous Implementation Path

- `lib/src/interactive/internal/interactive_move_session.dart` - closest valid
  precedent because `_moveHandleUp(...)` already wraps terminal commit in
  `try/finally` at the state-owning seam and rethrows commit failures after
  cleanup
- `lib/src/interactive/internal/scene_controller_pointer_session.dart` -
  nearby precedent for boundary-crossing terminal cleanup that uses `finally`
  to keep local terminal lifecycle state consistent when forwarding throws

### Governing Repository Rules

- `AGENTS.md` - fix the root cause at the owning seam rather than patching one
  downstream caller
- `AGENTS.md` - when stable behavioral constraints matter, keep them enforced
  by repository-local tests and tooling rather than prose-only reminders
- `AGENTS.md` and repository verification instructions - bug fixes require
  automated regression proof and final verification through the required
  verification preset
- `ARCHITECTURE.md` - `interactive/**` owns controller-side gesture state while
  `SceneControllerMutationBoundary` remains the only interactive owner that
  performs committed mutation work
- `docs/architecture/families/interaction_runtime.md` - keep draw runtime
  state in the interaction family and do not expand the draw subsystem into a
  new owner family or seam
- `tool/invariant_registry.dart` - `INV-ENG-INTERACTIVE-POINTER-SESSION-LIFECYCLE`
  is already the lifecycle owner for exception-safe terminal cleanup policy
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_draw_rules.dart`
  - `InteractiveDrawCoordinator` must remain a draw-family orchestrator and not
  re-own eraser geometry

### Rejected Misleading Local Patterns

- new coordinator-owned terminal commit API that re-centralizes all draw
  cleanup - wrong scope for this bug-fix step because it changes draw
  ownership form, crosses tool-local state contracts, and is not required to
  close `KI-3`
- move cleanup into `SceneControllerMutationBoundary` - wrong owner because the
  boundary does not own draw session, preview, pending-line, or tool-local
  buffers
- move cleanup into the view host or pointer-session boundary - wrong seam
  because `KI-3` is inside the draw runtime family, not the pointer host
- swallow terminal exceptions after cleanup - wrong behavior because current
  runtime semantics intentionally allow terminal commit failures to propagate
- patch only one tool path and leave the other draw terminal owners unchanged -
  incomplete root-cause fix because the audits already prove this is a shared
  draw terminal cleanup family

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- draw-family terminal lifecycle hardening inside the existing interactive
  runtime owners

#### Selected Architectural Form

- keep the current draw-family owner split unchanged:
  `InteractiveDrawCoordinator` remains the orchestrator,
  `InteractiveDrawTerminalRouter` remains the shared terminal router, and each
  draw engine keeps its own tool-local terminal state
- make shared draw terminal cleanup exception-safe in
  `InteractiveDrawTerminalRouter.handleUp(...)` with `finally` so
  `gestureSession.clear()` and line preview reset always run after any `up`
  path, including failing stroke, line, eraser, or eraser action-emission
  paths
- make tool-local terminal cleanup exception-safe in the owning engine methods
  with `finally` so owner-local buffers and pending state are cleared at the
  owner seam rather than by the router or mutation boundary
- preserve the current line two-tap ownership contract:
  only the dragged-line terminal path gains guaranteed cleanup-after-failure;
  the first-tap pending-line installation and same-session second-tap commit
  semantics stay owner-local and unchanged on successful paths
- preserve current exception behavior:
  commit or action-emission failures still escape to the caller after cleanup
  completes

#### Owning Layer or Module

- primary shared terminal owner:
  `lib/src/interactive/internal/interactive_draw_terminal_router.dart`
- primary tool-local terminal owners:
  `lib/src/interactive/internal/interactive_draw_stroke_engine.dart`,
  `lib/src/interactive/internal/interactive_draw_line_engine.dart`, and
  `lib/src/interactive/internal/interactive_draw_eraser_engine.dart`
- no ownership transfer to `InteractiveDrawCoordinator`,
  `SceneControllerMutationBoundary`, `InteractiveRuntime`, or view-layer files

#### Dependency Direction

- `InteractiveRuntime` ->
  `InteractiveGestureRouter` ->
  `InteractiveDrawCoordinator` ->
  `InteractiveDrawTerminalRouter` / draw engines
- draw engines continue to depend on callback seams for committed writes and
  action emission; no new dependency is introduced from draw owners back into
  mutation-boundary or view internals
- structural verification continues to depend on the existing audit and
  guardrail tools rather than new ad hoc runtime hooks

#### State and Data Ownership

- `InteractiveDrawGestureSession` remains shared draw-session state owned by
  the draw terminal owner path
- stroke and eraser path buffers remain local to their respective engines
- active line preview and owner-scoped pending-line state remain owned by
  `InteractiveDrawLineEngine`
- action emission remains on the existing draw action emitter path
- committed scene mutation and repaint invalidation remain owned by
  `SceneControllerMutationBoundary`

#### Entry and Exit Boundaries

- entry boundary for this defect family:
  `InteractiveDrawCoordinator.handlePointer(...)` on terminal `PointerPhase.up`
- shared owner boundary:
  `InteractiveDrawTerminalRouter.handleUp(...)`
- tool-local owner boundaries:
  `InteractiveDrawStrokeEngine.commitOnUp(...)`,
  `InteractiveDrawLineEngine._commitDraggedLine(...)`, and
  `InteractiveDrawEraserEngine.commitOnUp(...)`
- exit boundary:
  shared draw-session state and tool-local terminal state are cleaned, while
  the original exception still propagates to the caller

#### Permitted Extension Seam

- `try/finally` ordering changes inside the existing router and engine owner
  methods are allowed
- one new focused owner-level regression suite,
  `test/interactive/core/interactive_draw_terminal_cleanup_test.dart`, owns
  the direct `KI-3` reproducers
- the implementation must update family status, known-issue tracking,
  `README.md`, `API_GUIDE.md`, and release notes in slice 3
- no new public API, no new mutation-boundary callback, and no new draw owner
  class are allowed in this step

#### Rejected Alternatives

- consolidate all terminal draw commit into a new coordinator-owned API -
  rejected because it changes ownership form, pulls tool-local cleanup out of
  its current owners, and is broader than the minimum fix for `KI-3`
- move all cleanup into `SceneControllerMutationBoundary` - rejected because
  the boundary owns committed writes, not draw-session or preview state
- move all cleanup into `InteractiveRuntime` or `InteractiveGestureRouter` -
  rejected because the current defect sits below those owners in the more
  specific draw-family terminal seams
- fix only the router and leave engine-local cleanup after hazardous commits -
  rejected because stroke, line, and eraser each own local state that the
  router cannot correctly normalize without leaking tool-specific policy

#### Why This Level Is Correct

- `KI-3` is not a write-boundary bug or a view-host bug; it is a draw terminal
  lifecycle bug in ephemeral interactive state
- the current owners already separate shared draw-session cleanup from
  tool-local cleanup, so adding `finally` at those exact seams repairs the
  shared defect without reopening ownership
- the repository already accepts this pattern in the move family, and the
  existing audits point directly at the same owner level for the draw family

### 4B. Architecture Decision Gate

Not used. The architectural form is locked in 4A.

## 5. Locked Decisions

1. The first reproducer suite is owner-level and uses existing direct
   router/engine seams with throwing callbacks; it does not depend on a wider
   controller integration rewrite.
2. Router cleanup must be proven on both a failing stroke path and a failing
   eraser action-emission path, because those are distinct hazardous branches
   under the shared draw terminal owner.
3. Stroke and eraser engine reproducers must prove local buffer cleanup after
   thrown commit/action paths, not just successful terminal cleanup.
4. Line reproducers must prove cleanup for the dragged-line failing terminal
   path while preserving the existing successful first-tap pending-line and
   same-session second-tap ownership semantics.
5. Existing standalone audits remain the structural enforcement for this bug
   class; do not change audit or guardrail code in this step.
6. Repository tracking closes `KI-3` only in the same implementation change
   that lands regression proof and makes both standalone audits green.

## 6. Result Requirements

1. After any failing draw terminal `up` path, shared draw gesture state does
   not survive into the next gesture.
2. After any failing stroke or eraser terminal commit path, the tool-local path
   buffer is cleared before the exception escapes.
3. After any failing dragged-line terminal commit path, owner-scoped pending
   line cleanup runs exactly where the successful dragged-line contract already
   requires it.
4. Successful line first-tap pending installation, line second-tap commit,
   captured draw-style snapshots, and preview-until-up behavior remain
   unchanged.
5. Draw terminal commit or action-emission exceptions still propagate after
   cleanup; the change adds cleanup, not error suppression.
6. `tool/audit_terminal_cleanup_safety.dart` and
   `tool/audit_post_commit_cleanup_order.dart` no longer report the draw-family
   detections named by `KI-3`.
7. `KNOWN_ISSUES.md`, the interaction-runtime family status, `README.md`,
   `API_GUIDE.md`, and release notes all describe the landed exception-safe
   draw terminal cleanup behavior consistently.

## 7. Execution Order and Gates

### Required Order

- add one focused failing reproducer suite plus 1 to 3 neighboring guard tests
  for the current draw owner seams before changing production code
- land the minimum router and engine `finally` cleanup in the existing owners;
  do not widen the coordinator or callback seams during the bug fix
- prove line pending-line success semantics still hold after the line owner fix
  before closing the draw-family implementation slices
- update known-issue tracking, family status, `README.md`, `API_GUIDE.md`,
  release notes, and step status only after the behavioral proof and both
  standalone audits are green

### Successor Seam and Retirement Gates

- no successor seam is introduced in this step; the existing router/engine
  owner split remains authoritative
- retirement gate:
  do not add or keep any experimental coordinator-owned terminal API once the
  existing owner-level `finally` form is proven
- issue-closure gate:
  remove `KI-3` only after the owner-level regression tests pass and both
  standalone audits stop reporting the named draw-family detections
- tooling gate:
  if the current audits cannot represent the landed owner form without code
  changes, stop implementation and write a new contract for audit widening

### Deferred Broad Verification

- reserve `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`
  for the final implementation gate with the final repo-relative changed path
  list fed on stdin
- reserve broad repository audit bundles for the final gate if they still
  include unrelated active known issues during slice work

## 8. File Map

### Implementation Files

- `lib/src/interactive/internal/interactive_draw_terminal_router.dart`
- `lib/src/interactive/internal/interactive_draw_stroke_engine.dart`
- `lib/src/interactive/internal/interactive_draw_line_engine.dart`
- `lib/src/interactive/internal/interactive_draw_eraser_engine.dart`

### Test Files

- `test/interactive/core/interactive_draw_terminal_cleanup_test.dart`
- `test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart`
- `test/interactive/core/scene_controller_interactive_guardrails_line_test.dart`
- `test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart`
- `test/interactive/core/interactive_draw_eraser_engine_test.dart`

### Fixtures and Supporting Data

- no new external fixture files are allowed; use inline throwing callbacks and
  direct draw-owner instances inside
  `test/interactive/core/interactive_draw_terminal_cleanup_test.dart`

### Registry, Inventory, and Workflow Files

- `docs/architecture/families/interaction_runtime.md`
- `README.md`
- `API_GUIDE.md`
- `KNOWN_ISSUES.md`
- `CHANGELOG.md`
- `PLAN.md`
- `plan/step_32_exception_safe_draw_terminal_cleanup.md`

### Analysis Area

- `tool/audit_terminal_cleanup_safety.dart` and
  `tool/audit_post_commit_cleanup_order.dart` - verification-only in this step
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` - existing
  ownership split regression that must stay green without step-local changes

## 9. Implementation Rules

### Protected Invariants

- `INV-ENG-INTERACTIVE-POINTER-SESSION-LIFECYCLE`
- `INV-ENG-INTERACTIVE-PREVIEW-COMMIT-ON-UP`
- `INV-ENG-INTERACTIVE-DRAW-STYLE-SNAPSHOT`
- `INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY`
- `INV-ENG-INTERACTIVE-MUTATION-BOUNDARY`

### Required Proof

- behavioral proof:
  one focused failing reproducer suite for stroke, dragged line, eraser, and
  router-owned draw cleanup, plus 1 to 3 neighboring guard tests covering
  successful first-tap pending-line retention, successful draw preview cleanup
  on `up`, and preserved exception propagation
- structural proof:
  run `tool/audit_terminal_cleanup_safety.dart` and
  `tool/audit_post_commit_cleanup_order.dart` against each touched draw owner
  slice and against `lib/src` at final gate; keep `dart run tool/check_guardrails.dart`
  green for the unchanged draw-family ownership split
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard
  tests for neighboring branches of the same contract
- for refactors: existing locking tests must be named or missing
  characterization tests must be added before structural edits, plus 1 to 3
  guard tests for neighboring branches when needed

### Allowed Change Surface

- add `try/finally` cleanup only at the current draw terminal owners
- add or refine owner-level interactive tests needed to reproduce and guard the
  exception-safe cleanup contract
- update family status, known-issue tracking, `README.md`, `API_GUIDE.md`,
  release notes, and plan status after proof is green

### Forbidden Moves

- do not add a new draw coordinator terminal API in this step
- do not move draw-session, pending-line, or path-buffer ownership to
  `SceneControllerMutationBoundary`, `InteractiveRuntime`, or the view layer
- do not catch-and-return from failing terminal commit paths
- do not weaken or bypass the existing standalone audits to make the issue
  disappear mechanically without owner-side cleanup
- do not broaden this fix into eraser geometry ownership, draw coordinator
  architecture, or mutation callback redesign
- if the landed owner form would require audit or guardrail code changes, stop
  and open a separate contract instead of widening this step

## 10. Vertical Slices

### Slice 1. [ ] Reproduce and close shared router plus stroke cleanup

#### Slice Contract

Shared draw-session cleanup and stroke-local terminal buffer cleanup stay
correct even when the stroke terminal commit path throws.

#### Change

- add a focused owner-level failing reproducer for a stroke terminal throw that
  currently leaves shared draw-session cleanup and stroke-local buffer cleanup
  dependent on success
- add neighboring guard proof for preserved exception propagation and for the
  existing successful stroke-preview cleanup path
- land the minimum `finally` cleanup in
  `InteractiveDrawTerminalRouter.handleUp(...)` and
  `InteractiveDrawStrokeEngine.commitOnUp(...)`
- add the router-level eraser action-emission throw guard in
  `test/interactive/core/interactive_draw_terminal_cleanup_test.dart` so the
  shared router cleanup proof lives in one focused owner-level suite

#### Behavioral Verification

- `flutter test --no-pub test/interactive/core/interactive_draw_terminal_cleanup_test.dart`
- `flutter test --no-pub test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart`

#### Structural Verification

- `dart run tool/audit_terminal_cleanup_safety.dart lib/src/interactive/internal/interactive_draw_terminal_router.dart`
- `dart run tool/audit_terminal_cleanup_safety.dart lib/src/interactive/internal/interactive_draw_stroke_engine.dart`
- `dart run tool/audit_post_commit_cleanup_order.dart lib/src/interactive/internal/interactive_draw_terminal_router.dart`
- `dart run tool/audit_post_commit_cleanup_order.dart lib/src/interactive/internal/interactive_draw_stroke_engine.dart`
- `dart run tool/check_guardrails.dart`

#### Fixtures Used

- direct draw-owner instances and inline throwing callbacks in
  `test/interactive/core/interactive_draw_terminal_cleanup_test.dart`

#### Positive Scenarios

- failing stroke commit still clears shared draw-session state
- failing stroke commit still clears the stroke path buffer
- successful stroke preview still clears on `up`

#### Negative Scenarios

- stroke terminal exception still propagates after cleanup
- no new coordinator-owned terminal API or callback seam is introduced

#### Closure Evidence

- new stroke/router reproducers are green
- targeted standalone audits no longer report the router/stroke findings

### Slice 2. [ ] Reproduce and close line plus eraser owner cleanup

#### Slice Contract

Dragged-line and eraser terminal owner cleanup stay correct when their terminal
commit paths throw, without changing successful pending-line or preview
semantics.

#### Change

- add failing owner-level reproducers for dragged-line terminal throw and
  eraser terminal throw
- add neighboring guard proof for successful first-tap pending-line retention,
  successful second-tap line commit semantics, and successful eraser cleanup
- land the minimum owner-side `finally` cleanup in
  `InteractiveDrawLineEngine._commitDraggedLine(...)` and
  `InteractiveDrawEraserEngine.commitOnUp(...)`

#### Behavioral Verification

- `flutter test --no-pub test/interactive/core/interactive_draw_terminal_cleanup_test.dart`
- `flutter test --no-pub test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart`
- `flutter test --no-pub test/interactive/core/interactive_draw_eraser_engine_test.dart`

#### Structural Verification

- `dart run tool/audit_terminal_cleanup_safety.dart lib/src/interactive/internal/interactive_draw_line_engine.dart`
- `dart run tool/audit_terminal_cleanup_safety.dart lib/src/interactive/internal/interactive_draw_eraser_engine.dart`
- `dart run tool/audit_post_commit_cleanup_order.dart lib/src/interactive/internal/interactive_draw_line_engine.dart`
- `dart run tool/check_guardrails.dart`

#### Fixtures Used

- direct draw-owner instances and inline throwing callbacks in
  `test/interactive/core/interactive_draw_terminal_cleanup_test.dart`

#### Positive Scenarios

- failing dragged-line commit clears the line owner state that the successful
  dragged-line contract already retires
- successful first tap still installs a pending line for the owning session
- successful second tap still commits through the existing owner path
- failing eraser commit clears the eraser path buffer

#### Negative Scenarios

- line terminal exception still propagates after cleanup
- eraser terminal exception still propagates after cleanup
- first-tap pending-line installation is not accidentally cleared by the
  dragged-line fix

#### Closure Evidence

- new line/eraser reproducers and neighboring guards are green
- targeted standalone audits no longer report the line/eraser findings

### Slice 3. [ ] Close repository proof and issue tracking for KI-3

#### Slice Contract

Repository source-of-truth, release tracking, and final verification all agree
that draw terminal cleanup is now exception-safe at the accepted owner seam.

#### Change

- update `docs/architecture/families/interaction_runtime.md` status and any
  affected owner notes so the family no longer tracks `KI-3` as open
- update `README.md` and `API_GUIDE.md` to describe the observable runtime
  guarantee that failing draw terminal commits still clean draw state before
  rethrow
- remove `KI-3` from `KNOWN_ISSUES.md`
- add the unreleased changelog entry
- update `PLAN.md` and this step file when the implementation is complete

#### Behavioral Verification

- `flutter test --no-pub test/interactive/core/interactive_draw_terminal_cleanup_test.dart test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart test/interactive/core/scene_controller_interactive_guardrails_line_test.dart test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart test/interactive/core/interactive_draw_eraser_engine_test.dart`

#### Structural Verification

- `dart run tool/audit_terminal_cleanup_safety.dart lib/src`
- `dart run tool/audit_post_commit_cleanup_order.dart lib/src`
- `dart run tool/check_guardrails.dart`

#### Fixtures Used

- no new fixtures; slice closes documentation and proof tracking around the
  landed implementation

#### Positive Scenarios

- no active `KI-3` entry remains after the code proof is green
- interaction-runtime source-of-truth no longer describes draw terminal
  cleanup as an open issue
- public-facing docs describe the new exception-safe draw terminal cleanup
  behavior consistently with the landed runtime behavior

#### Negative Scenarios

- no issue closure lands without behavioral proof and green audits
- no architecture claim is widened beyond the current draw-family owner split

#### Closure Evidence

- `KNOWN_ISSUES.md` no longer lists `KI-3`
- final targeted tests and final structural checks are green
- plan status and source-of-truth files match the landed implementation

## 11. Final Verification

- `flutter test --no-pub test/interactive/core/interactive_draw_terminal_cleanup_test.dart`
- `flutter test --no-pub test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart test/interactive/core/scene_controller_interactive_guardrails_line_test.dart test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart test/interactive/core/interactive_draw_eraser_engine_test.dart`
- `dart run tool/audit_terminal_cleanup_safety.dart lib/src`
- `dart run tool/audit_post_commit_cleanup_order.dart lib/src`
- `dart run tool/check_guardrails.dart`
- feed the final repo-relative changed path list on stdin to
  `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`

## 12. Acceptance Criteria

- draw terminal commit or action-emission failures no longer leave shared draw
  session state, tool-local buffers, or dragged-line cleanup state behind
- successful stroke, line, and eraser flows still satisfy the existing preview
  and pending-line behavioral contracts
- the existing draw-family ownership split remains intact; no new coordinator,
  mutation-boundary, or view-layer ownership is introduced
- `tool/audit_terminal_cleanup_safety.dart` and
  `tool/audit_post_commit_cleanup_order.dart` are green for `lib/src`
- `KI-3` is removed from `KNOWN_ISSUES.md` only in the same change as green
  regression proof and final verification
