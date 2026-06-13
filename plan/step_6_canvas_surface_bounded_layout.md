# Change Contract

## Goal

`CanvasSurface` must no longer disappear silently when Flutter gives it
unbounded layout constraints. The public widget should require bounded width and
height, report a clear Flutter error in debug and release when either axis is
unbounded, and keep existing bounded-surface paint and pointer behavior intact.

## Source Inputs

- Design: none
- Research: `.research/2026-06-13-surface-unbounded-layout.md`
- Phase: none
- PLAN: `PLAN.md`
- Other: User input on 2026-06-13 selecting strict debug-and-release `FlutterError`, no placeholder UI, and no performance regression; `docs/README.md`; `lib/src/surface/canvas_surface_widget.dart`; `docs/contracts/public_api_v1.md`; `docs/verification/tests.md`; `docs/_registry/sections.yaml`; `docs/tool/sync_generated_docs.dart`; `docs/tool/generate_context_capsules.dart`

## Classification

Profile: Boundary-Owned Policy

Obligations: Owner-Level Fix; Boundary-Owned Policy; Source-Of-Truth Singularity; Compatibility; Negative Proof And Fixture Quarantine; Completion Evidence Boundary.

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| Research establishes `CanvasSurface` as the Flutter boundary that converts layout constraints to `paintSize` and viewport. | `Boundaries.Owner`; `Unit 1` | `test/surface/canvas_surface_layout_constraints_test.dart` proves bounded layout and unbounded rejection through the public widget. |
| Research establishes non-finite maximum dimensions currently become `0.0` and flow into `CustomPaint.size` and frame viewport. | `Boundaries.In Scope`; `Unit 1` | Focused widget tests fail if unbounded constraints still create a zero-size paint host instead of surfacing the error. |
| User input on 2026-06-13: use strict debug-and-release `FlutterError`, not debug-only assert and not placeholder UI. | `Boundaries.Compatibility`; `Unit 1` | Unbounded-width and unbounded-height tests expect the clear Flutter error; a test-only structural proof rejects assert-only, debug-only, profile-only, or release-excluded enforcement. |
| User input on 2026-06-13: do not worsen performance. | `Boundaries.Compatibility`; `Unit 1` | The bounded path remains an O(1) layout-boundary check and `constraints.biggest` return, with no runtime/frame/cache/painter/pointer work added. |
| Repository docs define normative contracts, verification policy, and structured relationships; research is evidence only. | `Boundaries.Source of Truth`; `Unit 2` | `docs/contracts/public_api_v1.md`, `docs/verification/tests.md`, and `docs/_registry/sections.yaml` are updated, then documentation checks pass. |
| Existing surface tests mount bounded hosts and do not cover unbounded layout. | `Boundaries.In Scope`; `Unit 1` | New focused surface layout tests cover bounded unchanged behavior and both unbounded axes. |

## Evidence

- `.research/2026-06-13-surface-unbounded-layout.md:13` / `surface`: `CanvasSurface` derives `CustomPaint.size` and viewport from Flutter constraints, and non-finite dimensions become `0.0` -> the fix belongs at the surface layout boundary, before runtime/frame capture receives viewport inputs.
- `.research/2026-06-13-surface-unbounded-layout.md:24` / `surface`: `BoxConstraints` enter `LayoutBuilder`, `_paintSizeFor` computes `paintSize`, and `Offset.zero & paintSize` becomes the viewport -> completion proof must exercise the public widget under Flutter layout constraints, not only `_paintSizeFor` directly.
- `.research/2026-06-13-surface-unbounded-layout.md:26` / `surface`: `_paintSizeFor` currently maps non-finite `maxWidth` or `maxHeight` to `0.0` -> implementation must remove the silent fallback for both axes.
- `.research/2026-06-13-surface-unbounded-layout.md:33` / `surface`: the derived viewport feeds both main and overlay frame builds, and derived `paintSize` feeds `CustomPaint.size` -> a zero-size fallback affects visible paint and frame capture, so the rejection must happen before `_buildPaintHost`.
- `.research/2026-06-13-surface-unbounded-layout.md:57` / `surface`: the public surface contract covers active lifecycle, painting, pointer routing, and resources but not layout constraints -> the public contract is the source-of-truth surface that must gain the bounded-layout rule.
- `.research/2026-06-13-surface-unbounded-layout.md:61` / `surface`: inspected guardrails cover pointer routing and `interactive=false`, not layout sizing -> this contract should use focused widget tests as the mechanical proof instead of adding a new structural guardrail.
- `.research/2026-06-13-surface-unbounded-layout.md:68` / `surface`: existing surface tests mount bounded hosts such as `SizedBox(width: 100, height: 100)` and `SizedBox(width: 120, height: 80)` -> the new fixture should preserve bounded behavior while adding unbounded cases.
- `.research/2026-06-13-surface-unbounded-layout.md:72` / `surface`: inspected test searches found no direct `CanvasSurface` size assertion or unbounded-layout host -> a focused test entrypoint is required for regression coverage.
- `docs/README.md:25` / `source-of-truth`: normative contracts live under `docs/contracts/` -> public `CanvasSurface` layout behavior belongs in the public API contract, not only in the research note.
- `docs/README.md:26` / `source-of-truth`: verification policy lives under `docs/verification/` -> the new focused surface test must be documented in the verification source of truth.
- `docs/README.md:27` / `source-of-truth`: structured relationships live under `docs/_registry/` -> adding a new documented surface test requires registry coverage, not only prose in `docs/verification/tests.md`.
- `docs/tool/sync_generated_docs.dart:124` / `docs-generation`: generated documentation sync delegates generator commands before loading sections -> registry edits must be verified through the generated-docs check.
- `docs/tool/generate_context_capsules.dart:144` / `docs-generation`: context capsules render `Required tests` from section registry entries -> the new test id must be registered where the public surface and tests sections own required test coverage.
- `docs/_registry/sections.yaml:87` / `registry`: section 4 owns `docs/contracts/public_api_v1.md` and its public API tests -> the new surface layout test must be registered under the public API contract section.
- `docs/_registry/sections.yaml:799` / `registry`: section 23 owns `docs/verification/tests.md` and its required tests -> the new surface layout test must be registered under the tests section.
- `PLAN.md:8` / `plan`: step entries link to dedicated `plan/step_<number>_<summary>.md` files -> Step 6 must follow the linked-step format.
- `PLAN.md:28` / `plan`: Step 6 is linked from the active plan index -> this contract is the linked source for the planned work.

## Boundaries

Owner: `CanvasSurface` owns conversion from Flutter layout constraints to paint size and viewport in `lib/src/surface/canvas_surface_widget.dart`.

In Scope:

- Replace silent non-finite-dimension fallback in `_paintSizeFor` with a bounded width-and-height requirement.
- Throw a clear `FlutterError` in debug and release when width or height is unbounded, with guidance to wrap `CanvasSurface` in `SizedBox`, `Expanded`, `AspectRatio`, or another finite-constraints widget.
- Return the bounded size from `constraints.biggest` for valid bounded constraints.
- Keep valid bounded layout cost constant: no new runtime/frame/cache/painter/pointer work, no scene reads, no resource resolution, and no per-pointer or per-paint checks for this policy.
- Add focused public-widget tests covering bounded layout behavior and both unbounded axes.
- Add a test-only structural proof that the rejection is not implemented solely inside `assert` or another debug-only path.
- Update the public surface contract, verification test documentation, and section registry entries for the bounded-layout requirement and proof.

Out of Scope:

- New public constructor parameters, intrinsic canvas sizing, preferred-size API, automatic aspect ratio, scroll-aware viewport policy, or placeholder UI.
- Runtime, frame, cache, painter, pointer-adapter, resource-session, or interaction-engine behavior changes beyond receiving the already bounded viewport.
- Benchmark additions or performance harness changes; this policy is a constant-time layout boundary guard and does not add hot-path benchmarking scope.
- New guardrail registration or standalone structural source scanner for layout constraints; the contract-named test-only structural proof in Unit 1 is in scope.
- Architecture design artifacts or generated architecture diagrams.

Source of Truth: `docs/contracts/public_api_v1.md` owns the durable public `CanvasSurface` behavior; `docs/verification/tests.md` owns the verification-policy description; `docs/_registry/sections.yaml` owns structured test-to-section relationships; the focused widget test owns mechanical regression proof. `.research/2026-06-13-surface-unbounded-layout.md` remains evidence only.

Compatibility: Public constructor and exported API remain unchanged. Bounded layouts keep existing paint-host and viewport behavior. Invalid unbounded layouts change from silent zero-size rendering to a clear Flutter error in debug and release. Performance compatibility is preserved by keeping the valid bounded path to a constant-time constraint check and `constraints.biggest` return at the surface layout boundary, with no runtime/frame/cache/painter/pointer changes.

Order Constraints:

1. Establish the surface layout behavior and focused widget proof together.
2. Update source-of-truth documentation after the behavior/proof surface is settled.
3. Run code checks and focused tests for the changed Dart surfaces; run documentation checks after docs change.

## Execution Units

### [ ] Unit 1: Enforce bounded surface layout

Owner: `lib/src/surface/canvas_surface_widget.dart`

Boundary: Flutter layout constraints entering `CanvasSurface` through `LayoutBuilder`.

Change: Replace `_paintSizeFor`'s non-finite-to-zero fallback with a bounded width-and-height check that throws a clear `FlutterError` when either axis is unbounded and returns `constraints.biggest` for bounded constraints. Keep the check local to layout-size derivation and do not add work to runtime, frame, cache, painter, pointer, resource, or interaction paths. Add `test/surface/canvas_surface_layout_constraints_test.dart` as the package-test entrypoint that calls `runFlutterInPackageTest('test/surface/fixtures/canvas_surface_layout_constraints_fixture.dart')`, with the fixture containing the focused `testWidgets` regression proof.

Completion Check: The new focused widget fixture proves three direct outcomes through public `CanvasSurface` mounting: a `SizedBox(width: 100, height: 100)` host produces the `ValueKey<String>('iwb_canvas_surface.paint_host')` `CustomPaint` with size `Size(100, 100)` and no tester exception; a vertically unbounded host such as `ListView(children: [CanvasSurface(...)])` produces a `tester.takeException()` or equivalent captured exception that is `isA<FlutterError>()` and whose message contains `CanvasSurface requires bounded width and height`; and a horizontally unbounded host such as a horizontal scroll view produces the same `FlutterError` type and message signal. The package-test entrypoint `test/surface/canvas_surface_layout_constraints_test.dart` uses `runFlutterInPackageTest('test/surface/fixtures/canvas_surface_layout_constraints_fixture.dart')` to run those `testWidgets` checks, matching existing surface test runner seams. The same entrypoint or fixture includes a bounded test-only structural check over `lib/src/surface/canvas_surface_widget.dart` that proves the unbounded check and `FlutterError` are on the ordinary `_paintSizeFor` execution path: the rejection must not be enclosed by `assert`, `kDebugMode`, `!kReleaseMode`, `kProfileMode`, `!kProfileMode`, debug-only closures, profile-only closures, release-excluded conditionals, or equivalent debug/profile gates, and the non-finite fallback tokens `? constraints.maxWidth : 0.0` and `? constraints.maxHeight : 0.0` must be absent from `_paintSizeFor`. Performance compatibility is proved by the implementation diff and structural check showing the policy remains local to `_paintSizeFor` with no runtime/frame/cache/painter/pointer production files changed for this behavior. Existing surface behavior regressions are verified by running `dart test test/surface/widget_paint_test.dart`, `dart test test/surface/pointer_adapter_finite_normalization_test.dart`, `dart test test/surface/interactive_false_pointer_routing_test.dart`, `dart test test/surface/interactive_false_active_session_cancel_test.dart`, `dart test test/surface/interactive_false_pending_line_preserved_test.dart`, `dart test test/surface/interactive_false_state_isolation_test.dart`, and `dart test test/surface/surface_camera_frame_output_test.dart`. Final verification for this unit runs those tests plus `dart test test/surface/canvas_surface_layout_constraints_test.dart`, `dart analyze`, `dcm analyze .`, and `dcm calculate-metrics lib/src/surface test/surface`.

Depends On: none

### [ ] Unit 2: Document bounded layout contract

Owner: `docs/contracts/public_api_v1.md`; `docs/verification/tests.md`; `docs/_registry/sections.yaml`

Boundary: Durable public surface contract, verification policy, and structured documentation relationships.

Change: Add the bounded width-and-height requirement to the `CanvasSurface` surface contract, including the release-mode error behavior, finite-parent guidance, and constant-time surface-boundary performance constraint. Add the focused layout-constraints test to the surface Flutter tests documentation. Register `test.surface.canvas_surface_layout_constraints` under `section_04_public_api_v1` and `section_23_tests` in `docs/_registry/sections.yaml`.

Completion Check: `docs/contracts/public_api_v1.md` states that `CanvasSurface` requires bounded Flutter layout width and height, reports a Flutter error on the ordinary execution path instead of silently painting a zero-size surface under unbounded constraints, and keeps the valid bounded path as a constant-time surface layout-boundary check. `docs/verification/tests.md` names `test/surface/canvas_surface_layout_constraints_test.dart` as the proof for bounded layout preservation, unbounded-axis rejection, release-behavior structural proof, and performance boundary. `docs/_registry/sections.yaml` registers `test.surface.canvas_surface_layout_constraints` under `section_04_public_api_v1` and `section_23_tests`. Documentation verification passes with `dart run docs/tool/sync_generated_docs.dart --check` and `dart run docs/tool/check_docs.dart`; if the generated-docs check reports stale generated navigation, run `dart run docs/tool/sync_generated_docs.dart`, review the generated diff, and rerun both documentation checks.

Depends On: Unit 1
