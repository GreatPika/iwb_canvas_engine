language: russian

# Шаг 77. Синхронизировать CI trigger surface tool-tests с repo-local public entrypoint dependencies

## 1. Change Mandate

Этот шаг чинит `tool-tests` CI trigger surface так, чтобы изменения `lib/iwb_canvas_engine.dart` и drift между `.github/workflows/ci.yaml` и `VERIFICATION.md` больше не могли тихо пропускать обязательный tool-test контур.

## 2. Change Boundary

### Included in the Change

- Добавление `lib/iwb_canvas_engine.dart` в `tool_tests` trigger surface в `.github/workflows/ci.yaml`.
- Выравнивание tool-test trigger list в `VERIFICATION.md` с фактическим CI filter.
- Добавление repository-local drift check для tool-test trigger surface, который механически сравнивает `.github/workflows/ci.yaml` и `VERIFICATION.md` и проверяет обязательные repo-local trigger entries.
- Добавление targeted tool tests для нового trigger-surface checker.

### Not Included in the Change

- Любая попытка автоматически выводить полный tool-test trigger surface из transitive Dart imports, `File(...)` вызовов или sandbox fixtures.
- Любая смена состава самих tool tests, их sandbox behavior или semantics `check_guardrails.dart` / `check_public_api_surface.dart`.
- Любая работа по invariant registry или render proof surface в этом шаге.

## 3. File Map and Analysis Areas

### Implementation Files

- `.github/workflows/ci.yaml`
- `VERIFICATION.md`
- `tool/check_tool_test_trigger_surface.dart`

### Test Files

- `test/tool/tool_test_trigger_surface_tool_test.dart`
- `test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart`
- `test/tool/guardrails/guardrails_public_surface_tool_test.dart`

### Fixture and Supporting Data Files

- `test/tool/support/public_entrypoint_contract.dart`
- `test/tool/support/guardrails_tool_test_support.dart`
- `PLAN.md`
- `plan/step_77_tool_test_trigger_surface_and_public_entrypoint_dependency.md`

### Analysis Area

- `.github/workflows/ci.yaml`
- `VERIFICATION.md`
- `tool/check_tool_test_trigger_surface.dart`
- `test/tool/tool_test_trigger_surface_tool_test.dart`
- `test/tool/support/public_entrypoint_contract.dart`
- `test/tool/guardrails/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified fixture must be tied to a specific verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Tool-test trigger surface remains an explicit repo-local allowlist; this step does not introduce heuristic dependency discovery.
2. `lib/iwb_canvas_engine.dart` is a required tool-test trigger entry because `test/tool/support/public_entrypoint_contract.dart` reads it directly and guardrails/public-surface tool tests depend on that helper.
3. `.github/workflows/ci.yaml` and `VERIFICATION.md` must carry the same tool-test trigger surface.
4. Trigger-surface drift must be checked on an always-on verification surface, not only inside the conditional `tool-tests` CI job.

## 5. Result Requirements

1. The `tool_tests` filter in `.github/workflows/ci.yaml` includes `lib/iwb_canvas_engine.dart`.
2. The documented tool-test trigger list in `VERIFICATION.md` matches the CI filter exactly.
3. A repository-local checker fails when the CI filter and `VERIFICATION.md` drift or when `lib/iwb_canvas_engine.dart` is missing from the required trigger set.
4. Tool-tests run on CI when `lib/iwb_canvas_engine.dart` changes.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `.github/workflows/ci.yaml` currently runs `tool-tests` only when the explicit `tool_tests` paths-filter matches a hardcoded path list.
- `VERIFICATION.md` already duplicates that same trigger list and says it must stay identical to `.github/workflows/ci.yaml`.
- `test/tool/support/public_entrypoint_contract.dart` reads `lib/iwb_canvas_engine.dart` directly from the repository root.
- `test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart` and `test/tool/guardrails/guardrails_public_surface_tool_test.dart` import `public_entrypoint_contract.dart`, so changes to the public entrypoint can change tool-test outcomes even when no `tool/**` or `test/tool/**` file changed.

### 6.2 Target Verification Units

- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/run_tool_tests.dart test/tool/tool_test_trigger_surface_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart test/tool/guardrails/guardrails_public_surface_tool_test.dart`

### 6.3 Protected States, Data, or Structures

- The current conditional `tool-tests` CI job shape and its `dorny/paths-filter` usage.
- The current documented trigger-surface role of `VERIFICATION.md`.
- The current public-entrypoint contract helper behavior in `test/tool/support/public_entrypoint_contract.dart`.

### 6.4 Allowed Semantic Change Zones

- Tool-test trigger-surface entries.
- Trigger-surface drift-check semantics.
- Verification documentation for the trigger-surface contract.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- quoted path entries inside the `tool_tests` block in `.github/workflows/ci.yaml`;
- markdown bullet entries in the tool-test trigger list block in `VERIFICATION.md`;
- required repo-local trigger entries that are not under `tool/**` or `test/tool/**`.

### 6.6 Allowed Forms That Do Not Count as Violations

- Existing `tool/**`, `test/tool/**`, support-file, and `pubspec.*` trigger entries remaining unchanged.
- Explicit trigger-list expansion when the same new entry is added to both `.github/workflows/ci.yaml` and `VERIFICATION.md`.
- Reordering or formatting changes outside the parsed trigger-surface blocks when the normalized trigger set remains unchanged.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- The trigger-surface checker must read the `tool_tests` list from `.github/workflows/ci.yaml`.
- The trigger-surface checker must read the documented trigger list from `VERIFICATION.md`.
- The checker must compare normalized repo-relative path entries, not raw line formatting.
- The checker must require `lib/iwb_canvas_engine.dart` to be present in both sources.
- The checker must run from an always-on verification surface so a skipped `tool-tests` job cannot hide trigger drift.

### 6.8 Prohibited

- Replacing the explicit trigger list with a heuristic scan of imports or filesystem reads.
- Updating `.github/workflows/ci.yaml` without updating `VERIFICATION.md`, or vice versa.
- Keeping the new checker only inside the conditional `tool-tests` job.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the trigger point must be attached.
7. If a slice changes an analysis rule, negative and positive scenarios must be covered where applicable to the subject of the change.
8. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [x] Trigger Surface Alignment And Drift Check

#### Slice Contract

The repository keeps one mechanically enforced tool-test trigger surface shared by `.github/workflows/ci.yaml` and `VERIFICATION.md`, and that surface explicitly covers `lib/iwb_canvas_engine.dart`.

#### Change

Добавить `lib/iwb_canvas_engine.dart` в CI/documented trigger list, затем ввести always-on checker и targeted tool tests, которые fail-fast on trigger drift or missing required public-entrypoint dependency.

#### Verification

- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/run_tool_tests.dart test/tool/tool_test_trigger_surface_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart test/tool/guardrails/guardrails_public_surface_tool_test.dart`

#### Fixtures Used

- `test/tool/support/public_entrypoint_contract.dart`
- `test/tool/support/guardrails_tool_test_support.dart`

#### Positive Scenarios

- The checker passes when `.github/workflows/ci.yaml` and `VERIFICATION.md` carry the same normalized trigger list including `lib/iwb_canvas_engine.dart`.
- The public-entrypoint-dependent guardrails tool tests remain green after the trigger-surface alignment.

#### Negative Scenarios

- The checker fails when `lib/iwb_canvas_engine.dart` is missing from either `.github/workflows/ci.yaml` or `VERIFICATION.md`.
- The checker fails when the CI filter and documented trigger list drift.

#### Closure Evidence

- Green run of the listed verifications.
- Diagnostic output from the checker for missing `lib/iwb_canvas_engine.dart` and CI/doc drift scenarios.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test shard presets: `core`, `model_contract`, `controller_internal`, `controller`, `render_view`, `interactive`, `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`
