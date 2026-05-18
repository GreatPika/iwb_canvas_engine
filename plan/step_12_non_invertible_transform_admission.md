# Change Contract

Contract Mode: FULL
Contract Profile: SOURCE_OF_TRUTH_DOCS
Contract Obligations: BUG_FIX, PUBLIC_API_CHANGE

## 1. Mandate and Boundary

### Mandate

Resolve the non-invertible transform fallback redesign note by moving the
accepted decision into normative repository source-of-truth documents: element
transforms are admitted only when finite and invertible, all public and schema
entry paths reject non-invertible element transforms before state mutation, and
runtime hit-test treats an internally corrupted non-invertible row as a
diagnostic miss rather than accepting by coarse candidate bounds.

### In Scope

- Lock the public/document validation contract for element transform admission
  across public DTO construction, schema decode, edit update materialization and
  preflight, and `loadDocument` staging.
- Lock the hit-test contract so a non-invertible committed row is excluded from
  exact hit acceptance, records only policy-gated diagnostics, and never uses
  coarse candidate bounds as an acceptance fallback.
- Align the active hit-test sequence diagram, diagnostic wording, and
  verification documentation with the locked decision.
- Retire the resolved note from `redesign.md` only after the normative
  contracts and verification wording carry the decision.

### Out of Scope

- Dart production implementation, runtime store changes, validator
  implementation, or test file implementation.
- Changing the exported public `CanvasTransform` type shape or replacing it
  with an `InvertibleCanvasTransform` public type.
- Changing schema v1 field names, JSON object shape, or schema version.
- Changing the spatial query budget fallback in `section_17_spatial_kernel`;
  this step only removes the geometry acceptance fallback for non-invertible
  transforms.
- Running `dart analyze`, `dcm analyze .`, or `dcm calculate-metrics .`,
  because this step is documentation-only.

## 2. Evidence Map

### Baseline Evidence

These facts describe repository state before execution. They are evidence for
the change, not target-state requirements.

- `redesign.md` contains an unresolved note that says non-invertible transforms
  must be rejected at public DTO construction, decode, edit update, and
  `loadDocument`, and that corrupted runtime rows must emit diagnostics without
  coarse candidate fallback.
- `docs/contracts/public_api_v1.md` defines `CanvasTransform` with
  `isInvertible` and nullable `invert()`, lists `fieldMustBeInvertible`, and
  already states that element transforms must be invertible.
- `docs/contracts/validation_limits.md` applies validation at public DTO
  construction, edit/update construction, dynamic or generated
  `CanvasFieldUpdate` materialization, edit preflight, schema decode, and
  `loadDocument` materialization.
- `docs/contracts/schema_v1.md` describes `CanvasTransform` JSON as the six
  affine components with finite values and scale singular values in
  `[1e-4, 1e4]` when invertibility is needed.
- `docs/contracts/codec_boundary.md` says decode validates elements before
  materializing an immutable `CanvasDocument` DTO and performs no runtime/store
  side effects.
- `docs/contracts/load_document.md` says `loadDocument` validates and
  materializes before interrupting interaction or installing replacement state.
- `docs/contracts/geometry.md` currently says box/image/text/rect exact hit
  uses inverse transform but falls back to coarse candidate bounds when the
  transform is non-invertible.
- `docs/diagrams/seq_hit_test_candidate_resolution.mmd` repeats that family
  rules own non-invertible transform fallback to coarse candidate bounds where
  geometry allows it.
- `docs/contracts/diagnostics.md` forbids `DiagnosticRecord` allocation and
  detail-string interpolation on successful pointer and paint hot paths when
  diagnostics are disabled.
- `plan/step_11_operation_matrix_field_effect_taxonomy.md` explicitly left the
  non-invertible transform fallback note unresolved and forbade removing it in
  Step 11.

### Entry Paths

- Public element DTO constructors and family constructors expose
  `CanvasElement.transform`.
- `CanvasElementUpdate.transform` is the public edit update entry path for
  changed persisted element transforms.
- `decodeCanvasDocument` and `decodeCanvasDocumentFromJson` are the schema v1
  decode entry paths.
- `CanvasEditPort.loadDocument(document)` is the public external document
  replacement entry path.
- Pointer hit-test resolves committed candidate rows through
  `InteractionEngine`, `InteractionReadPort`, `DocumentStoreKernel`,
  `HitTestPolicy`, and `GeometryPolicy`.

### Current Owners

- `section_04_public_api_v1` owns public DTO shapes, public update field names,
  and public validation surface.
- `section_06_validation_limits` owns shared validation limits and validation
  boundary placement.
- `section_05_schema_v1_contract` and `section_19_codec_boundary` own schema v1
  decode/encode validation and DTO materialization.
- `section_12_load_document` owns staged external document replacement ordering.
- `section_16_geometry_policy` owns hit eligibility and exact geometry policy.
- `section_20_diagnostics_hub` owns diagnostics allocation, sanitization, and
  projection policy.
- `section_23_tests` owns the documented test responsibilities that future
  implementation must satisfy.

### Existing Checks

- `docs/README.md` defines `dart run docs/tool/generate_context_capsules.dart
  --check` and `dart run docs/tool/check_docs.dart` as structural documentation
  checks.
- `docs/tool/check_docs.dart` checks documentation entrypoints, registries,
  navigation links, diagram catalog membership, and phase/read-first
  references; it explicitly does not check free-form semantic wording.
- `docs/verification/tests.md` already names future tests that can carry this
  behavior: `test.codec.constructor_and_schema_limits`,
  `test.edit.field_update_nullable_semantics`,
  `test.edit.staged_document_load_success_failure`,
  `test.geometry.hit_policy`, and
  `test.diagnostics.sanitizer_and_public_projection`.

### Valid Precedents

- `docs/contracts/load_document.md` already uses staged validation before
  interaction interruption as the precedent for rejecting bad input without
  changing runtime state.
- `docs/contracts/spatial_kernel.md` already distinguishes diagnostic fallback
  from successful partial candidate results: budget-exceeded fallback returns a
  typed no-partial result and increments diagnostics instead of silently
  scanning or accepting.
- `docs/contracts/diagnostics.md` already separates enabled diagnostic records
  from disabled hot-path branch-only overhead.

### Repository Rules

- `PLAN.md` is the active roadmap, and new roadmap work must add a linked step
  contract under `plan/`.
- Repository documentation is the durable source of truth for the architecture
  rebuild; `docs/README.md` identifies `docs/contracts`, `docs/diagrams`, and
  `docs/verification` as normative surfaces.
- Documentation-only changes do not run `dart analyze`, `dcm analyze .`, or
  `dcm calculate-metrics .`.
- Important stable constraints should be enforced through repository-local
  tests, guardrails, or tooling rather than repeated prose reminders.

### Misleading Patterns

- The current geometry fallback wording is not a valid target pattern; it is
  the contradiction being retired.
- `CanvasTransform.invert() -> null` is not evidence that element transforms may
  be non-invertible; `CanvasTransform` is a general affine value type, while
  element admission is stricter.
- Spatial query budget fallback is not the same behavior as geometry fallback
  for corrupted non-invertible transforms and must not be removed or weakened by
  this step.
- Historical Step 11 instructions to keep the redesign note were scoped to Step
  11 and do not block this step after the note is moved into normative docs.

## 3. Architecture Decision

### Selected Form

Use a documentation-only source-of-truth update that keeps `CanvasTransform` as
the general affine public value type while making `CanvasElement.transform` an
admitted element invariant: element transforms must be finite, invertible, and
within the existing singular-value limits whenever they cross public DTO,
schema decode, edit update, or `loadDocument` boundaries. Runtime hit-test must
treat a non-invertible committed row as corrupted internal state and return a
miss with policy-gated diagnostics instead of accepting the row by coarse
candidate bounds.

### Ownership

`section_04_public_api_v1` owns the public element transform contract and public
error code reference. `section_06_validation_limits` owns the shared validation
boundary list and singular-value limits. `section_05_schema_v1_contract` and
`section_19_codec_boundary` own schema decode rejection and no-partial-DTO
materialization. `section_12_load_document` owns failed-load ordering before
interaction interruption. `section_16_geometry_policy` owns hit-test rejection
of corrupted rows. `section_20_diagnostics_hub` owns diagnostic allocation and
sanitization wording. `section_23_tests` owns future executable test coverage
descriptions.

### Seam

The seam is element transform admission into document state. Its accepted entry
paths are public DTO construction, schema decode materialization, edit update
materialization/preflight, and `loadDocument` staging. The defensive runtime
exit path is hit-test candidate resolution: if an already-committed row violates
the admission invariant, it exits as a diagnostic miss and candidate scanning
continues.

### Dependency Direction

Public, codec, edit, and load contracts depend on the shared validation
contract for the admitted element transform invariant. Geometry consumes
committed rows through read-only candidate handles and may only add a defensive
corruption check; it must not become the owner of input admission. Diagnostics
receives bounded facts from validation and runtime corruption paths and must not
mutate document, selection, preview, resource, spatial, projection, cache, or
repaint state.

### State and Data Ownership

Accepted public and schema documents own only invertible element transforms.
`CanvasTransform` itself remains capable of representing non-invertible affine
values, and nullable `invert()` remains valid for general math. A
non-invertible element transform after admission is internal corruption, not a
valid document state. Diagnostic details may include sanitized field path,
element id, and source information, but must not expose runtime objects,
handles, full scene dumps, or unsanitized field values.

### Entry and Exit Boundaries

Rejected public construction, schema decode, edit update, and `loadDocument`
inputs must fail before DTO exposure, draft mutation, `PreparedDocumentLoad`
success, interaction interruption, runtime install, cache invalidation, repaint,
action event, or public state publication. Runtime hit-test corruption handling
must not mutate state and must not stop candidate scanning after the corrupted
row misses.

### Verification Strategy

Use targeted semantic documentation proof for the contradiction and target
contract, structural documentation checks for registries/diagrams/navigation,
and verification-document updates that assign future executable behavior to the
existing test areas named in `section_23_tests`. Do not create production tests
or runtime code in this step.

### Public Compatibility

This is a public contract tightening for invalid element transforms, not a
public API shape change. It is breaking only for callers or persisted schema v1
documents that currently rely on non-invertible element transforms being
accepted; valid invertible documents and public method signatures are
unchanged. No schema version bump is required because schema v1 keeps the same
six-field transform object shape and the existing public validation surface
already includes `fieldMustBeInvertible`. No public export registry update is
required unless the execution step introduces a new public name, which this
contract forbids. The migration note for callers is to repair or reject
documents with non-invertible element transforms before construction, decode,
edit update, or `loadDocument`; the engine must not auto-repair them.

### Decision Ledger

| ID | Decision | Owner | Proof |
|---|---|---|---|
| D1 | `CanvasTransform` remains the general affine value type; element transform admission is the stricter invertible invariant. | `section_04_public_api_v1`, `section_06_validation_limits` | P2, P4 |
| D2 | Public DTO construction, schema decode, edit update materialization/preflight, and `loadDocument` staging reject non-invertible element transforms before state mutation. | `section_04_public_api_v1`, `section_05_schema_v1_contract`, `section_06_validation_limits`, `section_19_codec_boundary`, `section_12_load_document` | P2, P4, P6 |
| D3 | Runtime hit-test treats a non-invertible committed row as corrupted state: policy-gated diagnostic miss, no coarse candidate acceptance fallback, and continued candidate scanning. | `section_16_geometry_policy`, `section_20_diagnostics_hub` | P1, P3, P4 |
| D4 | The temporary redesign note is retired only after the normative docs and verification wording carry D1-D3. | `redesign.md`, `section_23_tests` | P2, P4, P5, P7, P8 |

### Rejected Alternatives

- Rejecting non-invertible values in `CanvasTransform` itself is rejected
  because the public type already exposes general affine math and nullable
  `invert()`.
- Adding a new public `InvertibleCanvasTransform` type is rejected for this
  step because it would introduce a wider public API migration than needed to
  close the accepted contract contradiction.
- Auto-repairing non-invertible transforms by replacing them with identity or
  clamped values is rejected because it silently changes user data and hides
  the source of corruption.
- Keeping coarse fallback with diagnostics is rejected because it preserves the
  harmful user-visible behavior where corrupted geometry can become a hit
  result.

## 4. Execution Guardrails

### Required Order

1. Before source-of-truth edits, run the BUG_FIX reproducer search:
   `rg -in "fall back to coarse candidate bounds|fallback to coarse candidate bounds|non-invertible transform fallback|coarse fallback.*non-invertible transform|no coarse candidate fallback" redesign.md docs/contracts/geometry.md docs/diagrams/seq_hit_test_candidate_resolution.mmd`.
   Expected pre-change signal: matches include the redesign note in
   `redesign.md`, the accepted fallback wording in `docs/contracts/geometry.md`,
   and the accepted fallback wording in
   `docs/diagrams/seq_hit_test_candidate_resolution.mmd`; together these
   matches show the source-of-truth contradiction.
   P2, P3, and P7 are the three neighboring guard proofs that must protect the
   repaired public, runtime, and verification surfaces for the BUG_FIX
   obligation. P6 remains a boundary sequence consistency proof, not an
   additional BUG_FIX neighboring guard proof.
2. Update public, validation, schema, codec, and load source-of-truth wording so
   element transform admission is locked at every entry path before changing
   hit-test fallback wording.
3. Update geometry and hit-test diagram wording to remove coarse candidate
   acceptance fallback only after the admission invariant is locked.
4. Update diagnostics and verification wording so corrupted-row diagnostics are
   policy-gated and future tests cover both rejection and no-fallback runtime
   behavior.
5. Retire the `redesign.md` note only after the normative docs and verification
   surfaces contain the replacement contract.
6. Run the documentation structural proof after all doc and diagram edits.
7. Only after P1-P7 pass, mark every Step 12 slice checkbox complete in the
   step document and mark Step 12 complete in `PLAN.md` in the same change.
8. After finalization edits, rerun P4 and run P8 before closing the step.

### Cross-Slice Constraints

- Keep `CanvasTransform` public shape unchanged.
- Preserve schema v1 transform JSON shape and schema version.
- Preserve spatial budget fallback wording and guardrails.
- Keep diagnostics disabled hot-path wording branch-only and allocation-free.
- Keep all validation failures before runtime mutation, draft mutation, load
  interaction interruption, repaint, events, and public state publication.
- Use the existing `fieldMustBeInvertible` public data error code rather than
  inventing a new error code unless repository evidence later proves it
  insufficient.

### Forbidden Moves

- Do not move admission ownership into `GeometryPolicy` or individual hit-test
  family code.
- Do not leave a path where decode accepts a non-invertible element transform
  and expects `loadDocument` or runtime to repair it later.
- Do not add prose that allows coarse candidate bounds to accept
  non-invertible box/image/text/rect hits.
- Do not weaken `diagnostics.disabled_no_alloc_hot_path`.
- Do not remove, rename, or broaden the spatial fallback budget contract.
- Do not leave the resolved redesign note as an active future-work item after
  replacement source-of-truth wording exists.

### Deferred Broad Verification

Runtime checks such as `dart analyze`, `dcm analyze .`,
`dcm calculate-metrics .`, and future Dart behavior tests are deferred to the
later implementation step that edits production or test code.

## 5. Proof Plan

### P1. Geometry Fallback Wording Negative Proof

This proves the retired geometry acceptance fallback no longer remains in the
active geometry contract or hit-test sequence.

```sh
sh -c '! rg -in "fall back to coarse candidate bounds|fallback to coarse candidate bounds|non-invertible transform fallback" docs/contracts/geometry.md docs/diagrams/seq_hit_test_candidate_resolution.mmd'
```

Expected signal: no matches.

### P2. Admission Contract Semantic Proof

This proves the normative docs explicitly carry public, schema, edit update,
and load rejection of non-invertible element transforms while preserving
`CanvasTransform` as the general affine value type.

```sh
rg -n "element transform|element transforms|non-invertible|fieldMustBeInvertible|CanvasElementUpdate\\.transform|loadDocument|schema decode|CanvasTransform" docs/contracts/public_api_v1.md docs/contracts/validation_limits.md docs/contracts/schema_v1.md docs/contracts/codec_boundary.md docs/contracts/load_document.md docs/verification/tests.md
rg -n "CanvasTransform|CanvasDataErrorCode|decodeCanvasDocument|decodeCanvasDocumentFromJson" docs/_registry/public_api_v1.yaml
sh -c '! rg -n "InvertibleCanvasTransform" docs/_registry/public_api_v1.yaml docs/contracts/public_api_v1.md'
```

Expected signal: matches include the stricter element admission rule, all four
rejection entry paths, `fieldMustBeInvertible`, verification ownership, and the
existing public registry entries; the `InvertibleCanvasTransform` search has no
matches.

### P3. Runtime Corruption Semantic Proof

This proves runtime hit-test docs carry the diagnostic miss behavior and no
coarse acceptance fallback for corrupted non-invertible rows.

```sh
rg -n "corrupt|non-invertible|diagnostic|miss|candidate scan|coarse" docs/contracts/geometry.md docs/contracts/diagnostics.md docs/diagrams/seq_hit_test_candidate_resolution.mmd docs/verification/tests.md
```

Expected signal: matches describe policy-gated diagnostics, miss behavior, and
continued candidate scanning without any coarse candidate acceptance fallback.

### P4. Documentation Structural And Whitespace Proof

This proves generated context capsules, documentation structure, and changed
file whitespace remain valid after the source-of-truth edits.

```sh
dart run docs/tool/generate_context_capsules.dart --check
dart run docs/tool/check_docs.dart
git diff --check -- PLAN.md plan/step_12_non_invertible_transform_admission.md redesign.md docs/contracts/public_api_v1.md docs/contracts/validation_limits.md docs/contracts/schema_v1.md docs/contracts/codec_boundary.md docs/contracts/load_document.md docs/contracts/geometry.md docs/contracts/diagnostics.md docs/diagrams/seq_schema_v1_decode_encode_order.mmd docs/diagrams/seq_load_document_failure.mmd docs/diagrams/seq_hit_test_candidate_resolution.mmd docs/verification/tests.md docs/indexes/by_test_area.md
```

Expected signal: all commands pass.

### P5. Redesign Note Retirement Negative Proof

This proves the temporary redesign note is no longer an active future-work
item after the normative docs carry the decision.

```sh
sh -c '! rg -in "non-invertible transform fallback|coarse fallback for non-invertible transform|non-invertible row|coarse candidate fallback|no coarse candidate fallback" redesign.md'
```

Expected signal: no matches.

### P6. Boundary Sequence Semantic Proof

This proves the sequence diagrams listed in Slice 1 carry the same transform
admission ordering as the contracts.

```sh
rg -n "transform|non-invertible|element validation|validation failure|PreparedDocumentLoad|interrupt" docs/diagrams/seq_schema_v1_decode_encode_order.mmd docs/diagrams/seq_load_document_failure.mmd
```

Expected signal: the schema decode sequence names transform admission as part
of element validation, and the failed load sequence shows transform validation
failure before `PreparedDocumentLoad` success or interaction interruption.

### P7. Verification Index Semantic Proof

This proves the verification owner and reverse test index both describe the
future executable coverage for this contract.

```sh
rg -n "constructor_and_schema_limits|field_update_nullable_semantics|staged_document_load_success_failure|hit_policy|diagnostics|non-invertible|coarse fallback|fieldMustBeInvertible" docs/verification/tests.md docs/indexes/by_test_area.md
```

Expected signal: matches cover constructor/schema rejection, edit update
rejection before draft mutation, `loadDocument` failure before interruption,
hit-test diagnostic miss without coarse fallback, and diagnostics disabled
no-allocation coverage.

### P8. Step Finalization Proof

This proves the roadmap index and linked step document are finalized together
only after the source-of-truth proof set is complete.

```sh
rg -n "^- \\[x\\] \\[Step 12\\. Non-invertible transform admission\\]" PLAN.md
sh -c '! rg -n "^### Slice [0-9]+\\. \\[ \\]" plan/step_12_non_invertible_transform_admission.md'
rg -n "^### Slice [0-9]+\\. \\[x\\]" plan/step_12_non_invertible_transform_admission.md
```

Expected signal: `PLAN.md` marks Step 12 complete, the step document has no
unchecked slice headings, and completed slice headings remain present.

## 6. Vertical Slices

### Slice 1. [x] Lock Element Transform Admission

#### Implements

D1 and D2.

#### Obligations Covered

BUG_FIX, PUBLIC_API_CHANGE

#### Files

- Public contract edit: `docs/contracts/public_api_v1.md` — state that
  `CanvasTransform` remains a general affine value while element transform
  admission rejects non-invertible values through `fieldMustBeInvertible`;
  include `CanvasElementUpdate.transform` rejection before draft mutation.
- Public registry verify-only evidence: `docs/_registry/public_api_v1.yaml` —
  confirm that no new exported public type is needed and existing public names
  remain sufficient.
- Validation contract edit: `docs/contracts/validation_limits.md` — clarify
  that element transform invertibility is validated at the listed public,
  generated/dynamic update, edit preflight, schema decode, and `loadDocument`
  boundaries.
- Schema contract edit: `docs/contracts/schema_v1.md` — clarify that transform
  JSON keeps the same six-field shape but element transform positions require
  invertibility and existing singular-value limits.
- Codec boundary edit: `docs/contracts/codec_boundary.md` — make element
  validation include non-invertible element transform rejection before DTO
  materialization and with no runtime/store side effects.
- Load contract edit: `docs/contracts/load_document.md` — make staged
  validation include non-invertible element transform rejection before
  `PreparedDocumentLoad` success or interaction interruption.
- Decode sequence alignment: `docs/diagrams/seq_schema_v1_decode_encode_order.mmd`
  — align schema element validation wording so the sequence names transform
  admission as part of element validation.
- Failed load sequence alignment: `docs/diagrams/seq_load_document_failure.mmd`
  — align validation failure wording so transform admission failure is included
  before interruption.

#### Change

The source-of-truth validation path says a non-invertible element transform is
invalid input at every admission boundary, returns the existing public data
validation error shape, and cannot reach document state through public DTO,
schema decode, edit update, or `loadDocument`.

#### Proof

Run P2 and P6.

#### Closure

This slice is complete when the public/data boundary docs consistently describe
the admitted element transform invariant and no entry path delegates
non-invertible transform handling to later runtime geometry.

### Slice 2. [x] Remove Runtime Hit-Test Acceptance Fallback

#### Implements

D3.

#### Obligations Covered

BUG_FIX

#### Files

- Geometry contract edit: `docs/contracts/geometry.md` — replace
  non-invertible coarse hit acceptance with corrupted-row diagnostic miss and
  continued candidate scanning.
- Diagnostics contract edit: `docs/contracts/diagnostics.md` — clarify that
  corrupted runtime-row diagnostics are policy-gated and preserve disabled
  hot-path no-allocation behavior.
- Hit-test sequence edit: `docs/diagrams/seq_hit_test_candidate_resolution.mmd`
  — replace the non-invertible fallback note with an explicit diagnostic-miss
  branch before exact hit acceptance.

#### Change

The runtime hit-test source of truth no longer lets box/image/text/rect family
rules accept by coarse candidate bounds when the transform cannot be inverted.
An internally corrupted row records only bounded diagnostics when policy allows
it, returns miss, and candidate scanning continues.

#### Proof

Run P1 and P3.

#### Closure

This slice is complete when the active geometry contract and hit-test sequence
contain no coarse acceptance fallback for non-invertible transforms and still
preserve normal exact-hit and candidate-order behavior for valid rows.

### Slice 3. [x] Align Verification And Retire Redesign Note

#### Implements

D4.

#### Obligations Covered

BUG_FIX, PUBLIC_API_CHANGE

#### Files

- Verification contract edit: `docs/verification/tests.md` — assign future
  executable coverage to existing test areas for constructor/schema rejection,
  edit update rejection before draft mutation, `loadDocument` failure before
  interruption, hit-test diagnostic miss without coarse fallback, and
  diagnostics disabled no-allocation policy.
- Test index alignment: `docs/indexes/by_test_area.md` — align reverse lookup
  wording for the touched test areas so it mirrors the verification
  responsibilities.
- Redesign-note finalization: `redesign.md` — remove the resolved
  non-invertible transform fallback note after D1-D3 are present in normative
  docs.

#### Change

Verification docs become the durable reminder for future implementation, and
the temporary redesign note stops being an active source of truth once the
normative contracts carry the decision.

#### Proof

Run P5 and P7, then run P4.

#### Closure

This slice is complete when future executable coverage is documented, the
resolved redesign note is gone from active source-of-truth surfaces, and the
documentation structural checks pass.

### Slice 4. [x] Finalize Step 12 Roadmap State

#### Implements

D4.

#### Files

- Roadmap index finalization: `PLAN.md` — mark Step 12 complete only after
  P1-P7 pass.
- Step contract finalization:
  `plan/step_12_non_invertible_transform_admission.md` — mark Slice 1 through
  Slice 4 complete only after P1-P7 pass, and preserve this finalization proof
  in the contract.

#### Change

The roadmap index and linked step contract are finalized in the same change
after the source-of-truth docs, diagrams, verification wording, redesign-note
retirement, and documentation structural proof have all passed.

#### Proof

Run P4 and P8 after P1-P7 pass and after the finalization edits are applied.

#### Closure

This slice is complete when Step 12 is checked in `PLAN.md`, every Step 12
slice checkbox is checked in this file, and P4 plus P8 pass after those
checkbox edits.

## 7. Final Gate

### Run Proof Set

- P1
- P2
- P3
- P4
- P5
- P6
- P7
- P8

### Done When

- all referenced Decision Ledger decisions have passing proof;
- all Contract Obligations are satisfied;
- no out-of-scope files were changed;
- P4 whitespace validation passes;
- Step 12 and its slice checkboxes are marked complete only after P1-P7 pass,
  then P4 and P8 pass after those finalization edits;
- `redesign.md` no longer carries the resolved non-invertible transform
  fallback note as an active future-work item;
- documentation structural checks pass.
