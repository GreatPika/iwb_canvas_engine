# Change Contract

Contract Mode: FULL
Contract Profile: BEHAVIOR_CHANGE
Contract Obligations: PUBLIC_API_CHANGE

## 1. Mandate and Boundary

### Mandate

Implement the P1 v1 scope gate before public API freeze. The gate must make the
mandatory v1 public surface compile, prove that an external app adapter can use
only the root public barrel, reject legacy public/runtime shapes before API
freeze, and adopt validation limits at public constructors and boundary checks.

### In Scope

- Public API draft declarations and root barrel exports needed by
  `docs/_registry/public_api_v1.yaml` and `docs/contracts/public_api_v1.md`.
- P1 scope checklist result in this step contract, based only on the existing
  v1 scope, accepted differences, legacy capability inventory, and donor
  registry owners.
- Public constructor and boundary validation needed by
  `docs/contracts/validation_limits.md`.
- API contract tests and executable guardrails listed for the P1 phase.
- External app-adapter compile fixture that imports only
  `package:iwb_canvas_engine/iwb_canvas_engine.dart`.
- Scope-closure review against the existing legacy capability inventory, donor
  registry, and accepted differences.
- Read the P1 diagram inputs and update only the existing diagram owners when
  public API, validation, diagnostics, or public-edit flow changes make an
  existing diagram stale.
- Updates to existing source-of-truth documents only when implementation finds a
  scope gap that must be mapped to v1 scope, accepted differences, or a later
  owning phase/test.
- Final P1 planning checkbox closure in `PLAN.md` and this step file after the
  implementation gate is green.

### Out of Scope

- P2 public API freeze.
- Legacy API compatibility, legacy facade creation, old runtime wrapping, or
  legacy production fallback.
- New parallel capability inventories, donor inventories, or markdown-only
  guardrails.
- Full runtime, rendering, interaction, resource, codec, or Flutter surface
  behavior beyond the compileable public draft and boundary validation required
  by P1.
- Application-owned adapter implementation inside this package.

## 2. Evidence Map

### Baseline Evidence

These facts describe repository state before execution. They are evidence for
the change, not target-state requirements.

- P1 is explicitly the gate between oracle evidence and API commitment:
  `docs/implementation/p1_v1_scope_gate_before_public_api_freeze.md:110`.
- P1 must stop public API freeze until mandatory v1 scope, accepted differences,
  and validation limits are explicit and backed by public API or package
  boundary checks:
  `docs/implementation/p1_v1_scope_gate_before_public_api_freeze.md:3`.
- The current repository already has a root public barrel:
  `lib/iwb_canvas_engine.dart:1`.
- The current public API registry already lists the target exported names:
  `docs/_registry/public_api_v1.yaml:1`.
- Existing API contract tests cover export registry parity, undefined public
  type references, and legacy public symbol rejection:
  `test/api_contract/public_exports_complete_test.dart:5`,
  `test/api_contract/public_types_complete_test.dart:6`, and
  `test/api_contract/no_legacy_public_symbols_test.dart:6`.
- Existing guardrail runner inventory currently contains only
  `api.no_legacy_public_types`, `api.public_exports_complete`,
  `api.public_types_complete`, and P0 core guardrails:
  `tool/guardrails/src/guardrail_registry.dart:23`.

### Entry Paths

- P1 phase contract:
  `docs/implementation/p1_v1_scope_gate_before_public_api_freeze.md:1`.
- Public API contract:
  `docs/contracts/public_api_v1.md:76`.
- Validation limits contract:
  `docs/contracts/validation_limits.md:30`.
- Root public package barrel:
  `lib/iwb_canvas_engine.dart:1`.
- Guardrail runner entrypoint and inventory:
  `tool/guardrails/run.dart:6`,
  `tool/guardrails/src/guardrail_registry.dart:8`.
- P1 diagram inputs:
  `docs/diagrams/c4_container.mmd`,
  `docs/diagrams/c4_context.mmd`,
  `docs/diagrams/dfd_diagnostics_error_projection.mmd`, and
  `docs/diagrams/dfd_public_edit.mmd`, as required by the P1 phase at
  `docs/implementation/p1_v1_scope_gate_before_public_api_freeze.md:48`.

### Current Owners

- `docs/contracts/public_api_v1.md` owns public API semantics and declaration
  contracts; `docs/_registry/public_api_v1.yaml` owns exported-name
  completeness:
  `docs/contracts/public_api_v1.md:82`.
- `docs/contracts/validation_limits.md` owns mandatory v1 validation limits and
  boundary locations:
  `docs/contracts/validation_limits.md:30` and
  `docs/contracts/validation_limits.md:71`.
- `docs/architecture/00_architecture_overview.md` owns the v1 scope lock and
  legacy-ban target decision:
  `docs/architecture/00_architecture_overview.md:63` and
  `docs/architecture/00_architecture_overview.md:78`.
- `docs/architecture/04_decisions_and_differences.md` owns accepted differences
  from legacy:
  `docs/architecture/04_decisions_and_differences.md:28`.
- `docs/verification/legacy_capability_inventory.md` is only evidence input for
  P1 scope decisions:
  `docs/verification/legacy_capability_inventory.md:25`.
- `docs/_registry/donors.yaml` is the canonical donor registry; P1 donor
  closure requirements are summarized in
  `docs/donors/08_p1_closure_requirements.md:1`.

### Existing Checks

- `api.public_exports_complete` compares public barrel exports with the public
  registry:
  `tool/guardrails/src/public_api_checks.dart:8`.
- `api.public_types_complete` rejects undefined public signature references:
  `tool/guardrails/src/public_api_checks.dart:30`.
- `api.no_legacy_public_types` rejects exported names from the legacy golden:
  `tool/guardrails/src/public_api_checks.dart:49`.
- The blocking guardrail suite test locks runner inventory and suite selection:
  `test/guardrails/blocking_suite_test.dart:7`.
- P1 requires additional tests and guardrails beyond the current executable
  inventory, including app-adapter compile proof, constructor/schema limits,
  public API compile proof, DTO immutability, equality policy, id validation,
  and known-field validation:
  `docs/implementation/p1_v1_scope_gate_before_public_api_freeze.md:65`.

### Valid Precedents

- Public API registry parity is already implemented as a resolved public surface
  check:
  `tool/guardrails/src/public_api_checks.dart:8`.
- The public type reference guardrail already supports positive and negative
  fixture libraries:
  `test/api_contract/public_types_complete_test.dart:11` and
  `test/api_contract/public_types_complete_test.dart:23`.
- The legacy public symbol guardrail already uses the legacy public API golden
  as negative proof:
  `test/api_contract/no_legacy_public_symbols_test.dart:11`.
- Guardrail design patterns already classify P1-style checks as resolved public
  surface, parsed AST directive, runner inventory, and behavioral seam tests:
  `docs/verification/guardrail_design_patterns.md:83`.

### Repository Rules

- The new package is a separate package with a new public API, one new runtime,
  functional compatibility with legacy, no legacy API compatibility, no legacy
  facade, and no old runtime in the shipped artifact:
  `docs/architecture/00_architecture_overview.md:38`.
- The root barrel exports only `src/api/**`:
  `docs/architecture/02_package_boundaries.md:161`.
- The external adapter proof must import only
  `package:iwb_canvas_engine/iwb_canvas_engine.dart`, not `src/**`, legacy
  symbols, or internal runtime classes:
  `docs/architecture/00_architecture_overview.md:103` and
  `docs/contracts/public_api_v1.md:113`.
- Mandatory public API rules include dartdoc, explicit class modifiers,
  signature-shape limits, no named public extensions in v1, exported readable
  sealed variants where needed, and explicit equality policy:
  `docs/contracts/public_api_v1.md:93`,
  `docs/contracts/public_api_v1.md:98`,
  `docs/contracts/public_api_v1.md:127`, and
  `docs/contracts/public_api_v1.md:152`.
- Validation must be applied at public construction, edit/update
  construction, dynamic or generated `CanvasFieldUpdate` materialization, edit
  preflight, schema decode, load materialization, resource upsert, runtime config
  materialization, interaction config mutation, request id generation, and
  pointer sample routing:
  `docs/contracts/validation_limits.md:71`.

### Misleading Patterns

- Legacy inventory rows must not be treated as proof that the next public API is
  complete:
  `docs/verification/legacy_capability_inventory.md:111`.
- P1 explicitly forbids turning legacy inventory review into markdown-only
  executable proof:
  `docs/implementation/p1_v1_scope_gate_before_public_api_freeze.md:106`.
- Legacy public names such as `SceneController`, `SceneSnapshot`, `NodeSpec`,
  `NodePatch`, `PatchField`, and old schema v7 public entrypoints are banned
  from the new package public API:
  `docs/architecture/00_architecture_overview.md:78`.
- Donor entries are implementation inputs, not legacy architecture to copy:
  `docs/donors/08_p1_closure_requirements.md:1`.
- P1-related diagram catalog entries already bind `c4_context`, `c4_container`,
  `dfd_public_edit`, and `dfd_diagnostics_error_projection` to P1:
  `docs/diagrams/README.md:10`, `docs/diagrams/README.md:17`,
  `docs/diagrams/README.md:38`, and `docs/diagrams/README.md:136`.

## 3. Architecture Decision

### Selected Form

P1 will be implemented as a public API gate over the root public barrel and
package boundaries. Public declarations and validation helpers are added only
under the package-owned API/contract/codec/runtime boundary files required for
the v1 draft to compile. Executable proof is added through API contract tests
and guardrail runner entries; legacy inventory and donor registry review remain
decision input and do not become a second machine-readable inventory or
markdown-only guardrail.

### Ownership

- Public semantics stay owned by `docs/contracts/public_api_v1.md`.
- Exported-name completeness stays owned by `docs/_registry/public_api_v1.yaml`
  and `lib/iwb_canvas_engine.dart`.
- Validation limits stay owned by `docs/contracts/validation_limits.md` and are
  enforced by public constructors and boundary materialization helpers.
- Executable guardrail ids and suite routing stay owned by
  `tool/guardrails/src/guardrail_registry.dart` and delegated check modules
  under `tool/guardrails/src/**`.
- Guardrail implementation pattern selection stays owned by
  `docs/verification/guardrail_design_patterns.md`.
- P1 scope gap disposition stays in existing source-of-truth owners:
  v1 scope in `docs/architecture/00_architecture_overview.md`, accepted
  differences in `docs/architecture/04_decisions_and_differences.md`, donor
  metadata in `docs/_registry/donors.yaml`, and later-test ownership in the
  relevant phase/test documentation.

### Seam

The public seam is `package:iwb_canvas_engine/iwb_canvas_engine.dart`. P1 must
make this seam compile for the v1 draft and prove external integration through
that seam only. `src/**`, legacy package symbols, internal runtime classes, and
application adapter files are not public seams.

### Dependency Direction

- `lib/iwb_canvas_engine.dart` exports only package-owned `lib/src/api/**`
  declarations.
- Public API declarations may depend only on approved Dart, Flutter, and
  package-owned API/validation types named by the public API contract.
- Guardrail and test code may inspect production API declarations, registries,
  and fixtures; production code must not depend on test, tool, docs, legacy
  source, or guardrail code.
- Validation owner code may be consumed by public constructors and later
  schema/runtime boundaries, but must not import legacy validators.

### Public API Compatibility

P1 is a pre-freeze public draft change. The compatibility decision is: the new
package is not legacy API-compatible, no legacy public facade is promised, and
P2 public API freeze remains blocked until this gate is green. Changes made by
this step are breaking with respect to any earlier draft shape in this
repository, but they are not a stable-public migration because the package is
still unpublished and `publish_to: none` before P2 freeze. No app migration
guide is required for P1; any public API change after P2 must use a new public
API change contract with explicit versioning or migration notes.

### Export Registry Handling

`docs/_registry/public_api_v1.yaml` is locked verify-only for this contract. P1
may make implementation declarations and barrel exports match that registry, but
must not change registry membership. If scope review finds that the registry is
missing a required v1 public name or contains a name that conflicts with the P1
phase, implementation must stop for a contract revision instead of editing the
registry inside this step.

### State and Data Ownership

- P1 public DTO state is immutable or identity-owned according to the public
  equality policy. Collections exposed by public DTOs are defensively owned
  before exposure.
- Public id value data is owned by validated id wrapper classes and cannot be
  exposed through unchecked public extension types.
- Validation limit constants and validators are the single owner of numeric,
  length, metadata, id, and schema-boundary limit checks introduced by P1.
- The app-adapter compile fixture owns no runtime state; it is proof-only
  consumer code.

### Entry and Exit Boundaries

- Entry boundaries: public constructors, public update/materialization helpers,
  schema decode/materialization stubs needed for P1 proof, root barrel exports,
  and guardrail runner selection.
- Exit boundaries: public read fields/getters, public result objects, encoded
  schema output where present, guardrail diagnostics, and compile success or
  failure for the app-adapter fixture.

### Verification Strategy

Use executable API contract tests for public compileability and public behavior,
guardrail runner tests for structural enforcement, targeted negative fixtures
for legacy and invalid public surface shapes, and the repository-wide Dart/DCM
checks required after code changes.

### Decision Ledger

| ID | Decision | Owner | Proof |
|---|---|---|---|
| D1 | P1 proof is executable API/package-boundary proof over the root public barrel, not a markdown-only legacy inventory mapping. | Public API contract, guardrail runner, API contract tests | P1, P2, P3, P4, P5, P6, P9, P10 |
| D2 | Validation limits are adopted once through public constructors and shared boundary validators, not duplicated at individual call sites. | Public API validation owner and codec boundary validators | P3, P4, P6, P8 |

### Rejected Alternatives

- Rejected: freeze P2 first and retrofit scope gaps later. This contradicts the
  P1 exit gate and makes later public compatibility changes expensive.
- Rejected: create a legacy-compatible public facade. The repository's fixed
  architecture decision accepts functional compatibility, not legacy API
  compatibility.
- Rejected: prove P1 by parsing or expanding legacy inventory markdown. The
  inventory is evidence input only; executable proof belongs to API contract
  tests and guardrails.
- Rejected: copy donor structure wholesale into the new package. Donor rules
  allow copy/adapt only for selected behavior and require forbidden donor shells
  to remain avoided.

## 4. Execution Guardrails

### Required Order

1. Review v1 scope, accepted differences, legacy capability inventory, donor
   registry, P1 donor closure requirements, and P1 diagram inputs before
   changing public code.
2. Close any discovered scope gap in the existing owning source of truth before
   public API declarations are treated as ready for proof.
3. Make the root public barrel and exported API declarations compile against the
   registry and contract.
4. Add shared validation limits and wire public constructors/boundary
   materialization through them.
5. Add API contract fixtures/tests for compile proof, external adapter proof,
   legacy rejection, immutability, equality, id validation, and validation
   limits.
6. Register executable P1 guardrails and update guardrail runner tests.
7. Run the final proof set and then mark Step 21 complete in `PLAN.md` and this
   file in the same implementation change.

### P1 Guardrail Pattern Map

Use `docs/verification/guardrail_design_patterns.md` as the source of truth for
pattern meaning and bypass analysis. This step applies the following pattern
selection to the executable P1 guardrail set:

| Guardrail id | Primary pattern | Secondary pattern |
|---|---|---|
| `api.integration_surface_complete` | `behavioral_seam_test` | `parsed_ast_directive`, `runner_inventory` |
| `api.no_legacy_public_types` | `negative_legacy_shape` | `resolved_public_surface` |
| `api.public_exports_complete` | `registry_parity` | `resolved_public_surface` |
| `api.public_types_complete` | `resolved_public_surface` | `registry_parity` |
| `api.public_api_compiles_as_written` | `behavioral_seam_test` | `resolved_public_surface` |
| `api.no_undefined_public_type_references` | `resolved_public_surface` | `registry_parity` |
| `api.dto_immutability` | `behavioral_seam_test` | `resolved_public_surface`, `parsed_ast_directive` |
| `api.equality_policy_explicit` | `behavioral_seam_test` | `registry_parity` |
| `api.id_validation_no_extension_type_escape` | `behavioral_seam_test` | `resolved_public_surface`, `parsed_ast_directive` |
| `codec.known_fields_validated` | `behavioral_seam_test` | `registry_parity` |
| `core.no_legacy_imports` | `parsed_ast_directive` | `negative_legacy_shape` |
| `core.no_scene_controller_shape_dependency` | `negative_legacy_shape` | `resolved_element_identity` |
| `core.no_node_spec_patch_shape_dependency` | `negative_legacy_shape` | `resolved_element_identity` |

If implementation evidence shows that a listed pattern cannot prove the
owner-level invariant for this step, stop for a contract revision instead of
silently substituting a weaker check.

### Cross-Slice Constraints

- Do not add production imports from `legacy/**`.
- Do not export internal runtime, frame, store, interaction, resource, codec, or
  Flutter bridge implementation files from the root barrel.
- Do not create `AppCanvasPort`, `LegacyEngineAdapter`, or `NextEngineAdapter`
  inside the package.
- Do not use public named extension declarations for v1 ids or public values.
- Do not introduce duplicate validation constants outside the selected
  validation owner.
- Tests that prove public consumer behavior must import the root barrel unless
  the test is intentionally exercising a guardrail implementation helper.
- Do not edit P1 diagrams unless the public API, validation, diagnostics, or
  public-edit flow represented by that diagram actually changes.

### Seam Migration

No shared production seam is migrated or retired by this contract. The contract
hardens the existing root public barrel as the package consumer seam and adds
negative proof that legacy and internal seams are not exposed.

### Forbidden Moves

- Do not satisfy P1 by deleting registry names or weakening
  `docs/contracts/public_api_v1.md`.
- Do not silence public type, legacy symbol, equality, immutability, id, or
  validation failures with allowlists scoped only to the current files.
- Do not broaden package privileges, relax import boundaries, or add runtime
  fallback paths to make compile fixtures pass.
- Do not mark this plan step complete before P1 proof is green.

### Deferred Broad Verification

P1 does not need to prove full runtime/edit/render/interaction behavior for
P3-P14. Final broad checks still run because P1 edits production code and the
guardrail runner, but later phase behavior remains deferred to its owning phase.

## 5. Proof Plan

### P1. Static Analysis

This proves the changed Dart code, tests, and guardrail tool code analyze under
the repository analyzer configuration.

```sh
dart analyze
```

Expected signal: exits 0 with no analyzer errors.

### P2. DCM Analysis

This runs repository DCM analysis as a review signal. It must not be satisfied
by reshaping cohesive code only to reduce reported metrics.

```sh
dcm analyze .
```

Expected signal: exits 0, or every remaining finding is handled according to
the repository DCM exception policy: preserve coherent design, add only
targeted local suppressions with nearby plain-language justification when the
threshold conflicts with readability or architecture, and do not perform
metric-only splits.

### P3. DCM Metrics

This runs repository DCM metric checks as review signals for the changed code.
It must not force metric-only refactors.

```sh
dcm calculate-metrics .
```

Expected signal: exits 0, or every remaining metric finding is explicitly
reviewed under the repository DCM exception policy: preserve coherent design,
use targeted local suppressions only when they are clearer or safer than
reshaping the code, and surface the trade-off instead of changing structure only
to satisfy a threshold.

### P4. API Contract Tests

This proves the public barrel, public API draft, public compile fixtures,
legacy-ban fixtures, immutability, equality, id validation, and external adapter
compile proof by running the required P1 API contract test files directly.

```sh
dart test \
  test/api_contract/public_exports_complete_test.dart \
  test/api_contract/public_types_complete_test.dart \
  test/api_contract/no_legacy_public_symbols_test.dart \
  test/api_contract/public_api_v1_compiles_as_written_test.dart \
  test/api_contract/no_undefined_public_type_references_test.dart \
  test/api_contract/app_next_engine_adapter_compile_fixture_test.dart \
  test/api_contract/dto_immutability_test.dart \
  test/api_contract/public_equality_policy_test.dart \
  test/api_contract/public_readable_union_variants_test.dart \
  test/api_contract/public_signature_shape_test.dart \
  test/api_contract/id_validation_no_extension_type_escape_test.dart
```

Expected signal: exits 0. If any listed file is missing, the proof fails.

### P4a. Public API Draft Slice Tests

This proves only the Slice 2 public API draft surface: export parity, public
type closure, legacy public symbol rejection, public API compile proof, and
undefined public type rejection.

```sh
dart test \
  test/api_contract/public_exports_complete_test.dart \
  test/api_contract/public_types_complete_test.dart \
  test/api_contract/no_legacy_public_symbols_test.dart \
  test/api_contract/public_api_v1_compiles_as_written_test.dart \
  test/api_contract/no_undefined_public_type_references_test.dart
```

Expected signal: exits 0. If any listed Slice 2 file is missing, the proof
fails.

### P4b. API Id Validation Slice Test

This proves only the Slice 3 API id validation guard: ids cannot bypass
validation through public extension types or unchecked public construction.

```sh
dart test test/api_contract/id_validation_no_extension_type_escape_test.dart
```

Expected signal: exits 0. If the listed Slice 3 file is missing, the proof
fails.

### P4c. External Adapter Slice Test

This proves only the Slice 4 external adapter compile fixture and import
directive check.

```sh
dart test test/api_contract/app_next_engine_adapter_compile_fixture_test.dart
```

Expected signal: exits 0. If the listed Slice 4 file is missing, the proof
fails.

### P4d. Public Shape Slice Tests

This proves only the Slice 5 public shape tests for DTO immutability, equality,
readable public unions, and signature shape.

```sh
dart test \
  test/api_contract/dto_immutability_test.dart \
  test/api_contract/public_equality_policy_test.dart \
  test/api_contract/public_readable_union_variants_test.dart \
  test/api_contract/public_signature_shape_test.dart
```

Expected signal: exits 0. If any listed Slice 5 file is missing, the proof
fails.

### P5. Guardrail Suite

This proves the executable guardrail inventory and runner tests cover the P1
guardrail set.

```sh
dart test test/guardrails/blocking_suite_test.dart
```

Expected signal: exits 0.

### P6. Blocking Guardrail Runner

This proves every required P1 guardrail id is registered, dispatched, executable,
and reports no violations.

```sh
for guardrail in \
  api.integration_surface_complete \
  api.no_legacy_public_types \
  api.public_exports_complete \
  api.public_types_complete \
  api.public_api_compiles_as_written \
  api.no_undefined_public_type_references \
  api.dto_immutability \
  api.equality_policy_explicit \
  api.id_validation_no_extension_type_escape \
  codec.known_fields_validated \
  core.no_legacy_imports \
  core.no_scene_controller_shape_dependency \
  core.no_node_spec_patch_shape_dependency
do
  dart run tool/guardrails/run.dart --guardrail="$guardrail"
done
```

Expected signal: exits 0 for every listed guardrail id. If any id is missing
from the registry, missing from dispatch, or reports a violation, the proof
fails.

### P7. Scope Closure Search

This proves no temporary P1 scope-review marker remains unresolved in active
source-of-truth files after implementation.

```sh
rg -n "P1_SCOPE_GA[P]|P1_TOD[O]|P1_REVIEW_PENDIN[G]" PLAN.md plan docs lib test tool
```

Expected signal: exits 1 with no matches.

### P8. Codec Validation Tests

This proves constructor and schema validation limits by running the required P1
codec validation test file directly.

```sh
dart test test/codec/constructor_and_schema_limits_test.dart
```

Expected signal: exits 0. If the listed file is missing, the proof fails.

### P9. Documentation Structure Check

This proves documentation registries, navigation, and diagram catalog references
remain structurally consistent after any P1 source-of-truth or diagram
alignment.

```sh
dart run docs/tool/check_docs.dart
```

Expected signal: exits 0.

### P10. Scope Checklist Closure

This proves the P1 scope checklist result in this step contract has all four
required source categories checked after implementation.

```sh
awk -F'|' '
  $2 ~ /Approved v1 additions|Accepted legacy differences|Legacy capability inventory review|Donor registry review/ {
    gsub(/[[:space:]]/, "", $3);
    if ($3 == "[x]") checked++;
  }
  END { exit checked == 4 ? 0 : 1 }
' plan/step_21_v1_scope_gate_before_public_api_freeze.md
```

Expected signal: exits 0.

## 6. Vertical Slices

### Slice 1. [x] Close Scope Inputs

#### Implements

D1

#### Files

- Scope checklist result:
  `plan/step_21_v1_scope_gate_before_public_api_freeze.md` — update the
  checklist table below from `[ ]` to `[x]` only when the corresponding existing
  owner has been reviewed and any gap has been disposed in an allowed owner.
- Scope evidence: `docs/architecture/00_architecture_overview.md` — verify
  mandatory v1 additions and legacy bans before API draft proof.
- Accepted-difference evidence:
  `docs/architecture/04_decisions_and_differences.md` — verify every scope gap
  disposition has an existing accepted-difference owner when it is not v1 scope.
- Legacy inventory evidence:
  `docs/verification/legacy_capability_inventory.md` — verify legacy capability
  rows are used as scope input only.
- Donor evidence: `docs/_registry/donors.yaml` — verify P1 donor decisions and
  forbidden donor shells.
- Donor rule evidence: `docs/donors/00_reuse_rules.md` and
  `docs/donors/08_p1_closure_requirements.md` — verify donor review closure
  rules.
- Diagram evidence: `docs/diagrams/c4_container.mmd`,
  `docs/diagrams/c4_context.mmd`,
  `docs/diagrams/dfd_diagnostics_error_projection.mmd`,
  `docs/diagrams/dfd_public_edit.mmd`, and `docs/diagrams/README.md` — read as
  P1 inputs and update only when implementation changes their represented
  boundary or flow.
- Conditional source-of-truth alignment:
  `docs/architecture/00_architecture_overview.md`,
  `docs/architecture/04_decisions_and_differences.md`,
  `docs/_registry/donors.yaml`, `docs/verification/tests.md`,
  `docs/verification/guardrails.md`, `docs/indexes/by_guardrail.md`, and
  `docs/indexes/by_test_area.md` — edit only if review finds a concrete P1 gap
  that belongs to the existing owner.
- Conditional diagram alignment: `docs/diagrams/c4_container.mmd`,
  `docs/diagrams/c4_context.mmd`,
  `docs/diagrams/dfd_diagnostics_error_projection.mmd`, and
  `docs/diagrams/dfd_public_edit.mmd` — conditional diagram alignment targets
  only when P1 implementation changes their represented public API,
  validation/diagnostics, or public-edit flow.

#### Change

Review mandatory v1 additions, accepted differences, legacy capability rows,
and donor registry requirements before public API freeze. Any gap must be
disposed in its existing owner as v1 scope, accepted difference, donor metadata,
or a later owning phase/test before later slices close.

Scope checklist result:

| Source category | Closed | Existing owner |
|---|---|---|
| Approved v1 additions | [x] | `docs/architecture/00_architecture_overview.md` |
| Accepted legacy differences | [x] | `docs/architecture/04_decisions_and_differences.md` |
| Legacy capability inventory review | [x] | `docs/verification/legacy_capability_inventory.md` |
| Donor registry review | [x] | `docs/_registry/donors.yaml` |

#### Proof

Run P7, P9, and P10 after all conditional source-of-truth or diagram alignment
is complete.

#### Closure

The scope review has no unresolved P1 marker, and no new parallel inventory or
markdown-only guardrail has been created. All four scope checklist rows in this
contract are checked.

### Slice 2. [x] Compile Public API Draft

#### Implements

D1

#### Obligations Covered

PUBLIC_API_CHANGE

#### Files

- Public barrel: `lib/iwb_canvas_engine.dart` — root export seam for package
  consumers.
- Public API declarations: `lib/src/api/*.dart` — compileable public draft
  declarations for registry names and contract signatures.
- Public registry evidence: `docs/_registry/public_api_v1.yaml` — locked
  verify-only exported-name inventory; if it has a real P1 scope gap,
  implementation stops for contract revision.
- API compile tests:
  proposed `test/api_contract/public_api_v1_compiles_as_written_test.dart` —
  public declaration compile proof.
- Undefined-reference tests:
  proposed `test/api_contract/no_undefined_public_type_references_test.dart` —
  prove the explicit `api.no_undefined_public_type_references` P1 guardrail.
- Existing public type closure test:
  `test/api_contract/public_types_complete_test.dart` — keep registry-resolved
  public signature closure green while the dedicated undefined-reference test is
  added.
- Existing export parity test: `test/api_contract/public_exports_complete_test.dart`
  — verify registry and root barrel stay synchronized.
- Existing legacy rejection test:
  `test/api_contract/no_legacy_public_symbols_test.dart` — verify Slice 2 public
  draft work does not re-export retired legacy public symbols.

#### Change

Fill the public API draft so every registry name is exported through the root
barrel, every public signature compiles, and every referenced public type is
either exported or approved by the public API contract.

#### Proof

Run P4a during the slice. Run P1 before closure if production declarations
changed.

#### Closure

The public API draft compiles through the root barrel, export parity remains
green, and undefined public type references are rejected by test coverage.

### Slice 3. [x] Adopt Validation Limits

#### Implements

D2

#### Obligations Covered

PUBLIC_API_CHANGE

#### Files

- Validation owner: existing `lib/src/api/canvas_ids.dart`,
  proposed `lib/src/api/canvas_contract_limits.dart`, and
  proposed `lib/src/api/canvas_value_validators.dart` — public id, metadata,
  DTO, and boundary validation responsibility.
- Public DTO declarations: `lib/src/api/canvas_document.dart`,
  `lib/src/api/canvas_element.dart`, `lib/src/api/canvas_element_update.dart`,
  `lib/src/api/canvas_resource.dart`, `lib/src/api/canvas_field_update.dart`,
  `lib/src/api/canvas_geometry.dart`, `lib/src/api/canvas_pointer.dart`,
  `lib/src/api/canvas_tools.dart`, `lib/src/api/canvas_diagnostics.dart`, and
  `lib/src/api/canvas_errors.dart` — apply constructor and exposure validation
  where these files own public values.
- Codec boundary files: existing `lib/src/api/canvas_codec.dart` and proposed
  `lib/src/codec/schema_v1_validation.dart` — schema/materialization validation
  responsibility only where P1 adds executable proof.
- Validation tests: proposed
  `test/codec/constructor_and_schema_limits_test.dart` — constructor and
  boundary limit coverage.
- ID validation test: proposed
  `test/api_contract/id_validation_no_extension_type_escape_test.dart` — public
  surface proof that ids cannot bypass validation through public extension types
  or unchecked public construction.
- Validation-limit test relation:
  `test/codec/constructor_and_schema_limits_test.dart` remains the constructor
  and schema limit proof for P8; the separate id-validation test is required
  because P1 also needs public API surface proof for extension-type escape.

#### Change

Introduce or complete shared limit validation and route public constructors and
P1 boundary materialization through it for ids, metadata, field updates,
geometry/transform admission, diagnostic bounds, and other validation limits
needed by the public draft.

#### Proof

Run P4b and P8. Run P1 before closure.

#### Closure

Invalid public construction and P1 boundary materialization paths fail before
public exposure or runtime mutation, and tests cover both accepted and rejected
limit cases.

### Slice 4. [x] Prove External Adapter Surface

#### Implements

D1

#### Obligations Covered

PUBLIC_API_CHANGE

#### Files

- App-adapter fixture:
  proposed `test/api_contract/fixtures/app_next_engine_adapter_compile_fixture.dart`
  — public-barrel-only consumer of the integration surface.
- Fixture test:
  proposed `test/api_contract/app_next_engine_adapter_compile_fixture_test.dart`
  — compile proof and import-directive check.
- Public runtime API: `lib/src/api/canvas_runtime.dart` — expose only the public
  lifecycle, state/document observation, and edit/load surface required by the
  fixture.
- Public surface API: `lib/src/api/canvas_surface.dart` — expose only the
  `CanvasSurface` construction surface required by the fixture.
- Public document API: `lib/src/api/canvas_document.dart` — expose only
  document/state DTOs required by fixture observation and load/edit signatures.
- Public edit/update API: `lib/src/api/canvas_element.dart`,
  `lib/src/api/canvas_element_update.dart`, and
  `lib/src/api/canvas_field_update.dart` — expose only element/update values
  required by public edit/load fixture calls.
- Public resource API: `lib/src/api/canvas_resource.dart` — expose only
  resolver/style/resource inputs required by the fixture.
- Public command/action API: `lib/src/api/canvas_actions.dart`,
  `lib/src/api/canvas_tools.dart`, `lib/src/api/canvas_pointer.dart`, and
  `lib/src/api/canvas_preview.dart` — expose only selection/camera/tools,
  high-level commands, action/context-action request, and preview values
  required by the fixture.
- Public support API: `lib/src/api/canvas_ids.dart`,
  `lib/src/api/canvas_geometry.dart`, `lib/src/api/canvas_diagnostics.dart`,
  `lib/src/api/canvas_errors.dart`, and `lib/src/api/canvas_codec.dart` —
  expose only ids, geometry, diagnostics, errors, and codec names needed by the
  fixture's public signatures.

#### Change

Add a compile fixture that represents an application-owned adapter and imports
only `package:iwb_canvas_engine/iwb_canvas_engine.dart`. The fixture must
exercise the external operation families named by the public API contract
without importing `src/**`, legacy symbols, or internal runtime classes.

#### Proof

Run P4c and P1.

#### Closure

The fixture compiles as an external consumer, and its import check proves the
root public barrel is the only package seam it uses.

### Slice 5. [x] Harden Public Shape Guardrails

#### Implements

D1, D2

#### Obligations Covered

PUBLIC_API_CHANGE

#### Files

- Guardrail registry: `tool/guardrails/src/guardrail_registry.dart` — add P1
  executable guardrail ids and suite membership.
- Guardrail dispatch: `tool/guardrails/src/guardrail_executor.dart` — route
  every new P1 guardrail id from the registry to its executable check so the
  runner cannot fail with `Unknown guardrail`.
- Guardrail checks: `tool/guardrails/src/public_api_checks.dart`,
  `tool/guardrails/src/public_api_surface.dart`,
  `tool/guardrails/src/public_api_type_references.dart`, and proposed
  `tool/guardrails/src/public_api_contract_checks.dart` when extraction is
  needed to keep contract-specific checks cohesive — enforce P1 public shape and
  validation guardrails through reusable structural checks.
- Guardrail tests: `test/guardrails/blocking_suite_test.dart` — verify runner
  inventory, positive paths, and negative structural recognition.
- Legacy fixture: `test/api_contract/fixtures/legacy_public_symbol_exports.dart`
  — existing negative proof for retired legacy exports.
- Private-supertype fixture:
  `test/api_contract/fixtures/private_supertypes.dart` — existing negative
  proof for private inherited public surfaces.
- Public type violation fixture:
  `test/api_contract/fixtures/public_type_reference_violations.dart` — existing
  negative proof for hidden bounds and named public extension rejection.
- Public hidden-bound fixture:
  `test/api_contract/fixtures/public_type_reference_hidden_bound.dart` —
  existing support fixture for public type reference checks.
- API contract tests:
  proposed `test/api_contract/dto_immutability_test.dart`,
  proposed `test/api_contract/public_equality_policy_test.dart`,
  proposed `test/api_contract/public_readable_union_variants_test.dart`,
  proposed `test/api_contract/public_signature_shape_test.dart`,
  existing `test/api_contract/public_exports_complete_test.dart`,
  and existing `test/api_contract/public_types_complete_test.dart` — prove
  immutable DTO exposure, equality policy, readable public union variants,
  public signature shape, export parity, and public type closure.

#### Change

Complete executable guardrail coverage for P1 public shape: integration surface
complete, public API compiles as written, no undefined public type references,
DTO immutability, explicit equality policy, id validation without extension
type escape, known-field validation, no legacy public types, and the P0 core
legacy-ban checks that P1 depends on.

#### Proof

Run P4d, P5, and P6.

#### Closure

P1 guardrail ids are executable through tests and the runner, positive public
surfaces pass, and negative fixtures catch legacy or invalid public shapes.

### Slice 6. [x] Finalize P1 Gate

#### Implements

D1, D2

#### Obligations Covered

PUBLIC_API_CHANGE

#### Files

- Plan index: `PLAN.md` — mark Step 21 complete only after final proof passes.
- Step contract: `plan/step_21_v1_scope_gate_before_public_api_freeze.md` —
  mark all slice checkboxes complete only after matching slice proof has passed.
- Release/source-of-truth alignment:
  `docs/verification/release_gates.md`, `docs/verification/tests.md`,
  `docs/verification/guardrails.md`, `docs/indexes/by_guardrail.md`, and
  `docs/indexes/by_test_area.md` — final owner for any P1 check-name alignment
  required by implementation.
- Diagram alignment:
  `docs/diagrams/c4_container.mmd`, `docs/diagrams/c4_context.mmd`,
  `docs/diagrams/dfd_diagnostics_error_projection.mmd`,
  `docs/diagrams/dfd_public_edit.mmd`, and `docs/diagrams/README.md` — final
  owner for any P1 diagram alignment required by implementation.

#### Change

Run the complete proof set, fix any mismatches at the owning layer, and close
the P1 planning step only when public API, validation, external adapter,
legacy-ban, and guardrail proof are green.

#### Proof

Run P1, P2, P3, P4, P5, P6, P7, P8, P9, and P10.

#### Closure

All P1 exit gates pass, Step 21 is checked in both `PLAN.md` and this contract,
and P2 remains blocked only by its own public API freeze contract.

## 7. Final Gate

### Run Proof Set

P1, P2, P3, P4, P5, P6, P7, P8, P9, and P10.

### Done When

- all referenced Decision Ledger decisions have passing proof;
- all Contract Obligations are satisfied;
- P1 through P10 pass;
- D1 and D2 are proven by the referenced proof set;
- `PUBLIC_API_CHANGE` compatibility, registry handling, public seam proof, and
  validation proof are closed;
- all four P1 scope checklist rows in this contract are checked;
- `docs/_registry/public_api_v1.yaml` remained verify-only, or implementation
  stopped for a contract revision before changing registry membership;
- P1 diagram inputs were read, and any stale diagram was updated through its
  existing `docs/diagrams/**` owner;
- the P1 phase exit gate in
  `docs/implementation/p1_v1_scope_gate_before_public_api_freeze.md` is
  satisfied without copying its checklist into another source of truth;
- P2 public API freeze remains blocked until this P1 gate is green.
