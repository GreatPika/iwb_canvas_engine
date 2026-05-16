# Change Contract

If `4B. Architecture Decision Gate` is filled, stop after section 4.

## 1. Change Mandate

Replace the ambiguous public `CanvasOptional` update container with a
nullability-aware `CanvasFieldUpdate` API, close HOLE-005 before public API
freeze, and make field set/clear semantics mechanically provable.

## 2. Change Boundary

### Included in the Change

- Replace the public optional patch-field contract with
  `CanvasFieldUpdate<T>`, `CanvasFieldAbsent<T>`,
  `CanvasFieldSet<T extends Object>`, and
  `CanvasFieldClear<T extends Object> extends CanvasFieldUpdate<T?>`.
- Update every public element update DTO to use `CanvasFieldUpdate`.
- Preserve tri-state update semantics: absent means no change, set means set to
  a non-null value, and clear means set a nullable field to null.
- Make `CanvasFieldSet(null)` and clear-on-non-nullable-field invalid through
  Dart static typing for ordinary public API consumers.
- Keep boundary/runtime validation for dynamic, generated, schema, and other
  non-statically-typed construction paths.
- Update public API equality policy, export registry, phase mapping,
  verification mapping, audit, and redesign notes so `CanvasFieldUpdate` is the
  only v1 patch-field surface.
- After implementation proof is green, delete the completed HOLE-005 section
  from `audit.md` and delete the corresponding implemented redesign item from
  `redesign.md`; do not leave stale completed roadmap prose in either file.
- Add executable positive and negative proof for nullable and non-nullable
  field update semantics.

### Not Included in the Change

- No legacy API compatibility alias named `CanvasOptional`.
- No legacy `PatchField`, `NodePatch`, or `NodeSpec` public shape.
- No broad edit-kernel behavior beyond adopting the new field update container
  where element update compilation needs it.
- No schema v1 field-name change unless schema DTO materialization directly
  depends on the retired public type name.
- No unrelated DTO defensive-copy, metadata, collection, or `const`
  policy changes from HOLE-006.
- No operation matrix expansion unrelated to nullable field update behavior.

## 3. Surrounding Code Review

### Inspected Artifacts

- `audit.md` - lists HOLE-005 as an API-freeze blocker and requires one
  unambiguous rule for `CanvasOptional.value(null)`, update compiler behavior,
  and tests for nullable/non-nullable field update semantics.
- `redesign.md` - proposes replacing `CanvasOptional` with
  `CanvasFieldUpdate`, but its sample still relies on runtime rejection for
  `CanvasFieldSet(null)`.
- `docs/contracts/public_api_v1.md` - currently makes `CanvasOptional` public,
  includes it in value equality, and uses it for every `CanvasElementUpdate`
  field.
- `docs/_registry/public_api_v1.yaml` - currently lists `CanvasOptional` as a
  public API name and does not list the `CanvasFieldUpdate` family.
- `docs/implementation/p2_public_api_v1_freeze.md` - requires
  `CanvasOptional` implementation and maps the
  `foundation_tri_state_patch_semantics` donor to `CanvasOptional update
  semantics`.
- `docs/_registry/donors.yaml` - allows only semantic reuse from
  `foundation_tri_state_patch_semantics` and explicitly forbids copying the
  legacy `PatchField` name or `NodePatch` public API.
- `docs/verification/tests.md` - owns public API and edit proof paths,
  including API contract compilation, no undefined public type references,
  public equality policy, typed action payloads, and edit/update tests.
- `docs/verification/guardrails.md` - owns the public API guardrails that must
  remain green: public exports, public types, compile-as-written, signature
  shape, equality policy, DTO immutability, and no legacy patch-shape
  dependency.
- `docs/architecture/02_package_boundaries.md` - places public API files under
  `lib/src/api/**` and names `canvas_element_update.dart` as the API file for
  update DTOs.
- `docs/contracts/validation_limits.md` - requires validation at public DTO
  construction, edit/update construction, edit preflight, schema decode, and
  load materialization boundaries.
- `legacy/iwb_canvas_engine/lib/src/contract/patch_field.dart` - shows the
  donor tri-state wrapper and canonicalizes `PatchField.value(null)` to
  `nullValue`, which is the behavior this step rejects for the new public API.
- `legacy/iwb_canvas_engine/lib/src/contract/node_patch.dart` - shows the
  legacy consumer shape for common and family patch fields, including nullable
  fields such as image `naturalSize` and text `fontFamily`.
- `PLAN.md` - is the active roadmap index and requires each step to have a
  linked `plan/step_<number>_<short_snake_case_summary>.md` contract.

### Current Entry Path

- Public construction entry: callers construct `CanvasElementUpdate` family DTOs
  through `package:iwb_canvas_engine/iwb_canvas_engine.dart`.
- Public mutation entry: callers pass those DTOs to
  `CanvasEdit.updateElement(CanvasElementUpdate update)` or equivalent public
  edit command paths.
- Boundary entry: schema decode, generated fixtures, dynamic calls, and tests
  may materialize updates without ordinary static guarantees.

### Current Owner

- The public field update type is owned by the root public API layer under
  `lib/src/api/**`.
- Element update DTOs are owned by `lib/src/api/canvas_element_update.dart`.
- The edit/update compiler owns applying already-constructed field updates to
  draft state and must keep non-statically-typed invalid clear requests from
  mutating drafts.
- `docs/contracts/public_api_v1.md` owns the normative public API behavior.

### Adjacent Abstractions

- `CanvasElementUpdate` and its concrete family update classes are the adjacent
  public DTO consumers.
- `CanvasElementRead` and creation DTOs are adjacent public element DTOs but
  are not patch/update containers.
- `CanvasEdit.updateElement` is the public edit entry that consumes update DTOs.
- Public API contract tests and public equality policy tests are the adjacent
  proof layer.

### Existing Tests

- No repository-root `test/**` files exist yet; the current tree is still before
  the P0 package skeleton implementation.
- `docs/verification/tests.md` lists future required API contract tests for
  public API compilation, undefined public type references, DTO immutability,
  public equality policy, and edit/update behavior.
- `docs/indexes/by_test_area.md` maps the planned public API contract tests to
  the public API contract and guardrail sections.
- This step must create or update the concrete test files named in section 8
  rather than treating planned documentation entries as already-present tests.

### Analogous Implementation Path

- `legacy/iwb_canvas_engine/lib/src/contract/patch_field.dart` is the closest
  semantic donor for absent/value/nullValue tri-state behavior.
- `legacy/iwb_canvas_engine/lib/src/contract/node_patch.dart` is the closest
  consumer precedent for common and family update fields.
- `docs/contracts/public_api_v1.md` is the valid new API precedent because it
  already rejects the legacy `PatchField` name and owns the v1 public surface.

### Governing Repository Rules

- `AGENTS.md` - documentation is written in English, repository-specific rules
  must be updated in source-of-truth files, and recurring constraints should be
  mechanically enforced.
- `docs/README.md` - implementation starts from phase files, while root
  `plan/` contains workspace-level Change Contracts and audit trails.
- `docs/architecture/00_architecture_overview.md` - the new package is not
  API-compatible with legacy and must not expose legacy `NodeSpec`,
  `NodePatch`, or `PatchField` shape.
- `docs/architecture/02_package_boundaries.md` - public API declarations live
  under `lib/src/api/**`; public barrel exports only API-owned files.
- `docs/verification/guardrails.md` - public API names, signatures, equality,
  DTO immutability, and no legacy patch-shape dependency are blocking
  guardrails.
- `docs/_registry/donors.yaml` - `foundation_tri_state_patch_semantics` may be
  copied/adapted for semantics only, not for public names or structure.

### Rejected Misleading Local Patterns

- `CanvasOptional.value(null)` in the current contract - rejected because it
  keeps the ambiguous construction path that HOLE-005 exists to close.
- `CanvasOptional.nullValue()` with constructor-level nullable admission -
  rejected as the final public shape because ordinary consumers should get
  static feedback for non-nullable clear attempts.
- Legacy `PatchField.value(null)` canonicalization - rejected because silently
  mapping null set to clear hides caller intent and preserves ambiguity.
- Legacy `PatchFieldState` enum - rejected because the public v1 API already
  uses sealed public variants for readable unions and should keep variant data
  explicit.
- A compatibility alias `typedef CanvasOptional = CanvasFieldUpdate` - rejected
  because it preserves the misleading optional name and risks two public sources
  of truth for one update concept.
- Per-field bespoke `clearX` booleans or nullable value parameters - rejected
  because they duplicate tri-state state across call sites and make update DTOs
  harder to validate uniformly.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- The problem is owned at the public API DTO boundary, with a secondary
  safeguard at edit/update compilation for non-statically-typed inputs.
- It is not owned by individual update call sites, render code, schema codecs,
  or family-specific application branches.

#### Selected Architectural Form

- Introduce a public sealed `CanvasFieldUpdate<T>` union for field update
  intent.
- Use public concrete variants:
  - `CanvasFieldAbsent<T> extends CanvasFieldUpdate<T>`;
  - `CanvasFieldSet<T extends Object> extends CanvasFieldUpdate<T>`;
  - `CanvasFieldClear<T extends Object> extends CanvasFieldUpdate<T?>`.
- Keep an absent factory on the base type for ergonomic default values:
  `const factory CanvasFieldUpdate.absent() = CanvasFieldAbsent<T>`.
- Update element update DTO fields from `CanvasOptional<T>` to
  `CanvasFieldUpdate<T>`.
- Treat `CanvasFieldSet` as non-null set only; clearing a nullable field uses
  `CanvasFieldClear<FieldNonNullableType>()`.
- Retire `CanvasOptional` from the public API registry, public equality list,
  examples, phase text, audit item, and redesign notes.

#### Owning Layer or Module

- Public field update union: `lib/src/api/canvas_field_update.dart`.
- Public element update DTOs: `lib/src/api/canvas_element_update.dart`.
- Public barrel export: `lib/iwb_canvas_engine.dart`.
- Edit/update application owner: `lib/src/edit/commit_compiler.dart`.
- Field update application helpers, if needed to keep the compiler cohesive:
  `lib/src/edit/field_update_application.dart`.
- Normative behavior: `docs/contracts/public_api_v1.md`.

#### Dependency Direction

- API DTOs may define field update intent but must not depend on store, edit,
  frame, interaction, resource, codec, diagnostics, spatial, geometry, runtime,
  Flutter bridge, or legacy code.
- Edit/update compilation depends on public update DTOs and draft/store
  internals, not the reverse.
- Codec and load materialization may create public update DTOs only through the
  same validated public or boundary constructors.
- Tests may use analyzer or temporary consumer fixtures to prove static invalid
  forms fail without adding invalid code to production sources.

#### State and Data Ownership

- `CanvasFieldUpdate` stores only per-field update intent, never committed
  document state.
- `CanvasFieldSet` owns exactly one non-null replacement value.
- `CanvasFieldClear` owns no value and represents null assignment only for a
  nullable field type.
- Element update DTOs own the collection of field intents for one element
  update request.
- Draft state changes remain owned by edit/update compilation and application.

#### Entry and Exit Boundaries

- Entry boundary for ordinary callers: constructing update DTOs through the
  public barrel.
- Entry boundary for generated or dynamic callers: public constructors and edit
  preflight must reject invalid field update states before draft mutation.
- Exit boundary for no-op updates: no element revision change, no action, and
  no touched invalidation.
- Exit boundary for changed updates: element revision and typed touched effects
  follow the existing update semantics in `docs/contracts/public_api_v1.md`.

#### Permitted Extension Seam

- New updateable public fields may use `CanvasFieldUpdate<T>` with
  `CanvasFieldUpdate.absent()` defaults.
- New nullable updateable public fields may accept `CanvasFieldClear<BaseType>`
  because that variant is assignable to `CanvasFieldUpdate<BaseType?>`.
- Dynamic or generated update admission may add centralized helper functions
  only in `lib/src/edit/commit_compiler.dart` or
  `lib/src/edit/field_update_application.dart`, and those helpers must not
  recreate a second public update container.

#### Rejected Alternatives

- Keep `CanvasOptional` and throw from `value(null)` - rejected because the
  public type name still describes optional data rather than field update
  intent, and the best available static guarantee remains unused.
- Keep `CanvasOptional` and canonicalize `value(null)` to `nullValue` -
  rejected because it repeats the legacy donor ambiguity and hides caller
  intent.
- Use `CanvasFieldSet(this.value)` with runtime `value == null` guard only -
  rejected because `T extends Object` can make null set invalid statically.
- Make `CanvasFieldClear<T>` extend `CanvasFieldUpdate<T>` - rejected because
  it permits clear variants to be assigned to non-nullable update fields.
- Add per-field `bool clearX` flags - rejected because it splits one field's
  intent across multiple properties and makes no-op/change detection fragile.

#### Why This Level Is Correct

- HOLE-005 is a public API freeze blocker, so the public DTO type must express
  the intended semantics before downstream runtime phases consume it.
- Encoding set and clear nullability in the update union solves the defect once
  at the boundary instead of requiring every family-specific update compiler
  branch to rediscover it.
- Edit/update compilation still needs a defensive boundary because codecs,
  generated fixtures, tests, and dynamic calls can bypass ordinary static
  feedback.

### 4B. Architecture Decision Gate

## 5. Locked Decisions

1. `CanvasOptional` is retired from public v1 instead of preserved as an alias
   or renamed wrapper.
2. The successor public seam is `CanvasFieldUpdate`.
3. `CanvasFieldSet<T extends Object>` is the only set variant and can never
   represent null.
4. `CanvasFieldClear<T extends Object>` extends `CanvasFieldUpdate<T?>`, so it
   is assignable only to nullable field updates.
5. `CanvasFieldAbsent<T>` remains assignable to any `CanvasFieldUpdate<T>`.
6. `CanvasFieldUpdate.absent()` is the canonical default constructor used by
   public update DTOs.
7. `CanvasFieldClear` for a non-nullable field must be a static error in
   ordinary public API usage and a validation error before draft mutation for
   dynamic or generated boundary usage.
8. Public value equality covers `CanvasFieldUpdate` and its variants.
9. No implementation may copy the legacy `PatchField` name, `PatchFieldState`
   enum, `NodePatch` public shape, or null canonicalization behavior.

## 6. Result Requirements

1. Public API readers see field update intent as update intent, not optional
   value storage.
2. There is no public construction path where setting a field to null is
   indistinguishable from clearing a nullable field.
3. Nullable field clearing is explicit and available only through
   `CanvasFieldClear`.
4. Non-nullable public update fields cannot accept `CanvasFieldClear` in
   ordinary statically checked code.
5. Dynamic or generated invalid update requests are rejected before draft
   mutation and before any action, revision, touched-set, resource, repaint, or
   event effect.
6. Public API registry, contract prose, examples, equality policy, phase text,
   donor registry, verification mappings, and indexes all name the same
   successor seam.
7. `audit.md` no longer contains HOLE-005 after the implementation proof is
   green.
8. `redesign.md` no longer contains the implemented
   `CanvasOptional`/`CanvasFieldUpdate` redesign item after the implementation
   proof is green.
9. Existing API guardrails remain the proof mechanism for public exports,
   public signatures, equality, DTO immutability, no undefined public types, and
   no legacy patch-shape dependency.

## 7. Execution Order and Gates

### Required Order

- First update the public contract, registry, phase text, audit, redesign notes,
  and verification mappings so the successor seam is the only documented v1
  target.
- Add failing API contract and analyzer-based negative tests for the successor
  shape before implementing the production public types.
- Implement `CanvasFieldUpdate` and migrate public update DTOs only after the
  static nullability proof and neighboring guard snippets exist.
- Add or update edit/update compiler tests before adopting the new field update
  variants in edit application code.
- Migrate all in-scope consumers from `CanvasOptional` to `CanvasFieldUpdate`.
- Retire `CanvasOptional` only after public contract examples, registry,
  tests, and production references have moved.
- Run broad Dart and DCM verification only at the final gate for this step.

### Successor Seam and Retirement Gates

- Successor seam: `CanvasFieldUpdate<T>` and its public variants under
  `lib/src/api/**`.
- Consumer migration order: public contract and registry, API contract tests,
  public DTO implementation, edit/update compiler, and then audit/redesign
  retirement.
- Retirement gate: `rg -n "CanvasOptional|nullValue\\(|_CanvasOptional|PatchFieldState|PatchField<|NodePatch" lib test docs/contracts docs/implementation docs/verification docs/indexes docs/_registry audit.md redesign.md` must show no active new-engine public API dependency except legacy donor references and intentional negative-search commands in the step record.
- Registry gate: `docs/_registry/public_api_v1.yaml` lists
  `CanvasFieldUpdate`, `CanvasFieldAbsent`, `CanvasFieldSet`, and
  `CanvasFieldClear`, and no longer lists `CanvasOptional`.
- Donor gate: `docs/_registry/donors.yaml` and
  `docs/indexes/donor_to_phase.md` name the target owner as
  `CanvasFieldUpdate update semantics` while still preserving the donor rule
  that only tri-state semantics, not legacy public names, may be reused.
- Audit/redesign gate: after implementation proof is green, the HOLE-005
  section is deleted from `audit.md` and the corresponding implemented
  `CanvasOptional`/`CanvasFieldUpdate` redesign item is deleted from
  `redesign.md`.

### Deferred Broad Verification

- `dart analyze` is reserved for the final gate after implementation and test
  migration.
- `dcm analyze .` is reserved for the final gate after implementation and test
  migration.
- `dcm calculate-metrics .` is reserved for the final gate after
  implementation and test migration.

## 8. File Map

### Implementation Files

- `lib/iwb_canvas_engine.dart`
- `lib/src/api/canvas_field_update.dart`
- `lib/src/api/canvas_element_update.dart`
- `lib/src/edit/commit_compiler.dart`
- `lib/src/edit/field_update_application.dart`

### Test Files

- `test/api/canvas_field_update_test.dart`
- `test/api_contract/public_api_v1_compiles_as_written_test.dart`
- `test/api_contract/no_undefined_public_type_references_test.dart`
- `test/api_contract/no_legacy_public_symbols_test.dart`
- `test/api_contract/public_equality_policy_test.dart`
- `test/api_contract/dto_immutability_test.dart`
- `test/api_contract/canvas_field_update_static_semantics_test.dart`
- `test/edit/field_update_nullable_semantics_test.dart`
- `test/edit/operation_matrix_effects_test.dart`
- `test/edit/exact_touched_invalidation_test.dart`
- `test/edit/typed_effects_no_frame_dependency_test.dart`

### Fixtures and Supporting Data

- Temporary analyzer or compile fixtures created by
  `test/api_contract/canvas_field_update_static_semantics_test.dart`.

### Registry, Inventory, and Workflow Files

- `PLAN.md`
- `plan/step_3_canvas_field_update_patch_semantics.md`
- `audit.md`
- `redesign.md`
- `docs/contracts/public_api_v1.md`
- `docs/contracts/validation_limits.md`
- `docs/implementation/p2_public_api_v1_freeze.md`
- `docs/_registry/donors.yaml`
- `docs/_registry/public_api_v1.yaml`
- `docs/_registry/sections.yaml`
- `docs/verification/tests.md`
- `docs/verification/guardrails.md`
- `docs/verification/release_gates.md`
- `docs/indexes/by_test_area.md`
- `docs/indexes/by_guardrail.md`
- `docs/indexes/donor_to_phase.md`

### Analysis Area

- Public export and public signature analysis for `lib/iwb_canvas_engine.dart`
  and `lib/src/api/**`.
- Analyzer-based negative fixtures for invalid null set and invalid clear on
  non-nullable fields.
- Edit/update compiler rejection paths for dynamic or generated invalid field
  updates.

## 9. Implementation Rules

### Protected Invariants

- Field set and field clear are distinct public intents.
- A set variant never carries null.
- A clear variant is assignable only to nullable field updates in ordinary
  static usage.
- Invalid update requests never mutate draft state and never emit actions,
  revisions, touched sets, resource effects, repaints, diagnostics with secrets,
  or user events.
- Public API code does not import legacy code or copy legacy patch public
  names.
- The public API registry is the machine-readable source for exported public
  names.

### Required Proof

- behavioral proof: valid absent, set, and clear variants compare according to
  the public equality policy and drive nullable field update behavior correctly.
- structural proof: invalid `CanvasFieldSet(null)` and clear-on-non-nullable
  public update usage fail in analyzer or compile fixtures.
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard
  tests for neighboring branches of the same contract.
- for refactors: existing locking tests must be named or missing
  characterization tests must be added before structural edits, plus 1 to 3
  guard tests for neighboring branches when needed.

### Allowed Change Surface

- Public API field update union and element update DTOs.
- Public API contract, registry, phase, audit, redesign, verification, guardrail,
  release-gate, and index documents needed to make the successor seam the
  source of truth.
- Edit/update compiler code that consumes public update DTOs.
- Tests and analyzer fixtures that prove the successor seam.

### Forbidden Moves

- Do not preserve `CanvasOptional` as a public alias.
- Do not expose `PatchField`, `PatchFieldState`, `NodePatch`, or `NodeSpec`
  through the new public API.
- Do not canonicalize null set into clear.
- Do not add per-field clear booleans.
- Do not move update semantics into render, frame, interaction, or family
  paint code.
- Do not weaken public signature, equality, immutability, or no-legacy
  guardrails to make the migration easier.

### Optional: Recognition Forms That Must Be Supported

- `const CanvasFieldUpdate.absent()`
- `const CanvasFieldAbsent<T>()`
- `CanvasFieldSet(value)` where `value` is statically non-null.
- `const CanvasFieldClear<T>()` assigned to `CanvasFieldUpdate<T?>`.
- Exhaustive pattern matching over `CanvasFieldUpdate`.

### Optional: Allowed Forms That Are Not Violations

- A boundary helper that rejects invalid dynamic field update states before
  draft mutation.
- Test-only source snippets that intentionally fail analyzer checks to prove
  invalid public usage.
- Legacy donor references under `legacy/**` and donor registry references that
  explain semantic provenance without copying public names.

### Optional: Resolution Rules

- For any updateable nullable field of type `T?`, use
  `CanvasFieldUpdate<T?>` as the field type and `CanvasFieldClear<T>()` as the
  clear request.
- For any updateable non-nullable field of type `T`, use
  `CanvasFieldUpdate<T>` as the field type; a clear request is invalid.
- For any public set request, use `CanvasFieldSet<T>` with `T extends Object`.
- If static typing and runtime validation disagree, runtime validation must be
  stricter and reject before draft mutation.

## 10. Vertical Slices

### Slice 1. [ ] Public Contract And Registry

#### Slice Contract

The documented public v1 field update seam is `CanvasFieldUpdate`, and
`CanvasOptional` is no longer a public v1 target.

#### Change

Update the public API contract, public API registry, P2 phase text, tests and
guardrail mappings, donor registry owner text, audit entry, redesign notes, and
related indexes to name `CanvasFieldUpdate` and its variants as the v1
successor seam.

#### Behavioral Verification

- `dart run docs/tool/check_docs.dart`

#### Structural Verification

- `rg -n "CanvasOptional|_CanvasOptional|CanvasOptional\\.value|CanvasOptional\\.nullValue" docs/contracts/public_api_v1.md docs/_registry/public_api_v1.yaml docs/_registry/donors.yaml docs/implementation/p2_public_api_v1_freeze.md docs/verification docs/indexes audit.md redesign.md`
  returns no active successor-seam references after retirement.
- `rg -n "CanvasFieldUpdate update semantics" docs/_registry/donors.yaml docs/indexes/donor_to_phase.md`
  returns the donor registry and generated donor index owner references.

#### Fixtures Used

- None.

#### Positive Scenarios

- Public contract examples show absent, set, and clear semantics through
  `CanvasFieldUpdate`.
- Registry lists the public successor variants.
- Donor registry and donor index keep semantic reuse mapped to the successor
  owner.

#### Negative Scenarios

- Public contract no longer teaches `CanvasOptional.value(null)`.
- P2 phase no longer asks implementers to build `CanvasOptional`.

#### Closure Evidence

- Documentation checker passes and the retirement search has only allowed
  historical or command-text matches.

### Slice 2. [ ] Static Nullability Proof

#### Slice Contract

Ordinary public API consumers receive static analyzer feedback for null set and
clear-on-non-nullable misuse before production API implementation changes land.

#### Change

Add analyzer or compile-fixture tests that include valid snippets and invalid
negative snippets for the `CanvasFieldUpdate` variants. The first run must fail
because the successor API does not exist or does not yet enforce the locked
nullability shape.

#### Behavioral Verification

- `dart test test/api_contract/canvas_field_update_static_semantics_test.dart`

#### Structural Verification

- `dart test test/api_contract/canvas_field_update_static_semantics_test.dart`
  must assert analyzer diagnostics for invalid snippets and no diagnostics for
  valid snippets.

#### Fixtures Used

- Temporary consumer snippets generated by the test.

#### Positive Scenarios

- `CanvasFieldSet(nonNullValue)` compiles.
- `CanvasFieldClear<Size>()` compiles when assigned to
  `CanvasFieldUpdate<Size?>`.
- Public update DTO examples with nullable clear compile.

#### Negative Scenarios

- `CanvasFieldSet(null)` fails analysis.
- `CanvasFieldClear<Size>()` assigned to `CanvasFieldUpdate<Size>` fails
  analysis.
- A non-nullable public update field cannot receive a clear variant.

#### Closure Evidence

- Static semantics test passes and its negative snippets prove the rejected
  forms.

### Slice 3. [ ] Public DTO Implementation

#### Slice Contract

The public package exports `CanvasFieldUpdate` and element update DTOs use it
for every updateable field.

#### Change

Implement the public sealed field update union, export it through the public
barrel, migrate `CanvasElementUpdate` and family update DTO fields to
`CanvasFieldUpdate`, and update equality/immutability support as required. Run
the static nullability proof from Slice 2 first in this slice and make the
production changes only after it fails for the expected successor-shape gap.

#### Behavioral Verification

- `dart test test/api/canvas_field_update_test.dart`
- `dart test test/api_contract/public_equality_policy_test.dart`
- `dart test test/api_contract/dto_immutability_test.dart`

#### Structural Verification

- `dart test test/api_contract/public_api_v1_compiles_as_written_test.dart`
- `dart test test/api_contract/no_undefined_public_type_references_test.dart`

#### Fixtures Used

- Public API compile fixture used by
  `test/api_contract/public_api_v1_compiles_as_written_test.dart`.

#### Positive Scenarios

- `CanvasFieldAbsent<T>` is assignable to any field update type.
- `CanvasFieldSet<T extends Object>` stores and compares non-null values.
- `CanvasFieldClear<T extends Object>` is assignable to
  `CanvasFieldUpdate<T?>`.

#### Negative Scenarios

- `CanvasOptional` is not exported from the public barrel.
- `PatchField` and `NodePatch` remain absent from the new public API.

#### Closure Evidence

- API contract, equality, immutability, and undefined-type tests pass.

### Slice 4. [ ] Edit Compiler Adoption

#### Slice Contract

Element update compilation consumes `CanvasFieldUpdate` and preserves no-op,
  nullable clear, changed-field, and invalid-boundary behavior before draft
  mutation.

#### Change

Migrate edit/update compiler or applier logic from the old optional container
to `CanvasFieldUpdate` in `lib/src/edit/commit_compiler.dart`, add any cohesive
field helper in `lib/src/edit/field_update_application.dart`, and keep typed
touched invalidation behavior unchanged.

#### Behavioral Verification

- `dart test test/edit/field_update_nullable_semantics_test.dart`
- `dart test test/edit/operation_matrix_effects_test.dart`
- `dart test test/edit/exact_touched_invalidation_test.dart`

#### Structural Verification

- `dart test test/api_contract/no_legacy_public_symbols_test.dart`
- `dart test test/edit/typed_effects_no_frame_dependency_test.dart`
- `rg -n "PatchField|PatchFieldState|NodePatch|NodeSpec" lib/src/api lib/src/edit`
  returns no active legacy patch-shape dependency.

#### Fixtures Used

- Edit fixtures that construct image, path, text, stroke, line, and rect update
  DTOs with absent, set, and nullable clear fields.

#### Positive Scenarios

- Absent fields produce no mutation.
- Set fields update to non-null values.
- Clear fields set nullable fields to null.
- Changed updates produce the same revision and typed touched effects required
  by the operation matrix.

#### Negative Scenarios

- Dynamic or generated clear requests for non-nullable fields throw before
  draft mutation.
- Invalid requests do not emit actions, revisions, touched effects, repaints,
  resource effects, or user events.

#### Closure Evidence

- Edit behavior tests, typed-effects structure test, no-legacy public symbol
  test, and legacy patch-shape search pass.

### Slice 5. [ ] Retirement And Final Gate

#### Slice Contract

The old public seam is fully retired, and the successor seam is protected by
the standard project checks.

#### Change

Remove remaining active `CanvasOptional` references from new-engine docs, code,
tests, registries, and indexes; delete the HOLE-005 section from `audit.md`;
delete the corresponding implemented `CanvasOptional`/`CanvasFieldUpdate`
redesign item from `redesign.md`; and mark this plan step complete in both
`PLAN.md` and this step file.

#### Behavioral Verification

- `dart test test/api_contract/public_api_v1_compiles_as_written_test.dart`
- `dart test test/api_contract/public_equality_policy_test.dart`
- `dart test test/api_contract/canvas_field_update_static_semantics_test.dart`
- `dart test test/edit/field_update_nullable_semantics_test.dart`

#### Structural Verification

- `dart run docs/tool/check_docs.dart`
- `rg -n "CanvasOptional|_CanvasOptional|CanvasOptional\\.value|CanvasOptional\\.nullValue" lib test docs/contracts docs/implementation docs/verification docs/indexes docs/_registry audit.md redesign.md`
- `rg -n "PatchField|PatchFieldState|NodePatch|NodeSpec" lib/src/api lib/src/edit`
- `git diff --check`

#### Fixtures Used

- Public API compile fixtures.
- Static analyzer negative fixtures.
- Edit update fixtures.

#### Positive Scenarios

- Public API exports only the successor update container.
- HOLE-005 is absent from `audit.md`.
- The implemented `CanvasOptional`/`CanvasFieldUpdate` item is absent from
  `redesign.md`.

#### Negative Scenarios

- No new-engine public API, test, registry, or contract file depends on
  `CanvasOptional`.
- No active new-engine code imports or exposes legacy patch-shape types.

#### Closure Evidence

- Documentation checks, API contract tests, retirement searches, and final
  quality checks pass.

## 11. Final Verification

- `dart run docs/tool/check_docs.dart`
- `dart test test/api/canvas_field_update_test.dart`
- `dart test test/api_contract/public_api_v1_compiles_as_written_test.dart`
- `dart test test/api_contract/no_undefined_public_type_references_test.dart`
- `dart test test/api_contract/public_equality_policy_test.dart`
- `dart test test/api_contract/dto_immutability_test.dart`
- `dart test test/api_contract/canvas_field_update_static_semantics_test.dart`
- `dart test test/edit/field_update_nullable_semantics_test.dart`
- `dart test test/edit/operation_matrix_effects_test.dart`
- `dart test test/edit/exact_touched_invalidation_test.dart`
- `dart test test/api_contract/no_legacy_public_symbols_test.dart`
- `dart test test/edit/typed_effects_no_frame_dependency_test.dart`
- `rg -n "CanvasOptional|_CanvasOptional|CanvasOptional\\.value|CanvasOptional\\.nullValue" lib test docs/contracts docs/implementation docs/verification docs/indexes docs/_registry audit.md redesign.md`
- `rg -n "PatchField|PatchFieldState|NodePatch|NodeSpec" lib/src/api lib/src/edit`
- `dart analyze`
- `dcm analyze .`
- `dcm calculate-metrics .`
- `git diff --check`

## 12. Acceptance Criteria

- `CanvasFieldUpdate`, `CanvasFieldAbsent`, `CanvasFieldSet`, and
  `CanvasFieldClear` are the only public v1 field update container names.
- `CanvasOptional` is not exported, documented as active public API, or used by
  new-engine update DTOs.
- `CanvasFieldSet(null)` is rejected by static proof for ordinary public usage.
- `CanvasFieldClear<T>()` is accepted for `CanvasFieldUpdate<T?>` and rejected
  for `CanvasFieldUpdate<T>` by static proof.
- Nullable field clear behavior is proven through edit/update behavior tests.
- Invalid dynamic or generated clear requests for non-nullable fields fail
  before draft mutation and produce no runtime effects.
- Public API registry, contract, P2 phase text, donor registry, verification
  mappings, and indexes agree on the successor seam.
- `audit.md` does not contain HOLE-005 after implementation proof is green.
- `redesign.md` does not contain the implemented
  `CanvasOptional`/`CanvasFieldUpdate` item after implementation proof is
  green.
- This step is marked complete in `PLAN.md` and in this contract only after all
  final verification commands pass.
