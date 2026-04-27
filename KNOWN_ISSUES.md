language: english

# Known Issues

Confirmed active defects only.

## Rules

- Keep entries short.
- One entry per root cause.
- Use repository-local IDs in the format `KI-1`, `KI-2`, `KI-3`, ...
- Do not put feature ideas, vague risks, or temporary notes here.
- If an issue is listed here, it is unresolved.
- Do not track status here.
- Remove an entry in the same change that fixes it and adds regression proof.
- This file is not an archive.

## Entry Template

- `ID`
- `Severity`
- `Summary`
- `Detection`
- `Evidence`
- `Next action`

## Active Issues

### KI-2

- ID: `KI-2`
- Severity: `P2`
- Summary: Validated snapshot fast-path materialization can expose
  `SceneSnapshot` and `NodeSnapshot` objects built from raw backing without
  full value validation.
- Detection:
  `dart run tool/audit_route_expectations.dart`,
  `dart run tool/audit_validated_materialization_paths.dart`,
  `dart run tool/audit_bridge_surfaces.dart`
- Evidence:
  - `tool/audit/route_expectations_boundary_audit.json`
  - `lib/src/contract/internal/snapshot_materialization.dart`
  - `lib/src/contract/internal/snapshot_fast_path.dart`
  - Current detections:
    `nodeSnapshotFromValidatedBacking` does not reach
    `validateSnapshotCommonSchemaFields`;
    `sceneSnapshotFromValidatedBacking` does not reach
    `sceneValidateImportDraftValues`;
    `snapshot_fast_path.dart` exports raw backing and
    materialization-from-backing helpers
- Next action: Add full value validation before validated snapshot
  materialization or narrow the fast-path surface.

### KI-3

- ID: `KI-3`
- Severity: `P1`
- Summary: Interactive draw terminal cleanup is not exception-safe, so draw
  session, preview, or buffer state can survive a failing terminal commit path.
- Detection:
  `dart run tool/audit_terminal_cleanup_safety.dart`,
  `dart run tool/audit_post_commit_cleanup_order.dart`
- Evidence:
  - `lib/src/interactive/internal/interactive_draw_terminal_router.dart`
  - `lib/src/interactive/internal/interactive_draw_stroke_engine.dart`
  - `lib/src/interactive/internal/interactive_draw_line_engine.dart`
  - `lib/src/interactive/internal/interactive_draw_eraser_engine.dart`
  - Broad `lib/src` sweep currently adds no extra families beyond draw terminal
    cleanup; `InteractiveMoveSession._moveHandleUp` already uses `finally`.
  - Current terminal-cleanup detections:
    `InteractiveDrawTerminalRouter.handleUp`,
    `InteractiveDrawStrokeEngine.commitOnUp`,
    `InteractiveDrawLineEngine._commitDraggedLine`,
    `InteractiveDrawEraserEngine.commitOnUp`
  - Current post-commit cleanup-order detections:
    `InteractiveDrawTerminalRouter.handleUp`,
    `InteractiveDrawStrokeEngine.commitOnUp`,
    `InteractiveDrawLineEngine._commitDraggedLine`
- Next action: Guarantee terminal draw cleanup through `finally` at the draw
  owner seam and add regression tests for failing stroke, line, and eraser
  commits.

### KI-4

- ID: `KI-4`
- Severity: `P2`
- Summary: Runtime stroke value diagnostics do not enforce the same upper
  `sceneThicknessMax` bound as snapshot/backing validation, so oversized
  `StrokeNode.thickness` can escape runtime invariant reporting.
- Detection: Compare runtime/snapshot/backing stroke validators in
  `lib/src/model/scene_value_validation_node_stroke.dart`
- Evidence:
  - `lib/src/model/scene_value_validation_node_stroke.dart`
  - `lib/src/model/scene_value_validation_node_line.dart`
  - Current detections:
    `sceneValidateStrokeNode` checks positive finite thickness but skips
    `sceneValidateDoubleInRange(... max: sceneThicknessMax)`;
    `sceneValidateStrokeNodeSnapshot` and
    `sceneValidateStrokeNodeSnapshotBacking` do enforce the upper bound;
    `sceneValidateLineNode` already keeps runtime/snapshot/backing thickness
    validation aligned through `_sceneValidateLineNodeFields`
- Next action: Add the missing runtime `sceneThicknessMax` range check for
  stroke thickness and cover it with runtime diagnostic tests.

### KI-5

- ID: `KI-5`
- Severity: `P2`
- Summary: Direct model-level scene insertion trusts caller-supplied derived
  locator/index state as the sole uniqueness and budget source, so stale or
  incomplete maps can admit duplicate ids or undercount node budget.
- Detection: Inspect topology mutation helpers in
  `lib/src/model/document_scene_insert.dart` against derived locator builders
  in `lib/src/model/document_locator.dart`
- Evidence:
  - `lib/src/model/document_scene_insert.dart`
  - `lib/src/model/document_locator.dart`
  - Current detections:
    `txnInsertNodeInScene` uses `nodeLocator.containsKey(node.id)` for
    uniqueness and `nodeLocator.length` for node budget;
    `txnInsertContentLayerInScene` uses
    `layerIndexById.containsKey(layerId)` for uniqueness;
    both paths can bypass topology invariants when caller-provided derived
    indexes are stale or incomplete
- Next action: Move uniqueness and budget checks to actual scene topology or
  make the fast-path freshness precondition explicit and enforced.

### KI-6

- ID: `KI-6`
- Severity: `P2`
- Summary: Fill-only path hit-testing applies `hitPadding` to coarse candidate
  bounds but not to the precise path hit-test, so touch padding around filled
  paths is inconsistent with other node families.
- Detection: Compare path candidate-bounds inflation with precise path hit-test
  in `lib/src/core/node_geometry.dart`
- Evidence:
  - `lib/src/core/hit_test.dart`
  - `lib/src/core/node_geometry.dart`
  - Current detections:
    `nodeGeometryCandidateBoundsWorld` and
    `nodeSnapshotGeometryCandidateBoundsWorld` inflate by
    `hitPadding + kHitSlop`;
    `_hitTestPathGeometry` only accepts fill hits through
    `localPath.contains(localPoint)`;
    `_pathStrokeRadiusLocal` returns `0` for fill-only paths, so padding never
    reaches the precise check when `strokeColor == null`
- Next action: Align fill-only path precise hit-testing with shared
  `hitPadding` semantics and add runtime/snapshot hit-test regression cases.

### KI-7

- ID: `KI-7`
- Severity: `P3`
- Summary: Paint candidate admission uses different edge-touch predicates in
  committed spatial queries and snapshot-local fallback, so committed paint
  plans can include ordinary candidates that snapshot fallback excludes.
- Detection: Compare committed paint admission in
  `lib/src/core/scene_spatial_index.dart` with snapshot fallback admission in
  `lib/src/core/scene_snapshot_paint_candidates.dart`
- Evidence:
  - `lib/src/core/scene_spatial_index.dart`
  - `lib/src/core/scene_snapshot_paint_candidates.dart`
  - Current detections:
    committed paint queries resolve candidates through an inclusive boundary
    predicate;
    snapshot-local fallback uses strict `Rect.overlaps`;
    painter culling is also strict, so the drift currently affects candidate
    plan parity and staging work rather than confirmed pixels
- Next action: Choose one shared paint admission boundary policy, codify it in
  tests, and remove the committed-vs-snapshot drift.

### KI-8

- ID: `KI-8`
- Severity: `P1`
- Summary: Selection rendering redraws base line/stroke/open-path geometry in a
  late overlay pass, which can change alpha, break scene draw order, and add
  extra stroke-path work for selected vector nodes.
- Detection: Compare content-pass node rendering in
  `lib/src/render/scene_painter_node_renderer.dart` with selection-pass redraws
  in `lib/src/render/scene_painter_selection.dart`
- Evidence:
  - `lib/src/render/scene_painter_shell.dart`
  - `lib/src/render/scene_painter_node_renderer.dart`
  - `lib/src/render/scene_painter_selection.dart`
  - `lib/src/render/scene_painter_shared.dart`
  - Current detections:
    selected `LineNodeSnapshot` base geometry is redrawn in
    `_drawLineSelection` after the full content pass;
    selected `StrokeNodeSnapshot` base geometry is redrawn in
    `_drawStrokePathSelection` / `_drawDotSelection` after the full content
    pass;
    selected open `PathNodeSnapshot` stroke is redrawn in
    `_drawOpenPathSelection` after the full content pass;
    large selected strokes can rebuild stroke paths twice per frame when no
    `SceneStrokePathCache` is supplied
- Next action: Remove base-geometry redraw from the selection overlay or
  replace it with bounded halo compositing, then add render tests for
  alpha-preservation, overlap order, and open-path parity.

### KI-11

- ID: `KI-11`
- Severity: `P2`
- Summary: The API docs / Pages workflow is outside the verification contract,
  so executable workflow drift in `.github/workflows/api_docs_pages.yaml` is
  not checked by the contract checker.
- Detection: Compare workflow coverage in
  `tool/src/verification_contract/verification_contract_registry.dart` and
  `tool/check_verification_contract.dart` with committed workflows under
  `.github/workflows`
- Evidence:
  - `tool/src/verification_contract/verification_contract_registry.dart`
  - `tool/check_verification_contract.dart`
  - `.github/workflows/api_docs_pages.yaml`
  - `ARCHITECTURE.md`
  - Current detections:
    verification contract registry and checker only cover `ci.yaml` and
    `perf_nightly.yaml`;
    `.github/workflows/api_docs_pages.yaml` contains executable run commands
    but has no workflow definition in the contract graph
- Next action: Add `api_docs_pages.yaml` to the verification contract graph and
  checker, or explicitly document and test that it is intentionally excluded.

### KI-12

- ID: `KI-12`
- Severity: `P2`
- Summary: The load-profile runner validates case names and probes but does not
  validate required metrics, required operations, or required metric keys
  before writing benchmark reports.
- Detection: Compare runner-side validation in
  `tool/bench/run_load_profiles.dart` with contract metadata in
  `tool/bench/load_profile_policy.dart`
- Evidence:
  - `tool/bench/load_profile_policy.dart`
  - `tool/bench/run_load_profiles.dart`
  - `tool/bench/diff_load_profiles.dart`
  - `test/tool/bench_run_load_profiles_test.dart`
  - Current detections:
    runner-side contract validation checks case names and probes but can still
    emit reports missing required operations or required metric leaves;
    diff-side validation rejects part of that corruption later, after the
    malformed report has already been written
- Next action: Add runner-side validation for raw metrics, required operations,
  required metric keys, and finite metric values before report emission.

### KI-13

- ID: `KI-13`
- Severity: `P3`
- Summary: Load-profile diff output uses `...Us` field names even for RSS byte
  metrics, so the emitted schema mislabels memory values as microseconds.
- Detection: Inspect metric diff output construction in
  `tool/bench/diff_load_profiles.dart` against metric taxonomy in
  `tool/bench/load_profile_policy.dart`
- Evidence:
  - `tool/bench/load_profile_policy.dart`
  - `tool/bench/diff_load_profiles.dart`
  - `test/tool/bench_diff_load_profiles_test.dart`
  - Current detections:
    `avgRssDeltaBytes`, `minRssDeltaBytes`, and `maxRssDeltaBytes` are emitted
    through the same `baselineUs/currentUs/deltaAbsUs` shape used for latency
    metrics
- Next action: Switch diff output to a unit-truthful schema, for example
  neutral value fields plus an explicit unit, and add tests for latency vs RSS
  metric output.

### KI-14

- ID: `KI-14`
- Severity: `P3`
- Summary: Load-profile diff input validation does not reject duplicate case
  names or stale `caseCount`, so malformed baseline/current reports can be
  silently normalized before comparison.
- Detection: Compare runner-side case taxonomy validation with diff-side report
  ingestion in `tool/bench/diff_load_profiles.dart`
- Evidence:
  - `tool/bench/run_load_profiles.dart`
  - `tool/bench/load_profile_policy.dart`
  - `tool/bench/diff_load_profiles.dart`
  - `test/tool/bench_diff_load_profiles_test.dart`
  - Current detections:
    diff report ingestion does not validate `caseCount`;
    duplicate case names collapse into a map keyed by case name;
    malformed baseline/current artifacts can therefore lose taxonomy defects
    before diff status is computed
- Next action: Reject duplicate case names and mismatched `caseCount` during
  diff input parsing, before baseline/current cases are converted into maps.

### KI-15

- ID: `KI-15`
- Severity: `P3`
- Summary: Architecture family invariant ownership is enforced from a
  checker-local map instead of a registry-owned source of truth, so future
  invariant additions require manual synchronization across the invariant
  registry, atlas checker, checker fixtures, and family docs.
- Detection: Compare expected architecture-family invariant ids in
  `tool/check_architecture_atlas.dart` and
  `test/tool/architecture_atlas_tool_test.dart` with canonical invariant
  definitions in `tool/invariant_registry.dart`.
- Evidence:
  - `tool/check_architecture_atlas.dart`
  - `test/tool/architecture_atlas_tool_test.dart`
  - `tool/invariant_registry.dart`
  - `docs/architecture/families/*.md`
  - Current detections:
    `tool/check_architecture_atlas.dart` owns the
    `family -> expected invariant ids` map separately from
    `tool/invariant_registry.dart`;
    `test/tool/architecture_atlas_tool_test.dart` keeps a parallel fixture map;
    adding a new registry-backed invariant can pass invariant coverage while
    still requiring manual atlas-family mapping updates.
- Next action: Move architecture-family ownership for invariants into
  `tool/invariant_registry.dart` or a registry-owned companion, then derive
  atlas checker expectations and tests from that source so unmapped invariants
  fail mechanically.
