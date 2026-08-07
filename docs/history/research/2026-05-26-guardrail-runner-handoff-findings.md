---
date: 2026-05-26
researcher: Codex
commit: 5e46d96c
branch: new-architecture
research_question: "Inspect P6 handoff findings 1, 2, and 6 around guardrail CI proof, blocking suite expected ids, and guardrail runner cleanup."
---

# Research: Guardrail Runner Handoff Findings

## Summary

The root-package workflow proof is a test-local YAML inspection that reads
`.github/workflows/root_package.yml`, extracts the `root-package` job steps, and
asserts required actions and run commands. It also checks the raw workflow text
for selective guardrail arguments and explicit guardrail ids.

Guardrail ids and regular suite membership are already represented in
`tool/guardrails/src/guardrail_registry.dart`. The blocking suite tests still
keep manual expected-id sets for each regular suite, for the default blocking
selection, and for the P4 structural proof group.

The guardrail executor runs proof tests, optional structural checks, and
core-boundary checks through separate branches. `_negativeFixtureViolationsFor`
is currently private, is called only from the core-boundary branch, and returns
an empty iterable for every input.

## Detailed Findings

### 1. Root Workflow Guardrail Proof

- **Location**: primary `test/guardrails/root_ci_target_test.dart:9`; workflow
  source `.github/workflows/root_package.yml:11`.
- **Description**: The test reads `.github/workflows/root_package.yml` as a
  file, asserts the file exists, and stores its raw content in
  `workflowContent` (`test/guardrails/root_ci_target_test.dart:10`,
  `test/guardrails/root_ci_target_test.dart:12`,
  `test/guardrails/root_ci_target_test.dart:14`).
- **Dependencies**: The test imports `package:yaml/yaml.dart` for parsing and
  imports `guardrail_registry.dart` for `guardrailInventory()`
  (`test/guardrails/root_ci_target_test.dart:4`,
  `test/guardrails/root_ci_target_test.dart:6`).
- **Data flow**: Raw workflow text is parsed with `loadYaml`, then the test reads
  `jobs`, `jobs['root-package']`, and the job `steps`
  (`test/guardrails/root_ci_target_test.dart:32`,
  `test/guardrails/root_ci_target_test.dart:34`,
  `test/guardrails/root_ci_target_test.dart:35`,
  `test/guardrails/root_ci_target_test.dart:37`). Step `run` values are trimmed
  into a set (`test/guardrails/root_ci_target_test.dart:40`,
  `test/guardrails/root_ci_target_test.dart:44`), and step `uses` values are
  trimmed into a set (`test/guardrails/root_ci_target_test.dart:48`,
  `test/guardrails/root_ci_target_test.dart:52`).
- **Current assertions**: The test requires `actions/checkout@v4`,
  `subosito/flutter-action@v2`, `flutter pub get`, `dart analyze`, and
  `dart run tool/guardrails/run.dart`
  (`test/guardrails/root_ci_target_test.dart:19`,
  `test/guardrails/root_ci_target_test.dart:20`,
  `test/guardrails/root_ci_target_test.dart:21`,
  `test/guardrails/root_ci_target_test.dart:22`,
  `test/guardrails/root_ci_target_test.dart:23`).
- **Current selection checks**: The test checks raw workflow text for absence of
  `--guardrail=`, absence of `--suite=`, and absence of every id returned by
  `guardrailInventory().keys` (`test/guardrails/root_ci_target_test.dart:24`,
  `test/guardrails/root_ci_target_test.dart:25`,
  `test/guardrails/root_ci_target_test.dart:26`,
  `test/guardrails/root_ci_target_test.dart:27`).
- **Workflow shape**: The root workflow currently defines job `root-package` on
  `ubuntu-latest` and includes checkout, Flutter setup, dependency install,
  analyze, and guardrail steps (`.github/workflows/root_package.yml:11`,
  `.github/workflows/root_package.yml:12`,
  `.github/workflows/root_package.yml:14`,
  `.github/workflows/root_package.yml:17`,
  `.github/workflows/root_package.yml:22`,
  `.github/workflows/root_package.yml:25`,
  `.github/workflows/root_package.yml:28`).

### 2. Guardrail Registry And Blocking Suite Expected Ids

- **Location**: primary `tool/guardrails/src/guardrail_registry.dart:1`;
  consuming test `test/guardrails/blocking_suite_test.dart:12`.
- **Description**: A `GuardrailEntry` has an `id` and a `Set<String> suites`
  (`tool/guardrails/src/guardrail_registry.dart:1`,
  `tool/guardrails/src/guardrail_registry.dart:4`,
  `tool/guardrails/src/guardrail_registry.dart:5`). The registry source is the
  const `_blockingEntries` list (`tool/guardrails/src/guardrail_registry.dart:23`).
- **Dependencies**: `guardrailInventory()` builds a map from `_blockingEntries`
  (`tool/guardrails/src/guardrail_registry.dart:8`,
  `tool/guardrails/src/guardrail_registry.dart:9`). `blockingGuardrailIds()`
  returns ids from `_blockingEntries`
  (`tool/guardrails/src/guardrail_registry.dart:12`,
  `tool/guardrails/src/guardrail_registry.dart:13`). `suiteGuardrailIds()`
  filters inventory entries by `entry.suites.contains(suite)`
  (`tool/guardrails/src/guardrail_registry.dart:16`,
  `tool/guardrails/src/guardrail_registry.dart:18`,
  `tool/guardrails/src/guardrail_registry.dart:19`).
- **Data flow**: The CLI selects `blockingGuardrailIds()` when no selection
  argument is passed (`tool/guardrails/run.dart:43`,
  `tool/guardrails/run.dart:45`). `--suite=` selection uses
  `suiteGuardrailIds(suite)` (`tool/guardrails/run.dart:54`,
  `tool/guardrails/run.dart:67`,
  `tool/guardrails/run.dart:68`). `--guardrail=` selection validates the id
  against `guardrailInventory()` (`tool/guardrails/run.dart:58`,
  `tool/guardrails/run.dart:77`,
  `tool/guardrails/run.dart:78`).
- **Dry-run output**: Dry-run prints one line per selected id using
  `would run $id via ${route.description}` (`tool/guardrails/run.dart:17`,
  `tool/guardrails/run.dart:18`,
  `tool/guardrails/run.dart:29`,
  `tool/guardrails/run.dart:37`). The blocking suite test parses stdout lines
  that start with `would run ` and extracts the id before ` via `
  (`test/guardrails/blocking_suite_test.dart:158`,
  `test/guardrails/blocking_suite_test.dart:162`,
  `test/guardrails/blocking_suite_test.dart:166`).
- **Manual expected regular suites**: The test keeps manual expected sets for
  `api`, `codec`, `core`, `diagnostics`, `store`, `projection`, `selection`,
  `edit`, and `events` (`test/guardrails/blocking_suite_test.dart:226`,
  `test/guardrails/blocking_suite_test.dart:244`,
  `test/guardrails/blocking_suite_test.dart:250`,
  `test/guardrails/blocking_suite_test.dart:259`,
  `test/guardrails/blocking_suite_test.dart:264`,
  `test/guardrails/blocking_suite_test.dart:269`,
  `test/guardrails/blocking_suite_test.dart:271`,
  `test/guardrails/blocking_suite_test.dart:273`,
  `test/guardrails/blocking_suite_test.dart:282`). These sets are consumed by
  the suite-selection tests (`test/guardrails/blocking_suite_test.dart:33`,
  `test/guardrails/blocking_suite_test.dart:36`,
  `test/guardrails/blocking_suite_test.dart:39`,
  `test/guardrails/blocking_suite_test.dart:42`,
  `test/guardrails/blocking_suite_test.dart:51`,
  `test/guardrails/blocking_suite_test.dart:54`,
  `test/guardrails/blocking_suite_test.dart:63`,
  `test/guardrails/blocking_suite_test.dart:69`,
  `test/guardrails/blocking_suite_test.dart:72`).
- **Manual expected blocking aggregate**: `_expectedBlockingHardBoundaryIds`
  aggregates the manual suite sets and is used by the default dry-run assertion
  and by `_blockingInventoryMatchesExpectedIds()`
  (`test/guardrails/blocking_suite_test.dart:23`,
  `test/guardrails/blocking_suite_test.dart:24`,
  `test/guardrails/blocking_suite_test.dart:114`,
  `test/guardrails/blocking_suite_test.dart:116`,
  `test/guardrails/blocking_suite_test.dart:119`,
  `test/guardrails/blocking_suite_test.dart:317`).
- **Manual expected P4 structural group**: `_p4StructuralGuardrailIds` is a
  manual set of three ids and is compared with `_p4StructuralScanCases`
  (`test/guardrails/blocking_suite_test.dart:103`,
  `test/guardrails/blocking_suite_test.dart:105`,
  `test/guardrails/blocking_suite_test.dart:106`,
  `test/guardrails/blocking_suite_test.dart:284`,
  `test/guardrails/blocking_suite_test.dart:290`).

### 3. Guardrail Executor And Negative Fixture Hook

- **Location**: primary `tool/guardrails/src/guardrail_executor.dart:42`;
  negative hook `tool/guardrails/src/guardrail_executor.dart:159`.
- **Description**: `runGuardrails()` delegates to
  `runGuardrailsWithProofRunner()` with `_runDartTest`
  (`tool/guardrails/src/guardrail_executor.dart:42`,
  `tool/guardrails/src/guardrail_executor.dart:43`). The injectable runner keeps
  a list of ran ids, caches proof exit codes, and uses either injected
  `violationChecks` or `_violationChecks`
  (`tool/guardrails/src/guardrail_executor.dart:46`,
  `tool/guardrails/src/guardrail_executor.dart:51`,
  `tool/guardrails/src/guardrail_executor.dart:52`,
  `tool/guardrails/src/guardrail_executor.dart:53`).
- **Data flow for ids with proof paths**: `_runGuardrail()` looks up
  `_testProofPaths[id]`, runs each proof path through `runDartTest`, caches each
  result by `dart-test:$path`, stops on a non-zero proof result, then runs an
  optional structural check for the same id
  (`tool/guardrails/src/guardrail_executor.dart:94`,
  `tool/guardrails/src/guardrail_executor.dart:96`,
  `tool/guardrails/src/guardrail_executor.dart:97`,
  `tool/guardrails/src/guardrail_executor.dart:98`,
  `tool/guardrails/src/guardrail_executor.dart:102`,
  `tool/guardrails/src/guardrail_executor.dart:107`,
  `tool/guardrails/src/guardrail_executor.dart:109`).
- **Data flow for structural-only ids**: If no proof path exists and
  `violationChecks[id]` exists, `_runGuardrail()` reports those violations
  before reaching the core-boundary branch
  (`tool/guardrails/src/guardrail_executor.dart:115`,
  `tool/guardrails/src/guardrail_executor.dart:116`,
  `tool/guardrails/src/guardrail_executor.dart:117`,
  `tool/guardrails/src/guardrail_executor.dart:120`).
- **Core-boundary branch**: If the id is in `_coreBoundaryIds`, `_runGuardrail()`
  reports violations from `checkCoreBoundaries()` plus
  `_negativeFixtureViolationsFor(id)`
  (`tool/guardrails/src/guardrail_executor.dart:120`,
  `tool/guardrails/src/guardrail_executor.dart:121`,
  `tool/guardrails/src/guardrail_executor.dart:122`,
  `tool/guardrails/src/guardrail_executor.dart:123`).
- **Current hook behavior**: `_negativeFixtureViolationsFor()` returns
  `const []` when the id is not in `blockingGuardrailIds()` and also returns
  `const []` after that branch (`tool/guardrails/src/guardrail_executor.dart:159`,
  `tool/guardrails/src/guardrail_executor.dart:160`,
  `tool/guardrails/src/guardrail_executor.dart:161`,
  `tool/guardrails/src/guardrail_executor.dart:164`). The only found call is the
  core-boundary spread expression
  (`tool/guardrails/src/guardrail_executor.dart:123`).
- **In-memory negative checks**: `test/guardrails/import_boundaries_test.dart`
  creates violations with `checkCoreBoundaryFile()` and injects them into
  `runGuardrailsWithProofRunner()` through `violationChecks`
  (`test/guardrails/import_boundaries_test.dart:24`,
  `test/guardrails/import_boundaries_test.dart:26`,
  `test/guardrails/import_boundaries_test.dart:41`,
  `test/guardrails/import_boundaries_test.dart:44`). `test/guardrails/core_boundary_negative_fixtures_test.dart`
  checks a fixture list by passing in-memory path/content pairs to
  `checkCoreBoundaryFile()` (`test/guardrails/core_boundary_negative_fixtures_test.dart:6`,
  `test/guardrails/core_boundary_negative_fixtures_test.dart:17`,
  `test/guardrails/core_boundary_negative_fixtures_test.dart:21`,
  `test/guardrails/core_boundary_negative_fixtures_test.dart:38`).

## Code References

- `test/guardrails/root_ci_target_test.dart:9` - root workflow proof test entry.
- `test/guardrails/root_ci_target_test.dart:32` - workflow YAML parsing helper.
- `.github/workflows/root_package.yml:11` - root-package job declaration.
- `tool/guardrails/src/guardrail_registry.dart:1` - guardrail entry model.
- `tool/guardrails/src/guardrail_registry.dart:16` - suite lookup API.
- `tool/guardrails/run.dart:43` - CLI selection logic.
- `test/guardrails/blocking_suite_test.dart:226` - first manual expected suite
  id set.
- `test/guardrails/blocking_suite_test.dart:284` - manual P4 structural id set.
- `tool/guardrails/src/guardrail_executor.dart:46` - injectable guardrail
  execution entry.
- `tool/guardrails/src/guardrail_executor.dart:159` - negative fixture hook.
- `test/guardrails/import_boundaries_test.dart:41` - injected violation runner
  proof.
- `test/guardrails/core_boundary_negative_fixtures_test.dart:38` - in-memory
  negative fixture list.

## Observed Architecture Facts

- Pattern observed: registry-owned suite membership is already available through
  `suiteGuardrailIds()` and consumed by the CLI selection path
  (`tool/guardrails/src/guardrail_registry.dart:16`,
  `tool/guardrails/run.dart:67`).
- Pattern observed: runner tests can inject proof runners and violation runners
  directly through `runGuardrailsWithProofRunner()`
  (`tool/guardrails/src/guardrail_executor.dart:46`,
  `test/guardrails/blocking_suite_test.dart:77`,
  `test/guardrails/import_boundaries_test.dart:41`).
- Data flow: registry entries -> CLI selection -> dry-run stdout -> parsed test
  ids (`tool/guardrails/src/guardrail_registry.dart:23`,
  `tool/guardrails/run.dart:45`,
  `tool/guardrails/run.dart:68`,
  `tool/guardrails/run.dart:37`,
  `test/guardrails/blocking_suite_test.dart:158`).
- Data flow: workflow YAML file -> `loadYaml` -> `root-package` job steps ->
  run/action sets -> assertions (`.github/workflows/root_package.yml:11`,
  `test/guardrails/root_ci_target_test.dart:32`,
  `test/guardrails/root_ci_target_test.dart:35`,
  `test/guardrails/root_ci_target_test.dart:40`,
  `test/guardrails/root_ci_target_test.dart:48`).

## Open Questions

- No repository-local GitHub Actions bypass-inspection helper was observed in the
  current root package under `test` or `tool`; the existing workflow proof is
  test-local (`test/guardrails/root_ci_target_test.dart:9`).
- The current registry has regular suites such as `api`, `core`, and `store`,
  but no observed `p4-structural` suite or equivalent explicit phase/proof group
  in `tool/guardrails/src/guardrail_registry.dart:23`.
