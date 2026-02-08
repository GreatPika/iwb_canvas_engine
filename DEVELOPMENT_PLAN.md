# Plan (43 tasks). Grouped by phases, with explicit policies and acceptance criteria.

Goal: prevent invalid state (NaN/Infinity, duplicate IDs, time going backwards, bad JSON) from entering the core.

## Implementation Concept (Adopted)

- Use a **Contract-First Hardening** approach:
  - first, enforce shared behavior contracts in central boundaries (controller/contracts/validation),
  - then, implement phase tasks on top of those contracts,
  - then, apply performance optimizations after behavioral correctness is locked.
- Keep **single source of truth** in `SceneController` and avoid sync glue between duplicated state holders.
- Every completed task must include:
  - tests,
  - invariant marker updates where applicable (`INV:*` references),
  - checkbox update in this document.

## Whole-Plan Strategy

Implement the full roadmap through four cross-cutting layers, then map each task
to one primary layer. This keeps local fixes consistent and avoids fragmented
behavior across modules.

1. Reliability Kernel
   - Build shared primitives first: scene validation, selection normalization,
     monotonic timestamp resolution, and O(1) node identity/index helpers.
   - Rule: all input/command/serialization paths must use these primitives
     instead of re-implementing checks locally.

2. Transactional Gestures
   - Use a consistent gesture lifecycle: `begin -> preview -> commit | rollback`.
   - Apply the same rollback semantics to `cancel` and `setMode(...)` during an
     active gesture (no partial edits left behind).

3. Interaction Policy Layer
   - Centralize interaction contracts: active pointer ownership, pointer-signal
     filtering, and non-interactive/non-deletable background behavior.
   - Rule: selection contains valid interactive IDs only.

4. Performance Backbone
   - After behavior is stable, optimize with shared infrastructure: spatial
     indexing, cache-key correctness, O(1) membership paths, and hot-path math
     simplifications.
   - Rule: performance changes must preserve previously locked contracts.

### Task Mapping Rule

- Each task must declare one primary strategy layer (1-4) before implementation.
- If a task touches multiple layers, complete the primary layer behavior first,
  and treat the rest as minimal supporting changes only.

## Execution Ordering Policy

- The task checklist order and numbering are intentionally preserved.
- Do **not** renumber or reorder existing items unless scope changes materially.
- Work in small batches when it reduces risk and avoids temporary half-states.
  - Batch size limit: at most **3** tasks may be completed together.
  - Before starting a batch, explicitly decide which task IDs belong to the batch and document a short rationale (why these tasks are coupled, and what shared contract/infrastructure they touch).
  - Prefer batches that are adjacent in phase/scope and share the same primary strategy layer (see "Whole-Plan Strategy").
- Changes that help future tasks are allowed only as **prep-only** work:
  - they must not be marked as completed for those future task IDs,
  - they must be minimal and directly required to unblock the current task.
- A checkbox may be marked complete only after:
  - the task acceptance criteria are satisfied,
  - related tests are added/updated and pass,
  - invariants are added/updated when applicable, and have enforcement:
    - update `tool/invariant_registry.dart` when a new invariant is introduced or an existing one changes,
    - reference enforcement sites via `// INV:<id>` in `test/**` and/or `tool/**`,
    - keep `dart run tool/check_invariant_coverage.dart` green,
  - required docs/changelog updates are included when public behavior changes.

## API Clarity Guardrails

- Do not expand public API surface unless it is required by the current task scope.
- For any public behavior/API change, update in the same iteration:
  - `README.md`,
  - `API_GUIDE.md`,
  - public Dartdoc for changed symbols.
- Keep public entrypoints source-compatible (`basic.dart`, `advanced.dart`) unless a breaking change is explicitly planned and documented.
- Prefer explicit, direct API over wrappers; add wrappers only when they remove repetition in 3+ call sites without changing semantics.

## Quality Gates Policy

- After each completed task (or tightly coupled micro-batch), run and report:
  - `dart format --output=none --set-exit-if-changed lib test example/lib tool`
  - `flutter analyze`
  - `flutter test`
  - `flutter test --coverage`
  - `dart run tool/check_coverage.dart`
  - `dart run tool/check_invariant_coverage.dart`
  - `dart run tool/check_import_boundaries.dart`

1. [x] **(#1) Grid rendering can freeze when `cellSize` is too small**
   **Where:** `SceneController.setGridCellSize()`, `ScenePainter._drawGrid()`
   **Do:**

   * Clamp `cellSize` to `minCellSize` (define constant, e.g. `minCellSize = 1.0`) when grid is enabled.
   * In `_drawGrid()`: if `cellSize` is not finite OR `cellSize < minCellSize`, skip drawing grid.
   * Add `maxGridLines` guard (e.g. <= 200 lines per axis); if exceeded, skip grid.
     **Done when:** test proves no freeze for very small values; non-finite values don’t draw.

2. [x] **(#2) Duplicate `NodeId` causes nondeterministic find/remove/selection**
   **Where:** `SceneCommands.addNode(...)`, `SceneCodec.decodeScene(...)`
   **Do:**

   * In `addNode`: if `id` already exists in the scene → throw `ArgumentError` (or library-specific exception).
   * In `decodeScene`: after decoding, ensure all `id`s are unique → otherwise throw `SceneJsonFormatException`.
     **Done when:** tests: addNode with dup fails; JSON with dup fails.

3. [x] **(#6) `timestampMs` allows “time going backwards”**
   **Where:** central timestamp resolution (`_resolveTimestampMs` or right before `emitAction`)
   **Do:**

   * Enforce monotonic output: `resolvedTimestamp = max(inputTimestamp, cursor + 1)` and update cursor.
     **Done when:** test: action with timestamp 10 after 100 is emitted with >=101.

4. [x] **(#7) Mixed time scales (`event.timeStamp` vs epoch milliseconds)**
   **Where:** anywhere external `timestampMs` is accepted; pointer event pipeline uses `event.timeStamp.inMilliseconds`
   **Policy (fixed):** the engine uses **internal monotonic time**, not wall-clock.
   **Do:**

   * Treat all inbound timestamps as “hints”; always normalize via rule in #6.
   * Document in code comment: do not pass epoch timestamps; if passed, they’ll be normalized.
     **Done when:** test: epoch-like timestamp followed by pointer timestamps still yields monotonic actions.

5. [x] **(#8) `camera.offset` accepts NaN/Infinity and poisons coordinates**
   **Where:** `SceneController.setCameraOffset/_setCameraOffset`
   **Policy (fixed):** reject invalid input.
   **Do:**

   * If `offset.dx` or `offset.dy` is not finite → throw `ArgumentError` (and do not mutate scene).
     **Done when:** test: setting NaN throws; subsequent gestures never produce NaN in node transforms.

6. [x] **(#19) `normalizeToLocalCenter()` can throw and crash input processing**
   **Where:** `StrokeTool` commit path, `LineTool` commit path
   **Policy (fixed):** never crash; abort the tool safely.
   **Do:**

   * Wrap `normalizeToLocalCenter()` in try/catch; on exception: discard the pending node, reset tool state, emit no action.
     **Done when:** test: crafted invalid geometry does not crash; tool resets predictably.

7. [x] **(#22) `SceneController` does not validate scene invariants on construction**
   **Where:** `SceneController(scene: ...)` constructor
   **Policy (fixed):** validate + canonicalize recoverable invariants; fail fast on unrecoverable invariants.
   **Do:**

   * Add `validateSceneOrThrow(scene)` called in constructor:

     * camera offset finite (#8)
     * grid config finite and safe (#1, #28)
     * palettes non-empty (#27)
     * background layer invariants (#35), with explicit constructor behavior:
       * if no background layer exists -> create one at index 0
       * if background exists but not at index 0 -> move it to index 0 (preserve relative order of non-background layers)
       * if multiple background layers exist -> throw
       **Done when:** tests cover constructor canonicalization (missing/misordered background) and constructor rejection (multiple background layers), with consistent error on rejection.

8. [x] **(#24) Fill hit-test returns true for degenerate transforms after coarse check**
   **Where:** fill hit-test logic (`selection_geometry` / geometry hit-testing for fill)
   **Policy (fixed):** degenerate transform → not clickable for fill.
   **Do:**

   * If inverse matrix is null/unavailable → return `false` for fill hit-test (skip coarse-rect fallback).
     **Done when:** test: degenerate transform never “steals” clicks by AABB.

9. [x] **(#26) `SceneView` owned controller does not react to updated settings**
   **Where:** `SceneView.didUpdateWidget`
   **Do:**

   * Detect changes in `pointerSettings`, `dragStartSlop`, `nodeIdGenerator`.
   * Recreate the owned controller (or update fields if supported) on change.
     **Done when:** test/demo: updating `dragStartSlop` changes behavior without rebuilding the entire widget.

10. [x] **(#27) JSON allows empty palettes (`penColors/backgroundColors/gridSizes`)**
    **Where:** `SceneCodec` decode/validation
    **Do:**

* Reject empty lists with `SceneJsonFormatException`.
  **Done when:** test: empty palette JSON fails to load.

11. [x] **(#28) JSON too strict about `grid.cellSize` even when `enabled=false`**
    **Where:** `SceneCodec`
    **Policy (fixed):** when grid disabled, accept any finite value.
    **Do:**

* If `grid.enabled == false`: allow any finite `cellSize`.
* If later enabled: clamp via #1.
  **Done when:** test: disabled grid + “weird but finite” cellSize loads successfully.

12. [x] **(#33) `mutate(structural:false)` is easy to misuse and break caches/revisions**
    **Where:** scene mutation API
    **Policy (fixed):** make structural mutations explicit.
    **Do:**

* Add `mutateStructural(...)` and make structural changes go through it.
* In debug/assert: detect structure change while `structural:false` and throw/assert.
  **Done when:** misuse is caught in debug; correct paths use `mutateStructural`.

---

## Phase 2 — Interactivity rules + selection integrity

Goal: no bypasses. Background must never be selectable/deletable; selection must never contain garbage.

13. [x] **(#5) Background layer not consistently protected; can be selected/deleted via bypasses**
    **Where:** `MoveModeEngine._nodesIntersecting(...)`, `SceneCommands.selectAll/deleteSelection`, `selection_geometry.selectedTransformableNodesInSceneOrder(...)`
    **Policy (fixed):** background is **non-interactive** and **non-deletable**.
    **Do:**

* Introduce a single predicate: `isNodeInteractive(node, layer)` and `isNodeDeletable(node, layer)` (background => false).
* Apply consistently in marquee selection, selectAll, deleteSelection, and any “scene-order selection” helpers.
  **Done when:** tests: marquee/selectAll never include background; deleteSelection never deletes it even if ID is injected.

14. [x] **(#15) Eraser deletes nodes but selection still contains deleted IDs**
    **Where:** eraser deletion path + selection update path
    **Policy (fixed):** selection is always normalized against current scene.
    **Do:**

* After erasing, remove `deletedIds` from selection before publishing scene change / emitting action.
  **Done when:** test: erase a selected stroke => selection becomes empty.

15. [x] **(#35) Background layer invariants not defined (count/position/operations)**
    **Where:** scene model + `SceneCodec` + controller validation
    **Policy (fixed):** exactly **one** background layer at **index 0**.
    **Do:**

* On decode/validation:

  * If none → create one at index 0.
  * If multiple → throw a validation error (`SceneJsonFormatException` on decode; constructor validation error in `SceneController`).
  * If background not at index 0 → normalize by moving it to index 0 (preserving other order).
    **Done when:** tests cover all 3 cases above.

16. [ ] **(#36) Selection accepts garbage: unknown IDs / background IDs**
    **Where:** `setSelection`, `toggleSelection`, and central selection setter
    **Policy (fixed):** selection is a **set of valid, interactive node IDs only**.
    **Do:**

* Normalize on every set/update:

  * remove unknown IDs
  * remove background IDs
  * remove duplicates
    **Done when:** test: `setSelection([backgroundId, unknownId])` results in empty selection.

17. [ ] **(#39) `SelectionModel.setSelection` ignores ordering**
    **Policy (fixed):** selection is **unordered** (a mathematical set).
    **Where:** `SelectionModel.setSelection`
    **Do:**

* Ensure internal storage is a `Set<NodeId>` (or an order-insensitive representation).
* Update docs/comments to state ordering is not preserved.
* Where stable order is needed (painting/transform), derive order from scene order explicitly.
  **Done when:** tests confirm order is not relied upon; deterministic scene-order iteration works.

18. [ ] **(#41) `clearScene` leaves empty layers**
    **Policy (fixed):** after `clearScene`, keep **only** the background layer (index 0) + no other empty layers.
    **Where:** `clearScene`
    **Do:**

* Remove all non-background layers and nodes; ensure exactly one background layer remains.
  **Done when:** test: `clearScene` results in 1 layer (background) and empty selection.

---

## Phase 3 — Gesture transactions (cancel/mode change must be safe)

Goal: any in-progress gesture ends deterministically. No silent partial edits.

19. [ ] **(#3) Drag cancel/mode change leaves nodes moved without rollback and/or without Action**
    **Where:** `MoveModeEngine`, `SceneController.setMode(...)`
    **Policy (fixed):** `cancel` and `setMode(...)` during drag both **rollback**.
    **Do:**

* On drag start: snapshot positions/transforms for all affected nodes.
* On `PointerPhase.cancel`: restore snapshot; emit **no** action.
* On `SceneController.setMode(...)` while drag active: treat as cancel → restore snapshot; emit **no** action.
  **Done when:** tests: drag→move→cancel restores; drag→setMode restores identically.

20. [ ] **(#4) Eraser mutates scene during move; cancel/mode change loses Action and/or lacks rollback**
    **Where:** `EraserTool`, `SceneController.setMode(...)`
    **Policy (fixed):** eraser is transactional:

* during move: may delete immediately for feedback, but must keep a rollback journal
* end (pointer up): **commit** and emit `ActionType.erase`
* cancel or mode change: **rollback** using journal and emit no action
  **Do:**
* Maintain `List<DeletedRecord>` per gesture: (layerId, index, nodeSnapshot).
* On commit: emit action containing deleted node IDs (and optionally full payload if needed for undo).
* On rollback: reinsert nodes at original positions; restore selection normalization (#15/#36).
  **Done when:** tests: erasing then cancel restores nodes; erasing then setMode restores; erasing then up emits action.

21. [ ] **(#12) Line tool pending-start expires only on new events**
    **Where:** `LineTool`
    **Policy (fixed):** pending line start auto-clears after 10 seconds.
    **Do:**

* Start a `Timer(10s)` when setting pending start; clear pending on timer.
* Cancel timer on line completion or tool reset.
  **Done when:** test: first tap → wait >10s with no events → second tap does not use old start.

22. [ ] **(#20) Marquee commit always emits Action even when selection didn’t change**
    **Where:** `MoveModeEngine._commitMarquee(...)`
    **Policy (fixed):** do not emit no-op actions.
    **Do:**

* Compare previous and new normalized selection sets; only emit `ActionType.selectMarquee` when changed.
  **Done when:** test: empty marquee on empty selection emits nothing; real change emits action.

23. [ ] **(#16) `RepaintScheduler.notifyNow()` can notify after dispose**
    **Where:** `RepaintScheduler.notifyNow()`
    **Do:**

* Add `_isDisposed` guard; return early if disposed.
  **Done when:** test: calling after dispose is safe.

24. [ ] **(#17) `ActionDispatcher` may write into a closed stream after dispose**
    **Where:** `ActionDispatcher.emitAction/emitEditTextRequested`
    **Do:**

* Guard with `isClosed` or `_isDisposed`; drop events after dispose.
  **Done when:** test: calling after dispose does not throw.

---

## Phase 4 — Pointer signals, multitouch, timers

Goal: one active pointer policy; no spurious double taps; no timer storms.

25. [ ] **(#9) Tap/double-tap signals can be generated by a non-active pointer during an active gesture**
    **Where:** `SceneView`, `PointerInputTracker`, controller signal routing
    **Policy (fixed):** while a gesture is active, only the active `pointerId` can generate signals.
    **Do:**

* Track active pointer at controller level and expose it to signal tracker OR filter events before feeding the tracker.
* Ignore tap/double-tap candidates from other pointers while active gesture exists.
  **Done when:** multitouch test: one finger drags/draws; second finger taps → no double-tap/edit-text signal.

26. [ ] **(#10) `SceneView` creates/recreates timers on every pointer sample (especially move)**
    **Where:** `SceneView` double-tap window logic / tracker integration
    **Policy (fixed):** timer exists only while there is a “pending tap”.
    **Do:**

* Create the timer when first tap is registered (typically on pointer up).
* Never recreate on move; only cancel/expire on timeout or successful second tap.
  **Done when:** benchmark/test: dragging does not create multiple timers; at most one timer per pending-tap window.

27. [ ] **(#11) Double-tap tracking keyed by device kind instead of `pointerId` (multitouch bugs)**
    **Where:** `PointerInputTracker`
    **Do:**

* Replace `_pendingTapByKind` with `_pendingTapByPointerId` (or `(kind, pointerId)` if needed).
  **Done when:** multitouch test: two fingers don’t create false double-tap; single finger double-tap still works.

---

## Phase 5 — Performance + correctness polish

Goal: scalability on large scenes and long gestures; reduce unnecessary work; fix visual/text correctness.

28. [ ] **(#13) RTL languages broken: text always LTR; start/end alignment wrong**
    **Where:** `ScenePainter`, `SceneTextLayoutCache`, data passed from `SceneView`
    **Do:**

* Pass `TextDirection` from `Directionality.of(context)` into painting/layout cache.
* Make start/end alignment depend on direction.
  **Done when:** RTL sample/test renders and aligns correctly.

29. [ ] **(#14) PathNode selection highlight ignores `fillRule` (always nonZero)**
    **Where:** `_drawSelectionForNode(PathNode)`
    **Do:**

* Set highlight fill type based on `node.fillRule` (evenOdd vs nonZero).
  **Done when:** visual/test verifies highlight matches fill behavior.

30. [ ] **(#18) Eraser/hit-test is O(N) per move → slow on large scenes**
    **Where:** eraser hit-testing / scene hit-test pipeline
    **Do:**

* Add a coarse spatial index (uniform grid by node bounds) to retrieve candidates quickly.
* Keep it updated on structural mutations.
  **Done when:** perf test: erasing stays responsive on large scenes.

31. [ ] **(#21) Unlimited point growth in stroke/eraser paths (memory/JSON/CPU)**
    **Where:** `StrokeTool`, `EraserTool`
    **Do:**

* Point decimation: only append a point if screen-space distance from last point ≥ `0.75 px` (convert to scene units using current camera scale).
* Optionally simplify polyline on commit (only if needed).
  **Done when:** long draw/erase does not create huge point arrays; perf and serialization stable.

32. [ ] **(#23) PathNode stroke hit-test too coarse (AABB) → false hits**
    **Where:** stroke hit-test for `PathNode`
    **Do:**

* Implement distance-to-path (using path metrics) with stroke width tolerance.
* Use spatial index candidates (#30) first, then precise test.
  **Done when:** test: click inside AABB but far from stroke returns false.

33. [ ] **(#25) Thin-line pixel snapping ignores scale/rotation**
    **Where:** snapping/alignment logic
    **Do:**

* Determine “thin line” in screen units (use transform scale magnitude).
* Disable snapping when rotation ≠ 0 or scale ≠ 1 (unless you implement rotated snapping).
  **Done when:** scaled/rotated examples do not show snapping artifacts.

34. [ ] **(#29) Text layout cache key includes non-layout fields (color/height/nodeId) → low hit rate**
    **Where:** `SceneTextLayoutCache` key computation
    **Do:**

* Key must include only layout-affecting fields: text, font properties, maxWidth, direction, locale, etc.
* Exclude color and box height if they do not affect layout.
  **Done when:** metric/counter shows fewer layout recomputations when only color changes.

35. [ ] **(#30) Static layer cache depends on `cameraOffset` → rebuilt on panning**
    **Where:** static layer picture caching
    **Do:**

* Cache in world/scene space; apply camera transform at paint time.
* Separate grid/background caching from camera offset.
  **Done when:** pan does not trigger frequent picture rebuilds (measurable reduction).

36. [ ] **(#31) `newNodeId()` checks uniqueness via O(N) scan**
    **Where:** node ID generator / controller
    **Do:**

* Maintain `Set<NodeId> allNodeIds` updated on add/remove/decode.
* Generate/check in O(1).
  **Done when:** perf test: mass creation is significantly faster.

37. [ ] **(#32) `notifySceneChanged()` scans all nodes to clean selection**
    **Where:** `notifySceneChanged()`
    **Do:**

* Use `allNodeIds` set (#36) to filter selection without scanning the entire scene graph.
  **Done when:** repeated structural changes don’t produce O(N) overhead.

38. [ ] **(#34) `flipSelectionVertical/Horizontal` semantics ambiguous**
    **Policy (fixed):**

* `flipSelectionHorizontal`: reflect across **vertical** axis through the selection bounding box center (world space).
* `flipSelectionVertical`: reflect across **horizontal** axis through the selection bounding box center (world space).
  **Where:** selection transform commands
  **Do:**
* Implement/refactor to match the definition above.
* Add tests that verify exact transform results.
  **Done when:** tests encode the definition and pass.

39. [ ] **(#37) Hot paths use `distance()` (sqrt) instead of squared comparisons**
    **Where:** geometry/helpers used on move
    **Do:**

* Replace with squared distance comparisons (`dx*dx + dy*dy`).
  **Done when:** microbenchmark/profiling shows reduced time for move processing.

40. [ ] **(#38) `resolveSnappedPolyline` allocates before early exit**
    **Where:** `resolveSnappedPolyline`
    **Do:**

* Check “eligible for snapping” first; only allocate lists after passing checks.
  **Done when:** allocation count decreases; behavior unchanged.

41. [ ] **(#40) `deleteSelection` uses `List.contains` inside filters**
    **Where:** `SceneCommands.deleteSelection`
    **Do:**

* Convert selection IDs to a `Set` locally for the operation and use O(1) membership checks.
  **Done when:** faster on large selections; tests unchanged.

42. [ ] **(#42) PathNode rendering recomputes path metrics per frame**
    **Where:** PathNode rendering code
    **Do:**

* Cache path metrics keyed by path + relevant style; invalidate cache only when path/style changes.
  **Done when:** profiling shows fewer per-frame metric computations.

43. [ ] **(#43) Segment intersection math unstable for very large coordinates**
    **Where:** `geometry.segmentsIntersect`
    **Do:**

* Clamp scale used for epsilon estimation and/or normalize inputs to a safe range.
* Add “large coordinate” unit test set.
  **Done when:** large-coordinate tests pass without false positives/negatives.

---

## Final sanity check (completeness)

Included tasks: **#1–#43 exactly once**. No “choose policy” left: all key contracts are specified (rollback rules, selection semantics, background invariants, invalid-number behavior, flip definitions).

If you want, I can also append a **single “test matrix”** (named test cases mapped to these tasks) so the agent always knows what to run/green-light per phase.
