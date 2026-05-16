# Change Contract

If `4B. Architecture Decision Gate` is filled, stop after section 4.

## 1. Change Mandate

Close HOLE-006 at the architecture-documentation level by making the public DTO
metadata, collection ownership, validation, and `const` policy unambiguous across
the normative docs, registries, diagrams, verification inventory, audit, and
redesign backlog.

## 2. Change Boundary

### Included in the Change

- Update documentation only: contracts, registries, indexes, phase docs, donor
  docs, diagrams, `audit.md`, `redesign.md`, and this plan step.
- Lock the public API decision that metadata-bearing DTOs use an exported
  `CanvasMetadata` value object instead of ordinary raw metadata maps.
- Lock the policy that public DTO constructors accepting caller-owned
  `Iterable`, `List`, `Set`, `Map`, or metadata input are non-const because they
  must defensively copy, deep-freeze, and validate at runtime.
- Lock the policy that safe scalar-only DTOs and marker variants may remain
  `const` when they do not accept caller-owned mutable input and do not require
  runtime validation beyond safe compile-time/default values.
- Preserve schema v1 JSON metadata shape as an object while documenting
  `CanvasMetadata` as the public materialization/projection type.
- Preserve raw `Map<String, Object?>` only for raw JSON codec boundaries and
  sanitized diagnostic details where map-shaped public data is intentional.
- Update verification docs to name the future executable tests/guardrails that
  must prove defensive copy, deep-freeze, invalid construction rejection, and
  `const` policy during later code implementation.
- Remove HOLE-006 from active `audit.md` tracking and remove the implemented
  DTO collection/metadata redesign item from `redesign.md` after the docs agree.

### Not Included in the Change

- No production Dart implementation under `lib/**`.
- No Dart test implementation under `test/**`.
- No guardrail runner/tool implementation under `tool/**`.
- No generated code or fixture creation.
- No execution of `dart analyze`, `dcm analyze .`, or
  `dcm calculate-metrics .`, because this is documentation-only.
- No implementation of unrelated audit holes such as HOLE-002, HOLE-003,
  HOLE-004, HOLE-007, HOLE-008, HOLE-009, HOLE-010, HOLE-011, or DIAG-PROOF.
- No schema v1 JSON field-name or metadata JSON-shape change.
- No legacy API compatibility alias or legacy DTO public shape.

## 3. Surrounding Code Review

### Inspected Artifacts

- `audit.md` - lists HOLE-006 as an API-freeze blocker and requires public DTO
  boundary review, update DTO boundary review, runtime config boundary review,
  pointer sample routing boundary review, runtime validation, collection length
  validation, `CanvasPalette` review, policy wording expansion, and future tests
  for defensive copy, unmodifiable collections, and invalid construction.
- `redesign.md` - contains the implemented design direction for HOLE-006:
  collection/metadata DTOs become non-const, `CanvasPalette` copies iterables
  with `List.unmodifiable`, and metadata uses `CanvasMetadata`.
- `PLAN.md` - is the active roadmap index and needs a linked Step 4 entry.
- `plan/step_3_canvas_field_update_patch_semantics.md` - explicitly excludes
  unrelated DTO defensive-copy, metadata, collection, and `const` policy changes
  from Step 3 and assigns them to HOLE-006.
- `docs/contracts/public_api_v1.md` - owns public API semantics and currently
  contains the contradiction: immutable DTO prose, raw metadata map signatures,
  collection getters, `const CanvasPalette`, and metadata update fields using
  raw `Map<String, Object?>`.
- `docs/_registry/public_api_v1.yaml` - owns exported public names and currently
  does not list `CanvasMetadata`.
- `docs/contracts/schema_v1.md` - owns metadata as schema JSON object data and
  the JSON-only metadata limits.
- `docs/contracts/codec_boundary.md` - owns decode/encode boundary order,
  metadata validation, and public DTO validation before canonical encode.
- `docs/contracts/validation_limits.md` - owns metadata, palette, numeric, and
  construction-boundary validation limits.
- `docs/architecture/03_data_model.md` - already says projection DTOs must
  deep-copy all public collections and metadata.
- `docs/verification/guardrails.md` - defines `api.public_signature_shape` and
  `api.dto_immutability`; both need wording aligned with `CanvasMetadata` and
  deep-freeze.
- `docs/verification/tests.md` - owns the required future test inventory and
  already lists DTO immutability and constructor/schema limit proof areas.
- `docs/_registry/donors.yaml` and `docs/donors/**` - map immutable collection
  and metadata decode donor knowledge to future phases.
- `docs/diagrams/dfd_schema_v1_decode_encode.mmd` and
  `docs/diagrams/seq_schema_v1_decode_encode_order.mmd` - show schema metadata
  validation, DTO materialization, public DTO validation, and metadata encode
  order.
- `docs/diagrams/seq_load_document_success.mmd`,
  `docs/diagrams/seq_load_document_failure.mmd`, and
  `docs/diagrams/dfd_load_document_success_failure.mmd` - show load validation
  and materialization paths that must refer to frozen metadata facts.
- `docs/diagrams/dfd_resource_resolution.mmd` and
  `docs/diagrams/state_resource_resolution.mmd` - show resource descriptor
  metadata labels that must align with `CanvasMetadata`.
- `docs/diagrams/dfd_diagnostics_error_projection.mmd` - shows validation
  errors and public diagnostic details, which must stay distinct from schema
  metadata.

### Current Entry Path

- Documentation entry: `docs/README.md` routes public API work to
  `docs/contracts/public_api_v1.md`, schema work to `docs/contracts/schema_v1.md`,
  validation work to `docs/contracts/validation_limits.md`, and verification
  work to `docs/verification/**`.
- Roadmap entry: `PLAN.md` points to root `plan/**` Change Contracts.
- Audit entry: `audit.md` tracks HOLE-006 until the documentation source of
  truth is updated.
- Redesign entry: `redesign.md` contains the design note that should be retired
  once moved into the normative docs.

### Current Owner

- Public API semantics and `const` policy: `docs/contracts/public_api_v1.md`.
- Public export inventory: `docs/_registry/public_api_v1.yaml`.
- Schema metadata JSON policy: `docs/contracts/schema_v1.md`.
- Codec boundary ordering and materialization policy: `docs/contracts/codec_boundary.md`.
- Construction and metadata limits: `docs/contracts/validation_limits.md`.
- Verification inventory and guardrail descriptions: `docs/verification/**` and
  `docs/indexes/**`.
- Diagrams: `docs/diagrams/**`.
- Audit/redesign retirement: `audit.md` and `redesign.md`.

### Adjacent Abstractions

- `CanvasDocument`, `CanvasLayer`, `CanvasElement`, `CanvasResource`, and
  `CanvasElementUpdate` are the public metadata-bearing DTOs whose documented
  signatures must change to `CanvasMetadata`.
- `CanvasPalette`, stroke points, preview lists, action payload lists, clear
  result lists, and move request lists are the collection-bearing DTO examples
  that define the non-const defensive-copy policy.
- `CanvasDataException.details` is adjacent but not metadata; it remains a
  sanitized diagnostics details map.
- Raw JSON codec functions are adjacent but remain map-shaped boundaries.

### Existing Tests

- No root `lib/**` or `test/**` implementation exists for this architecture
  rebuild step.
- This step therefore does not create executable Dart tests.
- `docs/verification/tests.md` is the existing source of truth for future tests
  and must be updated so later implementation has explicit proof obligations.
- `docs/tool/check_docs.dart` is the executable documentation consistency check
  available for this docs-only step.

### Analogous Implementation Path

- `plan/step_2_public_readable_union_variants.md` is the precedent for moving a
  redesign/audit item into normative docs and then retiring stale backlog text.
- `plan/step_3_canvas_field_update_patch_semantics.md` is the precedent for
  explicitly excluding unrelated HOLE scope and deleting audit/redesign only
  after the step's own proof is complete.
- `legacy/iwb_canvas_engine/lib/src/core/immutable_collections.dart`,
  `legacy/iwb_canvas_engine/lib/src/contract/owned_collections.dart`, and
  `legacy/iwb_canvas_engine/lib/src/contract/scene_data_exception.dart` remain
  donor references only; this step documents how future implementation should
  adapt their behavior without copying legacy public shape.

### Governing Repository Rules

- `AGENTS.md` - documentation is written in English.
- `AGENTS.md` - repository-specific source-of-truth knowledge must be updated in
  repository docs, not left only in chat.
- `AGENTS.md` - prefer mechanically enforced repository-local rules over prose
  reminders; this docs step must name future guardrails/tests rather than rely
  on tribal knowledge.
- `docs/architecture/00_architecture_overview.md` - this package is the new
  architecture rebuild and must not preserve legacy public shapes.
- `docs/architecture/02_package_boundaries.md` - public API declarations live
  under `lib/src/api/**`; this docs-only step must keep implementation ownership
  consistent with that future boundary.
- `docs/verification/guardrails.md` - public API signature shape and DTO
  immutability are blocking guardrails.

### Rejected Misleading Local Patterns

- Keeping HOLE-006 only in `redesign.md` - rejected because the design decision
  must move into normative docs.
- Keeping raw metadata maps as ordinary public DTO metadata - rejected because
  metadata has validation/deep-freeze semantics that deserve one public owner.
- Treating diagnostic details as `CanvasMetadata` - rejected because diagnostics
  details are sanitized error projection, not schema metadata.
- Writing production code or tests in this step - rejected because the current
  user request is planning/documentation only and the root package code is not
  in scope.
- Leaving future proof unnamed - rejected because later implementation needs
  explicit test and guardrail obligations.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- HOLE-006 is owned first by the public API and schema documentation because the
  current defect is an architectural contradiction in the documented surface.
- Future production implementation is owned by `lib/src/api/**` and codec
  materialization, but that code is not changed in this step.

#### Selected Architectural Form

- `CanvasMetadata` is the exported public metadata value object for document,
  layer, element, resource, and metadata update DTOs.
- `CanvasMetadata` owns future metadata validation and deep-freeze semantics.
- Public metadata-bearing DTO signatures use `CanvasMetadata`, not raw metadata
  maps.
- Raw map signatures remain documented only for raw JSON codec input/output and
  sanitized diagnostic details.
- Public constructors that accept caller-owned collections or metadata are
  documented as non-const.
- Public scalar-only constructors and marker/empty variants may remain `const`
  when no caller-owned mutable input or runtime validation is required.

#### Owning Layer or Module

- Normative API owner: `docs/contracts/public_api_v1.md`.
- Export inventory owner: `docs/_registry/public_api_v1.yaml`.
- Schema metadata owner: `docs/contracts/schema_v1.md`.
- Codec boundary owner: `docs/contracts/codec_boundary.md`.
- Validation limits owner: `docs/contracts/validation_limits.md`.
- Verification owner: `docs/verification/**` and `docs/indexes/**`.
- Diagram owner: `docs/diagrams/**`.
- Backlog retirement owner: `audit.md` and `redesign.md`.

#### Dependency Direction

- Documentation points future `CanvasMetadata` implementation to `lib/src/api/**`.
- Codec/load/projection docs consume `CanvasMetadata`; they do not define a
  second metadata value owner.
- Diagnostics docs keep diagnostic details separate from schema metadata.
- Verification docs define future tests/guardrails; this step does not implement
  them.

#### State and Data Ownership

- Public metadata ownership is documented as `CanvasMetadata`.
- Public DTO collection ownership is documented as defensive-copy plus
  unmodifiable exposed values.
- Raw JSON maps are documented as boundary data, not stored DTO metadata.
- Diagnostic details are documented as sanitized frozen details, not metadata.

#### Entry and Exit Boundaries

- Documentation entry boundary: updates start at `docs/contracts/public_api_v1.md`
  and propagate to schema, codec, validation, verification, donor, phase, and
  diagram docs.
- Future public construction boundary: metadata-bearing DTOs receive or
  construct `CanvasMetadata`.
- Future schema decode boundary: raw metadata JSON validates and materializes
  `CanvasMetadata`.
- Future encode boundary: `CanvasMetadata` writes canonical JSON object metadata.
- Exit boundary for this step: audit/redesign no longer carry the implemented
  HOLE-006 decision as active backlog.

#### Permitted Extension Seam

- Future public metadata-bearing DTOs must use `CanvasMetadata`.
- Future raw map public signatures must be explicitly documented as JSON codec or
  diagnostics boundaries.
- Future proof must be added through `docs/verification/tests.md`,
  `docs/verification/guardrails.md`, and related indexes before code freeze.

#### Rejected Alternatives

- Leave raw map metadata in public DTO docs - rejected because it keeps the
  ambiguity HOLE-006 exists to close.
- Make every constructor non-const in docs - rejected because scalar-only safe
  types can keep useful `const` ergonomics.
- Close the hole by editing `audit.md` only - rejected because source-of-truth
  contracts, registries, and diagrams must carry the decision.
- Implement code/tests now - rejected because this step is documentation-only.

#### Why This Level Is Correct

- The repository currently has docs and roadmap artifacts but no root
  implementation/test surface for this API slice.
- Moving the decision from `redesign.md`/`audit.md` into normative docs is the
  correct closure level for the current work.
- Later implementation can then follow one documented source of truth instead of
  rediscovering policy from chat or backlog prose.

### 4B. Architecture Decision Gate

## 5. Locked Decisions

1. `CanvasMetadata` is part of the future public API and must be added to the
   public export registry.
2. Public document, layer, element, resource, and metadata update DTO docs use
   `CanvasMetadata` for metadata.
3. Schema v1 metadata remains a JSON object on the wire.
4. Raw `Map<String, Object?>` remains allowed for codec JSON boundaries and
   diagnostic details only.
5. DTO constructors with caller-owned collections or metadata are documented as
   non-const.
6. Safe scalar-only DTOs and marker variants may remain `const`.
7. `CanvasMetadata` future implementation belongs under `lib/src/api/**`.
8. This step updates future test/guardrail requirements but does not create
   `test/**`, `lib/**`, or `tool/**` files.
9. HOLE-006 and the corresponding redesign item are retired from active backlog
   only after the documentation source of truth is updated and checked.

## 6. Result Requirements

1. `docs/contracts/public_api_v1.md` no longer contradicts DTO immutability with
   raw metadata maps or `const` collection-owning constructors.
2. `CanvasMetadata` appears in `docs/_registry/public_api_v1.yaml`.
3. Schema, codec, validation, load, diagnostics, and data-model docs agree on
   metadata ownership and raw-map boundaries.
4. Verification docs name future executable proof for defensive copy,
   unmodifiable collections, metadata deep-freeze, invalid public construction,
   and `const` policy drift.
5. Diagrams that mention metadata or DTO materialization match the documented
   `CanvasMetadata` policy.
6. `audit.md` no longer tracks HOLE-006 as active work.
7. `redesign.md` no longer contains the implemented DTO collection/metadata
   redesign item.

## 7. Execution Order and Gates

### Required Order

- First update the normative public API contract and public export registry.
- Then update schema, codec, validation, diagnostics, load, data-model, phase,
  donor, verification, guardrail, index, and diagram docs to match.
- Then remove the implemented HOLE-006 entry from `audit.md` and the implemented
  DTO collection/metadata item from `redesign.md`.
- Then mark this step complete in `PLAN.md` and this step file.

### Successor Seam and Retirement Gates

- Successor metadata seam: `CanvasMetadata` in the public API contract.
- Raw-map documentation gate: raw `Map<String, Object?>` metadata remains
  documented only for codec JSON boundaries and diagnostics details.
- `const` documentation gate: public API docs classify collection/metadata
  constructors as non-const and safe scalar/marker constructors as allowed const.
- Audit/redesign gate:
  `sh -c '! rg -n "HOLE-006|DTO с коллекциями и metadata делаем non-const" audit.md redesign.md'`
  passes after retirement.

### Deferred Broad Verification

- `dart analyze` - deferred until production code exists for this step.
- `dcm analyze .` - deferred until production code exists for this step.
- `dcm calculate-metrics .` - deferred until production code exists for this step.
- Dart tests named in verification docs are future implementation obligations,
  not checks for this documentation-only step.

## 8. File Map

### Implementation Files

- None. This step is documentation-only.

### Test Files

- None. This step updates future test requirements but does not create tests.

### Fixtures and Supporting Data

- None.

### Registry, Inventory, and Workflow Files

- `PLAN.md`
- `plan/step_4_dto_metadata_immutability_and_const_policy.md`
- `audit.md`
- `redesign.md`
- `docs/contracts/public_api_v1.md`
- `docs/contracts/schema_v1.md`
- `docs/contracts/codec_boundary.md`
- `docs/contracts/validation_limits.md`
- `docs/contracts/diagnostics.md`
- `docs/contracts/load_document.md`
- `docs/architecture/03_data_model.md`
- `docs/_registry/public_api_v1.yaml`
- `docs/_registry/sections.yaml`
- `docs/_registry/donors.yaml`
- `docs/indexes/by_guardrail.md`
- `docs/indexes/by_test_area.md`
- `docs/indexes/donor_to_phase.md`
- `docs/verification/guardrails.md`
- `docs/verification/tests.md`
- `docs/verification/release_gates.md`
- `docs/implementation/p2_public_api_v1_freeze.md`
- `docs/implementation/p3_schema_v1_dto_validation_and_codec_skeleton.md`
- `docs/implementation/p6_load_document.md`
- `docs/donors/01_summary_by_decision.md`
- `docs/donors/04_dto_model_validation_structure.md`
- `docs/donors/05_codec.md`

### Analysis Area

- `docs/diagrams/dfd_schema_v1_decode_encode.mmd`
- `docs/diagrams/seq_schema_v1_decode_encode_order.mmd`
- `docs/diagrams/seq_load_document_success.mmd`
- `docs/diagrams/seq_load_document_failure.mmd`
- `docs/diagrams/dfd_load_document_success_failure.mmd`
- `docs/diagrams/dfd_resource_resolution.mmd`
- `docs/diagrams/state_resource_resolution.mmd`
- `docs/diagrams/dfd_diagnostics_error_projection.mmd`
- `docs/tool/check_docs.dart`

## 9. Implementation Rules

### Protected Invariants

- This step does not write production code or tests.
- Documentation must not leave two public metadata owners.
- Documentation must not imply raw metadata maps are ordinary DTO metadata.
- Documentation must not imply `const` constructors can defensively copy caller
  collections.
- Future proof obligations must be recorded in verification docs, not left only
  in this plan file.
- Audit/redesign cleanup must happen only after normative docs and diagrams are
  updated.

### Required Proof

- documentation proof: `docs/tool/check_docs.dart` passes after registry,
  index, and diagram updates.
- documentation proof: `CanvasMetadata` appears in the public API contract and
  public export registry.
- documentation proof: audit/redesign retirement command confirms no active
  HOLE-006/redesign backlog entry remains.
- documentation proof: verification docs name future proof for defensive copy,
  unmodifiable collections, metadata deep-freeze, invalid construction, and
  `const` drift.

### Allowed Change Surface

- Documentation, registries, indexes, diagrams, audit, redesign, and plan files
  listed in section 8.

### Forbidden Moves

- Do not create or modify `lib/**`.
- Do not create or modify `test/**`.
- Do not create or modify `tool/**` guardrail implementation.
- Do not run code-analysis gates and claim they prove this docs-only change.
- Do not delete unrelated audit/redesign items.
- Do not change schema v1 JSON field names.

### Optional: Recognition Forms That Must Be Supported

- `CanvasMetadata` in public API docs and export registry.
- `CanvasMetadata.empty()` as the documented default metadata value.
- `CanvasMetadata.fromMap({...})` as the documented caller-provided metadata form.
- `CanvasFieldUpdate<CanvasMetadata>` as the documented metadata update form.
- `CanvasPalette.defaults()` as the documented non-const default palette factory.

### Optional: Allowed Forms That Are Not Violations

- Raw `Map<String, Object?>` at documented JSON codec boundaries.
- Raw `Map<String, Object?>` for sanitized diagnostic details.
- `const` on scalar-only DTOs and marker variants that accept no mutable
  caller-owned input.
- Future test names in verification docs without creating those tests now.

### Optional: Resolution Rules

- When docs mention metadata-bearing public DTOs, use `CanvasMetadata`.
- When docs mention schema JSON metadata, keep the JSON object shape and name
  `CanvasMetadata` only as materialized public DTO data.
- When docs mention diagnostics details, keep them separate from
  `CanvasMetadata`.
- When docs mention collection-bearing public DTO constructors, describe
  defensive copy/unmodifiable exposure and non-const construction.

## 10. Vertical Slices

### Slice 1. [x] Public API and Registry Documentation

#### Slice Contract

The normative public API docs and public export registry lock `CanvasMetadata`
and the `const`/collection policy without creating code or tests.

#### Change

Update `docs/contracts/public_api_v1.md` and
`docs/_registry/public_api_v1.yaml`. Add `CanvasMetadata` to the exported names.
Replace ordinary public DTO metadata signatures with `CanvasMetadata` in the
documented API. Update the DTO immutability prose from shallow `List or Map`
wording to `Iterable`, `List`, `Set`, `Map`, metadata, defensive copy,
deep-freeze, and non-const construction where required.

#### Behavioral Verification

- `dart run docs/tool/check_docs.dart`

#### Structural Verification

- `rg -n "CanvasMetadata" docs/contracts/public_api_v1.md`
- `rg -n "  - CanvasMetadata$" docs/_registry/public_api_v1.yaml`
- `sh -c '! rg -n "Map<String, Object\\?> metadata|Map<String, Object\\?> get metadata|CanvasFieldUpdate<Map<String, Object\\?>> metadata|const CanvasPalette" docs/contracts/public_api_v1.md'`

#### Fixtures Used

- None.

#### Positive Scenarios

- `CanvasMetadata` is listed as public API.
- Metadata-bearing public DTO examples use `CanvasMetadata`.
- `CanvasPalette` and other collection-owning DTO docs are non-const where
  caller-owned collections are accepted.

#### Negative Scenarios

- Ordinary public DTO metadata remains documented as raw `Map<String, Object?>`.
- `const CanvasPalette` remains documented with caller-provided `Iterable`.

#### Closure Evidence

- Public API docs and export registry agree.

### Slice 2. [x] Cross-Contract Documentation Alignment

#### Slice Contract

Schema, codec, validation, diagnostics, load, data-model, phase, donor,
verification, guardrail, index, and diagram docs agree with the public API
metadata and `const` policy.

#### Change

Update all registry, inventory, workflow, donor, phase, contract, verification,
and diagram files listed in section 8 that mention metadata, DTO immutability,
public signature shape, schema materialization, load validation, resource
descriptor metadata, diagnostics details, or future proof requirements.

#### Behavioral Verification

- `dart run docs/tool/check_docs.dart`

#### Structural Verification

- `rg -n "CanvasMetadata" docs/contracts/schema_v1.md`
- `rg -n "CanvasMetadata" docs/contracts/codec_boundary.md`
- `rg -n "CanvasMetadata" docs/contracts/validation_limits.md`
- `rg -n "CanvasMetadata|diagnostic details.*not.*metadata|details.*not.*CanvasMetadata" docs/contracts/diagnostics.md`
- `rg -n "CanvasMetadata" docs/contracts/load_document.md`
- `rg -n "CanvasMetadata" docs/architecture/03_data_model.md`
- `rg -n "CanvasMetadata" docs/implementation/p2_public_api_v1_freeze.md`
- `rg -n "CanvasMetadata" docs/implementation/p3_schema_v1_dto_validation_and_codec_skeleton.md`
- `rg -n "CanvasMetadata" docs/implementation/p6_load_document.md`
- `rg -n "CanvasMetadata" docs/_registry/sections.yaml docs/_registry/donors.yaml`
- `rg -n "CanvasMetadata" docs/donors/01_summary_by_decision.md docs/donors/04_dto_model_validation_structure.md docs/donors/05_codec.md`
- `rg -n "CanvasMetadata" docs/verification/guardrails.md docs/verification/tests.md docs/verification/release_gates.md`
- `rg -n "CanvasMetadata" docs/indexes/by_guardrail.md docs/indexes/by_test_area.md docs/indexes/donor_to_phase.md`
- `rg -n "CanvasMetadata|frozen metadata" docs/diagrams/dfd_schema_v1_decode_encode.mmd`
- `rg -n "CanvasMetadata|frozen metadata" docs/diagrams/seq_schema_v1_decode_encode_order.mmd`
- `rg -n "CanvasMetadata|frozen metadata" docs/diagrams/seq_load_document_success.mmd`
- `rg -n "CanvasMetadata|frozen metadata" docs/diagrams/seq_load_document_failure.mmd`
- `rg -n "CanvasMetadata|frozen metadata" docs/diagrams/dfd_load_document_success_failure.mmd`
- `rg -n "CanvasMetadata|frozen metadata" docs/diagrams/dfd_resource_resolution.mmd`
- `rg -n "CanvasMetadata|frozen metadata" docs/diagrams/state_resource_resolution.mmd`
- `rg -n "CanvasMetadata|metadata value validation|diagnostic details.*not.*metadata" docs/diagrams/dfd_diagnostics_error_projection.mmd`
- `sh -c '! rg -n "ordinary public DTO metadata.*Map<String, Object\\?>|raw metadata maps become public DTO metadata|only shallow unmodifiable" docs/contracts docs/architecture docs/implementation docs/verification docs/indexes docs/_registry docs/donors docs/diagrams'`

#### Fixtures Used

- None.

#### Positive Scenarios

- Schema docs preserve JSON object metadata while naming `CanvasMetadata`
  materialization.
- Codec/load diagrams show metadata validation/freeze before DTO exposure.
- Verification docs name future tests for defensive copy, deep-freeze, invalid
  construction rejection, and `const` drift.

#### Negative Scenarios

- Diagrams still imply raw metadata maps become public DTO metadata.
- Guardrail docs mention only shallow unmodifiable collections.
- Verification docs omit future proof for metadata deep-freeze.

#### Closure Evidence

- Documentation check passes and targeted search shows the decision propagated.

### Slice 3. [x] Audit and Redesign Retirement

#### Slice Contract

After the normative docs and diagrams own the HOLE-006 decision, active backlog
files no longer track HOLE-006 or the implemented redesign item.

#### Change

Remove HOLE-006 from `audit.md`, including the API-freeze blocker line and the
HOLE-006 section. Remove the implemented `DTO с коллекциями и metadata делаем
non-const` item from `redesign.md`. Mark this step complete in `PLAN.md` and in
this step file.

#### Behavioral Verification

- `sh -c '! rg -n "HOLE-006|DTO с коллекциями и metadata делаем non-const" audit.md redesign.md'`

#### Structural Verification

- `dart run docs/tool/check_docs.dart`

#### Fixtures Used

- None.

#### Positive Scenarios

- `audit.md` no longer lists HOLE-006.
- `redesign.md` no longer contains the implemented DTO metadata item.
- Step 4 checkboxes are marked complete only after docs verification passes.

#### Negative Scenarios

- HOLE-006 is removed before the normative docs own the decision.
- Unrelated audit or redesign items are deleted.

#### Closure Evidence

- Documentation check passes and the retirement command returns no active
  HOLE-006/redesign matches.

## 11. Final Verification

- `dart run docs/tool/check_docs.dart`
- `rg -n "CanvasMetadata" docs/contracts/public_api_v1.md`
- `rg -n "  - CanvasMetadata$" docs/_registry/public_api_v1.yaml`
- `sh -c '! rg -n "Map<String, Object\\?> metadata|Map<String, Object\\?> get metadata|CanvasFieldUpdate<Map<String, Object\\?>> metadata|const CanvasPalette" docs/contracts/public_api_v1.md'`
- `rg -n "CanvasMetadata" docs/contracts/schema_v1.md`
- `rg -n "CanvasMetadata" docs/contracts/codec_boundary.md`
- `rg -n "CanvasMetadata" docs/contracts/validation_limits.md`
- `rg -n "CanvasMetadata|diagnostic details.*not.*metadata|details.*not.*CanvasMetadata" docs/contracts/diagnostics.md`
- `rg -n "CanvasMetadata" docs/contracts/load_document.md`
- `rg -n "CanvasMetadata" docs/architecture/03_data_model.md`
- `rg -n "CanvasMetadata" docs/implementation/p2_public_api_v1_freeze.md`
- `rg -n "CanvasMetadata" docs/implementation/p3_schema_v1_dto_validation_and_codec_skeleton.md`
- `rg -n "CanvasMetadata" docs/implementation/p6_load_document.md`
- `rg -n "CanvasMetadata" docs/_registry/sections.yaml docs/_registry/donors.yaml`
- `rg -n "CanvasMetadata" docs/donors/01_summary_by_decision.md docs/donors/04_dto_model_validation_structure.md docs/donors/05_codec.md`
- `rg -n "CanvasMetadata" docs/verification/guardrails.md docs/verification/tests.md docs/verification/release_gates.md`
- `rg -n "CanvasMetadata" docs/indexes/by_guardrail.md docs/indexes/by_test_area.md docs/indexes/donor_to_phase.md`
- `rg -n "CanvasMetadata|frozen metadata" docs/diagrams/dfd_schema_v1_decode_encode.mmd`
- `rg -n "CanvasMetadata|frozen metadata" docs/diagrams/seq_schema_v1_decode_encode_order.mmd`
- `rg -n "CanvasMetadata|frozen metadata" docs/diagrams/seq_load_document_success.mmd`
- `rg -n "CanvasMetadata|frozen metadata" docs/diagrams/seq_load_document_failure.mmd`
- `rg -n "CanvasMetadata|frozen metadata" docs/diagrams/dfd_load_document_success_failure.mmd`
- `rg -n "CanvasMetadata|frozen metadata" docs/diagrams/dfd_resource_resolution.mmd`
- `rg -n "CanvasMetadata|frozen metadata" docs/diagrams/state_resource_resolution.mmd`
- `rg -n "CanvasMetadata|metadata value validation|diagnostic details.*not.*metadata" docs/diagrams/dfd_diagnostics_error_projection.mmd`
- `sh -c '! rg -n "ordinary public DTO metadata.*Map<String, Object\\?>|raw metadata maps become public DTO metadata|only shallow unmodifiable" docs/contracts docs/architecture docs/implementation docs/verification docs/indexes docs/_registry docs/donors docs/diagrams'`
- `sh -c '! rg -n "HOLE-006|DTO с коллекциями и metadata делаем non-const" audit.md redesign.md'`

## 12. Acceptance Criteria

- The public API contract documents `CanvasMetadata` and non-const
  collection/metadata DTO construction policy.
- The public API registry includes `CanvasMetadata`.
- Schema, codec, validation, diagnostics, load, data-model, phase, donor,
  verification, guardrail, index, and diagram docs agree with the policy.
- Verification docs name future executable proof without creating tests in this
  docs-only step.
- `audit.md` no longer tracks HOLE-006.
- `redesign.md` no longer contains the implemented DTO collection/metadata
  redesign item.
- No `lib/**`, `test/**`, or `tool/**` implementation files are changed by this
  step.
