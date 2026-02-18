# Development Plan

## Objective
Implement validated fixes from review with priority on public-contract correctness, then close secondary architectural/performance gaps.

## Wave 1 — P0/P1 (Contract and Release Safety)

### [x] DP-01 (P0) Render typed background layer — Completed 2026-02-18
- Scope:
  - Render `snapshot.backgroundLayer.nodes` in `lib/src/render/scene_painter.dart` before content layers.
  - Keep ordering: `background -> grid -> backgroundLayer -> content layers -> selection/overlay`.
- Acceptance:
  - Add/adjust tests in `test/render/scene_painter_test.dart` for layering order and culling parity.
  - No regressions in existing render tests.

### [x] DP-02 (P0) Normalize command signal semantics (changed-only) — Completed 2026-02-18
- Scope:
  - In `lib/src/controller/commands/scene_commands.dart`, emit:
    - `selection.all` only when selection actually changed.
    - `background.updated`, `grid.enabled.updated`, `grid.cell.updated`, `camera.updated` only when underlying state changed.
- Acceptance:
  - Extend `test/controller/commands/scene_commands_test.dart` for:
    - `selectAll` changed-to-empty scenario.
    - no-op setters emit no signals.
    - no-op setters do not bump commit revision.

### [x] DP-03 (P0) Align release artifacts to schema v5-only — Completed 2026-02-18
- Scope:
  - Bump package to `5.0.0` in `pubspec.yaml`.
  - Reconcile `CHANGELOG.md` release sections with actual codec contract (`schemaVersion=5` read/write set).
  - Align wording in `README.md` and `API_GUIDE.md`.
- Acceptance:
  - No contradictory version/schema statements in docs/changelog.

### DP-04 (P1) Improve JSON boundary diagnostics and payload hardening
- Scope:
  - Add contextual path propagation (`pathPrefix`) across decode helpers in:
    - `lib/src/model/scene_builder_decode_json.part.dart`
    - `lib/src/model/scene_builder_json_require.part.dart`
  - Add upper limits for hostile inputs:
    - max content layers
    - max nodes per scene
    - max stroke points in decode path
    - max `svgPathData` length
  - Define limits in `lib/src/core/scene_limits.dart`.
- Acceptance:
  - Extend `test/model/scene_builder_test.dart` and `test/serialization/scene_codec_validation_test.dart` with:
    - full-path error assertions
    - oversized payload rejection assertions

### DP-05 (P1) Close root `lib/*.dart` coverage blind spot with guardrail
- Scope:
  - Keep coverage scope `lib/src/**` unchanged.
  - Add rule in `tool/check_guardrails.dart`: files under `lib/*.dart` may contain only `library`, docs/comments, and `export` directives.
  - Add sandbox tests in `test/tool/guardrails_tools_test.dart`.
- Acceptance:
  - Guardrail fails when executable logic appears in `lib/*.dart`.

### DP-06 (P1→P2) Introduce phased performance regression gate
- Phase A:
  - Add benchmark diff tool comparing current report vs baseline JSON (smoke/full).
  - Publish diff artifact in CI/nightly; do not fail build yet.
- Phase B:
  - Enable threshold-based fail gate (initially p95 deltas for key metrics).
- Scope:
  - `tool/bench/*`, `.github/workflows/ci.yaml`, `.github/workflows/perf_nightly.yaml`.
- Acceptance:
  - Unit tests for diff logic + deterministic report schema.

## Wave 2 — P2/P3 (Previously omitted, now added)

### DP-07 (P2) Clear-scene signal consistency edge case
- Problem:
  - `writeClearSceneKeepBackground()` may create background-layer structure even when removed count is zero.
  - `scene.cleared` currently depends only on removed ids.
- Scope:
  - Decide and implement one contract:
    - signal on any structural clear-side effect, or
    - no background-layer structural mutation on no-op clear.
  - Align interactive `clearScene` action emission with same rule.
- Acceptance:
  - Add tests for empty scene with missing background layer and for no-op clear semantics.

### DP-08 (P2) TextNode explicit contract hardening (missing before)
- Problem:
  - `TextNode.size` is derived but this is easy to violate in integrations and can cause cross-platform drift in serialized payloads.
- Scope:
  - Keep invariant `TextNode.size` derived from text layout inputs across write/import paths.
  - Add explicit docs section: serialized `size` is derived and not a source of truth.
  - Add regression tests for re-derivation on patch/import for text layout fields.
  - Add compatibility note about platform font metric variance when comparing JSON snapshots.
- Acceptance:
  - Tests in `test/model/document_model_test.dart` + `test/serialization/scene_codec_validation_test.dart` covering derivation and deterministic expectations.

### DP-09 (P2) Overlay painter camera sanitization parity
- Problem:
  - Main painter sanitizes camera offset; overlay painter currently reads raw offset.
- Scope:
  - Apply same finite/sanitize guard in `_SceneInteractiveOverlayPainter`.
- Acceptance:
  - Add tests preventing NaN/Infinity camera crashes in overlay path.

### DP-10 (P3) Render-path efficiency backlog
- Scope:
  - Evaluate and optionally implement:
    - remove color from `SceneTextLayoutCache` key (if layout-only caching intent confirmed);
    - lazy-build path metrics only when needed;
    - optional spatial-candidate-based culling path for very large scenes.
- Acceptance:
  - Bench evidence from DP-06 reports before/after; no visual regressions.

### DP-11 (P3) Runtime invariant enforcement mode review
- Scope:
  - Revisit debug/profile-only invariant checks and document rationale or migrate critical subset to release fail-fast.
- Acceptance:
  - Decision recorded in docs + tests for chosen behavior.

## Validation Checklist
1. `dart format --output=none --set-exit-if-changed lib test example/lib tool`
2. `flutter analyze`
3. `flutter test`
4. `flutter test --coverage`
5. `dart run tool/check_coverage.dart`
6. `dart run tool/check_invariant_coverage.dart`
7. `dart run tool/check_guardrails.dart`
8. `dart run tool/check_import_boundaries.dart`
9. `dart run tool/bench/run_load_profiles.dart --profile=smoke --output=build/bench/load_profiles_smoke.json`

## Assumptions
1. Signals are state-change events, not command-invocation events.
2. Release line is aligned to `5.0.0` for schema v5-only contract.
3. Perf gate rollout is phased: report/diff first, fail-threshold later.
