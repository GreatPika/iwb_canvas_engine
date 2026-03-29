language: russian

# Шаг 39. Разрезать `PointerInputTracker` на focused pointer-local state owner-ы

## 1. Change Mandate

Этот шаг разрезает `PointerInputTracker` на focused pointer-local state owner-ы
так, чтобы active down/slop tracking и deferred tap-window lifecycle больше не
жили в одном монолитном tracker owner.

## 2. Change Boundary

### Included in the Change

- `PointerInputTracker` orchestration ownership in `lib/src/core/pointer_input.dart`.
- Active pointer down/slop state ownership beneath the tracker.
- Pending tap / double-tap window state ownership beneath the tracker.
- Structural proof and architecture-doc updates required to pin the final
  pointer-input owner shape.

### Not Included in the Change

- `SceneViewPointerRouter` slot-allocation ownership.
- Interactive gesture routing, pointer normalization, or controller runtime
  ownership outside the direct verification surfaces.
- Public export changes for `PointerInputSettings` or
  `lib/iwb_canvas_engine.dart`.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/core/pointer_input.dart`
- `ARCHITECTURE.md`
- `PLAN.md`

### Test Files

- `test/core/pointer_input_test.dart`
- `test/view/scene_view_interactive_test.dart`

### Fixture and Supporting Data Files

- `plan/step_39_pointer_input_tracker_owner_decomposition.md`

### Analysis Area

- `lib/src/core/pointer_input.dart`
- `test/core/pointer_input_test.dart`
- `test/view/scene_view_interactive_test.dart`
- `ARCHITECTURE.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to one pointer-input owner
  slice.
- Every modified test must be tied to one behavioral or structural
  verification.
- Every modified documentation file must pin one final pointer-input owner
  boundary.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `PointerInputSettings` remains the public pointer-input configuration
   surface exported from `lib/iwb_canvas_engine.dart`.
2. `PointerInputTracker` remains a scene-model-agnostic core owner reusable by
   view and interactive hosts.
3. Base lifecycle signal emission order and deferred tap / double-tap semantics
   remain behaviorally equivalent.
4. Pointer-input settings validation remains a runtime boundary check owned by
   `lib/src/core/pointer_input.dart`.

## 5. Result Requirements

1. `PointerInputTracker` no longer directly owns active down/slop tracking and
   pending tap-window lifecycle in one monolithic body.
2. Focused pointer-local state owners beneath `PointerInputTracker` are explicit
   and single-purpose.
3. No accepted residual `HIGH` metric after closure may belong to the current
   monolithic `PointerInputTracker` shape.
4. Existing core and view consumers remain behaviorally equivalent, and the
   public `PointerInputSettings` surface remains unchanged.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `lib/src/core/pointer_input.dart` currently has `328` lines.
- `dcm calculate-metrics lib/src/core/pointer_input.dart --report-all`
  currently reports one `HIGH` metric:
  `PointerInputTracker.weighted-methods-per-class = 38`.
- The current hotspot is concentrated in one owner:
  `handle(...)`,
  `_handleTap(...)`,
  and
  `_flushExpiredTo(...)`
  keep the two internal state machines in the same class.
- No clone hotspot currently justifies this follow-up; the value of the step is
  ownership decomposition, not clone compression.
- Existing proofs already pin
  `INV-ENG-POINTER-SETTINGS-VALIDATION`
  and
  `INV-ENG-VIEW-POINTER-SETTINGS-LIVE-APPLY`.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/core/pointer_input.dart --report-all`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/core/pointer_input_test.dart`
- MCP test runner: `test/view/scene_view_interactive_test.dart`

### 6.3 Protected States, Data, or Structures

- `PointerInputSettings` validation semantics.
- Base down/move/up/cancel signal emission order.
- Pending single-tap flush semantics.
- Double-tap delay and slop semantics.
- Existing `SceneViewInteractive` integration behavior.

### 6.4 Allowed Semantic Change Zones

- Pointer-input orchestration inside `PointerInputTracker`.
- Active pointer down/slop state ownership.
- Pending tap / double-tap window ownership.
- Structural proofs and architecture documentation for the final pointer-input
  owner graph.

### 6.8 Prohibited

- Moving pointer signal derivation into `view/**` or `interactive/**`.
- Expanding the public pointer-input API to reduce tracker complexity.
- Introducing async timers, background jobs, or host-owned sync glue inside the
  core tracker.
- Changing tap or double-tap semantics merely to reduce the metric hotspot.

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

### Slice 1. [x] Pending tap-window owner is isolated

#### Slice Contract

Deferred tap / double-tap window lifecycle no longer lives directly inside the
monolithic `PointerInputTracker` body.

#### Change

Extract the pending tap-window lifecycle behind one focused pointer-local state
owner beneath `PointerInputTracker` while preserving the current tap and
double-tap semantics.

#### Verification

- `dcm calculate-metrics lib/src/core/pointer_input.dart --report-all`
- MCP test runner: `test/core/pointer_input_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Deferred tap flush and double-tap semantics stay green after the owner split.

### Slice 2. [x] Active pointer state owner is isolated and tracker becomes a shell

#### Slice Contract

Active down/slop tracking no longer lives directly inside the monolithic
`PointerInputTracker` body, and the tracker becomes a thin orchestration shell
over focused pointer-local state owners.

#### Change

Extract active pointer down/slop state into a focused owner, reduce
`PointerInputTracker` to orchestration over the focused state owners, and pin
the final owner graph in docs and proofs.

#### Verification

- `dcm calculate-metrics lib/src/core/pointer_input.dart --report-all`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/core/pointer_input_test.dart`
- MCP test runner: `test/view/scene_view_interactive_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `PointerInputTracker` no longer remains a `HIGH` metric hotspot in its
  current monolithic form.

## 9. Final Verification

- `dcm calculate-metrics lib/src/core/pointer_input.dart --report-all`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/core/pointer_input_test.dart`
- MCP test runner: `test/view/scene_view_interactive_test.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
