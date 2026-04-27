# Change Contract

## 1. Change Mandate

Fix `KI-1` by making public `NodePatch` admission reject explicit null writes for every non-nullable patch field at the patch schema boundary, before transactional patch application begins.

## 2. Change Boundary

### Included in the Change

- Reject `PatchField.nullValue()` for every non-nullable public `NodePatch` field currently reported by `dart run tool/audit_patch_field_admission.dart`.
- Add regression proof that public patch constructors reject those explicit-null writes eagerly.
- Preserve nullable patch semantics where `PatchField<T?>.value(null)` and `PatchField<T?>.nullValue()` remain valid explicit-null writes.
- Remove `KI-1` from `KNOWN_ISSUES.md` only after the implementation and regression proof land.

### Not Included in the Change

- Do not redesign `PatchField<T>` or its tri-state model.
- Do not move field nullability policy into transactional patch application.
- Do not change node runtime field defaults, node mutation semantics, or JSON schema versions.
- Do not address other active known issues.
- Do not update `ARCHITECTURE.md` unless the implementation changes invariant wording, architecture, or module ownership beyond the locked schema-boundary owner.

## 3. Surrounding Code Review

### Inspected Artifacts

- `KNOWN_ISSUES.md` — `KI-1` identifies non-nullable public `NodePatch` fields that admit `PatchField.nullValue()` and fail later during transactional patch application.
- `lib/src/contract/internal/node_boundary_schema_patch.dart` — owns patch schema field validation and already contains `_validateNonNullablePatchField(...)` and `_validateNullablePatchField(...)`.
- `lib/src/contract/node_patch.dart` — public patch constructors call `validate*PatchSchemaFields(...)` before exposing patch objects.
- `lib/src/model/document_node_patch_common.dart` — transactional patch assignment reads `patch.value` and assumes non-nullable patch fields have already been admitted correctly.
- `lib/src/model/document_node_patch_text.dart` and `lib/src/model/document_node_patch_stroke.dart` — typed patch application delegates to generic patch assignments and does not own field admission policy.
- `lib/src/contract/internal/node_patch_backing.dart` — validated fast-path backing helpers consume `*SchemaFieldsFromValidated(...)` and rely on the caller having already supplied validated schema fields.
- `tool/invariant_registry.dart` — `INV-ENG-RUNTIME-NODE-VALUE-OWNERS` states that patch-based writes inherit the same validated boundary contract as constrained runtime node fields.
- `API_GUIDE.md` — public integration contract describes `PatchField<T>` tri-state semantics and eager public patch constructor validation.
- `test/model/document_model_test.dart` — existing model contract tests already cover some patch nullability and invalid-value cases.

### Current Entry Path

- Public caller creates `CommonNodePatch` or a concrete `NodePatch` subtype.
- The constructor calls `validatePatchCommonSchemaFields(...)` or the concrete `validate*NodePatchSchemaFields(...)`.
- The resulting patch is later consumed by `txnApplyNodePatch(...)`, which delegates to common and typed patch assignment plans.

### Current Owner

- `lib/src/contract/internal/node_boundary_schema_patch.dart` is the current owner of public patch field admission and field-level nullability validation.

### Adjacent Abstractions

- `_validateNonNullablePatchField(...)` is the adjacent same-layer helper that already rejects explicit null writes and validates present values.
- `_validateNullablePatchField(...)` is the adjacent same-layer helper that preserves explicit null writes for nullable fields.
- `snapshotOffsetListPatchField(...)` is the patch schema helper that canonicalizes owned list state after value admission.

### Existing Tests

- `test/model/document_model_test.dart` — proves patch application behavior and already has examples for invalid non-nullable patch writes.
- `test/contract/patch_field_test.dart` — proves standalone `PatchField<T>` state semantics, including nullable `value(null)` canonicalization.
- `test/contract/validated_fast_path_contract_test.dart` — proves validated patch fast-path helper and materialization behavior.

### Analogous Implementation Path

- Existing non-nullable patch fields such as `transform`, `opacity`, `hitPadding`, `text`, `fontSize`, `points`, `thickness`, `size`, `strokeWidth`, and `svgPathData` already use `_validateNonNullablePatchField(...)`; the missing fields must follow the same schema-owner pattern.

### Governing Repository Rules

- `AGENTS.md` — validate data at system boundaries and fix root causes at the owning shared abstraction rather than patching one downstream call site.
- `AGENTS.md` — remove a `KNOWN_ISSUES.md` entry in the same change that fixes it and adds regression proof.
- `AGENTS.md` — public behavior changes must update `README.md`, `API_GUIDE.md`, and `CHANGELOG.md`; `ARCHITECTURE.md` updates are required when invariants, architecture, or module ownership change.
- `tool/invariant_registry.dart` — `INV-ENG-RUNTIME-NODE-VALUE-OWNERS` requires patch-based writes to inherit the validated boundary contract.
- `API_GUIDE.md` — public patch constructors validate present fields eagerly and `PatchField.nullValue()` is the explicit-null form.

### Rejected Misleading Local Patterns

- `lib/src/model/document_node_patch_common.dart` — tempting because `patch.value` is where the late failure occurs, but it is the consumer of admitted fields and lacks ownership of per-field nullability policy.
- `lib/src/model/document_node_patch_text.dart` and sibling typed patch application files — wrong level because fixing each family there would duplicate boundary policy across transaction consumers.
- `PatchField<T>` itself — wrong abstraction because explicit null is valid for nullable patch fields and the wrapper cannot infer field-level nullability from `T` reliably at runtime.
- `lib/src/contract/internal/node_patch_backing.dart` `*FromValidated(...)` helpers — wrong entrypoint for `KI-1` because these are validated-only fast-path surfaces, not the public admission boundary.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- Public contract boundary field admission for `NodePatch` schema fields.

#### Selected Architectural Form

- Normalize all non-nullable patch schema fields through `_validateNonNullablePatchField(...)` inside `validate*PatchSchemaFields(...)`.
- Keep nullable fields on `_validateNullablePatchField(...)` or direct nullable passthrough only where explicit null writes are part of the public contract.

#### Owning Layer or Module

- Contract layer, specifically `lib/src/contract/internal/node_boundary_schema_patch.dart`.

#### Dependency Direction

- Public patch constructors depend on contract schema validation.
- Model transaction code depends on already admitted public patch objects.
- Contract schema validation must not depend on model transaction code.

#### State and Data Ownership

- `PatchField<T>` owns tri-state representation.
- Patch schema validation owns whether a field admits absent, concrete value, or explicit null.
- Transactional patch application owns mutation and no-op detection after admission.

#### Entry and Exit Boundaries

- Entry: public `CommonNodePatch` and concrete `NodePatch` constructors.
- Exit: constructed patch objects whose non-nullable fields are either absent or hold a concrete validated value.

#### Permitted Extension Seam

- Extend existing schema helper use in `node_boundary_schema_patch.dart`; do not introduce a second nullability validator or transaction-side mirror.

#### Rejected Alternatives

- Add null checks in `txnPatchSet(...)` — rejects too late and leaves invalid public patch objects constructible.
- Add family-specific null checks in typed patch appliers — duplicates field admission policy across consumers.
- Change `PatchField.nullValue()` behavior globally — breaks valid nullable patch fields.
- Validate `*FromValidated(...)` helpers as the primary fix — targets internal fast-path trust rather than the public constructor defect in `KI-1`.

#### Why This Level Is Correct

- The defect is that public patch admission accepts an invalid state for non-nullable fields.
- The schema validator is already the shared owner for present-field validation and has the correct helper for this exact rule.
- Fixing this layer solves the defect once for all public constructors and preserves the transaction layer as a consumer of validated patches.

## 5. Locked Decisions

1. The implementation must update `validatePatchCommonSchemaFields(...)`, `validateTextNodePatchSchemaFields(...)`, `validateStrokeNodePatchSchemaFields(...)`, `validateLineNodePatchSchemaFields(...)`, and `validatePathNodePatchSchemaFields(...)` for the fields reported by `audit_patch_field_admission`.
2. The regression test must exercise public patch constructors, not only transactional application, because constructor admission is the behavior being fixed.
3. Nullable fields such as `naturalSize`, `fontFamily`, `maxWidth`, `lineHeight`, `fillColor`, and `strokeColor` must remain allowed to carry explicit null.
4. `KNOWN_ISSUES.md` `KI-1` may be removed only after behavioral and structural proof pass.

## 6. Result Requirements

1. Public patch constructors reject `PatchField.nullValue()` for every non-nullable patch field.
2. Public patch constructors continue to admit absent fields without validation side effects.
3. Public patch constructors continue to admit concrete valid values for the same fields.
4. Nullable patch fields continue to admit explicit null writes.
5. `dart run tool/audit_patch_field_admission.dart` reports no non-nullable passthrough violations for `KI-1`.

## 7. Execution Order and Gates

### Required Order

- Add a failing behavioral reproducer for the currently admitted non-nullable explicit-null patch fields.
- Add guard coverage for nullable explicit-null writes and valid concrete non-nullable writes.
- Update only the patch schema owner to reject the missing non-nullable explicit-null cases.
- Run the targeted behavioral test and the patch admission audit.
- Remove `KI-1` from `KNOWN_ISSUES.md` after the proof is green.
- Synchronize `README.md`, `API_GUIDE.md`, and `CHANGELOG.md` with the public behavior change.

### Successor Seam and Retirement Gates

- No successor seam is introduced.
- The retirement gate for `KI-1` is passing behavioral regression proof plus a clean `audit_patch_field_admission` run.

### Deferred Broad Verification

- Reserve `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->` for the final gate after implementation, tests, `KNOWN_ISSUES.md`, and documentation updates are complete.

## 8. File Map

### Implementation Files

- `lib/src/contract/internal/node_boundary_schema_patch.dart`

### Test Files

- `test/model/document_model_test.dart`

### Fixtures and Supporting Data

- None.

### Registry, Inventory, and Workflow Files

- `KNOWN_ISSUES.md`
- `README.md`
- `API_GUIDE.md`
- `CHANGELOG.md`
- `ARCHITECTURE.md` is excluded unless invariant wording, architecture, or module ownership changes during implementation.

### Analysis Area

- `tool/audit_patch_field_admission.dart`

## 9. Implementation Rules

### Protected Invariants

- `INV-ENG-RUNTIME-NODE-VALUE-OWNERS` — patch-based writes inherit the validated boundary contract.
- `INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY` — patch helper surfaces remain validated-only with unsafe raw owners kept separate.

### Required Proof

- behavioral proof: a public-constructor regression test rejects `PatchField.nullValue()` for all `KI-1` non-nullable fields.
- behavioral proof: guard cases show nullable explicit-null patch fields remain admitted.
- behavioral proof: guard cases show valid concrete writes for corrected non-nullable fields remain admitted.
- structural proof: `dart run tool/audit_patch_field_admission.dart`.
- for bug fixes, regressions, false positives, false negatives, and invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard tests for neighboring branches of the same contract.

### Allowed Change Surface

- Add or adjust tests in `test/model/document_model_test.dart` around patch boundary validation.
- Replace direct non-nullable patch field passthroughs with `_validateNonNullablePatchField(...)` in `node_boundary_schema_patch.dart`.
- Remove `KI-1` from `KNOWN_ISSUES.md` after proof.
- Make narrow `README.md`, `API_GUIDE.md`, and `CHANGELOG.md` updates for the public behavior change.

### Forbidden Moves

- Do not add nullability checks to transaction assignment helpers as the primary fix.
- Do not modify `PatchField<T>` state semantics.
- Do not change nullable patch field behavior.
- Do not alter internal unsafe materialization semantics.
- Do not broaden this step into other `KNOWN_ISSUES.md` entries.

## 10. Vertical Slices

### Slice 1. [x] Enforce Patch Boundary Nullability Contract

#### Slice Contract

Add test-first proof that public patch constructors reject explicit null writes for every non-nullable field listed in `KI-1`, then make the minimal schema-owner change that satisfies that proof while preserving neighboring valid nullable and concrete-value branches.

#### Change

Add the failing reproducer and guard tests before changing implementation, then update only `lib/src/contract/internal/node_boundary_schema_patch.dart` for the missing non-nullable fields.

#### Behavioral Verification

- Run `flutter test test/model/document_model_test.dart --name "node patch rejects explicit null for non-nullable public fields"`; record that it fails before the implementation change and passes after the schema-owner change.

#### Structural Verification

- `dart run tool/audit_patch_field_admission.dart` must report the current violations before the implementation change and pass with zero non-nullable passthrough violations after the schema-owner change.

#### Fixtures Used

- None.

#### Positive Scenarios

- Public constructors admit valid concrete values for the corrected non-nullable fields.
- Public constructors admit explicit null for nullable patch fields.
- Public constructors admit absent non-nullable fields without validation side effects.

#### Negative Scenarios

- Public constructors reject `PatchField.nullValue()` for `isVisible`, `isSelectable`, `isLocked`, `isDeletable`, `isTransformable`, text style fields, stroke color, line color, and path fill rule.

#### Closure Evidence

- The behavioral test fails before the implementation edit, then passes after it.
- The patch field admission audit is clean after the schema-owner change.

### Slice 2. [x] Close KI-1 And Public Reporting

#### Slice Contract

Retire the known issue only after proof exists, and keep public-facing docs consistent with the resulting contract.

#### Change

Remove `KI-1` from `KNOWN_ISSUES.md`; update `README.md`, `API_GUIDE.md`, and `CHANGELOG.md` for the public behavior change.

#### Behavioral Verification

- Re-run `flutter test test/model/document_model_test.dart --name "node patch rejects explicit null for non-nullable public fields"`.

#### Structural Verification

- Re-run `dart run tool/audit_patch_field_admission.dart`.

#### Fixtures Used

- None.

#### Positive Scenarios

- `KNOWN_ISSUES.md` no longer lists a resolved defect.

#### Negative Scenarios

- No unresolved `KI-1` evidence remains in the patch field admission audit.

#### Closure Evidence

- `KNOWN_ISSUES.md`, `README.md`, `API_GUIDE.md`, and `CHANGELOG.md` are synchronized with passing proof and the implemented behavior.

## 11. Final Verification

- `dart run tool/audit_patch_field_admission.dart`
- `flutter test test/model/document_model_test.dart --name "node patch rejects explicit null for non-nullable public fields"`
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`

## 12. Acceptance Criteria

- Every `KI-1` non-nullable patch field rejects `PatchField.nullValue()` during public constructor admission.
- Nullable patch fields continue to support explicit null writes.
- Transactional patch application remains a consumer of validated patch objects, not the owner of field nullability policy.
- `dart run tool/audit_patch_field_admission.dart` is green.
- `KI-1` is removed from `KNOWN_ISSUES.md` in the implementation change after regression proof passes.
- `README.md`, `API_GUIDE.md`, and `CHANGELOG.md` are synchronized with the public patch-admission behavior.
