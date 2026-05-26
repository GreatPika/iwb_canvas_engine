# Change Contract

## Goal

Close P6 handoff findings 1, 2, and 6 by making the root CI guardrail proof reject bypass settings, moving guardrail suite/proof expectations back to the guardrail registry as the source of truth, and removing the dead negative-fixture runner hook without changing guardrail semantics.

## Evidence

- `P6_HANDOFF_FINDINGS.md` / findings 1, 2, and 6: records the requested cleanup surfaces for root CI bypass proof, hand-maintained blocking suite ids, and the dead negative-fixture runner hook -> the step scope is limited to those three findings and their direct proof surfaces.
- `test/guardrails/root_ci_target_test.dart` / workflow proof: reads `.github/workflows/root_package.yml`, parses the `root-package` job steps with `loadYaml`, and asserts required actions and commands, but currently only checks raw workflow text for selective guardrail arguments and ids -> bypass rejection belongs in this existing workflow proof.
- `.github/workflows/root_package.yml` / root-package job: runs checkout, Flutter setup, dependency install, `dart analyze`, and `dart run tool/guardrails/run.dart` in one `root-package` job -> the proof must inspect this job and the `Run guardrails` step, not unrelated workflows.
- `tool/guardrails/src/guardrail_registry.dart` / guardrail inventory: `GuardrailEntry` owns each guardrail id and suite membership, while `suiteGuardrailIds()` filters entries by suite -> suite and runner-proof group membership should be derived from this registry rather than duplicated in tests.
- `tool/guardrails/run.dart` / CLI selection: default selection uses `blockingGuardrailIds()`, `--suite=` uses `suiteGuardrailIds()`, and dry-run prints `would run <id> via <route>` -> blocking suite tests should compare CLI dry-run output to registry-derived expected ids.
- `test/guardrails/blocking_suite_test.dart` / runner inventory proof: manually maintains expected suite id sets and a manual `_p4StructuralGuardrailIds` set, then compares dry-run output and structural scan cases to those sets -> the test should derive those expected ids from registry APIs.
- `tool/guardrails/src/guardrail_executor.dart` / executor: `_negativeFixtureViolationsFor()` is called only from the core-boundary branch and returns `const []` for every path -> the runner should remove that hook until a real negative-fixture execution seam exists.
- `test/guardrails/import_boundaries_test.dart` and `test/guardrails/core_boundary_negative_fixtures_test.dart` / negative proof seams: existing tests already inject in-memory violations through `runGuardrailsWithProofRunner()` and check in-memory fixtures through `checkCoreBoundaryFile()` -> the cleanup must preserve these proof seams instead of adding fixture-only data to production source files.
- `.research/2026-05-26-guardrail-runner-handoff-findings.md` / research note: records that no separate GitHub Actions bypass helper exists, regular suite membership is already registry-owned, and no `p4-structural` or equivalent proof group is currently present in the registry -> the implementation may add a narrowly named registry proof group but should not introduce broad helper layers.

## Boundaries

Owner:

Guardrail verification tooling and its tests: `.github/workflows/root_package.yml`, `test/guardrails/root_ci_target_test.dart`, `tool/guardrails/src/guardrail_registry.dart`, `tool/guardrails/src/guardrail_executor.dart`, `test/guardrails/blocking_suite_test.dart`, existing focused guardrail tests, `P6_HANDOFF_FINDINGS.md`, `PLAN.md`, and this linked step document.

In Scope:

- Strengthen the root-package workflow proof so the `root-package` job and `Run guardrails` step cannot silently bypass the guardrail runner through `continue-on-error` or `if` conditions.
- Replace manually maintained expected ids in `test/guardrails/blocking_suite_test.dart` with registry-derived expectations for default blocking selection and named suites.
- Add one registry-owned semantic proof marker for guardrails that require runner-level structural scan proof. This marker must be a dedicated `GuardrailEntry` field named `requiresRunnerStructuralProof` plus a public registry accessor named `runnerStructuralProofGuardrailIds()`, not a CLI suite. Do not use a scheduling-only `phase`, `step`, or `P6` marker.
- Remove `_negativeFixtureViolationsFor()` and its runner call site while preserving current production scans and in-memory negative proof tests.
- Remove or otherwise close the now-resolved entries for findings 1, 2, and 6 in `P6_HANDOFF_FINDINGS.md` after the executable checks prove the cleanup.
- Mark Step 33 complete in `PLAN.md` and in this linked step document after the executable checks prove the cleanup.

Out of Scope:

- Findings 3, 4, 5, and 7 in `P6_HANDOFF_FINDINGS.md`.
- New negative-fixture framework, filesystem fixture runner, generated fixture registry, or guardrail execution mode.
- Changes to guardrail rule semantics, public APIs, schema validation, architecture graph files, or unrelated CI jobs.
- Rewriting the guardrail runner CLI format beyond what is required to keep existing dry-run parsing working.
- Documentation portal or generated docs updates under `docs/`.

Source of Truth:

- Guardrail id, suite, and runner structural proof membership: `tool/guardrails/src/guardrail_registry.dart`.
- Guardrail execution order and proof/structural scan routing: `tool/guardrails/src/guardrail_executor.dart`.
- Root CI workflow command and bypass proof: `.github/workflows/root_package.yml` plus `test/guardrails/root_ci_target_test.dart`.
- Remaining P6 cleanup inventory until resolved: `P6_HANDOFF_FINDINGS.md`.

Compatibility:

- `dart run tool/guardrails/run.dart`, `--dry-run`, `--suite=<name>`, and `--guardrail=<id>` must keep their existing public CLI behavior for current suites and guardrail ids.
- The runner structural proof group must not create a new `--suite=` selection; it is registry metadata consumed by tests only.
- Existing guardrail ids must not be renamed.
- Existing in-memory negative proof seams through `checkCoreBoundaryFile()` and injected `violationChecks` must remain usable.
- The root workflow must continue to run the full guardrail runner command without `--suite=` or `--guardrail=`.

Order Constraints:

1. Harden the workflow proof first so CI bypass behavior is mechanically defined before handoff closure.
2. Move expected id/proof-group ownership into the guardrail registry before rewriting blocking suite assertions that consume it.
3. Remove the dead runner hook only after the workflow proof and registry expectation cleanup are complete, and confirm existing negative proof seams remain the bounded proof mechanism in the same unit.
4. Update `P6_HANDOFF_FINDINGS.md`, `PLAN.md`, and this linked step document only after the focused executable checks for units 1 through 3 pass.

## Execution Units

### [x] Unit 1: Root CI Bypass Proof

Owner:

`test/guardrails/root_ci_target_test.dart` owns the root workflow structural proof for `.github/workflows/root_package.yml`.

Boundary:

Only the `root-package` job and the `Run guardrails` step in `.github/workflows/root_package.yml`.

Change:

Extend the existing YAML-based workflow test so it locates the `root-package` job map and the `Run guardrails` step, then asserts:

- the job does not set `continue-on-error`;
- the job does not set an `if` condition;
- the guardrail step does not set `continue-on-error`;
- the guardrail step does not set an `if` condition;
- the guardrail step command remains exactly `dart run tool/guardrails/run.dart`;
- the existing checks still reject selective guardrail execution through `--suite=`, `--guardrail=`, or direct guardrail ids in the workflow content.

Completion Check:

`dart test test/guardrails/root_ci_target_test.dart` passes, and the test would fail if `continue-on-error` is added to the `root-package` job, an `if` key is added to the `root-package` job, `continue-on-error` is added to the `Run guardrails` step, or an `if` key is added to the `Run guardrails` step.

Depends On:

None.

### [x] Unit 2: Registry-Owned Suite And Structural-Proof Expectations

Owner:

`tool/guardrails/src/guardrail_registry.dart` owns guardrail membership metadata; `test/guardrails/blocking_suite_test.dart` owns runner selection and runner structural proof assertions.

Boundary:

Guardrail registry entries and blocking suite tests only.

Change:

Extend `GuardrailEntry` with a `requiresRunnerStructuralProof` boolean that defaults to `false`, and add `runnerStructuralProofGuardrailIds()` to `tool/guardrails/src/guardrail_registry.dart`. Set `requiresRunnerStructuralProof: true` only on the existing guardrails currently covered by the structural scan case list: `store.no_public_document_live_state`, `projection.only_explicit_read_paths`, and `selection.owner_separate_from_document`.

Rewrite `test/guardrails/blocking_suite_test.dart` so:

- default dry-run selection is compared with `blockingGuardrailIds()`;
- named suite dry-run selections are compared with `suiteGuardrailIds(<suite>)`;
- `_p4StructuralScanCases` is renamed to a durable test-local name such as `_runnerStructuralScanCases`;
- `_p4StructuralGuardrailIds` is removed;
- the renamed structural scan case list maps its ids to `runnerStructuralProofGuardrailIds()`;
- hand-maintained expected id sets for `api`, `codec`, `core`, `diagnostics`, `store`, `projection`, `selection`, `edit`, `events`, and the blocking aggregate are removed.

Completion Check:

`dart test test/guardrails/blocking_suite_test.dart` passes; `rg "_expected(Api|Codec|Core|Diagnostics|Store|Projection|Selection|Edit|Event|BlockingHardBoundary)Ids|_p4StructuralGuardrailIds" test/guardrails/blocking_suite_test.dart` returns no matches; dry-run tests still prove that `dart run tool/guardrails/run.dart --dry-run`, `--suite=api`, `--suite=core`, `--suite=codec`, `--suite=diagnostics`, `--suite=store`, `--suite=projection`, `--suite=selection`, `--suite=edit`, and `--suite=events` route the same ids as the registry; `dart run tool/guardrails/run.dart --dry-run --suite=runner-structural` exits with code `64` and `Unknown or empty guardrail suite` because runner structural proof membership is not a CLI suite.

Depends On:

Unit 1.

### [x] Unit 3: Dead Negative Fixture Hook Removal

Owner:

`tool/guardrails/src/guardrail_executor.dart` owns guardrail execution flow; existing guardrail tests own the in-memory negative proof seams.

Boundary:

The private `_negativeFixtureViolationsFor()` hook and its call site in the executor, plus focused tests that prove existing negative fixture behavior still runs outside that hook.

Change:

Remove `_negativeFixtureViolationsFor()` and remove the spread call from the core-boundary execution branch. Keep `checkCoreBoundaries()` as the production scan for core-boundary ids. Do not add a replacement fixture runner or move fixture-only cases into production source.

Completion Check:

`dart test test/guardrails/import_boundaries_test.dart test/guardrails/core_boundary_negative_fixtures_test.dart` passes; `rg "_negativeFixtureViolationsFor" tool/guardrails/src/guardrail_executor.dart` returns no matches; `test/guardrails/import_boundaries_test.dart` still proves injected `violationChecks` can make `runGuardrailsWithProofRunner(['core.import_boundaries'])` fail without writing fixtures into `lib`.

Depends On:

Unit 2.

### [x] Unit 4: Handoff Closure And Final Verification

Owner:

`P6_HANDOFF_FINDINGS.md` owns the temporary handoff inventory; `PLAN.md` and this linked step document own roadmap completion state; the repository verification commands own final proof for Dart/tool changes.

Boundary:

Only the resolved sections for findings 1, 2, and 6 in `P6_HANDOFF_FINDINGS.md`, the Step 33 entry in `PLAN.md`, the execution-unit checkboxes in this step document, and the required verification commands for the changed Dart/tool/test surfaces.

Change:

After units 1 through 3 are complete and focused tests pass, remove or mark resolved only the handoff entries for findings 1, 2, and 6. Preserve the unresolved entries for findings 3, 4, 5, and 7. After final verification passes, mark Step 33 complete in `PLAN.md` and mark this step document's execution-unit checkboxes complete in the same implementation change.

Run the required Dart/tool verification for this code and test change:

- `dart analyze`
- `dcm analyze .`
- `dcm calculate-metrics .`
- `dart test test/guardrails/root_ci_target_test.dart test/guardrails/blocking_suite_test.dart test/guardrails/import_boundaries_test.dart test/guardrails/core_boundary_negative_fixtures_test.dart`

Completion Check:

`rg "Root CI guardrail proof|Blocking suite expected ids|Negative fixture hook" P6_HANDOFF_FINDINGS.md` returns no matches or only resolved-history text if the file uses an explicit resolved section; unresolved findings 3, 4, 5, and 7 remain present; `PLAN.md` marks Step 33 as `[x]`; this step document marks Units 1 through 4 as `[x]`; all commands listed in this unit pass in the repository root before the roadmap completion markers are applied.

Depends On:

Units 1, 2, and 3.
