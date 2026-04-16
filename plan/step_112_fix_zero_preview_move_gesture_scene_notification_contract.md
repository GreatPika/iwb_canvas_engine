language: english

# Change Contract

## 1. Change Mandate
This change fixes false scene-state notifications for move gestures with zero
preview delta by separating gesture ownership from observable scene-effect
signals.

## 2. Change Boundary

### Included in the Change
- Move-session notification routing for `down`, terminal, cancel, interruption,
  and owning-session detach paths when move preview delta remains zero.
- Move-preview state contract adjustments so gesture capture state is not used
  as a scene-change signal.
- Regression tests that lock listener/repaint behavior for zero-preview move
  gestures.
- Structural assertions that prove move notification decisions no longer read
  preview activation state.
- Public behavior and architecture source-of-truth updates for the corrected
  zero-preview move notification contract.

### Not Included in the Change
- Changes to draw-mode gesture signaling and draw preview semantics.
- Changes to move commit math, move commit resolver behavior, or action payload
  structure.
- Public API changes in `SceneControllerInteraction` or exported package
  signatures.
- Rendering pipeline refactors outside interactive move notification ownership.
- New public listener ordering guarantees beyond the existing deferred and
  coalesced notification contract.

## 3. File Map and Analysis Areas

### Implementation Files
- `lib/src/interactive/internal/interactive_move_session.dart`
- `lib/src/interactive/internal/interactive_move_preview_state.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Test Files
- `test/interactive/core/interactive_move_session_test.dart`
- `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
- `test/interactive/core/scene_controller_public_listener_contract_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`

### Analysis Area
- `lib/src/interactive/internal/interactive_move_{session,preview_state}.dart`
- `test/interactive/core/{interactive_move_session,scene_controller_interactive_move_preview_invariants,scene_controller_public_listener_contract,scene_controller_architecture_boundary}_test.dart`

### Outside the Change Boundary
- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every newly proposed file or directory name must comply with the global
  `AGENTS.md` section `### File naming`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Scene-state notifications in move mode are allowed only for observable
   scene/read-side effects, not for gesture claim alone.
2. `down -> up` on an already selected movable node without crossing drag start
   threshold must not emit `onSceneStateChanged`.
3. Terminal, cancel, interruption, and owning-session detach paths must report
   `scene: false` when move preview delta remained zero for the whole gesture.
4. Existing behavior that emits scene notifications for non-zero move preview
   deltas remains valid and must be preserved.
5. The fix must remain local to interactive move internals and must not change
   public APIs.
6. `InteractiveMovePreviewState` remains the owner of move-preview effect
   semantics. `InteractiveMoveSession` derives scene-effect decisions from
   `InteractiveMovePreviewState.hasSceneEffect` only, not from preview lifecycle
   fields and not from gesture ownership fields.

## 5. Result Requirements

1. Move `down` on an already selected movable node does not trigger scene
   repaint/public scene notify unless a real preview translation or selection
   change occurs.
2. Terminal cleanup after a zero-preview move gesture does not mark scene
   change.
3. Cancel/interruption/detach after a zero-preview move gesture do not mark
   scene change.
4. Non-zero move preview translation still triggers scene-change signaling and
   remains visible through preview resolver until terminal cleanup.
5. Regression coverage proves the zero-preview no-notify contract at session
   unit level and controller listener/repaint level.
6. No code under `lib/src/interactive/internal/**` uses
   `InteractiveMovePreviewState.isActive` or `_previewState.isActive` after this
   step.
7. README, API guide, architecture, and changelog text describe the corrected
   zero-preview move notification behavior without promising listener ordering
   beyond the existing deferred/coalesced contract.

## 6. Implementation Specification

### 6.1 Analysis Scope
- Keep `InteractiveMoveGestureState` pointer ownership semantics intact.
- Treat preview activity (`gesture is active`) and preview effect (`scene shift
  exists`) as separate concepts.
- Keep move commit path unchanged except where it depends on the corrected
  preview effect contract.
- Keep `InteractiveMoveHitTestEngine` preview-hit behavior based on
  `InteractiveMovePreviewState.hasTranslation`; hit-testing still needs the
  shifted geometry probe only after a non-zero preview delta exists.

### 6.2 Target Verification Units
- `test/interactive/core/interactive_move_session_test.dart` for callback-level
  scene-notify behavior in zero-preview and non-zero-preview paths.
- `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
  for cancel/terminal behavior and preview contract continuity.
- `test/interactive/core/scene_controller_public_listener_contract_test.dart`
  for public-listener and repaint-channel behavior.
- `test/interactive/core/scene_controller_architecture_boundary_test.dart` for
  structural assertions that prevent notification logic from reading preview
  activation state again.

### 6.3 Protected States, Data, or Structures
- Active-gesture ownership and single-pointer routing semantics.
- Move preview delta accumulation and commit-on-up behavior.
- Existing selection baseline restore semantics on cancel/interrupt flows.

### 6.4 Allowed Semantic Change Zones
- Move preview state read/write contract used to derive scene-change decisions.
- Move session notification decisions in `down`, `move`, `up`, `cancel`,
  interruption, and detach terminalization paths.
- Test assertions for listener/repaint signaling in zero-preview move gestures.
- Structural tests that inspect the move preview/session source text for the
  forbidden activation-as-scene-signal forms.
- Documentation and changelog wording for the user-visible listener/repaint
  behavior and the internal move preview effect ownership rule.

### 6.5 Required Move Preview State Contract
- `InteractiveMovePreviewState.start(Set<NodeId> nodeIds)` must return `void`.
  It must set `_active = true`, `_delta = Offset.zero`, and `_nodeIds` to a
  defensive copy of `nodeIds`, and it must not return a value that callers can
  interpret as a scene-change result.
- `InteractiveMovePreviewState` must expose
  `bool get hasSceneEffect => hasTranslation;` as the canonical query for
  notification decisions.
- `InteractiveMovePreviewState.isActive` must be removed. The existing `_active`
  field remains private to `interactive_move_preview_state.dart` and must not be
  readable from `InteractiveMoveSession`.
- `InteractiveMovePreviewState.advance(...)` must keep returning `false` for a
  zero delta step and `true` after it accumulates a non-zero delta step.
- `InteractiveMovePreviewState.deltaForNode(...)` must keep returning
  `Offset.zero` for inactive previews, untracked nodes, and tracked nodes whose
  accumulated delta is zero.

### 6.6 Required Move Session Contract
- `InteractiveMoveSession.handlePointer(...)` must not call
  `callbacks.onSceneStateChanged()` from the `PointerPhase.down` branch.
- `InteractiveMoveSession._moveHandleDown(Offset scenePoint)` must return
  `void`. For a selected movable hit, it must set the move target and call
  `_previewState.start(previewNodeIds)` without returning any scene-change
  signal.
- `_advanceMovePreview(...)` remains the only move-session path where a move
  event turns preview advancement into a scene-change notification.
- `_resetGestureStateForTerminal()` must snapshot
  `_previewState.hasSceneEffect` and `_gestureState.selectionRect != null`
  before calling `resetGestureState()`, then return those captured values.
- `_restoreAndClearGestureState()` must continue to restore the selection
  baseline before delegating to `_resetGestureStateForTerminal()`.
- The implementation must not add a separate boolean flag to
  `InteractiveMoveSession` to remember whether preview moved; the accumulated
  preview delta in `InteractiveMovePreviewState` is the single source of truth
  for move-preview scene effect.

### 6.8 Prohibited
- Using preview activation flags as a proxy for scene-change signaling.
- Emitting compensating scene notifications on terminal cleanup when no preview
  translation existed.
- Widening change scope into draw coordinator or non-move interaction families.
- Modifying public APIs to route around the bug instead of fixing move-internal
  ownership of scene-change semantics.
- Keeping `bool start(...)` on `InteractiveMovePreviewState`.
- Keeping `InteractiveMovePreviewState.isActive` as a public getter.
- Adding notification-specific shadow state outside
  `InteractiveMovePreviewState`.

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
9. The plan must be detailed enough that the implementing agent has no material
   branch in how to execute a slice.
10. Every newly proposed file or directory name must comply with the global
   `AGENTS.md` section `### File naming` before the slice is considered valid.
11. If implementation discovers that the required move preview/session contract
    cannot be satisfied without changing public APIs or non-move interaction
    families, implementation must stop and the plan must be revised before
    coding continues.

## 8. Vertical Slices

### Slice 1. [ ] Split Move Preview Activity From Scene Effect

#### Slice Contract
Move preview internals expose scene-effect semantics that are independent from
gesture activation state.

#### Change
- Change `InteractiveMovePreviewState.start(...)` from `bool` to `void`.
- Add `InteractiveMovePreviewState.hasSceneEffect` as a getter that returns
  `hasTranslation`.
- Remove `InteractiveMovePreviewState.isActive`.
- Change `InteractiveMoveSession._moveHandleDown(...)` from `bool` to `void`.
- Update the `PointerPhase.down` branch in
  `InteractiveMoveSession.handlePointer(...)` to call `_moveHandleDown(...)`
  without calling `callbacks.onSceneStateChanged()`.
- Keep move-preview translation accumulation behavior unchanged for non-zero
  move steps.
- Add a callback-level test harness in `interactive_move_session_test.dart` with
  one selected movable `RectNodeSnapshot`, a matching `SceneSpatialCandidate`,
  `readSelectedNodeIds` returning `{'node'}`, and
  `commitMoveSelection`/`emitAction` counters.

#### Verification
- `flutter test test/interactive/core/interactive_move_session_test.dart`

#### Positive Scenarios
- `down -> move` past `dragStartSlop` on the selected rect reports exactly one
  scene-change callback from the move event and leaves
  `movePreviewDeltaForNode('node')` non-zero before terminal cleanup.

#### Negative Scenarios
- `down -> up` on the selected rect without crossing `dragStartSlop` produces
  zero scene-change callbacks, zero commit calls, zero emitted actions, and
  `movePreviewDeltaForNode('node') == Offset.zero` after terminal cleanup.

#### Closure Evidence
- Green run of listed verification.
- Unit assertions showing zero-preview path does not emit scene callback,
  commit, or action.

### Slice 2. [ ] Normalize Terminal Scene Signaling For Zero-Preview Gestures

#### Slice Contract
Terminalization paths report scene change only when move preview produced a real
translation.

#### Change
- Change `_resetGestureStateForTerminal()` to capture
  `_previewState.hasSceneEffect` before `resetGestureState()` and use that
  captured value for the returned `scene` field.
- Keep `overlay` derived from `_gestureState.selectionRect != null` before
  reset.
- Add one controller-level test named
  `zero-preview move terminal paths do not schedule scene repaint` that exercises
  `up`, `cancel`, `interruptForInteractionConfigChange()`, and owning pointer
  session `dispose()` after a zero-preview move gesture on a selected movable
  node.

#### Verification
- `flutter test test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`

#### Positive Scenarios
- `cancel` after non-zero move preview clears preview and still causes the
  scene repaint needed to remove the visual preview.

#### Negative Scenarios
- `up`, `cancel`, interaction config interruption, and owning pointer session
  detach after zero-preview move gesture do not schedule scene repaint through
  terminal reset.

#### Closure Evidence
- Green run of listed verification.
- Assertions proving all listed zero-preview terminal paths do not mark scene
  changed.

### Slice 3. [ ] Enforce Move Preview Effect Ownership Structurally

#### Slice Contract
Repository-local structural tests reject the activation-as-scene-signal forms
that caused this bug class.

#### Change
- Add assertions in
  `test/interactive/core/scene_controller_architecture_boundary_test.dart` that
  read `interactive_move_preview_state.dart` and
  `interactive_move_session.dart`.
- Assert that `interactive_move_preview_state.dart` does not contain
  `bool get isActive`.
- Assert that `interactive_move_preview_state.dart` contains
  `bool get hasSceneEffect => hasTranslation;`.
- Assert that `interactive_move_preview_state.dart` does not contain
  `bool start(Set<NodeId> nodeIds)`.
- Assert that `interactive_move_session.dart` does not contain
  `_previewState.isActive`.
- Assert that `interactive_move_session.dart` contains
  `_previewState.hasSceneEffect`.
- Assert that `interactive_move_session.dart` does not contain the down-branch
  form `if (_moveHandleDown(scenePoint))`.

#### Verification
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`

#### Positive Scenarios
- The required `hasSceneEffect` ownership form is present.

#### Negative Scenarios
- The old `isActive`, `bool start(...)`, and down-branch scene-notify forms are
  absent.

#### Closure Evidence
- Green run of listed verification.
- Structural assertions fail if preview activation is reintroduced as a scene
  notification input.

### Slice 4. [ ] Lock Public Listener/Repaint Contract For Zero-Preview Move Tap

#### Slice Contract
Public and scene repaint channels remain silent for zero-preview move tap
gestures and still fire for real preview movement.

#### Change
- Add one listener-contract test named
  `zero-preview move tap does not notify public or repaint channels` that asserts
  no public/scene repaint notify on zero-preview move tap (`down -> up` without
  drag start).
- Preserve existing assertions for non-zero move preview repaint behavior.
- Keep existing proof marker coverage for
  `INV-ENG-INTERACTIVE-PUBLIC-LISTENER-REPAINT-INDEPENDENCE` in
  `scene_controller_public_listener_contract_test.dart` and do not widen
  `tool/invariant_registry.dart` in this step.
- The zero-preview listener test must create a `SceneController` with one
  `RectNodeSnapshot` equivalent production scene node, select it before
  listener counters are attached or reset counters after selection, send
  `down -> up` at the node position without any move sample, pump the event
  queue, and assert zero public notifications, zero scene repaints, and zero
  overlay repaints for that gesture.

#### Verification
- `flutter test test/interactive/core/scene_controller_public_listener_contract_test.dart`

#### Positive Scenarios
- Drag with non-zero preview delta still triggers one scene/public notify tick.

#### Negative Scenarios
- Tap gesture on selected movable node without drag start triggers zero
  public, scene repaint, and overlay repaint notifications after listener
  counters are reset.

#### Closure Evidence
- Green run of listed verification.
- Listener/repaint counters proving zero-preview no-notify behavior.

### Slice 5. [ ] Update Public And Architecture Documentation

#### Slice Contract
Repository source-of-truth documentation describes zero-preview move taps as
non-notifying no-op gestures while preserving the existing deferred/coalesced
listener contract.

#### Change
- Update `CHANGELOG.md` under `## Unreleased` with the user-visible fix:
  selected-node move taps without drag no longer trigger scene repaint/public
  scene-change listener activity.
- Update `API_GUIDE.md` in the listener notification and move behavior sections
  so zero-preview move taps are documented as no-op for scene repaint/listener
  purposes.
- Update `README.md` in the interactive runtime/listener behavior summary with
  the same user-visible rule.
- Update `ARCHITECTURE.md` in the interactive invariants/owner graph wording so
  `InteractiveMovePreviewState` owns move-preview scene-effect semantics and
  move gesture ownership is not a repaint signal.

#### Verification
- `rg -n "selected-node move taps without drag no longer trigger scene repaint" CHANGELOG.md`
- `rg -n "move taps without drag" README.md API_GUIDE.md`
- `rg -n "move gesture ownership is not a repaint signal" ARCHITECTURE.md`

#### Positive Scenarios
- Documentation states that non-zero move previews still notify/repaint through
  the scene channel.

#### Negative Scenarios
- Documentation does not describe gesture claim or preview activation as a
  public listener/repaint signal.

#### Closure Evidence
- Green run of listed verification.
- `CHANGELOG.md` contains one `## Unreleased` entry for this fix.

## 9. Final Verification

- `flutter test test/interactive/core/interactive_move_session_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `flutter test test/interactive/core/scene_controller_public_listener_contract_test.dart`
- `printf '%s\n' 'lib/src/interactive/internal/interactive_move_session.dart' 'lib/src/interactive/internal/interactive_move_preview_state.dart' 'test/interactive/core/interactive_move_session_test.dart' 'test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart' 'test/interactive/core/scene_controller_architecture_boundary_test.dart' 'test/interactive/core/scene_controller_public_listener_contract_test.dart' 'README.md' 'API_GUIDE.md' 'ARCHITECTURE.md' 'CHANGELOG.md' | dart run tool/run_verification_preset.dart run --preset required_code_change --changed-paths-file=-`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
