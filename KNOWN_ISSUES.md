language: english

# Known Issues

Confirmed active defects only.

## Rules

- Keep entries short.
- One entry per root cause.
- Use repository-local IDs in the format `KI-<number>`.
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
