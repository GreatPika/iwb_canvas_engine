# P6 Handoff Findings

This file captures the remaining review findings to hand off before starting P6.

## P3 / Cleanup

### 3. CanvasSurface placeholder detector is a raw substring

- Severity: P3
- Location:
  - `test/api_contract/public_api_no_unapproved_placeholders_test.dart:182`
- Problem:
  `CanvasSurface.build` placeholder detection uses exact source text, unlike the
  AST-based public placeholder checks.
- Suggested work:
  Detect the placeholder structurally with analyzer AST.

### 4. Field update fixture name is too narrow

- Severity: P3
- Location:
  - `test/edit/fixtures/field_update_nullable_semantics_fixture.dart:1`
- Problem:
  The fixture covers nullable clears, rejected dynamic clears, non-invertible
  transforms, mismatched update kinds, geometry revisions, and selection pruning.
  The name only suggests nullable semantics.
- Suggested work:
  Rename around the broader owner, for example field update admission/effects
  semantics.

### 5. Schema root fields constant looks like an unused registry

- Severity: P3
- Location:
  - `lib/src/codec/schema_v1_validation.dart:5`
- Problem:
  `canvasSchemaV1RootFields` looks like a schema field source of truth, but
  decode, encode, and tests do not consume it.
- Suggested work:
  Consume it for canonical field checks, or remove/rename it so it does not imply
  enforcement.

### 7. Document summary fixture claim is broader than its body

- Severity: P3
- Location:
  - `test/runtime/fixtures/document_summary_publication_fixture.dart:7`
- Problem:
  The fixture name/test says publication/coherence, but the body checks only the
  initial summary against the initial document projection. Transition coverage
  lives elsewhere.
- Suggested work:
  Rename/scope it down, or merge it into runtime state publication coverage.
