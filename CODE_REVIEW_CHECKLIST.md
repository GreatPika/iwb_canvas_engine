# Code Review Checklist

This document is a **maintainer checklist** for reviewing changes in this package.
The goal is to make “looks good” mean **objective, repeatable signals**: automated checks, tests, and explicit invariants.

If you discover a new class of defect, the end state should be: **a test, a tool check, or a documented invariant** that prevents it from returning.

---

## How to use this checklist (fast)

- [ ] Run all quality gates (Section 2)
- [ ] Identify which layer(s) the change touches (core / input / slices / render / view / serialization)
- [ ] Review only the relevant section(s) below, plus Section 6 (architecture invariants)

---

## Invariants → enforcement map (quick links)

- [ ] Layer import boundaries (core/input/render/serialization/view): `tool/check_import_boundaries.dart`
- [ ] Input slice boundaries (`slices/**`, `internal/**`): `tool/check_import_boundaries.dart`
- [ ] Invariant enforcement coverage (no orphan invariants): `tool/check_invariant_coverage.dart`
- [ ] Public entrypoints surface area: `test/entrypoints/basic_smoke_test.dart`, `test/entrypoints/advanced_smoke_test.dart`
- [ ] 100% line coverage for `lib/src/**`: `tool/check_coverage.dart`
- [ ] Notify semantics (immediate vs once-per-frame): `test/input/notify/notify_test.dart`
- [ ] Signals invariants (broadcast/sync/actionId): `test/input/signals/action_dispatcher_test.dart`
- [ ] ActionCommitted payload invariants: `test/input/signals/action_events_payload_test.dart`
- [ ] Pointer + gesture sequencing: `test/input/pointer/pointer_input_test.dart`, `test/input/edge_cases_test.dart`
- [ ] Repaint scheduling invariants: `test/input/repaint/repaint_scheduler_test.dart`
- [ ] Selection notify invariants: `test/input/selection/selection_notify_test.dart`, `test/input/commands/commands_test.dart`
- [ ] JSON schema validation + fixtures: `test/serialization/scene_codec_validation_test.dart`, `test/serialization/scene_v2_fixture_test.dart`, `test/fixtures/scene_v2.json`
- [ ] Static layer cache invariants: `test/render/scene_static_layer_cache_test.dart`
- [ ] `SceneView` integration + disposal: `test/view/scene_view_test.dart`

---

## 0) Definition of Done (“no problems”)

All of the following must be true before merging:

- [ ] `dart format` has no diffs
- [ ] `flutter analyze` is clean (no warnings/errors)
- [ ] Import boundaries are respected (`tool/check_import_boundaries.dart`)
- [ ] Tests pass (`flutter test`)
- [ ] `lib/src/**` has **100% line coverage** (`tool/check_coverage.dart`)
- [ ] `dart doc` succeeds (review warnings; avoid introducing new ones)
- [ ] `dart pub publish --dry-run` succeeds
- [ ] Example app builds/runs on at least one target platform

Note: CI is the source of truth for the canonical command set and versions (`.github/workflows/ci.yaml`).

---

## 1) Reproducible environment

- [ ] Use the same Flutter version as CI (see `.github/workflows/ci.yaml`)
- [ ] Start from a clean working tree (avoid mixing unrelated edits)
- [ ] Keep changes small and reviewable (prefer multiple small PRs)

---

## 2) Run the full quality gate locally (CI parity)

Run in this order to minimize noise:

- [ ] `flutter pub get`
- [ ] `dart format --output=none --set-exit-if-changed lib test example/lib tool`
- [ ] `flutter analyze`
- [ ] `dart run tool/check_import_boundaries.dart`
- [ ] `dart run tool/check_invariant_coverage.dart`
- [ ] `flutter test --coverage`
- [ ] `dart run tool/check_coverage.dart`
- [ ] `dart doc`
- [ ] `dart pub publish --dry-run`

If any step fails:

- [ ] Record the failure as a concrete, reproducible issue (command + output)
- [ ] Fix it with the smallest possible change
- [ ] Add regression protection (test / invariant / tool check) when applicable

---

## 3) Issue register (make every problem traceable)

For every problem found during review, create a short entry (in the PR description, a GitHub issue, or a review comment thread) with:

- [ ] Symptom (what fails / what looks wrong)
- [ ] Minimal reproduction (command/test)
- [ ] Location (file + symbol)
- [ ] Expected behavior (contract)
- [ ] Non-regression plan (test / tool / invariant)

---

## 4) Repository consistency (docs and meta)

- [ ] README/API guide match the current public API (`README.md`, `API_GUIDE.md`)
- [ ] Architecture notes match implementation (`ARCHITECTURE.md`)
- [ ] Internal docs referenced by ignore files actually exist (e.g. `.pubignore`)
- [ ] Generated artifacts are not committed unless explicitly intended
- [ ] `DEVELOPMENT_PLAN.md` checkbox updates are scoped to target items only
      (no unrelated section rewrites unless explicitly requested)

---

## 5) Public API review (treat as a contract)

- [ ] Public entrypoints export only intended surface area (`lib/basic.dart`, `lib/advanced.dart`)
- [ ] No accidental exports of `lib/src/**` details
- [ ] Source-level compatibility is preserved unless intentionally broken
- [ ] Public symbols have clear Dartdoc: purpose, constraints, edge cases

Regression protection:

- [ ] Update/add smoke tests for entrypoints when exports change (`test/entrypoints/*_smoke_test.dart`)

---

## 6) Architecture & invariants (core + slices)

This project is intentionally layered. When reviewing changes, keep the intended dependency direction in mind:

```text
core  <-  {serialization, input}  <-  render  <-  view
```

### Global invariants

- [ ] `lib/src/core/**` does not import `input/`, `render/`, `view/`, or `serialization/`
- [ ] `SceneController` stays the single source of truth (avoid duplicated state + “sync glue”)
- [ ] Group is ephemeral: do not store a persisted `Group` node / group state

### Input slices boundaries (enforced by tooling)

These rules are enforced by `dart run tool/check_import_boundaries.dart`:

- [ ] `lib/src/input/slices/**`:
  - [ ] must not use `part` / `part of`
  - [ ] must not import `scene_controller.dart`
  - [ ] must not import other slices outside its own slice subtree
  - [ ] may import only:
    - `dart:*`
    - `package:flutter/*`
    - `package:meta/*`
    - `lib/src/core/**`
    - `lib/src/input/types.dart`
    - `lib/src/input/action_events.dart`
    - `lib/src/input/pointer_input.dart`
    - `lib/src/input/internal/**`
    - `lib/src/input/slices/<currentSlice>/**`
- [ ] `lib/src/input/internal/**`:
  - [ ] must not import `scene_controller.dart`
  - [ ] must not import `lib/src/input/slices/**`
  - [ ] may import only:
    - `dart:*`
    - `package:flutter/*`
    - `package:meta/*`
    - `lib/src/core/**`
    - `lib/src/input/types.dart`
    - `lib/src/input/action_events.dart`
    - `lib/src/input/pointer_input.dart`
    - `lib/src/input/internal/**`

Rule of thumb:

- [ ] shared reusable input code (used by multiple slices) lives in `lib/src/input/internal/**`
- [ ] pure math belongs in `lib/src/core/**`

### Notification semantics (public behavior)

Per `ARCHITECTURE.md`, input notifications must preserve bit-for-bit semantics:

- [ ] **Immediate notification** stays immediate:
  - [ ] mode/tool/color/background/grid setters
  - [ ] `notifySceneChanged()`
  - [ ] most mutation commands (rotate/flip/delete/clear/moveNode/removeNode/addNode)
- [ ] **Coalesced (once per frame)** stays coalesced:
  - [ ] stroke thickness/opacity setters
  - [ ] camera offset updates
  - [ ] selection / selection-rect updates
  - [ ] hot paths during pointer gestures

### Action boundaries (undo/redo integration)

- [ ] `ActionCommitted` is emitted on:
  - [ ] drag end (transform)
  - [ ] stroke end
  - [ ] line end
  - [ ] transform/delete/clear
  - [ ] marquee end
  - [ ] erase end

If touched:

- [ ] `ActionCommitted.actionId` format stays `a${counter++}`
- [ ] relevant streams remain `broadcast(sync: true)`

### Slice invariants (check when touching the slice)

If the change touches these slices, validate invariants from `ARCHITECTURE.md` with tests:

- [ ] Repaint: `requestRepaintOncePerFrame()` schedules at most one frame; tokening cancels stale callbacks
- [ ] Signals: both streams stay `broadcast(sync: true)`; action id format stays stable
- [ ] Selection: `setSelection(...)` defaults to coalesced; `clearSelection()` stays immediate
- [ ] Commands: structural mutations call `notifySceneChanged()` and return immediately

If a boundary/invariant must change intentionally:

- [ ] Update `ARCHITECTURE.md` with the new rule and rationale
- [ ] Update/extend tooling (`tool/check_import_boundaries.dart`) to enforce it (when applicable)
- [ ] Add tests that make the new dependency direction necessary and obvious

---

## 7) Core logic (`lib/src/core/**`): invariants and properties

Focus on correctness properties, not just line-by-line reading.

- [ ] Geometry/transforms: inversion, composition, coordinate-system conventions
- [ ] Scene model invariants: identity uniqueness, ordering semantics

Suggested regression tests (when applicable):

- [ ] `inverse(T) * T ≈ identity` (within epsilon)
- [ ] point transforms round-trip within epsilon
- [ ] serialization round-trip preserves equivalence

---

## 8) Serialization (`lib/src/serialization/**`): data contract

- [ ] Input JSON validation is explicit and error messages carry context
- [ ] Schema versioning is respected (see `ARCHITECTURE.md`; update fixtures/tests if it changes)
- [ ] `schemaVersionWrite` / `schemaVersionsRead` changes are intentional and documented
- [ ] Invalid input throws `SceneJsonFormatException` with useful context
- [ ] Fixtures cover new/changed cases (`test/fixtures/**`)

Regression protection:

- [ ] Add fixtures + tests for every discovered format bug
- [ ] Add negative tests for invalid schema cases

---

## 9) Rendering & caching (`lib/src/render/**`): correctness + perf

- [ ] Coordinate transforms are correct (local → world → view/screen)
- [ ] Camera offset conversion is consistent with `ARCHITECTURE.md` (render uses `scenePoint - cameraOffset`)
- [ ] Missing/invalid resources fail safely (no crashes, clear errors)
- [ ] Cache keys are correct; invalidation is complete and minimal
- [ ] Static layer cache key includes size/background/grid/camera offset/grid stroke width (see `SceneStaticLayerCache`)
- [ ] Static layer cached picture is rebuilt only when the key changes

Regression protection:

- [ ] Extend cache tests when caching rules change (e.g. `*_cache*_test.dart`)
- [ ] Consider golden tests if feasible for the change (optional)

---

## 10) Input & controller (`lib/src/input/**`): event semantics

Treat event ordering and grouping semantics as a public contract.

- [ ] Pointer capture behavior is correct (start → updates → end)
- [ ] Event grouping rules are preserved (immediate vs frame-grouped, as designed)
- [ ] Coordinate conversion matches `ARCHITECTURE.md` (input uses `pointerPoint + cameraOffset`)
- [ ] Double-tap detection semantics stay stable (time + distance thresholds)
- [ ] Line tool supports both flows: drag and two-tap (with timeout), if touched
- [ ] Timestamps/ordering are deterministic under test
- [ ] Handlers stay lightweight; no blocking work on critical paths

Regression protection:

- [ ] Add tests for event sequences using explicit timestamps and phases

---

## 11) View (`lib/src/view/**`): widget integration

- [ ] `SceneView` remains a thin integration layer (no app/domain logic)
- [ ] Repaint wiring stays correct (repaints driven by controller notifications)
- [ ] Resource ownership/disposal stays correct (especially static layer cache ownership)

Regression protection:

- [ ] Update widget tests when repaint/dispose behavior changes (`test/view/**`)

---

## 12) Docs & example app (real-world integration)

- [ ] README quickstart works for a new user
- [ ] `API_GUIDE.md` examples compile against the current API
- [ ] Example app builds/runs and demonstrates the intended flows

---

## 13) Make the process inevitable

- [ ] No “silent fixes”: every real bug fix adds a test/tool/invariant
- [ ] Avoid suppressing warnings without a tracked issue and rationale
- [ ] Keep CI gates mandatory for merge (no bypassing without explicit sign-off)
