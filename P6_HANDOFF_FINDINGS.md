# P6 Handoff Findings

This file captures the remaining review findings to hand off before starting P6.

### 5. JSON boundary path can become DTO-level path for appKey validation

- Severity: P2
- Location:
  - `lib/src/api/canvas_resource.dart:76`
  - `lib/src/codec/schema_v1_decoder.dart:379`
- Problem:
  The decoder reads `resource.source.key`, but materialization through
  `CanvasResourceSource.appKey` can report `resource.source.appKey` for some
  value-validation failures, such as empty or control-character keys. That is a
  DTO-level path, not the JSON boundary path.
- Suggested work:
  Validate appKey at the codec boundary with the JSON path, or add a path
  override path for codec materialization.

### 6. Public type reference guard allows Flutter src paths

- Severity: P2
- Location:
  - `tool/guardrails/src/public_api_type_references.dart:165`
- Problem:
  The contract allows public API types from `package:flutter/widgets.dart` and
  `package:flutter/foundation.dart`, but the guardrail also allows
  `package:flutter/src/widgets/**` and `package:flutter/src/foundation/**`.
- Suggested work:
  Reject direct `package:flutter/src/**` exposure, or prove that analyzer
  resolves public Flutter types to `src` URIs and encode that exception narrowly.

## P3 / Cleanup

### 1. Root CI guardrail proof does not check bypass flags

- Severity: P3
- Location:
  - `test/guardrails/root_ci_target_test.dart:9`
- Problem:
  The workflow test checks that the full guardrail runner command is present,
  but does not check bypass-style settings such as `continue-on-error`.
- Suggested work:
  Assert that the root-package job and guardrail step do not use bypass settings.

### 2. Blocking suite expected ids are hand-maintained in the test

- Severity: P3
- Location:
  - `test/guardrails/blocking_suite_test.dart:103`
- Problem:
  The "all P4 guardrails" proof compares against manually maintained sets in the
  same test file.
- Suggested work:
  Derive expected phase or suite ids from the registry/source of truth where
  possible.

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

### 6. Negative fixture hook in guardrail runner is dead

- Severity: P3
- Location:
  - `tool/guardrails/src/guardrail_executor.dart:159`
- Problem:
  `_negativeFixtureViolationsFor` is wired into the runner flow but always
  returns an empty list.
- Suggested work:
  Remove it until needed, or connect it to real negative fixture checks.

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
