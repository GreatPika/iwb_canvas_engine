# Plan

Refactor `SceneControllerInteractive` into a smaller, reviewable architecture using composition (collaborator classes) instead of `part` files, while preserving current behavior, invariants, and public API contracts. The implementation will proceed in small, low-risk phases that keep tests green after each phase. The controller remains the orchestration facade; move/draw/eraser/session internals become explicit modules with clear ownership boundaries.

## Scope
- In:
- Split responsibilities in `lib/src/interactive/scene_controller_interactive.dart` into focused modules under `lib/src/interactive/internal/`.
- Keep existing behavior for pointer handling, action/event streams, preview state, and commit semantics.
- Keep existing test-only/internal access points (`sceneControllerInteractiveInternal*`) compatible.
- Preserve architecture constraints: single source of truth in controller snapshot, no sync glue, no duplicated runtime state.
- Update docs if public behavior/API changes are introduced during refactor.
- Out:
- No new user-facing features or gesture behavior changes.
- No migration to `part` files.
- No broad refactor of `controller/`, `render/`, or `view/` subsystems unrelated to this decomposition.

## Action items
[x] Baseline current behavior and boundaries by mapping method/state groups in `lib/src/interactive/scene_controller_interactive.dart` and documenting ownership for: public facade, move flow, draw flow, eraser/hit-testing, preview/pending-line lifecycle, and async dispatch.
[x] Define target module layout under `lib/src/interactive/internal/` with intent-revealing names and clear responsibilities (for example: `interactive_event_dispatcher.dart`, `interactive_geometry.dart`, `interactive_move_session.dart`, `interactive_draw_session.dart`), and freeze ownership rules to avoid duplicated state.
[x] Extract `_InteractiveEventDispatcher` into `lib/src/interactive/internal/interactive_event_dispatcher.dart` and wire it back from the facade with no behavior changes.
[x] Extract pure geometry/math helpers (`_SegmentBatch`, segment-bounds batching, rect distance checks, matrix singular value helper, optional point-resampling helpers) into `lib/src/interactive/internal/interactive_geometry.dart`, keeping them stateless and testable.
[x] Introduce `InteractiveDrawSession` to own draw-specific ephemeral state and transitions (pen/highlighter buffers, line preview, pending two-tap line state, eraser gesture buffer) while delegating commits through explicit callbacks into `SceneControllerCore`.
[x] Introduce `InteractiveMoveSession` to own move/marquee ephemeral state and transitions (active pointer, drag threshold, selection rect, preview delta/node set) while delegating selection/transform commits through explicit callbacks.
[x] Keep `SceneControllerInteractive` as orchestrator only: validate/route input, maintain configuration/public getters, bridge to core commands, and coordinate session outputs; remove duplicated private state from facade once sessions are wired.
[x] Preserve and adapt internal/test hooks (`sceneControllerInteractiveInternal*`) by routing them to the new owner modules without changing signatures used by `test/interactive/scene_controller_interactive_unit_test.dart` and `lib/src/view/scene_view_interactive.dart`.
[x] Run required checks after each major extraction phase: `dart format --output=none --set-exit-if-changed lib test example/lib tool`, `flutter analyze`, `flutter test`, `flutter test --coverage`, `dart run tool/check_coverage.dart`, `dart run tool/check_invariant_coverage.dart`, `dart run tool/check_guardrails.dart`, `dart run tool/check_import_boundaries.dart`.
[x] Add/adjust focused tests for regression-prone paths: single active pointer gate, cancel state reset, move preview commit-on-up semantics, line tap-vs-drag behavior, eraser batching/complexity counters, and asynchronous/coalesced notifications.
[x] Update `ARCHITECTURE.md` if invariant enforcement/ownership boundaries change, and update `API_GUIDE.md`/`README.md` only if observable API/behavior changes; keep docs and code in the same change.
[x] Add user-visible notes under `## Unreleased` in `CHANGELOG.md` when refactor affects integration expectations (for example internal structure changes with stable API guarantees).
