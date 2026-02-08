# Plan (Checklist) — Simple and Stable by Default

## Objective

Deliver fixes that improve correctness and maintain a small, predictable codebase:

- no extra abstraction layers without clear reuse
- no duplicated state or sync glue
- behavior contracts decided before implementation

## Execution Rules (applies to every checkbox)

- Contract first: define intended behavior in 1-3 bullets before code.
- Minimal patch: modify existing modules first; avoid new wrappers/helpers unless reused in 3+ call sites.
- Single source of truth: do not introduce parallel state that needs synchronization.
- Scout rule in scope: if touched code can be simplified or deleted safely, do it in the same task.

## Global Definition of Done (for each completed item)

- [ ] Behavior contract is explicit in code/tests/docs.
- [ ] Regression test added/updated for the bug class.
- [ ] Public behavior changes are reflected in docs (`README.md`, `API_GUIDE.md`, `ARCHITECTURE.md` as applicable).
- [ ] User-visible changes are recorded in `CHANGELOG.md` (`## Unreleased`).
- [ ] Quality gates executed and green:
  - `dart format --output=none --set-exit-if-changed lib test example/lib tool`
  - `flutter analyze`
  - `flutter test`
  - `flutter test --coverage`
  - `dart run tool/check_coverage.dart`
  - `dart run tool/check_invariant_coverage.dart`
  - `dart run tool/check_import_boundaries.dart`

---

## Phase 0 — Decision Gates (must be resolved before implementation)

* [x] **(Gate-1) `hitPadding` behavior contract**

  * **Where:** `lib/src/core/hit_test.dart`
  * **Chosen contract (fixed): Option A (strict scene units).**
  * **Implementation rule:** compute distances in scene/world coordinates and apply `hitPadding` directly.
  * **Note:** degenerate-transform fallback may stay coarse, but must be documented as a fallback path, not primary semantics.
  * **Exit criteria:** this contract is written in `ARCHITECTURE.md` + covered by tests.

* [ ] **(Gate-2) Grid over-density behavior contract**

  * **Where:** `lib/src/render/scene_painter.dart`, `lib/src/core/grid_safety_limits.dart`
  * **Chosen contract (fixed): graceful degradation.**
  * **Implementation rule:** when density exceeds safety limits, draw every Nth line and preserve major lines (no silent full disappearance).
  * **Out of scope:** no extra public signal/state and no adaptive-limit logic in this phase.
  * **Exit criteria:** this behavior is documented and testable.

---

## Phase 1 — Correctness Blockers (highest risk first)

* [x] **(P1) Cache lifecycle correctness on controller swap**

  * **Where:** `lib/src/view/scene_view.dart`, caches used by `lib/src/render/scene_painter.dart`
  * **Problem:** `SceneView` keeps cache instances across `SceneController` replacement. Reused `NodeId` values can produce ghost rendering from old scene data.
  * **Action:** in `SceneView.didUpdateWidget`, detect controller replacement and clear/recreate all caches.
  * **Tests to add:** controller swap with repeated `NodeId`; ensure old cached geometry/layout is not reused.

* [x] **(P1) `hitPadding` implementation aligned with Gate-1**

  * **Where:** `lib/src/core/hit_test.dart` (`_sceneScalarToLocalMax`, `_scenePaddingToWorldMax`, line/stroke distance checks)
  * **Problem:** current behavior can inflate tolerance under anisotropic transforms and may contradict docs.
  * **Action:** implement exactly the Gate-1 contract.
  * **Tests to add:** line/stroke under scale `(100, 1)`; assert hit distance behavior per chosen contract.

---

## Phase 2 — Interoperability and API Clarity

* [ ] **(P2) JSON integer decoding robustness**

  * **Where:** `lib/src/serialization/scene_codec.dart` (`_requireInt`)
  * **Problem:** integer-like values parsed as `double` (for example `1.0`) are rejected.
  * **Action:** accept `num`, validate integral value, then cast to `int`.
  * **Tests to add:** payload with integer fields represented as `1.0`; decoding must succeed.

* [ ] **(P2) Flip comments corrected to match behavior**

  * **Where:** `lib/src/input/scene_controller.dart`, behavior reference in `lib/src/input/slices/commands/scene_commands.dart`
  * **Problem:** horizontal/vertical flip comments are swapped.
  * **Action:** fix wording to match implementation, preferably axis-based language.
  * **Tests to add:** optional command-level assertion of matrix component change.

---

## Phase 3 — UX/Performance Guardrails

* [ ] **(P3) Grid over-density implementation aligned with Gate-2**

  * **Where:** `lib/src/render/scene_painter.dart`, `lib/src/core/grid_safety_limits.dart`
  * **Problem:** grid can disappear silently when line count exceeds cap.
  * **Action:** implement exactly the Gate-2 contract.
  * **Tests to add:** small cell size on typical viewport; verify suppression/degradation behavior is explicit and stable.

* [ ] **(P3) Cache stale-entry behavior review (post P1)**

  * **Where:** caches used by `lib/src/render/scene_painter.dart`
  * **Problem:** deleted-node cache entries remain until LRU eviction (bounded, but potentially confusing in churn-heavy workloads).
  * **Action:** treat P1 as mandatory baseline; add delete-path invalidation only if a measurable issue remains.
  * **Tests to add:** create/delete churn; verify bounded cache size and no stale rendering artifacts.

---

## Phase 4 — Optional Hardening (only if needed)

* [ ] **(P4) `SceneStrokePathCache.getOrBuild` short-input contract**

  * **Where:** `SceneStrokePathCache`
  * **Problem:** direct calls with `< 2` points throw; painter path is currently safe via separate handling.
  * **Action (choose one):** keep strict precondition and document it, or make API tolerant with explicit return contract.
  * **Tests to add:** direct cache call with `0/1` points; assert chosen behavior.

---

## Regression Test Bundle (recommended minimum)

* [ ] Controller swap with repeated `NodeId` (ghost-render prevention)
* [x] Hit-testing under anisotropic scale (locks Gate-1 behavior)
* [ ] JSON numeric robustness (`1.0` for integer fields)
* [ ] Grid density behavior (locks Gate-2 behavior)
