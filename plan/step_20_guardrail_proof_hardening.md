# Change Contract

Contract Mode: FULL
Contract Profile: ANALYZER_RULE
Contract Obligations: BUG_FIX, PUBLIC_API_CHANGE

## 1. Mandate and Boundary

### Mandate

Repair the guardrail proof gaps found after Step 1 so the root package
hard-boundary runner catches the bad states that its P0 guardrail names and
documentation already claim to prevent.

### In Scope

- Make `api.no_legacy_public_types` reject every legacy public symbol listed by
  the legacy package golden file, not a manually curated subset.
- Make `api.public_types_complete` traverse exported typedef type parameter
  bounds and reject exported named extensions during P0.
- Make the interaction import rules that are part of the P0 forbidden import
  matrix fail under `core.import_boundaries` until their dedicated interaction
  guardrails are implemented as blocking runner entries.
- Add executable proof for the runner's `--suite=api` and `--suite=core`
  selection modes.
- Correct active proof-map documentation for the P0 guardrails that this step
  touches.

### Out of Scope

- Adding DCM commands to the GitHub workflow. The available analyzer license is
  not a reliable CI dependency for this repository, so DCM remains a local
  verification command and is not part of the CI gate in this step.
- Implementing future non-P0 guardrails beyond the P0 hard-boundary inventory.
- Exporting or supporting public named extension APIs.
- Changing the public exported-name registry except where a test fixture needs
  local test-only public declarations.
- Runtime, rendering, codec, edit, interaction behavior, or Flutter surface
  implementation.

## 2. Evidence Map

### Baseline Evidence

These facts describe repository state before execution. They are evidence for
the change, not target-state requirements.

### Entry Paths

- `PLAN.md` is the active roadmap index and currently lists completed Steps 1
  through 19.
- `plan/step_1_package_skeleton_and_hard_boundaries.md` closed the P0 package
  skeleton and hard-boundary runner surface.
- `PLAN.md` and this linked step contract must both be updated when Step 20 is
  completed.
- The anti-slop review of Step 1 identified false-negative guardrail and proof
  map gaps in `tool/guardrails/**`, `test/**`, and `docs/**`.

### Current Owners

- `docs/verification/guardrails.md` owns mandatory guardrail ids and states that
  the runner supports full, `--suite=<name>`, and `--guardrail=<id>` execution.
- `docs/architecture/02_package_boundaries.md` owns package layout, public
  barrel policy, production import boundaries, and the split between
  `test/guardrails/**` and `tool/guardrails/**`.
- `docs/contracts/public_api_v1.md` owns public API semantics and states that
  legacy public symbols listed by the legacy golden are not exported by the root
  package.
- `docs/_registry/public_api_v1.yaml` owns the machine-readable exported-name
  inventory for `api.public_exports_complete`.
- `tool/guardrails/src/public_api_checks.dart` owns public API guardrail result
  construction for `api.no_legacy_public_types`,
  `api.public_exports_complete`, and `api.public_types_complete`.
- `tool/guardrails/src/public_api_surface.dart` owns resolved public namespace
  collection for the root barrel or test fixture libraries.
- `tool/guardrails/src/public_api_type_references.dart` owns resolved public
  signature traversal.
- `tool/guardrails/src/core_boundary_checks.dart` owns production import,
  `part`, legacy import, retired-shape, and runtime-root structural checks.
- `tool/guardrails/src/guardrail_registry.dart` owns executable guardrail ids
  and suite membership for checks that run through the project runner.
- `test/guardrails/blocking_suite_test.dart` owns runner inventory and
  selection-mode proof.

### Existing Checks

- `test/api_contract/no_legacy_public_symbols_test.dart` checks the current root
  public surface but has no fixture that proves a legacy-golden symbol outside
  the hand-written subset is rejected.
- `test/api_contract/public_types_complete_test.dart` checks the current root
  public surface and private interface supertypes, but does not cover typedef
  bounds or exported named extension members.
- `test/guardrails/core_boundary_negative_fixtures_test.dart` covers many
  forbidden imports, but does not prove interaction-to-store and
  interaction-to-selection violations are reported under a blocking P0 id.
- `test/guardrails/blocking_suite_test.dart` proves inventory equality and one
  explicit `--guardrail=<id>` path, but does not execute `--suite=api` or
  `--suite=core`.
- `.github/workflows/root_package.yml` runs `flutter pub get`, `dart analyze`,
  and `dart run tool/guardrails/run.dart`; DCM is intentionally not treated as
  a CI proof source for this step.

### Valid Precedents

- `docs/verification/guardrail_design_patterns.md` selects
  `resolved_public_surface` for public API shape and type-leak guardrails.
- `docs/verification/guardrail_design_patterns.md` selects
  `negative_legacy_shape` plus `resolved_public_surface` for
  `api.no_legacy_public_types`.
- `docs/verification/guardrail_design_patterns.md` selects
  `parsed_ast_directive` for import-boundary guardrails and `runner_inventory`
  for runner selection proof.
- `legacy/iwb_canvas_engine/tool/goldens/public_api_symbols.txt` is the legacy
  public symbol golden referenced by the public API contract.
- Existing guardrail tests import reusable logic from `tool/guardrails/**` or
  execute `dart run tool/guardrails/run.dart`, matching the package-boundary
  split.

### Repository Rules

- Completed plan steps update both the `PLAN.md` index and the linked step
  document in the same change.
- Code changes must be verified with `dart analyze`, `dcm analyze .`,
  `dcm calculate-metrics .`, and relevant behavior or guardrail checks when
  those commands work locally.
- Guardrails should be mechanically enforced through repository-owned checks,
  not prose-only reminders.
- Production `lib/**` must not import `tool/**`; tests may import reusable
  guardrail check logic from `tool/guardrails/**`.
- Documentation is written in English.

### Misleading Patterns

- The hand-written `_legacySymbols` set in `public_api_checks.dart` looks like
  the legacy public-symbol source, but it omits most names from the legacy
  golden file.
- `interaction.no_concrete_store_imports` and
  `interaction.no_concrete_selection_imports` are mandatory future guardrail ids,
  but they are not executable P0 runner entries.
- A green `dart run tool/guardrails/run.dart` only proves violations whose ids
  match executable runner inventory entries.
- `docs/verification/tests.md` currently describes
  `test/guardrails/blocking_suite_test.dart` as proving every mandatory
  blocking guardrail, which is broader than the executable P0 inventory.
- `docs/indexes/by_guardrail.md` currently maps
  `api.public_exports_complete` and `api.public_types_complete` to later-phase
  API tests instead of their P0 proof files.
- `docs/indexes/by_test_area.md` currently carries the same stale proof map in
  the reverse direction: later-phase API tests point at the P0 completeness
  guardrails, and `test.guardrails.blocking_suite` appears to cover future
  mandatory guardrails without distinguishing P0 executable coverage from P14
  release-readiness coverage.
- `docs/implementation/p0_package_skeleton_and_hard_boundaries.md` is the P0
  phase brief for the same hard-boundary surface and must stay aligned with the
  runner suite and proof-map wording introduced by this hardening step.

## 3. Architecture Decision

### Selected Form

Harden the existing guardrail owners instead of creating new wrapper checks.
This contract uses the following accepted implementation plan as the baseline
for review and execution:

1. `api.no_legacy_public_types` reads the legacy public symbol golden at
   execution time and compares it with the resolved root public surface.
2. P0 interaction-to-store and interaction-to-selection import violations are
   emitted as `core.import_boundaries` until the dedicated interaction guardrail
   ids become blocking executable entries in a later implementation step.
3. `api.public_types_complete` keeps one resolved public-surface traversal and
   expands it to cover typedef type parameter bounds.
4. P0 rejects exported named extensions outright through the public API
   guardrail path. Named extension support requires a later explicit public API
   decision and traversal contract.
5. Runner suite membership is proven by executing `--suite=api` and
   `--suite=core`, not by inspecting metadata alone.
6. Proof-map documentation is corrected to describe the executable P0 scope and
   point reviewers at the actual P0 test files.

### Ownership

- Legacy public-symbol loading and public API violation construction remain
  owned by `tool/guardrails/src/public_api_checks.dart`.
- Resolved namespace collection remains owned by
  `tool/guardrails/src/public_api_surface.dart`.
- Public signature traversal remains owned by
  `tool/guardrails/src/public_api_type_references.dart`.
- Import boundary id selection remains owned by
  `tool/guardrails/src/core_boundary_checks.dart`.
- Runner selection proof remains owned by `test/guardrails/blocking_suite_test.dart`.
- Public API extension policy is owned by `docs/contracts/public_api_v1.md` and
  enforced by the public API guardrail path.
- Guardrail proof-map wording is owned by `docs/verification/tests.md`,
  `docs/indexes/by_guardrail.md`, `docs/indexes/by_test_area.md`, and the P0
  implementation phase brief.
- Roadmap completion state is owned by `PLAN.md` and this linked step contract.

### Seam

The shared seams remain:

- `package:iwb_canvas_engine/iwb_canvas_engine.dart` as the only public import
  seam used by package consumers and public API guardrails.
- `dart run tool/guardrails/run.dart` as the project-owned guardrail execution
  seam used by developers and CI.

This step strengthens those seams without introducing a second runner, a second
public API inventory, or a second legacy-symbol source of truth.

### Dependency Direction

- `tool/guardrails/src/public_api_checks.dart` may read
  `legacy/iwb_canvas_engine/tool/goldens/public_api_symbols.txt` as verify-only
  input; production `lib/**` must not depend on legacy paths.
- Public API guardrail logic may use analyzer elements from
  `tool/guardrails/src/public_api_surface.dart` and type traversal from
  `tool/guardrails/src/public_api_type_references.dart`.
- Core boundary checks may keep all structural import policy in
  `tool/guardrails/src/core_boundary_checks.dart`; callers must not remap
  violation ids.
- Tests may import `tool/guardrails/**` helpers or execute the runner command.
- Documentation updates must align with guardrail owners and must not create a
  new executable inventory outside `tool/guardrails/src/guardrail_registry.dart`.

### State and Data Ownership

No runtime state is introduced. The legacy public symbol golden remains the
source of truth for legacy public names. `docs/_registry/public_api_v1.yaml`
remains the source of truth for root public exported names. Runner metadata
continues to own only executable guardrail ids and suite membership.

### Public API Compatibility

The named-extension rule is a non-breaking P0/v1 clarification. The public API
contract and `docs/_registry/public_api_v1.yaml` already describe exported
public names as declarations from the root public barrel, and no approved public
named extension exists in the current registry or public contract. This step
does not remove an approved API, does not require a migration path, and does not
change the package version. The exported-name registry stays unchanged because
named extensions are rejected rather than added to the public surface. Active
proof indexes are updated only to point to the correct P0 guardrail proof files.

### Entry and Exit Boundaries

- Public API checks enter through the resolved public barrel or a targeted test
  fixture library path and exit as `GuardrailViolation` values with the
  owning guardrail id.
- Core boundary checks enter through production `lib/**` files or negative
  fixture content and exit as `GuardrailViolation` values.
- Runner checks enter through `dart run tool/guardrails/run.dart`,
  `--suite=<name>`, or `--guardrail=<id>` and exit with non-zero status when
  the selected executable guardrails report matching violations.

### Verification Strategy

Use failing structural fixtures before each owner-side fix, then prove the
runner path that would have missed the bad state. Keep DCM as local final
verification only; do not add DCM to GitHub Actions in this step.

### Decision Ledger

| ID | Decision | Owner | Proof |
|---|---|---|---|
| D1 | Legacy public-symbol rejection is golden-driven, not hand-list driven. | `tool/guardrails/src/public_api_checks.dart` | P1, P8 |
| D2 | P0 exported named extensions are rejected instead of partially traversed. | `docs/contracts/public_api_v1.md`, `tool/guardrails/src/public_api_type_references.dart` | P2, P7, P8 |
| D3 | P0 interaction import matrix violations report `core.import_boundaries` until dedicated interaction guardrails become executable. | `tool/guardrails/src/core_boundary_checks.dart` | P3, P8 |
| D4 | Runner suite support is proven by subprocess execution for `api` and `core` suites. | `test/guardrails/blocking_suite_test.dart` | P4, P8 |
| D5 | Active proof maps describe executable P0 scope and point to the actual P0 proof files. | `docs/verification/tests.md`, `docs/indexes/by_guardrail.md`, `docs/indexes/by_test_area.md`, `docs/implementation/p0_package_skeleton_and_hard_boundaries.md` | P5, P6 |
| D6 | Roadmap completion is a finalization step after all guardrail and documentation proof passes. | `PLAN.md`, `plan/step_20_guardrail_proof_hardening.md` | P10 |

### Rejected Alternatives

- Do not keep or rename the hand-written legacy symbol subset. The public API
  contract names the legacy golden as the legacy public-symbol source.
- Do not add DCM to GitHub Actions in this step. CI cannot rely on the required
  paid analyzer features, while local verification still runs the DCM commands.
- Do not add `interaction.no_concrete_store_imports` or
  `interaction.no_concrete_selection_imports` to the P0 blocking runner now.
  Their full interaction semantics are later-phase work; the P0 import-matrix
  failure must be represented by `core.import_boundaries`.
- Do not implement partial named extension traversal. P0 has no approved public
  named extension surface, and partial traversal would create false confidence.
- Do not create a second proof-map registry. Correct the active documents that
  already own test and guardrail navigation.

## 4. Execution Guardrails

### Required Order

1. For each BUG_FIX slice, add or adjust the false-negative reproducer before
   the owner-side fix, and include 1 to 3 neighboring guard tests or allowed
   non-violations in the same slice proof.
2. Fix the two false-green runner risks first: legacy public-symbol rejection,
   then interaction import matrix id coverage.
3. Fix public type traversal and named-extension rejection after the runner
   false-green risks are covered.
4. Add runner suite proof after the executable guardrail ids are stable.
5. Update proof-map documentation after executable proof points at the intended
   files and commands.
6. Mark `PLAN.md` and this step contract complete only after all executable and
   documentation proof is green.
7. Run the final proof set only after all slice-local proof is green.

### Cross-Slice Constraints

- Keep each false-negative fix in its owner; do not patch tests to expect the
  current weak behavior.
- Do not add public named extension support while closing this step.
- Do not change `docs/_registry/public_api_v1.yaml` to make a fixture pass.
- Do not broaden CI with DCM commands.
- Preserve the runner's single project-owned entrypoint.

### Seam Migration

No shared seam is retired or replaced. The runner and public barrel seams are
kept and strengthened.

### Forbidden Moves

- Do not duplicate the legacy public symbol list in a new Dart constant,
  generated file, or documentation table.
- Do not whitelist only `Transform2D`, `SceneView`, or another one-off legacy
  symbol; the fix must cover the whole golden file.
- Do not move import-boundary id translation into
  `tool/guardrails/src/guardrail_executor.dart`.
- Do not describe `test/guardrails/blocking_suite_test.dart` as proving every
  future mandatory guardrail.
- Do not mark Step 20 or any Step 20 slice complete before the final roadmap
  closure slice.

### Deferred Broad Verification

The local final gate includes DCM commands because repository rules require
them after code changes. CI remains unchanged with respect to DCM.

## 5. Proof Plan

### P1. Legacy Public Golden Rejection

This proves `api.no_legacy_public_types` rejects a legacy public symbol that was
not present in the old hand-written subset.

```sh
dart test test/api_contract/no_legacy_public_symbols_test.dart
```

Expected signal: the test fails before the golden-driven fix and passes after a
fixture exporting a non-subset legacy golden symbol is rejected. The same test
keeps neighboring guard coverage for the clean root public surface and at least
one next-owned public symbol that must not be rejected as legacy.

### P2. Public Type Reference Coverage

This proves `api.public_types_complete` rejects typedef bounds with hidden types
and rejects exported named extensions during P0.

```sh
dart test test/api_contract/public_types_complete_test.dart
```

Expected signal: the test fails before traversal and extension-policy fixes and
passes after both bad fixture shapes produce `api.public_types_complete`
violations. The same test keeps neighboring guard coverage for approved
Dart/Flutter SDK types, exported public types, and the existing private
supertype negative fixture.

### P3. Core Import Boundary Id Coverage

This proves interaction-to-store and interaction-to-selection import matrix
violations report the executable P0 id.

```sh
dart test test/guardrails/core_boundary_negative_fixtures_test.dart
dart test test/guardrails/import_boundaries_test.dart
dart run tool/guardrails/run.dart --guardrail=core.import_boundaries
```

Expected signal: fixtures for interaction imports expect
`core.import_boundaries` and fail before the id fix; the import-boundaries test
creates a temporary production-shaped interaction file that imports concrete
store or selection internals, runs
`dart run tool/guardrails/run.dart --guardrail=core.import_boundaries`, and
asserts a non-zero exit; the test removes the temporary file through
`try`/`finally`; the final selected runner command exits zero after the
temporary bad file is removed and the clean production tree has no matching
violations. The same fixture test keeps neighboring guard coverage for
unrelated import boundary violations, legacy imports, and unapproved part
directives.

### P4. Runner Suite Selection

This proves the runner executes the expected ids for the `api` and `core`
suites.

```sh
dart test test/guardrails/blocking_suite_test.dart
```

Expected signal: subprocess assertions for `--suite=api` and `--suite=core`
pass and prove suite labels cannot be removed while the test stays green. The
same test keeps neighboring coverage for the default blocking inventory, explicit
`--guardrail=<id>` selection, and unknown or empty suite rejection.

### P5. Proof Map Alignment

This proves active documentation names executable P0 scope and actual P0 proof
files for the guardrails touched by this step.

```sh
dart run docs/tool/check_docs.dart
```

Expected signal: documentation structural checks pass after proof-map wording
and index entries are updated.

### P6. Proof-Map Semantic Search

This proves the stale broad proof-map claims are gone from active documentation
and the P0 phase brief names the hardened suite selection proof.

```sh
! rg -n "every mandatory blocking guardrail" docs/verification/tests.md
perl -0ne 'exit 1 if /## api\.public_exports_complete\b(?:(?!\n## ).)*test\.api_contract\.public_readable_union_variants/s' docs/indexes/by_guardrail.md
perl -0ne 'exit 1 if /## api\.public_types_complete\b(?:(?!\n## ).)*test\.api_contract\.canvas_field_update_static_semantics/s' docs/indexes/by_guardrail.md
perl -0ne 'exit 1 if /## test\.api_contract\.public_readable_union_variants\b(?:(?!\n## ).)*api\.public_exports_complete/s' docs/indexes/by_test_area.md
perl -0ne 'exit 1 if /## test\.api_contract\.canvas_field_update_static_semantics\b(?:(?!\n## ).)*api\.public_types_complete/s' docs/indexes/by_test_area.md
perl -0ne 'exit 1 if /## test\.guardrails\.blocking_suite\b(?:(?!\n## ).)*interaction\.no_concrete_store_imports/s' docs/indexes/by_test_area.md
perl -0ne 'exit 1 if /## test\.guardrails\.blocking_suite\b(?:(?!\n## ).)*interaction\.no_concrete_selection_imports/s' docs/indexes/by_test_area.md
perl -0ne '$found ||= /## api\.public_exports_complete\b(?:(?!\n## ).)*test\.api_contract\.public_exports_complete/s; END { exit($found ? 0 : 1) }' docs/indexes/by_guardrail.md
perl -0ne '$found ||= /## api\.public_types_complete\b(?:(?!\n## ).)*test\.api_contract\.public_types_complete/s; END { exit($found ? 0 : 1) }' docs/indexes/by_guardrail.md
perl -0ne '$found ||= /## test\.api_contract\.public_exports_complete\b(?:(?!\n## ).)*api\.public_exports_complete/s; END { exit($found ? 0 : 1) }' docs/indexes/by_test_area.md
perl -0ne '$found ||= /## test\.api_contract\.public_types_complete\b(?:(?!\n## ).)*api\.public_types_complete/s; END { exit($found ? 0 : 1) }' docs/indexes/by_test_area.md
rg -n --fixed-strings -- "--suite=api" docs/implementation/p0_package_skeleton_and_hard_boundaries.md
rg -n --fixed-strings -- "--suite=core" docs/implementation/p0_package_skeleton_and_hard_boundaries.md
```

Expected signal: no stale broad blocking-suite claim remains, and the
section-aware checks find no stale `by_guardrail` mappings from
`api.public_exports_complete` to `test.api_contract.public_readable_union_variants`
or from `api.public_types_complete` to
`test.api_contract.canvas_field_update_static_semantics`; no reverse
`by_test_area` mappings keep the same stale API completeness associations; the
`test.guardrails.blocking_suite` entry no longer presents future interaction
guardrails as current executable coverage; and the P0 phase brief names both
`--suite=api` and `--suite=core`. Positive section-aware checks also prove
`by_guardrail.md` maps the two P0 completeness guardrails to their actual P0
proof tests and `by_test_area.md` contains the matching reverse entries.

### P7. Named Extension Policy Search

This proves active public API documentation states only the accepted P0 named
extension rejection policy.

```sh
test "$(rg -c "does not expose named extension declarations" docs/contracts/public_api_v1.md)" = "1"
```

Expected signal: exactly the public API contract states the P0 rejection policy
for exported named extension declarations.

### P8. Full Guardrail Runner

This proves the project-owned guardrail entrypoint remains green on the clean
tree after the hardened P0 checks are installed. Negative proof for the bad
states is owned by P1 through P4.

```sh
dart run tool/guardrails/run.dart
```

Expected signal: the full blocking runner exits zero after all hardened
guardrails pass.

### P9. Repository Code Checks

This proves the Dart and local DCM checks remain green after code changes.

```sh
dart analyze
dcm analyze .
dcm calculate-metrics .
```

Expected signal: all local repository checks pass. These commands are not added
to GitHub Actions by this step.

### P10. Roadmap Completion State

This proves the roadmap index and linked step contract are closed together only
after all other proof has passed.

```sh
rg -n --fixed-strings -- "- [x] [Step 20. Guardrail proof hardening](plan/step_20_guardrail_proof_hardening.md)" PLAN.md
! rg -n "### Slice [0-9]+\\. \\[ \\]" plan/step_20_guardrail_proof_hardening.md
```

Expected signal: `PLAN.md` marks Step 20 complete and this step contract has no
remaining unchecked slice checkboxes.

## 6. Vertical Slices

### Slice 1. [x] Golden-driven legacy public symbol rejection

#### Implements

D1.

#### Obligations Covered

BUG_FIX.

#### Files

- Primary guardrail logic:
  `tool/guardrails/src/public_api_checks.dart` — read the legacy public symbol
  golden and compare it with the resolved public surface.
- Verify-only fixture support:
  `tool/guardrails/src/public_api_surface.dart` — existing targeted
  `libraryPath` support resolves the proposed fixture; no edit is expected in
  this slice.
- Regression proof:
  `test/api_contract/no_legacy_public_symbols_test.dart` — prove a legacy
  golden symbol outside the old subset is rejected.
- Proposed fixture:
  `test/api_contract/fixtures/legacy_public_symbol_exports.dart` — model a
  public barrel that exports a non-subset legacy public symbol.
- Verify-only source:
  `legacy/iwb_canvas_engine/tool/goldens/public_api_symbols.txt` — provide the
  legacy public-symbol source of truth; do not edit it.

#### Change

Replace the hand-written legacy symbol subset with golden-file loading and add
a regression fixture for a symbol such as `Transform2D` or `SceneView`.

#### Proof

Run P1 and P8.

#### Closure

The root public surface remains clean, the fixture fails with
`api.no_legacy_public_types`, and no duplicate legacy-symbol list remains in
guardrail code.

### Slice 2. [x] P0 import matrix violations use the blocking core id

#### Implements

D3.

#### Obligations Covered

BUG_FIX.

#### Files

- Primary guardrail logic:
  `tool/guardrails/src/core_boundary_checks.dart` — emit
  `core.import_boundaries` for P0 interaction-to-store and
  interaction-to-selection forbidden imports.
- Regression proof:
  `test/guardrails/core_boundary_negative_fixtures_test.dart` — expect
  `core.import_boundaries` for interaction store and selection import fixtures.
- Runner-path proof:
  `test/guardrails/import_boundaries_test.dart` — create a temporary
  production-shaped bad interaction import, assert
  `dart run tool/guardrails/run.dart --guardrail=core.import_boundaries` exits
  non-zero, remove the temporary file through `try`/`finally`, and keep the
  clean production-file integration path green for the full import matrix.
- Verify-only inventory:
  `tool/guardrails/src/guardrail_registry.dart` — remain the executable P0
  inventory and do not add the later interaction ids in this slice.

#### Change

Move P0 interaction import matrix failures onto the executable
`core.import_boundaries` id while preserving later interaction guardrail ids for
their future implementation step.

#### Proof

Run P3 and P8.

#### Closure

An interaction file importing concrete store or selection internals fails under
the full runner and under `--guardrail=core.import_boundaries`.

### Slice 3. [x] Public type traversal hardening and extension rejection

#### Implements

D2.

#### Obligations Covered

BUG_FIX, PUBLIC_API_CHANGE.

#### Files

- Primary traversal logic:
  `tool/guardrails/src/public_api_type_references.dart` — traverse typedef type
  parameter bounds and reject exported named extensions.
- Public surface support:
  `tool/guardrails/src/public_api_surface.dart` — expose enough resolved
  elements for extension detection without changing the exported-name registry
  semantics.
- Public contract owner:
  `docs/contracts/public_api_v1.md` — state the non-breaking P0/v1
  clarification that exported named extensions are not supported, with no
  migration, no version bump, and no `docs/_registry/public_api_v1.yaml` change.
- Regression proof:
  `test/api_contract/public_types_complete_test.dart` — prove typedef-bound and
  named-extension bad shapes are rejected.
- Proposed fixture:
  `test/api_contract/fixtures/public_type_reference_violations.dart` — model
  hidden typedef bounds and exported named extension declarations.
- Verify-only registry:
  `docs/_registry/public_api_v1.yaml` — remains unchanged because named
  extensions are rejected rather than added to the public surface.

#### Change

Extend the public type guardrail to cover typedef bounds and enforce the
selected non-breaking named-extension rejection policy.

#### Proof

Run P2, P7, and P8.

#### Closure

The guardrail rejects hidden typedef bounds and exported named extensions, the
public API contract states the compatibility decision, and no public export
registry change is made.

### Slice 4. [x] Runner suite selection proof

#### Implements

D4.

#### Obligations Covered

BUG_FIX.

#### Files

- Primary regression proof:
  `test/guardrails/blocking_suite_test.dart` — execute `--suite=api` and
  `--suite=core` and assert the expected ids are run.
- Verify-only runner entrypoint:
  `tool/guardrails/run.dart` — keep the public command surface unchanged unless
  the new test exposes a real dispatch defect.
- Verify-only runner metadata:
  `tool/guardrails/src/guardrail_registry.dart` — keep suite membership as the
  single executable runner inventory.

#### Change

Add subprocess coverage for the supported suite selection modes and expected
suite membership.

#### Proof

Run P4 and P8.

#### Closure

Removing `api` or `core` suite labels from runner metadata makes
`test/guardrails/blocking_suite_test.dart` fail.

### Slice 5. [x] Active proof-map alignment

#### Implements

D5.

#### Obligations Covered

BUG_FIX.

#### Files

- Proof-map wording:
  `docs/verification/tests.md` — describe `blocking_suite_test.dart` as proof
  for executable P0 hard-boundary guardrails, not every future mandatory
  guardrail.
- Guardrail index:
  `docs/indexes/by_guardrail.md` — point `api.public_exports_complete` and
  `api.public_types_complete` at their actual P0 proof tests.
- Reverse test-area index:
  `docs/indexes/by_test_area.md` — remove stale reverse mappings from
  later-phase API tests to P0 completeness guardrails and distinguish
  executable P0 blocking-suite coverage from future interaction guardrail
  release-readiness coverage.
- P0 phase brief:
  `docs/implementation/p0_package_skeleton_and_hard_boundaries.md` — align the
  phase's hard-boundary proof list with the runner's full, `--suite=api`,
  `--suite=core`, and `--guardrail=<id>` execution paths.
- Verify-only docs registry:
  `docs/_registry/sections.yaml` — confirm no registry-owned test id changes
  are required by the documentation check.

#### Change

Correct the active documentation map and P0 phase brief so reviewers follow the
executable P0 proof paths and do not infer broader runner coverage than the
runner provides.

#### Proof

Run P5 and P6.

#### Closure

The active proof-map documents no longer overclaim blocking-suite coverage,
`by_guardrail.md` and `by_test_area.md` name the P0 proof files for the touched
guardrails, and the P0 phase brief includes the hardened suite-selection proof
surface.

### Slice 6. [x] Roadmap closure

#### Implements

D6.

#### Files

- Roadmap index:
  `PLAN.md` — mark Step 20 complete after P1 through P9 are green.
- Step contract finalization:
  `plan/step_20_guardrail_proof_hardening.md` — mark all Step 20 slice
  checkboxes complete after P1 through P9 are green.

#### Change

Close the roadmap index and this step contract in the same finalization change
after all guardrail, documentation, and repository checks pass.

#### Proof

Run P10.

#### Closure

`PLAN.md` marks Step 20 complete, this step contract has no unchecked slice
checkboxes, and no completion checkbox is changed before P1 through P9 pass.

## 7. Final Gate

### Run Proof Set

P1, P2, P3, P4, P5, P6, P7, P8, P9, and P10.

### Done When

- D1 through D6 have passing proof;
- all `BUG_FIX` obligations have failing-before/passing-after structural
  proof;
- the `PUBLIC_API_CHANGE` obligation is reflected in the public API contract
  and protected by guardrail tests;
- no duplicate legacy public-symbol source exists in guardrail code;
- no out-of-scope CI DCM workflow change was made;
- no out-of-scope public named extension support was added;
- Step 20 and its slices remain unchecked until the roadmap closure slice, then
  P10 proves `PLAN.md` and this contract close together;
- whitespace validation passes.
