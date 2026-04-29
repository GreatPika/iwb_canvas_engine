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
