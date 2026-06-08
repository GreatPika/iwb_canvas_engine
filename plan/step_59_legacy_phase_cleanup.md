# Change Contract

## Goal

Make the active repository read as a maintained `iwb_canvas_engine` package rather
than an architecture-rebuild workspace: current docs, registries, guardrails,
graph tooling, benchmark tooling, tests, CI, and repository instructions own the
remaining package invariants, while legacy package files, donor records, phase
documents, roadmap contracts, legacy-parity scaffolding, and rebuild navigation
are removed from the active tree after their current facts have replacement
owners and executable proof.

## Source Inputs

- Design: `.design/2026-06-08-legacy-phase-cleanup.md`
- Research: `.research/2026-06-08-legacy-phase-footprint.md`
- Phase: none
- PLAN: `PLAN.md`
- Other: `AGENTS.md`, `docs/README.md`, `docs/contracts/public_api_v1.md`,
  `docs/_registry/public_api_v1.yaml`, `docs/architecture/architecture_graph.yaml`,
  `docs/verification/guardrails.md`, `docs/verification/benchmarks.md`,
  `docs/verification/release_gates.md`, `tool/architecture_graph`,
  `tool/guardrails`, `tool/bench`, `.github/workflows`

## Classification

Profile: ANALYZER_RULE

Obligations: SEAM_MIGRATION

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| `D1` Full cleanup removes active legacy package, roadmap, donor, phase, and rebuild-mode navigation unless an artifact has a current mechanical consumer. | `Boundaries.In Scope`, `Boundaries.Out of Scope`, `Order Constraints` | Units 1, 4, 8; final no-residue scan and docs checker expectations. |
| `D2` Public API compatibility stays current-owned; retired symbols move from the legacy golden to `docs/_registry/public_api_v1.yaml`. | `Boundaries.Source of Truth`, `Boundaries.Compatibility` | Unit 2; `api.public_exports_complete`, `api.no_retired_public_exports`, public API compile/signature tests. |
| `D3` Phase closure is replaced by no-phase current architecture/release closure while preserving graph rule families. | `Boundaries.Source of Truth`, `Order Constraints` | Unit 3; graph checker tests and generated-view checks without `--phase`. |
| `D4` Donor and legacy inventory records are deleted only after still-current facts move to contracts, behavior tests, guardrails, benchmark policy, or release gates. | `Boundaries.Source of Truth`, `Order Constraints` | Unit 1 and Unit 8; invariant transfer checks and deletion gate. |
| `D5` Benchmark history/reference data remains current machine-consumed benchmark data, and legacy benchmark vocabulary is mechanically migrated to reference/baseline terms. | `Boundaries.Source of Truth`, `Boundaries.Compatibility` | Unit 6; benchmark manifest/report/diff/manual-history/reference tests over migrated committed data. |
| `D6` Guardrails and tests become positive current-architecture invariants, except explicit retired-export deny sets. | `Boundaries.Owner`, `Boundaries.Source of Truth` | Unit 5; guardrail registry, runner-backed tests, and negative fixtures. |
| `D7` Replacement owner and proof land before deletion, and residue proof runs after deletion. | `Order Constraints`, `All-Or-Nothing Failure Boundary` | Units 1 through 8 in order; final residue scan and full verification. |
| `D8` Cleanup does not rewrite or prune git history; deletion is active-tree cleanup through normal commits. | `Boundaries.Out of Scope`, `All-Or-Nothing Failure Boundary` | Unit 8; no history rewrite commands, old files recoverable from earlier commits. |
| `D9` Future Change Contracts do not get a new repository roadmap or archive after `PLAN.md` deletion. | `Boundaries.Source of Truth`, `Boundaries.Out of Scope` | Unit 7; `AGENTS.md`, `docs/README.md`, and docs checker route to per-task contracts without `PLAN.md`/`plan/`. |
| `D10` `docs/architecture/04_decisions_and_differences.md` is deleted only after current decisions move to named current owners. | `Boundaries.Source of Truth`, `Order Constraints` | Unit 1 and Unit 8; accepted-differences transfer proof and architecture README read-path update. |
| `D11` `.design/` and `.research/` remain active source-input/evidence layers, not active package behavior, release, guardrail, benchmark, roadmap, donor, or phase owners. | `Boundaries.Source of Truth`, `Boundaries.Out of Scope` | Unit 7 and Unit 8; residue-scan exception list and docs/AGENTS route. |

## Evidence

- `.design/2026-06-08-legacy-phase-cleanup.md:13` / disposition: design is `READY_FOR_CONTRACT` -> write a full step contract rather than a blocker.
- `.design/2026-06-08-legacy-phase-cleanup.md:17` / product outcome: repository should read as a normal maintained package and keep current enforcement in current owners -> contract must replace owners before deleting historical artifacts.
- `.design/2026-06-08-legacy-phase-cleanup.md:23` / exception policy: `.design/` and `.research/` remain source-input layers -> deletion and residue proof must exempt those paths only as evidence inputs.
- `.design/2026-06-08-legacy-phase-cleanup.md:29` / non-goals: preserving legacy package, plan, donor, phase, or prose archives is rejected -> no replacement archive or roadmap is in scope.
- `.design/2026-06-08-legacy-phase-cleanup.md:46` / classification: required profile is `ANALYZER_RULE` with `SEAM_MIGRATION` -> contract must sequence replacement checks before retirement.
- `.design/2026-06-08-legacy-phase-cleanup.md:63` / research evidence: legacy package is still present, and the direct executable dependency is the public API guardrail reading the legacy golden -> retired-export registry migration must precede legacy deletion.
- `.design/2026-06-08-legacy-phase-cleanup.md:64` / research evidence: `PLAN.md`, `plan/`, registries, generated indexes, graph, generated views, and docs tools still encode phases/donors -> cleanup must rewrite navigation/tooling, not only delete `legacy/`.
- `.design/2026-06-08-legacy-phase-cleanup.md:65` / enforcement inventory: existing legacy-related guardrails and tests preserve real invariants -> rewrite them into current-positive checks before deleting old artifacts.
- `.design/2026-06-08-legacy-phase-cleanup.md:73` / graph drift: P10/P13 are `future` while plan steps are complete -> graph current-state reconciliation must precede phase removal.
- `.design/2026-06-08-legacy-phase-cleanup.md:75` / benchmark vocabulary: benchmark tooling uses `equivalent_legacy`, `bootstrap_legacy_equivalence`, and `legacy_avg_us` -> benchmark schema migration needs code and data proof.
- `.design/2026-06-08-legacy-phase-cleanup.md:221` / registry ownership: current public API registry is machine-readable -> use it for retired public exports instead of a new historical file.
- `.design/2026-06-08-legacy-phase-cleanup.md:274` / selected scope: full cleanup is selected -> contract must preserve that target form.
- `.design/2026-06-08-legacy-phase-cleanup.md:278` / target owner map: current sources of truth are existing docs, registries, tools, tests, CI, and workflows -> execution units must be grouped by those owners.
- `.design/2026-06-08-legacy-phase-cleanup.md:292` / post-PLAN route: future contracts are per-task artifacts, not a repository roadmap or archive -> Unit 7 must update instructions and docs checker expectations before `PLAN.md` deletion.
- `.design/2026-06-08-legacy-phase-cleanup.md:295` / artifact disposition: legacy package, plan, donor, phase, legacy inventory, accepted differences, phase indexes, and generated phase views have explicit dispositions -> Unit 8 deletion scope is fixed.
- `.design/2026-06-08-legacy-phase-cleanup.md:343` / transfer map: historical source groups already map to current owners and deletion gates -> Unit 1 must implement that map rather than rediscover or archive it.
- `.design/2026-06-08-legacy-phase-cleanup.md:387` / retired public symbols: `retired_public_exports` belongs in `docs/_registry/public_api_v1.yaml` -> Unit 2 owns registry and guardrail migration.
- `.design/2026-06-08-legacy-phase-cleanup.md:402` / graph replacement: architecture graph checker runs without `--phase` and preserves closure rule families -> Unit 3 owns no-phase graph closure.
- `.design/2026-06-08-legacy-phase-cleanup.md:427` / benchmark replacement: benchmark case vocabulary changes to reference/baseline terms -> Unit 6 owns manifest schema migration.
- `.design/2026-06-08-legacy-phase-cleanup.md:434` / benchmark replacement: committed benchmark reference reports, run history, and reference decisions remain current benchmark data -> Unit 6 must preserve their machine readability.
- `.design/2026-06-08-legacy-phase-cleanup.md:437` / benchmark compatibility route: benchmark data must either be mechanically migrated or read through a same-contract compatibility reader, with mechanical migration preferred -> this contract intentionally chooses the preferred mechanical migration route and excludes an active old-vocabulary compatibility reader after completion.
- `.design/2026-06-08-legacy-phase-cleanup.md:443` / ordered slices: current-invariant capture precedes public API, graph, docs, guardrail, benchmark, CI, deletion, and residue work -> execution units must preserve this order.
- `.design/2026-06-08-legacy-phase-cleanup.md:481` / decision trace: D1-D11 are lock-required handoff rows -> every decision maps to a boundary, unit, or proof surface.
- `.design/2026-06-08-legacy-phase-cleanup.md:543` / all-or-nothing boundary: irreversible deletion follows all replacement owner creation and proof -> deletion must be blocked while replacement proof is red.
- `.design/2026-06-08-legacy-phase-cleanup.md:590` / source-of-truth impact: future contract must update AGENTS, docs entrypoints, registries, graph, tools, guardrails, benchmarks, workflows, and delete named artifacts -> execution units must cover each owner.
- `.design/2026-06-08-legacy-phase-cleanup.md:648` / verification impact: proof surfaces include public API registry tests, no-phase graph tests, docs tests, guardrail tests, benchmark tests, CI command checks, and residue scan -> completion checks must name these signals.
- `PLAN.md:5` / active roadmap: `PLAN.md` is currently the active plan index -> the new step must be registered here before implementation, and later deletion must update the planning route first.
- `docs/README.md:10` / docs navigation: current docs still route "Implement a phase" to `docs/indexes/by_phase.md` -> docs navigation rewrite is required before deleting phase indexes.
- `docs/README.md:15` / docs navigation: current docs still route donor decisions to `docs/indexes/donor_to_phase.md` -> donor navigation rewrite is required before deleting donor records.
- `docs/README.md:19` / docs navigation: current docs still route Change Contracts to `PLAN.md` and `plan/` -> post-PLAN route must be installed before deletion.
- `docs/contracts/public_api_v1.md:95` / public API source of truth: public barrel exports exactly registry names -> compatibility proof must keep `public_exports` stable.
- `docs/contracts/public_api_v1.md:110` / retired symbol source: current contract points to a legacy package golden -> registry migration is required before legacy deletion.
- `tool/architecture_graph/check.dart:7` / graph CLI: checker requires `--phase` -> no-phase CLI rewrite is a source-of-truth/tooling migration.
- `tool/architecture_graph/src/phase_closure.dart:116` / graph closure: selected-phase checker enforces required obligations, forbidden edges, placeholders, and unknown declarations -> no-phase closure must preserve these rule families.
- `tool/architecture_graph/src/architecture_graph.dart:473` / graph schema: validator expects P0-P14 phases -> schema migration and tests are required before phase inventory deletion.

## Boundaries

Owner:

Current root package owners own the cleanup: `docs/contracts/**`,
`docs/architecture/**`, `docs/verification/**`, `docs/_registry/**`,
`docs/tool/**`, `tool/architecture_graph/**`, `tool/guardrails/**`,
`tool/bench/**`, focused tests, `.github/workflows/**`, `AGENTS.md`, and
`docs/README.md`. The nested `legacy/iwb_canvas_engine` package, `PLAN.md`,
`plan/**`, donor docs/registries, phase implementation docs, legacy inventory,
and selected-phase generated views are retirement inputs, not target owners.

In Scope:

Transfer still-current invariants from checked plan steps, legacy inventory,
donor rows, accepted-difference docs, phase implementation docs, and P14 release
docs into current contracts, architecture docs, verification docs, registries,
tests, guardrails, benchmark policy, release gates, and CI. Move retired public
exports into the current public API registry. Replace selected-phase
architecture closure with current no-phase closure. Rewrite docs navigation,
generated indexes, docs checks, guardrail/test vocabulary, benchmark schema/data
vocabulary, release workflow commands, release gates, and repository
instructions. Delete only the named historical artifacts after replacement
owners and checks pass. Add final residue proof that active package navigation,
tooling, CI, guardrail policy, public API policy, benchmark policy, and release
gates no longer depend on retired artifacts.

Out of Scope:

Do not change the public API allowed export set except adding current
`retired_public_exports` metadata. Do not weaken public API compatibility,
guardrails, architecture closure, docs checks, benchmark checks, release gates,
or CI. Do not delete `.design/` or `.research/`. Do not create a replacement
repository roadmap, contract index, completed-contract archive, migration
archive, donor archive, phase archive, or prose-only proof table. Do not rewrite,
prune, filter, or otherwise remove historical commits or blobs from git. Do not
make runtime behavior changes except when focused tests need fixture updates for
renamed guardrails or current source-of-truth checks. Do not treat public
`CanvasPointerLifecyclePhase` or other current domain terms as residue merely
because their name contains `Phase`.

Source of Truth:

`docs/_registry/public_api_v1.yaml` owns both allowed public exports and retired
public export deny-list data. `docs/contracts/public_api_v1.md` owns public API
semantics. Current behavior invariants live in `docs/contracts/**`,
`docs/architecture/**`, and focused tests. Current verification policy lives in
`docs/verification/**`, `tool/guardrails/**`, `tool/architecture_graph/**`,
`tool/bench/**`, `.github/workflows/**`, and docs/graph/benchmark generated
outputs that are mechanically regenerated. Benchmark history/reference data is
mechanically migrated to the current reference/baseline schema; this contract
chooses the design's preferred mechanical migration route, so no active
compatibility reader preserves old benchmark vocabulary after this step. Future
Change Contracts are
per-task execution artifacts in the work item, Codex thread, or PR context; the
durable repository inputs for those contracts are `.design/`, `.research/`, and
current docs/registries, not `PLAN.md` or `plan/**`.

Compatibility:

Public barrel exports listed in `public_exports` must remain unchanged unless a
separate explicit breaking-change contract is approved. Existing behavior tests,
guardrails, docs checks, graph checks, mechanically migrated benchmark
history/reference data, release workflow gating, and CI expectations must
continue to enforce current package behavior after vocabulary and source-owner
migration. Committed benchmark history/reference reports remain usable after the
mechanical schema migration and must not require an old-vocabulary compatibility
reader after this step. This is an intentional narrowing to the design's
preferred route, not a replacement of the benchmark owner model. Git history
remains untouched; deleted active-tree artifacts remain recoverable from earlier
commits.

Order Constraints:

First transfer still-current historical facts into current owners and prove them.
Then migrate public API retired-export ownership. Then migrate architecture graph
closure to no-phase current closure after reconciling current statuses. Then
rewrite docs navigation/generated tooling/checks. Then rewrite guardrails/tests
into current-positive vocabulary. Then mechanically migrate benchmark
schema/readers/history/reference data to current reference/baseline vocabulary,
with no old-vocabulary compatibility reader left active. Then update AGENTS,
docs entrypoints, release gates, workflows, and post-PLAN planning route. Only
after those replacement owners and checks pass, delete the legacy package,
roadmap, donor, phase, legacy inventory, accepted-difference, phase-index, and
selected-phase generated artifacts. Run final residue and full verification
after deletion.

Temporal Surface Closure:

Not applicable. This cleanup changes repository source-of-truth, tooling,
guardrail, docs, benchmark, CI, and artifact ownership. It does not change
runtime callback, listener, observer, delivery, public-state publication,
transaction, rollback, no-op, or mutation guard semantics.

All-Or-Nothing Failure Boundary:

The irreversible point is deleting historical active-tree artifacts. Fallible
work before that point includes invariant transfer, public API registry
migration, no-phase graph migration, docs tooling rewrite, guardrail/test
rewrite, mechanical benchmark schema/history/reference-data migration,
CI/release/instruction rewrite, and focused proof. Later work is residue
scanning and full verification over the accepted deletion result. Failure before
the irreversible point projects as a blocked cleanup slice with old artifacts
still present. Failure after deletion must be contained by restoring from the
same working-tree/commit operation, not by rewriting git history.

## Execution Units

### [ ] Unit 1: Current invariant transfer

Owner:

Current contracts, architecture docs, verification docs, focused behavior tests,
and current source-of-truth registries.

Boundary:

Move only still-current facts out of checked plan steps, legacy inventory, donor
records, accepted-difference docs, and phase implementation docs before any
historical artifact is deleted.

Change:

Implement the design transfer maps for checked plan step groups, legacy
inventory facts, donor registry rows, accepted-difference decisions, and P14
release-readiness facts. Move retained facts to named current owners:
`docs/contracts/**`, `docs/architecture/**`, `docs/verification/**`,
`docs/_registry/**`, focused tests, guardrails, benchmark policy, release gates,
and CI surfaces. Prove redundant historical facts by existing current tests or
guardrails instead of copying them into a new archive. Remove active docs/checks
that cite plan, donor, legacy inventory, or phase documents as current owners
only after the replacement owner and proof exists.

Completion Check:

For every row in the design's checked-plan, legacy-inventory, donor-registry,
and accepted-differences transfer maps, the changed current owners and tests show
either a current owner plus executable proof or an existing current proof that
makes the historical fact redundant; no new mapping table, archive, or checklist
file is created as the proof. The current docs/contracts/verification surfaces own
the listed public API, schema, validation, codec, edit/load/runtime,
interaction/surface, frame/cache/resource/geometry/spatial/diagnostics,
guardrail, docs, graph, release, benchmark, and example invariants without
requiring active `PLAN.md`, `plan/**`, `docs/donors/**`,
`docs/implementation/**`, or `docs/verification/legacy_capability_inventory.md`
as sources of truth. Focused behavior tests for touched owners pass. Docs checks
pass for any changed docs: `dart run docs/tool/sync_generated_docs.dart --check`
and `dart run docs/tool/check_docs.dart`. For Dart code or test changes, run
`dart analyze`, `dcm analyze .`, scoped `dcm calculate-metrics` for changed
production/test/tool owners, and the focused tests that prove the transferred
facts.

Depends On:

None.

### [ ] Unit 2: Public API retired-export registry migration

Owner:

`docs/_registry/public_api_v1.yaml`, `docs/contracts/public_api_v1.md`, public
API guardrails/tests, and public API source resolver tooling.

Boundary:

Preserve current public API compatibility while removing the only direct
executable dependency on the legacy package golden.

Change:

Add current `retired_public_exports` deny-list data to
`docs/_registry/public_api_v1.yaml`, sourced from the retired legacy public
symbols that current compatibility still denies. Rewrite
`docs/contracts/public_api_v1.md` so it explains retired-export compatibility
through the current registry instead of
`legacy/iwb_canvas_engine/tool/goldens/public_api_symbols.txt`. Rename or
rewrite `api.no_legacy_public_types` and related tests/fixtures to the current
`api.no_retired_public_exports` rule. Keep `public_exports` unchanged unless a
separate explicit breaking-change contract exists.

Completion Check:

Public API registry tests fail if `retired_public_exports` is missing, malformed,
duplicates `public_exports`, or omits denied symbols that the current guardrail
previously enforced. Public barrel/export tests prove
`package:iwb_canvas_engine/iwb_canvas_engine.dart` exports exactly
`public_exports` and none of `retired_public_exports`. Guardrail runner tests
prove `api.no_retired_public_exports` reads the current registry and fails on a
fixture exporting a denied retired symbol without reading any file under
`legacy/`. Public API compile/signature tests pass. `dart analyze`,
`dcm analyze .`, scoped `dcm calculate-metrics docs/tool tool/guardrails
test/api_contract`, focused public API and guardrail tests, and docs checks pass.

Depends On:

Unit 1.

### [ ] Unit 3: No-phase architecture closure migration

Owner:

`docs/architecture/architecture_graph.yaml`, `tool/architecture_graph/**`,
generated architecture views, graph tests, release graph command surfaces, and
architecture documentation.

Boundary:

Replace selected-phase closure with current architecture/release closure without
dropping required-node, required-edge, forbidden-edge, placeholder, sensitive
throw, or unknown-seam enforcement.

Change:

Reconcile current graph status drift for P10, P13, P14, and actual current
owners before deleting phase semantics. Remove `phases`, `phaseIntroduced`,
`phaseRequiredBy`, selected phase status, and P0-P14 inventory semantics from
the graph schema. Rewrite or rename `phase_closure.dart` into a current closure
checker that runs without `--phase`, preserving existing closure rule families.
Rewrite graph view generation so generated current/release/actual-vs-expected
views have no selected-phase metadata. Delete or replace `current_phase.mmd` and
`future_target.mmd` only through generated-output tooling.

Completion Check:

Graph schema tests fail if `architecture_graph.yaml` still requires P0-P14
phase inventory or phase-required fields. Current graph checker tests fail for
missing required owners/edges, forbidden dependencies, placeholders, sensitive
throw mismatches, and unknown architecture declarations without a `--phase`
argument. CLI tests prove `dart run tool/architecture_graph/check.dart` and
`dart run tool/architecture_graph/generate_views.dart --check` are the accepted
commands and that `--phase P14` is no longer required. Generated-view checks
prove no generated architecture view contains selected-phase or future-target
metadata unless a current non-phase view explicitly owns that term. `dart
analyze`, `dcm analyze .`, scoped `dcm calculate-metrics
tool/architecture_graph test/architecture_graph docs/tool`, focused graph tests,
docs checks, and no-phase generated-view checks pass.

Depends On:

Unit 1.

### [ ] Unit 4: Current docs navigation and generated tooling

Owner:

`docs/README.md`, `docs/architecture/README.md`, `docs/_registry/sections.yaml`,
`docs/_registry/diagrams.yaml`, `docs/indexes/**`, `docs/diagrams/catalog.md`,
`docs/tool/sync_generated_docs.dart`, and `docs/tool/check_docs.dart`.

Boundary:

Remove phase, donor, and plan navigation from the docs portal only after current
owners and generated current lookup routes exist.

Change:

Rewrite docs entrypoints to route readers to current architecture, contracts,
verification, guardrails, benchmarks, release gates, diagrams, generated current
indexes, and per-task Change Contract workflow. Remove generated phase and donor
indexes, donor registry validation, phase implementation document checks, and
README expectations for `PLAN.md`/`plan/**`. Rewrite section/diagram registry
schema or metadata so it records current owner/subsystem/test/guardrail/benchmark
relationships consumed by docs tools, not phase/donor relationships. Update docs
checker expectations so phase/donor/plan routes are rejected after cleanup and no
replacement roadmap/archive route is accepted.

Completion Check:

`dart run docs/tool/sync_generated_docs.dart --check` fails if generated docs are
stale or still generate `docs/indexes/by_phase.md`,
`docs/indexes/donor_to_phase.md`, selected-phase graph navigation, donor routes,
or `PLAN.md`/`plan/**` Change Contract discovery. `dart run docs/tool/check_docs.dart`
fails if docs roots include deleted `docs/implementation/**` or `docs/donors/**`,
if `docs/README.md` or `docs/architecture/README.md` links to phase/donor/plan
routes, or if a replacement roadmap/contract archive is introduced. Generated
current indexes still cover subsystem, guardrail, test, benchmark, diagram, and
release lookup needed by current docs. For docs tool code changes, run
`dart analyze`, `dcm analyze .`, scoped `dcm calculate-metrics docs/tool
test/docs`, and focused docs-tool tests.

Depends On:

Unit 1 and Unit 3.

### [ ] Unit 5: Current-positive guardrail and test vocabulary

Owner:

`docs/verification/guardrails.md`, `docs/verification/tests.md`,
`tool/guardrails/**`, guardrail registry/tests, API/example/geometry/frame
boundary tests, and negative fixtures.

Boundary:

Keep enforcement strength while replacing legacy-negative and donor/parity names
with current architecture-positive invariants.

Change:

Rename or rewrite guardrails/tests such as legacy import rejection, geometry
scene-order rejection, frame cache legacy-snapshot shape checks, example retired
symbol scans, donor mapping tests, and release legacy-path rejection into current
package-boundary, retired-export, committed-order, current cache key, public
consumer, and release command invariants. Keep explicit retired-export deny-list
checks where that is the current policy. Quarantine negative fixtures under test
or guardrail fixture owners; do not store fixture-only names in public API
registries except real retired-export deny-list data.

Completion Check:

Guardrail registry and runner tests prove every renamed guardrail is registered,
runs from `dart run tool/guardrails/run.dart`, passes on the current repository,
and fails on representative negative fixtures for retired public exports,
forbidden package/import boundaries, committed handle order, cache key
ownership, public example boundary, and release workflow command residue.
Focused tests prove donor mapping tests are deleted or rewritten only after
current behavior/contract tests own the copied or adapted behavior. Docs
verification pages list current guardrail/test ids without legacy/donor/parity
vocabulary except explicit retired-export policy or historical evidence
exceptions. `dart analyze`, `dcm analyze .`, scoped `dcm calculate-metrics
tool/guardrails test/guardrails test/api_contract test/geometry test/frame
example/test`, focused guardrail/API/example/geometry/frame tests, and docs
checks pass.

Depends On:

Unit 2 and Unit 4.

### [ ] Unit 6: Benchmark schema and history migration

Owner:

`docs/_registry/benchmarks.yaml`, `docs/verification/benchmarks.md`,
`tool/bench/**`, benchmark tests, committed manual benchmark reference reports,
manual run history, and reference decision data.

Boundary:

Keep benchmark manifest, reports, diff policy, manual references, and committed
history machine-consumed while removing legacy-equivalence vocabulary.

Change:

Mechanically migrate benchmark manifest/report/diff/manual-history/reference
data vocabulary away from `p14_benchmark_measurement_boundary_v2`,
`classification: equivalent_legacy`, `classification: new_only`,
`legacy_avg_us`, and `bootstrap_legacy_equivalence`. Use current
reference/baseline vocabulary: `baseline_policy: reference_comparison`,
`baseline_policy: absolute_budget`, `reference_avg_us`, and
`first_baseline_reference_limits`. Preserve committed benchmark reference
reports, run history, and reference decisions as current benchmark data by
rewriting the committed data and readers together. Do not add or retain an
old-vocabulary compatibility reader for current active-tree benchmark data in
this step.

Completion Check:

Benchmark manifest tests fail on old legacy-equivalence vocabulary in current
manifest data and pass on the new reference/baseline schema. Benchmark report,
diff, runner, manual-history, and reference-decision tests prove committed
benchmark manifest data, reference reports, run history, and reference decisions
are mechanically migrated and remain readable under the new schema. Tests fail
if any current benchmark reader accepts or emits old-vocabulary fields for
active-tree benchmark data after this step. Release benchmark docs and release
gate docs describe current reference/baseline policy without P14 or
legacy-equivalent terminology. Benchmark-specific residue tests fail if current
benchmark manifest, reports, diff policy, workflows, or docs use
`equivalent_legacy`, `legacy_avg_us`, or `bootstrap_legacy_equivalence`.
`dart analyze`,
`dcm analyze .`, scoped `dcm calculate-metrics tool/bench test/benchmarks
docs/tool`, focused benchmark tests, `dart run tool/bench/run.dart
--profile=dry_run`, and docs checks pass.

Depends On:

Unit 4 and Unit 5.

### [ ] Unit 7: Repository instructions, release gates, CI, and post-PLAN route

Owner:

`AGENTS.md`, `docs/README.md`, `docs/tool/check_docs.dart`,
`docs/verification/release_gates.md`, `.github/workflows/**`, release readiness
guardrails/tests, and docs checker expectations. The repository-local
`.agents/skills/change-contract/**` and `.agents/skills/change-contract-check/**`
files are source inputs for the route and are edited only if their current text
still requires `PLAN.md`/`plan/**` after the new route is installed.

Boundary:

Install the future planning and verification route before deleting `PLAN.md` and
phase-specific commands.

Change:

Rewrite repository instructions from architecture rebuild mode to maintained
package mode. Remove active `PLAN.md` workflow instructions and phase-specific
architecture check commands. Route future implementation planning to per-task
Change Contracts in the work item, Codex thread, or PR context, using `.design/`,
`.research/`, and current docs/registries as durable source inputs when needed.
Do not create a replacement in-repo roadmap, contract index, or completed
contract archive. Update release gates and workflows to use no-phase graph
commands, current guardrails, docs checks, benchmark checks, and release
readiness checks.

Completion Check:

Docs checker expectations fail if `AGENTS.md`, `docs/README.md`, or release
docs still route users to `PLAN.md`, `plan/**`, phase indexes, donor indexes,
or `--phase P14` release commands after the replacement route is installed.
Release readiness guardrail tests fail if `.github/workflows/release_benchmarks.yml`
or related release workflow commands still require P14 graph checks, selected
phase generated-view checks, legacy paths, donor routes, or plan routes. The
repository instructions explicitly preserve `.design/` and `.research/` as
source-input/evidence layers and reject them as active package behavior,
release, guardrail, benchmark, roadmap, donor, or phase owners. `dart analyze`,
`dcm analyze .`, scoped `dcm calculate-metrics tool/guardrails test/guardrails
docs/tool`, focused release-readiness/workflow tests, docs checks, no-phase graph
checks, and guardrail runner pass.

Depends On:

Unit 3, Unit 4, Unit 5, and Unit 6.

### [ ] Unit 8: Historical artifact deletion and final residue gate

Owner:

Repository active tree, docs/tool residue checks, guardrail/release readiness
checks, generated docs/diagrams, and final verification commands.

Boundary:

Delete only after Units 1 through 7 have replacement owners and green focused
proof. Do not rewrite git history.

Change:

Remove `legacy/iwb_canvas_engine/`, `PLAN.md`, `plan/`, `docs/donors/`,
`docs/implementation/`, `docs/verification/legacy_capability_inventory.md`,
`docs/_registry/donors.yaml`, `docs/indexes/by_phase.md`,
`docs/indexes/donor_to_phase.md`,
`docs/architecture/04_decisions_and_differences.md`, generated selected-phase
graph views with no current replacement, and `analysis_options.yaml` legacy
exclusion/residue only after no active check reads those paths. Remove remaining
active references to retired paths and vocabulary in docs, tooling, workflows,
guardrails, tests, generated outputs, and examples. Preserve `.design/` and
`.research/` as documented residue-scan exceptions for evidence/source-input
text only. Preserve current domain terms such as `CanvasPointerLifecyclePhase`
when they are public API or current behavior vocabulary.

Completion Check:

A final residue scan fails on active-tree references to
`legacy/iwb_canvas_engine`, `docs/donors`, `docs/implementation`, `PLAN.md`,
`plan/`, `by_phase`, `donor_to_phase`, selected-phase graph views, `--phase P`,
`P14` release commands, `equivalent_legacy`, `legacy_avg_us`, and
`bootstrap_legacy_equivalence`, except documented current-domain terms and
`.design/`/`.research/` evidence-source text. Docs checks pass:
`dart run docs/tool/sync_generated_docs.dart --check` and
`dart run docs/tool/check_docs.dart`. No-phase graph checks pass:
`dart run tool/architecture_graph/check.dart` and
`dart run tool/architecture_graph/generate_views.dart --check`. Guardrails pass:
`dart run tool/guardrails/run.dart`. Code checks pass: `dart analyze`,
`dcm analyze .`, scoped `dcm calculate-metrics` for every changed production,
test, docs-tool, architecture-graph, guardrail, and benchmark owner. Focused
tests from Units 1 through 7 and broad root CI-equivalent non-benchmark tests
pass. Benchmark dry-run and focused benchmark tests pass. Git history is not
rewritten or pruned; deletion is visible only as normal active-tree file removal.

Depends On:

Unit 1, Unit 2, Unit 3, Unit 4, Unit 5, Unit 6, and Unit 7.
