# Change Contract

Contract Mode: FULL
Contract Profile: ANALYZER_RULE
Contract Obligations: BUG_FIX, PUBLIC_API_CHANGE

## 1. Mandate and Boundary

### Mandate

Close HOLE-007 by making public error-code prose in `docs/contracts/public_api_v1.md` use only stable `CanvasDataErrorCode` enum values, and add an executable API-contract guardrail that fails when prose names a `CanvasDataException` code that is not declared by the public enum.

### In Scope

- Correct the edit-contract prose for `CanvasEdit.addElement` error codes in `docs/contracts/public_api_v1.md`.
- Register `test.api_contract.public_error_codes_match_contract_prose` and `api.public_error_codes_match_contract_prose` in `docs/_registry/sections.yaml`, the public API contract context block, and verification documentation.
- Add `test/api_contract/public_error_codes_match_contract_prose_test.dart` as the enforcement owner for matching prose `CanvasDataException` codes to the public `CanvasDataErrorCode` enum.
- Prove that the old shorthand codes `duplicateId` and `missingReference` are retired from active public API contract prose.

### Out of Scope

- Changing the exported `CanvasDataErrorCode` enum values.
- Adding alias enum values for `duplicateId` or `missingReference`.
- Changing runtime, DTO, codec, edit-kernel, diagnostics, or resource behavior.
- Editing legacy package files.
- Moving free-form Markdown wording checks into `docs/tool/check_docs.dart`.

## 2. Evidence Map

### Baseline Evidence

These facts describe repository state before execution. They are evidence for the change, not target-state requirements.

- `docs/contracts/public_api_v1.md:73` states that Public API v1 declarations are normative and must compile against the documented names and semantics.
- `docs/contracts/public_api_v1.md:79` through `docs/contracts/public_api_v1.md:84` make `docs/_registry/public_api_v1.yaml` the exported-name inventory while keeping public semantics and declaration contracts in `docs/contracts/public_api_v1.md`.
- `docs/contracts/public_api_v1.md:1227` currently says `addElement with id collision throws CanvasDataException duplicateId`.
- `docs/contracts/public_api_v1.md:1228` currently says `addElement with missing resource reference throws CanvasDataException missingReference`.
- `docs/contracts/public_api_v1.md:2063` through `docs/contracts/public_api_v1.md:2084` declare the normative `CanvasDataErrorCode` enum.
- `docs/contracts/public_api_v1.md:2076` declares `duplicateElementId`; `docs/contracts/public_api_v1.md:2077` declares `duplicateLayerId`; `docs/contracts/public_api_v1.md:2078` declares `duplicateResourceId`; `docs/contracts/public_api_v1.md:2079` declares `missingResourceReference`.
- `docs/contracts/public_api_v1.md:2094` types `CanvasDataException.code` as `CanvasDataErrorCode`.

### Entry Paths

- The implementation entrypoint is the public API contract prose under `docs/contracts/public_api_v1.md` and the API contract test path `test/api_contract/public_error_codes_match_contract_prose_test.dart`.
- The planning entrypoint is the root roadmap entry in `PLAN.md`, which links this step file.

### Current Owners

- `docs/contracts/public_api_v1.md` owns public API semantics, signature rules, and declaration contracts.
- `CanvasDataErrorCode` in `docs/contracts/public_api_v1.md` owns the stable public error-code names.
- `test/api_contract/public_error_codes_match_contract_prose_test.dart` will own the executable recognition rule for prose `CanvasDataException` code references.
- `docs/_registry/sections.yaml` owns section-level guardrail/test membership that feeds context blocks and verification navigation for `section_04_public_api_v1`, `section_22_guardrails_machine_checks`, and `section_23_tests`.
- `docs/verification/guardrails.md` owns the mandatory guardrail inventory; `docs/verification/tests.md` owns the documented test mapping.

### Existing Checks

- `docs/contracts/public_api_v1.md:32` through `docs/contracts/public_api_v1.md:50` list required tests for the public API contract, but do not yet list `test.api_contract.public_error_codes_match_contract_prose`.
- `docs/contracts/public_api_v1.md:51` through `docs/contracts/public_api_v1.md:65` list public API guardrails, but do not yet list `api.public_error_codes_match_contract_prose`.
- `docs/_registry/sections.yaml:80` through `docs/_registry/sections.yaml:147` define `section_04_public_api_v1` and its public API guardrails/tests, but do not yet list `api.public_error_codes_match_contract_prose` or `test.api_contract.public_error_codes_match_contract_prose`.
- `docs/_registry/sections.yaml:751` through `docs/_registry/sections.yaml:782` define `section_22_guardrails_machine_checks` and its mandatory guardrails, but do not yet list `api.public_error_codes_match_contract_prose`.
- `docs/_registry/sections.yaml:839` through `docs/_registry/sections.yaml:1012` define `section_23_tests` and its test inventory, but do not yet list `test.api_contract.public_error_codes_match_contract_prose`.
- `docs/verification/guardrails.md:136` through `docs/verification/guardrails.md:149` contain adjacent mandatory public API guardrails, but no public error-code prose guardrail.
- `docs/verification/tests.md:313` through `docs/verification/tests.md:336` document adjacent API contract tests, but no public error-code prose test.
- A targeted `find test -maxdepth 3 -type f` returns no current root test files, so this step must create the API-contract test file instead of updating an existing one.

### Valid Precedents

- `docs/verification/tests.md:313` through `docs/verification/tests.md:336` show the documented pattern for `test/api_contract/*_test.dart` files that enforce public API contract rules.
- `docs/tool/check_docs.dart:1` through `docs/tool/check_docs.dart:7` explicitly keep free-form Markdown wording checks out of the structural docs checker and route them to structured registries, generated documentation, analyzer/lint rules, Dart tests, or benchmarks.
- `pubspec.yaml:15` through `pubspec.yaml:21` includes `test`, `analyzer`, and `yaml` dev dependencies, so a targeted Dart API-contract test is available without adding dependencies.

### Repository Rules

- Root `PLAN.md:5` through `PLAN.md:8` require every roadmap step to have a linked step document.
- Root `PLAN.md:18` through `PLAN.md:19` require the plan index and linked step document to be updated together when a step is completed.
- Root repository instructions require `dart analyze`, `dcm analyze .`, and `dcm calculate-metrics .` after code changes.
- Public API error codes are part of the compatibility promise because they are declared public enum values and exposed through `CanvasDataException.code`.

### Misleading Patterns

- The shorthand prose names `duplicateId` and `missingReference` look like friendly summaries, but they are not declared public enum values and cannot be treated as stable public codes.
- Adding `duplicateId` or `missingReference` to the enum would make invalid shorthand part of the public API instead of correcting the accepted contract.
- `docs/tool/check_docs.dart` is nearby documentation tooling, but it is explicitly the wrong owner for free-form Markdown wording checks.
- Legacy package tests or guardrails are not the owner for the new architecture root package.

## 3. Architecture Decision

### Selected Form

Add a focused API-contract test named `api.public_error_codes_match_contract_prose` in `test/api_contract/public_error_codes_match_contract_prose_test.dart`. The test must parse `docs/contracts/public_api_v1.md`, extract the `CanvasDataErrorCode` enum values from the normative Dart block, extract prose tokens matching `throws CanvasDataException <code>`, and fail if any prose token is not a declared enum value.

The initial reproducer must prevent vacuous success by proving that at least one prose `CanvasDataException` code reference exists and by reporting the current invalid tokens. After the prose correction, the final guardrail must also prove that the corrected relevant prose references `duplicateElementId` and `missingResourceReference` are present and declared enum values.

### Ownership

`docs/contracts/public_api_v1.md` remains the source of truth for public error semantics and enum declarations. `docs/_registry/sections.yaml` owns the section-level guardrail/test registration that keeps context blocks and verification docs aligned. The new API-contract test owns mechanical recognition of mismatches between prose `CanvasDataException` code references and the public `CanvasDataErrorCode` enum.

### Seam

The seam is the human-readable public API contract prose phrase `throws CanvasDataException <code>`. The successor stable seam for code names is the public `CanvasDataErrorCode` enum value set in the same contract document.

### Dependency Direction

The test depends on the Markdown public API contract. The public API contract, public registry, and production code must not depend on the test. `docs/tool/check_docs.dart` must remain a structural documentation checker and must not gain free-form wording checks for this rule.

### State and Data Ownership

No runtime state, persisted data, schema data, or exported Dart implementation state changes. The only data interpreted by the new rule is text from `docs/contracts/public_api_v1.md`: enum value names and prose error-code references.

### Entry and Exit Boundaries

Entry is a developer edit to public API contract prose or the `CanvasDataErrorCode` enum. Exit is a failing or passing API-contract test result. The rule must report mismatched prose code names as test failures with enough context to identify the invalid prose token.

### Verification Strategy

Use the new API-contract test as the reproducer and guardrail. It must fail against the current baseline because `duplicateId` and `missingReference` are not enum values, then pass after the prose is corrected to `duplicateElementId` and `missingResourceReference`. Use targeted negative searches to prove retired shorthand names are gone from active public API contract prose.

### Decision Ledger

Slices and the final gate rely on the locked architecture directly; no separate durable decision IDs are needed.

### Rejected Alternatives

- Do not add `duplicateId` or `missingReference` to `CanvasDataErrorCode`; that would preserve an ambiguous API shape instead of using the already precise public enum values.
- Do not implement this as a `docs/tool/check_docs.dart` rule; that tool explicitly excludes free-form Markdown wording checks.
- Do not use a prose-only reminder; this hole recurs when the prose is not mechanically checked against the enum.
- Do not patch legacy package tests; the root package is the canonical target for the architecture rebuild.

## 4. Execution Guardrails

### Required Order

1. Add the API-contract test while the current bad prose still exists, then run the new test to capture the failing reproducer.
2. Correct the public API contract prose, add the final corrected-code positive recognition, and update `docs/_registry/sections.yaml` before or together with the public API context block and verification documentation.
3. Run the targeted API-contract test and retired-term searches.
4. Run repository-required broad checks because the implementation adds Dart test code.

### Cross-Slice Constraints

- Keep `CanvasDataErrorCode` enum values unchanged unless a separate accepted contract explicitly changes the public API shape.
- Keep the test parser local to `test/api_contract/public_error_codes_match_contract_prose_test.dart`; do not create a production helper or shared parser for this narrow rule.
- Keep the recognized prose grammar intentionally narrow: only `throws CanvasDataException <code>` tokens are in scope.
- Keep section registry membership and document context blocks aligned for `section_04_public_api_v1`, `section_22_guardrails_machine_checks`, and `section_23_tests`.
- Preserve the distinction between duplicate element, layer, and resource id codes.

### Seam Migration

No shared seam migration is in scope. The shorthand prose names are invalid references, not accepted seam names with consumers to migrate. Retirement is complete when active public API contract prose no longer contains `CanvasDataException duplicateId` or `CanvasDataException missingReference`.

### Forbidden Moves

- Do not add alias enum values.
- Do not broaden the test into a general Markdown linter.
- Do not add new dependencies.
- Do not change public exports or `docs/_registry/public_api_v1.yaml` unless implementation evidence proves the registry already contains stale public error-code names.
- Do not edit implementation docs, diagrams, or legacy files unless the new test exposes an active source-of-truth contradiction in those files.

### Deferred Broad Verification

No broad verification is deferred. The final gate must run both targeted and repository-required checks in this environment when the implementation is performed.

## 5. Proof Plan

### P1. Public error-code prose guardrail

This proves prose `CanvasDataException` code names are recognized and must be stable `CanvasDataErrorCode` enum values.

```sh
dart test test/api_contract/public_error_codes_match_contract_prose_test.dart
```

Expected signal before prose correction: fails and reports `duplicateId` and `missingReference` as non-enum prose codes. Expected signal after prose correction: passes.

### P2. Retired shorthand terms are gone from public contract prose

This proves the invalid shorthand public error-code names are no longer present in active public API contract prose.

```sh
! rg -n "CanvasDataException (duplicateId|missingReference)" docs/contracts/public_api_v1.md
```

Expected signal after prose correction: no matches.

### P3. Documentation structure remains valid

This proves documentation registries, navigation, diagram catalogs, and context references remain structurally valid after contract and verification-doc edits.

```sh
dart run docs/tool/check_docs.dart
```

Expected signal: exits 0.

### P4. Dart analysis remains clean

This proves the new Dart test and existing package sources remain analyzable.

```sh
dart analyze
```

Expected signal: exits 0.

### P5. DCM analysis remains clean

This proves repository static-analysis rules remain satisfied after adding the guardrail test.

```sh
dcm analyze .
```

Expected signal: exits 0.

### P6. DCM metrics remain reviewed

This proves metrics checks have been run and any violations are treated as review signals instead of being hidden by metric-only refactors.

```sh
dcm calculate-metrics .
```

Expected signal: exits 0, or reports only explicitly accepted metric findings with no metric-only workaround.

## 6. Vertical Slices

### Slice 1. [ ] Add failing public error-code prose guardrail

#### Implements

This slice relies on the locked architecture without separate decision IDs.

#### Obligations Covered

BUG_FIX

#### Files

- New enforcement test reproducer: `test/api_contract/public_error_codes_match_contract_prose_test.dart` — parses the public API contract, extracts enum values and prose `CanvasDataException` code references, proves prose references are non-empty, and fails on prose codes outside the enum while the current shorthand prose remains.

#### Change

Create the new focused API-contract test while the current bad prose is still present. The test must fail against the baseline mismatch before any prose correction is made. This slice must not require future corrected prose tokens to exist.

#### Proof

- Run P1 before prose correction and confirm it fails because `duplicateId` and `missingReference` are not declared `CanvasDataErrorCode` values.

#### Closure

The slice is complete when the new test exists, fails for the current mismatch, and the failure identifies the invalid prose code names.

### Slice 2. [ ] Align public API prose and register the guardrail

#### Implements

This slice relies on the locked architecture without separate decision IDs.

#### Obligations Covered

BUG_FIX, PUBLIC_API_CHANGE

#### Files

- Primary public contract edit: `docs/contracts/public_api_v1.md` — replaces shorthand prose codes with exact public enum values and registers the required test and guardrail id in the context block.
- Section registry alignment: `docs/_registry/sections.yaml` — adds `api.public_error_codes_match_contract_prose` to `section_04_public_api_v1.guardrails` and `section_22_guardrails_machine_checks.guardrails`, and adds `test.api_contract.public_error_codes_match_contract_prose` to `section_04_public_api_v1.tests` and `section_23_tests.tests`.
- Final enforcement test alignment: `test/api_contract/public_error_codes_match_contract_prose_test.dart` — becomes the final owner for the guardrail and adds positive recognition that corrected prose codes `duplicateElementId` and `missingResourceReference` are present and declared enum values.
- Guardrail inventory alignment: `docs/verification/guardrails.md` — documents `api.public_error_codes_match_contract_prose` as a mandatory public API guardrail.
- Test inventory alignment: `docs/verification/tests.md` — documents `test/api_contract/public_error_codes_match_contract_prose_test.dart` and the rule it enforces.
- Export registry explicit non-edit: `docs/_registry/public_api_v1.yaml` — must remain unchanged unless implementation evidence shows it contains stale error-code names, because the exported public names `CanvasDataException` and `CanvasDataErrorCode` are already the right registry granularity.

#### Change

Replace `CanvasDataException duplicateId` with `CanvasDataException duplicateElementId`, replace `CanvasDataException missingReference` with `CanvasDataException missingResourceReference`, and register the new API-contract guardrail/test in the same source-of-truth surfaces that own adjacent public API checks. Update `docs/_registry/sections.yaml` before or together with the context blocks so the registry remains the source for section membership rather than a stale mirror.

The compatibility decision is a non-breaking public contract correction: no exported enum value is removed or renamed, no new alias is introduced, and the prose is aligned to the already-declared public enum. No migration or versioning note is required beyond the corrected contract text because the invalid shorthand values were not declared API values.

#### Proof

- Run P1 and confirm the new guardrail passes.
- Run P2 and confirm retired shorthand prose names are absent from the public API contract.
- Run P3 and confirm documentation structure remains valid.

#### Closure

The slice is complete when public prose, guardrail documentation, and test documentation all reference only stable public enum values and the new guardrail passes.

### Slice 3. [ ] Run final repository checks

#### Implements

This slice relies on the locked architecture without separate decision IDs.

#### Files

- Verification-only command set: `pubspec.yaml` — confirms existing dev dependencies are sufficient and no dependency update is required.
- Verification-only command set: repository root — runs the final proof commands without editing additional files.

#### Change

Run the repository-required broad checks after the Dart test and documentation edits are complete. Do not reshape code solely to satisfy metrics; if DCM reports a metrics concern, treat it according to repository metrics policy.

#### Proof

- Run P4.
- Run P5.
- Run P6.

#### Closure

The slice is complete when the final broad checks have been run and their results are recorded in the implementation report.

## 7. Final Gate

### Run Proof Set

- P1
- P2
- P3
- P4
- P5
- P6

### Done When

- the public API contract prose uses `duplicateElementId` and `missingResourceReference`;
- no active public API contract prose references `CanvasDataException duplicateId` or `CanvasDataException missingReference`;
- `test.api_contract.public_error_codes_match_contract_prose` is registered and documented;
- `api.public_error_codes_match_contract_prose` is registered and documented;
- the new guardrail test prevents prose `CanvasDataException` code names from drifting outside `CanvasDataErrorCode`;
- `CanvasDataErrorCode` exported values are not broadened with alias shorthand values;
- all referenced proof commands have been run and reported;
- all Contract Obligations are satisfied;
- no out-of-scope files were changed;
- whitespace validation passes.
