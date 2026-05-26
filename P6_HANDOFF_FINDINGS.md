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
